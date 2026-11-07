class_name Game
extends Node3D
## The game: table, machine, money, tray, discard pile and the camera between them.
## The room (Diner, Bar, Bingo Hall) sets the lights and where the machine stands.
## Rules: MIGRATION.md "Money", "Machine", "Table and machine navigation", "Bill window".
## Settings and the session are kept through the Save autoload (SessionState says what
## is kept); Esc / MENU opens the player menu, backquote the developer panel (debug builds).
##
## Two modes, each with its own table, money and save slot: free play (the demo: no
## goal, the house loan) and the run (story mode: RunState's debt in three layers, a
## day at the machine or a shift of work, shown on the RunCard).
## The phone (Phone, or the one lying on the table) holds LOAN in both modes, and in
## the run the shop (perks, items) and the contacts; RunState's effect hooks apply what
## was bought (M9).

const SEED := "G-0001"
## The machine's columns, left to right (the first half stands left of the console).
const FORM_UIDS := ["core:catch", "core:plate", "core:spur", "core:order",
	"core:kabawk", "core:flock", "core:nugget", "core:peckeye"]
const INFO_TIME := 2.5           ## how long the LCD names a column pressed by key
const START_ROOM := "diner"
const MACHINE_LIGHT_ENERGY := 0.8 / 6.5
const UI_TICK := 0.09
const MESSAGE_TIME := 1.6
const AUTOSAVE := 2.0
## The winners' pile: behind the tray, across the table from the discard pile. x as a
## share of the tray's offset from the middle; a tighter heap than the discards.
const WIN_PILE_AT := Vector3(1.03, 0, -1.8)
const WIN_PILE_SPREAD := 0.55
## The item tray (run): at the near left, mirroring the trash can; x as a share of the
## tray's offset from the middle, as above. It lies in front of the discard pile, left of
## the notepad and below the held ticket, turned toward the player.
const ITEM_TRAY_AT := Vector3(-0.94, 0, 3.0)
const ITEM_TRAY_YAW := 0.3

var painter := TicketPainter.new()
var rooms := RoomSet.new()
var machine_light := OmniLight3D.new()
var camera := CameraRig.new()
var view := TicketView.new()
var flecks := Flecks.new()
var flow := TicketFlow.new()
var table_tray := TableTray.new()
var pile := DiscardPile.new()
## Winning tickets get a pile of their own (looks only), lying inside up: each shows the
## prizes it held (G).
var win_pile := DiscardPile.new()
var machine_view := MachineView.new()
var hud := Hud.new()
var notepad := Notepad.new()
var input := GameInput.new()
var menu := Menu.new()
var run_card := RunCard.new()
var phone := Phone.new()
var table_phone := TablePhone.new()
var trash_can := TrashCan.new()
## Run only: the room's tray of items held on the table, and the picker it opens (M9.7).
var item_tray := ItemTray.new()
var item_picker := ItemPicker.new()
var dev: DevPanel

## Where the save lives ("" = the platform's save folder); tools point it elsewhere.
var save_path := ""
var use_save := true

## What the machine sells, a column each; tools set another list before the game is added.
var form_uids: Array = FORM_UIDS
var mode := "free"                 ## "free" play or the "run"
var run: RunState                  ## the run in progress; null in free play
var run_seed := ""                 ## tools: the seed of the next new run ("" picks one)
var base_forms: Array = []         ## every form the game sells, as the pack wrote them (stake 1)
## The machine's columns in the room in play: indexes into machine.forms. A room may
## sell fewer forms than the game has (RoomSet "forms"); free play keeps every form's
## box all the same, so a box goes on where it was when the player comes back.
var columns: Array = []
var economy := Economy.new()
var machine: MachineLogic
var tray := TicketTray.new()
var at_machine := true
var hover_column := -1             ## the machine column under the pointer, or -1 (GameInput)
var hover_item := ""               ## the item whose token in the tray is under the pointer, or "" (GameInput)
var current: Dictionary = {}       ## tray entry of the ticket in hand
var _go_machine := false            ## after this toss, go to the machine instead of dealing
var _time := 0.0
var _ui_at := 0.0
var _msg := ""
var _msg_until := 0.0
var _info_column := -1              ## the column pressed last: the LCD names it for a while
var _info_until := 0.0
var _ready_done := false
var _saved_at := 0.0
var _switching := false             ## a mode or a layer is being set up
var _leaving := false               ## run: the LEAVE card is up
var _trashing := false              ## the card asking before tickets go in the trash can is up
var _card_busy := false             ## run: a card key is being carried out
var _day := {}                      ## run: the ledger when today's play began {spent, won}
var aim := ""                       ## run: an item used on a column (PEEK, BOX REPORT) waits for a column press
var _picking := -1                  ## run, PICKY: the machine column whose new box waits for a form (the card is up)
var _sealing := false               ## run, SEAL: the card asking which boxes come along is up
var _seal_keep: Array = []          ## run, SEAL: the machine columns chosen so far
var _moonlight := false             ## run, MOONLIGHTING: at the machine after the shift (tickets for tomorrow)
var _pushing := false               ## run, ALL IN: the card asking whether to stake the window just closed is up
var _msg_args := []


func _ready() -> void:
	if _run_tool():
		return
	if use_save:
		Save.open(save_path)
		Lang.set_language(Save.setting("language"))
		Sfx.apply_settings(Save.settings)
		_apply_window()
		MachineView.lamp_preset = clampi(int(Save.setting("lamp")), 0, MachineView.LAMP_STEPS - 1)
	else:
		Lang.set_language("en")   # preview tools: English, their own lamp step, no file
	add_child(painter)
	add_child(rooms)
	add_child(camera)
	camera.current = true
	view.painter = painter
	view.visible = false
	add_child(view)
	add_child(flecks)
	add_child(table_tray)
	pile.painter = painter
	pile.find_form = _form_for
	add_child(pile)
	win_pile.painter = painter
	win_pile.find_form = _form_for
	win_pile.find_ticket = _ticket_for
	win_pile.show_inside = true
	win_pile.use_seed("wins", WIN_PILE_SPREAD)
	add_child(win_pile)
	notepad.painter = painter
	add_child(notepad)
	add_child(table_phone)
	add_child(trash_can)
	add_child(item_tray)
	add_child(hud)

	var forms: Array = []
	for uid in form_uids:
		forms.append(Packs.form(uid))
	if forms.has(null):
		_show_missing_data()
		return
	base_forms = forms
	machine = MachineLogic.new(forms, SEED)
	machine_view.painter = painter
	add_child(machine_view)   # built by _apply_stage, for the forms and stake of the stage in play
	machine_light.light_color = Color("#fff0e0")
	# Web build: PointLight(0xfff0e0, .8, 22, 1.2) with its own gentle falloff. Godot's default
	# 1/d falloff blew up into a hot spot on the diner booth, which this light stands right
	# against; no distance term here, and the energy keeps the machine face as lit as in M4
	# (0.8 at 1/d for the face's 6.5 units).
	machine_light.light_energy = MACHINE_LIGHT_ENERGY
	machine_light.omni_range = 22.0
	machine_light.omni_attenuation = 0.0
	add_child(machine_light)
	camera.at_machine = true
	camera.cam = 1.0

	flow.camera = camera
	flow.view = view
	flow.flecks = flecks
	flow.tray = table_tray
	flow.pile = pile
	flow.win_pile = win_pile
	flow.back_first = use_save and bool(Save.setting("back_first"))
	flow.one_click = use_save and bool(Save.setting("one_click"))
	flow.auto_wins = use_save and bool(Save.setting("auto_wins"))
	flow.may_auto_collect = _may_auto_collect
	flow.next_ticket = _take_ticket
	flow.deal_after_toss = _deal_after_toss
	flow.dealt.connect(_on_dealt)
	flow.revealed.connect(_on_revealed)
	add_child(flow)
	input.game = self
	add_child(input)
	hud.bill_pressed.connect(insert_bill)
	hud.cash_out_pressed.connect(cash_out)
	hud.phone_pressed.connect(open_phone)
	hud.menu_pressed.connect(toggle_menu)
	hud.leave_pressed.connect(leave_day)
	hud.new_box_pressed.connect(toggle_change)
	hud.open_pressed.connect(open_many)
	add_child(run_card)
	run_card.picked.connect(_on_card)
	add_child(phone)
	phone.acted.connect(_on_phone)
	phone.closed.connect(_on_phone_closed)
	add_child(item_picker)
	item_picker.acted.connect(_on_picker)
	add_child(menu)
	menu.mode_picked.connect(set_mode)
	menu.new_run_pressed.connect(new_run)
	menu.room_picked.connect(pick_room)
	menu.volume_changed.connect(set_master)
	menu.mute_toggled.connect(toggle_mute)
	menu.fullscreen_toggled.connect(toggle_fullscreen)
	menu.back_first_toggled.connect(toggle_back_first)
	menu.one_click_toggled.connect(toggle_one_click)
	menu.auto_wins_toggled.connect(toggle_auto_wins)
	menu.language_picked.connect(set_language)
	menu.quit_pressed.connect(quit_game)
	await _enter_mode(str(Save.setting("mode")) if use_save else "free", true)
	if OS.is_debug_build():
		dev = DevPanel.new()
		dev.game = self
		add_child(dev)
	get_viewport().size_changed.connect(_place_tray_and_pile)
	_place_tray_and_pile()
	hud.set_status("READY")
	_ready_done = true


# --- actions --------------------------------------------------------------------

## A machine button: a column, or PLAY ALL (the index after the last column). The number
## keys and Space press the same buttons.
func press_machine(i: int) -> void:
	if (run != null and not _selling()) or i < 0 or i > columns.size():
		return
	var play_all := i == columns.size()
	Sfx.play("button")
	machine_view.press_button(i)
	machine.return_at = 0.0
	if not play_all:
		_info_column = i
		_info_until = _time + INFO_TIME
	if aim != "":
		# An item waits for a column: this press is it; PLAY ALL lets it go.
		var item := aim
		aim = ""
		if play_all:
			return
		var got := run.use_item(item, machine, columns[i])
		if not got.is_empty():
			match item:
				"peek":
					say("NEXT %d: %d WIN", [got.of, got.winners], 4.0)
				"magnifier":
					say("NEXT ONE WINS" if got.wins else "NEXT ONE LOSES", [], 3.0)
				"report":
					say("BOX READ", [], 1.2)
					_info_until = _time + 8.0
				"skip":
					Sfx.play("toss")
					say("SKIPPED %d", [got.skipped], 2.5)
				"shuffle":
					Sfx.play("toss")
					say("SHUFFLED", [], 1.6)
				"coin":
					say("NEXT PRIZE X2", [], 2.5)
				"mover":
					Sfx.play("toss")
					_refresh_machine_view()
					say("BOXES SWAPPED", [], 2.0)
				"sure", "reel":
					say("NEXT ONE WINS", [], 3.0)
				"queue":
					say("%d WINNERS MOVED UP", [got.moved], 3.0)
		else:
			say("NOTHING TO MOVE", [], 2.0)
		_store_session()
		return
	if machine.change_armed:
		# NEW BOX is armed: a column press changes that column's box; PLAY ALL lets it go.
		if play_all:
			machine.change_armed = false
		elif run.can_pick_form():
			# PICKY: a card asks which of the layer's forms goes in first.
			machine.change_armed = false
			if economy.cash < run.change_fee():
				say("NO CASH")
				return
			_picking = columns[i]
			_show_run_card()
		elif run.change_box(economy, machine, columns[i]):
			Sfx.play("toss")
			say("NEW BOX")
		else:
			machine.change_armed = false
			say("NO CASH")
		return
	var r := machine.press_play_all(economy) if play_all else machine.press(columns[i], economy)
	if r == "insert_bill":
		say("INSERT BILL")


## The red PLAY ALL button.
func press_play_all() -> void:
	press_machine(columns.size())


## Run: the machine sells today: a day of play, or MOONLIGHTING's visit after the shift.
func _selling() -> bool:
	return run != null and (run.today == "play" or (_moonlight and run.today == "work"))


## Run, PICKY: the card of the forms the layer sells, one key each, for the column's new box.
func _pick_card() -> void:
	var rows := []
	var row := []
	for f: FormDef in run.stage_forms(_room_forms(run.scene())):
		row.append({"id": "pick_" + f.id, "text": f.name.to_upper()})
		if row.size() == 4:
			rows.append(row)
			row = []
	if not row.is_empty():
		rows.append(row)
	rows.append([{"id": "pick_back", "text": tr("BACK"), "kind": "chrome"}])
	var col := columns.find(_picking) + 1
	run_card.show_card(tr("WHICH TICKET GOES IN?"), [tr("NEW BOX IN COLUMN %d") % col,
		[tr("CASH %s") % Hud._money(economy.cash), "dim"]], rows)


## A key on the PICKY card: the form goes into the column (a new box, for the fee), or BACK.
func _on_pick(id: String) -> void:
	var col := _picking
	_picking = -1
	Sfx.play("button")
	var form: FormDef = null
	for f: FormDef in run.stage_forms(_room_forms(run.scene())):
		if "pick_" + f.id == id:
			form = f
	if form != null and col >= 0:
		if run.change_box(economy, machine, col, form):
			await _refresh_machine_view()
			Sfx.play("toss")
			say("NEW BOX")
			_store_session()
		else:
			say("NO CASH")
	_show_run_card()


func insert_bill(value: int) -> void:
	if not at_machine or not economy.insert(value):
		return
	hud.set_cash(economy.cash)


func cash_out() -> void:
	if machine.busy() or economy.credit <= 0:
		return
	economy.cash_out()
	machine.armed = false
	Sfx.play("toss")


## LOAN (on the phone): the house's flat line in free play; in the run, the layer's
## line, which goes on top of what is due with interest.
func take_loan() -> bool:
	if not (run.borrow(economy) if run != null else economy.take_loan()):
		return false
	Sfx.play("toss")
	hud.set_status("HOUSE LOAN")
	return true


## Run: the NEW BOX key (or N) arms a box change for the next column press.
func toggle_change() -> void:
	if run == null or not at_machine or camera.cam <= 0.9 or machine.busy() or run.today != "play":
		return
	Sfx.play("button")
	machine.press_change()


## Run, at the table: QUICK HANDS opens the next tickets of the tray at once (the ticket
## in hand first, if it is untouched). They go straight onto their piles.
func open_many() -> void:
	if run == null or at_machine or run.batch_size() <= 0 or camera.cam > 0.1:
		return
	if flow.state == TicketFlow.State.FRONT or flow.state == TicketFlow.State.BACK:
		if TableNav.leave(flow.hand(), flow.has_band(), view.band_on, view.any_torn(), false) != TableNav.Action.RETURN_THEN_GO:
			hud.set_status("ALREADY TORN")
			return
		flow.cancel()
		tray.put_back(current)
		current = {}
	elif flow.state != TicketFlow.State.IDLE or flow.dealing():
		return
	if tray.is_empty():
		return
	if not run.can_open():
		hud.set_status("OPEN THEM TOMORROW")
		return
	var entries := tray.take_many(run.batch_size())
	var pushed := _push_counts()
	var got := run.open_batch(economy, entries)
	_land(entries)
	if got.winners > 0:
		Sfx.play_win(maxi(1, got.won))
		hud.flash_win()
	else:
		Sfx.play("toss")
	hud.set_status("OPENED %d · %d WIN · $%d", [got.n, got.winners, got.won])
	_after_opening(pushed)
	_store_session()
	if not tray.is_empty():
		flow.deal()


## Run, ALL IN: what the run has won and lost on pushes so far (an opening compares).
func _push_counts() -> Array:
	return [int(run.stats.push_won), int(run.stats.push_lost)]


## Run, after an opening (by hand or OPEN): a push it settled is said, and, when it
## closed a window (RunState.take_window_closed) that can be staked (can_push), the
## ALL IN card goes up. While ALL IN is held an opening never crosses a window's end
## (RunState.batch_size), so every window that closes is asked about (G).
func _after_opening(before: Array) -> void:
	var won := int(run.stats.push_won) - int(before[0])
	var lost := int(run.stats.push_lost) - int(before[1])
	if won > 0:
		Sfx.play_win(won)
		hud.set_status("ALL IN WON $%d", [won])
		hud.flash_win()
	elif lost > 0:
		hud.set_status("ALL IN LOST $%d", [lost])
	hud.set_cash(economy.cash)
	if run.take_window_closed() and run.can_push(economy) and not _pushing:
		_pushing = true
		_show_run_card()


## The ALL IN card: the stake (what the window just closed paid), what the next
## window has to print, PUSH IT or KEEP IT.
func _push_card() -> void:
	var stake := run.push_offer()
	run_card.show_card(tr("ALL IN?"), [
		[tr("STAKE %s") % Hud._money(stake), "big"],
		tr("THE NEXT 10 MUST PRINT MORE THAN %s") % Hud._money(int(run.last_window.get("printed", 0))),
		tr("MORE: %s BACK. AS MUCH OR LESS: GONE") % Hud._money(stake * 3),
		[tr("CASH %s") % Hud._money(economy.cash), "dim"],
	], [[{"id": "push", "text": tr("PUSH IT")}, {"id": "keep", "text": tr("KEEP IT"), "kind": "chrome"}]])


## A key on the ALL IN card.
func _on_push(id: String) -> void:
	_pushing = false
	Sfx.play("button")
	if id == "push" and run.push(economy):
		Sfx.play("toss")
		hud.set_status("STAKED $%d", [run.push_stake])
		hud.set_cash(economy.cash)
		_store_session()
	_show_run_card()


## Tickets opened without the hand (QUICK HANDS): winners onto the winners' pile,
## the rest onto the discard pile, all at once.
func _land(entries: Array) -> void:
	var lost := []
	var wins := []
	for en in entries:
		if int(en.ticket.prize) > 0:
			wins.append(win_pile.face_id(en.form, en))
		else:
			lost.append(pile.face_id(en.form, en))
	pile.land_many(lost)
	win_pile.land_many(wins)


## Space / Enter.
func primary() -> void:
	if at_machine:
		if economy.can_buy(machine.min_price()):
			press_play_all()
		elif not tray.is_empty():
			toggle_view()
		else:
			say("INSERT BILL")
		return
	if flow.state == TicketFlow.State.IDLE and tray.is_empty():
		open_machine()
		return
	flow.primary()


## B and the view button.
func toggle_view() -> void:
	if at_machine:
		if machine.busy() or economy.bill > 0:
			return
		close_machine()
		if flow.state == TicketFlow.State.IDLE and not tray.is_empty():
			flow.deal()
		else:
			hud.set_status("READY")
		return
	_leave_table(false)


## The player clicked the machine from the table.
func leave_for_machine() -> void:
	_leave_table(true)


func _leave_table(machine_click: bool) -> void:
	match TableNav.leave(flow.hand(), flow.has_band(), view.band_on, view.any_torn(), machine_click):
		TableNav.Action.GO:
			open_machine()
		TableNav.Action.RETURN_THEN_GO:
			flow.cancel()
			tray.put_back(current)
			current = {}
			open_machine()
		TableNav.Action.DISCARD_THEN_GO:
			_go_machine = true
			flow.collect()


func open_machine() -> void:
	at_machine = true
	camera.at_machine = true
	machine.return_at = 0.0
	hud.set_status("ONE MORE?")


func close_machine() -> void:
	at_machine = false
	camera.at_machine = false
	machine.return_at = 0.0
	machine.armed = false
	machine.change_armed = false


## A short message on the machine LCD's status line (a translation key, with format args).
func say(key: String, args := [], time := MESSAGE_TIME) -> void:
	_msg = key
	_msg_args = args
	_msg_until = _time + time


## The built-in ticket data is missing or damaged (packs/core next to the game): say so
## instead of starting a game that cannot run. Both languages, as the menu is not up.
func _show_missing_data() -> void:
	hud.visible = false
	var layer := CanvasLayer.new()
	add_child(layer)
	var l := LcdStyle.label("", 30, LcdStyle.LCD)
	l.text = "Last Sale could not load its ticket data.\nPlease verify or reinstall the game.\n\n无法读取彩票数据，请验证或重新安装游戏。\n\n%s" % Platform.builtin_pack_dir()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(l)
	for dir in Packs.errors:
		push_error("Data pack rejected: %s\n  %s" % [dir, "\n  ".join(Packs.errors[dir].slice(0, 8))])


## Debug builds only: `-- --run-tool=res://tools/<scene>.tscn` opens a tool scene in
## place of the game, before the save is touched. Exported builds refuse scene paths
## on the command line, so this is how a verify export runs drive_game or bench_fps.
static var _tool_started := false

func _run_tool() -> bool:
	if _tool_started or not OS.is_debug_build():
		return false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--run-tool="):
			_tool_started = true
			# Every part of this game was made but never added; their own parts too. The
			# engine lists such nodes in debug builds (this path is debug-only): free them.
			for id in Node.get_orphan_node_ids():
				var n := instance_from_id(id)
				if is_instance_valid(n) and n is Node and n.get_parent() == null:
					n.free()
			get_tree().change_scene_to_file.call_deferred(a.trim_prefix("--run-tool="))
			return true
	return false


# --- modes and the run ----------------------------------------------------------------

## Menu: free play or the story's run. Each keeps its own table, money and save slot.
func set_mode(new_mode: String) -> void:
	if new_mode == mode or not _ready_done or _switching or not ["free", "run"].has(new_mode):
		_menu_state()
		return
	await _enter_mode(new_mode)
	_menu_state()


## Stores the mode in play (unless this is the start) and sets the other one up from
## its save slot: a run not found, or one that does not add up, starts fresh.
func _enter_mode(new_mode: String, first := false) -> void:
	if not first:
		_store_session()
	_switching = true
	_clear_table()
	mode = new_mode if new_mode == "run" else "free"
	Save.set_setting("mode", mode)
	var saved: Dictionary = {}
	if mode == "run":
		var state = Save.run.get("state")
		run = RunState.from_dict(state, RunConfig.standard()) if typeof(state) == TYPE_DICTIONARY else null
		if run != null and typeof(Save.run.get("session")) == TYPE_DICTIONARY:
			saved = Save.run.session
			var day = Save.run.get("day")
			_day = day if typeof(day) == TYPE_DICTIONARY else {}
		if run == null:
			run = _fresh_run()
		economy = run.new_economy()
		machine = _run_machine()
	else:
		run = null
		economy = Economy.new()
		machine = MachineLogic.new(base_forms, SEED)
		saved = Save.session
	if use_save and not saved.is_empty():
		var restored: bool = await _restore_session(saved)
		if not restored and run != null:
			# The run's money does not add up: the run cannot be trusted either.
			run = _fresh_run()
			economy = run.new_economy()
			machine = _run_machine()
	await _apply_stage()
	_switching = false
	open_machine()
	hud.set_status("READY")
	_show_run_card()


## A new run: the first layer at the player's table, the next two at the other rooms
## (until the later scenes exist).
func _fresh_run() -> RunState:
	var start: String = Save.setting("room")
	var i := maxi(0, RoomSet.ORDER.find(start))
	var n := RoomSet.ORDER.size()
	var scenes := [RoomSet.ORDER[i], RoomSet.ORDER[(i + 1) % n], RoomSet.ORDER[(i + 2) % n]]
	_day = {}
	return RunState.start(RunConfig.standard(), run_seed if run_seed != "" else "R-%06d" % (randi() % 1000000), scenes)


## Gives the run in progress up and starts another (menu NEW RUN, the settlement card,
## the developer panel's reset).
func new_run() -> void:
	if _switching or not _ready_done:
		return
	if run == null:
		Save.set_run({})
		await set_mode("run")
		return
	_switching = true
	_clear_table()
	run = _fresh_run()
	economy = run.new_economy()
	machine = _run_machine()
	await _apply_stage()
	_switching = false
	open_machine()
	hud.set_status("READY")
	_store_session()
	_show_run_card()
	_menu_state()


## Empties the table: the ticket in hand, the tray, the pile, anything in the machine.
func _clear_table() -> void:
	flow.cancel()
	current = {}
	_go_machine = false
	_leaving = false
	_trashing = false
	_picking = -1
	_sealing = false
	_seal_keep = []
	_moonlight = false
	_pushing = false
	tray.clear()
	pile.clear()
	win_pile.clear()
	_old_boxes.clear()
	aim = ""
	Sfx.motor(false)
	machine_view.show_bill(0, 0.0)
	run_card.hide_card()
	phone.visible = false
	item_picker.visible = false


## The room and the bills of the stage in play: the layer's in the run, the player's
## table and the pack's stake in free play.
func _apply_stage() -> void:
	var room: String = run.scene() if run != null else Save.setting("room")
	await set_room(room if RoomSet.ORDER.has(room) else START_ROOM, run == null)
	# The fronts of every form, painted before the first ticket flies out.
	for f in machine.forms:
		await pile.art(f)
	await machine_view.paint_bills(economy.bills)


## The forms a room's machine sells (RoomSet "forms"), out of every form the game has.
func _room_forms(room_id: String) -> Array:
	var wanted := RoomSet.machine_forms(room_id)
	var out := []
	for uid in wanted:
		for f: FormDef in base_forms:
			if f.uid() == str(uid):
				out.append(f)
	return out if not out.is_empty() else base_forms


## The run's machine for the layer in play: what its scene's machine sells, at its stake.
func _run_machine() -> MachineLogic:
	return run.new_machine(_room_forms(run.scene()))


## The forms on the machine's columns, left to right.
func column_forms() -> Array:
	var out := []
	for c in columns:
		out.append(machine.forms[c])
	return out


## Run: the LEAVE key puts the LEAVE card up: the day so far, and how many tickets
## would be thrown away. Nothing is lost until the player confirms there (NEXT DAY or PAY).
func leave_day() -> void:
	if run == null or run_card.visible or not _selling() or _switching:
		return
	Sfx.play("button")
	machine.queue.clear()   # nothing more is sold while the card is up
	machine.armed = false
	machine.change_armed = false
	_leaving = true
	if _moonlight:
		# MOONLIGHTING: back to the SHIFT DONE card; the tickets wait for tomorrow.
		_moonlight = false
		_walk_out()
	_show_run_card()


## Tickets tossed so far, on either pile.
func piled() -> int:
	return pile.opened + win_pile.opened


## Run: tickets bought and not opened yet (the tray, and one in hand not revealed).
func _unopened() -> int:
	return tray.size() + (0 if _hand_unrevealed().is_empty() else 1)


## The tray entry of a ticket in hand that is not revealed yet, or {}.
func _hand_unrevealed() -> Dictionary:
	match flow.state:
		TicketFlow.State.DEAL, TicketFlow.State.FRONT, TicketFlow.State.FLIP, TicketFlow.State.BACK:
			return current
		TicketFlow.State.IDLE:
			if flow.dealing():
				return current
	return {}


## Run: the player leaves (G: confirmed on the LEAVE card). Tickets not opened stay
## in the tray for the next day of the same layer (G, after M9): a ticket in hand not
## revealed yet goes back on top of the tray; an opened one goes on its pile. They are
## thrown away only when the layer ends (_layer_ended). A bill being fed lands first,
## so its money counts.
func _walk_out() -> void:
	var hand := _hand_unrevealed()
	if flow.state == TicketFlow.State.REVEALED:
		flow.collect()
		_go_machine = true   # after the toss, nothing more is dealt today
	elif flow.state != TicketFlow.State.TOSS and flow.state != TicketFlow.State.AWAY:
		flow.cancel()
		current = {}
		if not hand.is_empty():
			tray.put_back(hand)
	if economy.bill > 0:
		economy.step_bill(Economy.BILL_TIME)
		machine_view.show_bill(0, 0.0)
	open_machine()


## Run: the layer is over (paid, or its last day ended): tickets still unopened are
## thrown away, paid for and never opened, whatever they held.
func _layer_ended() -> void:
	run.stats.discarded += _unopened()
	flow.cancel()
	current = {}
	tray.clear()


## A key on the run's card.
func _on_card(id: String) -> void:
	if id == "menu":
		toggle_menu()
		return
	if id == "phone":
		open_phone()
		return
	if id.begins_with("trash_"):
		_on_trash(id)
		return
	if run == null or _card_busy or _switching:
		return
	if id.begins_with("offer_"):
		_on_offer(id)
		return
	if id.begins_with("pick_"):
		_on_pick(id)
		return
	if id.begins_with("seal_"):
		_on_seal(id)
		return
	if id == "push" or id == "keep":
		_on_push(id)
		return
	_card_busy = true
	Sfx.play("button")
	match id:
		"ok":
			run.story = ""
		"play":
			if run.play(economy):
				_day = {"spent": economy.spent, "won": economy.won}
		"work":
			run.work(economy)
		"machine":
			# MOONLIGHTING: to the machine after the shift, for tomorrow's tickets.
			if run.today == "work" and run.effect("wage_cut") > 0:
				_moonlight = true
				_leaving = false
				open_machine()
		"loan":
			take_loan()
		"back":
			_leaving = false
		"pay":
			if _seal_choice():
				# SEAL: which boxes come along is asked first (_on_seal pays).
				_sealing = true
				_seal_keep = []
			else:
				await _pay([])
		"next":
			var layer := run.layer
			if _leaving:
				_walk_out()
			run.end_day(economy)
			_leaving = false
			if not run.playing() or run.layer != layer:
				_layer_ended()
			if run.playing() and run.layer != layer:
				await _next_layer()
		"new_run":
			_card_busy = false
			await new_run()
			return
		"free":
			_card_busy = false
			await set_mode("free")
			Save.set_run({})   # the run was over: free play leaves nothing of it behind
			return
	if run.today != "work":
		_moonlight = false
	if run.playing():
		run.apply(machine)   # the day chosen (a new day's perks on the machine)
	_card_busy = false
	_store_session()
	_show_run_card()


## Pays the layer (the PAY key): with SEAL, the machine columns in `keep` come along.
func _pay(keep: Array) -> void:
	var layer := run.layer
	if _leaving and run.can_pay(economy):
		_walk_out()
	if run.pay(economy, machine, keep):
		Sfx.play_win(50)
		_leaving = false
		_moonlight = false
		_layer_ended()
		if run.playing() and run.layer != layer:
			await _next_layer()


## SEAL: the player picks the boxes that come along when there are more with tickets
## left than the perk keeps (otherwise every one of them comes, no question).
func _seal_choice() -> bool:
	return run.effect("seal") > 0 and run.can_pay(economy) and run.seal_choices(machine).size() > run.effect("seal")


## The SEAL card: a key for each column with tickets left and not chosen yet, one box
## at a time, up to the perk's count.
func _seal_card() -> void:
	var lines := [[tr("%d OF %d CHOSEN") % [_seal_keep.size(), run.effect("seal")], "dim"]]
	var rows := []
	for i in run.seal_choices(machine):
		if _seal_keep.has(i) or not columns.has(i):
			continue
		var box: TicketBox = machine.boxes[i]
		rows.append([{"id": "seal_%d" % i, "text": tr("COLUMN %d · %s · %d LEFT") % [columns.find(i) + 1,
			machine.forms[i].name.to_upper(), box.size - box.cursor]}])
	rows.append([{"id": "seal_back", "text": tr("BACK"), "kind": "chrome"}])
	run_card.show_card(tr("WHICH BOX COMES ALONG?"), lines, rows)


## A key on the SEAL card: a box chosen (the layer is paid once the perk's count is
## chosen), or BACK.
func _on_seal(id: String) -> void:
	Sfx.play("button")
	if id == "seal_back" or not _seal_choice():
		_sealing = false
		_seal_keep = []
		_show_run_card()
		return
	var i := int(id.trim_prefix("seal_"))
	if run.seal_choices(machine).has(i) and not _seal_keep.has(i):
		_seal_keep.append(i)
	if _seal_keep.size() < run.effect("seal"):
		_show_run_card()
		return
	_sealing = false
	_card_busy = true
	await _pay(_seal_keep)
	_seal_keep = []
	_card_busy = false
	_store_session()
	_show_run_card()


## A key on the card of perk offers: buy one (or take it free with a CHEAT SHEET),
## reroll them, put them away for later (they wait on the phone's TODAY page until
## the day ends), or be done (skipping them all gives an item).
func _on_offer(id: String) -> void:
	Sfx.play("button")
	var ok := false
	if id == "offer_reroll":
		ok = run.reroll_offers(economy)
	elif id == "offer_later":
		run.close_offers()
	elif id == "offer_done":
		var gift := run.close_offers(true)
		if gift != "":
			hud.set_status("GOT %s", [tr(run.catalog.item(gift).name)])
	elif id.begins_with("offer_free_"):
		ok = run.buy_offer(int(id.trim_prefix("offer_free_")), economy, true)
	else:
		ok = run.buy_offer(int(id.trim_prefix("offer_")), economy)
	if ok:
		Sfx.play("toss")
		run.apply(machine)
	_store_session()
	_show_run_card()


## The card of perk offers: each offer, its level and kind, in its rarity's colour (G:
## no word for it, the colour says it), and what it does (a risk perk's cost after it,
## _perk_text), a key to buy each (and to take one free with a CHEAT SHEET), reroll,
## LATER (they stay for the day, on the phone), done or skip for an item. No
## requirements here: those are the shelf's (G).
func _offer_card() -> void:
	var lines := [[tr("CASH %s") % Hud._money(economy.cash), "dim"]]
	var buy := []
	var free := []
	for k in run.offers.size():
		var id := str(run.offers[k])
		var p := run.catalog.perk(id)
		var lv := run.level(id) + 1
		lines.append(["%d  %s %d · %s" % [k + 1, tr(p.name), lv, tr(Catalog.KIND_NAMES[Catalog.kind(p)])], "big",
			LcdStyle.BRIGHT_TEXT if p.rarity == "common" else Phone.rarity_color(str(p.rarity))])
		lines.append([_perk_text(p, lv), "note"])
		buy.append({"id": "offer_%d" % k, "text": tr("BUY %s") % Hud._money(run.perk_price(id)), "disabled": not run.can_buy_offer(k, economy)})
		if run.held("cheat") > 0:
			free.append({"id": "offer_free_%d" % k, "text": tr("FREE %d") % (k + 1), "kind": "chrome"})
	if run.offers.is_empty():
		lines.append(tr("NOTHING MORE TODAY"))
	var rows := []
	if not buy.is_empty():
		rows.append(buy)
	if not free.is_empty():
		rows.append(free)
	var ends := [{"id": "offer_reroll", "text": tr("REROLL %s") % Hud._money(run.reroll_price()), "kind": "chrome",
			"disabled": economy.cash < run.reroll_price() or run.offerable().is_empty() or run.offers.is_empty()}]
	# LATER only while SKIP is the other way out (once something is bought, DONE is the same).
	if run.can_skip_offers():
		ends.append({"id": "offer_later", "text": tr("LATER"), "kind": "chrome"})
	ends.append({"id": "offer_done", "text": tr("SKIP FOR AN ITEM") if run.can_skip_offers() else tr("DONE")})
	rows.append(ends)
	rows.append([{"id": "phone", "text": tr("PHONE"), "kind": "chrome"}])
	run_card.show_card(tr("PERK OFFERS"), lines, rows)


## The layer was paid: a new venue, a new machine at the new stake, a clean table.
func _next_layer() -> void:
	_switching = true
	_clear_table()
	machine = _run_machine()
	await _apply_stage()
	_switching = false
	open_machine()
	hud.set_status("READY")


## Shows the card the run calls for, or none while the player is at the machine:
## a story beat first, then the settlement of a finished run, the day's choice, the
## shift just worked, or the LEAVE card.
func _show_run_card() -> void:
	if _trashing:
		_trash_card()
		return
	if run == null:
		run_card.hide_card()
		return
	if _picking >= 0 and run.playing():
		_pick_card()
		return
	if _sealing and run.playing():
		_seal_card()
		return
	if _pushing and run.playing() and run.can_push(economy):
		_push_card()
		return
	_pushing = false
	var due := Hud._money(run.due())
	var cash := Hud._money(economy.cash + economy.credit)
	var day_line := tr("LAYER %d · DAY %d OF %d") % [run.layer + 1, run.day, run.days()]
	var ok := [[{"id": "ok", "text": tr("OK")}]]
	if run.story == "intro":
		run_card.show_card(tr("BAD NEWS"), [[tr("STORY INTRO") % [due, run.days()], "story"]], ok)
		return
	if run.story == "twist":
		var text := tr("STORY TWIST 1") if run.layer == 1 else tr("STORY TWIST 2")
		run_card.show_card(tr("ABOUT THE INTEREST"), [[text % [due, run.days()], "story"]], ok)
		return
	if run.story == "ending":
		run_card.show_card(tr("DEBT CLEARED"), [[tr("STORY ENDING"), "story"]], ok)
		return
	if run.story == "failed":
		run_card.show_card(tr("TIME IS UP"), [[tr("STORY FAILED"), "story"]], ok)
		return
	if not run.playing():
		var s: Dictionary = run.stats
		run_card.show_card(tr("DEBT CLEARED") if run.status == RunState.CLEARED else tr("RUN OVER"), [
			[tr("LAYERS PAID %d OF %d") % [s.layers_cleared, run.config.layers.size()], "big"],
			tr("DAYS %d") % s.days,
			tr("SHIFTS WORKED %d") % s.shifts,
			tr("TICKETS BOUGHT %s") % Hud._num(s.tickets),
			tr("BORROWED %s") % Hud._money(s.borrowed),
			tr("PERKS BOUGHT %d") % s.perks,
			tr("DAYS SPARED %d") % s.days_spared,
		], [[{"id": "new_run", "text": tr("NEW RUN")}, {"id": "free", "text": tr("FREE PLAY"), "kind": "chrome"}]])
		return
	if run.offers_open and run.today == "":
		_offer_card()
		return
	var money_row := [
		{"id": "pay", "text": tr("PAY %s") % due, "kind": "chrome", "disabled": not run.can_pay(economy)},
		{"id": "phone", "text": tr("PHONE"), "kind": "chrome"},
	]
	var last := [[tr("LAST DAY: PAY OR IT IS OVER"), "big"]] if run.last_day() else []
	var line := [[tr("HOUSE LINE %s LEFT") % Hud._money(run.loan_left()), "dim"]]
	# Unopened tickets wait for the next day of the layer; paying, or the end of the
	# layer's last day, throws them away.
	var held := _unopened()
	var kept := []
	if held > 0:
		if run.last_day() and run.today != "":
			kept = [[tr("%d UNOPENED TICKETS WILL BE THROWN AWAY") % held, "big"]]
		else:
			kept = [tr("%d UNOPENED TICKETS KEPT FOR TOMORROW") % held if _leaving else tr("%d UNOPENED TICKETS ON THE TABLE") % held]
			if run.can_pay(economy):
				kept.append([tr("PAYING NOW THROWS THEM AWAY"), "dim"])
	# On the last day there is no next day: the key ends it, paid or over.
	var next_text := tr("END THE DAY") if run.last_day() else tr("NEXT DAY")
	if run.today == "":
		run_card.show_card(day_line, [[tr("DUE %s") % due, "big"], tr("CASH %s") % cash,
			tr("WAGE TODAY %s") % Hud._money(run.shift_wage())] + kept + last + line,
			[[{"id": "play", "text": tr("PLAY")}, {"id": "work", "text": tr("WORK"), "disabled": not run.can_work()}], money_row])
	elif run.today == "work" and not _moonlight:
		# MOONLIGHTING: the machine after the shift, tickets for tomorrow (as many as the
		# money buys); the wage was cut for it.
		var day_row := [{"id": "next", "text": next_text}]
		var cut := []
		if run.effect("wage_cut") > 0:
			day_row.append({"id": "machine", "text": tr("TO THE MACHINE"), "kind": "chrome"})
			cut = [[tr("MOONLIGHTING: THE WAGE -%d%%") % run.effect("wage_cut"), "dim"]]
		run_card.show_card(tr("SHIFT DONE"), [[tr("WAGE +%s") % Hud._money(run.last_wage() * (2 if run.overtime else 1)), "big"]] + cut + [
			tr("CASH %s") % cash, tr("DUE %s") % due, [day_line, "dim"]] + kept + last + line,
			[day_row, money_row])
	elif _leaving:
		var spent: int = economy.spent - int(_day.get("spent", economy.spent))
		var won: int = economy.won - int(_day.get("won", economy.won))
		# HOUSE ACCOUNT: what is on the tab is settled as the day ends.
		var tab := [[tr("ON THE TAB %s") % Hud._money(economy.tab), "big"], [tr("THE TAB IS SETTLED WHEN YOU LEAVE"), "dim"]] \
			if economy.tab != 0 else []
		# ALL IN: a stake waiting on a window does not cross the day.
		if run.push_stake > 0:
			tab.append([tr("THE STAKE ON ALL IN (%s) IS LOST") % Hud._money(run.push_stake), "big"])
		run_card.show_card(tr("LEAVE FOR TODAY?"), [[day_line, "dim"], tr("SPENT TODAY %s") % Hud._money(spent),
			tr("WON TODAY %s") % Hud._money(won), tr("CASH %s") % cash, [tr("DUE %s") % due, "big"]] + tab + kept + last + line,
			[[{"id": "next", "text": next_text}, {"id": "back", "text": tr("BACK"), "kind": "chrome"}], money_row])
	else:
		run_card.hide_card()


# --- the tray and the trash can ---------------------------------------------------------

## The ticket in hand goes back into the tray, at the bottom (G, after M9): only one
## that is untouched (what TableNav lets go back when leaving for the machine). The next
## ticket is dealt, if there is another.
func put_back() -> bool:
	if flow.state != TicketFlow.State.FRONT and flow.state != TicketFlow.State.BACK:
		return false
	if TableNav.leave(flow.hand(), flow.has_band(), view.band_on, view.any_torn(), false) != TableNav.Action.RETURN_THEN_GO:
		hud.set_status("ALREADY TORN")
		return false
	var entry := current
	current = {}
	tray.put_last(entry)
	flow.send_away(table_tray.global_position + Vector3(0, 0.3, 0), tray.size() > 1)
	hud.set_status("BACK IN THE TRAY")
	return true


## The trash can was clicked: an opened ticket in hand just goes on its pile; with
## unopened tickets (in hand or in the tray) a card asks first.
func click_trash() -> void:
	if flow.state == TicketFlow.State.REVEALED:
		flow.collect()
		return
	if _trash_hand().is_empty() and tray.is_empty():
		hud.set_status("NOTHING TO THROW AWAY")
		return
	Sfx.play("button")
	_trashing = true
	_show_run_card()


## The ticket in hand when it can go in the trash (dealt and not opened), or {}.
func _trash_hand() -> Dictionary:
	var still := flow.state == TicketFlow.State.FRONT or flow.state == TicketFlow.State.BACK
	return current if still and flow.hand() != TableNav.Hand.OPENED else {}


func _trash_card() -> void:
	var hand := not _trash_hand().is_empty()
	var total := tray.size() + (1 if hand else 0)
	var lines := []
	if hand:
		lines.append(tr("THE TICKET IN HAND"))
	if not tray.is_empty():
		lines.append(tr("%d UNOPENED TICKETS IN THE TRAY") % tray.size())
	if run != null and run.refund_pct() > 0:
		lines.append([tr("RETURNS: %d%% OF THE PRICE BACK") % run.refund_pct(), "dim"])
	else:
		lines.append([tr("PAID FOR, NEVER OPENED, WHATEVER THEY HOLD"), "dim"])
	var keys := []
	if hand:
		keys.append({"id": "trash_one", "text": tr("THIS ONE")})
	keys.append({"id": "trash_all", "text": tr("ALL %d") % total})
	run_card.show_card(tr("THROW AWAY?"), lines, [keys, [{"id": "trash_back", "text": tr("BACK"), "kind": "chrome"}]])


func _on_trash(id: String) -> void:
	_trashing = false
	Sfx.play("button")
	var hand := _trash_hand()
	var n := 0
	var gone := []
	match id:
		"trash_one":
			if not hand.is_empty():
				gone.append(current)
				current = {}
				flow.send_away(trash_can.mouth(), not tray.is_empty())
				n = 1
		"trash_all":
			n = tray.size()
			gone = tray.items.duplicate()
			tray.clear()
			if not hand.is_empty():
				gone.append(current)
				current = {}
				flow.send_away(trash_can.mouth(), false)
				n += 1
	if n > 0:
		if run != null:
			run.stats.discarded += n
			# RETURNS: an untorn ticket in the trash goes back to the machine for its share.
			var back := run.refund_tickets(economy, gone, run.refund_pct()) if run.refund_pct() > 0 else 0
			if back > 0:
				hud.set_status("THROWN AWAY · $%d BACK", [back])
				hud.set_cash(economy.cash)
			else:
				hud.set_status("THROWN AWAY")
		else:
			hud.set_status("THROWN AWAY")
		_store_session()
	if run != null:
		_show_run_card()
	else:
		run_card.hide_card()


# --- the phone ----------------------------------------------------------------------

## The PHONE key, P, the phone on the table, the run card's PHONE key.
func open_phone(app := "home") -> void:
	if menu.visible or _switching or not _ready_done or phone.visible:
		return
	Sfx.play("button")
	aim = ""
	phone.open(phone_state(), app)


## What the phone shows, translated: the status bar, LOAN, and in the run the perk tree,
## the items and the contacts.
func phone_state() -> Dictionary:
	var m := Hud._money
	var st := {"run": run != null, "cash": m.call(economy.cash)}
	if run == null:
		st.status = tr("FREE PLAY")
		st.headline = m.call(economy.cash)
		st.subline = tr("CASH")
		st.loan = {"left": m.call(economy.loan_left()), "button": tr("LOAN %s") % m.call(Economy.LOAN),
			"ok": economy.loan_available(), "lines": [tr("ONE PRESS LENDS %s") % m.call(Economy.LOAN)]}
		return st
	st.status = tr("DAY %d/%d") % [run.day, run.days()]
	st.headline = tr("DUE %s") % m.call(run.due())
	st.subline = tr("LAYER %d · DAY %d OF %d") % [run.layer + 1, run.day, run.days()]
	st.loan = {"left": m.call(run.loan_left()), "button": tr("LOAN %s") % m.call(run.loan_step()), "ok": run.can_borrow(),
		"lines": [tr("ONE PRESS LENDS %s") % m.call(run.loan_step()),
			tr("INTEREST %d%% A DAY ON WHAT IS OWED") % run.interest(),
			tr("BORROWED %s") % m.call(run.borrowed), tr("DUE %s") % m.call(run.due())]}
	# SHELF: every shelf perk, then the dealt perks held (the build so far).
	var shelf_perks := []
	for id in run.shelf_perks():
		shelf_perks.append(_perk_state(run.catalog.perk(id)))
	st.shelf_perks = shelf_perks
	var build := []
	for p in run.catalog.dealt():
		var lv := run.level(p.id)
		if lv > 0:
			build.append({"id": p.id, "name": tr(p.name), "rarity_id": p.rarity,
				"kind": tr(Catalog.KIND_NAMES[Catalog.kind(p)]),
				"lines": [[tr("LEVEL %d OF %d") % [lv, p.levels.size()]], _perk_text(p, lv)]})
	st.build = build
	st.build_line = tr("YOUR BUILD")
	# TODAY: the day's offers (as on the morning's card), buyable until the day ends.
	var offers := []
	for k in run.offers.size():
		var p := run.catalog.perk(str(run.offers[k]))
		var lv := run.level(p.id) + 1
		offers.append({"k": k, "name": "%s %d" % [tr(p.name), lv], "kind": tr(Catalog.KIND_NAMES[Catalog.kind(p)]),
			"rarity_id": p.rarity, "desc": _perk_text(p, lv), "buy_text": tr("BUY %s") % m.call(run.perk_price(p.id)),
			"can_buy": run.can_buy_offer(k, economy), "free_text": tr("FREE") if run.held("cheat") > 0 else ""})
	st.offers = offers
	st.offers_line = tr("PERK OFFERS") if not offers.is_empty() else tr("NOTHING MORE TODAY")
	if run.playing() and not offers.is_empty():
		st.reroll_offers = {"text": tr("REROLL %s") % m.call(run.reroll_price()),
			"ok": economy.cash >= run.reroll_price() and not run.offerable().is_empty()}
	if run.can_skip_offers():
		st.skip_offers = {"text": tr("SKIP FOR AN ITEM"), "ok": true}
	st.merge(items_state())
	var shelf := []
	for id in run.shelf:
		var it := run.catalog.item(id)
		shelf.append({"id": id, "name": tr(it.name), "kind": tr(str(it.rarity).to_upper()), "rarity_id": it.rarity,
			"desc": _item_desc(it), "note": tr(it.kind), "buy_text": tr("BUY %s") % m.call(run.item_price(id)),
			"can_buy": run.can_buy_item(id, economy)})
	st.shelf = shelf
	st.shelf_line = tr("TODAY'S SHELF") if not shelf.is_empty() else tr("THE SHELF IS EMPTY")
	if run.playing():
		st.reroll_shelf = {"text": tr("NEW SHELF %s") % m.call(run.shelf_price()), "ok": economy.cash >= run.shelf_price()}
	var contacts := []
	for c in run.catalog.contacts:
		var line := tr(c.line)
		if line.contains("%"):
			line = line % [m.call(run.due()), run.days() - run.day + 1]
		var services := []
		for sv in c.get("services", []):
			var used := int(run.services.get(sv.id, 0)) >= int(sv.get("per_layer", 1))
			services.append({"id": sv.id, "name": tr(sv.name), "desc": tr(sv.desc), "can": run.can_buy_service(sv.id, economy),
				"button": tr("ONCE A LAYER") if used else tr("BUY %s") % m.call(run.service_price(sv.id))})
		contacts.append({"id": c.id, "name": tr(c.name), "line": line, "answers": c.get("answers", false), "services": services})
	st.contacts = contacts
	return st


## The items held, as the phone's ITEMS page and the item picker on the table both show
## them (one set of rules for USE and for why it is grey), translated: `held` (a row
## each: name, kind, what it does, HELD n, USE, whether it can be used now and when
## it can), `held_line` and `use_line`. Run only.
func items_state() -> Dictionary:
	var held := []
	for it in run.catalog.items:
		var n := run.held(it.id)
		if n > 0:
			held.append({"id": it.id, "name": tr(it.name), "kind": tr(it.kind), "rarity_id": it.rarity, "desc": _item_desc(it),
				"note": tr("HELD %d") % n, "use_text": tr("USE") if it.use == "column" or it.use == "now" else "",
				"can_use": _can_use(it), "why": _use_why(it)})
	return {"held": held, "held_line": tr("ITEMS %d OF %d") % [run.items_held(), run.item_cap()],
		"use_line": tr("USE: PICK A COLUMN AT THE MACHINE, OR FROM HERE") if not held.is_empty() else ""}


## A shelf perk on the phone's SHELF page: its level, what it does now and next, its
## price here, what it needs (the shelf is where requirements show, G), a BUY key.
func _perk_state(p: Dictionary) -> Dictionary:
	var lv := run.level(p.id)
	var top: int = p.levels.size()
	var price := run.perk_price(p.id)
	var miss := run.missing(p.id)
	var lines := [[tr("LEVEL %d OF %d") % [lv, top]]]
	if lv > 0:
		lines.append(tr("NOW: %s") % _perk_text(p, lv))
	if lv < top:
		lines.append(tr("NEXT: %s") % _perk_text(p, lv + 1))
	# HIGH ROLLER (`fixed`): a level bought is for good (G).
	if p.get("fixed", false):
		lines.append(tr("CANNOT BE UNDONE"))
	if lv < top:
		lines.append([tr("PRICE HERE %s") % Hud._money(price)])
	if not miss.is_empty():
		var names := []
		for id in miss:
			names.append("%s %d" % [tr(run.catalog.perk(id).name), miss[id]])
		lines.append([tr("NEEDS %s") % ", ".join(names)])
	var st := {"id": p.id, "name": tr(p.name), "level": lv, "max": top, "locked": not miss.is_empty(),
		"rarity": tr(str(p.rarity).to_upper()), "rarity_id": p.rarity, "lines": lines}
	if lv < top:
		st.buy = {"text": tr("BUY %s") % Hud._money(price), "ok": run.can_buy_perk(p.id, economy)}
	return st


## What a perk does at a level, in words (a risk perk's price after a dash).
func _perk_text(p: Dictionary, lv: int) -> String:
	var l: Dictionary = p.levels[lv - 1]
	var cost := " · " + tr(l.cost) if l.has("cost") else ""
	if l.has("desc"):
		return tr(l.desc) + cost
	var text := tr(p.desc)
	var v := int(l.get("show", l.value))
	if p.get("money", false):
		return text % Hud._money(v * run.stake()) + cost
	return (text % v if text.replace("%%", "").contains("%") else text.replace("%%", "%")) + cost


func _item_desc(it: Dictionary) -> String:
	var text := tr(it.desc)
	if it.id == "peek":
		return text % run.peek_n()
	if it.has("value"):
		return text % int(it.value)
	return text


## An item can be used now: one used on a column at the machine on a day of play, one
## used from the phone when its rule allows (TIP-OFF at the machine).
func _can_use(it: Dictionary) -> bool:
	if not run.playing() or run.held(it.id) <= 0:
		return false
	if it.use == "column":
		return run.today == "play" and at_machine
	if it.use == "now":
		return run.can_use_now(it.id) and (it.id != "tip" or at_machine) and (it.id != "slip" or _unopened() > 0)
	return false


## When and where an item is used (the phone says it under a held item whose USE is
## greyed or that has none; G could not tell why), translated. "" for COPIER (its rule
## is in its text).
func _use_why(it: Dictionary) -> String:
	match str(it.get("use", "")):
		"column":
			return tr("AT THE MACHINE, ON A DAY OF PLAY")
		"auto":
			return tr("WORKS BY ITSELF")
		"offer":
			return tr("USED FROM THE OFFERS CARD")
	match str(it.id):
		"tip":
			return tr("AT THE MACHINE, ON A DAY OF PLAY")
		"happy", "safety":
			return tr("ON A DAY OF PLAY")
		"overtime":
			return tr("BEFORE THE DAY IS CHOSEN, OR AFTER A SHIFT")
		"slip":
			return tr("WITH UNOPENED TICKETS ON THE TABLE")
	return ""


## A key on the phone.
func _on_phone(action: String, id: String) -> void:
	var ok := false
	match action:
		"loan":
			ok = take_loan()
		"buy_item":
			ok = run != null and run.buy_item(id, economy)
		"buy_perk":
			ok = run != null and run.buy_perk(id, economy)
			if ok:
				run.apply(machine)
				hud.set_cash(economy.cash)
		"reroll_shelf":
			ok = run != null and run.reroll_shelf(economy)
		"buy_offer", "offer_free":
			ok = run != null and run.buy_offer(int(id), economy, action == "offer_free")
			if ok:
				run.apply(machine)
				hud.set_cash(economy.cash)
		"reroll_offers":
			ok = run != null and run.reroll_offers(economy)
		"skip_offers":
			if run != null:
				var gift := run.close_offers(true)
				ok = gift != ""
				if ok:
					hud.set_status("GOT %s", [tr(run.catalog.item(gift).name)])
		"buy_service":
			ok = run != null and run.buy_service(id, economy)
		"use_item":
			use_item(id)
			return
	if ok:
		Sfx.play("toss")
	phone.show_state(phone_state())
	_store_session()


## A held item's USE key, on the phone's ITEMS page or on the item picker (one path for
## both, so an item does the same from either). A column item then waits for a column
## press at the machine (aim); TIP-OFF names the hottest column. Both put the phone and
## the picker away; the others leave them up with the new numbers.
func use_item(id: String) -> void:
	var it := run.catalog.item(id) if run != null else {}
	var ok := false
	if it.is_empty() or not _can_use(it):
		pass
	elif it.use == "column":
		aim = id
		machine.armed = false
		machine.change_armed = false
		_put_items_away()
		return
	else:
		var got := run.use_now(id, machine, economy)
		ok = not got.is_empty()
		match id:
			"slip":
				if ok:
					# Every unopened ticket on the table goes back for its full price.
					var gone := tray.items.duplicate()
					tray.clear()
					var hand := _trash_hand()
					if not hand.is_empty():
						gone.append(current)
						current = {}
						flow.send_away(trash_can.mouth(), false)
					var back := run.refund_tickets(economy, gone, 100)
					hud.set_cash(economy.cash)
					hud.set_status("RETURNED %d · $%d BACK", [gone.size(), back])
			"overtime":
				hud.set_status("OVERTIME ON")
			"tip":
				if ok:
					var col := columns.find(int(got.column))
					_put_items_away()
					say("HOTTEST: COLUMN %d", [col + 1], 4.0)
					_info_column = col
					_info_until = _time + 4.0
					Sfx.play("toss")
					_store_session()
					return
			"happy":
				hud.set_status("HAPPY HOUR")
			"safety":
				hud.set_status("SAFETY NET ON")
			"copy":
				if ok:
					hud.set_status("COPIED %s", [tr(run.catalog.item(got.copied).name)])
	if ok:
		Sfx.play("toss")
	phone.show_state(phone_state())
	_show_items_state()
	_store_session()


func _put_items_away() -> void:
	phone.close()
	item_picker.close()


func _on_phone_closed() -> void:
	if run_card.visible:
		_show_run_card()


# --- the item tray and its picker -----------------------------------------------------

## The item tray on the table was clicked: the picker of the items held (run only).
func open_items() -> void:
	if run == null or menu.visible or _switching or not _ready_done or item_picker.visible or phone.visible \
			or run_card.visible:
		return
	Sfx.play("button")
	aim = ""
	item_picker.open(items_state())


## A key on the item picker: USE goes the phone's way.
func _on_picker(action: String, id: String) -> void:
	if action == "use_item":
		use_item(id)


func _show_items_state() -> void:
	if run != null:
		item_picker.show_state(items_state())


## An item's token in the tray was clicked (M9.7, G: no USE key needed): that item is
## used as USE on the phone or the picker uses it (use_item). A column item takes the
## player to the machine (as clicking the machine does: TableNav) with it aimed, so the
## next column press there is it; column items still act at the machine, the token only
## walks the player there. One that cannot be used now does nothing but say why on the
## status line.
func use_token(id: String) -> void:
	if run == null or at_machine or _covered():
		return
	var it := run.catalog.item(id)
	if it.is_empty():
		return
	if not _token_can(it):
		var why := _token_why(it)
		if why == "" and it.use != "column":
			why = tr(it.desc)   # COPIER: its rule is in its text
		if why != "":
			hud.set_status(why)
		return
	if it.use != "column":
		use_item(id)
		return
	Sfx.play("button")
	_leave_table(true)
	aim = id
	machine.armed = false
	machine.change_armed = false


## A token can be used now: as USE on the phone, except that a column item needs no
## standing at the machine (the token takes the player there), only a day of play and
## a way to leave the table (not with a ticket half torn in hand, or one on its way).
func _token_can(it: Dictionary) -> bool:
	if it.use != "column":
		return _can_use(it)
	return run.playing() and run.held(it.id) > 0 and run.today == "play" \
		and TableNav.leave(flow.hand(), flow.has_band(), view.band_on, view.any_torn(), true) != TableNav.Action.STAY


## Why a token cannot be used now, translated: the phone's reason, or, for a
## column item on a day of play, ALREADY TORN (the ticket in hand keeps the player at
## the table, as it keeps it out of the tray); "" while the ticket is on its way.
func _token_why(it: Dictionary) -> String:
	if it.use == "column" and run.playing() and run.held(it.id) > 0 and run.today == "play":
		return "" if flow.hand() == TableNav.Hand.MOVING else tr("ALREADY TORN")
	return _use_why(it)


## The tip beside the pointer over a token: the item's name, then what it does and,
## when it cannot be used now, why (the phone's reason), translated. {} for none.
func item_tip(id: String) -> Dictionary:
	if run == null or id == "" or run.held(id) <= 0:
		return {}
	var it := run.catalog.item(id)
	var lines := [_item_desc(it)]
	if not _token_can(it):
		var why := _token_why(it)
		if why != "":
			lines.append(why)
	return {"name": tr(it.name), "text": "\n".join(lines)}


## Shows the tip for the token under the pointer (hover_item) beside `at`, or hides it;
## at (-1, -1) keeps it where it is (a new text only).
func show_item_tip(at := Vector2(-1, -1)) -> void:
	var tip := item_tip(hover_item)
	hud.set_tip(str(tip.get("name", "")), str(tip.get("text", "")), at)


## What lies in the item tray: a token for each item held, in the catalogue's order.
func item_tokens() -> Array:
	var out := []
	if run != null:
		for it in run.catalog.items:
			for n in run.held(it.id):
				out.append({"id": it.id, "kind": it.kind, "rarity": it.rarity})
	return out


# --- menu and settings --------------------------------------------------------------

func toggle_menu() -> void:
	if menu.visible:
		menu.close()
	else:
		menu.open(Save.settings, rooms.id, Lang.current, mode)


func _menu_state() -> void:
	if menu.visible:
		menu.show_state(Save.settings, rooms.id, Lang.current, mode)


## The menu's table keys: free play only; in the run the table is the layer's.
func pick_room(room_id: String) -> void:
	if run == null:
		set_room(room_id)
	_menu_state()


func set_master(linear: float) -> void:
	Save.set_setting("master", clampf(linear, 0.0, 1.0))
	Sfx.apply_settings(Save.settings)


func toggle_mute() -> void:
	Save.set_setting("muted", not bool(Save.setting("muted")))
	Sfx.apply_settings(Save.settings)
	_menu_state()


func toggle_fullscreen() -> void:
	Save.set_setting("fullscreen", not bool(Save.setting("fullscreen")))
	_apply_window()
	_menu_state()


## Setting: tickets come to the hand back side up. Takes hold from the next deal.
func toggle_back_first() -> void:
	Save.set_setting("back_first", not bool(Save.setting("back_first")))
	flow.back_first = bool(Save.setting("back_first"))
	_menu_state()


## Setting: one click opens the whole ticket (TicketFlow.open_all). Takes hold at once.
func toggle_one_click() -> void:
	Save.set_setting("one_click", not bool(Save.setting("one_click")))
	flow.one_click = bool(Save.setting("one_click"))
	_menu_state()


## Setting: a ticket goes to its pile by itself once revealed (a winner after a longer
## look). Takes hold at once.
func toggle_auto_wins() -> void:
	Save.set_setting("auto_wins", not bool(Save.setting("auto_wins")))
	flow.auto_wins = bool(Save.setting("auto_wins"))
	_menu_state()


func set_language(code: String) -> void:
	Save.set_setting("language", code)
	Lang.set_language(code)
	_menu_state()
	if run_card.visible:
		_show_run_card()
	if phone.visible:
		phone.show_state(phone_state())
	_show_items_state()


func quit_game() -> void:
	save_now()
	get_tree().quit()


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var full := bool(Save.setting("fullscreen"))
	var mode := DisplayServer.window_get_mode()
	if full and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not full and mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


# --- saving ---------------------------------------------------------------------

## The session as SessionState keeps it: a ticket in hand that is not revealed goes
## back to the tray, a revealed one counts on the pile it is bound for.
func capture_session() -> Dictionary:
	var hand := {}
	var landing := ""
	var landing_win := ""
	match flow.state:
		TicketFlow.State.REVEALED, TicketFlow.State.TOSS:
			if flow.ticket.prize > 0:
				landing_win = win_pile.face_id(flow.form, flow.entry)
			else:
				landing = flow.form.uid()
		TicketFlow.State.DEAL, TicketFlow.State.FRONT, TicketFlow.State.FLIP, TicketFlow.State.BACK:
			hand = current
		TicketFlow.State.IDLE:
			if flow.dealing():
				hand = current
	var piles := pile.to_dict(landing)
	piles["wins"] = win_pile.to_dict(landing_win)
	return SessionState.capture(economy, machine, tray, hand, piles)


## Puts the table and the money in the save slot of the mode in play.
func _store_session() -> void:
	if not use_save or _switching:
		return
	if run != null:
		Save.set_run({"state": run.to_dict(), "session": capture_session(), "day": _day})
	else:
		Save.set_session(capture_session())


func save_now() -> void:
	if not use_save or not _ready_done:
		return
	_store_session()
	Save.flush()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()
	elif what == NOTIFICATION_PREDELETE:
		# Parts never added (run-tool, missing data). Its own parts only.
		Orphans.free_members(self, ["painter", "rooms", "machine_light", "camera", "view", "flecks", "flow",
			"table_tray", "pile", "win_pile", "machine_view", "hud", "notepad", "input", "menu", "run_card",
			"phone", "table_phone", "trash_can", "item_tray", "item_picker"])



## False if the saved money does not add up (nothing is restored then).
func _restore_session(d: Dictionary) -> bool:
	if not SessionState.restore(d, economy, machine, tray, _form_for):
		push_warning("Save: the saved session does not add up; starting a new one")
		return false
	var p = d.get("pile", {})
	if typeof(p) == TYPE_DICTIONARY:
		await pile.from_dict(p)
		var w = p.get("wins", {})
		await win_pile.from_dict(w if typeof(w) == TYPE_DICTIONARY else {})
	return true


## A form of the machine in play (at the stage's stake) by its id.
func _form_for(uid: String) -> FormDef:
	if machine != null:
		for f in machine.forms:
			if f.uid() == uid:
				return f
	if run != null:
		# A form of the layer not on the machine now (PICKY put another in its column).
		for f in run.stage_forms(_room_forms(run.scene())):
			if f.uid() == uid:
				return f
	return null


## A ticket by its form, its box's seed and its number, for the winners' pile (which
## shows each ticket's inside): from the machine's boxes, or a box built again from its
## seed (one that was changed for a new one, or a save's).
var _old_boxes := {}

func _ticket_for(uid: String, seed_text: String, no: int) -> Dictionary:
	var form := _form_for(uid)
	if form == null or seed_text == "":
		return {}
	var box: TicketBox = null
	for b in machine.boxes:
		if b.form == form and b.seed == seed_text:
			box = b
	if box == null:
		var key := "%s|%s" % [form.art_key(), seed_text]
		if not _old_boxes.has(key):
			_old_boxes[key] = BoxGenerator.build(form, seed_text, machine.model)
		box = _old_boxes[key]
	return box.tickets[no - 1] if no >= 1 and no <= box.size else {}


# --- developer panel --------------------------------------------------------------

## Red button brightness step (0 brightest .. LAMP_STEPS-1 most muted).
func set_lamp(step: int) -> void:
	MachineView.lamp_preset = clampi(step, 0, MachineView.LAMP_STEPS - 1)
	machine_view.apply_lamp()
	Save.set_setting("lamp", MachineView.lamp_preset)


## A free ticket of machine column `i` (web build's bench): an untouched ticket in hand
## goes back to the tray first; the free one is dealt at the table. Not counted as spent.
func dev_free_ticket(i: int) -> void:
	if flow.has_ticket() and TableNav.leave(flow.hand(), flow.has_band(), view.band_on, view.any_torn(), false) == TableNav.Action.RETURN_THEN_GO:
		flow.cancel()
		tray.put_back(current)
		current = {}
	if flow.state != TicketFlow.State.IDLE or flow.dealing() or machine.busy() or economy.bill > 0 or machine.stock_left(i) <= 0:
		return
	var box: TicketBox = machine.boxes[i]
	var t: Dictionary = box.tickets[box.cursor]
	box.cursor += 1
	tray.put_back({"form": machine.forms[i], "ticket": t, "box": box})
	close_machine()
	flow.deal()


## Replaces column `i`'s box with a new one from `seed_text`, fully loaded.
func dev_new_box(i: int, seed_text: String) -> void:
	machine.boxes[i] = BoxGenerator.build(machine.forms[i], seed_text, machine.model)
	machine.loaded[i] = machine.boxes[i].size


## Clears the table and the money: tray, pile, hand, ledger. The boxes stay as they are.
func dev_reset() -> void:
	if run != null:
		new_run()   # in the run, the money belongs to the run: start it over
		return
	flow.cancel()
	current = {}
	_go_machine = false
	tray.clear()
	pile.clear()
	win_pile.clear()
	economy = Economy.new()
	machine.queue.clear()
	machine.armed = false
	machine.return_at = 0.0
	Sfx.motor(false)
	machine_view.show_bill(0, 0.0)
	open_machine()
	hud.set_status("READY")


## Developer: "cash" adds $500 at the stage's stake (as a prize, so the ledger holds);
## in the run, "perks" takes every perk to its top level, "items" gives three of each,
## "offers" deals again, "deal" puts the dealt perk `arg` (an id) first in today's
## offers, "sure_items" gives one of each SURE item (past the pockets' room), "window"
## starts the ticket window over (the streak and a pending ALL IN with it).
func dev_run(what: String, arg := "") -> void:
	match what:
		"cash":
			economy.bonus(500 * (run.stake() if run != null else 1))
		"perks":
			# Every perk but the risk ones (their prices would close the run's doors).
			if run != null:
				for p in run.catalog.perks:
					if Catalog.kind(p) != "risk":
						run.perks[p.id] = p.levels.size()
				run.apply(machine)
		"offer_more":
			if run != null:
				run.offer_bonus += 1
				say("OFFERS %d", [run.offer_count()])
		"offers":
			if run != null and run.playing():
				run.offer_rerolls += 1
				run.offers = run.deal_offers()
				run.offers_open = not run.offers.is_empty()
				run.offer_bought = false
				_show_run_card()
		"items":
			if run != null:
				for it in run.catalog.items:
					run.items[it.id] = run.held(it.id) + 3
		"deal":
			# A dealt perk not at its top level yet: first in the offers, once.
			var p := run.catalog.perk(arg) if run != null else {}
			if p.is_empty() or Catalog.kind(p) == "shelf" or run.level(arg) >= p.levels.size() or not run.playing():
				push_warning("dev: no dealt perk to offer: %s" % arg)
			else:
				run.offers.erase(arg)
				run.offers.insert(0, arg)
				run.offers_open = true
				_show_run_card()
		"sure_items":
			if run != null:
				for it in run.catalog.items:
					if it.kind == "SURE":
						run.items[it.id] = run.held(it.id) + 1
		"window":
			if run != null:
				run.reset_window()
				_pushing = false
				_show_run_card()
	if phone.visible:
		phone.show_state(phone_state())
	_show_items_state()
	_store_session()


## Developer sound bench: a file replaces a sound slot (copied next to the save file).
func dev_sound_file(slot: String, path: String) -> void:
	var ext := path.get_extension().to_lower()
	if not Sfx.AUDIO_EXTS.has(ext):
		return
	var dir := Save.path.get_base_dir().path_join("sounds") if Save.path != "" else "user://sounds"
	DirAccess.make_dir_recursive_absolute(dir)
	for e in Sfx.AUDIO_EXTS:
		var old := dir.path_join(slot + "." + e)
		if FileAccess.file_exists(old):
			DirAccess.remove_absolute(old)
	var dst := dir.path_join(slot + "." + ext)
	if DirAccess.copy_absolute(path, dst) != OK or Sfx.load_file(dst) == null:
		push_warning("Sound file could not be used: " + path)
		DirAccess.remove_absolute(dst)
		return
	var sounds: Dictionary = Save.setting("sounds").duplicate(true)
	var d: Dictionary = sounds.get(slot, {})
	d.file = dst
	d.name = path.get_file()
	sounds[slot] = d
	Save.set_setting("sounds", sounds)
	Sfx.apply_settings(Save.settings)
	Sfx.audition(slot)


func dev_sound_clear(slot: String) -> void:
	var sounds: Dictionary = Save.setting("sounds").duplicate(true)
	var d: Dictionary = sounds.get(slot, {})
	if d.has("file") and FileAccess.file_exists(d.file):
		DirAccess.remove_absolute(d.file)
	d.erase("file")
	d.erase("name")
	if d.is_empty():
		sounds.erase(slot)
	else:
		sounds[slot] = d
	Save.set_setting("sounds", sounds)
	Sfx.apply_settings(Save.settings)


func dev_sound_volume(slot: String, linear: float) -> void:
	var sounds: Dictionary = Save.setting("sounds").duplicate(true)
	var d: Dictionary = sounds.get(slot, {})
	d.volume = clampf(linear, 0.0, 2.0)
	sounds[slot] = d
	Save.set_setting("sounds", sounds)
	Sfx.apply_settings(Save.settings)


# --- ticket flow hooks ------------------------------------------------------------

func _take_ticket() -> Dictionary:
	if tray.is_empty():
		return {}
	if run != null and not run.can_open():
		# MOONLIGHTING: bought after the shift, opened tomorrow.
		hud.set_status("OPEN THEM TOMORROW")
		return {}
	current = tray.take()
	return current


## A revealed ticket may go to its pile by itself only while nothing is over the table.
func _may_auto_collect() -> bool:
	return not _covered()


## The menu, a run card, the phone or the item picker is over the table.
func _covered() -> bool:
	return menu.visible or run_card.visible or phone.visible or item_picker.visible


func _deal_after_toss() -> bool:
	if _go_machine:
		_go_machine = false
		open_machine()
		return false
	return true


func _on_dealt(t: Dictionary, _form: FormDef) -> void:
	hud.set_status(str(t.no).pad_zeros(5))


func _on_revealed(t: Dictionary, _form: FormDef) -> void:
	# In the run every prize goes through the perks (RunState.pay_ticket): what it pays
	# over the printed prize at its bet shows as the bonus.
	var wins := economy.wins
	var paid := int(t.prize)
	var pushed := _push_counts() if run != null else []
	if run != null:
		paid = run.open_ticket(economy, current)
	else:
		economy.open_ticket(t.prize)
		if current.has("box"):
			current.box.opened = t.no
	var base := int(t.prize) * int(current.get("bet", 1))
	if economy.wins > wins:
		if base > 0 and paid != base:
			hud.set_status("WINNER $%d +$%d", [base, paid - base])
		else:
			hud.set_status("WINNER $%d", [paid])
		hud.flash_win()
	elif paid > 0:
		hud.set_status("NO WIN · $%d BACK", [paid])
	else:
		hud.set_status("NO WIN")
	if run != null:
		_after_opening(pushed)


# --- frame ----------------------------------------------------------------------

func _process(dt: float) -> void:
	if not _ready_done:
		return
	_time += dt
	var bill := economy.bill
	var ev := economy.step_bill(dt)
	if ev.get("sound", false):
		Sfx.play("bill")
	machine_view.show_bill(economy.bill if economy.bill > 0 else 0, economy.bill_t)
	if bill > 0 and economy.bill == 0:
		machine_view.show_bill(0, 0.0)
	var sale := machine.last_sale   # what a last sale in this step pays (it may grow after: SNOWBALL)
	var m := machine.step(dt, _time, economy, tray)
	Sfx.motor(m.motor)
	for s in m.sold:
		var sold: FormDef = machine.forms[s.form]
		var sold_card: Array = sold.layout.card.size
		machine_view.launch_card(pile.cached_art(sold), Vector2(sold_card[0], sold_card[1]), maxi(0, columns.find(s.form)))
	if run != null:
		var by_form := {}
		for s in m.sold:
			by_form[s.form] = int(by_form.get(s.form, 0)) + 1
		for f in by_form:
			run.count_sales(by_form[f], 0, machine.forms[f].uid())
		run.count_sales(0, m.last_sale.size())
	if not m.last_sale.is_empty():
		# The last ticket of a box: its prize is already in the cash.
		if run != null:
			for k in m.last_sale.size():
				run.cleared_box(machine)
		Sfx.play_win(sale)
		hud.set_status("LAST SALE $%d", [sale])
		hud.flash_win()
		say("LAST SALE")
	if m.stopped:
		Sfx.play("dispense_stop")
	if at_machine and machine.return_at > 0.0 and _time > machine.return_at and not tray.is_empty() \
			and (run == null or run.can_open()):
		toggle_view()
	# PLAY ALL blinks only while you stand at the machine; from the table it stays lit.
	machine_view.set_blink(not at_machine or sin(_time * 4.0) > 0.0)
	rooms.set_view(camera.cam)
	if _time - _ui_at > UI_TICK:
		_ui_at = _time
		_refresh_ui()
	if use_save and _time - _saved_at > AUTOSAVE:
		_saved_at = _time
		_store_session()
	_place_bill_window()


func _refresh_ui() -> void:
	hud.set_cash(economy.cash)
	hud.set_ledger(tray.size(), economy)
	if run != null:
		item_tray.show_items(item_tokens())
	# The token tip goes with the table: not at the machine, nor under a card or the menu;
	# its text follows what is held (a token used up takes its tip with it).
	if hover_item != "" and (at_machine or camera.cam > 0.1 or _covered()):
		hover_item = ""
	show_item_tip()
	var n := economy.net()
	var net := tr("NET %s") % (("+" if n > 0 else "-" if n < 0 else "") + Hud._money(absi(n)))
	if run != null and run.reading() >= BoxReading.BOOKS:
		notepad.show_ledger(_box_rows())
	else:
		notepad.show_ledger([
			tr("OPENED %s") % Hud._num(economy.opened),
			tr("WINS %s") % Hud._num(economy.wins),
			tr("SPENT %s") % Hud._money(economy.spent),
			tr("WON %s") % Hud._money(economy.won),
			net,
		])
	# The third line names a column: the one under the pointer, or one just pressed.
	var named := hover_column if hover_column >= 0 else _info_column if _time < _info_until else -1
	var reading := _reading_lines(named)
	var blink := sin(_time * 7.0) > -0.4
	var msg := tr(_msg) % _msg_args if not _msg_args.is_empty() else tr(_msg)
	var sub := tr("READING BILL") if economy.bill > 0 \
		else (tr("PLAYALL") if blink else "") if machine.armed \
		else (tr("NEW BOX?") if blink else "") if machine.change_armed \
		else (tr("PICK A COLUMN") if blink else "") if aim != "" \
		else msg if _time < _msg_until \
		else str(reading[0]) if not reading.is_empty() \
		else tr("SELECT A TICKET") if economy.can_buy(machine.min_price()) else tr("INSERT BILL")
	var info := ""
	if named >= 0 and named < columns.size():
		var f: FormDef = machine.forms[columns[named]]
		info = "%d %s $%d" % [named + 1, f.name.to_upper(), machine.price(columns[named])]
		# The form's tags (G: the form says what it is; the perks never name forms).
		if run != null and not f.tags.is_empty():
			info += " · " + " · ".join(f.tags.map(func(t): return tr(t)))
		# A full reading takes turns with the name on the third line.
		if reading.size() > 1 and fmod(_time, 4.0) >= 2.0:
			info = str(reading[1])
	var top := "$ %7.2f %s" % [economy.credit, tr("CREDIT")]
	if economy.tab_on and economy.tab > 0:
		# HOUSE ACCOUNT: what is on the tab, after the credit (or alone when there is none).
		var tab := tr("TAB %s") % Hud._money(economy.tab)
		top = "$ %d %s · %s" % [economy.credit, tr("CREDIT"), tab] if economy.credit > 0 else tab
	machine_view.set_lcd(top, sub, info)
	var shares := []
	for i in columns:
		shares.append(float(machine.stock_left(i)) / machine.boxes[i].size)
	machine_view.set_stock(shares)
	var next := tray.peek()
	var art: Texture2D = null
	var card := Vector2(1.4, 2.0)
	if not next.is_empty():
		art = pile.cached_art(next.form)
		var s: Array = next.form.layout.card.size
		card = Vector2(s[0], s[1])
	table_tray.set_stack(tray.size(), art, card)
	machine_view.set_trays(_machine_trays())
	var change := {}
	if run != null:
		change = {"fee": run.change_fee(), "armed": machine.change_armed,
			"ok": not machine.busy() and economy.cash >= run.change_fee()}
		var at_once := mini(run.batch_size(), _unopened())
		hud.set_open(tr("OPEN %d AT ONCE") % at_once if at_once > 0 and not at_machine and run.today == "play" else "")
		if run.playing():
			hud.set_run(tr("DUE %s · DAY %d/%d") % [Hud._money(run.due()), run.day, run.days()], _selling())
		else:
			hud.set_run(tr("DEBT CLEARED") if run.status == RunState.CLEARED else tr("RUN OVER"))
	else:
		hud.set_run("")
		hud.set_open("")
	hud.set_bill_window(at_machine and camera.cam > 0.97, economy, machine.busy(), change)


## Run: what reading a column's box tells (BoxReading), as the LCD's status line and,
## from level 3, a second line that takes turns with the name; [] without a reading.
func _reading_lines(col: int) -> Array:
	if run == null or col < 0 or col >= columns.size():
		return []
	var lv := run.reading_of(machine, columns[col])
	if lv <= 0:
		return []
	var box: TicketBox = machine.boxes[columns[col]]
	var r := BoxReading.read(box)
	var top := tr(BoxReading.top(r))
	var nature := tr(BoxReading.nature(box, machine.model))
	match lv:
		1:
			return [top]
		2:
			return [nature + " · " + top]
		3:
			return [tr(BoxReading.feel(r.heat)) + " · " + top, nature]
	return [tr("%d LEFT") % r.left + " · " + tr(BoxReading.feel(r.heat)),
		tr("TOP %d MID %d LOW %d") % [r.roles.top, r.roles.mid, r.roles.low]]


## Run, box reading at KEEP BOOKS: the notepad keeps a line for each column's box,
## tickets opened from it and the money they won.
func _box_rows() -> Array:
	var rows := [[[tr("BOX"), 0.0], [tr("OPEN"), 64.0], [tr("WON"), 140.0]]]
	for k in columns.size():
		var box: TicketBox = machine.boxes[columns[k]]
		rows.append([[str(k + 1), 0.0], [Hud._num(box.opened), 64.0], [Hud._money(int(box.summary().paid)), 140.0]])
	return rows


## What lies in the machine's two trays: the tickets held, split by the cabinet their
## column stands in, each stack showing the ticket that came out last there.
func _machine_trays() -> Array:
	var piles := [{"count": 0}, {"count": 0}]
	for item in tray.items:
		var p: Dictionary = piles[machine_view.side_of(maxi(0, columns.find(machine.forms.find(item.form))))]
		p.count += 1
		p.form = item.form
	for p in piles:
		if p.has("form"):
			var s: Array = p.form.layout.card.size
			p.art = pile.cached_art(p.form)
			p.card = Vector2(s[0], s[1])
	return piles


func _place_bill_window() -> void:
	if not hud.bill_window_visible():
		return
	var side := camera.unproject_position(machine_view.anchor("side"))
	var slot := camera.unproject_position(machine_view.anchor("slot"))
	var win := camera.unproject_position(machine_view.anchor("window"))
	hud.place_bill_window(side.x, slot.y, win.y, get_viewport().get_visible_rect().size)


# --- scene ------------------------------------------------------------------------

## Shows a room and stands its machine where that room puts it: the columns that room
## sells, at the stage's prices (built anew when either differs; that takes a few
## frames, so callers that go on to use the machine await this). `remember`: keep it as
## the player's table (free play); the run's layers set their own without that.
func set_room(room_id: String, remember := true) -> void:
	rooms.set_room(room_id)
	item_tray.set_room(room_id)
	item_tray.show_tray(run != null)
	if remember:
		Save.set_setting("room", room_id)
	_menu_state()
	columns = []
	for f in _room_forms(room_id):
		for i in machine.forms.size():
			if machine.forms[i].uid() == f.uid():
				columns.append(i)
	if columns.is_empty():
		columns = range(machine.forms.size())
	machine.armed = false
	machine.change_armed = false
	_place_machine()
	if not machine_view.shows(column_forms()):
		await machine_view.build(column_forms(), pile.art)
		_place_machine()   # its width is known now


## The machine built again when its columns changed (MOVER, PICKY).
func _refresh_machine_view() -> void:
	if not machine_view.shows(column_forms()):
		await machine_view.build(column_forms(), pile.art)
		_place_machine()


func _place_machine() -> void:
	var pos := rooms.machine_pos()
	machine_view.position = pos
	machine_view.rotation.y = rooms.machine_yaw()
	machine_light.position = pos + Vector3(-3.5, 5, 6)
	camera.set_machine(machine_view, pos, rooms.machine_yaw(), machine_view.world_width())


func _place_tray_and_pile() -> void:
	var sx := minf(5.3, camera.table_half_width() * 0.72)
	table_tray.position = Vector3(sx - 0.05, 0, 1.2)
	table_tray.rotation = Vector3(0, -0.12, 0)
	pile.position = Vector3(-sx, 0, 1.25)
	win_pile.position = WIN_PILE_AT * Vector3(sx, 1, 1)
	# The notepad lies in front of the pile, toward the player, clear of the held ticket.
	notepad.position = Vector3(-sx * 0.6, 0, 2.6)
	notepad.rotation = Vector3(0, 0.18, 0)
	# The phone lies in front of the tray, toward the player, across from the notepad.
	table_phone.position = Vector3(sx * 0.62, 0, 2.4)
	table_phone.rotation = Vector3(0, -0.32, 0)
	# The trash can stands at the near right, in front of the tray and beside the phone.
	trash_can.position = Vector3(sx * 1.0, 0, 2.8)
	item_tray.position = ITEM_TRAY_AT * Vector3(sx, 1, 1)
	item_tray.rotation = Vector3(0, ITEM_TRAY_YAW, 0)
