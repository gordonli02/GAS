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
	eq(m.press(0, e.credit), "", "press")
	_run(m, e, tray, 2.0)
	eq(tray.size(), 1, "one ticket")
	eq(e.credit, 4, "$1 of credit")
	eq(m.return_at, 0.0, "credit left: the camera stays")
	var broke := Economy.new()
	eq(m.press(1, broke.credit), "insert_bill", "no credit: INSERT BILL")


func test_play_all() -> void:
	var m := _machine()
	var e := Economy.new()
	var tray := TicketTray.new()
	e.credit = 150
	m.press_play_all(e.credit)
	check(m.armed, "armed")
	m.press(1, e.credit)
	check(not m.armed, "disarms on the column press")
	var t := _run(m, e, tray, 20.0)
	eq(tray.size(), 100, "sells min(100, credit)")
	check(absf(t - 100.0 / 16.35) < 0.15, "at 16.35 a second (%.2f s for 100)" % t)
	eq(e.credit, 50, "credit used")
	var m2 := _machine()
	var e2 := Economy.new()
	var tray2 := TicketTray.new()
	e2.credit = 7
	m2.press_play_all(e2.credit)
	m2.press(2, e2.credit)
	_run(m2, e2, tray2, 5.0)
	eq(tray2.size(), 7, "PLAY ALL with $7: 7 tickets")
	check(m2.return_at > 0.0, "credit gone: camera returns after dispensing")
	m2.press_play_all(0)
	check(not m2.armed, "PLAY ALL needs credit")


func test_mixed_forms_open_in_purchase_order() -> void:
	var m := _machine()
	var e := Economy.new()
	var tray := TicketTray.new()
	e.credit = 10
	for i in [2, 0, 1, 0]:
		m.press(i, e.credit)
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
	m.press_play_all(e.credit)
	m.press(0, e.credit)   # 50 tickets, only 2 left in the box
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
		m.press(0, e.credit)
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
				m.press(rng.randi() % 3, e.credit)
			3:
				m.press_play_all(e.credit)
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
