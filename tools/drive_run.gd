extends Node
## Plays the story mode's run in the game scene with synthetic input: the menu's mode
## keys, the story and day cards, a day at the machine (bills, tickets, NEW BOX, LOAN,
## the last sale of a box), LEAVE, a shift of work, paying early into the next layer
## and its stake, saving and reloading mid-run, the deadline, the settlement, and a
## whole run cleared by work alone. Checks the money identity every frame and saves
## screenshots. The save file goes to <output dir>/save/, never the player's own.
##   godot --path . --resolution 1920x1080 res://tools/drive_run.tscn -- <output dir>
## Money the script needs for a step is put in through Economy.bonus (a prize), so the
## ledger stays honest.

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

	# Free play first: one ticket bought, to see later that the run left it alone.
	_expect(game.mode == "free" and game.run == null and not game.run_card.visible, "opens in free play, no card")
	_expect(not game.hud.run_key("leave").visible and not game.hud.run_key("new_box").visible, "free play: no LEAVE, no NEW BOX")
	_click(_button_center(game.hud._bills[0]))
	await _wait(2.4)
	_key(KEY_1)
	await _wait(1.0)
	_expect(game.tray.size() == 1 and game.economy.cash == 195, "free play: one ticket in the tray, $195")

	# Menu: STORY starts a run.
	_click(_button_center(game.hud.menu_key))
	await _wait(0.3)
	_expect(game.menu.key("free").button_pressed and not game.menu.key("run").button_pressed, "menu shows free play")
	_expect(not game.menu.key("new_run").visible, "no NEW RUN key in free play")
	await _shot("01_menu_modes")
	_click(_button_center(game.menu.key("run")))
	await _wait(1.0)
	_expect(game.mode == "run" and game.run != null, "STORY: the run starts")
	_expect(game.menu.key("run").button_pressed and game.menu.key("new_run").visible, "menu shows the run and NEW RUN")
	_expect(game.menu.key("bar").disabled and not game.menu.key("diner").disabled, "the table keys only show the layer's table")
	_key(KEY_ESCAPE)
	await _wait(0.3)
	var run := game.run
	var e := game.economy
	_expect(game.tray.is_empty() and e.cash == 200 and e.spent == 0, "the run has its own table and money: $200, nothing bought")
	_expect(game.run_card.visible and run.story == "intro", "the story card first")
	await _shot("02_story_intro")
	_card("ok")
	await _wait(0.3)
	_expect(run.story == "" and game.run_card.visible and run.can_choose(), "then the day's choice")
	_expect(game.run_card.key("pay").disabled and not game.run_card.key("loan").disabled, "PAY dark without the money, LOAN lit")
	await _shot("03_day_card")
	# Nothing reaches the machine behind the card.
	_key(KEY_1)
	_key(KEY_SPACE)
	await _wait(0.2)
	_expect(not game.machine.armed and not game.machine.busy(), "keys do not reach the machine behind the card")

	# A day at the machine.
	_card("play")
	await _wait(0.4)
	_expect(not game.run_card.visible and run.today == "play", "PLAY: the card goes, the day is at the machine")
	_expect(game.hud.run_key("leave").visible and game.hud.run_key("new_box").visible, "run: LEAVE and NEW BOX keys")
	await _shot("04_at_machine")
	_click(_button_center(game.hud._bills[0]))
	await _wait(2.4)
	_key(KEY_1)
	await _wait(0.8)
	_key(KEY_SPACE)
	_key(KEY_2)
	await _wait(2.4)
	_expect(game.tray.size() + (0 if game.current.is_empty() else 1) == 5 and e.spent == 5, "five tickets for $5")
	_expect(run.stats.tickets == 5, "the run counts them")
	# LEAVE with tickets to open: the card says how many would be thrown away; BACK keeps them.
	_click(_button_center(game.hud.run_key("leave")))
	await _wait(0.3)
	_expect(game.run_card.visible and game._unopened() == 5, "LEAVE with five tickets unopened: the card warns")
	await _shot("05_leave_with_tickets")
	_card("back")
	await _wait(0.3)
	_expect(not game.run_card.visible and run.day == 1 and game._unopened() == 5, "BACK: still today, the tickets are still there")
	await _open_all()
	_expect(game.tray.is_empty() and e.opened == 5, "all five opened")
	_key(KEY_SPACE)
	await _wait(1.0)
	_expect(game.at_machine, "back at the machine")

	# NEW BOX: arms, then a column press changes that column's box for the fee.
	var seed_before: String = game.machine.boxes[2].seed
	var cash := e.cash
	_click(_button_center(game.hud.run_key("new_box")))
	await _wait(0.3)
	_expect(game.machine.change_armed, "NEW BOX arms")
	await _shot("06_new_box_armed")
	_key(KEY_3)
	await _wait(0.4)
	_expect(game.machine.boxes[2].seed == MachineLogic.next_seed(seed_before) and e.cash == cash - 25, "column 3 has a new box, $25 paid")
	_expect(not game.machine.change_armed and run.stats.box_changes == 1 and game.tray.is_empty(), "disarmed, counted, no ticket sold")

	# LOAN: the layer's line, with interest on top of what is due.
	_click(_button_center(game.hud._loan))
	await _wait(0.3)
	_expect(e.cash == cash - 25 + 100 and run.due() == 1125, "LOAN $100: cash now, $125 more due")

	# The last ticket of a box pays the last sale.
	var box: TicketBox = game.machine.boxes[0]
	box.cursor = box.size - 2
	var won := e.won
	_click(_button_center(game.hud._bills[0]))
	await _wait(2.4)
	_key(KEY_1)
	await _wait(0.8)
	_expect(e.won == won, "the ticket before the last: nothing yet")
	_key(KEY_1)
	await _wait(0.8)
	_expect(e.won == won + 50 and run.stats.last_sales == 1, "the last ticket of the box: LAST SALE $50")
	await _shot("07_last_sale")
	_key(KEY_B)
	await _wait(0.8)
	await _open_all()
	_key(KEY_SPACE)
	await _wait(1.0)

	# Quit and start again mid-run.
	var before := {"cash": e.cash, "credit": e.credit, "due": run.due(), "day": run.day, "tickets": run.stats.tickets,
		"seed": game.machine.boxes[2].seed, "pile": game.piled()}
	game.save_now()
	game.free()
	game = _new_game()
	add_child(game)
	await _wait(1.5)
	run = game.run
	e = game.economy
	_expect(game.mode == "run" and run != null and run.today == "play" and not game.run_card.visible, "reload: back in the run, mid-day")
	_expect(e.cash + e.credit == before.cash + before.credit and run.due() == before.due and run.day == before.day, "money, debt and day as left")
	_expect(run.stats.tickets == before.tickets and game.machine.boxes[2].seed == before.seed and game.piled() == before.pile, "tickets counted, boxes and pile as left")
	_expect(e.balanced(), "ledger balanced after the reload")

	# LEAVE: the day's summary, then the next day.
	_click(_button_center(game.hud.run_key("leave")))
	await _wait(0.3)
	_expect(game.run_card.visible and game.run_card.key("next") != null and game.run_card.key("back") != null, "LEAVE: the card with NEXT DAY and BACK")
	await _shot("08_leave_card")
	_card("back")
	await _wait(0.3)
	_expect(not game.run_card.visible and run.day == 1, "BACK: still today")
	_click(_button_center(game.hud.run_key("leave")))
	await _wait(0.3)
	_card("next")
	await _wait(0.3)
	_expect(run.day == 2 and run.can_choose() and game.run_card.visible, "NEXT DAY: day 2, a new choice")

	# A shift of work.
	cash = e.cash
	_card("work")
	await _wait(0.3)
	_expect(e.cash == cash + 120 and run.today == "work", "WORK: $120 at once")
	_expect(game.run_card.key("play") == null and game.run_card.key("next") != null, "no tickets today, only NEXT DAY")
	await _shot("09_shift_done")
	_card("next")
	await _wait(0.3)
	_expect(run.day == 3, "day 3")

	# Chinese.
	game.set_language("zh")
	await _wait(0.3)
	await _shot("10_day_card_zh")
	game.set_language("en")
	await _wait(0.2)

	# Paying early: the next layer at once, its table, its stake.
	e.bonus(run.due())
	game._show_run_card()
	await _wait(0.2)
	_expect(not game.run_card.key("pay").disabled, "with the money, PAY lights up")
	var room_before: String = game.rooms.id
	_card("pay")
	await _wait(1.5)
	_expect(run.layer == 1 and run.day == 1 and run.story == "twist", "PAY: the second layer, day 1, the interest has compounded")
	_expect(run.stats.days_spared == 2, "two days spared")
	_expect(game.rooms.id != room_before and game.rooms.id == run.scene(), "a new table (%s)" % game.rooms.id)
	_expect(game.machine.forms[0].price == 5 and e.bills == [25, 50, 100, 250, 500], "tickets $5, bills at five times")
	_expect(game.piled() == 0 and game.tray.is_empty(), "a clean table")
	await _shot("11_story_twist")
	_card("ok")
	await _wait(0.3)
	_card("play")
	await _wait(0.5)
	await _shot("12_layer_2_machine")
	_expect(game.hud._bills[0].text == "$25", "the bill keys show the new bills")
	_click(_button_center(game.hud._bills[0]))
	await _wait(2.4)
	_expect(e.credit == 25, "a $25 bill")
	var spent := e.spent
	_key(KEY_1)
	await _wait(0.8)
	_key(KEY_B)
	await _wait(1.6)
	_expect(e.spent == spent + 5 and game.current.get("form") != null and game.current.form.price == 5, "one ticket for $5")
	await _wait(0.6)
	await _shot("13_ticket_at_stake_5")
	await _open_all()
	_key(KEY_SPACE)
	await _wait(1.0)
	_click(_button_center(game.hud._cash_out))
	await _wait(0.3)

	# The deadline: the last day ends unpaid and the run is over.
	_click(_button_center(game.hud.run_key("leave")))
	await _wait(0.3)
	_card("next")
	await _wait(0.3)
	while run.playing() and not run.last_day():
		_card("work")
		await _wait(0.2)
		_card("next")
		await _wait(0.2)
	_expect(run.playing() and run.last_day() and run.layer == 1, "the last day of the layer")
	await _shot("14_last_day")
	# The last day at the machine: five tickets bought, then LEAVE without opening them.
	e.pay(e.cash - 25)   # the rest of the money goes on something else
	_card("play")
	await _wait(0.4)
	_click(_button_center(game.hud._bills[0]))
	await _wait(2.4)
	_key(KEY_SPACE)
	_key(KEY_3)
	await _wait(1.6)
	var spent_before := e.spent
	var opened_before := e.opened
	_expect(game._unopened() == 5 and not game.at_machine, "five tickets on the table")
	_click(_button_center(game.hud.run_key("leave")))
	await _wait(0.3)
	_expect(game.run_card.visible and game.run_card.key("next") != null, "LEAVE on the last day: the card")
	await _shot("14b_leave_last_day")
	_card("next")
	await _wait(0.4)
	_expect(game.tray.is_empty() and game.current.is_empty() and run.stats.discarded == 5, "confirmed: the five tickets are thrown away")
	_expect(e.spent == spent_before and e.opened == opened_before and e.balanced(), "they stay paid for and are never opened")
	_expect(run.status == RunState.FAILED and run.story == "failed", "the last day ends unpaid: over")
	await _shot("15_story_failed")
	_card("ok")
	await _wait(0.3)
	_expect(game.run_card.key("new_run") != null and game.run_card.key("free") != null, "the settlement: NEW RUN or FREE PLAY")
	await _shot("16_settlement")
	_card("free")
	await _wait(1.2)
	_expect(game.mode == "free" and game.run == null and not game.run_card.visible, "FREE PLAY")
	_expect(game.tray.size() == 1 and game.economy.cash == 195, "free play as it was left: one ticket, $195")
	_expect(Save.run.is_empty(), "nothing of the finished run is kept")

	# A whole run by work alone, through the cards: cleared to the dollar, no ticket.
	_click(_button_center(game.hud.menu_key))
	await _wait(0.3)
	_click(_button_center(game.menu.key("run")))
	await _wait(1.0)
	_key(KEY_ESCAPE)
	await _wait(0.3)
	run = game.run
	e = game.economy
	_expect(run != null and run.layer == 0 and run.day == 1 and e.cash == 200, "a new run")
	var guard := 0
	while run.playing() and guard < 80:
		guard += 1
		if game.run_card.key("ok") != null:
			_card("ok")
		elif game.run_card.key("work") != null:
			_card("work")
		elif game.run_card.key("next") != null:
			_card("next")
		await _wait(0.25 if run.story == "" else 1.2)
	_expect(run.status == RunState.CLEARED, "work every day: cleared")
	_expect(e.cash == 0 and run.stats.tickets == 0 and run.stats.days == 18, "to the dollar, without a ticket, in 18 days")
	await _shot("17_story_ending")
	_card("ok")
	await _wait(0.3)
	await _shot("18_settlement_cleared")

	# NEW RUN on the menu asks once. The card covers the HUD's MENU key and has its own.
	_card("menu")
	await _wait(0.3)
	_expect(game.menu.visible, "the card's MENU key opens the menu")
	_click(_button_center(game.menu.key("new_run")))
	await _wait(0.2)
	_expect(game.run == run and game.menu.key("new_run").text == "SURE?", "menu NEW RUN: asks first")
	_click(_button_center(game.menu.key("new_run")))
	await _wait(1.2)
	_expect(game.run != run and game.run.playing() and game.run.story == "intro" and game.economy.cash == 200, "second press: a new run")
	_key(KEY_ESCAPE)
	await _wait(0.3)

	_expect(_unbalanced == 0, "money identity held on every frame")
	print("\nDRIVE RUN %s (%d failed checks)" % ["OK" if failures == 0 else "FAILED", failures])
	game.use_save = false
	get_tree().quit(1 if failures > 0 else 0)


## Clicks a key on the run's card.
func _card(id: String) -> void:
	var b := game.run_card.key(id)
	if b == null or not game.run_card.visible:
		_expect(false, "card key '%s' is not there" % id)
		return
	_click(_button_center(b))


## Opens every ticket in the tray with Space, from the table.
func _open_all() -> void:
	if game.at_machine and not game.tray.is_empty():
		_key(KEY_B)
		await _wait(1.0)
	var guard := 0
	while (not game.tray.is_empty() or game.flow.state != TicketFlow.State.IDLE or game.flow.dealing()) and guard < 400:
		guard += 1
		_key(KEY_SPACE)
		await _wait(0.14)
	await _wait(0.6)


func _new_game() -> Game:
	var g: Game = load("res://src/game/game.tscn").instantiate()
	g.save_path = _save_path()
	g.run_seed = "D-0001"
	return g


func _save_path() -> String:
	return out.path_join("save/save.json")


func _button_center(b: Control) -> Vector2:
	return b.get_global_rect().get_center()


func _expect(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


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
