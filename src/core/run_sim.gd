class_name RunSim
extends RefCounted
## Plays whole runs with simple bots, for looking at the numbers. Pure logic: the
## run's own rules (RunState, Economy, MachineLogic), with tickets sold and opened at
## once instead of through the motor, the tray and the table.
##
## Bots (the targets for most of them are docs/roadmap.md's bots table):
##   work     works every day, never buys a ticket; buys SAVINGS as the work line does
##            (RunConfig.line_buys), so it clears every layer on its last day (the wage
##            is derived from the debt for that, RunConfig)
##   blind    plays whenever it can pay for a ticket, works when it cannot
##   borrow   as blind, but takes the whole house line before giving a day up
##   gamble   plays by default, works only when its cash cannot pay for a day's tickets
##            (GAMBLE_DAY tickets at the machine's cheapest price): the steady gambler
##            who builds nothing
##   perks    as blind, but every round of perk offers it buys the cheapest offer that
##            costs no more than half its cash, then the next, and so on (the perks
##            are where a run grows); it opens in batches when it has QUICK HANDS
##            (never in a run now: QUICK HANDS waits for M13)
##   skip     as blind, but never buys a perk: every round of offers is skipped for its
##            item (which it never uses)
##   build and the line bots (LINES): as blind, but each morning they buy their shelf
##            perks, then the first of their dealt perks offered (in their order of
##            preference), each while it costs at most `share` of the cash, and skip
##            the rest; at the machine they pick a column of their line's forms when
##            one is there. `build` takes any line's engines; `clearing`, `jackpot`,
##            `small`, `batch` and `money` one line each (docs/roadmap.md M9.5: a bot
##            per line). HIGH ROLLER is the bet (fixed): a level is bought only when
##            the cash left after it holds HIGH_ROLLER_CASH tickets at the new price.
##            With ALL IN they stake a window whenever they can while the stake is
##            under half their cash (one ticket at a time, so every window can be
##            staked). `batch` is the window line now (STREAK, ALL IN, MAGNET): QUICK
##            HANDS, CHAIN and ENCORE wait for the shop outside the run (M13)
##   churn    the exploit check for FIRST PULL x REGULAR (docs/perk_research.md 5.11):
##            buys both whenever it can pay for them, and at the machine buys CHURN
##            tickets of a column, then changes the box, again and again. Its return
##            counted with the fees (summary's `return_fees`) must stay at 1 or under
## A bot that cannot work (NO WAY BACK bought) plays instead.
## "Can pay for a ticket" is the slot's rule (_can_buy): bills, and coins under the
## smallest bill (Economy.coins_for, G 2026-11-07), so every bot that goes to the machine
## buys at least one ticket there; the result's `idle_days` counts the days one did not.

const BOTS := ["work", "blind", "borrow", "gamble", "perks", "skip", "build",
	"clearing", "jackpot", "small", "batch", "money", "churn"]
## The build bots: dealt perks taken, best first; shelf perks bought (every level, in
## this order; SAVINGS only on the work line's checkpoints); the share of the cash a
## perk may cost; `reserve`, optional: a dealt perk is bought only if the cash left
## holds this many tickets of the machine's cheapest price (0 when missing); the forms
## (FormDef.id) the bot's column is picked among when the machine sells one of them
## (none: any column). `build` takes the perks that lift the return of any ticket,
## cheapest and surest first (G, 2026-11-07, wants build to clear highest; a player who builds does not buy
## CLOSER or FIRST PULL in a layer whose boxes hold 900 tickets or more; `clearing`
## measures those), and keeps 100 tickets of cash.
## jackpot buys REGULAR for what it opens: READ THE FLARE needs CLOSER or REGULAR, and
## JACKPOT HUNTER needs READ THE FLARE.
const LINES := {
	"build": {"perks": ["prizes", "luck", "scrap", "penny", "bigfish", "streak", "stacker", "fortune", "pity", "middle"],
		"shelf": [], "share": 0.6, "reserve": 100, "forms": []},
	"clearing": {"perks": ["closer", "firstpull", "assembly", "snowball"], "shelf": ["regular"], "share": 0.6, "forms": []},
	"jackpot": {"perks": ["bigfish", "pity", "hunter"], "shelf": ["regular", "read1"], "share": 0.6,
		"forms": ["catch", "kabawk"]},
	"small": {"perks": ["penny", "stacker", "consolation", "packed", "scrap", "crumbs", "trashking"], "shelf": [], "share": 0.6,
		"forms": ["plate", "nugget"]},
	"batch": {"perks": ["streak", "allin", "magnet", "crumbs", "consolation"], "shelf": ["bet"], "share": 0.6, "forms": []},
	"money": {"perks": ["worth", "middle"], "shelf": ["savings"], "share": 0.6, "forms": ["spur"]},
	"churn": {"perks": ["firstpull"], "shelf": ["regular"], "share": 1.0, "forms": []},
}
## Perk levels whose return tools/sim_runs prints (box_return), one build per line. A
## "snow" key is not a perk: SNOWBALL's count of boxes already cleared; a "form" key
## (a FormDef.id) plays that form's boxes alone. NET WORTH (the cash, kept at 0 here),
## SEAL, the reading chain and the items (REEL IN) do nothing in box_return; ALL IN
## is played on every window it can be (box_return). Rows marked M13 hold QUICK HANDS,
## CHAIN or ENCORE, which no run sells now (they wait for the shop outside the run):
## kept as "what if" rows, they still compute.
const EV_SETS := [
	{}, {"prizes": 1}, {"prizes": 3}, {"scrap": 2}, {"luck": 3}, {"luck": 3, "fortune": 1},
	{"prizes": 1, "bigfish": 2}, {"luck": 1, "firstpull": 2}, {"luck": 1, "pity": 2},
	# The lines' full sets.
	{"closer": 2, "firstpull": 2, "assembly": 1, "snowball": 1, "regular": 2},
	{"bigfish": 2, "pity": 2, "hunter": 1, "read1": 1},
	{"penny": 2, "stacker": 1, "scrap": 2, "trashking": 1},
	{"multi": 2, "combo": 2, "again": 2, "streak": 2},                     # M13
	{"streak": 2, "allin": 1, "magnet": 2},                                # the window line, in a run now
	{"middle": 2},
	# The draft's combos: daily small prizes (batches of 20 with CHAIN), the
	# astronomical one (after ten boxes cleared), FLARE ONLY on BIG FISH.
	{"magnet": 2, "penny": 2, "stacker": 1, "multi": 2, "combo": 1},      # M13
	{"bigfish": 2, "bet": 3, "snowball": 1, "snow": 10},
	{"flare": 2, "bigfish": 2},
	{"prizes": 3, "bigfish": 2, "luck": 3, "fortune": 1, "closer": 2, "firstpull": 2, "snowball": 1},
	# The combo table (docs/perk_research.md section 5 part 14), a row each, for its
	# 期望回报 column.
	{"read1": 1, "bet": 3, "bigfish": 2},                                 # 猎大奖 (REEL IN is an item: not here)
	{"closer": 2, "firstpull": 2, "regular": 2, "read3": 1},              # 清盒
	{"magnet": 2, "penny": 2, "stacker": 1, "multi": 2, "combo": 2},      # 小奖 (M13)
	{"magnet": 2, "penny": 2, "stacker": 1},                              # 小奖 in a run now
	{"insurance": 2, "pity": 2, "form": "kabawk"},                        # 保险 (on Ka-Bawk!)
	{"allin": 1, "streak": 1, "read1": 1},                                # 梭哈 (needs STREAK 1)
	{"streak": 2, "magnet": 2, "multi": 2, "combo": 1},                   # 连庄 (M13)
	{"streak": 2, "magnet": 2},                                           # 连庄 in a run now
	{"savings": 3, "lowrate": 2, "shark": 2, "worth": 1},                 # 钱生钱 (NET WORTH needs cash: 0 here)
	{"seal": 2, "snowball": 1, "snow": 10, "bet": 3},                     # 封盒 (SEAL itself does nothing here)
	{"read1": 1, "allin": 1, "streak": 1},                                # 跨：信息换胜率
	{"magnet": 2, "insurance": 2, "pity": 2, "form": "kabawk"},           # 跨：确定性叠大奖票
	# The line that wins more often (section 15): CONSOLATION adds a little, PACKED and
	# CRUMBS alone add nothing; with PENNY JAR, CHAIN and STREAK they do.
	{"consolation": 1}, {"consolation": 2}, {"packed": 1}, {"packed": 2}, {"crumbs": 1}, {"crumbs": 2},
	{"packed": 2, "penny": 2, "consolation": 2},
	{"crumbs": 2, "multi": 2, "combo": 2},                                   # M13
	{"crumbs": 2, "consolation": 2, "streak": 2, "multi": 2, "combo": 1},    # M13
	# How they stack with PENNY JAR and STREAK (G, 2026-11-07: PACKED must not make
	# PENNY JAR much stronger), each beside the same without it.
	{"penny": 2}, {"packed": 2, "penny": 2}, {"crumbs": 2, "penny": 2},
	{"penny": 2, "streak": 2}, {"packed": 2, "penny": 2, "streak": 2},
]
## Perk levels the churn table (churn_return) prints: CHURN tickets a box, then NEW BOX.
const CHURN_SETS := [{}, {"regular": 2}, {"firstpull": 1, "regular": 2}, {"firstpull": 2, "regular": 2}]
## A day at the machine has no limit; a bot stops after this many tickets so that a
## run always ends.
const DAY_CAP := 6000
const BATCH := 25
const GAMBLE_DAY := 25   ## the gamble bot works when its cash is less than this many tickets
const HIGH_ROLLER_CASH := 25   ## a bot buys a level of HIGH ROLLER only if its cash then holds this many tickets (G: 20 to 30)
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
	var idle := 0   # days the bot went to the machine (it chose to) and bought nothing
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
		if wants_play and _can_buy(e, price):
			run.play(e)
			if _play_day(run, e, m, rng, bot, line) == 0 and run.playing() and run.layer == layer:
				idle += 1
		elif not run.work(e) and run.play(e):
			_play_day(run, e, m, rng, bot, line)
		if run.playing() and run.layer == layer:
			run.end_day(e)
		if run.playing() and run.layer != layer:
			m = run.new_machine(base_forms, true)
		assert(e.balanced(), "the ledger must balance")
	return {"status": run.status, "layer": run.layer, "days": int(run.stats.days), "tickets": int(run.stats.tickets),
		"cash": e.cash, "spent": e.spent, "won": e.won, "balanced": e.balanced(), "stats": run.stats.duplicate(),
		"idle_days": idle}


## Whether the slot can turn this money into a ticket at `price` (the machine's
## cheapest): the credit or the tab already does, or the cash with the credit makes one,
## fed as bills and, under the smallest bill, as coins (Economy.coins_for, G 2026-11-07;
## before that the coins under a bill were stuck, and the bots "played" days at the
## machine buying nothing). Every bot asks this.
static func _can_buy(e: Economy, price: int) -> bool:
	return e.can_buy(price) or e.cash + e.credit >= price


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
## paid (and pays it), the money runs out, or the day's cap is reached. The churn bot
## changes the box after every CHURN tickets when it can pay the fee. A column the money
## cannot buy a ticket of gives way to the cheapest. Returns the tickets bought.
static func _play_day(run: RunState, e: Economy, m: MachineLogic, rng: RandomNumberGenerator, bot: String,
		line: Dictionary) -> int:
	var col := _column(m, rng, line.get("forms", []))
	if not _can_buy(e, m.price(col)):
		for i in m.forms.size():
			if m.price(i) == m.min_price():
				col = i
				break
	var borrows := bot == "borrow"
	var churn := bot == "churn"
	var per := CHURN if churn else BATCH
	var bought := 0
	var layer := run.layer
	while bought < DAY_CAP:
		if run.can_pay(e):
			run.pay(e, m)
			return bought
		var price := m.price(col)
		_feed(e, price * per, m.min_price())
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
			return bought
		if churn and m.boxes[col].cursor < m.boxes[col].size:
			if e.cash < run.change_fee():
				e.cash_out()
			run.change_box(e, m, col)
	e.cash_out()
	return bought


## Opens tickets bought: in batches of QUICK HANDS' size when the run has it (asked
## before each batch: with ALL IN it stops at the window's end), else one at a time.
## After every opening, ALL IN (_push).
static func _open(run: RunState, e: Economy, held: Array) -> void:
	if run.batch_size() <= 0:
		for en in held:
			run.open_ticket(e, en)
			_push(run, e)
		return
	var k := 0
	while k < held.size():
		var n := run.batch_size()
		run.open_batch(e, held.slice(k, k + n))
		_push(run, e)
		k += n


## A bot's ALL IN: stake the window just closed whenever it can, while the stake is
## under half its cash.
static func _push(run: RunState, e: Economy) -> void:
	if run.can_push(e) and run.push_offer() * 2 < e.cash:
		run.push(e)


## The perks bot's round of offers: the cheapest it can pay with half its cash, again
## and again; then the offers are closed.
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


## The work line's morning: one level of SAVINGS off the shelf when the layer allows it
## and the cash is there (RunConfig.line_buys). The offers are left alone.
static func _save(run: RunState, e: Economy) -> void:
	if RunConfig.line_buys(run.level(RunConfig.SAVINGS) + 1, run.layer):
		run.buy_perk(RunConfig.SAVINGS, e)


## A build bot's morning (LINES): its shelf perks, every level it can pay with its
## share of the cash (SAVINGS as the work line buys it); then the best of its dealt
## perks offered by the same rule, again and again; then the offers are closed (an
## item if nothing was bought). HIGH ROLLER only while the cash left after it holds
## HIGH_ROLLER_CASH tickets at the new bet (_rolls).
static func _build(run: RunState, e: Economy, m: MachineLogic, line: Dictionary) -> void:
	var share := float(line.get("share", 0.6))
	var prefs: Array = line.get("perks", [])
	var keep: int = int(line.get("reserve", 0)) * m.min_price()
	for id in line.get("shelf", []):
		if id == RunConfig.SAVINGS:
			_save(run, e)
			continue
		var g := 0
		while g < 5:
			g += 1
			var p := run.perk_price(id)
			if p <= 0 or p > e.cash * share or (id == "bet" and not _rolls(run, e, m)) or not run.buy_perk(id, e):
				break
		run.apply(m)
	var guard := 0
	while run.offers_open and guard < 10:
		guard += 1
		var best := -1
		for k in run.offers.size():
			var id := str(run.offers[k])
			var p := run.perk_price(id)
			if prefs.has(id) and p > 0 and p <= e.cash * share and e.cash - p >= keep \
					and (best < 0 or prefs.find(id) < prefs.find(str(run.offers[best]))):
				best = k
		if best < 0 or not run.buy_offer(best, e):
			break
		run.apply(m)
	run.close_offers(true)


## Whether the next level of HIGH ROLLER leaves the cash, once it is paid, with
## HIGH_ROLLER_CASH tickets of the machine's cheapest form at the new bet (G: 20 to 30,
## not a hundred, or nobody could buy it in the first layer).
static func _rolls(run: RunState, e: Economy, m: MachineLogic) -> bool:
	var p := run.catalog.perk("bet")
	var lv := run.level("bet")
	if lv >= p.levels.size():
		return false
	var price := m.min_price() / m.bet * int(p.levels[lv].value)
	return e.cash - run.perk_price("bet") >= HIGH_ROLLER_CASH * price


## Moves cash into credit through the bill slot until `want` is there or no bill fits;
## then, under the smallest bill, the coins for whole tickets at `price` (the cheapest).
static func _feed(e: Economy, want: int, price: int) -> void:
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
			# Under the smallest bill: the coins, whole tickets at the cheapest price.
			if e.insert_coins(price):
				e.step_bill(Economy.BILL_TIME)
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


## One run as the row tests/fixtures/sim_baseline.json keeps (written by
## `sim_runs --baseline=`, compared by test_bots_match_the_baseline): the run's
## outcome and the few stats that show how it was played. status is RunState's
## string ("cleared" / "failed"); everything else is an int.
static func baseline_row(result: Dictionary) -> Dictionary:
	var s: Dictionary = result.stats
	return {"status": str(result.status), "layer": int(result.layer), "days": int(result.days),
		"tickets": int(result.tickets), "cash": int(result.cash), "spent": int(result.spent),
		"won": int(result.won), "idle_days": int(result.idle_days), "perks": int(s.perks),
		"layers_cleared": int(s.layers_cleared), "best_prize": int(s.best_prize), "fees": int(s.fees)}


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
## every form bought out at stake 1 and at the bet, perks' bonuses and the
## last-sale prize included. The boxes load through the machine, so luck counts too.
## With QUICK HANDS the tickets are opened in batches of its size (at most BATCH), so
## CHAIN and ENCORE count; SNOWBALL grows as boxes are cleared; STREAK counts its
## windows. The cash is kept at zero (the ledger is not kept here), so NET WORTH adds
## nothing. With ALL IN every window that can be staked is (the stake counts as
## spent, the x3 as won). Pass one form in `base_forms`, or a "form" key in
## `perk_levels`, for that form's return alone.
static func box_return(base_forms: Array, perk_levels: Dictionary, boxes: int, seed_prefix := "EV") -> float:
	var run := RunState.start(RunConfig.standard(), seed_prefix, ["diner"])
	run.perks = perk_levels.duplicate()
	run.snow = int(run.perks.get("snow", 0))
	run.perks.erase("snow")
	if run.perks.has("form"):
		var only := str(run.perks.form)
		run.perks.erase("form")
		base_forms = base_forms.filter(func(f): return f.id == only)
	var pushes := run.effect("all_in") > 0
	var e := run.new_economy()
	e.cash = 0
	var m := run.new_machine(base_forms, true)
	var spent := 0
	var won := 0
	var batch := run.batch_size() > 0
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
			# Asked each ticket: with ALL IN the batch stops at the window's end.
			var n := mini(BATCH, run.batch_size()) if batch else 1
			if held.size() >= n or m.boxes[col].cursor >= m.boxes[col].size:
				var before := e.won
				if batch:
					run.open_batch(e, held)
				else:
					run.open_ticket(e, held[0])
				won += e.won - before
				held = []
				e.cash = 0
				if pushes and run.window_n == 0 and run.push_stake == 0 and run.push_offer() > 0:
					e.cash = run.push_offer()
					spent += e.cash
					run.push(e)
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


## ALL IN's odds on each form, no perks, stake 1: `boxes` boxes of the form in the
## run's model, their tickets opened in order in windows of Catalog.WINDOW (the boxes
## one after another). Of the windows after one that paid, the share whose printed
## prizes reach its bar (the form's Catalog.all_in_share, or `shares`' {form id:
## percent} to try another; the push wins). Returns [{form, p, windows, share}]
## (windows: how many were counted).
static func push_odds(base_forms: Array, boxes: int, seed_prefix := "PU", shares := {}) -> Array:
	var model := RunConfig.standard().box_model(0)
	var out := []
	for base: FormDef in base_forms:
		var f := base.shaped()
		var share := int(shares.get(f.id, Catalog.all_in_share(f.uid())))
		var prev := -1
		var sum := 0
		var n := 0
		var counted := 0
		var beat := 0
		for b in boxes:
			var box := BoxGenerator.build(f, "%s-%d" % [seed_prefix, b], model, true)
			for t in box.tickets:
				sum += maxi(0, int(t.prize))
				n += 1
				if n < Catalog.WINDOW:
					continue
				if prev > 0:
					counted += 1
					if sum >= Catalog.all_in_bar(prev * share):
						beat += 1
				prev = sum
				sum = 0
				n = 0
		out.append({"form": f.id, "p": float(beat) / counted if counted > 0 else 0.0, "windows": counted, "share": share})
	return out
