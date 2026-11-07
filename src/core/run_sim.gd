class_name RunSim
extends RefCounted
## Plays whole runs with simple bots, for looking at the numbers. Pure logic: the
## run's own rules (RunState, Economy, MachineLogic), with tickets sold and opened at
## once instead of through the motor, the tray and the table.
##
## Bots (the targets for most of them are docs/roadmap.md's bots table):
##   work     works every day, never buys a ticket; buys SAVINGS as the work line does
##            (RunConfig.line_buys), so it clears every layer to the dollar
##   blind    plays whenever it can pay for a ticket, works when it cannot
##   borrow   as blind, but takes the whole house line before giving a day up
##   gamble   plays by default, works only when its cash cannot pay for a day's tickets
##            (GAMBLE_DAY tickets at the machine's cheapest price): the steady gambler
##            who builds nothing
##   perks    as blind, but every round of perk offers it buys the cheapest offer that
##            costs no more than half its cash, then the next, and so on (the perks
##            are where a run grows); it opens in batches when it has QUICK HANDS and
##            bets the most it can while it holds a hundred tickets' worth of cash
##   skip     as blind, but never buys a perk: every round of offers is skipped for its
##            item (which it never uses)
##   build and the line bots (LINES): as blind, but each morning they buy their shelf
##            perks, then the first of their dealt perks offered (in their order of
##            preference), each while it costs at most `share` of the cash, and skip
##            the rest; at the machine they pick a column of their line's forms when
##            one is there. `build` takes any line's engines; `clearing`, `jackpot`,
##            `small`, `batch` and `money` one line each (docs/roadmap.md M9.5: a bot
##            per line). With HIGH ROLLER they bet as the perks bot does; with ALL IN
##            they buy a box out once a day of play
##   churn    the exploit check for FIRST PULL x REGULAR (docs/perk_research.md 5.11):
##            buys both whenever it can pay for them, and at the machine buys CHURN
##            tickets of a column, then changes the box, again and again. Its return
##            counted with the fees (summary's `return_fees`) must stay at 1 or under
## A bot that cannot work (NO WAY BACK bought) plays instead.

const BOTS := ["work", "blind", "borrow", "gamble", "perks", "skip", "build",
	"clearing", "jackpot", "small", "batch", "money", "churn"]
## The build bots: dealt perks taken, best first; shelf perks bought (every level, in
## this order; SAVINGS only on the work line's checkpoints); the share of the cash a
## perk may cost; the forms (FormDef.id) the bot's column is picked among when the
## machine sells one of them (none: any column).
## jackpot buys REGULAR for what it opens: READ THE FLARE needs CLOSER or REGULAR, and
## JACKPOT HUNTER needs READ THE FLARE.
const LINES := {
	"build": {"perks": ["snowball", "bigfish", "prizes", "closer", "combo", "again", "stacker", "penny", "luck",
		"fortune", "firstpull", "pity", "scrap", "assembly", "middle"], "shelf": ["multi"], "share": 0.6, "forms": []},
	"clearing": {"perks": ["closer", "firstpull", "assembly", "snowball"], "shelf": ["regular"], "share": 0.6, "forms": []},
	"jackpot": {"perks": ["bigfish", "pity", "hunter"], "shelf": ["regular", "read1"], "share": 0.6,
		"forms": ["catch", "kabawk"]},
	"small": {"perks": ["penny", "stacker", "scrap", "trashking"], "shelf": [], "share": 0.6, "forms": ["plate", "nugget"]},
	"batch": {"perks": ["combo", "again", "allin"], "shelf": ["multi", "bet"], "share": 0.6, "forms": []},
	"money": {"perks": ["worth", "middle"], "shelf": ["savings"], "share": 0.6, "forms": ["spur"]},
	"churn": {"perks": ["firstpull"], "shelf": ["regular"], "share": 1.0, "forms": []},
}
## Perk levels whose return tools/sim_runs prints (box_return), one build per line. A
## "snow" key is not a perk: SNOWBALL's count of boxes already cleared. ALL IN (once a
## day) and NET WORTH (the cash, kept at 0 here) do nothing in box_return, so the
## batch and money lines are shown without them.
const EV_SETS := [
	{}, {"prizes": 1}, {"prizes": 3}, {"scrap": 2}, {"luck": 3}, {"luck": 3, "fortune": 1},
	{"prizes": 1, "bigfish": 2}, {"luck": 1, "firstpull": 2}, {"luck": 1, "pity": 2},
	# The lines' full sets.
	{"closer": 2, "firstpull": 2, "assembly": 1, "snowball": 1, "regular": 2},
	{"bigfish": 2, "pity": 2, "hunter": 1, "read1": 1},
	{"penny": 2, "stacker": 1, "scrap": 2, "trashking": 1},
	{"multi": 2, "combo": 2, "again": 2},
	{"middle": 2},
	# The draft's combos: daily small prizes (batches of 20 with CHAIN), the
	# astronomical one (after ten boxes cleared), FLARE ONLY on BIG FISH.
	{"magnet": 2, "penny": 2, "stacker": 1, "multi": 2, "combo": 1},
	{"bigfish": 2, "bet": 3, "snowball": 1, "snow": 10},
	{"flare": 2, "bigfish": 2},
	{"prizes": 3, "bigfish": 2, "luck": 3, "fortune": 1, "closer": 2, "firstpull": 2, "snowball": 1},
]
## Perk levels the churn table (churn_return) prints: CHURN tickets a box, then NEW BOX.
const CHURN_SETS := [{}, {"regular": 2}, {"firstpull": 1, "regular": 2}, {"firstpull": 2, "regular": 2}]
## A day at the machine has no limit; a bot stops after this many tickets so that a
## run always ends.
const DAY_CAP := 6000
const BATCH := 25
const GAMBLE_DAY := 25   ## the gamble bot works when its cash is less than this many tickets
const CHURN := 20        ## the churn bot's tickets a box (Catalog.FIRST_TICKETS)
const BEST_PCT := [50, 90, 99]   ## the percentiles of each run's best prize summary gives


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
	var line: Dictionary = LINES.get(bot, {})
	var guard := 0
	while run.playing() and guard < 1000:
		guard += 1
		var layer := run.layer
		if bot == "perks":
			_shop(run, e, m)
		elif not line.is_empty():
			_build(run, e, m, line)
		elif bot == "skip":
			run.close_offers(true)
		elif bot == "work":
			_save(run, e)
		var price := m.min_price()
		var wants_play := bot != "work"
		if bot == "gamble":
			wants_play = run.can_pay(e) or e.cash + e.credit >= price * GAMBLE_DAY
		if wants_play and e.cash + e.credit < price and bot == "borrow":
			while run.can_borrow():
				run.borrow(e)
		if wants_play and e.cash + e.credit >= price:
			run.play(e)
			_play_day(run, e, m, rng, bot, line)
		elif not run.work(e) and run.play(e):
			_play_day(run, e, m, rng, bot, line)
		if run.playing() and run.layer == layer:
			run.end_day(e)
		if run.playing() and run.layer != layer:
			m = run.new_machine(base_forms, true)
		assert(e.balanced(), "the ledger must balance")
	return {"status": run.status, "layer": run.layer, "days": int(run.stats.days), "tickets": int(run.stats.tickets),
		"cash": e.cash, "spent": e.spent, "won": e.won, "balanced": e.balanced(), "stats": run.stats.duplicate()}


## The column a bot plays today: one of its line's forms when the machine sells one,
## else any, at random.
static func _column(m: MachineLogic, rng: RandomNumberGenerator, forms: Array) -> int:
	var cols := []
	for i in m.forms.size():
		if forms.has(m.forms[i].id):
			cols.append(i)
	if cols.is_empty():
		return rng.randi() % m.forms.size()
	return int(cols[rng.randi() % cols.size()])


## Buys and opens tickets from one column, a batch at a time, until the layer can be
## paid (and pays it), the money runs out, or the day's cap is reached. With ALL IN the
## column is bought out first when the money is there; the churn bot changes the box
## after every CHURN tickets when it can pay the fee.
static func _play_day(run: RunState, e: Economy, m: MachineLogic, rng: RandomNumberGenerator, bot: String,
		line: Dictionary) -> void:
	var col := _column(m, rng, line.get("forms", []))
	var borrows := bot == "borrow"
	var churn := bot == "churn"
	var per := CHURN if churn else BATCH
	var bought := 0
	var layer := run.layer
	while bought < DAY_CAP:
		if run.can_pay(e):
			run.pay(e, m)
			return
		var price := m.price(col)
		if run.effect("all_in") > 0 and run.can_all_in(e, m, col):
			var r := run.all_in(e, m, col)
			bought += int(r.get("n", 0))
			continue
		_feed(e, price * per)
		if e.credit < price:
			if borrows and run.can_borrow():
				run.borrow(e)
				continue
			break
		var sales := 0
		var last := 0
		var held := []
		for k in per:
			var sold := m.sell_now(col, e)
			if sold.is_empty():
				break
			sales += 1
			if sold.last_sale:
				last += 1
				run.cleared_box(m)
			held.append({"form": m.forms[col], "ticket": sold.ticket, "box": sold.box, "bet": m.bet})
		_open(run, e, held)
		run.count_sales(sales, last, m.forms[col].uid())
		bought += sales
		if run.layer != layer:
			return
		if churn and m.boxes[col].cursor < m.boxes[col].size:
			if e.cash < run.change_fee():
				e.cash_out()
			run.change_box(e, m, col)
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
## and again; then the offers are closed. Then the bet.
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
	run.close_offers(true)
	_bet(run, e, m)


## The bet: the most the machine takes while the cash holds a hundred tickets at it.
static func _bet(run: RunState, e: Economy, m: MachineLogic) -> void:
	run.bet = 1
	for b in run.bets():
		if e.cash >= int(b) * m.forms[0].price * 100:
			run.bet = int(b)
	run.apply(m)


## The work line's morning: one level of SAVINGS off the shelf when the layer allows it
## and the cash is there (RunConfig.line_buys). The offers are left alone.
static func _save(run: RunState, e: Economy) -> void:
	if RunConfig.line_buys(run.level(RunConfig.SAVINGS) + 1, run.layer):
		run.buy_perk(RunConfig.SAVINGS, e)


## A build bot's morning (LINES): its shelf perks, every level it can pay with its
## share of the cash (SAVINGS as the work line buys it); then the best of its dealt
## perks offered by the same rule, again and again; then the offers are closed (an
## item if nothing was bought) and, with HIGH ROLLER, the bet.
static func _build(run: RunState, e: Economy, m: MachineLogic, line: Dictionary) -> void:
	var share := float(line.get("share", 0.6))
	var prefs: Array = line.get("perks", [])
	for id in line.get("shelf", []):
		if id == RunConfig.SAVINGS:
			_save(run, e)
			continue
		var g := 0
		while g < 5:
			g += 1
			var p := run.perk_price(id)
			if p <= 0 or p > e.cash * share or not run.buy_perk(id, e):
				break
		run.apply(m)
	var guard := 0
	while run.offers_open and guard < 10:
		guard += 1
		var best := -1
		for k in run.offers.size():
			var id := str(run.offers[k])
			var p := run.perk_price(id)
			if prefs.has(id) and p > 0 and p <= e.cash * share and (best < 0 or prefs.find(id) < prefs.find(str(run.offers[best]))):
				best = k
		if best < 0 or not run.buy_offer(best, e):
			break
		run.apply(m)
	run.close_offers(true)
	if run.bet_max() > 1:
		_bet(run, e, m)


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


## `runs` runs of one bot. Returns the shares and means a balance pass looks at:
## `cleared` (overall), `reached` (share that got to each layer), `layer_rates` (of the
## runs that reached a layer, the share that paid it: their product is `cleared`),
## days, tickets, perks and days spared per run; `return` (prizes per dollar of
## tickets) and `return_fees` (per dollar of tickets and NEW BOX fees); `best` (the
## BEST_PCT percentiles of each run's biggest single prize, in dollars: the
## "astronomical" numbers of docs/perk_research.md 5.8).
static func summary(bot: String, base_forms: Array, runs: int, seed_prefix := "SIM", config: RunConfig = null) -> Dictionary:
	if config == null:
		config = RunConfig.standard()
	var layers := config.layers.size()
	var cleared := 0
	var reached := []
	reached.resize(layers)
	reached.fill(0)
	var paid := []
	paid.resize(layers)
	paid.fill(0)
	var days := 0
	var tickets := 0
	var spent := 0
	var won := 0
	var fees := 0
	var spared := 0
	var perks := 0
	var bests := []
	for i in runs:
		var r := play(bot, base_forms, "%s-%d" % [seed_prefix, i], config)
		if r.status == RunState.CLEARED:
			cleared += 1
		for l in int(r.layer) + 1:
			reached[l] += 1
		for l in mini(layers, int(r.stats.layers_cleared)):
			paid[l] += 1
		days += int(r.days)
		tickets += int(r.tickets)
		spent += int(r.spent)
		won += int(r.won)
		fees += int(r.stats.fees)
		spared += int(r.stats.days_spared)
		perks += int(r.stats.perks)
		bests.append(int(r.stats.best_prize))
	var n := maxf(1.0, runs)
	var reach := []
	var rates := []
	for l in layers:
		reach.append(reached[l] / n)
		rates.append(float(paid[l]) / reached[l] if reached[l] > 0 else 0.0)
	return {"bot": bot, "runs": runs, "cleared": cleared / n, "reached": reach, "layer_rates": rates, "days": days / n,
		"tickets": tickets / n, "return": float(won) / spent if spent > 0 else 0.0,
		"return_fees": float(won) / (spent + fees) if spent + fees > 0 else 0.0, "fees": fees / n,
		"days_spared": spared / n, "perks": perks / n, "best": percentiles(bests, BEST_PCT)}


## The nearest-rank percentiles `pcts` of `values` (non-decreasing in `pcts`).
static func percentiles(values: Array, pcts: Array) -> Array:
	var v := values.duplicate()
	v.sort()
	var out := []
	for p in pcts:
		if v.is_empty():
			out.append(0)
			continue
		out.append(v[clampi(ceili(float(p) / 100.0 * v.size()) - 1, 0, v.size() - 1)])
	return out


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


## What a dollar of tickets pays back at given perk levels ({perk id: level}; a "snow"
## key sets SNOWBALL's count of boxes already cleared), over `boxes` whole boxes of
## every form bought out at stake 1 and at the top bet, perks' bonuses and the
## last-sale prize included. The boxes load through the machine, so luck counts too.
## With QUICK HANDS the tickets are opened in batches of its size (at most BATCH), so
## CHAIN and ENCORE count; SNOWBALL grows as boxes are cleared. The cash is kept at
## zero (the ledger is not kept here), so NET WORTH adds nothing. Pass one form in
## `base_forms` for that form's return alone.
static func box_return(base_forms: Array, perk_levels: Dictionary, boxes: int, seed_prefix := "EV") -> float:
	var run := RunState.start(RunConfig.standard(), seed_prefix, ["diner"])
	run.perks = perk_levels.duplicate()
	run.snow = int(run.perks.get("snow", 0))
	run.perks.erase("snow")
	run.bet = run.bet_max()
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


## The churn exploit at fixed perk levels: in every column, CHURN tickets bought and
## opened one at a time, then NEW BOX for the fee, `boxes` times, at stake 1. Returns
## {return: prizes per dollar of tickets, return_fees: per dollar of tickets and fees,
## fee: the fee paid}. FIRST PULL's floor on the fee (RunState.change_fee) is what
## keeps return_fees at 1 or under.
static func churn_return(base_forms: Array, perk_levels: Dictionary, boxes: int, seed_prefix := "CH") -> Dictionary:
	var run := RunState.start(RunConfig.standard(), seed_prefix, ["diner"])
	run.perks = perk_levels.duplicate()
	var e := run.new_economy()
	var m := run.new_machine(base_forms, true)
	var spent := 0
	var won := 0
	var fees := 0
	for col in m.forms.size():
		for b in boxes:
			for k in CHURN:
				e.credit += m.price(col)
				var sold := m.sell_now(col, e)
				spent += m.price(col)
				if sold.last_sale:
					run.cleared_box(m)
				var before := e.won
				run.open_ticket(e, {"form": m.forms[col], "ticket": sold.ticket, "box": sold.box, "bet": m.bet})
				won += e.won - before
			var fee := run.change_fee()
			e.cash += fee
			run.change_box(e, m, col)
			fees += fee
	return {"return": float(won) / spent if spent > 0 else 0.0,
		"return_fees": float(won) / (spent + fees) if spent + fees > 0 else 0.0, "fee": run.change_fee()}
