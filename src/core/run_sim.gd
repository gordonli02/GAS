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

const BOTS := ["work", "blind", "borrow", "mixed"]
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
		var price := m.min_price()
		var wants_play := bot != "work" and not (bot == "mixed" and run.day <= 2)
		if wants_play and e.cash + e.credit < price and bot == "borrow":
			while run.can_borrow():
				run.borrow(e)
		if wants_play and e.cash + e.credit >= price:
			run.play()
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
		for k in BATCH:
			var sold := m.sell_now(col, e)
			if sold.is_empty():
				break
			sales += 1
			if sold.last_sale:
				last += 1
			e.open_ticket(sold.ticket.prize)
		run.count_sales(sales, last)
		bought += sales
		if run.layer != layer:
			return
	e.cash_out()


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
	var n := maxf(1.0, runs)
	var reach := []
	for v in reached:
		reach.append(v / n)
	return {"bot": bot, "runs": runs, "cleared": cleared / n, "reached": reach, "days": days / n,
		"tickets": tickets / n, "return": float(won) / spent if spent > 0 else 0.0, "days_spared": spared / n}
