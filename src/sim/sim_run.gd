class_name SimRun
extends RefCounted
## One run of a bot, by the run's own rules (RunState, Economy, MachineLogic), with
## tickets sold and opened at once instead of through the motor, the tray and the
## table. The loop is the day's skeleton; every choice in it is a block of the bot's
## spec (SimBlocks, SimBots):
##   morning   perks, then items ("morning")
##   enter     to the machine when the bot wants it and the slot can sell it a ticket
##             (can_buy), else work (a bot that cannot work plays)
##   machine   a column; then, until the layer is paid or the bot leaves: pay the layer
##             when it can be and the stay block's pay agrees, else stay (the next batch's size, 0 leaves), items
##             ("machine"), feed the slot (the stay block's feed; refill when it cannot
##             buy: borrow or leave), sell and open the batch (push after every
##             opening), box
##   evening   the day ends; a layer paid brings a new machine
## A spec's `given` perks ({id: level}) are held from the start, free (the "given
## cards" test, docs/roadmap.md M9.8 step 1 stage 3), and its `bonus` dollars are in the
## pocket from the start, as a prize (the rounds probe's plenty of cash); only the
## simulator does these.

## A day at the machine has no limit; a bot stops after this many tickets so that a
## run always ends.
const DAY_CAP := 6000


## One run of the bot `spec` (SimBots.spec). Returns {status, layer (0-based, where it
## ended), days, tickets, cash, spent, won, balanced, stats, idle_days} and the
## measures (docs/roadmap.md 七.3, 七.5, 十二.6):
##   perks   {perk id: {level, day (the run's day it was bought, 1-based), tickets
##           (bought while it was held)}} for every perk held at the end
##   fired, fired_pct  RunState's (what the perks did; the percents they added)
##   carry   for each layer paid but the last: the cash carried into the next layer
##           over that layer's due (index 0: 1 to 2, 1: 2 to 3)
##   death   a failed run's: {layer (1-based), day (of the layer), cash, due, short (due
##           less what the cash and credit could pay), loan (owed), perks ({id: level}),
##           shifts, play_days, tickets (these three in that layer), last_day_tickets};
##           {} for a run that did not fail
##   held_by for each layer the run played: the perks held ({id: level}) when it ended
##           there (paid, or the run failed in it)
##   offered_by  parallel to held_by: the perks dealt as a card by then ({id: times},
##           RunState.offered: every round, reroll and reward round, from the run's start)
##   rounds  {morning, reward, rerolls, free_rerolls}: the rounds dealt in the run, the
##           rerolls made and, of them, the free ones (RunState.stats)
##   counters  what the bot's blocks counted (SimCtx.counters)
## The same spec, forms, seed and config always give the same run.
static func play(spec: Dictionary, base_forms: Array, seed_text: String, config: RunConfig = null) -> Dictionary:
	if config == null:
		config = RunConfig.standard()
	var ctx := SimCtx.new()
	ctx.spec = spec
	ctx.rng = dice(seed_text)
	ctx.run = RunState.start(config, seed_text, ["diner", "bar", "bingo"])
	give(ctx.run, spec.params.get("given", {}))
	ctx.e = ctx.run.new_economy()
	if int(spec.params.get("bonus", 0)) > 0:
		ctx.e.bonus(int(spec.params.bonus))
	ctx.m = ctx.run.new_machine(base_forms, true)
	var run := ctx.run
	var e := ctx.e
	var guard := 0
	var idle := 0   # days the bot went to the machine (it chose to) and bought nothing
	var held := {}  # perk id -> {day, tickets: stats.tickets when it was bought}
	var carry := []
	var held_by := []
	var offered_by := []
	var at_layer := _layer_mark(run)
	while run.playing() and guard < 1000:
		guard += 1
		ctx.start_day()
		var layer := run.layer
		SimBlocks.perks(ctx)
		_note_perks(run, held)
		SimBlocks.items(ctx, "morning")
		if SimBlocks.enter(ctx) and can_buy(e, ctx.m.min_price()):
			run.play(e)
			if day(ctx) == 0 and run.playing() and run.layer == layer:
				idle += 1
		elif not run.work(e) and run.play(e):
			day(ctx)
		_note_perks(run, held)
		if run.playing() and run.layer == layer:
			run.end_day(e)
		if not run.playing() or run.layer != layer:
			held_by.append(run.perks.duplicate())
			offered_by.append(run.offered.duplicate())
		if run.playing() and run.layer != layer:
			carry.append(float(e.cash) / maxi(1, run.due()))
			at_layer = _layer_mark(run)
			ctx.m = run.new_machine(base_forms, true)
		assert(e.balanced(), "the ledger must balance")
	var perks := {}
	for id in run.perks:
		var h: Dictionary = held.get(id, {"day": 0, "tickets": 0})
		perks[id] = {"level": run.level(id), "day": int(h.day), "tickets": int(run.stats.tickets) - int(h.tickets)}
	var death := {}
	if run.status == RunState.FAILED:
		death = {"layer": run.layer + 1, "day": run.day, "cash": e.cash, "due": run.due(),
			"short": run.due() - (e.cash + e.credit - e.tab), "loan": run.loan_due, "perks": run.perks.duplicate(),
			"shifts": run.shifts, "play_days": int(run.stats.play_days) - int(at_layer.play_days),
			"tickets": int(run.stats.tickets) - int(at_layer.tickets), "last_day_tickets": ctx.bought}
	return {"status": run.status, "layer": run.layer, "days": int(run.stats.days), "tickets": int(run.stats.tickets),
		"cash": e.cash, "spent": e.spent, "won": e.won, "balanced": e.balanced(), "stats": run.stats.duplicate(),
		"idle_days": idle, "perks": perks, "fired": run.fired.duplicate(), "fired_pct": run.fired_pct.duplicate(),
		"carry": carry, "death": death, "held_by": held_by, "offered_by": offered_by, "counters": ctx.counters.duplicate(),
		"rounds": {"morning": int(run.stats.rounds), "reward": int(run.stats.reward_rounds), "rerolls": int(run.stats.rerolls),
			"free_rerolls": int(run.stats.free_rerolls)}}


## The `given` perks ({id: level}) put on a run before its first day, free (nothing is
## paid or counted as bought), with the requirements they lack at the level asked (of
## `requires_any`, the first), so the state is one a run could reach; the day's round
## and upgrade slots are dealt again for what it now holds (the first deal's cards are no
## longer counted as offered; the round is still counted once). Only the simulator does this.
static func give(run: RunState, given: Dictionary) -> void:
	if given.is_empty():
		return
	for id in given:
		run.perks[id] = maxi(run.level(id), int(given[id]))
	var guard := 0
	var short := true
	while short and guard < 10:
		guard += 1
		short = false
		for id in run.perks.keys():
			var p := run.catalog.perk(id)
			var need: Dictionary = p.get("requires", {}).duplicate()
			var any: Dictionary = p.get("requires_any", {})
			if not any.is_empty() and not any.keys().any(func(k): return run.level(k) >= int(any[k])):
				need[any.keys()[0]] = any[any.keys()[0]]
			for k in need:
				if run.level(k) < int(need[k]):
					run.perks[k] = int(need[k])
					short = true
	run.offers = run.deal_offers()
	run.offers_open = not run.offers.is_empty()
	run.offered = {}
	for id in run.offers:
		run.offered[id] = 1
	run.upgrades = run.deal_upgrades()


## A run's dice for the bot (SimCtx.rng). Common random numbers (docs/roadmap.md 七.6):
## they are the seed's alone, not the bot's, so two bots (or two variants of one) on a
## seed draw the same dice, as they already load the same boxes; a difference between
## them is then their play's.
static func dice(seed_text: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text + "|bot")
	return rng


## The stats a layer's death report counts from (where they stood when it began).
static func _layer_mark(run: RunState) -> Dictionary:
	return {"play_days": int(run.stats.play_days), "tickets": int(run.stats.tickets)}


## Perks the run holds that `held` has not seen: bought today (the run's day, 1-based,
## and the tickets bought before it, so a report can count the tickets it was held for).
static func _note_perks(run: RunState, held: Dictionary) -> void:
	for id in run.perks:
		if not held.has(id) and run.level(id) > 0:
			held[id] = {"day": int(run.stats.days) + 1, "tickets": int(run.stats.tickets)}


## A day at the machine: one column (SimBlocks.column), then batches until the layer
## can be paid (and is, when SimBlocks.pay says so), the bot leaves (stay 0, or the money runs out and it does not
## refill), or DAY_CAP. Returns the tickets bought.
static func day(ctx: SimCtx) -> int:
	var run := ctx.run
	var e := ctx.e
	ctx.day_money = e.cash + e.credit
	ctx.col = SimBlocks.column(ctx)
	var layer := run.layer
	while ctx.bought < DAY_CAP:
		var m := ctx.m
		if run.can_pay(e) and SimBlocks.pay(ctx):
			run.pay(e, m)
			return ctx.bought
		var per := SimBlocks.stay(ctx)
		if per <= 0:
			break
		SimBlocks.items(ctx, "machine")
		var col := ctx.col
		var price := m.price(col)
		SimBlocks.feed(ctx, price * per)
		if e.credit < price:
			if SimBlocks.refill(ctx):
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
		open_tickets(ctx, held)
		run.count_sales(sales, last, m.forms[col].uid())
		ctx.bought += sales
		if run.layer != layer:
			return ctx.bought
		SimBlocks.box(ctx)
	e.cash_out()
	return ctx.bought


## Opens tickets bought: in batches of QUICK HANDS' size when the run has it (asked
## before each batch: with ALL IN it stops at the window's end), else one at a time.
## After every opening, ALL IN (SimBlocks.push).
static func open_tickets(ctx: SimCtx, held: Array) -> void:
	var run := ctx.run
	if run.batch_size() <= 0:
		for en in held:
			run.open_ticket(ctx.e, en)
			SimBlocks.push(ctx)
		return
	var k := 0
	while k < held.size():
		var n := run.batch_size()
		run.open_batch(ctx.e, held.slice(k, k + n))
		SimBlocks.push(ctx)
		k += n


## Whether the slot can turn this money into a ticket at `price` (the machine's
## cheapest): the credit or the tab already does, or the cash with the credit makes one,
## fed as bills and, under the smallest bill, as coins (Economy.coins_for, G 2026-11-07;
## before that the coins under a bill were stuck, and the bots "played" days at the
## machine buying nothing). Every bot asks this.
static func can_buy(e: Economy, price: int) -> bool:
	return e.can_buy(price) or e.cash + e.credit >= price


## Moves cash into credit through the bill slot until `want` is there or no bill fits;
## then, under the smallest bill, the coins for whole tickets at `price` (the cheapest).
static func feed(e: Economy, want: int, price: int) -> void:
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
