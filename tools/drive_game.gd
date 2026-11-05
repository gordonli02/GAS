extends Node
## Plays the game scene with synthetic input: bills, buying, PLAY ALL, the camera
## swing, opening tickets, every way of leaving the table, cash out and the loan.
## Checks the money invariant every frame and saves screenshots.
##   godot --path . --resolution 1920x1080 res://tools/drive_game.tscn -- <output dir>

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
	game = load("res://src/game/game.tscn").instantiate()
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
	print("NET %+d  opened %d  wins %d" % [e.net(), e.opened, e.wins])
	print("DRIVE %s (%d failed checks)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures > 0 else 0)


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
