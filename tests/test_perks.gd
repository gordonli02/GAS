extends "res://tests/test_case.gd"
## Perks, items and contacts in the run (the perk-tree talk with G): the tree, the prize
## formula and every effect hook, the daily perk offers and the item shelf, opening at
## once, ALL IN, box reading, and how all of it is saved.
## Big Catch's tiers: 0 and 1 top ($500), 2 mid ($100), 3 low ($25); a ticket is $1.


func _run() -> RunState:
	return RunState.start(RunConfig.standard(), "P-1", ["diner", "bar", "bingo"])


## A run with `cash` in hand (put in as a prize, so the ledger stays honest).
func _rich(cash: int) -> Array:
	var r := _run()
	var e := r.new_economy()
	e.bonus(cash - e.cash)
	return [r, e]


var _form: FormDef = null


func _catch() -> FormDef:
	if _form == null:
		var pack := core_pack()
		_form = pack.forms[0] if pack != null else null
	return _form


func _ticket(tier: int, no := 100) -> Dictionary:
	var f := _catch()
	return {"no": no, "tier": tier, "prize": int(f.tiers[tier].prize) if tier >= 0 else 0}


## What a ticket pays in run `r` (a fresh ledger each time, so cash plays no part).
func _pays(r: RunState, t: Dictionary, bet := 1, x := 1.0) -> int:
	var e := Economy.new()
	e.cash = 0
	return r.pay_ticket(e, t, _catch(), bet, x)


func test_catalog_holds_together() -> void:
	var c := Catalog.standard()
	eq(c.problems(), PackedStringArray(), "standard catalog")
	eq(c.branches.size(), 5, "five branches")
	for b in c.branches:
		check(c.branch_perks(b.id).size() >= 4, "branch %s has its perks" % b.id)
	for kind in ["INFO", "ECONOMY", "ACTION"]:
		var found := 0
		for i in c.items:
			if i.kind == kind:
				found += 1
		check(found >= 3, "items of kind %s" % kind)
	# G's numbers.
	eq(c.perk("haggler").levels.size(), 1, "HAGGLER has one level")
	eq(int(c.perk("haggler").levels[0].value), 15, "items 15% less")
	eq(c.perk("savings").levels.map(func(l): return int(l.value)), [10, 20, 30], "SAVINGS 10, 20, 30 (the work line's perk)")
	check(c.perk("savings").get("requires", {}).is_empty(), "SAVINGS has no requirement: the work line buys it first")
	eq(c.perk("debt").levels.map(func(l): return int(l.value)), [25, 50], "BORROWED LUCK at half")
	eq(c.perk("credit").effect, "loan_pct", "GOOD CREDIT in percent")
	var bad := Catalog.from_dict(Catalog.STANDARD)
	bad.perks[0].requires = {"nothing": 1}
	check(not bad.problems().is_empty(), "a requirement on a perk that is not there is reported")
	var loop := Catalog.from_dict(Catalog.STANDARD)
	loop.perk("prizes").requires = {"bigfish": 1}
	check(not loop.problems().is_empty(), "a circle of requirements is reported")


func test_the_prize_formula() -> void:
	if _catch() == null:
		return
	var r := _run()
	eq(_pays(r, _ticket(2)), 100, "no perk: the printed prize")
	r.perks = {"prizes": 1}
	eq(_pays(r, _ticket(2)), 125, "FAT PRIZES 1: +25%")
	r.perks = {"prizes": 3}
	eq(_pays(r, _ticket(2)), 200, "FAT PRIZES 3: +100%")
	eq(_pays(r, _ticket(2), 5), 1000, "at a bet of 5, five times")
	r.perks = {"prizes": 1, "bigfish": 2}
	eq(_pays(r, _ticket(0)), 2500, "BIG FISH: a top prize x4, then +25%")
	eq(_pays(r, _ticket(2)), 125, "not a mid prize")
	r.perks = {"stacker": 1}
	var two := {"no": 100, "tier": 2, "prize": 125, "wins": [2, 3, -1]}
	eq(_pays(r, two), 375, "STACKER: a ticket with two prizes x3")
	r.perks = {"firstpull": 2}
	eq(_pays(r, _ticket(3, 20)), 125, "FIRST PULL 2: the 20th ticket of a box x5")
	eq(_pays(r, _ticket(3, 21)), 25, "not the 21st")
	r.perks = {"prizes": 2, "firstpull": 1}
	eq(_pays(r, _ticket(2, 5), 2, 1.5), 1350, "100 x bet 2 x (1 + 50%) x 3 x 1.5: the + slot adds, the x slot multiplies")
	r.perks = {}
	r.items = {"coin": 1}
	eq(_pays(r, _ticket(-1)), 0, "a LUCKY COIN is not used on a loser")
	eq(_pays(r, _ticket(3)), 50, "the next prize doubles")
	eq(r.held("coin"), 0, "used up")
	var res := _rich(1000)
	var r2: RunState = res[0]
	var e: Economy = res[1]
	r2.perks = {"prizes": 1}
	eq(r2.pay_ticket(e, _ticket(2), _catch()), 125, "into the ledger")
	eq(r2.stats.bonus, 25, "the perk's share counted as bonus")
	check(e.balanced(), "ledger balanced")


func test_losers_and_streaks() -> void:
	if _catch() == null:
		return
	var r := _run()
	r.perks = {"scrap": 2}
	var e := Economy.new()
	e.cash = 0
	eq(r.pay_ticket(e, _ticket(-1), _catch(), 4), 1, "SCRAP DEALER 2: a $4 loser gives back $1")
	eq(e.wins, 0, "it is not a winner")
	var back := 0
	for k in 10:
		back += r.pay_ticket(e, _ticket(-1), _catch())
	eq(back, 2, "ten $1 losers: 25 cents each, paid as whole dollars")
	check(absf(r.scrap - 0.5) < 1e-6, "the rest saved up")
	r = _run()
	r.perks = {"pity": 2}
	for k in 5:
		_pays(r, _ticket(-1))
	eq(r.dry, 5, "five losers in a row")
	eq(_pays(r, _ticket(2)), 110, "DUE A WIN 2: +2% each, +10%")
	eq(r.dry, 0, "a winner ends the streak")
	eq(_pays(r, _ticket(2)), 100, "so the next is plain")
	r = _run()
	r.perks = {"trashking": 1, "hunter": 1}
	for k in 250:
		_pays(r, _ticket(-1))
	eq(r.prize_pct(null), 10, "TRASH KING: 250 losers this layer, +10%")
	_pays(r, _ticket(0))
	eq(r.prize_pct(null), 20, "JACKPOT HUNTER: a top prize, +10% more")
	r.items = {"whiteout": 1}
	eq(_pays(r, _ticket(-1)), 30, "WHITE-OUT: a loser pays the smallest prize, +20%")
	eq(r.held("whiteout"), 0, "used up")


func test_snowball_and_the_last_sale() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var r := _run()
	var m := r.new_machine(pack.forms, true)
	eq(r.last_sale_prize(), 50, "the stage's last sale")
	r.perks = {"closer": 2}
	eq(r.last_sale_prize(), 300, "CLOSER 2: x6")
	r.perks = {"snowball": 1}
	r.cleared_box(m)
	r.cleared_box(m)
	check(absf(r.snow_x() - 1.21) < 1e-6, "SNOWBALL: two boxes cleared, x1.21")
	eq(_pays(r, _ticket(2)), 121, "on every prize")
	eq(m.last_sale, 61, "and on the last sale, put into the machine")
	eq(r.stats.boxes_cleared, 2, "boxes cleared counted")


func test_money_perks() -> void:
	var res := _rich(100000)
	var r: RunState = res[0]
	var e: Economy = res[1]
	var line := r.loan_limit()
	r.perks = {"credit": 1}
	eq(r.loan_limit(), line * 3 / 2, "GOOD CREDIT 1: the line +50%")
	r.perks = {"credit": 3}
	eq(r.loan_limit(), line * 3, "GOOD CREDIT 3: +200%")
	r.perks = {"credit": 3, "lowrate": 1}
	eq(r.interest(), 10, "LOW RATE 1: 10% a day")
	r.perks = {"credit": 3, "lowrate": 2}
	eq(r.interest(), 5, "LOW RATE 2: 5% a day (never free: it compounds against SAVINGS)")
	r.borrow(e)
	eq(r.loan_due, r.borrowed, "so nothing on top")
	var fee := r.change_fee()
	r.perks = {"regular": 1}
	eq(r.change_fee(), fee / 2, "REGULAR 1: half the fee")
	r.perks = {"regular": 2}
	eq(r.change_fee(), 0, "REGULAR 2: free")
	r.perks = {"haggler": 1}
	eq(r.item_price("peek"), 17, "HAGGLER: $20 less 15%")
	eq(r.item_cap(), 3, "room for three items")
	r.perks = {"pockets": 2}
	eq(r.item_cap(), 8, "BIG POCKETS 2: eight")
	# BORROWED LUCK only when half the line is borrowed.
	var r2 := _run()
	var e2 := r2.new_economy()
	r2.perks = {"debt": 1, "credit": 1}
	r2.borrow(e2)
	check(not r2.debt_on(), "a token loan does not turn it on (%d of %d)" % [r2.borrowed, r2.loan_limit()])
	r2.borrow(e2)
	check(r2.debt_on(), "half the line does")
	eq(_pays(r2, _ticket(2)), 125, "+25%")
	# NET WORTH: +2% per $100 (times the stake) in cash.
	var r3 := _run()
	r3.perks = {"worth": 1}
	var e3 := Economy.new()
	e3.cash = 1050
	eq(r3.pay_ticket(e3, _ticket(2), _catch()), 120, "$1,050 in cash: +20%")
	var many := []
	for k in 3:
		many.append({"form": _catch(), "ticket": _ticket(2), "box": null, "bet": 1})
	e3.cash = 1050
	eq(r3.open_batch(e3, many).won, 360, "one opening counts the cash it started with: 3 x $120")
	r3.layer = 1
	e3.cash = 1050
	eq(r3.prize_pct(e3), 4, "at stake 5, $500 a step")


func test_savings_grow_every_morning() -> void:
	var r := _run()
	var e := r.new_economy()
	r.perks = {"savings": 3}
	r.close_offers()
	r.work(e)
	var cash := e.cash
	r.end_day(e)
	eq(e.cash, cash + roundi(cash * 0.3), "SAVINGS 3: +30% the morning after a shift too (G)")
	var grown := roundi(cash * 0.3)
	r.close_offers()
	r.play(e)
	cash = e.cash
	r.end_day(e)
	eq(e.cash, cash + roundi(cash * 0.3), "and the morning after play")
	eq(r.stats.savings, grown + roundi(cash * 0.3), "counted")
	check(e.balanced(), "ledger balanced")


func test_offers_are_dealt_each_day() -> void:
	var res := _rich(100000)
	var r: RunState = res[0]
	var e: Economy = res[1]
	check(r.offers_open, "offers wait at the start of the run")
	eq(r.offers.size(), Catalog.OFFERS, "three of them")
	var again := _run()
	eq(again.offers, r.offers, "the same seed deals the same")
	var branches := {}
	for id in r.offers:
		check(r.missing(id).is_empty(), "%s: its requirements are met" % id)
		branches[r.catalog.perk(id).branch] = true
	check(branches.size() >= 2, "from two branches at least")
	var plus := _run()
	plus.offer_bonus = 2
	eq(plus.deal_offers().size(), 5, "a bonus from outside the run deals more")
	# Buying: from cash, at the layer's stake; it leaves the offers.
	var id: String = r.offers[0]
	var price := r.perk_price(id)
	var cash := e.cash
	check(r.buy_offer(0, e), "buy the first offer")
	eq(r.level(id), 1, "the perk is held")
	eq(cash - e.cash, price, "for its price")
	eq(r.offers.size(), Catalog.OFFERS - 1, "it leaves the offers")
	eq(r.close_offers(), "", "something bought: no gift for skipping")
	check(not r.offers_open, "closed")
	# Rerolls cost double each time.
	r.close_offers()
	r.play(e)
	r.end_day(e)
	check(r.offers_open and r.day == 2, "new offers after the day")
	var p1 := r.reroll_price()
	check(r.reroll_offers(e), "reroll")
	eq(r.reroll_price(), p1 * 2, "the next costs double")
	# Skipping a whole round gives an item.
	var gift := r.close_offers()
	check(gift != "" and r.held(gift) == 1, "skipped: an item for it (%s)" % gift)
	eq(r.stats.skipped_offers, 1, "counted")
	check(e.balanced(), "ledger balanced")
	# The next layer deals again, at its stake.
	var r2 := _run()
	var e2 := r2.new_economy()
	e2.bonus(10000)
	r2.pay(e2)
	check(r2.layer == 1 and r2.offers_open, "offers for the new layer")
	eq(r2.perk_price(r2.offers[0]), int(r2.catalog.perk(r2.offers[0]).levels[0].price) * 5, "at stake 5")


func test_offers_only_what_is_open() -> void:
	var r := _run()
	for k in 40:
		r.offer_rerolls = k
		for id in r.deal_offers():
			check(r.missing(id).is_empty(), "no locked perk offered (%s)" % id)
	r.perks = {}
	for p in r.catalog.perks:
		r.perks[p.id] = p.levels.size()
	eq(r.deal_offers(), [], "every perk at the top: nothing to offer")


func test_cheat_sheet_takes_an_offer_free() -> void:
	var r := _run()
	var e := r.new_economy()
	check(not r.buy_offer(0, e, true), "no CHEAT SHEET: no free offer")
	r.items = {"cheat": 1}
	var id: String = r.offers[0]
	var cash := e.cash
	check(r.buy_offer(0, e, true), "with one: free")
	eq(r.level(id), 1, "held")
	eq(e.cash, cash, "nothing paid")
	eq(r.held("cheat"), 0, "used up")


func test_the_shelf() -> void:
	var res := _rich(10000)
	var r: RunState = res[0]
	var e: Economy = res[1]
	eq(r.shelf.size(), Catalog.SHELF, "four items on the shelf")
	var off := ""
	for it in r.catalog.items:
		if not r.shelf.has(it.id):
			off = it.id
	check(not r.buy_item(off, e), "an item not on the shelf cannot be bought")
	var id: String = r.shelf[0]
	check(r.buy_item(id, e), "one that is")
	check(not r.shelf.has(id), "it leaves the shelf")
	eq(r.last_item, id if id != "copy" else "", "the last item bought")
	var before := r.shelf.duplicate()
	var p := r.shelf_price()
	check(r.reroll_shelf(e), "a new shelf")
	eq(r.shelf_price(), p * 2, "the next costs double")
	check(r.shelf.size() == Catalog.SHELF and r.shelf != before, "four others")
	r.items = {"peek": 3}
	r.shelf = ["key"]
	check(not r.can_buy_item("key", e), "no room past three")
	check(e.balanced(), "ledger balanced")


func test_column_items() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var res := _rich(10000)
	var r: RunState = res[0]
	var e: Economy = res[1]
	var m := r.new_machine(pack.forms)
	# BOX KEY: the next NEW BOX is free, and only that one.
	r.items = {"key": 1}
	eq(r.change_fee(), 0, "NEW BOX costs nothing with it")
	var cash := e.cash
	check(r.change_box(e, m, 0), "change a box")
	eq(e.cash, cash, "for free")
	eq(r.held("key"), 0, "the key is used up")
	check(r.change_fee() > 0, "the next one costs again")
	# PEEK, and INFORMANT sees further.
	check(r.use_item("peek", m, 1).is_empty(), "none held: nothing")
	r.items = {"peek": 2}
	eq(r.use_item("peek", m, 1).get("winners"), BoxReading.winners_next(m.boxes[1], 10), "winners in the next ten")
	r.perks = {"informant": 2}
	eq(r.use_item("peek", m, 1).get("of"), 30, "INFORMANT 2: the next thirty")
	# MAGNIFIER: the next ticket.
	r.items = {"magnifier": 1}
	eq(r.use_item("magnifier", m, 2).get("wins"), int(m.boxes[2].tickets[0].prize) > 0, "whether the next one wins")
	# BOX REPORT: that box reads at level 4 until it leaves the machine.
	r.perks = {}
	r.items = {"report": 1}
	r.use_item("report", m, 2)
	eq(r.reading_of(m, 2), 4, "that box reads at level 4")
	eq(r.reading_of(m, 3), 0, "the others do not")
	r.change_box(e, m, 2)
	eq(r.reading_of(m, 2), 0, "a new box has to be read again")
	# FAST FORWARD: the next ten go unsold.
	r.items = {"skip": 1}
	var at := m.boxes[3].cursor
	eq(r.use_item("skip", m, 3).get("skipped"), 10, "ten skipped")
	eq(m.boxes[3].cursor, at + 10, "gone from the box")
	# SHUFFLE: the rest in another order, the same again from a save.
	r.items = {"shuffle": 1}
	var box: TicketBox = m.boxes[4]
	box.cursor = 100
	var order := box.tickets.slice(100).map(func(t): return int(t.prize))
	r.use_item("shuffle", m, 4)
	var shuffled := box.tickets.slice(100).map(func(t): return int(t.prize))
	check(shuffled != order, "another order")
	order.sort()
	var sorted := shuffled.duplicate()
	sorted.sort()
	eq(sorted, order, "the same tickets")
	eq(int(box.tickets[150].no), 151, "numbered by their new places")
	var saved := m.to_dict()
	var m2 := r.new_machine(pack.forms)
	var by_uid := {}
	for form in m.forms:
		by_uid[form.uid()] = form
	m2.load_boxes(saved.boxes, func(uid, s): return BoxGenerator.build(by_uid[uid], s, m2.model))
	eq(m2.boxes[4].tickets.slice(100).map(func(t): return int(t.prize)), shuffled, "a saved box shuffles the same way")
	check(e.balanced(), "ledger balanced")


func test_items_used_now() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var r := _run()
	var e := r.new_economy()
	var m := r.new_machine(pack.forms, true)
	r.items = {"happy": 1, "safety": 1, "tip": 1}
	check(not r.can_use_now("happy"), "HAPPY HOUR only on a day of play")
	r.close_offers()
	r.play(e)
	eq(r.use_now("tip", m).get("column"), BoxReading.hottest(m.boxes), "TIP-OFF names the hottest box")
	check(not r.use_now("happy").is_empty() and r.happy, "HAPPY HOUR on")
	eq(_pays(r, _ticket(2)), 150, "+50% today")
	check(not r.use_now("safety").is_empty(), "SAFETY NET on")
	e.credit += 100
	e.cash -= 100
	for k in 100:
		var sold := m.sell_now(0, e)
		r.open_ticket(e, {"form": m.forms[0], "ticket": sold.ticket, "box": sold.box})
	var loss := e.spent - e.won
	var cash := e.cash
	r.end_day(e)
	eq(e.cash - cash, roundi(maxi(0, loss) * 30 / 100.0), "30% of the day's loss back when it ends")
	check(not r.happy, "HAPPY HOUR is over")
	check(e.balanced(), "ledger balanced")
	# COPIER: the last item bought again.
	var res := _rich(10000)
	var r2: RunState = res[0]
	var e2: Economy = res[1]
	r2.shelf = ["coin", "copy"]
	r2.buy_item("coin", e2)
	r2.buy_item("copy", e2)
	eq(r2.use_now("copy").get("copied"), "coin", "copies the LUCKY COIN")
	eq(r2.items, {"coin": 2}, "two coins, the copier used up")


func test_opening_at_once() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var r := _run()
	var f := _catch()
	var entries := []
	for tier in [2, -1, 3, -1, 2]:
		entries.append({"form": f, "ticket": _ticket(tier), "box": null, "bet": 1})
	var e := Economy.new()
	e.cash = 0
	r.perks = {"multi": 1}
	eq(r.batch_size(), 5, "QUICK HANDS 1: five at once")
	eq(r.open_batch(e, entries).won, 225, "without CHAIN: the prizes as they are")
	r.perks = {"multi": 1, "combo": 1}
	var got := r.open_batch(e, entries)
	eq(got.winners, 3, "three winners")
	eq(got.won, 450, "CHAIN 1: two more winners, x2 on the opening")
	r.perks = {"multi": 2, "combo": 2}
	eq(r.open_batch(e, entries).won, 675, "CHAIN 2: x3")
	# ENCORE: from the box seed and the ticket number, so the same each time.
	var box := BoxGenerator.build(f, "AG-1", null, true)
	var many := []
	for k in 400:
		many.append({"form": f, "ticket": box.tickets[k], "box": box, "bet": 1})
	r.perks = {"multi": 3}
	var plain: int = r.open_batch(e, many).won
	r.perks = {"multi": 3, "again": 2}
	var more: int = r.open_batch(e, many).won
	check(more > plain, "ENCORE 2: some winners pay again (%d against %d)" % [more, plain])
	eq(r.open_batch(e, many).won, more, "the same ones every time")


func test_all_in() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var res := _rich(5000)
	var r: RunState = res[0]
	var e: Economy = res[1]
	var m := r.new_machine(pack.forms, true)
	r.close_offers()
	r.play(e)
	check(not r.can_all_in(e, m, 0), "without the perk: no")
	r.perks = {"allin": 1}
	var box: TicketBox = m.boxes[0]
	box.cursor = box.size - 200
	var left := 200
	var won := e.won
	var spent := e.spent
	var got := r.all_in(e, m, 0)
	eq(got.n, left, "the whole rest of the box")
	eq(e.spent - spent, left, "paid as tickets")
	eq(box.cursor, box.size, "the box is sold out")
	eq(got.last_sale, 50, "the last sale is paid")
	eq(e.won - won, got.won + 50, "prizes and the last sale")
	eq(r.stats.last_sales, 1, "counted")
	check(not r.can_all_in(e, m, 1), "once a day")
	check(e.balanced(), "ledger balanced")


func test_bets() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var r := _run()
	eq(r.bets(), [1], "no HIGH ROLLER: a bet of 1")
	r.perks = {"bet": 2}
	eq(r.bets(), [1, 2, 5], "HIGH ROLLER 2: 1, 2 or 5")
	r.bet = 5
	var m := r.new_machine(pack.forms, true)
	eq(m.price(0), 5, "a $1 ticket costs $5")
	var e := r.new_economy()
	e.credit = 5
	e.cash -= 5
	var sold := m.sell_now(0, e)
	check(not sold.is_empty() and e.credit == 0, "and is paid at that")
	r.bet = 9
	r.apply(m)
	eq(m.bet, 5, "never past the top bet")


func test_luck_passes_losing_boxes_over() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var forms := [pack.forms[0]]
	var plain := MachineLogic.new(forms, "LK-0001", null, true)
	var lucky := MachineLogic.new(forms, "LK-0001", null, true, 0.9)
	var fortune := MachineLogic.new(forms, "LK-0001", null, true, 0.9, Catalog.FORTUNE_TRIES)
	var lost := [0, 0, 0]
	for k in 60:
		for j in 3:
			var m: MachineLogic = [plain, lucky, fortune][j]
			if m.losing(m.boxes[0]):
				lost[j] += 1
			m.change_box(0)
	check(lost[0] > 15, "without luck about half the boxes lose (%d of 60)" % lost[0])
	check(lost[1] < lost[0] * 0.75, "LUCKY STREAK 3: fewer (%d against %d)" % [lost[1], lost[0]])
	check(lost[2] < lost[1], "FORTUNE: fewer still (%d against %d)" % [lost[2], lost[1]])
	var again := MachineLogic.new(forms, "LK-0001", null, true, 0.9)
	eq(again.boxes[0].seed, MachineLogic.new(forms, "LK-0001", null, true, 0.9).boxes[0].seed, "same seed, same box")
	# ASSEMBLY LINE: the box after a sell-out does not lose.
	var line := MachineLogic.new(forms, "AL-0001", null, true)
	line.flow_line = true
	var e := Economy.new()
	var bad := 0
	for k in 20:
		var box := line.boxes[0]
		box.cursor = box.size - 1
		e.credit = 2
		line.sell_now(0, e)   # the last ticket of the box
		line.sell_now(0, e)   # the next box loads, and sells its first
		if line.losing(line.boxes[0]):
			bad += 1
	eq(bad, 0, "ASSEMBLY LINE: never a losing box after a sell-out")


func test_box_reading() -> void:
	var pack := core_pack()
	if pack == null:
		return
	for f in [pack.forms[0], pack.form("plate")]:
		var box := BoxGenerator.build(f, "RD-1")
		var full := BoxReading.read(box)
		eq(full.left, box.size, "%s: a full box" % f.id)
		eq(full.value, box.prize_total(), "%s: all its money left" % f.id)
		eq(BoxReading.top(full), "TOP IN" if int(full.roles.top) > 0 else "NO TOP", "%s: whether it has a top prize" % f.id)
		box.cursor = 300
		var part := BoxReading.read(box)
		var gone := 0
		for i in 300:
			gone += int(box.tickets[i].prize)
		eq(part.left, box.size - 300, "%s: tickets sold are gone" % f.id)
		eq(part.value, box.prize_total() - gone, "%s: and so is their money" % f.id)
		check(absf(part.heat - float(part.value) / part.left / f.price) < 1e-6, "heat is money left per ticket's price")
		box.cursor = box.size
		eq(BoxReading.top(BoxReading.read(box)), "NO TOP", "%s: sold out, no top prize left" % f.id)
	var b := BoxGenerator.build(pack.forms[0], "RD-2")
	for t in [["big_loss", "LEAN BOX"], ["break_even", "EVEN BOX"], ["mid_win", "FAT BOX"]]:
		b.type_id = t[0]
		eq(BoxReading.nature(b), t[1], "%s reads %s" % t)
	eq(BoxReading.feel(2.0), "HOT", "hot")
	eq(BoxReading.feel(1.0), "FAIR", "fair")
	eq(BoxReading.feel(0.4), "COLD", "cold")
	var r := _run()
	r.perks = {"read1": 1, "read2": 1, "read3": 1}
	eq(r.reading(), 3, "three perks of the chain: level 3")
	check(not r.missing("read1").is_empty(), "READ THE FLARE needs CLOSER and REGULAR")


func test_buying_anything_breaks_the_work_only_line() -> void:
	var r := _run()
	var e := r.new_economy()
	r.shelf = ["key"]
	check(r.buy_item("key", e), "a $15 BOX KEY on day one")
	while r.playing():
		r.close_offers()
		r.work(e)
		r.end_day(e)
	eq(r.status, RunState.FAILED, "then working every day is not enough")


func test_lender_sells_a_day_once_per_layer() -> void:
	var res := _rich(100000)
	var r: RunState = res[0]
	var e: Economy = res[1]
	var days := r.days()
	check(r.buy_service("more_time", e), "ONE MORE DAY")
	eq(r.days(), days + 1, "the layer has another day")
	check(not r.buy_service("more_time", e), "once a layer")
	for d in days:
		r.work(e)
		r.end_day(e)
	eq(r.layer, 0, "still in the first layer after its own days")
	check(r.playing() and r.last_day(), "on the day bought")
	r.pay(e)
	eq(r.extra_days, 0, "the next layer has its own days")
	check(r.can_buy_service("more_time", e), "and the lender sells it again")


func test_saved_and_loaded() -> void:
	var res := _rich(100000)
	var r: RunState = res[0]
	var e: Economy = res[1]
	r.perks = {"prizes": 1, "luck": 1, "bet": 1, "pity": 1}
	r.items = {"coin": 2}
	r.buy_service("more_time", e)
	r.reports["core:catch"] = "X-0002"
	r.bet = 2
	r.dry = 7
	r.snow = 3
	r.happy = true
	r.reroll_offers(e)
	var d: Dictionary = JSON.parse_string(JSON.stringify(r.to_dict()))
	var back := RunState.from_dict(d, RunConfig.standard())
	check(back != null, "loads")
	if back == null:
		return
	eq(back.perks, r.perks, "perks")
	eq(back.items, {"coin": 2}, "items")
	eq(back.extra_days, 1, "the extra day")
	eq(back.services, {"more_time": 1}, "services used")
	eq(back.reports, {"core:catch": "X-0002"}, "boxes read")
	eq(back.offers, r.offers, "the offers")
	check(back.offers_open and back.offer_rerolls == 1, "still open, rerolled once")
	eq(back.shelf, r.shelf, "the shelf")
	check(back.bet == 2 and back.dry == 7 and back.snow == 3 and back.happy, "the bet, the streak, the snowball, today's HAPPY HOUR")
	eq(back.stats, r.stats, "stats")
	d.perks = {"prizes": 9, "gone": 2, "luck": -1}
	d.offers = ["prizes", "gone"]
	var odd := RunState.from_dict(d, RunConfig.standard())
	eq(odd.perks, {"prizes": 3}, "unknown perks dropped, levels kept within the perk")
	eq(odd.offers, ["prizes"], "an unknown offer dropped")
	eq(odd.bet, 1, "the bet within what HIGH ROLLER allows")
	for k in ["perks", "items", "extra_days", "services", "reports", "offers", "offers_open", "shelf", "bet"]:
		d.erase(k)
	var old := RunState.from_dict(d, RunConfig.standard())
	check(old != null and old.perks.is_empty() and old.items.is_empty() and not old.offers_open, "an older run loads with nothing bought")
