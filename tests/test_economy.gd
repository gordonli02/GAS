extends "res://tests/test_case.gd"
## Money, machine and tray rules (MIGRATION.md "Money", "Machine", acceptance
## "cash + credit = 200 + loans + won - spent, at every step").

const DT := 1.0 / 60.0


func _machine(seed_text := "G-0001") -> MachineLogic:
	var pack := core_pack()
	return MachineLogic.new(pack.forms, seed_text)


## Runs the machine until it stops selling (or `max_t` seconds).
func _run(m: MachineLogic, e: Economy, tray: TicketTray, max_t: float) -> float:
	var t := 0.0
	while t < max_t:
		t += DT
		e.step_bill(DT)
		var ev := m.step(DT, t, e, tray)
		if ev.stopped:
			return t
	return t


func test_start_and_bills() -> void:
	var e := Economy.new()
	eq(e.cash, 200, "start cash")
	eq(e.credit, 0, "start credit")
	check(not e.can_insert(7), "only real bills")
	check(e.insert(20), "insert $20")
	eq(e.cash, 180, "cash leaves at the click")
	check(not e.can_insert(5), "one bill at a time")
	var t := 0.0
	var heard := -1.0
	var credited := -1.0
	while t < 3.0:
		t += DT
		var ev := e.step_bill(DT)
		if ev.get("sound", false):
			heard = t
		if ev.has("credited"):
			credited = t
		check(e.balanced(), "balanced while feeding (%.2f s)" % t)
	check(absf(heard - 0.16 * 2.05) < 0.02, "bill sound at 16%% (%.3f s)" % heard)
	check(absf(credited - 2.05) < 0.02, "credit after 2.05 s (%.3f s)" % credited)
	eq(e.credit, 20, "credited")
	var poor := Economy.new()
	poor.cash = 30
	check(not poor.can_insert(50), "not more than the cash")


## G, 2026-11-07: with the cash under the smallest bill the slot takes coins, the whole
## tickets the credit and the cash make at the cheapest price; what cannot buy a ticket
## stays in the pocket. They feed as a bill does.
func test_coins_under_the_smallest_bill() -> void:
	var e := Economy.new()
	e.cash = 4
	e.start_cash = 4
	eq(e.smallest_bill(), 5, "free play's smallest bill")
	check(not e.can_insert(5), "$4 is no bill")
	eq(e.coins_for(1), 4, "four $1 tickets of coins")
	check(e.insert_coins(1), "the coins go in")
	eq(e.cash, 0, "the cash leaves at the click")
	eq(e.bill, 4, "fed as a bill is")
	check(e.coins, "as coins")
	eq(e.coins_for(1), 0, "one feed at a time")
	check(not e.insert(5), "and no bill meanwhile")
	var heard := false
	var t := 0.0
	while e.bill > 0 and t < 3.0:
		t += DT
		heard = e.step_bill(DT).get("sound", false) or heard
		check(e.balanced(), "balanced while feeding (%.2f s)" % t)
	check(heard, "with the slot's sound")
	check(absf(t - Economy.BILL_TIME) < 0.05, "in a bill's time (%.2f s)" % t)
	eq(e.credit, 4, "credited")
	check(not e.coins, "the feed is over")
	# A bill in the pocket: bills first, the coins after.
	var b := Economy.new()
	b.cash = 7
	eq(b.coins_for(1), 0, "$7 holds a bill: no coins")
	b.insert(5)
	b.step_bill(Economy.BILL_TIME)
	eq(b.coins_for(1), 2, "then the $2 left")
	# The run's second layer: bills from $25, tickets $5.
	var r := Economy.new()
	r.bills = RunConfig.bills(5)
	r.cash = 24
	r.start_cash = 24
	eq(r.smallest_bill(), 25, "the smallest bill at stake 5")
	eq(r.coins_for(5), 20, "$24: four tickets of coins")
	check(r.insert_coins(5), "fed")
	r.step_bill(Economy.BILL_TIME)
	eq(r.credit, 20, "four tickets of credit")
	eq(r.cash, 4, "$4 stays in the pocket")
	eq(r.coins_for(5), 0, "under one ticket: nothing")
	check(not r.insert_coins(5), "nothing fed")
	eq(r.cash, 4, "nothing taken")
	check(r.balanced(), "balanced")
	# The credit counts: $3 of credit and $4 of coins make a ticket and more.
	var c := Economy.new()
	c.bills = RunConfig.bills(5)
	c.credit = 3
	c.cash = 4
	eq(c.coins_for(5), 2, "$2 of coins tops $3 of credit up to one ticket")
	c.credit = 5
	c.cash = 2
	eq(c.coins_for(5), 0, "a whole ticket of credit and $2: nothing")
	c.cash = 0
	eq(c.coins_for(5), 0, "no cash, no coins")
	# HIGH ROLLER's bet raises the cheapest price the machine asks: whole tickets of it.
	var h := Economy.new()
	h.cash = 4
	eq(h.coins_for(3), 3, "at $3 a ticket: $3 of coins, $1 kept")
	# The machine sells from the coins' credit.
	var pack := core_pack()
	if pack == null:
		return
	var m := MachineLogic.new(pack.forms, "CO-0001")
	var k := Economy.new()
	k.cash = 3
	eq(m.press(0, k), "insert_bill", "no credit: the machine asks for money")
	check(k.insert_coins(m.min_price()), "coins")
	k.step_bill(Economy.BILL_TIME)
	eq(m.press(0, k), "", "now it sells")


func test_prizes_cash_out_and_net() -> void:
	var e := Economy.new()
	e.credit = 10
	e.cash = 190
	check(e.buy(1), "ticket from credit")
	eq(e.spent, 1, "spending recorded at purchase")
	e.open_ticket(25)
	eq(e.cash, 215, "prize to cash")
	eq(e.credit, 9, "never back to credit")
	eq(e.net(), 24, "NET = won - spent")
	eq(e.cash_out(), 9, "cash out returns credit")
	eq(e.cash, 224, "to cash")
	eq(e.credit, 0, "credit empty")
	check(not e.buy(1), "no credit, no ticket")


func test_loan_rules() -> void:
	var e := Economy.new()
	check(e.loan_available(), "loan offered any time, even with cash")
	var net_before := e.net()
	check(e.take_loan(), "take a loan")
	eq(e.cash, 400, "loan adds $200")
	eq(e.net(), net_before, "a loan does not count in NET")
	check(e.balanced(), "money identity holds with loans")
	while e.take_loan():
		pass
	eq(e.loans, Economy.LOAN_LIMIT, "lends up to the limit")
	check(not e.loan_available(), "then no more")
	eq(e.loan_left(), 0, "nothing left")


func test_single_press_sells_one() -> void:
	var m := _machine()
	var e := Economy.new()
	var tray := TicketTray.new()
	e.credit = 5
	eq(m.press(0, e), "", "press")
	_run(m, e, tray, 2.0)
	eq(tray.size(), 1, "one ticket")
	eq(e.credit, 4, "$1 of credit")
	eq(m.return_at, 0.0, "credit left: the camera stays")
	var broke := Economy.new()
	eq(m.press(1, broke), "insert_bill", "no credit: INSERT BILL")


func test_play_all() -> void:
	var m := _machine()
	var e := Economy.new()
	var tray := TicketTray.new()
	e.credit = 150
	m.press_play_all(e)
	check(m.armed, "armed")
	m.press(1, e)
	check(not m.armed, "disarms on the column press")
	var t := _run(m, e, tray, 20.0)
	eq(tray.size(), 100, "sells min(100, credit)")
	check(absf(t - 100.0 / 16.35) < 0.15, "at 16.35 a second (%.2f s for 100)" % t)
	eq(e.credit, 50, "credit used")
	var m2 := _machine()
	var e2 := Economy.new()
	var tray2 := TicketTray.new()
	e2.credit = 7
	m2.press_play_all(e2)
	m2.press(2, e2)
	_run(m2, e2, tray2, 5.0)
	eq(tray2.size(), 7, "PLAY ALL with $7: 7 tickets")
	check(m2.return_at > 0.0, "credit gone: camera returns after dispensing")
	m2.press_play_all(e2)
	check(not m2.armed, "PLAY ALL needs credit")


func test_mixed_forms_open_in_purchase_order() -> void:
	var m := _machine()
	var e := Economy.new()
	var tray := TicketTray.new()
	e.credit = 10
	for i in [2, 0, 1, 0]:
		m.press(i, e)
	_run(m, e, tray, 3.0)
	var order := []
	while not tray.is_empty():
		order.append(tray.take().form.id)
	eq(order, ["spur", "catch", "plate", "catch"], "one tray, purchase order")


func test_sold_out_restocks_and_sales_wait() -> void:
	var m := _machine()
	var e := Economy.new()
	var tray := TicketTray.new()
	var box := m.boxes[0]
	box.cursor = box.size - 2
	e.credit = 50
	m.press_play_all(e)
	m.press(0, e)   # 50 tickets, only 2 left in the box
	var t := 0.0
	var sold_at_two := -1.0
	while t < 10.0 and tray.size() < 50:
		t += DT
		m.step(DT, t, e, tray)
		if tray.size() == 2 and sold_at_two < 0:
			sold_at_two = t
	eq(tray.size(), 50, "all 50 sold in the end")
	eq(m.boxes[0].seed, "G-0002", "next seed loaded")
	eq(tray.items[1].box.seed, "G-0001", "first two from the old box")
	eq(tray.items[2].box.seed, "G-0002", "the rest from the new one")
	# 48 tickets at the restock rate (18/s) take longer than at the dispense rate.
	check(t > 48.0 / 18.0, "sales waited for stock (%.2f s)" % t)


func test_queue_clears_without_credit() -> void:
	var m := _machine()
	var e := Economy.new()
	var tray := TicketTray.new()
	e.credit = 2
	for i in 4:
		m.press(0, e)
	_run(m, e, tray, 3.0)
	eq(tray.size(), 2, "only what the credit pays for")
	check(not m.busy(), "rest of the queue dropped")


func test_next_seed() -> void:
	eq(MachineLogic.next_seed("G-0001"), "G-0002", "counts up")
	eq(MachineLogic.next_seed("G-0999"), "G-1000", "keeps width")
	eq(MachineLogic.next_seed("box"), "box-2", "no number")


## Acceptance: the money identity holds at every step of a long random session.
func test_invariant_random_session() -> void:
	var steps := 60000 if full else 12000
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var m := _machine("INV-1")
	var e := Economy.new()
	var tray := TicketTray.new()
	var t := 0.0
	var bought := 0
	for s in steps:
		match rng.randi() % 9:
			0:
				var v: int = Economy.BILLS[rng.randi() % 5]
				e.insert(v)
			1, 2:
				m.press(rng.randi() % 3, e)
			3:
				m.press_play_all(e)
			4:
				if not tray.is_empty():
					var it := tray.take()
					it.box.opened = it.ticket.no
					e.open_ticket(it.ticket.prize)
			5:
				if not m.busy():
					e.cash_out()
			6:
				if rng.randf() < 0.05:
					e.take_loan()
		t += DT
		e.step_bill(DT)
		var ev := m.step(DT, t, e, tray)
		bought += ev.sold.size()
		if not e.balanced():
			check(false, "step %d: cash %d + credit %d + bill %d != 200 + loans %d + won %d - spent %d" % [s, e.cash, e.credit, e.bill, e.loans, e.won, e.spent])
			return
		if e.cash < 0 or e.credit < 0:
			check(false, "step %d: negative money" % s)
			return
	eq(e.spent, bought, "spent = tickets bought")
	eq(bought - e.opened, tray.size(), "held = bought - opened")
	note("random session: %d steps, %d bought, %d opened, %d wins, loans $%d, net %+d" % [steps, bought, e.opened, e.wins, e.loans, e.net()])
