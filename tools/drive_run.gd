extends Node
## Plays the story mode's run in the game scene with synthetic input: the menu's mode
## keys, the story and day cards, a day at the machine (bills, tickets, NEW BOX, LOAN,
## the last sale of a box), the perk offers after a day (buy, reroll, done), the phone
## (LOAN, the perk tree, the item shelf, box reading, a call to a contact), the item tray
## (its picker, a token's tip, a column item's token taking the player to the machine), HIGH ROLLER's fixed bet, opening at once, putting a ticket back in the
## tray, the trash can, tickets kept overnight, LEAVE, a shift of work, paying early into the next layer
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
	_key(KEY_P)
	await _wait(0.4)
	_expect(game.phone.visible and _pkey("app_loan") != null and _pkey("app_shop") == null, "free play: the phone has LOAN only")
	await _shot("01a_phone_free_play")
	_phone("app_loan")
	await _wait(0.3)
	await _shot("01b_phone_loan_free_play")
	_key(KEY_ESCAPE)
	await _wait(0.3)
	_expect(not game.phone.visible and not game.menu.visible, "Esc puts the phone away (and opens no menu)")

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
	# The perk offers come first, at the start of the run and after every day.
	_expect(run.story == "" and game.run_card.visible and game.run_card.key("offer_done") != null, "then the perk offers")
	_expect(game.run_card.key("offer_0") != null and run.offers.size() == Catalog.OFFERS, "three offers, a key each")
	_expect(game.run_card.key("offer_later") != null, "LATER while nothing is bought")
	await _shot("02b_offers")
	game.set_language("zh")
	await _wait(0.3)
	await _shot("02c_offers_zh")
	game.set_language("en")
	await _wait(0.2)
	e.bonus(1000)
	game._show_run_card()
	await _wait(0.2)
	var offered: String = run.offers[0]
	var price := run.perk_price(offered)
	var cash := e.cash
	_card("offer_0")
	await _wait(0.3)
	_expect(run.level(offered) == 1 and e.cash == cash - price and run.offers.size() == Catalog.OFFERS - 1, "BUY: %s for %s, gone from the offers" % [offered, Hud._money(price)])
	var reroll := run.reroll_price()
	cash = e.cash
	_card("offer_reroll")
	await _wait(0.3)
	_expect(e.cash == cash - reroll and run.offers.size() == Catalog.OFFERS and run.reroll_price() == reroll * 2, "REROLL: three new offers for %s, the next costs double" % Hud._money(reroll))
	await _shot("02d_offers_rerolled")
	_expect(game.run_card.key("offer_later") == null, "something bought: DONE, no LATER")
	_card("offer_done")
	await _wait(0.3)
	_expect(not run.offers_open and run.items_held() == 0, "DONE: closed, no item (something was bought)")
	_expect(run.offers.size() == Catalog.OFFERS - 1, "the other offers wait for the day (the phone's TODAY page)")
	# The checks that follow count on a run without perks and the first day's money.
	run.perks = {}
	run.apply(game.machine)
	e.pay(e.cash - 200)
	game._show_run_card()
	await _wait(0.2)
	_expect(run.story == "" and game.run_card.visible and run.can_choose(), "then the day's choice")
	_expect(game.run_card.key("pay").disabled and game.run_card.key("phone") != null, "PAY dark without the money; the PHONE key")
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
	cash = e.cash
	_click(_button_center(game.hud.run_key("new_box")))
	await _wait(0.3)
	_expect(game.machine.change_armed, "NEW BOX arms")
	await _shot("06_new_box_armed")
	_key(KEY_3)
	await _wait(0.4)
	_expect(game.machine.boxes[2].seed == MachineLogic.next_seed(seed_before) and e.cash == cash - 25, "column 3 has a new box, $25 paid")
	_expect(not game.machine.change_armed and run.stats.box_changes == 1 and game.tray.is_empty(), "disarmed, counted, no ticket sold")

	# LOAN, on the phone now: the layer's line, with interest on top of what is due.
	_click(_button_center(game.hud.phone_key))
	await _wait(0.4)
	_expect(game.phone.visible and _pkey("app_shop") != null and _pkey("app_contacts") != null, "the run's phone: LOAN, SHOP, CONTACTS")
	await _shot("06b_phone_home")
	_phone("app_loan")
	await _wait(0.3)
	await _shot("06c_phone_loan")
	_phone("loan")
	await _wait(0.3)
	_expect(e.cash == cash - 25 + 100 and run.due() == int(run.config.layer(0).debt) + 100, "LOAN $100: cash now, $100 more due (the interest comes each morning)")
	_key(KEY_1)
	await _wait(0.3)
	_expect(game.tray.is_empty() and e.spent == 5, "keys do not reach the machine behind the phone")
	_key(KEY_P)
	await _wait(0.3)
	_expect(not game.phone.visible, "P puts it away")

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

	# The shop: SHELF (the shelf's perks for sale, the build held), TODAY (the day's
	# offers, still for sale, and the item shelf), ITEMS (what is held).
	e.bonus(3000)
	cash = e.cash
	_key(KEY_P)
	await _wait(0.3)
	_phone("app_shop")
	await _wait(0.3)
	_expect(_pkey("tab_shelf") != null and game.phone.row("shelf_read1") != null and _pkey("buy_perk_savings") != null, "SHELF: the shelf's perks, each for sale")
	await _shot("07a_shop_shelf")
	_phone("tab_today")
	await _wait(0.2)
	_expect(game.phone.row("offer_0") != null and _pkey("buy_offer_0") != null and _pkey("reroll_offers") != null, "TODAY: the day's offers, still for sale")
	_expect(_pkey("skip_offers") == null, "something was bought: no SKIP")
	await _shot("07b_shop_today")
	var left := run.offers.size()
	cash = e.cash
	var offer_price := run.perk_price(str(run.offers[0]))
	_phone("buy_offer_0")
	await _wait(0.2)
	_expect(run.offers.size() == left - 1 and e.cash == cash - offer_price, "an offer bought from the phone at the machine")
	cash = e.cash
	# Perks for the checks below (the offers are random): LUCKY STREAK, REGULAR, CLOSER
	# and the reading chain to HOT OR COLD.
	for id in ["luck", "regular", "closer", "read1", "read2", "read3"]:
		run.perks[id] = 1
	run.apply(game.machine)
	_expect(game.machine.luck == 0.3 and run.change_fee() == 12 and run.reading() == 3, "the machine has the luck; NEW BOX half price; reading at 3")
	run.shelf = ["peek", "coin", "magnifier", "skip"]
	game.phone.show_state(game.phone_state())
	await _wait(0.2)
	_phone("tab_shelf")
	await _wait(0.2)
	_expect(game.phone.row("build_closer") != null and game.phone.row("build_luck") != null, "YOUR BUILD: the dealt perks held")
	_phone("tab_today")
	await _wait(0.2)
	_expect(_pkey("buy_peek") != null and _pkey("reroll_shelf") != null, "today's shelf, and a key for another")
	_phone("buy_peek")
	await _wait(0.15)
	_phone("buy_coin")
	await _wait(0.2)
	_expect(run.held("peek") == 1 and run.held("coin") == 1 and not run.shelf.has("peek"), "PEEK and a LUCKY COIN in hand, gone from the shelf")
	_expect(e.cash == cash - 60 and e.balanced(), "$60 from cash")
	_phone("tab_items")
	await _wait(0.2)
	_expect(_pkey("use_peek") != null and _pkey("buy_magnifier") == null, "ITEMS: what is held, nothing to buy")
	await _shot("07d_shop_items")
	# PEEK: used on a column at the machine.
	_phone("use_peek")
	await _wait(0.3)
	_expect(not game.phone.visible and game.aim == "peek", "USE: the phone goes, the machine waits for a column")
	await _shot("07e_pick_a_column")
	_key(KEY_2)
	await _wait(0.3)
	_expect(run.held("peek") == 0 and game.tray.is_empty() and game.aim == "", "column 2 is read, nothing sold")
	_expect(game.machine_view._lcd_sub.text.begins_with("NEXT 10"), "the LCD: %s" % game.machine_view._lcd_sub.text)
	await _shot("07f_peek")
	# Reading at level 3: how the rest feels, and whether a top prize is in.
	await _wait(4.0)
	game._info_column = 0
	game._info_until = game._time + 6.0
	await _wait(0.3)
	var lcd: String = game.machine_view._lcd_sub.text
	_expect(["HOT", "FAIR", "COLD"].any(func(w): return lcd.begins_with(w)) and lcd.contains("TOP"), "reading: %s" % lcd)
	await _shot("07g_reading")
	# The top level: the notepad keeps a line for every box (developer panel: every perk at the top).
	game.dev_run("perks")
	run.perks.erase("allin")   # its card would stop the drive (tests/test_perks has ALL IN)
	_key(KEY_B)
	await _wait(1.4)
	_expect(run.reading() == 5 and not game.at_machine, "every perk at the top; at the table")
	await _shot("07g2_notepad_boxes")
	_key(KEY_SPACE)
	await _wait(1.2)
	# Calling the lender: one more day for this layer.
	_key(KEY_P)
	await _wait(0.3)
	_phone("app_contacts")
	await _wait(0.2)
	await _shot("07h_contacts")
	_phone("contact_lender")
	await _wait(0.4)
	await _shot("07i_calling")
	await _wait(2.0)
	_expect(_pkey("service_more_time") != null, "the lender picks up and offers a day")
	await _shot("07j_lender")
	var days := run.days()
	_phone("service_more_time")
	await _wait(0.2)
	_expect(run.days() == days + 1 and _pkey("service_more_time").disabled, "ONE MORE DAY: the layer has %d days; once a layer" % run.days())
	_phone("hang_up")
	await _wait(0.2)
	_phone("contact_unknown")
	await _wait(3.2)
	_expect(_pkey("hang_up") != null and _pkey("service_more_time") == null, "the unknown number: nobody picks up")
	await _shot("07k_no_answer")
	game.set_language("zh")
	_phone("hang_up")
	await _wait(0.2)
	game.phone.go("shop")
	await _wait(0.3)
	await _shot("07l_shop_zh")
	game.set_language("en")
	_key(KEY_ESCAPE)
	await _wait(0.3)

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
	_expect(run.reading() == 5 and run.held("coin") == 1 and run.extra_days == 1 and game.machine.luck == 0.9, "perks, items and the extra day kept")

	# HIGH ROLLER is the bet (fixed, G): the panel's perks bought it to the top, x10, and
	# there is no key to change it. The rest of the drive plays at x1 (the perk taken off).
	_expect(game.at_machine and run.bet() == 10 and game.machine.price(0) == 10, "HIGH ROLLER 3: a $1 ticket costs $10")
	await _shot("07m_bet")
	run.perks.erase("bet")
	run.apply(game.machine)
	_expect(game.machine.price(0) == 1, "without it: $1 again")

	# Tickets at the table: one goes back into the tray, one in the trash can; the rest
	# stay overnight (G, after M9).
	_click(_button_center(game.hud._bills[0]))
	await _wait(2.4)
	_key(KEY_SPACE)
	_key(KEY_1)
	await _wait(3.6)
	var bought := game._unopened()
	_expect(bought >= 5 and not game.at_machine and game.flow.state == TicketFlow.State.FRONT, "%d tickets bought, the first in hand" % bought)
	var first: Dictionary = game.current
	_click(game.camera.unproject_position(game.table_tray.global_position + Vector3(0, 0.3, 0)))
	await _wait(1.3)
	_expect(game.tray.items[-1] == first and game.current != first and game._unopened() == bought, "clicking the tray: the ticket goes back to the bottom, the next comes up")
	await _shot("08a_put_back")
	_click(game.camera.unproject_position(game.trash_can.mouth()))
	await _wait(0.3)
	_expect(game.run_card.visible and game.run_card.key("trash_one") != null and game.run_card.key("trash_all") != null, "the trash can asks first")
	await _shot("08b_trash_card")
	var discarded: int = run.stats.discarded
	_card("trash_one")
	await _wait(1.3)
	_expect(game._unopened() == bought - 1 and run.stats.discarded == discarded + 1 and not game.run_card.visible, "THIS ONE: the ticket in hand goes in the trash")
	_click(game.camera.unproject_position(game.table_phone.global_position + Vector3(0, 0.08, 0)))
	await _wait(0.4)
	_expect(game.phone.visible, "clicking the phone on the table opens it")
	_key(KEY_ESCAPE)
	await _wait(0.3)
	# The item tray (M9.7): its picker lists what the phone's ITEMS page lists. LUCKY COIN
	# is used on a column at the machine: grey at the table, the phone's reason under it.
	_expect(game.item_tray.visible and game.item_tray.token_count() == mini(run.items_held(), ItemTray.MAX_TOKENS),
		"the item tray on the table, a token for each item held")
	_click(game.camera.unproject_position(game.item_tray.floor_point()))
	await _wait(0.4)
	var coin := game.item_picker.key("use_coin")
	_expect(game.item_picker.visible and coin != null and coin.disabled and game.item_picker.why("coin") != "",
		"clicking the item tray (not a token) opens the picker: LUCKY COIN grey at the table, and why")
	await _shot("08c_item_picker")
	_key(KEY_ESCAPE)
	await _wait(0.3)
	_expect(not game.item_picker.visible and not game.menu.visible, "Esc puts the picker away (and opens no menu)")
	# A click on LUCKY COIN's token (G): to the machine with the coin aimed; PLAY ALL lets
	# it go unused, B back to the table.
	var coin_at := game.item_tray.token_point("coin")
	_expect(coin_at != Vector3.INF, "LUCKY COIN has a token in the tray")
	if coin_at != Vector3.INF:
		_mouse_move(game.camera.unproject_position(coin_at))
		await _wait(0.2)
		_expect(game.hover_item == "coin" and game.hud.tip()[0] != "", "pointing at the token shows its tip")
		await _shot("08d_item_tip")
		_click(game.camera.unproject_position(coin_at))
		await _wait(1.2)
		_expect(game.at_machine and game.aim == "coin" and run.held("coin") == 1, "clicking the token: at the machine, LUCKY COIN aimed, not used yet")
		game.press_play_all()
		await _wait(0.3)
		_expect(game.aim == "" and run.held("coin") == 1, "PLAY ALL lets it go")
		_key(KEY_B)
		await _wait(1.0)
		_expect(not game.at_machine, "B: back at the table")

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
	_expect(game.tray.size() == bought - 1 and game.current.is_empty() and run.stats.discarded == discarded + 1, "the %d unopened tickets are still in the tray" % (bought - 1))
	await _shot("08c_kept_overnight")

	# A shift of work.
	cash = e.cash
	_card("work")
	await _wait(0.3)
	_expect(e.cash == cash + run.shift_wage() and run.shift_wage() == 120 * 85 / 100 and run.today == "work", "WORK: $120 less MOONLIGHTING 2's 15% at once")
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
	_expect(run.stats.days_spared == 3, "three days spared (one bought)")
	_expect(game.rooms.id != room_before and game.rooms.id == run.scene(), "a new table (%s)" % game.rooms.id)
	_expect(game.machine.forms[0].price == 5 and e.bills == [25, 50, 100, 250, 500], "tickets $5, bills at five times")
	_expect(game.piled() == 0 and game.tray.is_empty(), "a clean table")
	_expect(run.stats.discarded == discarded + bought, "paying ends the layer: the kept tickets are thrown away")
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
	# QUICK HANDS: the OPEN key opens the ticket in hand (untouched) and the tray at once.
	var opened := e.opened
	_expect(game.hud.run_key("open").visible, "the OPEN key at the table")
	_key(KEY_O)
	await _wait(0.6)
	_expect(e.opened == opened + 1 and game.current.is_empty() and game.tray.is_empty(), "O: opened at once")
	await _shot("13b_opened_at_once")
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
		await _skip_offers()
		_card("work")
		await _wait(0.2)
		_card("next")
		await _wait(0.2)
	await _skip_offers()
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
	_expect(game.tray.is_empty() and game.current.is_empty() and run.stats.discarded == discarded + bought + 5, "confirmed: the five tickets are thrown away")
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
	_expect(not game.item_tray.visible, "free play: no item tray on the table")
	# The trash can in free play: everything unopened, after asking.
	_key(KEY_B)
	await _wait(1.6)
	_click(game.camera.unproject_position(game.trash_can.mouth()))
	await _wait(0.3)
	_expect(game.run_card.visible and game.run_card.key("trash_all") != null, "free play: the trash can asks too")
	_card("trash_all")
	await _wait(1.0)
	_expect(game._unopened() == 0 and not game.run_card.visible and game.economy.balanced(), "ALL: thrown away, the money as it was")

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
		elif game.run_card.key("offer_done") != null:
			_card("offer_done")
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


## The perk offers, when they are up: closed without buying (an item for it).
func _skip_offers() -> void:
	if game.run_card.visible and game.run_card.key("offer_done") != null:
		_card("offer_done")
		await _wait(0.3)


## Clicks a key on the run's card.
func _card(id: String) -> void:
	var b := game.run_card.key(id)
	if b == null or not game.run_card.visible:
		_expect(false, "card key '%s' is not there" % id)
		return
	_click(_button_center(b))


## A key on the phone's screen.
func _phone(id: String) -> void:
	var b := _pkey(id)
	if b == null:
		_expect(false, "phone key '%s' is not there" % id)
		return
	_click(_button_center(b))


func _pkey(id: String) -> Button:
	return game.phone.key(id) if game.phone.visible else null


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


func _mouse_move(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	Input.parse_input_event(ev)


func _mouse_button(p: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = p
	ev.global_position = p
	Input.parse_input_event(ev)
