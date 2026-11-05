extends Node
## Plays the game scene with synthetic input: bills, buying, PLAY ALL, the camera
## swing, opening tickets, every way of leaving the table, cash out and the loan,
## then the menu, the language switch, the developer panel and saving and reloading.
## Checks the money invariant every frame and saves screenshots. The save file goes
## to <output dir>/save/, never the player's own.
##   godot --path . --resolution 1920x1080 res://tools/drive_game.tscn -- <output dir>

const EDGE := 0.25   ## props stay this far in from the table edge

var out := ""
var game: Game
var failures := 0
var _unbalanced := 0


func _ready() -> void:
	_run.call_deferred()


func _process(_dt: float) -> void:
	if game != null and game.machine != null and not game.economy.balanced():
		_unbalanced += 1


func _run() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.make_dir_recursive_absolute(_save_path().get_base_dir())
	var start := SaveFile.SETTINGS.duplicate(true)
	start.language = "en"
	SaveFile.write(_save_path(), start, {})
	game = _new_game()
	add_child(game)
	await _wait(1.5)
	var e := game.economy
	_expect(game.at_machine and is_equal_approx(game.camera.cam, 1.0), "starts at the machine")
	_expect(game.hud.bill_window_visible(), "bill window shown in the machine view")
	await _shot("01_machine")

	# A $5 bill: cash leaves at once, credit 2.05 s later.
	_click(_button_center(game.hud._bills[0]))
	await _wait(0.6)
	_expect(e.cash == 195 and e.credit == 0 and e.bill == 5, "bill feeding: $195 cash, credit not yet")
	await _shot("02_bill_feeding")
	await _wait(1.7)
	_expect(e.credit == 5, "credit $5 after the feed")

	# Key 1 sells one Big Catch; credit left, so the camera stays.
	_key(KEY_1)
	await _wait(1.2)
	_expect(game.tray.size() == 1 and e.credit == 4 and e.spent == 1, "one ticket for $1")
	_expect(game.at_machine, "credit left: stays at the machine")

	# Space arms PLAY ALL; key 2 sells the other 4 (Hot Plate); then back to the table.
	_key(KEY_SPACE)
	await _wait(0.2)
	_expect(game.machine.armed, "Space arms PLAY ALL")
	await _shot("03_play_all_armed")
	_key(KEY_2)
	await _wait(0.15)
	await _shot("04_dispensing")
	await _wait(1.6)
	_expect(e.credit == 0 and e.spent == 5, "PLAY ALL bought what the credit allowed")
	_expect(not game.at_machine, "credit gone: back to the table 0.7 s after dispensing")
	await _wait(1.0)
	_expect(game.flow.state == TicketFlow.State.FRONT and game.flow.form.id == "catch", "first ticket dealt (purchase order)")
	await _shot("05_table")
	var steady := true
	var lit := float(MachineView.lamp().on)
	for i in 20:
		await get_tree().process_frame
		var c: Color = game.machine_view._big_mat.albedo_color
		steady = steady and is_equal_approx(c.r, lit) and is_equal_approx(c.a, 1.0)
	_expect(steady, "PLAY ALL stays lit (no blinking) in the table view")

	# Open it with Space.
	await _open_by_space()
	_expect(game.flow.state == TicketFlow.State.REVEALED and e.opened == 1, "ticket opened")
	_key(KEY_SPACE)   # toss; the next one is dealt
	await _wait(1.0)
	_expect(game.pile.opened == 1, "tossed onto the pile")
	_expect(game.flow.state == TicketFlow.State.FRONT and game.tray.size() == 3, "next ticket dealt")

	# B with an untouched ticket: it goes back to the tray.
	_key(KEY_B)
	await _wait(0.8)
	_expect(game.at_machine and game.tray.size() == 4, "B: untouched ticket back in the tray, at the machine")
	_key(KEY_B)
	await _wait(1.2)
	_expect(not game.at_machine and game.flow.state == TicketFlow.State.FRONT, "B again: back at the table, dealt")

	# Partly torn: leaving is blocked.
	_key(KEY_SPACE)   # flip
	await _wait(0.5)
	var view := game.view
	var s := view.sims[0]
	var a := Vector3(s.w * 0.9, 0.0, 0)
	_mouse_button(_screen(view.flaps[0].to_global(a)), true)
	for k in 9:
		_mouse_move(_screen(view.flaps[0].to_global(a + Vector3(-s.w * 0.06 * k, 0, 0))))
		await _wait(0.03)
	_mouse_button(_screen(view.flaps[0].to_global(a + Vector3(-s.w * 0.48, 0, 0))), false)
	await _wait(0.4)
	_expect(view.any_torn() and not view.all_settled(), "partly torn")
	_click(_machine_point())
	await _wait(0.8)
	_expect(not game.at_machine, "clicking the machine with a partly torn ticket does nothing")
	_key(KEY_B)
	await _wait(0.5)
	_expect(not game.at_machine, "B does nothing either")
	await _shot("06_partly_torn_blocked")
	# Finish it, then click the machine: discard first, then go.
	for i in 5:
		_key(KEY_SPACE)
		await _wait(0.1)
	await _wait(1.0)
	_expect(game.flow.state == TicketFlow.State.REVEALED, "finished")
	_key(KEY_B)
	await _wait(0.5)
	_expect(not game.at_machine, "B with an opened ticket does nothing (web build)")
	var piled := game.pile.opened
	_click(_machine_point())
	await _wait(1.2)
	_expect(game.pile.opened == piled + 1 and game.at_machine, "clicking the machine discards the opened ticket, then goes")

	# Clicking the room (not the machine) in the machine view returns to the table.
	_click(Vector2(120, 900))
	await _wait(1.2)
	_expect(not game.at_machine, "click off the machine: back to the table")
	# Open the rest, then the empty table.
	while not game.tray.is_empty() or game.flow.state != TicketFlow.State.IDLE:
		if game.flow.state == TicketFlow.State.IDLE:
			_key(KEY_SPACE)
			await _wait(0.6)
		await _open_by_space()
		_key(KEY_SPACE)
		await _wait(0.6)
		if game.at_machine:
			break
	_expect(e.opened == 5, "all five opened (%d)" % e.opened)
	if game.at_machine:
		_key(KEY_B)
		await _wait(1.0)
	_click(Vector2(960, 700))
	await _wait(0.6)
	_expect(not game.at_machine and game.flow.state == TicketFlow.State.IDLE, "empty tray: clicking the table does nothing")
	await _shot("07_empty_table")
	_key(KEY_SPACE)
	await _wait(1.0)
	_expect(game.at_machine, "empty tray: Space goes to the machine")

	# Cash out.
	_click(_button_center(game.hud._bills[1]))
	await _wait(2.4)
	var cash_before := e.cash
	_click(_button_center(game.hud._cash_out))
	await _wait(0.3)
	_expect(e.credit == 0 and e.cash == cash_before + 10, "CASH OUT returns all credit to cash")

	# Loan: always offered, within the limit.
	var checked := _unbalanced
	_expect(game.hud._loan.visible and not game.hud._loan.disabled, "LOAN $200 offered with cash in hand")
	await _shot("08_loan")
	var cash_now := e.cash
	_click(_button_center(game.hud._loan))
	await _wait(0.3)
	_expect(e.cash == cash_now + 200 and e.loans == 200, "loan adds $200")
	for i in 6:
		_click(_button_center(game.hud._loan))
		await _wait(0.2)
	_expect(e.loans == Economy.LOAN_LIMIT and game.hud._loan.disabled, "stops at the limit; the key greys out")
	checked = _unbalanced
	_expect(checked == 0, "cash + credit + bill = 200 + loans + won - spent on every frame (%d bad frames)" % checked)

	# Rooms: the developer panel switches them; the machine stands where each room puts it.
	for i in 3:
		var id: String = RoomSet.ORDER[i]
		await _dev_click(game.dev._rooms[id])
		await _wait(0.4)
		_expect(game.rooms.id == id and game.machine_view.position.is_equal_approx(game.rooms.machine_pos()), "dev panel: %s, machine at its spot" % id)
		await _shot("09_room_" + id)
		_table_props_clear(id)
	# Clicks respect room props: from the table, a point where a prop covers the machine
	# does not go to the machine.
	await _dev_click(game.dev._rooms["diner"])
	_key(KEY_B)
	await _wait(1.0)
	_expect(not game.at_machine, "at the table in the diner")
	var covered := []
	for y in range(40, 1080, 16):
		for x in range(40, 1920, 16):
			if not game.input._pick(Vector2(x, y)).has_meta("machine"):
				covered.append(Vector2(x, y))
	game.rooms._set_colliders("")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var behind := Vector2(-1, -1)
	for p in covered:
		if game.input._pick(p).has_meta("machine"):
			behind = p
			break
	game.rooms._set_colliders("diner")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(behind.x >= 0, "found a spot where a prop covers the machine (%s)" % behind)
	if behind.x >= 0:
		_click(behind)
		await _wait(0.8)
		_expect(not game.at_machine, "clicking a prop in front of the machine stays at the table")
		_click(_machine_point())
		await _wait(0.8)
		_expect(game.at_machine, "clicking the machine itself still goes")
	checked = _unbalanced
	_expect(checked == 0, "money invariant held through the room changes (%d bad frames)" % checked)

	# Developer lamp steps for the red buttons; repainted live and remembered.
	_expect(MachineView.lamp_preset == 0, "buttons start at the brightest lamp step")
	var face_tex := game.machine_view._big_mat.albedo_texture
	await _dev_click(game.dev._lamps[1])
	await _wait(0.1)
	_expect(MachineView.lamp_preset == 1 and game.machine_view._big_mat.albedo_texture != face_tex
		and is_equal_approx(game.machine_view._sides[0].albedo_color.r, MachineView.lamp(1).side.r)
		and Save.setting("lamp") == 1, "dev panel: lamp step 2 dims the buttons")
	await _dev_click(game.dev._lamps[0])
	await _wait(0.1)
	_expect(MachineView.lamp_preset == 0, "dev panel: back to the brightest")
	await _milestone_6()
	e = game.economy
	print("NET %+d  opened %d  wins %d" % [e.net(), e.opened, e.wins])
	print("DRIVE %s (%d failed checks)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures > 0 else 0)


## Milestone 6: the menu, the language switch, the developer panel, saving and reloading.
func _milestone_6() -> void:
	var e := game.economy
	if not game.at_machine:
		_key(KEY_B)
		await _wait(1.0)
	# Menu: Esc opens it; keys don't reach the game; clicking outside closes it.
	_key(KEY_ESCAPE)
	await _wait(0.3)
	_expect(game.menu.visible, "Esc opens the menu")
	await _shot("10_menu")
	_key(KEY_B)
	_key(KEY_SPACE)
	await _wait(0.6)
	_expect(game.at_machine and not game.machine.armed, "B and Space do nothing while the menu is open")
	_click(Vector2(40, 1040))
	await _wait(0.2)
	_expect(not game.menu.visible, "clicking outside the menu closes it")
	_click(_button_center(game.hud.menu_key))
	await _wait(0.2)
	_expect(game.menu.visible, "the MENU key opens it")
	_key(KEY_ESCAPE)
	await _wait(0.2)
	_expect(not game.menu.visible, "Esc closes it again")
	_key(KEY_ESCAPE)
	await _wait(0.2)

	# Table, volume, sound, full screen: applied at once and kept in the settings.
	_click(_button_center(game.menu.key("bar")))
	await _wait(0.4)
	_expect(game.rooms.id == "bar" and Save.setting("room") == "bar" and game.menu.key("bar").button_pressed
		and not game.menu.key("diner").button_pressed, "menu: BAR picked, shown pressed, remembered")
	game.menu.volume_slider().value = 40
	_expect(is_equal_approx(Save.setting("master"), 0.4) and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)), 0.4), "menu: volume 40%")
	_click(_button_center(game.menu.key("sound")))
	await _wait(0.2)
	_expect(Save.setting("muted") and AudioServer.is_bus_mute(0) and game.menu.key("sound").text == "MUTED", "menu: SOUND mutes (the key reads MUTED)")
	_click(_button_center(game.menu.key("sound")))
	await _wait(0.2)
	_expect(not Save.setting("muted") and not AudioServer.is_bus_mute(0), "menu: and unmutes")
	_click(_button_center(game.menu.key("fullscreen")))
	await _wait(1.0)
	_expect(Save.setting("fullscreen") and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "menu: full screen")
	game.menu.key("fullscreen").pressed.emit()   # a click would land elsewhere if the screen is not 1080p
	await _wait(1.0)
	_expect(not Save.setting("fullscreen") and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN, "menu: back to a window")
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(0.5)

	# Language: everything the player reads switches at once.
	_click(_button_center(game.menu.key("zh")))
	await _wait(0.3)
	_expect(Lang.current == "zh" and Save.setting("language") == "zh" and tr("RESUME") == "继续", "menu: 中文")
	_expect(game.hud._status.text.begins_with("现金"), "the HUD status line follows at once (%s)" % game.hud._status.text)
	await _shot("11_menu_zh")
	_click(_button_center(game.menu.key("resume")))
	await _wait(0.5)
	_expect(not game.menu.visible, "RESUME closes the menu")
	await _shot("12_machine_zh")
	var spent := e.spent
	await _dev_click(game.dev._forms[1])
	await _wait(1.4)
	_expect(not game.at_machine and game.flow.state == TicketFlow.State.FRONT and game.flow.form.id == "plate" and e.spent == spent,
		"dev panel: a free Hot Plate, dealt at the table, not counted as spent")
	await _shot("13_table_zh")
	_key(KEY_ESCAPE)
	await _wait(0.2)
	_click(_button_center(game.menu.key("en")))
	await _wait(0.2)
	_expect(Lang.current == "en" and tr("RESUME") == "RESUME" and game.hud._status.text.begins_with("CASH"), "menu: back to English")
	_key(KEY_ESCAPE)
	await _wait(0.2)

	# Developer panel: a new box from a seed, a replaced sound, reset.
	_key(KEY_QUOTELEFT)
	await _wait(0.4)
	_expect(game.dev.visible, "backquote opens the developer panel")
	await _shot("14_dev_panel")
	game.dev._seed.text = "TEST-0007"
	game.dev._new_box()
	var col := game.dev.form_index
	var box: TicketBox = game.machine.boxes[col]
	_expect(box.seed == "TEST-0007" and box.cursor == 0 and is_equal_approx(game.machine.loaded[col], box.size), "dev panel: a new box from a seed")
	game.dev_sound_file("toss", ProjectSettings.globalize_path("res://assets/audio/sfx_pop.wav"))
	game.dev_sound_volume("toss", 1.5)
	var copied: String = Save.setting("sounds").get("toss", {}).get("file", "")
	_expect(Sfx.is_replaced("toss") and FileAccess.file_exists(copied) and is_equal_approx(Sfx.volume("toss"), 1.5), "dev panel: toss replaced by a file (copied to %s), 150%%" % copied)
	_click(_button_center(_dev_button("重置桌上的票和钱")))
	await _wait(0.8)
	e = game.economy
	_expect(e.cash == 200 and e.credit == 0 and e.spent == 0 and e.loans == 0 and game.tray.is_empty() and game.pile.opened == 0
		and game.flow.state == TicketFlow.State.IDLE and game.at_machine, "dev panel: reset clears the tickets and money, back at the machine")
	_key(KEY_QUOTELEFT)
	await _wait(0.2)
	_expect(not game.dev.visible, "backquote closes it")

	# Saving: buy 20, reveal one (in hand: paid, so the save counts it on the pile),
	# then partly tear the next one and save.
	_click(_button_center(game.hud._bills[2]))
	await _wait(2.4)
	_key(KEY_SPACE)
	await _wait(0.1)
	_key(KEY_1)
	await _wait(3.0)
	_expect(not game.at_machine and e.spent == 20 and game.tray.size() == 19, "bought 20, back at the table")
	await _open_by_space()
	_expect(game.flow.state == TicketFlow.State.REVEALED, "first one revealed")
	var snap := game.capture_session()
	_expect(snap.pile.opened == game.pile.opened + 1 and snap.tray.size() == game.tray.size(),
		"a revealed ticket in hand is saved on the pile, not in the tray")
	_key(KEY_SPACE)
	await _wait(1.2)
	_key(KEY_SPACE)
	await _wait(0.5)
	await _tear_partly()
	_expect(game.view.any_torn() and not game.view.all_settled(), "second one partly torn")
	var hand_serial: String = game.flow.ticket.serial
	var serials := [hand_serial]
	for it in game.tray.items:
		serials.append(it.ticket.serial)
	var money := e.to_dict()
	var piled := game.pile.opened
	var pile_forms := game.pile._forms.duplicate()
	var cursors := []
	for b in game.machine.boxes:
		cursors.append([b.seed, b.cursor, b.opened])
	game.save_now()
	_expect(FileAccess.file_exists(_save_path()), "saved")

	# Reload: a new game from the same file.
	game.queue_free()
	game = null
	await _wait(0.3)
	game = _new_game()
	add_child(game)
	await _wait(2.0)
	e = game.economy
	_expect(e.to_dict() == money, "reload: money and ledger as saved %s" % e.to_dict())
	var got := []
	for it in game.tray.items:
		got.append(it.ticket.serial)
	_expect(got == serials, "reload: tray in purchase order, the partly torn ticket first (%d)" % got.size())
	_expect(game.pile.opened == piled and game.pile._forms == pile_forms, "reload: the pile as it was (%d)" % piled)
	var got_boxes := []
	for b in game.machine.boxes:
		got_boxes.append([b.seed, b.cursor, b.opened])
	_expect(got_boxes == cursors, "reload: every box's seed and progress %s" % [got_boxes])
	_expect(game.rooms.id == "bar" and is_equal_approx(Save.setting("master"), 0.4) and Lang.current == "en" and MachineView.lamp_preset == 0,
		"reload: room, volume, language and lamp kept")
	_expect(Sfx.is_replaced("toss") and is_equal_approx(Sfx.volume("toss"), 1.5), "reload: the replaced sound is kept")
	game.dev_sound_clear("toss")
	_expect(not Sfx.is_replaced("toss") and not FileAccess.file_exists(copied), "dev panel: clearing the sound removes its copy")
	_expect(game.at_machine, "reload: starts at the machine")
	await _shot("15_reloaded")
	_key(KEY_SPACE)
	await _wait(1.6)
	_expect(game.flow.state == TicketFlow.State.FRONT and game.flow.ticket.serial == hand_serial and not game.view.any_torn(),
		"reload: the partly torn ticket is dealt again, untouched")
	# A bill being fed is saved as credit.
	_key(KEY_B)
	await _wait(1.0)
	_click(_button_center(game.hud._bills[0]))
	await _wait(0.5)
	var snap2 := game.capture_session()
	_expect(e.bill == 5 and snap2.economy.credit == e.credit + 5 and snap2.economy.cash == e.cash, "a bill being fed is saved as credit")
	await _wait(2.0)
	game.save_now()


func _tear_partly() -> void:
	var view := game.view
	var s := view.sims[0]
	var a := Vector3(s.w * 0.9, 0.0, 0)
	_mouse_button(_screen(view.flaps[0].to_global(a)), true)
	for k in 9:
		_mouse_move(_screen(view.flaps[0].to_global(a + Vector3(-s.w * 0.06 * k, 0, 0))))
		await _wait(0.03)
	_mouse_button(_screen(view.flaps[0].to_global(a + Vector3(-s.w * 0.48, 0, 0))), false)
	await _wait(0.4)


## Clicks a key in the developer panel (opening it first), then closes the panel.
func _dev_click(b: Button) -> void:
	if not game.dev.visible:
		_key(KEY_QUOTELEFT)
		await _wait(0.15)
	_click(_button_center(b))
	await _wait(0.15)
	_key(KEY_QUOTELEFT)
	await _wait(0.1)


func _dev_button(text: String) -> Button:
	for b: Button in game.dev.find_children("*", "Button", true, false):
		if b.text == text:
			return b
	return null


func _new_game() -> Game:
	var g: Game = load("res://src/game/game.tscn").instantiate()
	g.save_path = _save_path()
	return g


func _save_path() -> String:
	return out.path_join("save/save.json")


## Nothing standing on the table top overlaps the tray or the notepad, and nothing on
## the table comes within EDGE of its edge (G: the diner jukebox looked half off it).
## Bar: the pint and the flip phone stay apart. The discard pile is left out: a big heap
## spreads over half the table by design (web build).
func _table_props_clear(id: String) -> void:
	var top := Rect2(-7.5, -6.25, 15, 12.5)
	var table := top.grow(-EDGE)
	var keep_out := {"tray": _footprint(game.table_tray),  "notepad": _footprint(game.notepad)}
	var hits := []
	var over := []
	var g: Node3D = game.rooms.get_node(NodePath(id))
	for m: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
		var b := m.global_transform * m.get_aabb()
		if b.position.y < -0.05 or b.position.y > 1.0:
			continue   # not standing on the table top
		var f := Rect2(b.position.x, b.position.z, b.size.x, b.size.z)
		if not top.has_point(f.get_center()):
			continue   # off the table (the bar's beer tap, stools)
		if not table.encloses(f):
			over.append(str(f))
		for k in keep_out:
			if keep_out[k].intersects(f):
				hits.append("%s under the %s" % [f, k])
	_expect(hits.is_empty(), "%s: no prop under the tray or notepad %s" % [id, hits])
	_expect(over.is_empty(), "%s: props keep %.2f clear of the table edge %s" % [id, EDGE, over])
	if id == "bar":
		var phone := Rect2()
		var pint := Rect2()
		for n: Node3D in g.get_children():
			var at := Vector2(n.position.x, n.position.z)
			if at.is_equal_approx(RoomBar.PHONE):
				phone = _footprint(n)
			elif at.is_equal_approx(RoomBar.PINT):
				var b := n.global_transform * (n as MeshInstance3D).get_aabb()
				pint = Rect2(b.position.x, b.position.z, b.size.x, b.size.z) if pint.size == Vector2.ZERO else pint.merge(Rect2(b.position.x, b.position.z, b.size.x, b.size.z))
		_expect(phone.size != Vector2.ZERO and pint.size != Vector2.ZERO and not phone.intersects(pint), "bar: pint %s and phone %s apart" % [pint, phone])


## Where a node's visible meshes cover the table, seen from above (x, z).
func _footprint(n: Node) -> Rect2:
	var r := Rect2()
	for v: VisualInstance3D in n.find_children("*", "VisualInstance3D", true, false):
		if not v.is_visible_in_tree():
			continue
		var b := v.global_transform * v.get_aabb()
		var f := Rect2(b.position.x, b.position.z, b.size.x, b.size.z)
		r = f if r.size == Vector2.ZERO else r.merge(f)
	return r


func _open_by_space() -> void:
	for i in 3:
		if game.flow.state == TicketFlow.State.FRONT and game.view.band_on:
			_key(KEY_SPACE)
			await _wait(0.5)
		if game.flow.state == TicketFlow.State.FRONT:
			_key(KEY_SPACE)
			await _wait(0.5)
	for i in 6:
		if game.flow.state == TicketFlow.State.BACK:
			_key(KEY_SPACE)
			await _wait(0.12)
	await _wait(1.2)


func _machine_point() -> Vector2:
	return game.camera.unproject_position(game.machine_view.to_global(Vector3(0, 5.5, 1.7)))


func _button_center(b: Control) -> Vector2:
	return b.get_global_rect().get_center()


func _expect(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _screen(world: Vector3) -> Vector2:
	return game.camera.unproject_position(world)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))


func _key(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	Input.parse_input_event(ev)
	var u := ev.duplicate()
	u.pressed = false
	Input.parse_input_event(u)


func _click(p: Vector2) -> void:
	_mouse_button(p, true)
	_mouse_button(p, false)


func _mouse_button(p: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = p
	ev.global_position = p
	Input.parse_input_event(ev)


func _mouse_move(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	Input.parse_input_event(ev)
