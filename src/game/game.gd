class_name Game
extends Node3D
## The game: table, machine, money, tray, discard pile and the camera between them.
## The room (Diner, Bar, Bingo Hall) sets the lights and where the machine stands.
## Rules: MIGRATION.md "Money", "Machine", "Table and machine navigation", "Bill window".
## Settings and the session are kept through the Save autoload (SessionState says what
## is kept); Esc / MENU opens the player menu, backquote the developer panel (debug builds).

const SEED := "G-0001"
const FORM_UIDS := ["core:catch", "core:plate", "core:spur"]
const START_ROOM := "diner"
const MACHINE_LIGHT_ENERGY := 0.8 / 6.5
const UI_TICK := 0.09
const MESSAGE_TIME := 1.6
const AUTOSAVE := 2.0

var painter := TicketPainter.new()
var rooms := RoomSet.new()
var machine_light := OmniLight3D.new()
var camera := CameraRig.new()
var view := TicketView.new()
var flecks := Flecks.new()
var flow := TicketFlow.new()
var table_tray := TableTray.new()
var pile := DiscardPile.new()
var machine_view := MachineView.new()
var hud := Hud.new()
var notepad := Notepad.new()
var input := GameInput.new()
var menu := Menu.new()
var dev: DevPanel

## Where the save lives ("" = the platform's save folder); tools point it elsewhere.
var save_path := ""
var use_save := true

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
	add_child(pile)
	notepad.painter = painter
	add_child(notepad)
	add_child(hud)

	var forms: Array = []
	for uid in FORM_UIDS:
		forms.append(Packs.form(uid))
	if forms.has(null):
		_show_missing_data()
		return
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
	add_child(menu)
	menu.room_picked.connect(set_room)
	menu.volume_changed.connect(set_master)
	menu.mute_toggled.connect(toggle_mute)
	menu.fullscreen_toggled.connect(toggle_fullscreen)
	menu.language_picked.connect(set_language)
	menu.quit_pressed.connect(quit_game)
	if use_save and not Save.session.is_empty():
		await _restore_session(Save.session)
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
	Sfx.play("button")
	machine_view.press_button(i)
	machine.return_at = 0.0
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


func take_loan() -> void:
	if not economy.take_loan():
		return
	Sfx.play("toss")
	hud.set_status("HOUSE LOAN")


## Space / Enter.
func primary() -> void:
	if at_machine:
		if economy.credit >= 1:
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


# --- menu and settings --------------------------------------------------------------

func toggle_menu() -> void:
	if menu.visible:
		menu.close()
	else:
		menu.open(Save.settings, rooms.id, Lang.current)


func set_master(linear: float) -> void:
	Save.set_setting("master", clampf(linear, 0.0, 1.0))
	Sfx.apply_settings(Save.settings)


func toggle_mute() -> void:
	Save.set_setting("muted", not bool(Save.setting("muted")))
	Sfx.apply_settings(Save.settings)
	menu.show_state(Save.settings, rooms.id, Lang.current)


func toggle_fullscreen() -> void:
	Save.set_setting("fullscreen", not bool(Save.setting("fullscreen")))
	_apply_window()
	menu.show_state(Save.settings, rooms.id, Lang.current)


func set_language(code: String) -> void:
	Save.set_setting("language", code)
	Lang.set_language(code)
	menu.show_state(Save.settings, rooms.id, Lang.current)


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
## back to the tray, a revealed one counts on the pile.
func capture_session() -> Dictionary:
	var hand := {}
	var landing := ""
	match flow.state:
		TicketFlow.State.REVEALED, TicketFlow.State.TOSS:
			landing = flow.form.uid()
		TicketFlow.State.DEAL, TicketFlow.State.FRONT, TicketFlow.State.FLIP, TicketFlow.State.BACK:
			hand = current
		TicketFlow.State.IDLE:
			if flow.dealing():
				hand = current
	return SessionState.capture(economy, machine, tray, hand, pile.to_dict(landing))


func save_now() -> void:
	if not use_save or not _ready_done:
		return
	Save.set_session(capture_session())
	Save.flush()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()
	elif what == NOTIFICATION_PREDELETE:
		# Parts never added (run-tool, missing data). Its own parts only.
		Orphans.free_members(self, ["painter", "rooms", "machine_light", "camera", "view", "flecks", "flow",
			"table_tray", "pile", "machine_view", "hud", "notepad", "input", "menu"])



func _restore_session(d: Dictionary) -> void:
	if not SessionState.restore(d, economy, machine, tray, Packs.form):
		push_warning("Save: the saved session does not add up; starting a new one")
		return
	var p = d.get("pile", {})
	if typeof(p) == TYPE_DICTIONARY:
		await pile.from_dict(p)


# --- developer panel --------------------------------------------------------------

## Red button brightness step (0 brightest .. LAMP_STEPS-1 most muted).
func set_lamp(step: int) -> void:
	MachineView.lamp_preset = clampi(step, 0, MachineView.LAMP_STEPS - 1)
	machine_view.apply_lamp()
	Save.set_setting("lamp", MachineView.lamp_preset)


## A free ticket of machine column `i` (web build's bench): an untouched ticket in hand
## goes back to the tray first; the free one is dealt at the table. Not counted as spent.
func dev_free_ticket(i: int) -> void:
	if flow.state == TicketFlow.State.FRONT and TableNav.leave(flow.hand(), flow.has_band(), view.band_on, view.any_torn(), false) == TableNav.Action.RETURN_THEN_GO:
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
	machine.boxes[i] = BoxGenerator.build(machine.forms[i], seed_text)
	machine.loaded[i] = machine.boxes[i].size


## Clears the table and the money: tray, pile, hand, ledger. The boxes stay as they are.
func dev_reset() -> void:
	flow.cancel()
	current = {}
	_go_machine = false
	tray.clear()
	pile.clear()
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
		machine_view.launch_card()
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
		Save.set_session(capture_session())
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
		else tr(_msg) if _time < _msg_until \
		else tr("SELECT A TICKET") if economy.credit >= 1 else tr("INSERT BILL")
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
	machine_view.set_tray(tray.size(), art, card)
	hud.set_bill_window(at_machine and camera.cam > 0.97, economy, machine.busy())


func _place_bill_window() -> void:
	if not hud.bill_window_visible():
		return
	var side := camera.unproject_position(machine_view.anchor("side"))
	var slot := camera.unproject_position(machine_view.anchor("slot"))
	var win := camera.unproject_position(machine_view.anchor("window"))
	hud.place_bill_window(side.x, slot.y, win.y, get_viewport().get_visible_rect().size)


# --- scene ------------------------------------------------------------------------

## Shows a room and stands the machine where that room puts it.
func set_room(room_id: String) -> void:
	rooms.set_room(room_id)
	Save.set_setting("room", room_id)
	if menu.visible:
		menu.show_state(Save.settings, room_id, Lang.current)
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
	# The notepad lies in front of the pile, toward the player, clear of the held ticket.
	notepad.position = Vector3(-sx * 0.6, 0, 2.6)
	notepad.rotation = Vector3(0, 0.18, 0)
