class_name SimBlocks
extends RefCounted
## A bot's day cut into six blocks (docs/roadmap.md 七.2), each asked by the run's loop
## (SimRun) at its point of the day:
##   perks   the morning: the dealt offers and the shelf (perks)
##   items   using an item, in the morning and at the machine before each batch (items)
##   enter   go to the machine or work, borrowing first (enter); and, at the machine,
##           whether to borrow when the money runs short (refill)
##   column  which column to play (column); asked once a day
##   stay    how many tickets to buy next, 0 to leave (stay), asked before every batch;
##           and, after every opening, whether to stake ALL IN's window (push)
##   box     after every batch: change the box, or the column (box)
## Each block has a default (the first of its VARIANTS) and named variants; the bot's
## spec (SimBots) names the variant and gives the params it reads, so a variant's
## numbers live in the spec, not here.
##
## A block may only call into the run (RunState, Economy, MachineLogic) and set
## ctx.col; the loop does the rest (paying the layer, feeding the slot, selling,
## opening, counting).

## The variants of each block, the default first.
const VARIANTS := {
	"enter": ["play", "work", "gamble", "borrow"],
	"column": ["pick"],
	"stay": ["batches"],
	"perks": ["none", "savings", "cheapest", "skip", "line"],
	"items": ["none"],
	"box": ["keep", "churn"],
}


# --- enter -----------------------------------------------------------------------

## Whether the bot wants the machine today (the loop then checks the slot's rule,
## SimRun.can_buy, and works when it cannot pay). Variants:
##   play    always
##   work    never (it works; one that cannot work, NO WAY BACK, plays instead)
##   gamble  when the layer can be paid, or the cash with the credit holds `gamble_day`
##           tickets at the machine's cheapest price
##   borrow  always, and takes the whole house line first when the cash with the credit
##           cannot pay for one ticket
static func enter(ctx: SimCtx) -> bool:
	var run := ctx.run
	var e := ctx.e
	var price := ctx.m.min_price()
	match ctx.variant("enter"):
		"play":
			return true
		"work":
			return false
		"gamble":
			return run.can_pay(e) or e.cash + e.credit >= price * int(ctx.param("gamble_day"))
		"borrow":
			if e.cash + e.credit < price:
				while run.can_borrow():
					run.borrow(e)
			return true
	assert(false, "unknown enter variant")
	return true


## At the machine, the money fed cannot buy a ticket of today's column: true when the
## bot borrowed (the loop feeds again), false to leave. Only `borrow` borrows.
static func refill(ctx: SimCtx) -> bool:
	if ctx.variant("enter") == "borrow" and ctx.run.can_borrow():
		ctx.run.borrow(ctx.e)
		return true
	return false


# --- column ----------------------------------------------------------------------

## The column the bot plays today. Variants:
##   pick    one of the `forms` (FormDef.id) when the machine sells one, else any, at
##           random (one draw of the bot's dice); a column the money cannot buy a
##           ticket of gives way to the cheapest
static func column(ctx: SimCtx) -> int:
	match ctx.variant("column"):
		"pick":
			var m := ctx.m
			var forms: Array = ctx.param("forms")
			var cols := []
			for i in m.forms.size():
				if forms.has(m.forms[i].id):
					cols.append(i)
			var col: int
			if cols.is_empty():
				col = ctx.rng.randi() % m.forms.size()
			else:
				col = int(cols[ctx.rng.randi() % cols.size()])
			if not SimRun.can_buy(ctx.e, m.price(col)):
				for i in m.forms.size():
					if m.price(i) == m.min_price():
						col = i
						break
			return col
	assert(false, "unknown column variant")
	return 0


# --- stay ------------------------------------------------------------------------

## The tickets the bot buys next, asked before every batch (after the layer is paid
## when it can be); 0 leaves the machine. Variants:
##   batches  `batch` tickets every time (the loop's DAY_CAP ends the day)
static func stay(ctx: SimCtx) -> int:
	match ctx.variant("stay"):
		"batches":
			return int(ctx.param("batch"))
	assert(false, "unknown stay variant")
	return 0


## ALL IN, asked after every opening (SimRun.open_tickets): stake the window just
## closed whenever the card asks and the stake is under `push` of the cash (0: never).
static func push(ctx: SimCtx) -> void:
	match ctx.variant("stay"):
		"batches":
			if ctx.run.can_push(ctx.e) and ctx.run.push_offer() < ctx.e.cash * float(ctx.param("push")):
				ctx.run.push(ctx.e)
			return
	assert(false, "unknown stay variant")


# --- perks -----------------------------------------------------------------------

## The morning's offers and the shelf. Variants:
##   none      leaves everything alone (the offers stay open)
##   savings   the work line's morning: one level of SAVINGS off the shelf when the
##             layer allows it and the cash is there (RunConfig.line_buys)
##   cheapest  the cheapest offer that costs at most `share` of the cash, again and
##             again; then the offers are closed
##   skip      closes every round of offers for its item (never used)
##   line      the `shelf` perks, every level it can pay with `share` of the cash
##             (SAVINGS as `savings` buys it; HIGH ROLLER only while the cash left holds
##             `high_roller_cash` tickets at the new bet); then the first of the dealt
##             `perks` offered (in that order of preference), each while it costs at
##             most `share` of the cash and leaves `reserve` tickets of the cheapest
##             price; then the offers are closed (an item if nothing was bought)
static func perks(ctx: SimCtx) -> void:
	match ctx.variant("perks"):
		"none":
			return
		"savings":
			_save(ctx.run, ctx.e)
			return
		"cheapest":
			_cheapest(ctx)
			return
		"skip":
			ctx.run.close_offers(true)
			return
		"line":
			_line(ctx)
			return
	assert(false, "unknown perks variant")


static func _save(run: RunState, e: Economy) -> void:
	if RunConfig.line_buys(run.level(RunConfig.SAVINGS) + 1, run.layer):
		run.buy_perk(RunConfig.SAVINGS, e)


static func _cheapest(ctx: SimCtx) -> void:
	var run := ctx.run
	var e := ctx.e
	var share := float(ctx.param("share"))
	var guard := 0
	while run.offers_open and guard < 10:
		guard += 1
		var best := -1
		for k in run.offers.size():
			var p := run.perk_price(str(run.offers[k]))
			if p > 0 and p <= e.cash * share and (best < 0 or p < run.perk_price(str(run.offers[best]))):
				best = k
		if best < 0 or not run.buy_offer(best, e):
			break
		run.apply(ctx.m)
	run.close_offers(true)


static func _line(ctx: SimCtx) -> void:
	var run := ctx.run
	var e := ctx.e
	var m := ctx.m
	var share := float(ctx.param("share"))
	var prefs: Array = ctx.param("perks")
	var keep: int = int(ctx.param("reserve")) * m.min_price()
	for id in ctx.param("shelf"):
		if id == RunConfig.SAVINGS:
			_save(run, e)
			continue
		var g := 0
		while g < 5:
			g += 1
			var p := run.perk_price(id)
			if p <= 0 or p > e.cash * share or (id == "bet" and not _rolls(ctx)) or not run.buy_perk(id, e):
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
## `high_roller_cash` tickets of the machine's cheapest form at the new bet (G: 20 to
## 30, not a hundred, or nobody could buy it in the first layer).
static func _rolls(ctx: SimCtx) -> bool:
	var run := ctx.run
	var m := ctx.m
	var p := run.catalog.perk("bet")
	var lv := run.level("bet")
	if lv >= p.levels.size():
		return false
	var price := m.min_price() / m.bet * int(p.levels[lv].value)
	return ctx.e.cash - run.perk_price("bet") >= int(ctx.param("high_roller_cash")) * price


# --- items -----------------------------------------------------------------------

## Using an item, `at` "morning" (after the perks) or "machine" (before each batch).
## Variants:
##   none  never (no bot uses one today)
static func items(ctx: SimCtx, _at: String) -> void:
	match ctx.variant("items"):
		"none":
			return
	assert(false, "unknown items variant")


# --- box -------------------------------------------------------------------------

## After every batch bought and opened (the layer not paid): change the box, or set
## ctx.col to another column. Variants:
##   keep   nothing
##   churn  NEW BOX on today's column when its box is not finished, cashing out first
##          when the cash cannot pay the fee
static func box(ctx: SimCtx) -> void:
	match ctx.variant("box"):
		"keep":
			return
		"churn":
			var run := ctx.run
			var e := ctx.e
			var m := ctx.m
			if m.boxes[ctx.col].cursor < m.boxes[ctx.col].size:
				if e.cash < run.change_fee():
					e.cash_out()
				run.change_box(e, m, ctx.col)
			return
	assert(false, "unknown box variant")
