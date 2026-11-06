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

const SEED := "G-0001"
const FORM_UIDS := ["core:catch", "core:plate", "core:spur"]
const START_ROOM := "diner"
const MACHINE_LIGHT_ENERGY := 0.8 / 6.5
const UI_TICK := 0.09
const MESSAGE_TIME := 1.6
const AUTOSAVE := 2.0
## The winners' pile: behind the tray, across the table from the discard pile. x as a
## share of the tray's offset from the middle; a tighter heap than the discards.
const WIN_PILE_AT := Vector3(1.03, 0, -1.8)
const WIN_PILE_SPREAD := 0.55

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
var dev: DevPanel

## Where the save lives ("" = the platform's save folder); tools point it elsewhere.
var save_path := ""
var use_save := true

var mode := "free"                 ## "free" play or the "run"
var run: RunState                  ## the run in progress; null in free play
var run_seed := ""                 ## tools: the seed of the next new run ("" picks one)
var base_forms: Array = []         ## the machine's forms as the pack wrote them (stake 1)
var economy := Economy.new()
var machine: MachineLogic
var tray := TicketTray.new()
var at_machine := true
var current: Dictionary = {}       ## tray entry of the ticket in hand
var _go_machine := false            ## after this toss, go to the machine instead of dealing
var _time := 0.0
var _ui_at := 0.0
var _msg := ""
var _msg_until := 0.0
var _ready_done := false
var _saved_at := 0.0
var _switching := false             ## a mode or a layer is being set up
var _leaving := false               ## run: the LEAVE card is up
var _card_busy := false             ## run: a card key is being carried out
var _day := {}                      ## run: the ledger when today's play began {spent, won}


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
	add_child(hud)

	var forms: Array = []
	for uid in FORM_UIDS:
		forms.append(Packs.form(uid))
	if forms.has(null):
		_show_missing_data()
		return
	base_forms = forms
	machine = MachineLogic.new(forms, SEED)
	machine_view.painter = painter
	add_child(machine_view)
	await machine_view.build(forms)
	machine_light.light_color = Color("#fff0e0")
	# Web build: PointLight(0xfff0e0, .8, 22, 1.2) with its own gentle falloff. Godot's default
	# 1/d falloff blew up into a hot spot on the diner booth, which this light stands right
	# against; no distance term here, and the energy keeps the machine face as lit as in M4
	# (0.8 at 1/d for the face's 6.5 units).
	machine_light.light_energy = MACHINE_LIGHT_ENERGY
	machine_light.omni_range = 22.0
	machine_light.omni_attenuation = 0.0
	add_child(machine_light)
	var room: String = Save.setting("room")
	set_room(room if RoomSet.ORDER.has(room) else START_ROOM)
	camera.at_machine = true
	camera.cam = 1.0

	flow.camera = camera
	flow.view = view
	flow.flecks = flecks
	flow.tray = table_tray
	flow.pile = pile
	flow.win_pile = win_pile
	flow.back_first = use_save and bool(Save.setting("back_first"))
	flow.next_ticket = _take_ticket
	flow.deal_after_toss = _deal_after_toss
	flow.dealt.connect(_on_dealt)
	flow.revealed.connect(_on_revealed)
	add_child(flow)
	input.game = self
	add_child(input)
	hud.bill_pressed.connect(insert_bill)
	hud.cash_out_pressed.connect(cash_out)
	hud.loan_pressed.connect(take_loan)
	hud.menu_pressed.connect(toggle_menu)
	hud.leave_pressed.connect(leave_day)
	hud.new_box_pressed.connect(toggle_change)
	add_child(run_card)
	run_card.picked.connect(_on_card)
	add_child(menu)
	menu.mode_picked.connect(set_mode)
	menu.new_run_pressed.connect(new_run)
	menu.room_picked.connect(pick_room)
	menu.volume_changed.connect(set_master)
	menu.mute_toggled.connect(toggle_mute)
	menu.fullscreen_toggled.connect(toggle_fullscreen)
	menu.back_first_toggled.connect(toggle_back_first)
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

## A machine button: 0-2 columns, 3 PLAY ALL. Keys 1-3 and Space press the same buttons.
func press_machine(i: int) -> void:
	if run != null and run.today != "play":
		return
	Sfx.play("button")
	machine_view.press_button(i)
	machine.return_at = 0.0
	if machine.change_armed:
		# NEW BOX is armed: a column press changes that column's box; PLAY ALL lets it go.
		if i == 3:
			machine.change_armed = false
		elif run.change_box(economy, machine, i):
			Sfx.play("toss")
			say("NEW BOX")
		else:
			machine.change_armed = false
			say("NO CASH")
		return
	var r := machine.press_play_all(economy.credit) if i == 3 else machine.press(i, economy.credit)
	if r == "insert_bill":
		say("INSERT BILL")


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


## LOAN: the house's flat line in free play; in the run, the layer's line, which goes
## on top of what is due with interest.
func take_loan() -> void:
	if not (run.borrow(economy) if run != null else economy.take_loan()):
		return
	Sfx.play("toss")
	hud.set_status("HOUSE LOAN")


## Run: the NEW BOX key (or N) arms a box change for the next column press.
func toggle_change() -> void:
	if run == null or not at_machine or camera.cam <= 0.9 or machine.busy() or run.today != "play":
		return
	Sfx.play("button")
	machine.press_change()


## Space / Enter.
func primary() -> void:
	if at_machine:
		if economy.credit >= machine.min_price():
			press_machine(3)
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


## A short message on the machine LCD's status line (a translation key).
func say(key: String) -> void:
	_msg = key
	_msg_until = _time + MESSAGE_TIME


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
		machine = run.new_machine(base_forms)
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
			machine = run.new_machine(base_forms)
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
	machine = run.new_machine(base_forms)
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
	tray.clear()
	pile.clear()
	win_pile.clear()
	_old_boxes.clear()
	Sfx.motor(false)
	machine_view.show_bill(0, 0.0)
	run_card.hide_card()


## The room and the bills of the stage in play: the layer's in the run, the player's
## table and the pack's stake in free play.
func _apply_stage() -> void:
	var room: String = run.scene() if run != null else Save.setting("room")
	set_room(room if RoomSet.ORDER.has(room) else START_ROOM, run == null)
	await machine_view.paint_bills(economy.bills)
	# The fronts of what this machine sells, painted before the first ticket flies out.
	for f in machine.forms:
		await pile.art(f)


## Run: the LEAVE key puts the LEAVE card up: the day so far, and how many tickets
## would be thrown away. Nothing is lost until the player confirms there (NEXT DAY or PAY).
func leave_day() -> void:
	if run == null or run_card.visible or run.today != "play" or _switching:
		return
	Sfx.play("button")
	machine.queue.clear()   # nothing more is sold while the card is up
	machine.armed = false
	machine.change_armed = false
	_leaving = true
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


## Run: the player leaves (G: confirmed on the LEAVE card). Tickets not opened are
## thrown away: paid for, never opened, whatever they held. An opened ticket in hand
## goes on the pile. A bill being fed lands first, so its money counts.
func _walk_out() -> void:
	var n := _unopened()
	if flow.state == TicketFlow.State.REVEALED:
		flow.collect()
	elif flow.state != TicketFlow.State.TOSS:
		flow.cancel()
		current = {}
	_go_machine = false
	tray.clear()
	run.stats.discarded += n
	if economy.bill > 0:
		economy.step_bill(Economy.BILL_TIME)
		machine_view.show_bill(0, 0.0)
	open_machine()


## A key on the run's card.
func _on_card(id: String) -> void:
	if id == "menu":
		toggle_menu()
		return
	if run == null or _card_busy or _switching:
		return
	_card_busy = true
	Sfx.play("button")
	match id:
		"ok":
			run.story = ""
		"play":
			if run.play():
				_day = {"spent": economy.spent, "won": economy.won}
		"work":
			run.work(economy)
		"loan":
			take_loan()
		"back":
			_leaving = false
		"pay":
			var layer := run.layer
			if _leaving and run.can_pay(economy):
				_walk_out()
			if run.pay(economy):
				Sfx.play_win(50)
				if run.playing() and run.layer != layer:
					await _next_layer()
		"next":
			var layer := run.layer
			if _leaving:
				_walk_out()
			run.end_day(economy)
			_leaving = false
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
	_card_busy = false
	_store_session()
	_show_run_card()


## The layer was paid: a new venue, a new machine at the new stake, a clean table.
func _next_layer() -> void:
	_switching = true
	_clear_table()
	machine = run.new_machine(base_forms)
	await _apply_stage()
	_switching = false
	open_machine()
	hud.set_status("READY")


## Shows the card the run calls for, or none while the player is at the machine:
## a story beat first, then the settlement of a finished run, the day's choice, the
## shift just worked, or the LEAVE card.
func _show_run_card() -> void:
	if run == null:
		run_card.hide_card()
		return
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
			tr("DAYS SPARED %d") % s.days_spared,
		], [[{"id": "new_run", "text": tr("NEW RUN")}, {"id": "free", "text": tr("FREE PLAY"), "kind": "chrome"}]])
		return
	var money_row := [
		{"id": "pay", "text": tr("PAY %s") % due, "kind": "chrome", "disabled": not run.can_pay(economy)},
		{"id": "loan", "text": tr("LOAN %s") % Hud._money(run.loan_step()), "kind": "chrome", "disabled": not run.can_borrow()},
	]
	var last := [[tr("LAST DAY: PAY OR IT IS OVER"), "big"]] if run.last_day() else []
	var line := [[tr("HOUSE LINE %s LEFT") % Hud._money(run.loan_left()), "dim"]]
	# On the last day there is no next day: the key ends it, paid or over.
	var next_text := tr("END THE DAY") if run.last_day() else tr("NEXT DAY")
	if run.today == "":
		run_card.show_card(day_line, [[tr("DUE %s") % due, "big"], tr("CASH %s") % cash,
			tr("WAGE TODAY %s") % Hud._money(run.wage())] + last + line,
			[[{"id": "play", "text": tr("PLAY")}, {"id": "work", "text": tr("WORK")}], money_row])
	elif run.today == "work":
		run_card.show_card(tr("SHIFT DONE"), [[tr("WAGE +%s") % Hud._money(run.last_wage()), "big"],
			tr("CASH %s") % cash, tr("DUE %s") % due, [day_line, "dim"]] + last + line,
			[[{"id": "next", "text": next_text}], money_row])
	elif _leaving:
		var spent: int = economy.spent - int(_day.get("spent", economy.spent))
		var won: int = economy.won - int(_day.get("won", economy.won))
		var held := _unopened()
		var thrown := [[tr("%d UNOPENED TICKETS WILL BE THROWN AWAY") % held, "big"]] if held > 0 else []
		run_card.show_card(tr("LEAVE FOR TODAY?"), [[day_line, "dim"], tr("SPENT TODAY %s") % Hud._money(spent),
			tr("WON TODAY %s") % Hud._money(won), tr("CASH %s") % cash, [tr("DUE %s") % due, "big"]] + thrown + last + line,
			[[{"id": "next", "text": next_text}, {"id": "back", "text": tr("BACK"), "kind": "chrome"}], money_row])
	else:
		run_card.hide_card()


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


func set_language(code: String) -> void:
	Save.set_setting("language", code)
	Lang.set_language(code)
	_menu_state()
	if run_card.visible:
		_show_run_card()


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
			"table_tray", "pile", "win_pile", "machine_view", "hud", "notepad", "input", "menu", "run_card"])



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
	current = tray.take()
	return current


func _deal_after_toss() -> bool:
	if _go_machine:
		_go_machine = false
		open_machine()
		return false
	return true


func _on_dealt(t: Dictionary, _form: FormDef) -> void:
	hud.set_status(str(t.no).pad_zeros(5))


func _on_revealed(t: Dictionary, _form: FormDef) -> void:
	economy.open_ticket(t.prize)
	if current.has("box"):
		current.box.opened = t.no
	if t.prize > 0:
		hud.set_status("WINNER $%d", [t.prize])
		hud.flash_win()
	else:
		hud.set_status("NO WIN")


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
	var m := machine.step(dt, _time, economy, tray)
	Sfx.motor(m.motor)
	for s in m.sold:
		var sold: FormDef = machine.forms[s.form]
		var sold_card: Array = sold.layout.card.size
		machine_view.launch_card(pile.cached_art(sold), Vector2(sold_card[0], sold_card[1]))
	if run != null:
		run.count_sales(m.sold.size(), m.last_sale.size())
	if not m.last_sale.is_empty():
		# The last ticket of a box: its prize is already in the cash.
		Sfx.play_win(machine.last_sale)
		hud.set_status("LAST SALE $%d", [machine.last_sale])
		hud.flash_win()
		say("LAST SALE")
	if m.stopped:
		Sfx.play("dispense_stop")
	if at_machine and machine.return_at > 0.0 and _time > machine.return_at and not tray.is_empty():
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
	var n := economy.net()
	notepad.show_ledger([
		tr("OPENED %s") % Hud._num(economy.opened),
		tr("WINS %s") % Hud._num(economy.wins),
		tr("SPENT %s") % Hud._money(economy.spent),
		tr("WON %s") % Hud._money(economy.won),
		tr("NET %s") % (("+" if n > 0 else "-" if n < 0 else "") + Hud._money(absi(n))),
	])
	var sub := tr("READING BILL") if economy.bill > 0 \
		else (tr("PLAYALL") if sin(_time * 7.0) > -0.4 else "") if machine.armed \
		else (tr("NEW BOX?") if sin(_time * 7.0) > -0.4 else "") if machine.change_armed \
		else tr(_msg) if _time < _msg_until \
		else tr("SELECT A TICKET") if economy.credit >= machine.min_price() else tr("INSERT BILL")
	machine_view.set_lcd("$ %7.2f %s" % [economy.credit, tr("CREDIT")], sub)
	var shares := []
	for i in machine.boxes.size():
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
	# The machine's tray shows the ticket that came out last, lying on top.
	var newest := tray.newest()
	if not newest.is_empty():
		art = pile.cached_art(newest.form)
		var s: Array = newest.form.layout.card.size
		card = Vector2(s[0], s[1])
	machine_view.set_tray(tray.size(), art, card)
	var loan := {"step": Economy.LOAN, "left": economy.loan_left(), "ok": economy.loan_available()}
	var change := {}
	if run != null:
		loan = {"step": run.loan_step(), "left": run.loan_left(), "ok": run.can_borrow()}
		change = {"fee": run.change_fee(), "armed": machine.change_armed,
			"ok": not machine.busy() and economy.cash >= run.change_fee()}
		if run.playing():
			hud.set_run(tr("DUE %s · DAY %d/%d") % [Hud._money(run.due()), run.day, run.days()], run.today == "play")
		else:
			hud.set_run(tr("DEBT CLEARED") if run.status == RunState.CLEARED else tr("RUN OVER"))
	else:
		hud.set_run("")
	hud.set_bill_window(at_machine and camera.cam > 0.97, economy, machine.busy(), loan, change)


func _place_bill_window() -> void:
	if not hud.bill_window_visible():
		return
	var side := camera.unproject_position(machine_view.anchor("side"))
	var slot := camera.unproject_position(machine_view.anchor("slot"))
	var win := camera.unproject_position(machine_view.anchor("window"))
	hud.place_bill_window(side.x, slot.y, win.y, get_viewport().get_visible_rect().size)


# --- scene ------------------------------------------------------------------------

## Shows a room and stands the machine where that room puts it. `remember`: keep it as
## the player's table (free play); the run's layers set their own without that.
func set_room(room_id: String, remember := true) -> void:
	rooms.set_room(room_id)
	if remember:
		Save.set_setting("room", room_id)
	_menu_state()
	var pos := rooms.machine_pos()
	machine_view.position = pos
	machine_view.rotation.y = rooms.machine_yaw()
	machine_light.position = pos + Vector3(-3.5, 5, 6)
	camera.set_machine(machine_view, pos, rooms.machine_yaw())


func _place_tray_and_pile() -> void:
	var sx := minf(5.3, camera.table_half_width() * 0.72)
	table_tray.position = Vector3(sx - 0.05, 0, 1.2)
	table_tray.rotation = Vector3(0, -0.12, 0)
	pile.position = Vector3(-sx, 0, 1.25)
	win_pile.position = WIN_PILE_AT * Vector3(sx, 1, 1)
	# The notepad lies in front of the pile, toward the player, clear of the held ticket.
	notepad.position = Vector3(-sx * 0.6, 0, 2.6)
	notepad.rotation = Vector3(0, 0.18, 0)
