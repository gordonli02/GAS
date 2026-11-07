extends "res://tests/test_case.gd"
## The run (story mode): layers, days, work, the house line, paying, and the rule
## that working every day, spending nothing on tickets and buying SAVINGS along the
## way clears every layer to the dollar (docs/roadmap.md "一局的结构"; G, 2026-11-06).

const DT := 1.0 / 60.0


func _run() -> RunState:
	return RunState.start(RunConfig.standard(), "T-1", ["diner", "bar", "bingo"])


## Works every day except the days listed (counted from 0 across the run), which are
## spent at the machine buying nothing, and buys SAVINGS as the work line does (unless
## `saves` is false). Returns [run, economy].
func _work_through(idle_days: Array, before := Callable(), saves := true) -> Array:
	var r := _run()
	var e := r.new_economy()
	if before.is_valid():
		before.call(r, e)
	var n := 0
	while r.playing() and n < 100:
		if saves and RunConfig.line_buys(r.level(RunConfig.SAVINGS) + 1, r.layer):
			r.buy_perk(RunConfig.SAVINGS, e)
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
	check(not bad.problems().is_empty(), "a debt the work line does not meet is reported")
	var line := c.work_line()
	for i in 3:
		eq(int(line[i].debt), int(c.layer(i).debt), "layer %d: the debt is the work line's" % (i + 1))
		check(int(line[i].wages) < int(line[i].debt), "layer %d: wages alone fall short" % (i + 1))
		eq(int(line[i].level), i + 1, "layer %d: one level of SAVINGS a layer" % (i + 1))
	var poor := RunConfig.from_dict(RunConfig.STANDARD)
	poor.layers[2].wage = 1
	poor.layers[2].erase("debt")
	poor = RunConfig.from_dict({"start_cash": poor.start_cash, "loan_interest": poor.loan_interest, "layers": poor.layers})
	check(not poor.problems().is_empty(), "a wage that leaves the top of SAVINGS unaffordable is reported")
	eq(int(c.layer(0).savings_day), 1, "the line buys SAVINGS on the first day of the run (G)")
	for i in 3:
		check(int(c.layer(i).savings_day) >= 1, "layer %d: a checkpoint to buy SAVINGS on" % (i + 1))
	check(c.line_text().begins_with("layer 1: debt $"), "the line in words")


func test_work_and_savings_clear_to_the_dollar() -> void:
	var r := _run()
	var e := r.new_economy()
	var total_days := 0
	for l in r.config.layers.size():
		eq(r.layer, l, "in layer %d" % (l + 1))
		for d in r.days():
			eq(r.day, d + 1, "day")
			if RunConfig.line_buys(r.level(RunConfig.SAVINGS) + 1, r.layer):
				r.buy_perk(RunConfig.SAVINGS, e)
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
	eq(r.level(RunConfig.SAVINGS), 3, "SAVINGS at the top by the end")
	eq(r.stats.perks, 3, "and nothing else bought")


func test_work_line_fails_when_off_by_anything() -> void:
	var total := 0
	for l in RunConfig.standard().layers:
		total += int(l.days)
	for k in total:
		var res := _work_through([k])
		eq(res[0].status, RunState.FAILED, "one day off work (day %d) and the line is not enough" % (k + 1))
	var spent := _work_through([], func(_r: RunState, e: Economy): e.pay(1))
	eq(spent[0].status, RunState.FAILED, "one dollar spent")
	eq(spent[0].layer, 0, "fails in the first layer")
	# The interest compounds daily above SAVINGS' first level (G), so a loan on the
	# first day grows faster than the cash it brought.
	var loan := _work_through([], func(r: RunState, e: Economy): r.borrow(e))
	eq(loan[0].status, RunState.FAILED, "one loan on the first day: the interest outgrows SAVINGS")
	eq(loan[0].layer, 0, "and it shows in the first layer")
	var plain := _work_through([], Callable(), false)
	eq(plain[0].status, RunState.FAILED, "working without SAVINGS is not enough")
	eq(plain[0].layer, 0, "it fails in the first layer already")


func test_borrowing_to_invest_does_not_clear() -> void:
	# SAVINGS x LOAN (docs/perk_research.md 5.11, borrow to invest): the whole house
	# line on the first morning, SAVINGS bought up to its top as soon as the cash is
	# there, every day worked, the layer paid the moment it can be. At 15% a day on
	# what is owed it still falls short of the first layer.
	var r := _run()
	var e := r.new_economy()
	while r.borrow(e):
		pass
	eq(r.loan_due, r.loan_limit(), "the whole line borrowed")
	var n := 0
	while r.playing() and r.layer == 0 and n < 20:
		while r.level(RunConfig.SAVINGS) < 3 and r.buy_perk(RunConfig.SAVINGS, e):
			pass
		r.work(e)
		if r.can_pay(e):
			r.pay(e)
		else:
			r.end_day(e)
		n += 1
	note("borrow to invest, layer 1: SAVINGS %d by the last day, cash $%d, owed $%d, due $%d" % [
		r.level(RunConfig.SAVINGS), e.cash, r.loan_due, r.due()])
	eq(r.status, RunState.FAILED, "borrowing the line to buy SAVINGS does not clear the first layer")
	eq(r.layer, 0, "it fails there")


func test_wages_alone_fall_short() -> void:
	# The wage is flat within a layer (no hidden raises), and the wage times the days
	# never reaches the debt: SAVINGS has to make up the rest.
	var r := _run()
	var e := r.new_economy()
	for l in r.config.layers.size():
		check(e.cash + r.wage() * r.days() < r.due(), "layer %d: wage x days falls short" % (l + 1))
		var first := r.wage()
		for d in r.days():
			eq(r.wage(), first, "layer %d day %d: the same wage" % [l + 1, d + 1])
			r.work(e)
			if d == r.days() - 1:
				e.bonus(r.due() - e.cash)   # make the layer, to look at the next
			r.end_day(e)


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
	eq(e.cash, 200 + 150, "the wage at once")
	check(not r.play() and not r.work(e), "one choice a day")
	eq(r.today, "work", "worked today")


func test_paying_early_moves_on_at_once() -> void:
	var r := _run()
	var e := r.new_economy()
	r.play()
	check(not r.can_pay(e), "not with $200")
	check(not r.pay(e), "pay refused")
	var debt := r.due()
	e.bonus(debt - 100)
	e.insert(100)
	check(not r.can_pay(e), "a bill being fed has to land first")
	e.step_bill(Economy.BILL_TIME)
	eq(e.credit, 100, "credit in the machine")
	e.pay(50)
	check(r.can_pay(e), "cash and credit together cover it")
	check(r.pay(e), "pay")
	eq(e.credit, 0, "credit cashed out")
	eq(e.cash, 200 + (debt - 100) - 50 - debt, "paid in one go")
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
	e2.bonus(r2.due() - 100)
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
	var debt: int = r.config.layer(0).debt
	eq(r.due(), debt + 100, "the loan on top of the debt, no interest yet")
	eq(r.interest(), 15, "15% a day")
	r.work(e)
	r.end_day(e)
	eq(r.due(), debt + 115, "a morning: 15% on what is owed")
	check(r.borrow(e), "again")
	check(not r.borrow(e), "up to the line")
	eq(r.loan_left(), 0, "nothing left")
	r.loan_bonus = 100
	check(r.borrow(e), "a perk can raise the line")
	eq(r.due(), debt + 315, "all of it due in this layer")
	eq(r.stats.interest, 15, "the interest counted")
	check(e.balanced(), "balanced")
	e.bonus(2000)
	r.pay(e)
	eq(e.cash, 200 + 150 + 300 + 2000 - (debt + 315), "repaid with the layer")
	eq(r.due(), r.config.layer(1).debt, "the next layer starts clean")
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
	m.press(0, e)
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
	eq(int(m2.forms[0].tiers[0].prize), 5000, "top prize (the run's $1,000 Big Catch at stake 5)")
	eq(m2.forms[0].uid(), pack.forms[0].uid(), "same form id")
	check(m2.forms[0].art_key() != pack.forms[0].art_key(), "its own printed art")
	eq(pack.forms[0].price, 1, "the pack's form is untouched")
	check(pack.forms[0].scaled(1) == pack.forms[0], "stake 1 is the form itself")
	eq(m2.min_price(), 5, "cheapest ticket")
	var e4 := Economy.new()
	e4.credit = 4
	eq(m2.press(0, e4), "insert_bill", "$4 buys nothing at $5")
	m2.armed = true
	e4.credit = 23
	eq(m2.press(0, e4), "", "PLAY ALL with $23")
	eq(m2.queue[0].n, 4, "buys four")


## G, M9.6: the run's machine deals the forms' shapes; free play's machine does not.
func test_run_boxes_are_shaped_free_play_boxes_are_not() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var r := _run()
	var m := r.new_machine(pack.forms, true)
	check(m.model != null and m.model.shapes, "the run's machine carries the shaped model")
	var free := MachineLogic.new(pack.forms, "S-FREE", null, true)
	check(free.model == null, "free play's machine has the standard model")
	var catch := pack.form("catch")
	eq(int(catch.tiers[0].prize), 500, "the pack's Big Catch pays $500 (free play)")
	check(not free.forms[0].shaped_prizes, "free play sells the pack's form")
	var run_catch: FormDef = null
	for f in m.forms:
		if f.id == "catch":
			run_catch = f
	if not check(run_catch != null, "the run sells Big Catch"):
		return
	check(run_catch.shaped_prizes, "the run sells the shaped form")
	eq(int(run_catch.tiers[0].prize), 1000, "the run's Big Catch pays $1,000 at stake 1")
	eq(run_catch.price, 1, "at the pack's price")
	var differ := 0
	for n in 20:
		var seed := "RB-%02d" % n
		var in_run := BoxGenerator.build(run_catch, seed, m.model, true)
		var in_free := BoxGenerator.build(catch, seed, free.model, true)
		eq(in_free.counts, BoxGenerator.build(catch, seed, null, true).counts, "free play: the standard box")
		eq(in_run.prize_total(), in_free.prize_total(), "the same money either way")
		if in_run.counts != in_free.counts:
			differ += 1
	check(differ > 10, "Big Catch is dealt differently in the run (%d of 20 boxes)" % differ)
	# The next layer: the run's prizes at that layer's stake.
	r.layer = 1
	var m2 := r.new_machine(pack.forms, true)
	for f in m2.forms:
		if f.id == "catch":
			eq(int(f.tiers[0].prize), 5000, "layer 2: the run's top prize at stake 5")
			eq(f.price, 5, "layer 2: price at stake 5")


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
					m.press(rng.randi() % 3, e)
			4:
				if r.today == "play":
					m.press_play_all(e)
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


## A layer can name what its machine sells, column by column; without a list it sells
## every form (M8.6).
func test_layer_picks_its_columns() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var r := _run()
	eq(r.stage_forms(pack.forms).map(func(f): return f.uid()), pack.forms.map(func(f): return f.uid()), "no list: every form")
	var d: Dictionary = RunConfig.STANDARD.duplicate(true)
	d.layers[0]["forms"] = ["core:spur", "core:nugget", "core:gone", "core:catch"]
	d.layers[1]["forms"] = ["core:gone"]
	var picky := RunState.start(RunConfig.from_dict(d), "T-2", ["diner", "bar", "bingo"])
	var m := picky.new_machine(pack.forms)
	eq(m.forms.map(func(f): return f.id), ["spur", "nugget", "catch"], "the listed forms, in column order; one not installed is left out")
	eq(m.boxes.size(), 3, "a box per column")
	picky.layer = 1
	eq(picky.stage_forms(pack.forms).size(), pack.forms.size(), "a list with nothing installed: every form")
	eq(picky.stage_forms(pack.forms)[0].price, 5, "at the layer's stake")
