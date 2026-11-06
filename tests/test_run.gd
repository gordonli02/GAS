extends "res://tests/test_case.gd"
## The run (story mode): layers, days, work, the house line, paying, and the rule
## that working every day and spending nothing clears it to the dollar
## (docs/roadmap.md "一局的结构").

const DT := 1.0 / 60.0


func _run() -> RunState:
	return RunState.start(RunConfig.standard(), "T-1", ["diner", "bar", "bingo"])


## Works every day except the days listed (counted from 0 across the run), which are
## spent at the machine buying nothing. Returns [run, economy].
func _work_through(idle_days: Array, before := Callable()) -> Array:
	var r := _run()
	var e := r.new_economy()
	if before.is_valid():
		before.call(r, e)
	var n := 0
	while r.playing() and n < 100:
		if idle_days.has(n):
			r.play()
		else:
			r.work(e)
		r.end_day(e)
		n += 1
	return [r, e]


func test_config_holds_together() -> void:
	var c := RunConfig.standard()
	eq(c.problems(), PackedStringArray(), "standard numbers")
	eq(c.layers.size(), 3, "three layers")
	var bad := RunConfig.from_dict(RunConfig.STANDARD)
	bad.layers[1].debt += 1
	check(not bad.problems().is_empty(), "a debt the wages do not meet is reported")


func test_work_only_clears_to_the_dollar() -> void:
	var r := _run()
	var e := r.new_economy()
	var total_days := 0
	for l in r.config.layers.size():
		eq(r.layer, l, "in layer %d" % (l + 1))
		for d in r.days():
			eq(r.day, d + 1, "day")
			check(r.work(e), "work")
			if d < r.days() - 1:
				check(e.cash < r.due(), "layer %d day %d: not enough yet (%d of %d)" % [l + 1, d + 1, e.cash, r.due()])
			else:
				eq(e.cash, r.due(), "layer %d: exactly the debt on the last day" % (l + 1))
			r.end_day(e)
			total_days += 1
			check(e.balanced(), "ledger balanced")
	eq(r.status, RunState.CLEARED, "cleared")
	eq(e.cash, 0, "nothing to spare")
	eq(r.stats.tickets, 0, "without a single ticket")
	eq(r.stats.days_spared, 0, "and not a day early")
	eq(r.stats.days, total_days, "days counted")
	eq(r.stats.shifts, total_days, "a shift every day")


func test_work_only_fails_when_off_by_anything() -> void:
	var total := 0
	for l in RunConfig.standard().layers:
		total += int(l.days)
	for k in total:
		var res := _work_through([k])
		eq(res[0].status, RunState.FAILED, "one day off work (day %d) and working alone is not enough" % (k + 1))
	var spent := _work_through([], func(_r: RunState, e: Economy): e.pay(1))
	eq(spent[0].status, RunState.FAILED, "one dollar spent")
	eq(spent[0].layer, 0, "fails in the first layer")
	var loan := _work_through([], func(r: RunState, e: Economy): r.borrow(e))
	eq(loan[0].status, RunState.FAILED, "one loan: the interest is not covered")


func test_todays_wage_never_adds_up() -> void:
	# The player sees only today's wage; at that wage the layer's days never reach the debt.
	var r := _run()
	var e := r.new_economy()
	for l in r.config.layers.size():
		check(e.cash + r.wage() * r.days() < r.due(), "layer %d: day-one wage x days falls short" % (l + 1))
		var first := r.wage()
		var raised := false
		for d in r.days():
			raised = raised or r.wage() > first
			r.work(e)
			r.end_day(e)
		check(raised, "layer %d: the wage rises along the way" % (l + 1))


func test_a_day_is_work_or_play() -> void:
	var r := _run()
	var e := r.new_economy()
	check(r.can_choose(), "a new day: choose")
	check(r.play(), "play")
	check(not r.work(e), "no shift after choosing the machine")
	eq(e.earned, 0, "no wage")
	r.end_day(e)
	eq(r.day, 2, "next day")
	check(r.work(e), "work")
	eq(e.cash, 200 + 120, "the wage at once")
	check(not r.play() and not r.work(e), "one choice a day")
	eq(r.today, "work", "worked today")


func test_paying_early_moves_on_at_once() -> void:
	var r := _run()
	var e := r.new_economy()
	r.play()
	check(not r.can_pay(e), "not with $200")
	check(not r.pay(e), "pay refused")
	e.bonus(900)
	e.insert(100)
	check(not r.can_pay(e), "a bill being fed has to land first")
	e.step_bill(Economy.BILL_TIME)
	eq(e.credit, 100, "credit in the machine")
	e.pay(50)
	check(r.can_pay(e), "cash and credit together cover it")
	check(r.pay(e), "pay")
	eq(e.credit, 0, "credit cashed out")
	eq(e.cash, 200 + 900 - 50 - 1000, "paid in one go")
	eq(r.layer, 1, "next layer")
	eq(r.day, 1, "on a new day")
	check(r.can_choose(), "a fresh choice")
	eq(r.story, "twist", "the interest has compounded")
	eq(r.stats.days_spared, 4, "four days spared")
	eq(e.bills, [25, 50, 100, 250, 500], "bills at the new stake")
	check(e.balanced(), "balanced")
	for l in 2:
		e.bonus(r.due())
		check(r.pay(e), "pay layer %d" % (r.layer + 1))
	eq(r.status, RunState.CLEARED, "third layer paid: cleared")
	eq(r.story, "ending", "ending")
	eq(r.stats.layers_cleared, 3, "three layers")
	check(not r.pay(e) and not r.play() and not r.borrow(e), "nothing more to do")


func test_deadline() -> void:
	var r := _run()
	var e := r.new_economy()
	for d in r.days() - 1:
		r.play()
		r.end_day(e)
		check(r.playing(), "day %d: still on" % (d + 1))
	check(r.last_day(), "last day")
	r.play()
	r.end_day(e)
	eq(r.status, RunState.FAILED, "the last day ends unpaid: over")
	eq(r.story, "failed", "story")
	var r2 := _run()
	var e2 := r2.new_economy()
	for d in r2.days() - 1:
		r2.play()
		r2.end_day(e2)
	r2.play()
	e2.bonus(900)
	r2.end_day(e2)
	eq(r2.layer, 1, "leaving on the last day with the money pays the layer")
	eq(e2.cash, 100, "what was left")


func test_house_line() -> void:
	var r := _run()
	var e := r.new_economy()
	eq(r.loan_left(), 200, "base line of the first layer")
	check(r.borrow(e), "borrow")
	eq(e.cash, 300, "cash now")
	eq(e.loans, 100, "a loan in the ledger")
	eq(r.due(), 1000 + 125, "the loan and its interest on top of the debt")
	check(r.borrow(e), "again")
	check(not r.borrow(e), "up to the line")
	eq(r.loan_left(), 0, "nothing left")
	r.loan_bonus = 100
	check(r.borrow(e), "a perk can raise the line")
	eq(r.due(), 1000 + 375, "all of it due in this layer")
	check(e.balanced(), "balanced")
	e.bonus(2000)
	r.pay(e)
	eq(e.cash, 200 + 300 + 2000 - 1375, "repaid with the layer")
	eq(r.due(), 5000, "the next layer starts clean")
	eq(r.loan_left(), 1000 + 100, "with a higher base line")
	eq(r.loan_step(), 500, "and a bigger step")


func test_stage_machine() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var r := _run()
	var e := r.new_economy()
	var m := r.new_machine(pack.forms)
	var tray := TicketTray.new()
	eq(m.forms[0].price, 1, "first layer at the pack's price")
	eq(m.last_sale, 50, "last sale prize")
	# A new box for the fee.
	var seed_before: String = m.boxes[1].seed
	check(r.change_box(e, m, 1), "change box")
	eq(e.cash, 175, "fee paid")
	eq(m.boxes[1].seed, MachineLogic.next_seed(seed_before), "next seed")
	eq(m.stock_left(1), 0, "restocking")
	eq(r.stats.box_changes, 1, "counted")
	e.pay(165)
	check(not r.change_box(e, m, 0), "no fee, no box")
	# The last ticket of a box pays the last sale.
	e.earn(90)
	e.insert(5)
	e.step_bill(Economy.BILL_TIME)
	var box := m.boxes[0]
	box.cursor = box.size - 2
	m.armed = true
	m.press(0, e.credit)
	m.queue[0].n = 2
	var last := []
	var t := 0.0
	while m.busy() and t < 5.0:
		t += DT
		last.append_array(m.step(DT, t, e, tray).last_sale)
	eq(tray.size(), 2, "two tickets")
	eq(last, [0], "one last sale, on the last ticket")
	eq(e.won, 50, "paid as a prize")
	eq(e.cash, 95 + 50, "straight to cash")
	check(e.balanced(), "balanced")
	# Second layer: everything at five times the stake, the same boxes otherwise.
	e.bonus(r.due())
	r.pay(e)
	var m2 := r.new_machine(pack.forms)
	eq(m2.forms[0].price, 5, "price")
	eq(int(m2.forms[0].tiers[0].prize), 2500, "top prize")
	eq(m2.forms[0].uid(), pack.forms[0].uid(), "same form id")
	check(m2.forms[0].art_key() != pack.forms[0].art_key(), "its own printed art")
	eq(pack.forms[0].price, 1, "the pack's form is untouched")
	check(pack.forms[0].scaled(1) == pack.forms[0], "stake 1 is the form itself")
	eq(m2.min_price(), 5, "cheapest ticket")
	eq(m2.press(0, 4), "insert_bill", "$4 buys nothing at $5")
	m2.armed = true
	eq(m2.press(0, 23), "", "PLAY ALL with $23")
	eq(m2.queue[0].n, 4, "buys four")


func test_prizes_only_boxes_match() -> void:
	var pack := core_pack()
	if pack == null:
		return
	for f in pack.forms:
		var a := BoxGenerator.build(f, "P-7")
		var b := BoxGenerator.build(f, "P-7", null, true)
		eq(b.size, a.size, "size")
		eq(b.counts, a.counts, "counts")
		eq(b.type_id, a.type_id, "type")
		var same := true
		for i in a.size:
			same = same and a.tickets[i].tier == b.tickets[i].tier and a.tickets[i].prize == b.tickets[i].prize
		check(same, "%s: the same prizes in the same order" % f.id)


func test_round_trip() -> void:
	var r := _run()
	var e := r.new_economy()
	r.story = ""
	r.work(e)
	r.end_day(e)
	r.borrow(e)
	r.play()
	r.count_sales(12, 1)
	var back := RunState.from_dict(JSON.parse_string(JSON.stringify(r.to_dict())), RunConfig.standard())
	check(back != null, "reads back")
	if back != null:
		eq(back.to_dict(), r.to_dict(), "the same run")
		eq(back.due(), r.due(), "due")
		eq(back.wage(), r.wage(), "wage")
	var e2 := Economy.new()
	e2.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	check(e2.balanced(), "the run's ledger reads back balanced")
	eq(e2.cash, e.cash, "cash")
	for bad in [{}, {"seed": "x", "layer": 9}, {"seed": "x", "day": 99}, {"seed": "x", "today": "nap"}, {"seed": "x", "status": "?"}]:
		check(RunState.from_dict(bad, RunConfig.standard()) == null, "refused: %s" % str(bad))


## The money identity holds through a long random run, with every kind of step.
func test_invariant_random_run() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var steps := 40000 if full else 8000
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var r := _run()
	var e := r.new_economy()
	var m := r.new_machine(pack.forms, true)
	var tray := TicketTray.new()
	var t := 0.0
	var runs := 1
	for s in steps:
		if not r.playing():
			r = RunState.start(RunConfig.standard(), "T-%d" % runs, ["diner", "bar", "bingo"])
			e = r.new_economy()
			m = r.new_machine(pack.forms, true)
			tray.clear()
			runs += 1
		var layer := r.layer
		match rng.randi() % 12:
			0:
				if r.today == "play":
					e.insert(e.bills[rng.randi() % e.bills.size()])
			1, 2, 3:
				if r.today == "play":
					m.press(rng.randi() % 3, e.credit)
			4:
				if r.today == "play":
					m.press_play_all(e.credit)
			5, 6:
				if not tray.is_empty():
					e.open_ticket(tray.take().ticket.prize)
			7:
				if rng.randf() < 0.3:
					r.borrow(e)
			8:
				if r.today == "play" and rng.randf() < 0.1:
					r.change_box(e, m, rng.randi() % 3)
			9:
				if r.can_choose():
					if rng.randf() < 0.4:
						r.work(e)
					else:
						r.play()
			10:
				if not m.busy() and tray.is_empty() and r.today != "" and rng.randf() < 0.05:
					r.end_day(e)
			11:
				if not m.busy() and tray.is_empty():
					r.pay(e)
		if r.layer != layer and r.playing():
			m = r.new_machine(pack.forms, true)
		t += DT
		e.step_bill(DT)
		var ev := m.step(DT, t, e, tray)
		r.count_sales(ev.sold.size(), ev.last_sale.size())
		if not e.balanced() or e.cash < 0 or e.credit < 0:
			check(false, "step %d: cash %d credit %d bill %d start %d loans %d won %d earned %d spent %d paid %d" % [
				s, e.cash, e.credit, e.bill, e.start_cash, e.loans, e.won, e.earned, e.spent, e.paid])
			return
	note("random runs: %d steps, %d runs" % [steps, runs])
