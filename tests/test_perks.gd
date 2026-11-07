extends "res://tests/test_case.gd"
## Perks, items and contacts in the run (the tree draft v2, M9.5): the catalog's shape
## (the shelf and the four kinds), the prize formula and every effect hook, the daily
## perk offers and the item shelf, the sure wins (a prize of the box moved forward),
## opening at once, ALL IN, box reading, and how all of it is saved.
## Big Catch's tiers (the pack's): 0 and 1 top ($500), 2 mid ($100), 3 low ($25); $1.


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


## A column of the machine whose next ticket loses, or -1.
func _losing_column(m: MachineLogic) -> int:
	for i in m.boxes.size():
		var box: TicketBox = m.boxes[i]
		if box.cursor < box.size and not box.wins(box.cursor):
			return i
	return -1


func test_catalog_holds_together() -> void:
	var c := Catalog.standard()
	eq(c.problems(), PackedStringArray(), "standard catalog")
	eq(c.branches.size(), 10, "the shelf, six build lines, risk, twist and certainty")
	for k in Catalog.KINDS:
		check(c.perks_of(k).size() >= 3, "kind %s has its perks (%d)" % [k, c.perks_of(k).size()])
	for p in c.perks_of("shelf"):
		check(p.get("shelf", false) and p.branch == "shelf", "%s: on the shelf" % p.id)
	for p in c.dealt():
		check(not p.get("shelf", false), "%s: dealt, not shelved" % p.id)
	for p in c.perks_of("risk") + c.perks_of("twist"):
		eq(p.levels.size(), 2, "%s: two levels (G)" % p.id)
	for p in c.perks_of("risk"):
		for l in p.levels:
			check(l.has("cost"), "%s: its price written at every level" % p.id)
	for kind in Catalog.ITEM_KINDS:
		var found := 0
		for i in c.items:
			if i.kind == kind:
				found += 1
		check(found >= 3, "items of kind %s (%d)" % [kind, found])
	# G's numbers.
	eq(c.perk("haggler").levels.size(), 1, "HAGGLER has one level")
	eq(int(c.perk("haggler").levels[0].value), 25, "items 25% less")
	eq(c.perk("savings").levels.map(func(l): return int(l.value)), [10, 20, 30], "SAVINGS 10, 20, 30 (the work line's perk)")
	check(c.perk("savings").get("requires", {}).is_empty(), "SAVINGS has no requirement: the work line buys it first")
	check(c.perk("pockets").get("requires", {}).is_empty() and c.perk("bet").get("requires", {}).is_empty(), "BIG POCKETS and HIGH ROLLER need nothing (G)")
	eq(c.perk("regular").levels.map(func(l): return int(l.value)), [50, 75], "REGULAR at most -75% (FIRST PULL's floor)")
	eq(c.perk("credit").effect, "loan_pct", "GOOD CREDIT in percent")
	check(c.perk("friend").is_empty() and c.item("key").is_empty(), "HOUSE FRIEND and the BOX KEY are gone (merged, deleted)")
	eq(Catalog.kind(c.perk("magnet")), "twist", "MAGNET is a twist (it changes the box's rule)")
	var bad := Catalog.from_dict(Catalog.STANDARD)
	bad.perks[0].requires = {"nothing": 1}
	check(not bad.problems().is_empty(), "a requirement on a perk that is not there is reported")
	var loop := Catalog.from_dict(Catalog.STANDARD)
	loop.perk("closer").requires = {"snowball": 1}
	check(not loop.problems().is_empty(), "a circle of requirements is reported")
	var risky := Catalog.from_dict(Catalog.STANDARD)
	risky.perk("shark").levels[0].erase("cost")
	check(not risky.problems().is_empty(), "a risk perk without its price written is reported")


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
	r.perks = {"penny": 2, "middle": 1}
	eq(_pays(r, _ticket(3)), 75, "PENNY JAR 2: a small prize x3")
	eq(_pays(r, _ticket(2)), 200, "MIDDLE CUT 1: a middle prize x2")
	eq(_pays(r, _ticket(0)), 500, "a top prize as printed")
	r.perks = {"stacker": 1}
	var two := {"no": 100, "tier": 2, "prize": 125, "wins": [2, 3, -1]}
	eq(_pays(r, two), 375, "STACKER: a ticket with two prizes x3")
	r.perks = {"firstpull": 2}
	eq(_pays(r, _ticket(3, 20)), 125, "FIRST PULL 2: the 20th ticket of a box x5")
	eq(_pays(r, _ticket(3, 21)), 25, "not the 21st")
	r.perks = {"prizes": 2, "firstpull": 1}
	eq(_pays(r, _ticket(2, 5), 2, 1.5), 1350, "100 x bet 2 x (1 + 50%) x 3 x 1.5: the + slot adds, the x slot multiplies")
	# FLARE ONLY: the top prizes grow, the small (then middle) ones pay nothing; two
	# perks on the same "x" multiply.
	r.perks = {"flare": 1}
	eq(_pays(r, _ticket(0)), 1500, "FLARE ONLY 1: a top prize x3")
	eq(_pays(r, _ticket(2)), 100, "a middle prize still pays")
	eq(_pays(r, _ticket(3)), 0, "a small prize pays nothing")
	eq(r.dry, 1, "and counts as a loser")
	r.perks = {"flare": 2, "bigfish": 2}
	eq(_pays(r, _ticket(0)), 10000, "FLARE ONLY 2 with BIG FISH 2: x5 x4")
	eq(_pays(r, _ticket(2)), 0, "a middle prize pays nothing at level 2")
	# A LUCKY COIN waits on its column.
	r.perks = {}
	r.coin_on = {_catch().uid(): 1}
	eq(_pays(r, _ticket(-1)), 0, "a LUCKY COIN is not used on a loser")
	eq(_pays(r, _ticket(3)), 50, "the column's next prize doubles")
	check(r.coin_on.is_empty(), "used up")
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
	for n in [5, 10]:
		r.snow = n
		check(absf(r.snow_x() - pow(1.1, n)) < 1e-9, "%d boxes cleared: 1.1 to the %d (G: it compounds)" % [n, n])


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
	# LOAN SHARK: the line times two, the interest times two, on LOW RATE's rate.
	r.perks = {"shark": 1}
	eq(r.loan_limit(), line * 2, "LOAN SHARK 1: the line x2")
	eq(r.interest(), 30, "and the interest x2")
	r.perks = {"shark": 2, "lowrate": 2}
	eq(r.interest(), 15, "LOAN SHARK 2 on LOW RATE 2: (15 - 10) x3, never nothing")
	var fee := r.change_fee()
	r.perks = {"regular": 1}
	eq(r.change_fee(), fee / 2, "REGULAR 1: half the fee")
	r.perks = {"regular": 2}
	eq(r.change_fee(), fee / 4, "REGULAR 2: a quarter (never free)")
	r.perks = {"haggler": 1}
	eq(r.item_price("peek"), 15, "HAGGLER: $20 less 25%")
	eq(r.item_cap(), 3, "room for three items")
	r.perks = {"pockets": 2}
	eq(r.item_cap(), 8, "BIG POCKETS 2: eight")
	# BORROWED LUCK: as much as is owed, in percent of the line; it grows with the
	# interest and goes when the loan does.
	var r2 := _run()
	var e2 := r2.new_economy()
	r2.perks = {"debt": 1}
	eq(_pays(r2, _ticket(2)), 100, "nothing owed: nothing")
	r2.borrow(e2)
	eq(r2.owe_pct(), 50, "$100 of a $200 line: +50%")
	eq(_pays(r2, _ticket(2)), 150, "on the prize")
	r2.borrow(e2)
	eq(r2.owe_pct(), 100, "the whole line: +100%")
	r2.accrue()
	eq(r2.owe_pct(), 115, "a morning's interest: more owed, more luck")
	r2.perks = {"debt": 2}
	eq(r2.owe_pct(), 230, "level 2: twice")
	e2.bonus(10000)
	r2.pay(e2)
	eq(r2.owe_pct(), 0, "paid: gone")
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


func test_risk_perks_have_their_price() -> void:
	if _catch() == null:
		return
	# SHORT WEEK: a day less in every layer; bought on the last day, that stays the last.
	var r := _run()
	var e := r.new_economy()
	eq(r.days(), 5, "five days")
	r.perks = {"shortweek": 1}
	eq(r.days(), 4, "SHORT WEEK 1: four")
	eq(_pays(r, _ticket(2)), 150, "and every prize +50%")
	r.perks = {"shortweek": 2}
	eq(r.days(), 3, "SHORT WEEK 2: three")
	r.perks = {}
	r.day = 5
	r.perks = {"shortweek": 2}
	eq(r.days(), 5, "bought on day 5: day 5 is the last, not gone")
	check(r.last_day(), "so it is the last day")
	# DOUBLE DOWN: more offers, more debt.
	var r2 := _run()
	var debt := r2.due()
	r2.perks = {"double": 1}
	eq(r2.due(), debt * 125 / 100, "DOUBLE DOWN 1: the debt +25%")
	eq(r2.offer_count(), Catalog.OFFERS + 1, "one more offer")
	r2.perks = {"double": 2}
	eq(r2.deal_offers().size(), Catalog.OFFERS + 2, "DOUBLE DOWN 2: two more dealt")
	# NO WAY BACK: no more work; every day of play since adds to the prizes.
	var r3 := _run()
	var e3 := r3.new_economy()
	r3.perks = {"noback": 1}
	check(not r3.can_work(), "NO WAY BACK: no shift")
	check(not r3.work(e3), "work refused")
	eq(e3.earned, 0, "no wage")
	r3.close_offers()
	r3.play(e3)
	r3.end_day(e3)
	eq(r3.noback_days, 1, "a day of play since")
	eq(_pays(r3, _ticket(2)), 110, "+10%")
	r3.close_offers()
	r3.play(e3)
	r3.end_day(e3)
	eq(_pays(r3, _ticket(2)), 120, "+20% after two")
	check(e.balanced() and e3.balanced(), "ledgers balanced")


func test_twist_perks() -> void:
	var pack := core_pack()
	if pack == null:
		return
	# RETURNS: untorn tickets given back for a share of their price.
	var res := _rich(1000)
	var r: RunState = res[0]
	var e: Economy = res[1]
	eq(r.refund_pct(), 0, "nothing back without it")
	r.perks = {"returns": 1}
	eq(r.refund_pct(), 50, "RETURNS 1: half")
	var entries := [{"form": _catch(), "ticket": _ticket(-1), "bet": 2}, {"form": _catch(), "ticket": _ticket(3), "bet": 2}]
	e.spend(4)
	var cash := e.cash
	eq(r.refund_tickets(e, entries, r.refund_pct()), 2, "two $2 tickets: $2 back")
	eq(e.cash, cash + 2, "to cash")
	eq(e.spent, 2, "no longer spent")
	eq(r.stats.refunded, 2, "counted")
	check(e.balanced(), "ledger balanced")
	# LOYAL and VARIETY: the forms bought today; the higher of the two counts.
	var r2 := _run()
	r2.perks = {"loyal": 1, "variety": 2}
	eq(r2.prize_pct(null), 0, "nothing bought today: nothing")
	r2.count_sales(5, 0, "core:catch")
	eq(r2.prize_pct(null), 30, "one form: LOYAL's +30% beats VARIETY's +10%")
	r2.count_sales(5, 0, "core:plate")
	r2.count_sales(5, 0, "core:spur")
	r2.count_sales(5, 0, "core:nugget")
	eq(r2.prize_pct(null), 40, "four forms: VARIETY's +40%, LOYAL is off")
	eq(r2.day_tickets, 20, "tickets of the day counted")
	var e2 := r2.new_economy()
	r2.close_offers()
	r2.play(e2)
	r2.end_day(e2)
	eq(r2.prize_pct(null), 0, "a new day: nothing bought yet")
	# MAGNET: in every window of 20 tickets of a box, one wins at least.
	var r3 := _run()
	r3.perks = {"magnet": 1}
	var m := r3.new_machine([pack.forms[0]], true)
	eq(m.magnet, 20, "the machine has it")
	var e3 := r3.new_economy()
	e3.credit = 400
	e3.cash -= 400
	var dry_windows := 0
	var pulled := 0
	for w in 20:
		var won := 0
		for k in 20:
			var sold := m.sell_now(0, e3)
			if int(sold.ticket.prize) > 0:
				won += 1
		if won == 0:
			dry_windows += 1
	for op in m.boxes[0].ops:
		if op.has("m"):
			pulled += 1
	eq(dry_windows, 0, "no window of 20 without a winner (%d prizes moved)" % pulled)
	# SEAL: paying takes the hottest box along into the next layer, as it stands.
	var r4 := _run()
	var e4 := r4.new_economy()
	r4.perks = {"seal": 1}
	var m4 := r4.new_machine(pack.forms, true)
	e4.credit = 150
	e4.cash -= 150
	for k in 150:
		m4.sell_now(2, e4)
	var kept: TicketBox = m4.boxes[2]
	kept.shuffle_rest()
	var hottest := BoxReading.hottest(m4.boxes)
	var hot: TicketBox = m4.boxes[hottest]
	e4.bonus(r4.due())
	check(r4.pay(e4, m4), "paid, the machine given")
	eq(r4.sealed.size(), 1, "one box sealed")
	eq(str(r4.sealed[0].form), hot.form.uid(), "the hottest one")
	eq(r4.stats.sealed, 1, "counted")
	var m5 := r4.new_machine(pack.forms, true)
	check(r4.sealed.is_empty(), "put into the next layer's machine")
	var found: TicketBox = null
	for b in m5.boxes:
		if b.seed == hot.seed and b.form.uid() == hot.form.uid():
			found = b
	check(found != null, "the box is on the new machine")
	if found != null:
		eq(found.cursor, hot.cursor, "where it stood")
		eq(found.form.stake, 5, "at the new layer's stake")
		eq(found.tickets.map(func(t): return int(t.prize)), hot.tickets.map(func(t): return int(t.prize) * 5), "the same tickets, prizes x5")
	# PICKY: NEW BOX may put another of the layer's forms in the column.
	var res6 := _rich(10000)
	var r6: RunState = res6[0]
	var e6: Economy = res6[1]
	var m6 := r6.new_machine(pack.forms, true)
	var other: FormDef = m6.forms[3]
	check(not r6.change_box(e6, m6, 0, other), "without PICKY: no")
	r6.perks = {"picky": 1}
	check(r6.change_box(e6, m6, 0, other), "with it")
	eq(m6.forms[0].uid(), other.uid(), "the column sells the other form")
	eq(m6.boxes[0].form.uid(), other.uid(), "its box is that form's")
	# HOUSE ACCOUNT: tickets on a tab on a day of play, settled when it ends; what the
	# cash does not cover is borrowed.
	var r7 := _run()
	var e7 := r7.new_economy()
	r7.perks = {"account": 1}
	var m7 := r7.new_machine(pack.forms, true)
	r7.close_offers()
	r7.play(e7)
	check(e7.tab_on, "the tab is open")
	eq(e7.tab_limit, r7.loan_left(), "as far as the house line")
	eq(e7.credit, 0, "no credit fed")
	check(m7.sell_now(0, e7).size() > 0, "a ticket sells on the tab")
	eq(e7.tab, 1, "owed to the machine")
	eq(e7.spent, 1, "and spent")
	check(e7.balanced(), "ledger balanced")
	e7.cash = 10
	e7.start_cash = e7.start_cash - 190
	for k in 29:
		m7.sell_now(0, e7)
	eq(e7.tab, 30, "thirty on the tab against $10 cash")
	check(not m7.sell_now(0, e7).is_empty(), "the house line covers more")
	r7.end_day(e7)
	eq(e7.tab, 0, "settled when the day ends")
	eq(e7.cash, 0, "the cash went first")
	eq(r7.borrowed, 21, "the rest was borrowed")
	eq(r7.loan_due, roundi(21 * 1.15), "with the morning's interest on it")
	check(not e7.tab_on, "the tab is closed")
	check(e7.balanced(), "ledger balanced")
	# MOONLIGHTING: a few tickets on a day of work, not opened that day.
	var r8 := _run()
	var e8 := r8.new_economy()
	r8.perks = {"moonlight": 1}
	r8.close_offers()
	r8.work(e8)
	var m8 := r8.new_machine(pack.forms, true)
	eq(m8.sale_cap, 20, "twenty may be bought")
	check(not r8.can_open(), "none opened today")
	e8.credit = 30
	e8.cash -= 30
	var sold := 0
	for k in 25:
		if not m8.sell_now(0, e8).is_empty():
			sold += 1
	eq(sold, 20, "the machine stops at twenty")
	r8.count_sales(sold, 0, "core:catch")
	r8.apply(m8)
	eq(m8.sale_cap, 0, "nothing more today")
	r8.end_day(e8)
	r8.close_offers()
	r8.play(e8)
	r8.apply(m8)
	eq(m8.sale_cap, -1, "a day of play: no cap")
	check(r8.can_open(), "and the tickets open")


func test_sure_wins_move_a_prize_forward() -> void:
	var pack := core_pack()
	if pack == null:
		return
	# STAKEOUT: the first ticket of the day wins; not the second.
	var r := _run()
	r.perks = {"stakeout": 1}
	var e := r.new_economy()
	r.close_offers()
	r.play(e)
	var m := r.new_machine(pack.forms, true)
	check(m.sure_next.is_valid(), "the machine asks the run")
	var col := _losing_column(m)
	check(col >= 0, "a column whose next ticket loses")
	if col < 0:
		return
	var box: TicketBox = m.boxes[col]
	var value := box.prize_total()
	e.credit = 50
	e.cash -= 50
	var first := m.sell_now(col, e)
	check(int(first.ticket.prize) > 0, "the first ticket of the day wins")
	eq(box.ops.size(), 1, "one prize moved")
	eq(box.prize_total(), value, "the box holds the same money")
	eq(r.stats.sure_wins, 1, "counted")
	r.count_sales(1, 0, box.form.uid())
	check(r.sure_armed, "armed until it is opened")
	r.open_ticket(e, {"form": m.forms[col], "ticket": first.ticket, "box": box})
	check(not r.sure_armed, "opened")
	var moves := box.ops.size()
	for k in 30:
		m.sell_now(col, e)
	eq(box.ops.size(), moves, "the day's other tickets are what they are")
	# INSURANCE: after the losers in a row, the next ticket sold wins; once, until opened.
	var r2 := _run()
	r2.perks = {"insurance": 2}
	var e2 := r2.new_economy()
	r2.close_offers()
	r2.play(e2)
	var m2 := r2.new_machine(pack.forms, true)
	e2.credit = 100
	e2.cash -= 100
	r2.dry = 14
	var c2 := _losing_column(m2)
	var b2: TicketBox = m2.boxes[c2]
	check(int(m2.sell_now(c2, e2).ticket.prize) == 0, "14 losers in a row: not yet")
	r2.dry = 15
	var again := _losing_column(m2)
	var b3: TicketBox = m2.boxes[again]
	var before := b3.ops.size()
	var sold := m2.sell_now(again, e2)
	check(int(sold.ticket.prize) > 0, "INSURANCE 2: the 15th loser is followed by a winner")
	eq(b3.ops.size(), before + 1, "moved forward")
	for k in 5:
		m2.sell_now(again, e2)
	eq(b3.ops.size(), before + 1, "not again until it is opened")
	check(b2.ops.is_empty() or b2 == b3, "the column tried at 14 was left alone")
	# MARKED: a PEEK puts the column's next winners first.
	var r3 := _run()
	r3.perks = {"marked": 1}
	r3.items = {"peek": 1}
	var m3 := r3.new_machine(pack.forms, true)
	var b4: TicketBox = m3.boxes[1]
	var winners := BoxReading.winners_next(b4, Catalog.MARKED_WINDOW)
	r3.use_item("peek", m3, 1)
	var front := 0
	for i in range(b4.cursor, b4.cursor + Catalog.MARKED_WINDOW):
		if b4.wins(i):
			front += 1
		else:
			break
	eq(front, winners, "MARKED: the %d winners of the next 10 come first" % winners)
	# The SURE items.
	var res := _rich(10000)
	var r4: RunState = res[0]
	var e4: Economy = res[1]
	var m4 := r4.new_machine(pack.forms, true)
	r4.items = {"sure": 1, "reel": 1, "queue": 1}
	var c4 := _losing_column(m4)
	var b5: TicketBox = m4.boxes[c4]
	var got := r4.use_item("sure", m4, c4)
	check(got.get("wins", false) and got.get("moved", false), "SURE THING: the next ticket wins, a prize moved up")
	check(b5.wins(b5.cursor), "it is there")
	eq(r4.held("sure"), 0, "used up")
	var c5 := (c4 + 1) % m4.boxes.size()
	var b6: TicketBox = m4.boxes[c5]
	var biggest := 0
	for i in range(b6.cursor, b6.size):
		biggest = maxi(biggest, int(b6.tickets[i].prize))
	r4.use_item("reel", m4, c5)
	eq(int(b6.tickets[b6.cursor].prize), biggest, "REEL IN: the biggest prize left is next")
	var c6 := (c4 + 2) % m4.boxes.size()
	var b7: TicketBox = m4.boxes[c6]
	var in_window := BoxReading.winners_next(b7, Catalog.QUEUE_WINDOW)
	var q := r4.use_item("queue", m4, c6)
	eq(BoxReading.winners_next(b7, Catalog.QUEUE_WINDOW), in_window + int(q.get("moved", 0)), "QUEUE JUMP: %d more winners in the next 20" % int(q.get("moved", 0)))
	check(int(q.get("moved", 0)) > 0, "some were moved")
	# A SURE THING with nothing left to move is not used up.
	var r5 := _run()
	r5.items = {"sure": 1}
	var m5 := r5.new_machine([pack.forms[0]], true)
	var b8: TicketBox = m5.boxes[0]
	var last_win := -1
	for i in b8.size:
		if b8.wins(i):
			last_win = i
	if last_win + 1 < b8.size:
		b8.cursor = last_win + 1
		eq(r5.use_item("sure", m5, 0), {}, "no prize left behind the cursor: nothing")
		eq(r5.held("sure"), 1, "kept")
	# The moves are replayed from a save.
	var saved := m4.to_dict()
	var m6 := r4.new_machine(pack.forms, true)
	var by_uid := {}
	for form in m4.forms:
		by_uid[form.uid()] = form
	m6.load_boxes(saved.boxes, func(uid, s): return BoxGenerator.build(by_uid[uid], s, m6.model, true))
	for i in m4.boxes.size():
		eq(m6.boxes[i].tickets.map(func(t): return int(t.prize)), m4.boxes[i].tickets.map(func(t): return int(t.prize)), "column %d loads in the same order" % i)
		eq(m6.boxes[i].ops, m4.boxes[i].ops, "column %d: the log" % i)


func test_box_ops() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var box := BoxGenerator.build(pack.forms[0], "OP-1", null, true)
	box.cursor = 10
	check(not box.swap(3, 50), "a sold ticket does not move")
	check(not box.swap(50, box.size), "nor one out of the box")
	var a := int(box.tickets[20].prize)
	var b := int(box.tickets[300].prize)
	check(box.swap(20, 300), "two unsold ones")
	eq([int(box.tickets[20].prize), int(box.tickets[300].prize)], [b, a], "changed places")
	eq([int(box.tickets[20].no), int(box.tickets[300].no)], [21, 301], "numbered by their new places")
	var w := box.find_winner(10, "next")
	check(w >= 10 and box.wins(w), "the next winner")
	var small := box.find_winner(10, "small")
	check(box.role_of(small) == "low", "the next small prize")
	var big := box.find_winner(10, "biggest")
	for i in range(10, box.size):
		check(int(box.tickets[i].prize) <= int(box.tickets[big].prize), "the biggest")
	var rnd := box.find_winner(10, "random")
	check(box.wins(rnd), "a winner at random")
	box.shuffle_rest()
	eq(box.shuffles(), 1, "one shuffle")
	var copy := BoxGenerator.build(pack.forms[0], "OP-1", null, true)
	copy.replay(box.ops)
	eq(copy.tickets.map(func(t): return int(t.prize)), box.tickets.map(func(t): return int(t.prize)), "the log replays to the same box")
	eq(copy.ops, box.ops, "and the same log")
	box.cursor = 20
	var in_window := BoxReading.winners_next(box, 10)
	eq(box.front_load(20, 10), in_window, "front_load counts the window's winners")
	for i in range(20, 20 + in_window):
		check(box.wins(i), "and they come first (%d)" % i)
	eq(BoxReading.winners_next(box, 10), in_window, "no more, no fewer")


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
		check(not r.catalog.perk(id).get("shelf", false), "%s: not a shelf perk" % id)
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
			check(Catalog.kind(r.catalog.perk(id)) != "shelf", "no shelf perk dealt (%s)" % id)
	r.perks = {}
	for p in r.catalog.dealt():
		r.perks[p.id] = p.levels.size()
	eq(r.deal_offers(), [], "every dealt perk at the top: nothing to offer")


## Every deal of `r` over 60 seeds and 3 rerolls each, at its layer and day.
func _deals(r: RunState) -> Array:
	var out := []
	for i in 60:
		r.seed = "DEAL-%d" % i
		for k in 3:
			r.offer_rerolls = k
			out.append(r.deal_offers())
	return out


## How many perks of a deal hold `pred` (a perk's dictionary -> bool), over the deals.
func _count(r: RunState, deals: Array, pred: Callable) -> int:
	var n := 0
	for d in deals:
		for id in d:
			if pred.call(r.catalog.perk(id)):
				n += 1
	return n


## Two kinds and two branches among the first three of every deal.
func _two_and_two(r: RunState, deals: Array, what: String) -> void:
	var bad := 0
	for d in deals:
		var kinds := {}
		var branches := {}
		for id in d.slice(0, Catalog.OFFERS):
			kinds[Catalog.kind(r.catalog.perk(id))] = true
			branches[r.catalog.perk(id).branch] = true
		if d.size() >= Catalog.OFFERS and (kinds.size() < 2 or branches.size() < 2):
			bad += 1
	eq(bad, 0, "%s: every deal has two kinds and two branches" % what)


func test_the_deal_by_layer() -> void:
	var r := _run()
	var legendary := func(p: Dictionary) -> bool: return p.rarity == "legendary"
	var risk := func(p: Dictionary) -> bool: return Catalog.kind(p) == "risk"
	# Layer 1: no risk; mostly common; a legendary now and then once one is open (G:
	# the first layer can raise the ceiling).
	var d1 := _deals(r)
	eq(_count(r, d1, risk), 0, "layer 1: no risk perk dealt")
	check(_count(r, d1, func(p: Dictionary) -> bool: return p.rarity == "common") > _count(r, d1, func(p: Dictionary) -> bool: return p.rarity == "rare"),
		"layer 1: more common than rare")
	for id in r.offerable():
		check(Catalog.kind(r.catalog.perk(id)) != "risk", "layer 1: %s not even offerable" % id)
	_two_and_two(r, d1, "layer 1")
	var opened := _run()
	opened.perks = {"closer": 1}
	var leg1 := _count(opened, _deals(opened), legendary)
	check(leg1 > 0, "layer 1 with CLOSER: SNOWBALL or ASSEMBLY LINE dealt now and then (%d)" % leg1)
	opened.layer = 1
	var leg1b := _count(opened, _deals(opened), legendary)
	check(leg1 < leg1b, "fewer than layer 2 would deal with the same perks (%d to %d)" % [leg1, leg1b])
	# Layer 2: everything open.
	r.layer = 1
	var d2 := _deals(r)
	var leg2 := _count(r, d2, legendary)
	check(leg2 > 0, "layer 2: legendary perks dealt (%d)" % leg2)
	check(_count(r, d2, risk) > 0, "layer 2: risk perks dealt (%d)" % _count(r, d2, risk))
	_two_and_two(r, d2, "layer 2")
	# Layer 3: legendary weighed up.
	r.layer = 2
	var d3 := _deals(r)
	var leg3 := _count(r, d3, legendary)
	check(leg3 > leg2, "layer 3: more legendary than layer 2 (%d to %d)" % [leg3, leg2])
	_two_and_two(r, d3, "layer 3")
	note("legendary dealt over 180 deals: layer 1 (with CLOSER) %d, layer 2 %d, layer 3 %d" % [leg1, leg2, leg3])
	# A layer past the table deals by the last one's weights (the seed has the layer in it).
	eq(Catalog.deal(5), Catalog.deal(2), "past the table: the last layer's weights")
	r.layer = 5
	eq(r.offerable(), _at_layer(2).offerable(), "and the same perks open")
	# The same seed, layer, day and reroll deal the same.
	var a := _at_layer(1)
	var b := _at_layer(1)
	check(a.deal_offers() == b.deal_offers() and _deals(a) == _deals(b), "the same seed deals the same")
	# DOUBLE DOWN 2: five offers, the first three still two kinds and two branches.
	a.perks = {"double": 2}
	var d5 := _deals(a)
	var five := 0
	for d in d5:
		if d.size() == Catalog.OFFERS + 2:
			five += 1
	eq(five, d5.size(), "DOUBLE DOWN 2: five offers every time")
	_two_and_two(a, d5, "DOUBLE DOWN 2")
	var kinds_ok := 0
	for d in d5:
		var kinds := {}
		for id in d:
			kinds[Catalog.kind(a.catalog.perk(id))] = true
		if kinds.size() >= 2:
			kinds_ok += 1
	eq(kinds_ok, d5.size(), "DOUBLE DOWN 2: two kinds in all five")


## A run moved to layer `l` (0-based), nothing else changed.
func _at_layer(l: int) -> RunState:
	var r := _run()
	r.layer = l
	return r


func test_a_perk_of_a_form() -> void:
	# The hook for the perks of a form (section 6b, none written yet): one with `form`
	# is offered only while that form is on the machine.
	var r := _run()
	r.layer = 1
	var p: Dictionary = r.catalog.perk("closer").duplicate(true)
	p.id = "of_a_form"
	p.erase("requires")
	p.erase("requires_any")
	p["form"] = "catch"
	r.catalog.perks.append(p)
	check(not r.offerable().has("of_a_form"), "its form not on the machine: not offered")
	check(r.offerable(["catch"]).has("of_a_form"), "its form on the machine: offered")


func test_the_shelf_of_perks() -> void:
	var res := _rich(100000)
	var r: RunState = res[0]
	var e: Economy = res[1]
	var ids := r.shelf_perks()
	check(ids.has("savings") and ids.has("read1") and ids.has("bet"), "SAVINGS, the reading chain and HIGH ROLLER are on the shelf")
	for id in ids:
		eq(Catalog.kind(r.catalog.perk(id)), "shelf", "%s: a shelf perk" % id)
	check(r.buy_perk("savings", e), "SAVINGS bought off the shelf")
	check(not r.buy_perk("read1", e), "READ THE FLARE needs CLOSER or REGULAR")
	eq(r.missing("read1").keys(), ["closer", "regular"], "either would do")
	r.perks["regular"] = 1
	check(r.missing("read1").is_empty() and r.buy_perk("read1", e), "with REGULAR: yes")
	check(not r.buy_perk("closer", e), "a dealt perk is not sold off the shelf")


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
	r.shelf = ["magnifier"]
	check(not r.can_buy_item("magnifier", e), "no room past three")
	check(e.balanced(), "ledger balanced")


func test_column_items() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var res := _rich(10000)
	var r: RunState = res[0]
	var e: Economy = res[1]
	var m := r.new_machine(pack.forms)
	# PEEK sees 50, and INFORMANT sees further.
	check(r.use_item("peek", m, 1).is_empty(), "none held: nothing")
	r.items = {"peek": 2}
	eq(r.use_item("peek", m, 1).get("winners"), BoxReading.winners_next(m.boxes[1], 50), "winners in the next fifty")
	r.perks = {"informant": 2}
	eq(r.use_item("peek", m, 1).get("of"), 100, "INFORMANT 2: the next hundred")
	eq(r.effect("free_peek"), 1, "and a free PEEK every day of play (HOUSE FRIEND, merged)")
	# MAGNIFIER: the next ticket.
	r.items = {"magnifier": 1}
	eq(r.use_item("magnifier", m, 2).get("wins"), int(m.boxes[2].tickets[m.boxes[2].cursor].prize) > 0, "whether the next one wins")
	# BOX REPORT: that box reads at level 4 until it leaves the machine.
	r.perks = {}
	r.items = {"report": 1}
	r.use_item("report", m, 2)
	eq(r.reading_of(m, 2), 4, "that box reads at level 4")
	eq(r.reading_of(m, 3), 0, "the others do not")
	r.change_box(e, m, 2)
	eq(r.reading_of(m, 2), 0, "a new box has to be read again")
	# FAST FORWARD: the next fifty go unsold.
	r.items = {"skip": 1}
	var at := m.boxes[3].cursor
	eq(r.use_item("skip", m, 3).get("skipped"), 50, "fifty skipped")
	eq(m.boxes[3].cursor, at + 50, "gone from the box")
	# LUCKY COIN on a column.
	r.items = {"coin": 1}
	check(r.use_item("coin", m, 0).get("on", false), "a coin on column 0")
	eq(r.coin_on, {m.forms[0].uid(): 1}, "waiting on that form's next prize")
	# MOVER: the column's box trades places with the next column's.
	r.items = {"mover": 1}
	var f0 := m.forms[0].uid()
	var f1 := m.forms[1].uid()
	var s0 := m.boxes[0].seed
	eq(r.use_item("mover", m, 0).get("with"), 1, "with column 1")
	check(m.forms[0].uid() == f1 and m.forms[1].uid() == f0, "the forms changed places")
	check(m.boxes[1].seed == s0 and m.boxes[1].form.uid() == f0, "and the boxes with them")
	# SHUFFLE: the rest in another order, the same again from a save (columns included).
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
	check(m2.forms[0].uid() == f1 and m2.boxes[1].seed == s0, "the swapped columns come back swapped")
	var old: Dictionary = saved.boxes[4].duplicate()
	old.erase("ops")
	old.erase("column")
	old.shuffles = [100]
	var m3 := r.new_machine(pack.forms)
	m3.load_boxes([old], func(uid, s): return BoxGenerator.build(by_uid[uid], s, m3.model))
	eq(m3.boxes[4].tickets.slice(100).map(func(t): return int(t.prize)), shuffled, "a save from before the log loads too")
	check(e.balanced(), "ledger balanced")


func test_items_used_now() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var r := _run()
	var e := r.new_economy()
	var m := r.new_machine(pack.forms, true)
	r.items = {"happy": 1, "safety": 1, "tip": 1, "slip": 1}
	check(not r.can_use_now("happy"), "HAPPY HOUR only on a day of play")
	check(not r.can_use_now("slip"), "a RETURN SLIP too")
	r.close_offers()
	r.play(e)
	eq(r.use_now("tip", m).get("column"), BoxReading.hottest(m.boxes), "TIP-OFF names the hottest box")
	check(not r.use_now("happy").is_empty() and r.happy, "HAPPY HOUR on")
	eq(_pays(r, _ticket(2)), 150, "+50% today")
	check(not r.use_now("safety").is_empty() and r.safety, "SAFETY NET on")
	check(r.use_now("slip").get("on", false), "a RETURN SLIP: the caller gives the tray back")
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
	# OVERTIME: before the day is chosen, the shift pays double; after a shift, the
	# wage again.
	var r2 := _run()
	var e2 := r2.new_economy()
	r2.items = {"overtime": 2}
	check(r2.can_use_now("overtime"), "before the day is chosen")
	check(r2.use_now("overtime").get("on", false), "on")
	r2.close_offers()
	r2.work(e2)
	eq(e2.earned, 300, "the shift paid double")
	check(not r2.can_use_now("overtime"), "once a day")
	r2.end_day(e2)
	r2.close_offers()
	r2.work(e2)
	check(r2.use_now("overtime", null, e2).get("on", false), "after a shift")
	eq(e2.earned, 300 + 150 + 150, "the wage again")
	r2.end_day(e2)
	r2.close_offers()
	r2.play(e2)
	r2.items = {"overtime": 1}
	check(not r2.can_use_now("overtime"), "not on a day of play")
	check(e2.balanced(), "ledger balanced")
	# COPIER: the last item bought again.
	var res := _rich(10000)
	var r3: RunState = res[0]
	var e3: Economy = res[1]
	r3.shelf = ["coin", "copy"]
	r3.buy_item("coin", e3)
	r3.buy_item("copy", e3)
	eq(r3.use_now("copy").get("copied"), "coin", "copies the LUCKY COIN")
	eq(r3.items, {"coin": 2}, "two coins, the copier used up")


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
	check(not r.missing("read1").is_empty(), "READ THE FLARE needs CLOSER or REGULAR")
	r.perks = {"closer": 1}
	check(r.missing("read1").is_empty(), "CLOSER alone opens it")


func test_buying_anything_breaks_the_work_only_line() -> void:
	var r := _run()
	var e := r.new_economy()
	r.shelf = ["magnifier"]
	check(r.buy_item("magnifier", e), "an $8 MAGNIFIER on day one")
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
	r.coin_on = {"core:catch": 1}
	r.forms_today = {"core:catch": true, "core:plate": true}
	r.day_tickets = 12
	r.noback_days = 2
	r.sure_armed = true
	r.overtime = true
	r.sealed = [{"form": "core:catch", "seed": "S-1", "cursor": 40, "opened": 30, "ops": [{"s": 20}, {"m": [25, 90]}]}]
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
	eq(back.coin_on, {"core:catch": 1}, "the coin on its column")
	eq(back.forms_today, r.forms_today, "the forms of the day")
	check(back.day_tickets == 12 and back.noback_days == 2 and back.sure_armed and back.overtime, "the day's count, NO WAY BACK's days, the sure win armed, OVERTIME")
	eq(back.sealed.size(), 1, "the sealed box")
	eq(int(back.sealed[0].cursor), 40, "where it stood")
	eq(back.sealed[0].ops.size(), 2, "with its log")
	eq(back.stats, r.stats, "stats")
	d.perks = {"prizes": 9, "gone": 2, "luck": -1}
	d.offers = ["prizes", "gone"]
	var odd := RunState.from_dict(d, RunConfig.standard())
	eq(odd.perks, {"prizes": 3}, "unknown perks dropped, levels kept within the perk")
	eq(odd.offers, ["prizes"], "an unknown offer dropped")
	eq(odd.bet, 1, "the bet within what HIGH ROLLER allows")
	for k in ["perks", "items", "extra_days", "services", "reports", "offers", "offers_open", "shelf", "bet", "coin_on",
			"forms_today", "sealed", "day_tickets", "sure_armed"]:
		d.erase(k)
	var old := RunState.from_dict(d, RunConfig.standard())
	check(old != null and old.perks.is_empty() and old.items.is_empty() and not old.offers_open, "an older run loads with nothing bought")
	check(old != null and old.coin_on.is_empty() and old.sealed.is_empty() and not old.sure_armed, "and none of the new state")
	# The ledger's tab is saved too.
	var e2 := Economy.new()
	e2.tab_on = true
	e2.tab_limit = 50
	e2.buy(30)
	var e3 := Economy.new()
	e3.from_dict(e2.to_dict())
	check(e3.tab == 30 and e3.tab_on and e3.tab_limit == 50 and e3.balanced(), "the tab, open, with its limit")
