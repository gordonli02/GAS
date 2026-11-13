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
##             when it can be, else stay (the next batch's size, 0 leaves), items
##             ("machine"), feed the slot (refill when it cannot buy: borrow or leave),
##             sell and open the batch (push after every opening), box
##   evening   the day ends; a layer paid brings a new machine

## A day at the machine has no limit; a bot stops after this many tickets so that a
## run always ends.
const DAY_CAP := 6000


## One run of the bot `spec` (SimBots.spec). Returns {status, layer (0-based, where it
## ended), days, tickets, cash, spent, won, balanced, stats, idle_days}. The same spec,
## forms, seed and config always give the same run.
static func play(spec: Dictionary, base_forms: Array, seed_text: String, config: RunConfig = null) -> Dictionary:
	if config == null:
		config = RunConfig.standard()
	var ctx := SimCtx.new()
	ctx.spec = spec
	ctx.rng = RandomNumberGenerator.new()
	ctx.rng.seed = hash(seed_text + "|" + str(spec.name))
	ctx.run = RunState.start(config, seed_text, ["diner", "bar", "bingo"])
	ctx.e = ctx.run.new_economy()
	ctx.m = ctx.run.new_machine(base_forms, true)
	var run := ctx.run
	var e := ctx.e
	var guard := 0
	var idle := 0   # days the bot went to the machine (it chose to) and bought nothing
	while run.playing() and guard < 1000:
		guard += 1
		ctx.start_day()
		var layer := run.layer
		SimBlocks.perks(ctx)
		SimBlocks.items(ctx, "morning")
		if SimBlocks.enter(ctx) and can_buy(e, ctx.m.min_price()):
			run.play(e)
			if day(ctx) == 0 and run.playing() and run.layer == layer:
				idle += 1
		elif not run.work(e) and run.play(e):
			day(ctx)
		if run.playing() and run.layer == layer:
			run.end_day(e)
		if run.playing() and run.layer != layer:
			ctx.m = run.new_machine(base_forms, true)
		assert(e.balanced(), "the ledger must balance")
	return {"status": run.status, "layer": run.layer, "days": int(run.stats.days), "tickets": int(run.stats.tickets),
		"cash": e.cash, "spent": e.spent, "won": e.won, "balanced": e.balanced(), "stats": run.stats.duplicate(),
		"idle_days": idle}


## A day at the machine: one column (SimBlocks.column), then batches until the layer
## can be paid (and is), the bot leaves (stay 0, or the money runs out and it does not
## refill), or DAY_CAP. Returns the tickets bought.
static func day(ctx: SimCtx) -> int:
	var run := ctx.run
	var e := ctx.e
	ctx.col = SimBlocks.column(ctx)
	var layer := run.layer
	while ctx.bought < DAY_CAP:
		var m := ctx.m
		if run.can_pay(e):
			run.pay(e, m)
			return ctx.bought
		var per := SimBlocks.stay(ctx)
		if per <= 0:
			break
		SimBlocks.items(ctx, "machine")
		var col := ctx.col
		var price := m.price(col)
		feed(e, price * per, m.min_price())
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
