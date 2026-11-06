class_name RunSim
extends RefCounted
## Plays whole runs with simple bots, for looking at the numbers. Pure logic: the
## run's own rules (RunState, Economy, MachineLogic), with tickets sold and opened at
## once instead of through the motor, the tray and the table.
##
## Bots:
##   work    works every day, never buys a ticket
##   blind   plays whenever it can pay for a ticket, works when it cannot
##   borrow  as blind, but takes the whole house line before giving a day up
##   mixed   works the first two days of each layer, then plays as blind
##   perks   as blind, but every round of perk offers it buys the cheapest offer that
##           costs no more than half its cash, then the next, and so on (the perks
##           are where a run grows); it opens in batches when it has QUICK HANDS and
##           bets the most it can while it holds a hundred tickets' worth of cash
##   skip    as blind, but never buys a perk: every round of offers is skipped for its
##           item (which it never uses)
##   build   as perks, but it only takes the money and luck engines of BUILD (the first
##           of them offered that costs at most 60% of its cash) and skips the rest

const BOTS := ["work", "blind", "borrow", "mixed", "perks", "skip", "build"]
## The build bot's perks, best first.
const BUILD := ["snowball", "bigfish", "prizes", "closer", "combo", "again", "multi", "stacker", "luck", "fortune",
	"firstpull", "pity", "scrap", "assembly", "regular"]
## Perk levels whose return tools/sim_runs prints (box_return), one build per line.
const EV_SETS := [
	{}, {"prizes": 1}, {"prizes": 3}, {"scrap": 2}, {"luck": 3}, {"luck": 3, "fortune": 1},
	{"prizes": 1, "bigfish": 2}, {"luck": 1, "firstpull": 2}, {"luck": 1, "pity": 2},
	{"closer": 2, "regular": 2, "assembly": 1},
	{"prizes": 1, "bigfish": 1, "closer": 2, "snowball": 1},
	{"multi": 2, "combo": 2, "again": 2},
	{"prizes": 3, "stacker": 1, "multi": 2, "combo": 2, "again": 2},
	{"prizes": 3, "bigfish": 2, "luck": 3, "fortune": 1, "closer": 2, "firstpull": 2, "snowball": 1},
]
## A day at the machine has no limit; a bot stops after this many tickets so that a
## run always ends.
const DAY_CAP := 6000
const BATCH := 25


## One run. Returns {status, layer (0-based, where it ended), days, tickets, cash,
## spent, won, stats}. The same bot, forms, seed and config always give the same run.
static func play(bot: String, base_forms: Array, seed_text: String, config: RunConfig = null) -> Dictionary:
	if config == null:
		config = RunConfig.standard()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text + "|" + bot)
	var run := RunState.start(config, seed_text, ["diner", "bar", "bingo"])
	var e := run.new_economy()
	var m := run.new_machine(base_forms, true)
	var guard := 0
	while run.playing() and guard < 1000:
		guard += 1
		var layer := run.layer
		if bot == "perks":
			_shop(run, e, m)
		elif bot == "build":
			_build(run, e, m)
		elif bot == "skip":
			run.close_offers()
		var price := m.min_price()
		var wants_play := bot != "work" and not (bot == "mixed" and run.day <= 2)
		if wants_play and e.cash + e.credit < price and bot == "borrow":
			while run.can_borrow():
				run.borrow(e)
		if wants_play and e.cash + e.credit >= price:
			run.play(e)
			_play_day(run, e, m, rng, bot == "borrow")
		else:
			run.work(e)
		if run.playing() and run.layer == layer:
			run.end_day(e)
		if run.playing() and run.layer != layer:
			m = run.new_machine(base_forms, true)
		assert(e.balanced(), "the ledger must balance")
	return {"status": run.status, "layer": run.layer, "days": int(run.stats.days), "tickets": int(run.stats.tickets),
		"cash": e.cash, "spent": e.spent, "won": e.won, "balanced": e.balanced(), "stats": run.stats.duplicate()}


## Buys and opens tickets from one column picked at random, a batch at a time, until
## the layer can be paid (and pays it), the money runs out, or the day's cap is reached.
static func _play_day(run: RunState, e: Economy, m: MachineLogic, rng: RandomNumberGenerator, borrows: bool) -> void:
	var col := rng.randi() % m.forms.size()
	var price: int = m.forms[col].price
	var bought := 0
	var layer := run.layer
	while bought < DAY_CAP:
		if run.can_pay(e):
			run.pay(e)
			return
		_feed(e, price * BATCH)
		if e.credit < price:
			if borrows and run.can_borrow():
				run.borrow(e)
				continue
			break
		var sales := 0
		var last := 0
		var held := []
		for k in BATCH:
			var sold := m.sell_now(col, e)
			if sold.is_empty():
				break
			sales += 1
			if sold.last_sale:
				last += 1
				run.cleared_box(m)
			held.append({"form": m.forms[col], "ticket": sold.ticket, "box": sold.box, "bet": m.bet})
		_open(run, e, held)
		run.count_sales(sales, last)
		bought += sales
		if run.layer != layer:
			return
	e.cash_out()


## Opens tickets bought: in batches of QUICK HANDS' size when the run has it, else one
## at a time.
static func _open(run: RunState, e: Economy, held: Array) -> void:
	var n := run.batch_size()
	if n <= 0:
		for en in held:
			run.open_ticket(e, en)
		return
	var k := 0
	while k < held.size():
		run.open_batch(e, held.slice(k, k + n))
		k += n


## The perks bot's round of offers: the cheapest it can pay with half its cash, again
## and again; then the offers are closed. Then the bet: the most it can while it holds
## a hundred tickets' worth.
static func _shop(run: RunState, e: Economy, m: MachineLogic) -> void:
	var guard := 0
	while run.offers_open and guard < 10:
		guard += 1
		var best := -1
		for k in run.offers.size():
			var p := run.perk_price(str(run.offers[k]))
			if p > 0 and p * 2 <= e.cash and (best < 0 or p < run.perk_price(str(run.offers[best]))):
				best = k
		if best < 0 or not run.buy_offer(best, e):
			break
		run.apply(m)
	run.close_offers()
	run.bet = 1
	for b in run.bets():
		if e.cash >= int(b) * m.forms[0].price * 100:
			run.bet = int(b)
	run.apply(m)


## The build bot's round of offers: the best of BUILD it can pay with 60% of its cash,
## again and again; then the offers are closed (an item if nothing was bought).
static func _build(run: RunState, e: Economy, m: MachineLogic) -> void:
	var guard := 0
	while run.offers_open and guard < 10:
		guard += 1
		var best := -1
		for k in run.offers.size():
			var id := str(run.offers[k])
			var p := run.perk_price(id)
			if BUILD.has(id) and p > 0 and p <= e.cash * 0.6 and (best < 0 or BUILD.find(id) < BUILD.find(str(run.offers[best]))):
				best = k
		if best < 0 or not run.buy_offer(best, e):
			break
		run.apply(m)
	run.close_offers()


## Moves cash into credit through the bill slot until `want` is there or no bill fits.
static func _feed(e: Economy, want: int) -> void:
	var guard := 0
	while e.credit < want and guard < 500:
		guard += 1
		var fed := false
		for i in range(e.bills.size() - 1, -1, -1):
			if e.cash >= int(e.bills[i]):
				e.insert(int(e.bills[i]))
				e.step_bill(Economy.BILL_TIME)
				fed = true
				break
		if not fed:
			return


## `runs` runs of one bot. Returns the shares and means a balance pass looks at.
static func summary(bot: String, base_forms: Array, runs: int, seed_prefix := "SIM", config: RunConfig = null) -> Dictionary:
	if config == null:
		config = RunConfig.standard()
	var cleared := 0
	var reached := []
	reached.resize(config.layers.size())
	reached.fill(0)
	var days := 0
	var tickets := 0
	var spent := 0
	var won := 0
	var spared := 0
	var perks := 0
	for i in runs:
		var r := play(bot, base_forms, "%s-%d" % [seed_prefix, i], config)
		if r.status == RunState.CLEARED:
			cleared += 1
		for l in int(r.layer) + 1:
			reached[l] += 1
		days += int(r.days)
		tickets += int(r.tickets)
		spent += int(r.spent)
		won += int(r.won)
		spared += int(r.stats.days_spared)
		perks += int(r.stats.perks)
	var n := maxf(1.0, runs)
	var reach := []
	for v in reached:
		reach.append(v / n)
	return {"bot": bot, "runs": runs, "cleared": cleared / n, "reached": reach, "days": days / n,
		"tickets": tickets / n, "return": float(won) / spent if spent > 0 else 0.0, "days_spared": spared / n, "perks": perks / n}


## Each form's boxes in the run's model (the forms' shapes, G, M9.6), `boxes` boxes
## at stake 1, no perks: what a dollar of tickets pays back, winners per 100 tickets,
## top prizes a box, and the standard deviation of one ticket's prize (how bumpy the
## form is). Every form should pay back about the same; the rest is its shape.
static func form_table(base_forms: Array, boxes: int, seed_prefix := "FM") -> Array:
	var model := RunConfig.standard().box_model(0)
	var out := []
	for base: FormDef in base_forms:
		var f := base.shaped()
		var spent := 0
		var won := 0
		var winners := 0
		var tops := 0
		var sq := 0.0
		var tickets := 0
		for n in boxes:
			var box := BoxGenerator.build(f, "%s-%d" % [seed_prefix, n], model, true)
			spent += box.gross()
			won += box.prize_total()
			tickets += box.size
			for i in box.counts.size():
				if f.is_top(i):
					tops += box.counts[i]
			for t in box.tickets:
				if t.prize > 0:
					winners += 1
				sq += float(t.prize) * t.prize
		var mean := float(won) / tickets
		out.append({"form": f.id, "return": float(won) / spent, "winners": 100.0 * winners / tickets,
			"tops": float(tops) / boxes, "sd": sqrt(maxf(0.0, sq / tickets - mean * mean))})
	return out


## What a dollar of tickets pays back at given perk levels ({perk id: level}), over
## `boxes` whole boxes of every form bought out at stake 1, perks' bonuses and the
## last-sale prize included. The boxes load through the machine, so luck counts too.
## With QUICK HANDS the tickets are opened in batches of its size (at most BATCH), so
## CHAIN and ENCORE count; SNOWBALL grows as boxes are cleared. The cash is kept at
## zero (the ledger is not kept here), so NET WORTH adds nothing.
static func box_return(base_forms: Array, perk_levels: Dictionary, boxes: int, seed_prefix := "EV") -> float:
	var run := RunState.start(RunConfig.standard(), seed_prefix, ["diner"])
	run.perks = perk_levels.duplicate()
	var e := run.new_economy()
	e.cash = 0
	var m := run.new_machine(base_forms, true)
	var spent := 0
	var won := 0
	var n := mini(BATCH, run.batch_size()) if run.batch_size() > 0 else 1
	for col in m.forms.size():
		var done := 0
		var held := []
		while done < boxes:
			e.credit += m.price(col)
			var sold := m.sell_now(col, e)
			spent += m.price(col)
			if sold.last_sale:
				won += m.last_sale
				run.cleared_box(m)
			held.append({"form": m.forms[col], "ticket": sold.ticket, "box": sold.box, "bet": m.bet})
			if held.size() >= n or m.boxes[col].cursor >= m.boxes[col].size:
				var before := e.won
				if n > 1:
					run.open_batch(e, held)
				else:
					run.open_ticket(e, held[0])
				won += e.won - before
				held = []
				e.cash = 0
			if m.boxes[col].cursor >= m.boxes[col].size:
				done += 1
	return float(won) / spent
