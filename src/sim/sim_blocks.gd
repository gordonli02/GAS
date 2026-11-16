class_name SimBlocks
extends RefCounted
## A bot's day cut into six blocks (docs/roadmap.md 七.2), each asked by the run's loop
## (SimRun) at its point of the day:
##   perks   the morning: the rounds of perk offers, the shelf and its upgrade slots (perks)
##   items   using and buying items: in the morning, after a shift, and at the machine
##           before each batch (items) and when leaving (one_more); CHEAT SHEET is
##           used in the perks block (_cheat), on a round's card
##   enter   go to the machine or work, borrowing first (enter); and, at the machine,
##           whether to borrow when the money runs short (refill)
##   column  which column to play (column); asked once a day
##   stay    how many tickets to buy next, 0 to leave (stay), asked before every batch;
##           whether to pay the layer when it can be (pay, asked first); how the money
##           goes into the slot for them (feed); and, after every opening, whether to
##           stake ALL IN's window (push)
##   box     after every batch: change the box, or the column (box)
## Each block has a default (the first of its VARIANTS) and named variants; the bot's
## spec (SimBots) names the variant and gives the params it reads, so a variant's
## numbers live in the spec, not here.
##
## A block may only call into the run (RunState, Economy, MachineLogic, BoxReading), set ctx.col
## and count in ctx.counters; the loop does the rest (paying the layer, selling,
## opening, counting), but for a RETURN SLIP's tickets, bought and given back unopened
## by the items block through SimRun.slip_rest.
##
## The line bots (M9.8 step 1, stage 3) share three rules, read by their variants:
##   the stop-loss  while the bot buys its line's perks (perks "core"), it leaves the
##                  machine once the day has cost `stop` of the money it came with, so
##                  the next morning still has money for the next card
##   the endgame    on the layer's last `endgame` days the stop-loss and the cash floor
##                  are off: it plays whatever it holds (it only goes to the machine
##                  then when working cannot reach the debt, enter "line")
##   small bills    they feed the slot the smallest bills that buy the batch, so the
##                  cash stays in the pocket (NET WORTH counts it, ALL IN is paid from it)
## And (M9.8 step 2, stage 2) the reroll, read by perks "line" and "core" (_reroll): a
## morning round with no card the bot would take is dealt again for its price, at most
## `rerolls` times, while the price is at most `reroll_share` of the cash and the cash
## left still buys a card it is rerolling for. `rerolls` 0 (the default) never rerolls.

## The variants of each block, the default first.
const VARIANTS := {
	"enter": ["play", "work", "gamble", "borrow", "line"],
	"column": ["pick", "clear", "top"],
	"stay": ["batches", "stop", "clear", "windows", "floor", "hunt"],
	"perks": ["none", "savings", "cheapest", "skip", "line", "core", "grab", "reach"],
	"items": ["none", "use", "blind"],
	"box": ["keep", "churn", "flare", "magnet"],
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
##   line    the line bots: with `work_out`, works when the money with a wage for every
##           day left (today's included) reaches what is due (the layer is then worked
##           out and paid on its last day); with stay "floor", works when the money
##           over the floor buys no ticket; else plays when it holds one of its `engine` perks
##           (unless `work_held` is 1) or does not buy perks (perks not "core"); else
##           works while the cash is under `work_below` (times the stake), to afford an
##           engine or (`work_held` 1, holding one) to come to the machine with a
##           bankroll, except on the layer's last `endgame` days
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
		"line":
			var left := run.days() - run.day + 1
			if int(ctx.param("work_out")) > 0 and run.can_work() \
					and e.cash + e.credit + run.shift_wage() * left >= run.due():
				return false
			if ctx.variant("stay") == "floor" and e.cash + e.credit - cash_floor(ctx) < price:
				return false
			if ctx.variant("perks") != "core" or (_engine(ctx) and int(ctx.param("work_held")) <= 0):
				return true
			return not (run.can_work() and left > int(ctx.param("endgame"))
				and e.cash < int(ctx.param("work_below")) * run.stake())
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
##   clear   the clearing line: the box with the fewest tickets left (the one already
##           started, the one the money can finish), among the `forms` when the
##           machine sells one; no dice
##   top     the jackpot line: without READ THE FLARE as `pick`. With it, a box whose
##           top prize is still in (the `forms` first, then any: BIG FISH doubles every
##           top), the fewest tickets left; when none has one, `pick`'s column, its box
##           changed until one does while the fee is worth it (top_box)
static func column(ctx: SimCtx) -> int:
	match ctx.variant("column"):
		"pick":
			return _pick(ctx)
		"clear":
			return _fewest_left(ctx, _cols(ctx, false))
		"top":
			if ctx.run.reading() < BoxReading.FLARE:
				return _pick(ctx)
			var c := _top_column(ctx)
			if c >= 0:
				return c
			c = _pick(ctx)
			top_box(ctx, c)
			return c
	assert(false, "unknown column variant")
	return 0


static func _pick(ctx: SimCtx) -> int:
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
		col = _cheap_col(ctx.m)
	return col


## The first column at the machine's cheapest price.
static func _cheap_col(m: MachineLogic) -> int:
	for i in m.forms.size():
		if m.price(i) == m.min_price():
			return i
	return 0


## The columns the money can buy a ticket of: the `forms`' when the machine sells one
## (all of them with `any`), else every one.
static func _cols(ctx: SimCtx, any: bool) -> Array:
	var m := ctx.m
	var forms: Array = ctx.param("forms")
	var own := []
	var all := []
	for i in m.forms.size():
		if not SimRun.can_buy(ctx.e, m.price(i)):
			continue
		all.append(i)
		if forms.has(m.forms[i].id):
			own.append(i)
	return own if not own.is_empty() and not any else all


## Tickets left in column `i`'s box (a box sold out counts as a fresh one: the next
## sale loads its successor).
static func left_in(m: MachineLogic, i: int) -> int:
	var box: TicketBox = m.boxes[i]
	return box.size - box.cursor if box.cursor < box.size else box.size


## Of `cols`, the one whose box has the fewest tickets left (the first of equals); the
## cheapest column when `cols` is empty.
static func _fewest_left(ctx: SimCtx, cols: Array) -> int:
	var best := -1
	for i in cols:
		if best < 0 or left_in(ctx.m, i) < left_in(ctx.m, best):
			best = i
	return best if best >= 0 else _cheap_col(ctx.m)


## Whether READ THE FLARE says column `i`'s box still holds a top prize (a box sold out
## reads as holding none).
static func top_in(ctx: SimCtx, i: int) -> bool:
	var box: TicketBox = ctx.m.boxes[i]
	return box.cursor < box.size and int(BoxReading.read(box).roles.top) > 0


## A column whose box still holds a top prize: the `forms`' first, then any; the
## fewest tickets left. -1 when none does (or the run cannot read the flare).
static func _top_column(ctx: SimCtx) -> int:
	for any in [false, true]:
		var cols := []
		for i in _cols(ctx, any):
			if ctx.run.reading() >= BoxReading.FLARE and top_in(ctx, i):
				cols.append(i)
		if not cols.is_empty():
			return _fewest_left(ctx, cols)
	return -1


## NEW BOX on column `col` until READ THE FLARE says its box holds a top prize, while the
## fee is at most `fee_max` tickets of the column and the cash (the credit cashed out
## first) pays it with a batch's money left over. A box sold out is left alone (its successor loads, unread, at the
## next sale, for nothing). Returns whether the box holds one now.
static func top_box(ctx: SimCtx, col: int) -> bool:
	var run := ctx.run
	var e := ctx.e
	var guard := 0
	while not top_in(ctx, col) and ctx.m.boxes[col].cursor < ctx.m.boxes[col].size and guard < 20:
		guard += 1
		var fee := run.change_fee()
		var price := ctx.m.price(col)
		if fee > int(ctx.param("fee_max")) * price or e.cash + e.credit - fee < int(ctx.param("batch")) * price:
			return false
		if e.cash < fee:
			e.cash_out()
		if not run.change_box(e, ctx.m, col):
			return false
	return top_in(ctx, col)


# --- stay ------------------------------------------------------------------------

## The tickets the bot buys next, asked before every batch (after the layer is paid
## when it can be and pay agrees); 0 leaves the machine. Variants:
##   batches  `batch` tickets every time (the loop's DAY_CAP ends the day)
##   stop     `batch` tickets, until the stop-loss
##   clear    the clearing line: `batch` tickets, never past the end of the box, until
##            the stop-loss, unless the money still finishes the box it is on
##   windows  the window line: the tickets that close the window (Catalog.WINDOW), so a
##            window is never left half open; it leaves for the stop-loss only on a
##            window's edge after a window without a winner (STREAK kept alive)
##   floor    the money line: `batch` tickets, as many as keep the cash with the credit
##            over `floor` (times the stake: NET WORTH pays by the cash in the pocket,
##            SAVINGS grows what is left at night), until the stop-loss
##   hunt     the jackpot line: as `stop`, and it pays the layer later (pay)
## Every variant but `batches` feeds the slot small bills (feed).
static func stay(ctx: SimCtx) -> int:
	var batch := int(ctx.param("batch"))
	match ctx.variant("stay"):
		"batches":
			return batch
		"stop", "hunt":
			return 0 if stopped(ctx) else batch
		"clear":
			var left := left_in(ctx.m, ctx.col)
			if stopped(ctx) and ctx.e.cash + ctx.e.credit < left * ctx.m.price(ctx.col):
				return 0
			return mini(batch, left)
		"windows":
			var run := ctx.run
			if run.window_n == 0 and stopped(ctx) and not _won_last(run):
				return 0
			return Catalog.WINDOW - run.window_n
		"floor":
			if stopped(ctx):
				return 0
			var over := ctx.e.cash + ctx.e.credit - cash_floor(ctx)
			return clampi(over / ctx.m.price(ctx.col), 0, batch)
	assert(false, "unknown stay variant")
	return 0


## Asked when the layer can be paid: true pays it now (every variant but `hunt`).
## `hunt`: JACKPOT HUNTER adds to every prize of the layer once a top prize came out in
## it, and a top prize mostly pays the layer at once, so while it is on (held, a top
## out this layer, not the endgame) the bot plays on, up to `hunt` tickets more today,
## with the money over what is due, and pays before that money is under a batch.
static func pay(ctx: SimCtx) -> bool:
	if ctx.variant("stay") != "hunt":
		return true
	var run := ctx.run
	if run.level("hunter") <= 0 or run.layer_tops <= 0 or endgame(ctx) or int(ctx.param("hunt")) <= 0:
		return true
	if ctx.e.cash + ctx.e.credit - run.due() < int(ctx.param("batch")) * ctx.m.price(maxi(0, ctx.col)):
		return true
	if ctx.payable_at < 0:
		ctx.payable_at = ctx.bought
	return ctx.bought - ctx.payable_at >= int(ctx.param("hunt"))


## Whether the last window closed today had a winner (STREAK's count, or its pay
## without STREAK).
static func _won_last(run: RunState) -> bool:
	if run.effect("streak_pct") > 0:
		return run.streak > 0
	return int(run.last_window.get("paid", 0)) > 0


## The stop-loss: the bot buys its line's perks (perks "core"), it is not the layer's
## endgame, and the money (cash and credit) is under the day's (SimCtx.day_money) less
## `stop` of it. `stop` 1 never stops.
static func stopped(ctx: SimCtx) -> bool:
	if ctx.variant("perks") != "core" or endgame(ctx):
		return false
	return ctx.e.cash + ctx.e.credit < ctx.day_money * (1.0 - float(ctx.param("stop")))


## The layer's last `endgame` days (today counted): the line bots play whatever they hold.
static func endgame(ctx: SimCtx) -> bool:
	return ctx.run.days() - ctx.run.day + 1 <= int(ctx.param("endgame"))


## The money line's cash floor in dollars (`floor` times the stake); 0 in the endgame.
static func cash_floor(ctx: SimCtx) -> int:
	return 0 if endgame(ctx) else int(ctx.param("floor")) * ctx.run.stake()


## Puts the money for `want` (the next batch at today's column) into the slot.
## `batches`: SimRun.feed (the biggest bill the cash holds first); the line variants:
## the smallest bill that makes up what is missing, else the biggest the cash holds,
## and under the smallest bill the coins (so the cash stays in the pocket).
static func feed(ctx: SimCtx, want: int) -> void:
	var e := ctx.e
	var price := ctx.m.min_price()
	if ctx.variant("stay") == "batches":
		SimRun.feed(e, want, price)
		return
	var guard := 0
	while e.credit < want and guard < 500:
		guard += 1
		var pick := 0
		for b in e.bills:
			if int(b) <= e.cash:
				pick = int(b)
				if pick >= want - e.credit:
					break
		if pick == 0:
			if e.insert_coins(price):
				e.step_bill(Economy.BILL_TIME)
			return
		e.insert(pick)
		e.step_bill(Economy.BILL_TIME)


## ALL IN, asked after every opening (SimRun.open_tickets): stake the window just
## closed whenever the card asks and the stake is under `push` of the cash (0: never);
## with `windows`, only on a window that paid at least `push_paid` tickets of the
## machine's cheapest price too.
static func push(ctx: SimCtx) -> void:
	var run := ctx.run
	if not run.can_push(ctx.e) or run.push_offer() >= ctx.e.cash * float(ctx.param("push")):
		return
	if ctx.variant("stay") == "windows" and int(ctx.param("push_paid")) > 0 \
			and run.push_offer() < int(ctx.param("push_paid")) * ctx.m.min_price():
		return
	run.push(ctx.e)


# --- perks -----------------------------------------------------------------------

## The morning: every round of perk offers that is up (after a layer is paid the reward
## rounds come first, then the morning's: RunState.offers_open stays true until they are
## all done), the shelf's perks and its upgrade slots. A round ends with its pick (one
## card) or given up for its item (RunState.skip_offers); `line` and `core` may reroll
## a morning round first (_reroll; `rerolls` 0, the default, never). Variants:
##   none      leaves everything alone: going to the machine or to work throws the
##             rounds away (RunState.play, work)
##   savings   the work line's morning: one level of SAVINGS off the shelf when the
##             layer allows it and the cash is there (RunConfig.line_buys); the rounds
##             as `none`
##   cheapest  a morning round: the cheapest card that costs at most `share` of the
##             cash, else the item; a reward round: the first card. Then any upgrade
##             slot that costs at most `share` of the cash
##   skip      every round given up for its item (which it never uses)
##   line      the `shelf` perks, every level it can pay with `share` of the cash
##             (SAVINGS as `savings` buys it; HIGH ROLLER only while the cash left holds
##             `high_roller_cash` tickets at the new bet); a morning round: the first of
##             its dealt `perks` offered (in that order of preference) that costs at most
##             `share` of the cash and leaves `reserve` tickets of the cheapest price,
##             else a reroll when _reroll allows (a card on its list it could take with
##             the cash left), else the item; a reward round: the first of its `perks`
##             among the cards (an upgrade card of one counts), else the item (it never
##             takes a card off its list: some would hurt it). Then an upgrade slot of a
##             perk on its list, within `share` and `reserve`
##   core      the line bots: the line's core first. While it holds none of its
##             `engine` perks it buys the first of them on the shelf it can, with all
##             its cash; then, still holding none, from a morning round the first engine
##             it can pay for with all its cash, else a reroll when _reroll allows (an
##             engine it could pay for with the cash left), else the item; from a reward
##             round the first engine (free), else the first of its `perks` there, else
##             the item. Once it holds one, as `line` (the stop-loss keeps money for the
##             next card, stay)
##   grab      the rounds probe's bot (SimProbes "rounds"): every round, every card
##             tried, rerolls tried before and after, in every order; it counts in
##             ctx.counters what a sound run must refuse (grab)
##   reach     the deal's ceiling (SimReport.reach, SimBots.reach_spec: plenty of cash):
##             the `shelf` perks (level 1 each, a requirement bought first); then from
##             every round the first of its `perks` (the line's dealt core) it does not
##             hold; on a morning round with none, up to `rerolls` rerolls while a core
##             card it lacks could be dealt (no share limit), else the item. Counted in
##             ctx.counters: "reach_round", the rounds dealt (morning and reward) when the
##             last core card was taken; "reroll_cost", dollars paid for rerolls
static func perks(ctx: SimCtx) -> void:
	var v := ctx.variant("perks")
	match v:
		"none":
			return
		"savings":
			_save(ctx.run, ctx.e)
			return
		"skip":
			var g := 0
			while ctx.run.offers_open and g < 50:
				g += 1
				ctx.run.skip_offers()
			return
		"grab":
			grab(ctx)
			return
		"reach":
			reach(ctx)
			return
		"cheapest", "line", "core":
			pass
		_:
			assert(false, "unknown perks variant")
			return
	if v == "core" and not _engine(ctx):
		_shelf_engine(ctx)
	var lined := v == "line" or v == "core" and _engine(ctx)
	if lined:
		_shelf(ctx)
	var guard := 0
	while ctx.run.offers_open and guard < 50:
		guard += 1
		if _cheat(ctx, v):
			continue
		if v == "cheapest":
			_cheapest_round(ctx)
		elif v == "line" or _engine(ctx):
			_line_round(ctx)
		else:
			_engine_round(ctx)
	if v == "cheapest":
		_upgrades(ctx, false)
	elif v == "line" or _engine(ctx):
		_upgrades(ctx, true)


## Whether the run holds one of the bot's `engine` perks.
static func _engine(ctx: SimCtx) -> bool:
	for id in ctx.param("engine"):
		if ctx.run.level(id) > 0:
			return true
	return false


## CHEAT SHEET (items "use"), asked before each morning round of perks `cheapest`,
## `line` and `core`: the dearest card of the round the bot wants (`cheapest`: any;
## `core` holding no engine: its `engine` perks; else its `perks`) taken for free, the
## sheet used up (a free card saves the most on the dearest). True when it took one
## (the round is over).
static func _cheat(ctx: SimCtx, v: String) -> bool:
	var run := ctx.run
	if ctx.variant("items") != "use" or run.held("cheat") <= 0 or run.offer_reward or not run.offers_open:
		return false
	var wanted: Array = run.offers
	if v == "core" and not _engine(ctx):
		wanted = ctx.param("engine")
	elif v != "cheapest":
		wanted = ctx.param("perks")
	var ks := []
	for k in run.offers.size():
		if wanted.has(str(run.offers[k])) and run.perk_price(str(run.offers[k])) > 0:
			ks.append(k)
	ks.sort_custom(func(a, b): return run.perk_price(str(run.offers[a])) > run.perk_price(str(run.offers[b])) or \
		run.perk_price(str(run.offers[a])) == run.perk_price(str(run.offers[b])) and a < b)
	for k in ks:
		if run.buy_offer(k, ctx.e, true):
			run.apply(ctx.m)
			_count(ctx, "item_cheat")
			return true
	return false


## The first of the `engine` perks on the shelf the cash pays for.
static func _shelf_engine(ctx: SimCtx) -> void:
	var run := ctx.run
	for id in ctx.param("engine"):
		if run.shelf_perks().has(id) and run.buy_perk(id, ctx.e):
			run.apply(ctx.m)
			return


## A round, holding no engine: the first of the `engine` perks among its cards that
## the cash pays for (or free, on a reward round); on a morning round with none, a
## reroll when _reroll allows (an engine the cash left could pay for), then again; on a
## reward round with none, the first of its `perks` there (free); else the item.
static func _engine_round(ctx: SimCtx) -> void:
	var run := ctx.run
	var e := ctx.e
	var pays := func(id: String, left: int) -> bool: return run.perk_price(id) > 0 and run.perk_price(id) <= left
	var k := _first_of(ctx, ctx.param("engine"))
	while k < 0 and _reroll(ctx, ctx.param("engine"), pays):
		k = _first_of(ctx, ctx.param("engine"))
	if k < 0 and run.offer_reward:
		k = _first_of(ctx, ctx.param("perks"))
	if k >= 0 and run.buy_offer(k, e):
		run.apply(ctx.m)
		return
	run.skip_offers()


## The card of the round up that is the first of `ids` (in that order) the run can take
## now (RunState.can_buy_offer: free on a reward round, else from the cash); -1: none.
static func _first_of(ctx: SimCtx, ids: Array) -> int:
	for id in ids:
		var k := ctx.run.offers.find(id)
		if k >= 0 and ctx.run.can_buy_offer(k, ctx.e):
			return k
	return -1


## The reroll (perks "line" and "core"), asked when the morning round up holds no card
## the bot would take: true when it paid for another deal. It rerolls only a morning
## round (never a reward round), fewer than `rerolls` times a round, while the price is
## at most `reroll_share` of the cash, and only when the cash left once it is paid
## still buys a card it is rerolling for: one of `wanted` that could be dealt
## (RunState.offerable) and for which `takes(id, cash_left)` holds (the same test the
## bot's pick makes of a card, on the cash left). Counted in ctx.counters
## "reroll_cost" (dollars).
static func _reroll(ctx: SimCtx, wanted: Array, takes: Callable) -> bool:
	var run := ctx.run
	var e := ctx.e
	if run.offer_reward or not run.offers_open or run.offer_rerolls >= int(ctx.param("rerolls")):
		return false
	var price := run.reroll_price()
	if price > e.cash * float(ctx.param("reroll_share")) or not run.can_reroll_offers(e):
		return false
	var dealable := run.offerable()
	var worth := false
	for id in wanted:
		if dealable.has(id) and takes.call(id, e.cash - price):
			worth = true
			break
	if not worth or not run.reroll_offers(e):
		return false
	ctx.counters["reroll_cost"] = int(ctx.counters.get("reroll_cost", 0)) + price
	return true


static func _save(run: RunState, e: Economy) -> void:
	if RunConfig.line_buys(run.level(RunConfig.SAVINGS) + 1, run.layer):
		run.buy_perk(RunConfig.SAVINGS, e)


## A round for `cheapest`: on a reward round the first card; on a morning round the
## cheapest card within `share` of the cash; else the item.
static func _cheapest_round(ctx: SimCtx) -> void:
	var run := ctx.run
	var e := ctx.e
	var share := float(ctx.param("share"))
	var best := -1
	if run.offer_reward:
		best = 0
	else:
		for k in run.offers.size():
			var p := run.perk_price(str(run.offers[k]))
			if p > 0 and p <= e.cash * share and (best < 0 or p < run.perk_price(str(run.offers[best]))):
				best = k
	if best >= 0 and run.buy_offer(best, e):
		run.apply(ctx.m)
		return
	run.skip_offers()


## The `shelf` perks for `line`: every level it can pay with `share` of the cash.
static func _shelf(ctx: SimCtx) -> void:
	var run := ctx.run
	var e := ctx.e
	var share := float(ctx.param("share"))
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
		run.apply(ctx.m)


## A round for `line`: the first of its `perks` among the cards (in its order of
## preference), within `share` and `reserve` on a morning round, free on a reward
## round; on a morning round with none, a reroll when _reroll allows (a card on its list
## it could take with the cash left), then again; else the item.
static func _line_round(ctx: SimCtx) -> void:
	var run := ctx.run
	var e := ctx.e
	var takes := func(id: String, left: int) -> bool: return SimBlocks._line_takes(ctx, id, left)
	var best := _line_pick(ctx)
	while best < 0 and _reroll(ctx, ctx.param("perks"), takes):
		best = _line_pick(ctx)
	if best >= 0 and run.buy_offer(best, e):
		run.apply(ctx.m)
		return
	run.skip_offers()


## The card `line` takes from the round up: the first of its `perks` among the cards
## that _line_takes on the cash (any on a reward round, free); -1: none.
static func _line_pick(ctx: SimCtx) -> int:
	var run := ctx.run
	var prefs: Array = ctx.param("perks")
	var best := -1
	for k in run.offers.size():
		var id := str(run.offers[k])
		if not prefs.has(id) or run.perk_price(id) <= 0:
			continue
		if not run.offer_reward and not _line_takes(ctx, id, ctx.e.cash):
			continue
		if best < 0 or prefs.find(id) < prefs.find(str(run.offers[best])):
			best = k
	return best


## Whether `line` buys perk `id` on a morning round with `cash`: it costs at most
## `share` of it and leaves `reserve` tickets of the cheapest price.
static func _line_takes(ctx: SimCtx, id: String, cash: int) -> bool:
	var p := ctx.run.perk_price(id)
	var keep: int = int(ctx.param("reserve")) * ctx.m.min_price()
	return p > 0 and p <= cash * float(ctx.param("share")) and cash - p >= keep


## The shelf's upgrade slots: each one costing at most `share` of the cash; with `line`
## only a perk on the bot's `perks` list that leaves `reserve` tickets too.
static func _upgrades(ctx: SimCtx, line: bool) -> void:
	var run := ctx.run
	var e := ctx.e
	var share := float(ctx.param("share"))
	var keep: int = int(ctx.param("reserve")) * ctx.m.min_price() if line else 0
	for id in run.upgrades.duplicate():
		var p := run.perk_price(id)
		if p <= 0 or p > e.cash * share or e.cash - p < keep or (line and not ctx.param("perks").has(id)):
			continue
		if run.buy_upgrade(id, e):
			run.apply(ctx.m)


## The rounds probe's morning (SimProbes.check_rounds): with plenty of cash, every round
## up attacked: a reroll tried first; every card tried in order, a reroll, every card
## again in the other order, a reroll; then SKIP FOR AN ITEM on whatever is still up.
## A take may bring the next round up (a reward chain), and the cards tried after it
## then try that one, as a player's presses would. Counted in ctx.counters:
##   grab_taken          cards taken
##   grab_twice          a card taken on a round a card was already taken on (the
##                       rounds dealt, RunState.stats rounds + reward_rounds, had not
##                       moved since the last take): must stay 0
##   grab_reward_reroll  a reward round rerolled: must stay 0
static func grab(ctx: SimCtx) -> void:
	var run := ctx.run
	var guard := 0
	while run.offers_open and guard < 50:
		guard += 1
		_grab_reroll(ctx)
		for pass_no in 2:
			var ks := range(run.offers.size())
			if pass_no == 1:
				ks.reverse()
			for k in ks:
				_grab_take(ctx, k)
			_grab_reroll(ctx)
		run.skip_offers()


static func _grab_reroll(ctx: SimCtx) -> void:
	var reward := ctx.run.offer_reward
	if ctx.run.reroll_offers(ctx.e) and reward:
		ctx.counters["grab_reward_reroll"] = int(ctx.counters.get("grab_reward_reroll", 0)) + 1


static func _grab_take(ctx: SimCtx, k: int) -> void:
	var run := ctx.run
	if k >= run.offers.size():
		return
	var at := int(run.stats.rounds) + int(run.stats.reward_rounds)
	if not run.buy_offer(k, ctx.e):
		return
	run.apply(ctx.m)
	var c := ctx.counters
	c["grab_taken"] = int(c.get("grab_taken", 0)) + 1
	if at == ctx.taken_on:
		c["grab_twice"] = int(c.get("grab_twice", 0)) + 1
	ctx.taken_on = at


## The deal's ceiling (perks "reach"; SimReport.reach): the `shelf` perks, level 1 each
## (passes until none more can be bought, so a requirement on the list comes first);
## then every round: the first of the `perks` (the line's dealt core, in that order) on
## its cards the run does not hold; on a morning round with none, a reroll while fewer
## than `rerolls` were made of it and a core card it lacks could be dealt (no share
## limit: the bot has plenty of cash), then again; else the item.
static func reach(ctx: SimCtx) -> void:
	var run := ctx.run
	var e := ctx.e
	var more := true
	var g := 0
	while more and g < 10:
		g += 1
		more = false
		for id in ctx.param("shelf"):
			if run.level(id) < 1 and run.buy_perk(id, e):
				run.apply(ctx.m)
				more = true
	var core: Array = ctx.param("perks")
	var guard := 0
	while run.offers_open and guard < 50:
		guard += 1
		var k := _reach_pick(ctx, core)
		while k < 0 and not run.offer_reward and run.offer_rerolls < int(ctx.param("rerolls")) \
				and core.any(func(id): return run.level(id) <= 0 and run.offerable().has(id)):
			var price := run.reroll_price()
			if not run.reroll_offers(e):
				break
			ctx.counters["reroll_cost"] = int(ctx.counters.get("reroll_cost", 0)) + price
			k = _reach_pick(ctx, core)
		var at := int(run.stats.rounds) + int(run.stats.reward_rounds)
		if k >= 0 and run.buy_offer(k, e):
			run.apply(ctx.m)
			if not ctx.counters.has("reach_round") and core.all(func(id): return run.level(id) > 0):
				ctx.counters["reach_round"] = at
			continue
		run.skip_offers()


## The card `reach` takes: the first of `core` on the round up the run does not hold
## and can take now; -1: none.
static func _reach_pick(ctx: SimCtx, core: Array) -> int:
	for id in core:
		var k := ctx.run.offers.find(id)
		if k >= 0 and ctx.run.level(id) <= 0 and ctx.run.can_buy_offer(k, ctx.e):
			return k
	return -1


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

## The items used on a column (RunState.use_item) and from the phone (use_now).
const COLUMN_ITEMS := ["peek", "magnifier", "skip", "shuffle", "coin", "mover", "sure", "reel", "queue"]
const NOW_ITEMS := ["happy", "safety", "slip", "overtime", "copy"]


## Using (and buying) items, `at` "morning" (after the perks), "work" (after a shift)
## or "machine" (before each batch, today's column picked). False only at the machine:
## the bot leaves for the day. Variants:
##   none   never (the default: no bot uses one unless its spec says so)
##   use    the careful player, using only what the game shows (a PEEK's and a
##          MAGNIFIER's answers, READ THE FLARE through the run's reading), each item by
##          its rule (_use, _at_machine, one_more; CHEAT SHEET in the perks block,
##          _cheat); in the morning it buys off the shelf the `item_list` items whose
##          price is at most `item_share` of the cash (0, the default: never), then a
##          COPIER copies one of them. WHITE-OUT works by itself (RunState.pay_ticket)
##   blind  the given-cards control with items: every item held is used the moment it
##          can be, on today's column, with no thought (a PEEK's answer is ignored, a
##          coin and HAPPY HOUR go on at once, a RETURN SLIP on an empty tray)
static func items(ctx: SimCtx, at: String) -> bool:
	match ctx.variant("items"):
		"none":
			return true
		"use":
			return _use(ctx, at)
		"blind":
			_blind(ctx, at)
			return true
	assert(false, "unknown items variant")
	return true


## One item used on today's column, counted ("item_<id>"). Returns use_item's answer.
static func _col(ctx: SimCtx, id: String) -> Dictionary:
	var got := ctx.run.use_item(id, ctx.m, ctx.col)
	if not got.is_empty():
		ctx.counters["item_" + id] = int(ctx.counters.get("item_" + id, 0)) + 1
	return got


## One item used from the phone, counted. Returns use_now's answer.
static func _now(ctx: SimCtx, id: String) -> Dictionary:
	var got := ctx.run.use_now(id, ctx.e)
	if not got.is_empty():
		ctx.counters["item_" + id] = int(ctx.counters.get("item_" + id, 0)) + 1
	return got


static func _count(ctx: SimCtx, key: String) -> void:
	ctx.counters[key] = int(ctx.counters.get(key, 0)) + 1


## items "use". The morning: the shelf's `item_list` items within `item_share` of the
## cash, in that order (an item is worth a small share of a bankroll, never the day);
## then a COPIER on the last one bought when it is on that list (a free second one).
## After a shift: OVERTIME (the shift is paid again: never better spent than on a day
## worked). At the machine: _at_machine.
static func _use(ctx: SimCtx, at: String) -> bool:
	var run := ctx.run
	match at:
		"morning":
			var share := float(ctx.param("item_share"))
			if share > 0.0:
				for id in ctx.param("item_list"):
					if run.shelf.has(id) and run.item_price(id) <= ctx.e.cash * share and run.buy_item(id, ctx.e):
						_count(ctx, "bought_" + str(id))
			if run.can_use_now("copy") and ctx.param("item_list").has(run.last_item):
				_now(ctx, "copy")
			return true
		"work":
			if run.can_use_now("overtime"):
				_now(ctx, "overtime")
			return true
		"machine":
			return _at_machine(ctx)
	return true


## items "use" before a batch on today's column, in this order:
##   SAFETY NET   at once on a day of play: it gives back a share of the day's loss, and
##                the bot cannot tell a losing day before it is played
##   HAPPY HOUR   when the money the bot came with today buys `happy_min` tickets of the
##                column: +50% is worth most on the day the most is bought
##   RETURN SLIP  when the box has at most `slip_max` tickets left, the machine has a
##                last-sale prize and the money buys them all (and READ THE FLARE, when
##                held, does not say a top prize is in): the rest is bought unopened,
##                the last sale (and a cleared box's perks) taken, every ticket given
##                back at full price (_slip; the rules allow it: they sit unopened in the
##                tray). The only use of a slip a bot has: it opens what it buys at once
##   PEEK         the column decision (_peek): may move the bot to another column, or
##                send it home
##   SURE THING   with a MAGNIFIER held, only when the MAGNIFIER says the next ticket
##                loses (on a winner it would be spent for nothing); without, at once
##   REEL IN      with READ THE FLARE, only on a box whose top prize is in (its biggest
##                prize left is then the top); without the flare, at once
##   QUEUE JUMP   when the money buys QUEUE_WINDOW tickets of the column (the winners it
##                moves are bought, not left for tomorrow's box)
##   LUCKY COIN   when no coin waits on the column's form: at once (a coin waits for the
##                form's next prize whichever ticket that is, so a MAGNIFIER adds nothing
##                to it); with `coin_wait` 1, as the brief had it, only after a
##                MAGNIFIER's yes when one is held
## FAST FORWARD and SHUFFLE only answer a bad PEEK (_peek); MOVER is never used (moving
## to the other column is free). A MAGNIFIER with no SURE THING (and no coin waiting
## for it) is kept for the day's end (one_more).
static func _at_machine(ctx: SimCtx) -> bool:
	var run := ctx.run
	var e := ctx.e
	if run.can_use_now("safety"):
		_now(ctx, "safety")
	if run.can_use_now("happy") and ctx.day_money >= int(ctx.param("happy_min")) * ctx.m.price(ctx.col):
		_now(ctx, "happy")
	_slip(ctx)
	if not _peek(ctx):
		return false
	var box: TicketBox = ctx.m.boxes[ctx.col]
	if box.cursor >= box.size:
		return true   # sold out: the next sale loads a new box
	var price := ctx.m.price(ctx.col)
	if run.held("sure") > 0:
		if run.held("magnifier") <= 0 or not bool(_col(ctx, "magnifier").get("wins", true)):
			_col(ctx, "sure")
	if run.held("reel") > 0 and (run.reading() < BoxReading.FLARE or top_in(ctx, ctx.col)):
		_col(ctx, "reel")
	if run.held("queue") > 0 and e.cash + e.credit >= Catalog.QUEUE_WINDOW * price:
		_col(ctx, "queue")
	if run.held("coin") > 0 and int(run.coin_on.get(box.form.uid(), 0)) <= 0:
		if int(ctx.param("coin_wait")) <= 0 or run.held("magnifier") <= 0:
			_col(ctx, "coin")
		elif bool(_col(ctx, "magnifier").get("wins", false)):
			_col(ctx, "coin")
	return true


## RETURN SLIP (items "use"; _at_machine says when): the rest of today's box bought
## unopened and given back (SimRun.slip_rest).
static func _slip(ctx: SimCtx) -> void:
	var run := ctx.run
	if run.held("slip") <= 0 or not run.can_use_now("slip") or ctx.m.last_sale <= 0:
		return
	var box: TicketBox = ctx.m.boxes[ctx.col]
	var rest := box.size - box.cursor
	if rest <= 0 or rest > int(ctx.param("slip_max")):
		return
	if ctx.e.cash + ctx.e.credit < rest * ctx.m.price(ctx.col):
		return
	if run.reading() >= BoxReading.FLARE and top_in(ctx, ctx.col):
		return
	SimRun.slip_rest(ctx, ctx.col)


## The PEEK threshold of a form, in winners per 100 tickets (`peek_min` of its id, times
## `peek_scale`; a form not listed: 0, never left).
static func peek_min(ctx: SimCtx, form: FormDef) -> float:
	return float(ctx.param("peek_min").get(form.id, 0.0)) * float(ctx.param("peek_scale"))


## items "use": the PEEK, the one item that makes playing at the machine a decision.
## Before a batch, when today's box has no answer yet for where it stands, a PEEK held
## looks at its next peek_n() tickets (INFORMANT sees further); the bot buys into them
## only when their winners reach peek_min (per 100 tickets: the window's count times 100
## over its size). An answer is kept until the box has gone past it, so a window known
## to be under is left again without another PEEK. Under it the bot leaves the window:
## a FAST FORWARD held skips it (then it may PEEK again), else a SHUFFLE held deals the
## rest again (the next tickets are then the rest's average), else another column (its
## `forms`' first, the fewest left, none it left today nor one known to be under), else
## it goes home for the day: false. In the layer's endgame it never goes home: it plays
## the window. Counted (SimCtx.counters).
static func _peek(ctx: SimCtx) -> bool:
	var run := ctx.run
	var guard := 0
	while guard < 12:
		guard += 1
		var box: TicketBox = ctx.m.boxes[ctx.col]
		if box.cursor >= box.size:
			return true
		var key := "%s|%s" % [box.form.uid(), box.seed]
		var known: Dictionary = ctx.peeks.get(key, {})
		if not known.is_empty() and box.cursor < int(known.until):
			if known.good:
				return true
			_count(ctx, "peek_known")
		elif run.held("peek") > 0:
			var got := _col(ctx, "peek")
			var n := mini(int(got.get("of", 0)), box.size - box.cursor)
			var good := float(got.get("winners", 0)) * 100.0 >= peek_min(ctx, box.form) * n
			ctx.peeks[key] = {"until": box.cursor + n, "good": good}
			if good:
				return true
			_count(ctx, "peek_bad")
		else:
			return true
		if run.held("skip") > 0 and not _col(ctx, "skip").is_empty():
			ctx.peeks.erase(key)
			_count(ctx, "peek_skip")
			continue
		if run.held("shuffle") > 0 and not _col(ctx, "shuffle").is_empty():
			ctx.peeks.erase(key)
			_count(ctx, "peek_shuffle")
			continue
		if not ctx.left_today.has(ctx.col):
			ctx.left_today.append(ctx.col)
		var c := _other_column(ctx)
		if c >= 0:
			ctx.col = c
			_count(ctx, "peek_moved")
			continue
		if endgame(ctx):
			_count(ctx, "peek_stayed")
			return true
		_count(ctx, "peek_stop")
		return false
	return true


## A column to go to from a window under peek_min: of the columns the money buys a
## ticket of (the `forms`' first, then any), not today's, not one left today, not one
## whose box is known to be under where it stands; the fewest tickets left. The jackpot
## line (column "top", reading the flare) goes only to a box whose top prize is in, as
## its column block does. -1: none.
static func _other_column(ctx: SimCtx) -> int:
	var tops := ctx.variant("column") == "top" and ctx.run.reading() >= BoxReading.FLARE
	for any in [false, true]:
		var cols := []
		for i in _cols(ctx, any):
			if i == ctx.col or ctx.left_today.has(i) or (tops and not top_in(ctx, i)):
				continue
			var box: TicketBox = ctx.m.boxes[i]
			var known: Dictionary = ctx.peeks.get("%s|%s" % [box.form.uid(), box.seed], {})
			if not known.is_empty() and box.cursor < int(known.until) and not known.good:
				continue
			cols.append(i)
		if not cols.is_empty():
			return _fewest_left(ctx, cols)
	return -1


## Asked when the bot is about to leave the machine (stay said 0): items "use" holding a
## MAGNIFIER looks at today's column, and when the next ticket wins buys that one ticket
## (a winner for a ticket's price). Returns the tickets to buy: 1, or 0 to leave.
static func one_more(ctx: SimCtx) -> int:
	if ctx.variant("items") != "use" or ctx.run.held("magnifier") <= 0 or ctx.col < 0:
		return 0
	var box: TicketBox = ctx.m.boxes[ctx.col]
	if box.cursor >= box.size or not SimRun.can_buy(ctx.e, ctx.m.price(ctx.col)):
		return 0
	if not bool(_col(ctx, "magnifier").get("wins", false)):
		return 0
	_count(ctx, "one_more")
	return 1


## items "blind": every item held used the moment it can be. In the morning and after a
## shift, the phone's (OVERTIME, a COPIER); at the machine, the phone's (HAPPY HOUR,
## SAFETY NET, a RETURN SLIP on an empty tray), then every column item on today's
## column, each as many as are held (a PEEK's and a MAGNIFIER's answers ignored).
static func _blind(ctx: SimCtx, at: String) -> void:
	var run := ctx.run
	for id in NOW_ITEMS:
		var g := 0
		while run.can_use_now(id) and g < 10:
			g += 1
			if _now(ctx, id).is_empty():
				break
	if at != "machine":
		return
	for id in COLUMN_ITEMS:
		var g := 0
		while run.held(id) > 0 and g < 10:
			g += 1
			if _col(ctx, id).is_empty():
				break


# --- box -------------------------------------------------------------------------

## After every batch bought and opened (the layer not paid): change the box, or set
## ctx.col to another column. Variants:
##   keep   nothing
##   churn  NEW BOX on today's column when its box is not finished, cashing out first
##          when the cash cannot pay the fee
##   flare  the jackpot line, with READ THE FLARE: when it says today's box holds no top
##          prize any more, it leaves the box (counted, ctx.counters "flare_left"): to
##          another column whose box holds one, else NEW BOX while the fee is worth it
##          (top_box; REGULAR cuts the fee). A box that only just sold out is left for
##          the next batch to read.
##   magnet the window line, with MAGNET: on a window's edge, when today's column is not
##          sure of a winner in the next window (sure_window), a column that is (the
##          `forms` first, then any); else today's column
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
		"flare":
			var m := ctx.m
			if ctx.run.reading() < BoxReading.FLARE or m.boxes[ctx.col].cursor >= m.boxes[ctx.col].size \
					or top_in(ctx, ctx.col):
				return
			var c := _top_column(ctx)
			var changes := int(ctx.run.stats.box_changes)
			if c >= 0:
				ctx.col = c
			elif not top_box(ctx, ctx.col) and int(ctx.run.stats.box_changes) == changes:
				return
			ctx.counters["flare_left"] = int(ctx.counters.get("flare_left", 0)) + 1
			return
		"magnet":
			if ctx.run.window_n != 0 or sure_window(ctx, ctx.col):
				return
			for any in [false, true]:
				for i in _cols(ctx, any):
					if sure_window(ctx, i):
						ctx.col = i
						return
			return
	assert(false, "unknown box variant")


## Whether MAGNET makes the rest of the window sure of a winner on column `i`: its
## box's next MAGNET ticket (every `magnet`-th of the box) falls within the window, and
## every ticket sold since the one before it lost (the bot opened them: it is what has
## already happened, not what is left).
static func sure_window(ctx: SimCtx, i: int) -> bool:
	var mg := ctx.m.magnet
	var box: TicketBox = ctx.m.boxes[i]
	var c := box.cursor
	if mg <= 0 or c >= box.size:
		return false
	var at := (c / mg + 1) * mg - 1
	if at >= box.size or at - c >= Catalog.WINDOW - ctx.run.window_n:
		return false
	for k in range(maxi(0, at - mg + 1), c):
		if box.wins(k):
			return false
	return true
