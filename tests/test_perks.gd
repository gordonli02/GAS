extends "res://tests/test_case.gd"
## Perks, items and contacts in the run (the tree draft v2, M9.5): the catalog's shape
## (the shelf and the four kinds), the prize formula and every effect hook, the daily
## perk offers and the item shelf, the sure wins (a prize of the box moved forward),
## opening at once, the window of ten (STREAK, ALL IN), HIGH ROLLER's fixed bet,
## MOONLIGHTING's wage cut, box reading, and how all of it is saved.
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
	eq(c.branches.size(), 11, "the shelf, seven build lines, risk, twist and certainty")
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
	var parked := Catalog.from_dict(Catalog.STANDARD)
	parked.perk("allin").requires = {"combo": 1}
	check(not parked.problems().is_empty(), "a perk of the run needing one parked for M13 is reported")
	# ALL IN's bar: a share for every core form, about half to all of the window.
	var pack := core_pack()
	if pack != null:
		for f in pack.forms:
			check(Catalog.ALL_IN_SHARE.has(f.uid()), "ALL IN has a share for %s" % f.id)
	for k in Catalog.ALL_IN_SHARE:
		var share := int(Catalog.ALL_IN_SHARE[k])
		check(share > 0 and share <= 100, "%s: a share in (0, 100] (%d)" % [k, share])
	eq(Catalog.all_in_share("someone:else"), Catalog.ALL_IN_DEFAULT, "a Workshop form: the default share")
	eq(Catalog.all_in_bar(0), 1, "an empty window's bar is $1: the next must print something")
	eq(Catalog.all_in_bar(25 * 70), 18, "70% of $25, rounded up")


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
	eq(r.last_sale_prize(), 10, "the stage's last sale")
	r.perks = {"closer": 2}
	eq(r.last_sale_prize(), 60, "CLOSER 2: x6")
	r.perks = {"snowball": 1}
	r.cleared_box(m)
	r.cleared_box(m)
	check(absf(r.snow_x() - 1.21) < 1e-6, "SNOWBALL: two boxes cleared, x1.21")
	eq(_pays(r, _ticket(2)), 121, "on every prize")
	eq(m.last_sale, 12, "and on the last sale, put into the machine ($12.10)")
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
	# FIRST PULL x REGULAR (docs/perk_research.md 5.11): while FIRST PULL is held the fee
	# never falls under its multiplier times twenty tickets at the bet, so changing
	# boxes to farm the first twenty does not pay. REGULAR's cut comes first.
	r.perks = {"firstpull": 2, "regular": 2}
	eq(r.change_fee(), 100, "FIRST PULL 2 with REGULAR 2: x5 times 20 tickets at stake 1")
	r.perks = {"firstpull": 1}
	eq(r.change_fee(), 60, "FIRST PULL 1 alone: x3 times 20, over the $25 fee")
	r.perks = {"firstpull": 2, "regular": 2, "bet": 3}
	eq(r.change_fee(), 1000, "at a bet of x10 the twenty cost ten times as much: so does the floor")
	r.layer = 1
	r.perks = {"firstpull": 2, "regular": 2}
	eq(r.change_fee(), 500, "layer 2: at stake 5")
	r.perks = {"regular": 2}
	eq(r.change_fee(), r.config.layer(1).change_fee / 4, "without FIRST PULL, REGULAR 2 is a quarter there too")
	r.layer = 0
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
	eq(_pays(r2, _ticket(2)), 100, "and the prize is back to the printed one")
	# LOAN SHARK x LOW RATE x BORROWED LUCK (5.11): the shark's line, the full of it
	# owed, pays +100% / +200% only while owed, and the rate is never nothing.
	var r4 := _run()
	var e4 := r4.new_economy()
	r4.perks = {"shark": 2, "lowrate": 2, "credit": 1, "debt": 1}
	eq(r4.interest(), 15, "LOAN SHARK 2 on LOW RATE 2: still 15% a day")
	eq(_pays(r4, _ticket(2)), 100, "nothing owed: BORROWED LUCK adds nothing")
	while r4.borrow(e4):
		pass
	eq(r4.loan_due, r4.loan_limit(), "the shark's whole line owed")
	eq(r4.owe_pct(), 100, "BORROWED LUCK 1 at a full line: +100%")
	eq(_pays(r4, _ticket(2)), 200, "on the prize")
	r4.perks["debt"] = 2
	eq(r4.owe_pct(), 200, "BORROWED LUCK 2 at a full line: +200%")
	eq(_pays(r4, _ticket(2)), 300, "on the prize")
	r4.accrue()
	check(r4.loan_due > r4.loan_limit(), "a morning at 15% and more is owed than the line")
	e4.bonus(100000)
	r4.pay(e4)
	eq(r4.loan_due, 0, "paid with the layer")
	eq(r4.owe_pct(), 0, "repaid: no luck")
	eq(_pays(r4, _ticket(2)), 100, "the prize is the printed one again")
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
	r.work(e)
	var cash := e.cash
	r.end_day(e)
	eq(e.cash, cash + roundi(cash * 0.3), "SAVINGS 3: +30% the morning after a shift too (G)")
	var grown := roundi(cash * 0.3)
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
	r3.play(e3)
	r3.end_day(e3)
	eq(r3.noback_days, 1, "a day of play since")
	eq(_pays(r3, _ticket(2)), 110, "+10%")
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
	r2.play(e2)
	r2.end_day(e2)
	eq(r2.prize_pct(null), 0, "a new day: nothing bought yet")
	# MAGNET: in every window of 20 tickets of a box, one wins at least.
	var r3 := _run()
	r3.perks = {"magnet": 1}
	var m := r3.new_machine([pack.forms[0]], true)
	eq(m.magnet, 20, "the machine has it")
	var e3 := r3.new_economy()
	var windows: int = m.boxes[0].size / 20   # the run's boxes are 200 tickets now: whole windows of one box
	var winners_in_box := 0
	for t in m.boxes[0].tickets:
		if int(t.prize) > 0:
			winners_in_box += 1
	e3.credit = windows * 20
	e3.cash -= windows * 20
	var dry_windows := 0
	var pulled := 0
	for w in windows:
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
	# A window gets its winner as long as the box has winners to give: Big Catch's box of
	# 200 holds about ten, for ten windows, so it may come up short by the winners it lacks.
	check(dry_windows <= maxi(0, windows - winners_in_box), "no window of 20 without a winner (%d dry of %d windows, %d winners, %d prizes moved)" % [dry_windows, windows, winners_in_box, pulled])
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
		eq(found.size, hot.size, "the same size: rebuilt under the layer it came from, not the new layer's")
		# Saved in the new layer, it still comes back as that box (M9.7: the layers' box sizes differ).
		var saved := m5.to_dict()
		var col := m5.boxes.find(found)
		eq(saved.boxes[col].sizes, hot.model.sizes_key(), "the save keeps the sizes it was built under")
		check(not saved.boxes[(col + 1) % m5.boxes.size()].has("sizes"), "the layer's own boxes carry none")
		var m5b := r4.new_machine(pack.forms, true)
		var by_uid := {}
		for f in m5b.forms:
			by_uid[f.uid()] = f
		m5b.load_boxes(saved.boxes, func(uid, s, sizes := []):
			var model := m5b.model.with_sizes(sizes) if sizes.size() == 3 else m5b.model
			return BoxGenerator.build(by_uid[uid], s, model, true))
		eq(m5b.boxes[col].size, found.size, "restored: the same size")
		eq(m5b.boxes[col].tickets.map(func(t): return int(t.prize)), found.tickets.map(func(t): return int(t.prize)), "restored: the same tickets")
	# SEAL, the player's choice (the PAY key's card): the column chosen comes along, hot or not.
	var rs := _run()
	var es := rs.new_economy()
	rs.perks = {"seal": 1}
	var ms := rs.new_machine(pack.forms, true)
	eq(rs.seal_choices(ms).size(), ms.boxes.size(), "every column with tickets left can be chosen")
	var cold := (BoxReading.hottest(ms.boxes) + 1) % ms.boxes.size()
	var chosen: TicketBox = ms.boxes[cold]
	es.bonus(rs.due())
	check(rs.pay(es, ms, [cold]), "paid, a column chosen")
	eq(rs.sealed.size(), 1, "one box sealed")
	eq([str(rs.sealed[0].form), str(rs.sealed[0].seed)], [chosen.form.uid(), chosen.seed], "the one chosen, not the hottest")
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
	# MOONLIGHTING: tickets on a day of work, as many as the money buys, not opened that
	# day; the wage cut on every day of work while it is held (G).
	var r8 := _run()
	var e8 := r8.new_economy()
	var wage := r8.wage()
	r8.perks = {"moonlight": 1}
	eq(r8.shift_wage(), wage * 70 / 100, "MOONLIGHTING 1: the wage -30%")
	var before := e8.cash
	r8.work(e8)
	eq(e8.cash - before, wage * 70 / 100, "a day of work pays the wage less the cut")
	eq(r8.last_wage(), wage * 70 / 100, "the SHIFT DONE card says so")
	var m8 := r8.new_machine(pack.forms, true)
	check(not r8.can_open(), "none opened today")
	e8.credit = 30
	e8.cash -= 30
	var sold := 0
	for k in 30:
		if not m8.sell_now(0, e8).is_empty():
			sold += 1
	eq(sold, 30, "no limit: the machine sells what the money buys")
	r8.count_sales(sold, 0, "core:catch")
	r8.end_day(e8)
	r8.play(e8)
	check(r8.can_open(), "the tickets open the next day")
	r8.perks = {"moonlight": 2}
	eq(r8.shift_wage(), wage * 85 / 100, "MOONLIGHTING 2: -15%")
	r8.perks = {}
	eq(r8.shift_wage(), wage, "without it: the whole wage")
	check(e8.balanced(), "ledger balanced")


func test_sure_wins_move_a_prize_forward() -> void:
	var pack := core_pack()
	if pack == null:
		return
	# STAKEOUT: the first ticket of the day wins; not the second.
	var r := _run()
	r.perks = {"stakeout": 1}
	var e := r.new_economy()
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
	check(r.offers_open and not r.offer_reward, "a morning round is up at the start of the run")
	eq(r.offers.size(), Catalog.OFFERS, "three cards")
	eq(r.stats.rounds, 1, "counted")
	var again := _run()
	eq(again.offers, r.offers, "the same seed deals the same")
	var branches := {}
	for id in r.offers:
		check(r.missing(id).is_empty(), "%s: its requirements are met" % id)
		check(not r.catalog.perk(id).get("shelf", false), "%s: not a shelf perk" % id)
		eq(int(r.offered.get(id, 0)), 1, "%s: counted as offered" % id)
		branches[r.catalog.perk(id).branch] = true
	check(branches.size() >= 2, "from two branches at least")
	var plus := _run()
	plus.offer_bonus = 2
	eq(plus.deal_offers().size(), 5, "a bonus from outside the run deals more")
	# Taking one: from cash, at the layer's stake; it is the round's pick.
	var id: String = r.offers[0]
	var price := r.perk_price(id)
	var cash := e.cash
	check(r.buy_offer(0, e), "buy the first card")
	eq(r.level(id), 1, "the perk is held")
	eq(cash - e.cash, price, "for its price")
	check(not r.offers_open and r.offers.is_empty(), "the round is over: the other cards are gone")
	# A new day, a new round; rerolls cost double; giving it up gives an item.
	r.play(e)
	r.end_day(e)
	check(r.offers_open and r.day == 2 and not r.offer_reward, "a new round the next morning")
	eq(r.stats.rounds, 2, "counted")
	var p1 := r.reroll_price()
	check(r.reroll_offers(e), "reroll")
	eq(r.reroll_price(), p1 * 2, "the next costs double")
	eq(r.stats.rounds, 2, "a reroll is the same round")
	var gift := r.skip_offers()
	check(gift != "" and r.held(gift) == 1, "given up: an item for it (%s)" % gift)
	eq(r.stats.skipped_offers, 1, "counted")
	check(not r.offers_open, "and the round is over")
	check(e.balanced(), "ledger balanced")
	# The next layer deals again, at its stake (after its reward rounds).
	var r2 := _run()
	var e2 := r2.new_economy()
	e2.bonus(10000)
	r2.pay(e2)
	_past_rewards(r2)
	check(r2.layer == 1 and r2.offers_open and not r2.offer_reward, "a morning round for the new layer")
	eq(r2.perk_price(r2.offers[0]), int(r2.catalog.perk(r2.offers[0]).levels[0].price) * 5, "at stake 5")


## The reward rounds up, each given up for nothing in particular (an item if there is room).
func _past_rewards(r: RunState) -> void:
	var guard := 0
	while r.offers_open and r.offer_reward and guard < 20:
		guard += 1
		r.skip_offers()


## G (docs/roadmap.md 十.1-4, M9.8 step 2): a round is a pick of one. It ends with one
## card taken (bought, or free with a CHEAT SHEET) or given up for an item; a reroll
## comes only before the pick. Every order of those.
func test_a_round_is_a_pick_of_one() -> void:
	# Buy first: nothing more of the round, no reroll, no item.
	var res := _rich(100000)
	var r: RunState = res[0]
	var e: Economy = res[1]
	check(r.buy_offer(1, e), "buy the second card")
	var cash := e.cash
	for k in Catalog.OFFERS:
		check(not r.can_buy_offer(k, e) and not r.buy_offer(k, e), "card %d: no second pick" % k)
	check(not r.can_reroll_offers(e) and not r.reroll_offers(e), "no reroll after the pick")
	check(not r.can_skip_offers() and r.skip_offers() == "", "no item after the pick")
	eq(e.cash, cash, "nothing more paid")
	eq(r.stats.perks, 1, "one perk from the round")
	# Reroll, then buy: the new deal's card; then nothing more.
	res = _rich(100000)
	r = res[0]
	e = res[1]
	var first := r.offers.duplicate()
	check(r.reroll_offers(e) and r.reroll_offers(e), "two rerolls before the pick")
	check(r.offers.size() == Catalog.OFFERS and r.offers != first, "a new deal")
	eq(r.offer_rerolls, 2, "rerolled twice")
	var id: String = r.offers[2]
	check(r.buy_offer(2, e) and r.level(id) == 1, "then a pick")
	check(not r.reroll_offers(e) and not r.buy_offer(0, e), "and nothing after it")
	# Reroll, then give up: an item, and nothing after.
	res = _rich(100000)
	r = res[0]
	e = res[1]
	r.reroll_offers(e)
	var gift := r.skip_offers()
	check(gift != "", "rerolled, then given up for an item (%s)" % gift)
	check(not r.buy_offer(0, e) and not r.reroll_offers(e) and r.skip_offers() == "", "nothing after it")
	eq(r.stats.perks, 0, "no perk")
	# Give up first: nothing to buy after.
	res = _rich(100000)
	r = res[0]
	e = res[1]
	check(r.skip_offers() != "", "given up at once")
	check(not r.buy_offer(0, e, false) and not r.reroll_offers(e), "nothing to buy or reroll")
	# A CHEAT SHEET's free card is the pick.
	res = _rich(100000)
	r = res[0]
	e = res[1]
	r.items = {"cheat": 2}
	cash = e.cash
	check(r.buy_offer(0, e, true), "a card free")
	check(not r.buy_offer(1, e, true) and not r.buy_offer(1, e), "no second, free or bought")
	eq(r.held("cheat"), 1, "one CHEAT SHEET used")
	eq(e.cash, cash, "nothing paid")
	# A round no card of which the cash covers: still given up, or rerolled when it can.
	var poor := _run()
	var pe := poor.new_economy()
	pe.pay(pe.cash)
	check(not poor.can_buy_offer(0, pe) and not poor.reroll_offers(pe), "no money: no buy, no reroll")
	check(poor.can_skip_offers(), "but the item")
	# DOUBLE DOWN: more cards to choose among, still one pick.
	res = _rich(100000)
	r = res[0]
	e = res[1]
	r.perks = {"double": 2}
	r.reroll_offers(e)
	eq(r.offers.size(), Catalog.OFFERS + 2, "DOUBLE DOWN 2: five cards")
	check(r.buy_offer(4, e) and not r.offers_open, "one pick of five ends it")
	check(e.balanced(), "ledger balanced")


## G (docs/roadmap.md 十.4): the game never lets a player leave a round unresolved; the
## run itself throws a round away (no item) when the day is spent at the machine or at
## work with one still up, and the reward rounds pending with it.
func test_walking_away_throws_the_rounds_away() -> void:
	var res := _rich(100000)
	var r: RunState = res[0]
	var e: Economy = res[1]
	var cards := r.offers.duplicate()
	check(r.play(e), "a day of play with the round up")
	check(not r.offers_open and r.offers.is_empty(), "the round is gone")
	eq(r.items_held(), 0, "no item for it")
	eq(r.stats.skipped_offers, 0, "not counted as given up")
	check(not r.buy_offer(0, e) and not r.reroll_offers(e) and r.skip_offers() == "", "nothing of it at the machine")
	eq(r.stats.perks, 0, "nothing bought")
	r.end_day(e)
	check(r.offers_open and r.offers != cards, "the next morning: a new round")
	check(r.work(e) and not r.offers_open, "a shift throws it away too")
	r.end_day(e)
	# A layer paid early: reward rounds up and pending; a day of play throws them all away.
	var r2 := _run()
	var e2 := r2.new_economy()
	e2.bonus(100000)
	r2.pay(e2)
	check(r2.offer_reward and r2.rewards_pending > 0, "reward rounds up after paying early")
	check(r2.play(e2), "a day of play instead")
	check(not r2.offers_open and r2.rewards_pending == 0 and not r2.offer_reward, "every round of the morning gone")
	eq(r2.items_held(), 0, "without an item")
	r2.end_day(e2)
	check(r2.offers_open and not r2.offer_reward, "the next morning: only the morning's round")


## G (docs/roadmap.md 十.6): only perks not held are dealt; a held one is levelled up
## from the shelf's upgrade slots or a reward round's upgrade card.
func test_only_new_perks_are_dealt() -> void:
	var r := _run()
	r.layer = 1
	r.perks = {"closer": 1, "penny": 1, "luck": 2, "prizes": 1, "shark": 1, "magnet": 1, "stakeout": 1}
	for i in 60:
		r.seed = "NEW-%d" % i
		for k in 3:
			r.offer_rerolls = k
			for id in r.deal_offers():
				eq(r.level(id), 0, "%s: held, not dealt" % id)
		r.reward_no = i % 4
		for id in r.deal_reward():
			check(r.level(id) == 0 or r.upgradable().has(id), "a reward card is new or an upgrade (%s)" % id)
	for id in r.perks:
		check(not r.offerable().has(id), "%s: held, not offerable" % id)
	# Every dealt perk held, none at its top: no morning round.
	var all := _run()
	var e := all.new_economy()
	for p in all.catalog.dealt():
		all.perks[p.id] = 1
	eq(all.offerable(), [], "nothing left to deal")
	eq(all.deal_offers(), [], "a morning deals nothing")
	all.play(e)
	all.end_day(e)
	check(not all.offers_open and all.offers.is_empty(), "no round when nothing is left to deal")
	eq(all.stats.rounds, 1, "the first morning's round only")
	check(not all.reroll_offers(e) and all.skip_offers() == "", "nothing to reroll or give up")
	# A reward round with nothing new: only its upgrade card.
	all.reward_no = 0
	var cards := all.deal_reward()
	eq(cards.size(), 1, "only the upgrade card")
	check(all.level(str(cards[0])) == 1, "a perk held (%s)" % str(cards[0]))


## G (docs/roadmap.md 十.5-6, M9.8 step 2): the shelf is not rerolled; each morning it
## holds config.shelf_upgrades upgrade slots, each a dealt perk held below its top,
## bought from cash at its next level's price, once, that day.
func test_upgrade_slots() -> void:
	var res := _rich(100000)
	var r: RunState = res[0]
	var e: Economy = res[1]
	check(not r.has_method("reroll_shelf"), "the shelf has no reroll")
	eq(r.upgrades, [], "nothing held: no slot")
	var held := {"closer": 1, "penny": 1, "luck": 2, "stakeout": 1, "savings": 1, "combo": 1}
	r.perks = held.duplicate()
	eq(r.upgradable(), ["closer", "penny", "luck"], "the dealt perks held below their top (not STAKEOUT at its top, SAVINGS on the shelf, CHAIN parked)")
	var seen := {}
	for i in 60:
		r.seed = "UP-%d" % i
		var ups := r.deal_upgrades()
		eq(ups.size(), 1, "one slot")
		check(r.upgradable().has(ups[0]), "drawn among them (%s)" % str(ups))
		seen[ups[0]] = true
		eq(r.deal_upgrades(), ups, "the same seed, layer and day draw the same")
	eq(seen.size(), 3, "each of them now and then")
	# Bought once, at the perk's next price.
	r.seed = "P-1"
	r.upgrades = r.deal_upgrades()
	var id: String = r.upgrades[0]
	var off: String = ["closer", "luck", "penny"].filter(func(x): return x != id)[0]
	check(not r.can_buy_upgrade(off, e) and not r.buy_upgrade(off, e), "a perk not in today's slots: not sold")
	var price := r.perk_price(id)
	var cash := e.cash
	check(r.buy_upgrade(id, e), "the slot's upgrade bought")
	eq(r.level(id), int(held[id]) + 1, "a level up")
	eq(cash - e.cash, price, "at its next price")
	check(not r.upgrades.has(id) and not r.buy_upgrade(id, e), "it leaves the slot: once")
	# Gone the next day: the next morning draws anew.
	r.play(e)
	r.end_day(e)
	eq(r.upgrades, r.deal_upgrades(), "the next morning's slot")
	# A perk taken from this morning's round is not on today's slots (they were drawn
	# first); it can be tomorrow's.
	var t := _rich(100000)
	var tr2: RunState = t[0]
	var te: Economy = t[1]
	var taken: String = tr2.offers[0]
	check(tr2.buy_offer(0, te), "a card taken")
	check(not tr2.upgrades.has(taken), "not on today's slots")
	if tr2.upgradable().has(taken):
		tr2.play(te)
		tr2.end_day(te)
		eq(tr2.upgrades, [taken], "tomorrow's, the only one held")
	# The config's count: two slots, two different perks; none.
	var d: Dictionary = RunConfig.STANDARD.duplicate(true)
	d.shelf_upgrades = 2
	var two := RunState.start(RunConfig.from_dict(d), "P-1", ["diner", "bar", "bingo"])
	two.perks = held.duplicate()
	var ups2 := two.deal_upgrades()
	check(ups2.size() == 2 and ups2[0] != ups2[1], "two slots, two perks (%s)" % str(ups2))
	d.shelf_upgrades = 0
	var none := RunState.start(RunConfig.from_dict(d), "P-1", ["diner", "bar", "bingo"])
	none.perks = held.duplicate()
	eq(none.deal_upgrades(), [], "no slot")
	eq(RunConfig.standard().shelf_upgrades, 1, "the standard config: one (G)")
	# Saved and loaded.
	r.perks = held.duplicate()
	r.upgrades = r.deal_upgrades()
	var back := RunState.from_dict(r.to_dict(), r.config)
	eq(back.upgrades, r.upgrades, "the slots are saved")
	check(e.balanced(), "ledger balanced")


## Pays layer `r`'s debt on its current day (cash put in first).
func _pay_now(r: RunState, e: Economy) -> bool:
	e.bonus(maxi(0, r.due() - e.cash) + 10)
	return r.pay(e)


## How many reward rounds come up in a row, each given up for its item.
func _count_rewards(r: RunState) -> int:
	var n := 0
	while r.offers_open and r.offer_reward and n < 20:
		n += 1
		r.skip_offers()
	return n


## G (docs/roadmap.md 十.7, M9.8 step 2): paying a layer (not the last) gives a reward
## round, and one more for every day paid early, counted against the layer's own days
## (SHORT WEEK's taken off), not a day bought from the lender.
func test_reward_rounds_by_days_paid_early() -> void:
	var r := _run()
	var e := r.new_economy()
	check(_pay_now(r, e), "layer 1 paid on day 1 of 5")
	eq(r.rewards_pending + 1, 5, "one and four for the days early")
	eq(_count_rewards(r), 5, "five reward rounds in a row")
	check(r.offers_open and not r.offer_reward, "then the morning's round")
	eq(r.stats.reward_rounds, 5, "counted")
	# On the last day: one.
	var last := _run()
	var le := last.new_economy()
	last.day = 5
	_pay_now(last, le)
	eq(_count_rewards(last), 1, "paid on the last day: one")
	# A day bought from the lender is not one of the layer's own: buying it and paying
	# mints nothing.
	var plain := _run()
	var pe := plain.new_economy()
	plain.day = 3
	_pay_now(plain, pe)
	var bought := _run()
	var be := bought.new_economy()
	bought.day = 3
	be.bonus(10000)
	check(bought.buy_service("more_time", be), "a day bought")
	eq(bought.days(), 6, "six days now")
	_pay_now(bought, be)
	eq(_count_rewards(plain), 3, "paid on day 3 of 5: three")
	eq(_count_rewards(bought), 3, "the same with a day bought: three, not four")
	var late := _run()
	var lae := late.new_economy()
	late.day = 5
	lae.bonus(10000)
	late.buy_service("more_time", lae)
	late.day = 6
	_pay_now(late, lae)
	eq(_count_rewards(late), 1, "paid on the bought sixth day: one")
	# SHORT WEEK: the layer's own days are fewer.
	var short := _run()
	var se := short.new_economy()
	short.perks = {"shortweek": 1}
	_pay_now(short, se)
	eq(_count_rewards(short), 4, "SHORT WEEK 1, paid on day 1 of 4: four")
	# The last layer paid clears the run: no reward round.
	var end := _run()
	var ee := end.new_economy()
	end.layer = 2
	_pay_now(end, ee)
	check(end.status == RunState.CLEARED and not end.offers_open and end.rewards_pending == 0, "the run cleared: none")


## A reward round (docs/roadmap.md 十.7): free, new perks of rarity rare or legendary
## (commons fill when too few are left), one card a free upgrade of a perk held when one
## is below its top, no reroll, given up for an item like any round; seeded by the
## seed, the layer and the reward's index, saved and loaded mid-chain.
func test_reward_rounds() -> void:
	var r := _run()
	var e := r.new_economy()
	r.perks = {"closer": 1}
	_pay_now(r, e)
	check(r.offer_reward and r.offers.size() == Catalog.OFFERS, "a reward round of three cards")
	eq(r.offers[r.offers.size() - 1], "closer", "the last is CLOSER's free upgrade (the only perk held)")
	for k in r.offers.size() - 1:
		var p := r.catalog.perk(str(r.offers[k]))
		check(p.rarity != "common" and r.level(p.id) == 0, "%s: a new perk, rare or better" % p.id)
	# No reroll.
	e.pay(e.cash)
	e.bonus(100000)
	var cash := e.cash
	check(not r.can_reroll_offers(e) and not r.reroll_offers(e), "a reward round has no reroll")
	eq(e.cash, cash, "nothing paid")
	# Free: taken with no cash at all.
	var spend := e.cash
	e.pay(spend)
	var shop := int(r.stats.shop)
	check(r.can_buy_offer(0, e), "free, the pocket empty")
	var id: String = r.offers[0]
	check(r.buy_offer(0, e), "taken")
	eq(r.level(id), 1, "held")
	eq(int(r.stats.shop), shop, "nothing spent")
	check(r.offer_reward and r.rewards_pending == 3, "the next reward round up, three more to come")
	# The upgrade card: taken, a level up for nothing.
	var up := str(r.offers[r.offers.size() - 1])
	check(r.level(up) > 0, "the upgrade card is a perk held (%s)" % up)
	var lv := r.level(up)
	check(r.buy_offer(r.offers.size() - 1, e), "the upgrade taken")
	eq(r.level(up), lv + 1, "a level up")
	# Given up for an item, like any round.
	var gift := r.skip_offers()
	check(gift != "" and r.held(gift) == 1, "a reward round given up: an item (%s)" % gift)
	# Seeded by the seed, the layer and the index: the same cards whatever the order.
	var a := _run()
	var b := _run()
	a.layer = 1
	b.layer = 1
	for k in 4:
		a.reward_no = k
		b.reward_no = k
		eq(a.deal_reward(), b.deal_reward(), "reward %d: the same seed deals the same" % k)
	# Saved and loaded mid-chain: the round up and the ones to come.
	var d := r.to_dict()
	var back := RunState.from_dict(d, r.config)
	eq(back.offers, r.offers, "the round up")
	check(back.offers_open and back.offer_reward == r.offer_reward, "a reward round still")
	eq(back.rewards_pending, r.rewards_pending, "the reward rounds to come")
	eq(back.reward_no, r.reward_no, "and where the chain is")
	var be := Economy.new()
	be.cash = 0
	var seq_a := []
	var seq_b := []
	for run_e in [[r, e, seq_a], [back, be, seq_b]]:
		var x: RunState = run_e[0]
		var guard := 0
		while x.offers_open and guard < 10:
			guard += 1
			run_e[2].append(x.offers.duplicate())
			if x.offer_reward:
				x.buy_offer(0, run_e[1])
			else:
				x.skip_offers()
	eq(seq_b, seq_a, "the loaded run deals the same rounds after it")
	# Commons fill the cards when too few rare-or-better perks are left to deal.
	var c := _run()
	c.layer = 1
	for p in c.catalog.dealt():
		if p.rarity != "common":
			c.perks[p.id] = 1
	c.reward_no = 0
	var cards := c.deal_reward()
	eq(cards.size(), c.offer_count(), "not short")
	var commons := 0
	for k in cards.size() - 1:
		if c.catalog.perk(str(cards[k])).rarity == "common" and c.level(str(cards[k])) == 0:
			commons += 1
	eq(commons, cards.size() - 1, "new commons beside the upgrade card")
	# The two-kinds rule where the pool allows: at the second layer's weights.
	var w := _run()
	w.layer = 1
	var deals := []
	for i in 40:
		w.seed = "RW-%d" % i
		w.reward_no = i % 3
		deals.append(w.deal_reward())
	_two_and_two(w, deals, "reward rounds")
	for dl in deals:
		for cid in dl:
			check(w.catalog.perk(str(cid)).rarity != "common", "nothing held: every card rare or better (%s)" % cid)


## Saves made before the rounds (M9.8 step 2) load by the new rules.
func test_old_saves_and_the_rounds() -> void:
	var res := _rich(1000)
	var r: RunState = res[0]
	var d := r.to_dict()
	# Offers put away with LATER: the round had ended.
	var later := d.duplicate(true)
	later.offers_open = false
	later.shelf_rerolls = 2
	later.erase("upgrades")
	later.erase("offer_reward")
	later.erase("rewards_pending")
	later.erase("reward_no")
	var a := RunState.from_dict(later, r.config)
	check(a != null, "loads")
	check(a.offers.is_empty() and not a.offers_open, "with no offers")
	eq(a.upgrades, [], "no upgrade slots until the next morning")
	check(not a.offer_reward and a.rewards_pending == 0, "no reward round")
	# Offers with something bought from them (the old card stayed up): over too.
	var bought := d.duplicate(true)
	bought.offer_bought = true
	var b := RunState.from_dict(bought, r.config)
	check(b.offers.is_empty() and not b.offers_open, "something bought from them: no offers")
	# An open round with nothing bought loads as it was.
	var open := RunState.from_dict(d, r.config)
	eq(open.offers, r.offers, "an open round loads")
	check(open.offers_open and not open.offer_reward, "a morning round")
	# Odd values are kept within bounds.
	var odd := d.duplicate(true)
	odd.rewards_pending = 40
	odd.offer_reward = true
	odd.offers = []
	var o := RunState.from_dict(odd, r.config)
	check(o.rewards_pending == 0 and not o.offer_reward, "layer 1: no reward rounds pending, none up without cards")
	odd.layer = 1
	odd.rewards_pending = 40
	o = RunState.from_dict(odd, r.config)
	eq(o.rewards_pending, int(r.config.layer(0).days) + 1, "at most the paid layer's days and one")


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


## A run on the standard config with `over` laid on it (the dealing experiments).
func _exp_run(over: Dictionary, seed_text := "P-1") -> RunState:
	var d: Dictionary = RunConfig.STANDARD.duplicate(true)
	d.merge(over, true)
	return RunState.start(RunConfig.from_dict(d), seed_text, ["diner", "bar", "bingo"])


## Every reward deal of `r` over 60 seeds and 3 reward indices, the new cards only (a
## card of a perk held is the upgrade card).
func _reward_deals(r: RunState) -> Array:
	var out := []
	for i in 60:
		r.seed = "DEAL-%d" % i
		for k in 3:
			r.reward_no = k
			out.append(r.deal_reward().filter(func(id): return r.level(id) == 0))
	return out


## The dealing experiments of docs/roadmap.md 十三.5 (RunConfig deal_bias, reward_bias,
## free_rerolls, starter, offer_bonus; not rules yet): every one off in the standard
## config, where the deal is what it was; off by hand, the same.
func test_deal_experiments_off() -> void:
	var std := RunConfig.standard()
	check(std.deal_bias == 1.0 and std.reward_bias == 1.0, "the biases off (1.0)")
	check(std.free_rerolls == 0 and std.starter == 0 and std.offer_bonus == 0, "free rerolls, starter, offer bonus off (0)")
	eq(std.problems(), PackedStringArray(), "the standard config holds together")
	var off := _exp_run({"deal_bias": 1.0, "reward_bias": 1.0, "free_rerolls": 0, "starter": 0, "offer_bonus": 0})
	var r := _run()
	eq(off.offers, r.offers, "the first round of a seed: the same")
	eq(_deals(off), _deals(r), "every deal of 60 seeds: the same")
	for run in [off, r]:
		run.layer = 1
		run.perks = {"closer": 1, "penny": 1, "savings": 1}
	eq(_deals(off), _deals(r), "with perks held, at layer 2: the same")
	eq(_reward_deals(off), _reward_deals(r), "reward rounds: the same")
	# The pool: the layer's weight, doubled for a perk with requirements, nothing else.
	for c in r._pool(r.offerable()):
		var p := r.catalog.perk(c.id)
		var w := Catalog.deal_weight(p, r.layer) * (2.0 if not p.get("requires", {}).is_empty() else 1.0)
		eq(float(c.w), w, "%s: its weight as before" % c.id)
	r.offer_rerolls = 0
	eq(r.reroll_price(), Catalog.OFFER_REROLL * r.stake(), "the first reroll at its price")
	eq(r.offer_bonus, 0, "no offer bonus")


## deal_bias (an experiment): a morning round's perks of a branch held (a dealt perk,
## not the shelf's) weigh that many times more; reward rounds are not touched.
func test_deal_bias() -> void:
	var b := _exp_run({"deal_bias": 4.0})
	var r := _run()
	for run in [b, r]:
		run.layer = 1
		run.perks = {"closer": 1, "savings": 1}
	eq(b.held_branches(), {"clearing": true}, "CLOSER's branch held; SAVINGS on the shelf is not counted")
	var plain := r._pool(r.offerable())
	var biased := b._pool(b.offerable(), b.config.deal_bias)
	eq(plain.size(), biased.size(), "the same perks in the pool")
	for k in plain.size():
		var x := 4.0 if str(plain[k].branch) == "clearing" else 1.0
		eq(float(biased[k].w), float(plain[k].w) * x, "%s: x%.0f" % [plain[k].id, x])
	var clearing := func(p: Dictionary) -> bool: return p.branch == "clearing"
	var nb := _count(b, _deals(b), clearing)
	var nr := _count(r, _deals(r), clearing)
	check(nb > nr, "over 180 deals, more clearing cards with the bias (%d to %d)" % [nb, nr])
	note("deal_bias 4, CLOSER held: clearing cards over 180 deals %d, standard %d" % [nb, nr])
	eq(_reward_deals(b), _reward_deals(r), "reward rounds as standard")
	# Only the shelf held: no branch to lean toward, the deal as standard.
	for run in [b, r]:
		run.perks = {"savings": 1, "regular": 1}
	eq(_deals(b), _deals(r), "only shelf perks held: as standard")


## reward_bias (an experiment): the same multiplier on a reward round's new cards only.
func test_reward_bias() -> void:
	var b := _exp_run({"reward_bias": 4.0})
	var r := _run()
	for run in [b, r]:
		run.layer = 1
		run.perks = {"closer": 1}
	eq(_deals(b), _deals(r), "morning rounds as standard")
	var clearing := func(p: Dictionary) -> bool: return p.branch == "clearing"
	var nb := _count(b, _reward_deals(b), clearing)
	var nr := _count(r, _reward_deals(r), clearing)
	check(nb > nr, "over 180 reward rounds, more new clearing cards with the bias (%d to %d)" % [nb, nr])
	note("reward_bias 4, CLOSER held: new clearing cards over 180 reward rounds %d, standard %d" % [nb, nr])


## free_rerolls (an experiment): the first that many rerolls of each morning round cost
## nothing, the paid ones after start at the first price and double; all counted in
## stats.rerolls, the free ones in stats.free_rerolls; a save keeps where the round is.
func test_free_rerolls() -> void:
	var r := _exp_run({"free_rerolls": 1})
	var e := r.new_economy()
	e.bonus(10000)
	var cash := e.cash
	eq(r.reroll_price(), 0, "the first reroll: free")
	check(r.can_reroll_offers(e) and r.reroll_offers(e), "rerolled")
	eq(e.cash, cash, "for nothing")
	eq(int(r.stats.rerolls), 1, "counted as a reroll")
	eq(int(r.stats.free_rerolls), 1, "and as a free one")
	eq(r.paid_rerolls(), 0, "none paid")
	eq(r.reroll_price(), Catalog.OFFER_REROLL, "the next at the first price ($20)")
	var back := RunState.from_dict(r.to_dict(), r.config)
	eq(back.reroll_price(), Catalog.OFFER_REROLL, "saved and loaded mid-round: still $20")
	eq(int(back.stats.free_rerolls), 1, "the count kept")
	eq(back.offers, r.offers, "the round kept")
	check(r.reroll_offers(e), "rerolled again")
	eq(cash - e.cash, Catalog.OFFER_REROLL, "paid $20")
	eq(r.reroll_price(), Catalog.OFFER_REROLL * 2, "then $40")
	eq(int(r.stats.rerolls), 2, "two rerolls")
	eq(int(r.stats.free_rerolls), 1, "one free")
	eq(r.paid_rerolls(), 1, "one paid")
	var fresh := RunState.from_dict(_exp_run({"free_rerolls": 1}).to_dict(), r.config)
	eq(fresh.reroll_price(), 0, "saved before the round's reroll: free on load")
	r.skip_offers()
	r.play(e)
	r.end_day(e)
	check(r.offers_open and not r.offer_reward, "the next morning's round")
	eq(r.reroll_price(), 0, "free again: each morning round")
	var two := _exp_run({"free_rerolls": 2})
	var e2 := two.new_economy()
	check(two.reroll_offers(e2) and two.reroll_offers(e2), "two free rerolls")
	eq(two.reroll_price(), Catalog.OFFER_REROLL, "then $20")
	eq(e2.cash, e2.start_cash, "nothing paid")
	# A reroll deals as before: the deal is the seed's, the layer's, the day's and the
	# reroll's, free or not.
	var s := _run()
	s.offer_rerolls = 2
	eq(two.offers, s.deal_offers(), "the same cards as a paid second reroll would deal")
	check(e2.balanced(), "ledger balanced")


## starter (an experiment): the run's first morning round is one entry card of each of
## three build lines drawn from the seed; only that round, a reroll of it deals as usual.
func test_starter_round() -> void:
	var r := _run()
	var entries := {}
	for b in RunState.STARTER_LINES:
		entries[b] = r.entry_card(b)
	eq(entries, {"clearing": "closer", "jackpot": "pity", "small": "penny", "batch": "streak", "money": "middle"},
		"each line's entry card: its cheapest perk with no requirements at layer 1 (SMALL: PENNY JAR before SCRAP DEALER, the same price)")
	var lines_seen := {}
	for i in 30:
		var s := _exp_run({"starter": 1}, "ST-%d" % i)
		eq(s.offers.size(), Catalog.OFFERS, "three cards")
		var branches := {}
		for id in s.offers:
			var br := str(s.catalog.perk(id).branch)
			check(entries.get(br, "") == id, "%s: the entry card of %s" % [id, br])
			branches[br] = true
		eq(branches.size(), 3, "three different lines")
		lines_seen[",".join(s.offers)] = true
		eq(_exp_run({"starter": 1}, "ST-%d" % i).offers, s.offers, "the same for a seed")
	check(lines_seen.size() > 3, "the lines change with the seed (%d sets)" % lines_seen.size())
	# A reroll deals the usual way; so do the next morning and the next layer's first.
	var st := _exp_run({"starter": 1}, "ST-1")
	var std := _exp_run({}, "ST-1")
	var e := st.new_economy()
	check(st.reroll_offers(e), "rerolled")
	std.offer_rerolls = 1
	eq(st.offers, std.deal_offers(), "a reroll of it: the usual deal")
	var st2 := _exp_run({"starter": 1}, "ST-1")
	var e2 := st2.new_economy()
	var std2 := _exp_run({}, "ST-1")
	var es := std2.new_economy()
	for pair in [[st2, e2], [std2, es]]:
		pair[0].skip_offers()
		pair[0].play(pair[1])
		pair[0].end_day(pair[1])
	eq(st2.offers, std2.offers, "the second morning: the usual deal")
	st2.layer = 1
	st2.day = 1
	std2.layer = 1
	std2.day = 1
	eq(st2.deal_offers(), std2.deal_offers(), "the next layer's first morning: the usual deal")
	# A fourth card (offer_bonus) is dealt the usual way, not another entry card.
	var four := _exp_run({"starter": 1, "offer_bonus": 1}, "ST-2")
	eq(four.offers.size(), 4, "four cards")
	eq(four.offers.slice(0, 3), _exp_run({"starter": 1}, "ST-2").offers, "the first three: the starter's")
	check(not four.offers.slice(0, 3).has(four.offers[3]), "the fourth another perk (%s)" % str(four.offers[3]))


## starter 2 (an experiment): the starter round of starter 1, its pick free like a
## reward round's; a morning round in every other way: rerolled, it deals a paid round;
## given up, an item. A save keeps it.
func test_free_starter_round() -> void:
	var s := _exp_run({"starter": 2}, "ST-1")
	var e := s.new_economy()
	eq(s.offers, _exp_run({"starter": 1}, "ST-1").offers, "the cards of starter 1")
	check(s.starter_pick() and not s.offer_reward, "a free pick, still a morning round")
	check(not _exp_run({"starter": 1}, "ST-1").starter_pick(), "starter 1: not free")
	check(not _run().starter_pick(), "the standard config: not free")
	var k := 0
	for i in s.offers.size():
		if s.perk_price(s.offers[i]) > s.perk_price(s.offers[k]):
			k = i
	var id: String = s.offers[k]
	check(s.can_buy_offer(k, e), "the dearest card (%s, $%d) can be taken with $%d" % [id, s.perk_price(id), e.cash])
	var cash := e.cash
	check(s.buy_offer(k, e), "taken")
	eq(s.level(id), 1, "held")
	eq(e.cash, cash, "nothing paid")
	eq(int(s.stats.shop), 0, "nothing counted as spent")
	eq(int(s.stats.perks), 1, "a perk counted")
	check(not s.offers_open and not s.starter_pick(), "the round is over")
	check(e.balanced(), "ledger balanced")
	# A CHEAT SHEET is not used up on it.
	var c := _exp_run({"starter": 2}, "ST-1")
	var ec := c.new_economy()
	c.items["cheat"] = 1
	check(c.buy_offer(0, ec, true), "taken with free set")
	eq(c.held("cheat"), 1, "the CHEAT SHEET kept")
	# Rerolled: a paid morning round, the usual deal.
	var r := _exp_run({"starter": 2}, "ST-1")
	var er := r.new_economy()
	er.bonus(10000)
	check(r.reroll_offers(er), "rerolled")
	check(not r.starter_pick(), "no longer free")
	var std := _exp_run({}, "ST-1")
	std.offer_rerolls = 1
	eq(r.offers, std.deal_offers(), "the usual deal")
	var price := r.perk_price(r.offers[0])
	cash = er.cash
	check(r.buy_offer(0, er), "a card bought")
	eq(cash - er.cash, price, "at its price")
	# Saved and loaded with the round up: still free.
	var sv := _exp_run({"starter": 2}, "ST-1")
	var back := RunState.from_dict(sv.to_dict(), sv.config)
	check(back.starter_pick(), "loaded: still the free pick")
	eq(back.offers, sv.offers, "the same cards")
	var eb := back.new_economy()
	cash = eb.cash
	check(back.buy_offer(k, eb), "taken after loading")
	eq(eb.cash, cash, "for nothing")
	# Given up for an item; the next morning is an ordinary round.
	var g := _exp_run({"starter": 2}, "ST-1")
	var eg := g.new_economy()
	var gift := g.skip_offers()
	check(gift != "" and g.held(gift) == 1, "given up: an item (%s)" % gift)
	g.play(eg)
	g.end_day(eg)
	check(g.offers_open and not g.starter_pick(), "day 2: not free")


## offer_bonus in the config (an experiment): copied to the run when it starts.
func test_offer_bonus_from_the_config() -> void:
	var r := _exp_run({"offer_bonus": 1})
	eq(r.offer_bonus, 1, "the run's bonus from the config")
	eq(r.offers.size(), Catalog.OFFERS + 1, "four cards a round")
	var back := RunState.from_dict(r.to_dict(), r.config)
	eq(back.offer_bonus, 1, "kept by a save")
	eq(_run().offer_bonus, 0, "the standard config: none")


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


## QUICK HANDS, CHAIN and ENCORE wait for the shop outside the run (M13, G 2026-11-07):
## never on the shelf, dealt or sold in a run, their effects still working when held.
func test_batch_perks_wait_for_m13() -> void:
	var c := Catalog.standard()
	var parked := ["multi", "combo", "again"]
	for id in parked:
		check(Catalog.meta(c.perk(id)), "%s is parked (meta)" % id)
		check(not c.dealt().has(c.perk(id)), "%s is never dealt" % id)
		for k in Catalog.KINDS:
			check(not c.perks_of(k).has(c.perk(id)), "%s is in no kind's list (%s)" % [id, k])
	eq(c.perk("allin").get("requires", {}), {"streak": 1}, "ALL IN needs STREAK 1 (CHAIN went with QUICK HANDS)")
	var res := _rich(1000000)
	var r: RunState = res[0]
	var e: Economy = res[1]
	for id in parked:
		check(not r.shelf_perks().has(id), "%s is not on the shelf" % id)
		check(not r.offerable().has(id), "%s cannot be offered" % id)
	check(not r.buy_perk("multi", e), "QUICK HANDS is not sold, rich as the player is")
	r.perks["multi"] = 2
	check(not r.offerable().has("combo") and not r.offerable().has("again"), "not even with QUICK HANDS held")
	r.offers = ["combo"]
	check(not r.can_buy_offer(0, e) and not r.buy_offer(0, e), "CHAIN put in the offers by hand is not sold")
	eq(r.level("combo"), 0, "nothing bought")
	# Every layer's deals over many seeds and rerolls, with every requirement met.
	r.perks = {"multi": 3, "streak": 1}
	for l in 3:
		r.layer = l
		for k in 30:
			r.offer_rerolls = k
			for id in r.deal_offers():
				check(not parked.has(id), "layer %d: %s dealt" % [l + 1, id])
	check(not r.offerable().has("multi") and r.missing("allin").is_empty(), "with STREAK 1 ALL IN can be offered")
	# The simulator's bots do not buy them.
	for line in SimBots.NAMES:
		var spec := SimBots.spec(line)
		for id in spec.params.perks + spec.params.shelf:
			check(not parked.has(id), "the %s bot buys %s" % [line, id])
	# Held (a save, the developer panel, M13): they still work.
	r.perks = {"multi": 1}
	eq(r.batch_size(), 5, "QUICK HANDS 1 held: five at once")
	r.perks = {"multi": 3}
	eq(r.batch_size(), 9999, "QUICK HANDS 3: the whole tray")


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
	# Not rerolled (M9.8 step 2): the next morning brings another.
	var before := r.shelf.duplicate()
	r.play(e)
	r.end_day(e)
	check(r.shelf.size() == Catalog.SHELF and r.shelf != before, "a new shelf the next morning")
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
	var w2 := r2.wage()
	r2.work(e2)
	eq(e2.earned, 2 * w2, "the shift paid double")
	check(not r2.can_use_now("overtime"), "once a day")
	r2.end_day(e2)
	r2.work(e2)
	check(r2.use_now("overtime", null, e2).get("on", false), "after a shift")
	eq(e2.earned, 4 * w2, "the wage again")
	r2.end_day(e2)
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


## A tray entry of Big Catch at tier `tier` (-1: a loser), not from a box.
func _entry(tier: int) -> Dictionary:
	return {"form": _catch(), "ticket": _ticket(tier), "box": null, "bet": 1}


## Ten tickets opened by hand in `r`: the tiers in `tiers` first, losers after.
func _window(r: RunState, e: Economy, tiers: Array) -> void:
	for k in Catalog.WINDOW:
		r.open_ticket(e, _entry(int(tiers[k]) if k < tiers.size() else -1))


## A run on a day of play with `cash` in hand.
func _playing(cash: int) -> Array:
	var res := _rich(cash)
	res[0].play(res[1])
	return res


func test_the_window_of_ten() -> void:
	if _catch() == null:
		return
	var res := _playing(1000)
	var r: RunState = res[0]
	var e: Economy = res[1]
	for k in 9:
		r.open_ticket(e, _entry(3 if k == 4 else -1))
	eq(r.window_n, 9, "nine opened by hand: the window is still open")
	eq(r.window_printed, 25, "the printed prizes so far")
	check(r.last_window.is_empty(), "none closed yet")
	r.open_ticket(e, _entry(2))
	eq(r.window_n, 0, "the tenth closes it")
	eq(r.last_window, {"printed": 125, "paid": 125, "bar": 125}, "printed and paid, the same without perks; Big Catch's bar is all of it")
	# The printed sum is before the bet and every perk; the pay is what the ledger got.
	r.perks = {"prizes": 3}
	_window(r, e, [3])
	eq(r.last_window, {"printed": 25, "paid": 50, "bar": 25}, "FAT PRIZES 3: paid double, printed the same")
	# QUICK HANDS 5 twice makes one window; QUICK HANDS 20 closes two in one opening
	# (QUICK HANDS waits for M13: set directly, its effect still works).
	r.perks = {"multi": 1}
	r.open_batch(e, [_entry(3), _entry(-1), _entry(-1), _entry(-1), _entry(-1)])
	eq(r.window_n, 5, "five at once: half a window")
	r.open_batch(e, [_entry(-1), _entry(-1), _entry(-1), _entry(-1), _entry(-1)])
	eq(r.window_n, 0, "five more close it")
	eq(int(r.last_window.printed), 25, "one window of ten")
	r.perks = {"multi": 2, "streak": 1}
	var twenty := []
	for k in 20:
		twenty.append(_entry(3 if k == 0 or k == 10 else -1))
	r.open_batch(e, twenty)
	eq(r.window_n, 0, "QUICK HANDS 20 from an empty window: two windows, none open")
	eq(r.streak, 2, "both counted (STREAK)")
	check(e.balanced(), "ledger balanced")


func test_streak() -> void:
	if _catch() == null:
		return
	var res := _playing(1000)
	var r: RunState = res[0]
	var e: Economy = res[1]
	_window(r, e, [3])
	eq(r.streak, 0, "without STREAK nothing is counted")
	r.perks = {"streak": 1}
	eq(r.streak_pct(), 0, "no streak yet")
	_window(r, e, [3])
	eq(r.streak, 1, "a window with a winner")
	eq(r.streak_pct(), 25, "STREAK 1: +25% on what follows")
	eq(r.prize_pct(null), 25, "in the + slot")
	# The next window's prizes are paid with it: a $25 ticket pays $31.
	var won := e.won
	r.open_ticket(e, _entry(3))
	eq(e.won - won, 31, "$25 at +25%")
	for k in 9:
		r.open_ticket(e, _entry(-1))
	eq(r.streak, 2, "two in a row")
	_window(r, e, [])
	eq(r.streak, 0, "a window of losers: back to 0")
	for w in 5:
		_window(r, e, [3])
	eq(r.streak, 5, "five in a row")
	eq(r.streak_pct(), 100, "125% capped at +100%")
	r.perks = {"streak": 2}
	eq(r.streak_pct(), 160, "STREAK 2: 40% a window, capped at +160%")
	r.end_day(e)
	eq(r.streak, 0, "a new day: the streak starts over")
	check(e.balanced(), "ledger balanced")


func test_all_in() -> void:
	if _catch() == null:
		return
	var res := _playing(1000)
	var r: RunState = res[0]
	var e: Economy = res[1]
	_window(r, e, [3])
	check(not r.can_push(e), "without the perk: no")
	r.perks = {"allin": 1}
	check(r.can_push(e), "with it: the window just closed paid $25")
	eq(r.push_offer(), 25, "the stake is what it paid")
	r.open_ticket(e, _entry(-1))
	check(not r.can_push(e), "not once a ticket of the next window is open")
	for k in 9:
		r.open_ticket(e, _entry(3 if k == 0 else -1))
	# Won: the next window prints more.
	var cash := e.cash
	check(r.push(e), "staked")
	eq(e.cash, cash - 25, "the stake leaves the cash")
	eq(int(r.stats.staked), 25, "counted")
	check(not r.can_push(e) and not r.push(e), "not again while a push is pending")
	_window(r, e, [2])
	eq(e.cash, cash - 25 + 100 + 75, "$100 printed reaches $25: the window's $100 and the stake x3")
	eq(int(r.stats.push_won), 75, "what came back")
	eq(r.push_stake, 0, "settled")
	# Big Catch's bar is all of the window (Catalog.ALL_IN_SHARE): as much printed wins.
	# A new push goes on the window that settled one.
	check(r.can_push(e), "a new push on that window")
	eq(r.push_offer(), 100, "its $100")
	eq(r.push_target(), 100, "the next ten must print $100 at least")
	r.push(e)
	eq(r.push_need, 100, "the bar is kept with the stake")
	cash = e.cash
	_window(r, e, [2])
	eq(e.cash, cash + 100 + 300, "as much printed: the window's $100 and the stake x3")
	eq(int(r.stats.push_won), 375, "won again")
	# Lost: less printed than the bar.
	r.push(e)
	cash = e.cash
	_window(r, e, [3, 3])
	eq(e.cash, cash + 50, "$50 printed under the $100 bar: the window's prize only")
	eq(int(r.stats.push_lost), 100, "the stake is lost")
	# What the tickets print counts, not what they pay: FAT PRIZES bought between the
	# windows pays the next one double, and still does not win.
	_window(r, e, [2])
	r.push(e)
	r.perks = {"allin": 1, "prizes": 3}
	cash = e.cash
	_window(r, e, [3, 3])
	eq(e.cash, cash + 100, "paid $100, printed $50 under the $100 bar: lost")
	eq(int(r.stats.push_lost), 200, "a second stake lost")
	r.perks = {"allin": 1}
	# Nothing paid: nothing to stake.
	_window(r, e, [])
	check(not r.can_push(e), "a window of losers cannot be staked")
	# Short of cash.
	_window(r, e, [2])
	e.pay(e.cash - 50)
	check(not r.can_push(e), "$50 in cash does not cover a $100 stake")
	e.bonus(1000)
	# A new day: a pending push is lost, the window starts over.
	check(r.push(e), "staked before leaving")
	var lost: int = r.stats.push_lost
	r.end_day(e)
	eq(r.push_stake, 0, "a new day clears the push")
	eq(int(r.stats.push_lost), lost + 100, "and its stake is gone")
	check(r.last_window.is_empty() and r.window_n == 0 and not r.can_push(e), "a fresh window")
	check(e.balanced(), "ledger balanced")


## ALL IN's bar is each ticket's form's share of the window (G, 2026-11-07: a push wins
## about half the time on every form): Ka-Bawk! half of it, Big Catch all of it.
func test_all_in_bar_by_form() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var kabawk: FormDef = null
	for f in pack.forms:
		if f.id == "kabawk":
			kabawk = f
	if not check(kabawk != null, "Ka-Bawk! is in the core pack"):
		return
	eq(Catalog.all_in_share(kabawk.uid()), 50, "Ka-Bawk!: half")
	var res := _playing(5000)
	var r: RunState = res[0]
	var e: Economy = res[1]
	r.perks = {"streak": 1, "allin": 1}
	var mid: int = kabawk.tier_indices("mid")[0]
	var low := RunState.smallest_tier(kabawk)
	var kb := func(tier: int) -> Dictionary:
		return {"form": kabawk, "ticket": {"no": 100, "tier": tier, "prize": int(kabawk.tiers[tier].prize) if tier >= 0 else 0},
			"box": null, "bet": 1}
	# A Ka-Bawk! window of $100: the bar is $50, and $50 printed wins.
	r.open_ticket(e, kb.call(mid))
	for k in 9:
		r.open_ticket(e, kb.call(-1))
	eq(r.last_window.bar, 50, "half of $100")
	eq(r.push_target(), 50, "what the card shows")
	check(r.push(e), "staked $100")
	r.open_ticket(e, kb.call(low))
	r.open_ticket(e, kb.call(low))
	for k in 8:
		r.open_ticket(e, kb.call(-1))
	eq(int(r.stats.push_won), 300, "$50 printed reaches the $50 bar: x3 back")
	# A window of both forms: each ticket at its own form's share ($100 Big Catch at
	# 100%, $100 Ka-Bawk! at 50%: a bar of $150).
	r.open_ticket(e, _entry(2))
	r.open_ticket(e, kb.call(mid))
	for k in 8:
		r.open_ticket(e, _entry(-1))
	eq(r.last_window.printed, 200, "printed $200")
	eq(r.last_window.bar, 150, "the bar: $100 + $50")
	# A window that paid without printing (SCRAP DEALER's give-back) has a $1 bar: the
	# next window must print something.
	r.perks = {"streak": 1, "allin": 1, "scrap": 2}
	_window(r, e, [])
	check(r.can_push(e) and r.last_window.printed == 0, "paid, printed nothing: it can be staked")
	eq(r.push_target(), 1, "the bar is $1")
	var stake := r.push_offer()
	check(r.push(e), "staked")
	var lost: int = r.stats.push_lost
	_window(r, e, [])
	eq(int(r.stats.push_lost), lost + stake, "an empty window loses")
	check(e.balanced(), "ledger balanced")


## ALL IN asks after every window (G, 2026-11-07): while it is held QUICK HANDS opens no
## further than the window's end, so every window closes on an opening's last ticket.
func test_all_in_every_window() -> void:
	if _catch() == null:
		return
	var res := _playing(5000)
	var r: RunState = res[0]
	var e: Economy = res[1]
	r.perks = {"multi": 2}
	eq(r.batch_size(), 20, "QUICK HANDS 2 without ALL IN: 20 at once")
	r.perks = {"multi": 2, "combo": 1, "allin": 1}
	eq(r.batch_size(), 10, "with ALL IN and an empty window: 10")
	r.take_window_closed()
	# By hand three, then OPEN opens the seven the window has left.
	for k in 3:
		r.open_ticket(e, _entry(3 if k == 0 else -1))
	check(not r.take_window_closed(), "three opened: no window closed")
	eq(r.batch_size(), 7, "three opened: the rest of the window, 7")
	var batch := []
	for k in r.batch_size():
		batch.append(_entry(-1))
	r.open_batch(e, batch)
	eq(r.window_n, 0, "the opening ended on the window")
	check(r.take_window_closed(), "a window closed in that opening")
	check(not r.take_window_closed(), "said once")
	check(r.can_push(e), "the card can ask: the window paid $25")
	# An OPEN 20 from here: ten, the card, the next ten, the card again.
	for i in 2:
		eq(r.batch_size(), 10, "an empty window: 10 (opening %d)" % (i + 1))
		batch = []
		for k in r.batch_size():
			batch.append(_entry(2 if k == 0 else -1))
		r.open_batch(e, batch)
		check(r.take_window_closed() and r.window_n == 0, "the window closed on its tenth (opening %d)" % (i + 1))
		check(r.can_push(e), "and the card can ask (opening %d)" % (i + 1))
	# The tenth by hand closes a window too.
	for k in 9:
		r.open_ticket(e, _entry(3 if k == 0 else -1))
	check(not r.take_window_closed(), "nine by hand: open")
	r.open_ticket(e, _entry(-1))
	check(r.take_window_closed() and r.can_push(e), "the tenth by hand: closed, the card asks")
	# QUICK HANDS 3 (the whole tray) is capped the same.
	r.perks = {"multi": 3, "combo": 1, "allin": 1}
	eq(r.batch_size(), 10, "the whole tray with ALL IN: 10")
	r.end_day(e)
	check(not r.take_window_closed(), "a new day clears it")
	check(e.balanced(), "ledger balanced")
	# The simulator's batch bot opens 25 bought in three openings (10, 10, 5) and stakes
	# the first window, which paid.
	var res2 := _playing(5000)
	var r2: RunState = res2[0]
	var e2: Economy = res2[1]
	r2.perks = {"multi": 2, "combo": 1, "allin": 1}
	var bought := []
	for k in 25:
		bought.append(_entry(3 if k == 0 else -1))
	SimRun.open_tickets(SimCtx.of(r2, e2, null, SimBots.spec("batch")), bought)
	eq(int(r2.stats.staked), 25, "the bot staked the first window's $25")
	eq(int(r2.stats.push_lost), 25, "the second printed nothing: lost")
	eq(r2.window_n, 5, "five into the third window")


func test_window_saved() -> void:
	var res := _rich(1000)
	var r: RunState = res[0]
	r.window_n = 7
	r.window_printed = 150
	r.window_paid = 200
	r.window_wins = 2
	r.streak = 3
	r.window_bar = 11250
	r.push_stake = 40
	r.push_printed = 125
	r.push_need = 94
	r.last_window = {"printed": 125, "paid": 40, "bar": 94}
	var d := r.to_dict()
	var back := RunState.from_dict(JSON.parse_string(JSON.stringify(d)), RunConfig.standard())
	check(back != null, "loads")
	if back == null:
		return
	check(back.window_n == 7 and back.window_printed == 150 and back.window_paid == 200 and back.window_wins == 2
		and back.window_bar == 11250, "the window as it stood")
	check(back.streak == 3 and back.push_stake == 40 and back.push_printed == 125 and back.push_need == 94, "the streak and the push")
	eq(back.last_window, {"printed": 125, "paid": 40, "bar": 94}, "the window closed last")
	# A run saved before ALL IN's bar: the old rule, more than the window.
	d.erase("push_need")
	d.erase("window_bar")
	d.last_window = {"printed": 125, "paid": 40}
	var old := RunState.from_dict(JSON.parse_string(JSON.stringify(d)), RunConfig.standard())
	check(old != null and old.push_need == 126 and int(old.last_window.bar) == 126, "a saved push needs more than its window")


func test_high_roller_is_the_bet() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var r := _run()
	eq(r.bet(), 1, "no HIGH ROLLER: x1")
	check(Catalog.standard().perk("bet").get("fixed", false), "the shelf says it cannot be undone")
	r.perks = {"bet": 2}
	eq(r.bet(), 5, "HIGH ROLLER 2: x5")
	var m := r.new_machine(pack.forms, true)
	eq(m.price(0), 5, "the machine sells at x5: a $1 ticket costs $5")
	var e := r.new_economy()
	e.credit = 5
	e.cash -= 5
	var sold := m.sell_now(0, e)
	check(not sold.is_empty() and e.credit == 0, "and is paid at that")
	r.perks = {"bet": 3}
	r.apply(m)
	eq(m.price(0), 10, "level 3 bought: x10")
	check(e.balanced(), "ledger balanced")

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
		b.net_type_id = t[0]
		eq(BoxReading.nature(b), t[1], "%s reads %s" % t)
	# The run: the box is told by its net after the payout, not the type it was drawn.
	b.type_id = "break_even"
	b.net_type_id = "small_loss"
	eq(BoxReading.nature(b), "LEAN BOX", "drawn break even, losing after the payout: LEAN BOX")
	b.net_type_id = ""
	eq(BoxReading.nature(b), "EVEN BOX", "a box with no net type: its own type")
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
	check(back.bet() == 2 and back.dry == 7 and back.snow == 3 and back.happy, "the bet (HIGH ROLLER 1), the losers in a row, the snowball, today's HAPPY HOUR")
	eq(back.coin_on, {"core:catch": 1}, "the coin on its column")
	eq(back.forms_today, r.forms_today, "the forms of the day")
	check(back.day_tickets == 12 and back.noback_days == 2 and back.sure_armed and back.overtime, "the day's count, NO WAY BACK's days, the sure win armed, OVERTIME")
	eq(back.sealed.size(), 1, "the sealed box")
	eq(int(back.sealed[0].cursor), 40, "where it stood")
	eq(back.sealed[0].ops.size(), 2, "with its log")
	eq(back.stats, r.stats, "stats")
	d.perks = {"prizes": 9, "gone": 2, "luck": -1}
	d.offers = ["prizes", "gone", "combo"]
	d.bet = 5   # an older save's bet key: ignored, the bet is the perk's level
	var odd := RunState.from_dict(d, RunConfig.standard())
	eq(odd.perks, {"prizes": 3}, "unknown perks dropped, levels kept within the perk")
	eq(odd.offers, ["prizes"], "an unknown offer dropped, and CHAIN (it waits for M13)")
	eq(odd.bet(), 1, "an old save's bet is ignored: no HIGH ROLLER, x1")
	for k in ["perks", "items", "extra_days", "services", "reports", "offers", "offers_open", "shelf", "bet", "coin_on",
			"forms_today", "sealed", "day_tickets", "sure_armed", "window_n", "window_printed", "window_paid",
			"window_wins", "streak", "push_stake", "push_printed", "last_window", "window_bar", "push_need"]:
		d.erase(k)
	var old := RunState.from_dict(d, RunConfig.standard())
	check(old != null and old.perks.is_empty() and old.items.is_empty() and not old.offers_open, "an older run loads with nothing bought")
	check(old != null and old.coin_on.is_empty() and old.sealed.is_empty() and not old.sure_armed, "and none of the new state")
	check(old != null and old.window_n == 0 and old.streak == 0 and old.push_stake == 0 and old.last_window.is_empty(),
		"a fresh window, no streak, no push")
	# The ledger's tab is saved too.
	var e2 := Economy.new()
	e2.tab_on = true
	e2.tab_limit = 50
	e2.buy(30)
	var e3 := Economy.new()
	e3.from_dict(e2.to_dict())
	check(e3.tab == 30 and e3.tab_on and e3.tab_limit == 50 and e3.balanced(), "the tab, open, with its limit")


# --- the line that wins more often (docs/perk_research.md section 15) ------------------

## The run's form `id` (its run table on, stake 1), or null without the core pack.
func _run_form(id: String) -> FormDef:
	var pack := core_pack()
	if pack == null:
		return null
	for f in pack.forms:
		if f.id == id:
			return f.shaped()
	return null


## A box of the run's model, prizes only.
func _run_box(form: FormDef, seed_text: String) -> TicketBox:
	return BoxGenerator.build(form, seed_text, RunConfig.standard().box_model(0), true)


## The prize money a box's tickets hold, and whether its counts match its tickets.
func _holds(box: TicketBox) -> Dictionary:
	var money := 0
	var counts := []
	counts.resize(box.counts.size())
	counts.fill(0)
	for t in box.tickets:
		money += int(t.prize)
		for tier in t.get("wins", [t.tier]):
			if int(tier) >= 0:
				counts[int(tier)] += 1
	return {"money": money, "counts_match": counts == box.counts}


## The prizes of a box's tickets, in order (to compare two boxes).
func _prizes(box: TicketBox) -> Array:
	return box.tickets.map(func(t): return int(t.prize))


func _winners(box: TicketBox) -> int:
	return box.tickets.filter(func(t): return int(t.prize) > 0).size()


func test_consolation_turns_losers_into_the_smallest_prize() -> void:
	var p := Catalog.standard().perk("consolation")
	eq(p.rarity, "common", "CONSOLATION is common")
	eq(p.levels.map(func(l): return int(l.value)), Catalog.CONSOLATION, "its rates are Catalog.CONSOLATION")
	eq(Catalog.CONSOLATION, [5, 10], "5 and 10 in a hundred (section 15's 10 / 20 were for $25 smallest prizes)")
	for id in ["catch", "plate"]:
		var form := _run_form(id)
		if form == null:
			return
		var s := int(form.tiers[RunState.smallest_tier(form)].prize)
		for lv in 2:
			var pct: int = Catalog.CONSOLATION[lv]
			var losers := 0
			var turned := 0
			var bad := 0
			var off := 0
			for n in 30:
				var box := _run_box(form, "CO-%02d" % n)
				var before := box.prize_total()
				var k := 0
				while box.cursor < box.size:
					var at := box.cursor
					if not box.wins(at):
						losers += 1
						if box.console(at, pct):
							turned += 1
							k += 1
							var t: Dictionary = box.tickets[at]
							if int(t.prize) != s or int(t.tier) != box.smallest_tier() or (form.wins_by_group() and not t.wins.has(t.tier)):
								bad += 1
					elif box.console(at, pct):
						bad += 1
					box.cursor += 1
				var h := _holds(box)
				if h.money != box.prize_total() or not h.counts_match or box.prize_total() != before + k * s:
					off += 1
			var share := float(turned) / losers
			check(absf(share - pct / 100.0) <= 0.01, "%s, CONSOLATION %d: %.3f of %d losers turned (%d%%)" % [id, lv + 1, share, losers, pct])
			eq(bad, 0, "%s: every one turned is the smallest prize ($%d), on the ticket; winners left alone" % [id, s])
			eq(off, 0, "%s: the box counts them, as new money" % id)
	# The same seed turns the same tickets; the log replays them.
	var catch := _run_form("catch")
	var a := _run_box(catch, "CO-SAME")
	var b := _run_box(catch, "CO-SAME")
	for at in a.size:
		a.cursor = at
		b.cursor = at
		a.console(at, 10)
		b.console(at, 10)
	eq(_prizes(a), _prizes(b), "same seed, same tickets turned")
	var again := _run_box(catch, "CO-SAME")
	again.replay(a.ops)
	eq(_prizes(again), _prizes(a), "a saved box comes back with them")


func test_consolation_on_the_machine_is_a_real_winner() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var r := _run()
	r.perks = {"consolation": 2}
	var m := r.new_machine([pack.forms[0]], true)
	eq(m.consolation, 10, "the machine has it")
	var plain := _run().new_machine([pack.forms[0]], true)
	var e := r.new_economy()
	e.credit = 300
	e.cash -= 300
	var e2 := r.new_economy()
	e2.credit = 300
	e2.cash -= 300
	var won := 0
	var won_plain := 0
	var turned: Array = []
	for k in 300:
		var sold := m.sell_now(0, e)
		var other := plain.sell_now(0, e2)
		if int(sold.ticket.prize) > 0:
			won += 1
		if int(other.ticket.prize) > 0:
			won_plain += 1
		if int(other.ticket.prize) == 0 and int(sold.ticket.prize) > 0:
			turned.append(sold.ticket)
	check(won > won_plain, "more winners in 300 (%d against %d)" % [won, won_plain])
	if not check(not turned.is_empty(), "some losers turned"):
		return
	# It pays the smallest prize and counts as a winner in the window (STREAK, ALL IN).
	var paid := r.pay_ticket(r.new_economy(), turned[0], m.forms[0])
	eq(paid, int(m.forms[0].tiers[RunState.smallest_tier(m.forms[0])].prize), "it pays the smallest prize")
	eq(r.window_wins, 1, "a winner in the window")
	eq(r.window_printed, paid, "its printed prize in the window (ALL IN compares those)")


## The big prizes (bigger than the smallest) a box holds, every prize on a ticket.
func _big(box: TicketBox) -> int:
	var low := box.smallest_tier()
	var n := 0
	for i in box.counts.size():
		if int(box.form.tiers[i].prize) > int(box.form.tiers[low].prize):
			n += int(box.counts[i])
	return n


func test_packed_puts_the_money_in_more_smallest_prizes() -> void:
	var p := Catalog.standard().perk("packed")
	eq(p.rarity, "rare", "PACKED is rare")
	eq(p.levels.map(func(l): return int(l.value)), [25, 50], "25 / 50% of the big prizes")
	for id in ["catch", "plate", "spur", "order", "kabawk", "flock", "nugget", "peckeye"]:
		var form := _run_form(id)
		if form == null:
			return
		var low := RunState.smallest_tier(form)
		var s := int(form.tiers[low].prize)
		for pct in [25, 50]:
			var big := 0
			var broken := 0
			var winners := 0
			var winners_packed := 0
			var off := 0
			var share_off := 0
			var tickets := 0
			for n in 300:   # the run's boxes are small now (M9.7): big prizes are few in 60 of them
				var plain := _run_box(form, "PK-%02d" % n)
				var box := _run_box(form, "PK-%02d" % n)
				var added := box.pack(pct)
				var b := _big(plain)
				var gone := b - _big(box)
				big += b
				tickets += plain.size
				broken += gone
				winners += _winners(plain)
				winners_packed += _winners(box)
				if gone != floori(b * pct / 100.0) and gone != ceili(b * pct / 100.0):
					share_off += 1
				var h := _holds(box)
				if box.prize_total() != plain.prize_total() or h.money != box.prize_total() or not h.counts_match \
						or int(box.counts[low]) != int(plain.counts[low]) + added or box.type_id != plain.type_id:
					off += 1
			eq(off, 0, "%s %d%%: the same money to the coin, counts that match the tickets, the same type" % [id, pct])
			eq(share_off, 0, "%s %d%%: in every box that share of its big prizes, in whole prizes, is broken" % [id, pct])
			var share := float(broken) / maxi(1, big)
			note("%s PACKED %d%%: %d of %d big prizes broken (%.0f%%), winners per 100 %.1f -> %.1f (300 boxes)" % [id, pct, broken,
				big, share * 100.0, winners * 100.0 / tickets, winners_packed * 100.0 / tickets])
			# Within a tenth, or three prizes where a form has few (Big Catch: one a box). A
			# top prize that breaks into more pieces than a small box has losers (Big Catch's
			# $1,000 into 199 fives in a box of 200, Lucky Spur's $500 into 249 twos) cannot be
			# broken at all (M9.7): such a form can only fall short of its share, not pass it.
			var top := int(form.tiers[form.tier_indices("top")[0]].prize) / s
			var short := top > 150
			check(share <= pct / 100.0 + 0.1 and (short or absf(share - pct / 100.0) <= 0.1) or absf(broken - big * pct / 100.0) <= 3.0,
				"%s: about %d%% of the big prizes broken (%.0f%%)" % [id, pct, share * 100.0])
			check(winners_packed > winners, "%s %d%%: more winners (%d against %d)" % [id, pct, winners_packed, winners])
	# Deterministic, logged, replayed.
	var plate := _run_form("plate")
	var a := _run_box(plate, "PK-SAME")
	var b2 := _run_box(plate, "PK-SAME")
	a.pack(50)
	b2.pack(50)
	eq(_prizes(a), _prizes(b2), "same seed, same box")
	var again := _run_box(plate, "PK-SAME")
	again.replay(a.ops)
	eq(_prizes(again), _prizes(a), "a saved box comes back packed")
	eq(again.counts, a.counts, "with its counts")
	a.cursor = 1
	eq(a.pack(50), 0, "a box sold from is not packed again")


## The smallest prizes PACKED breaks off are not small prizes to PENNY JAR, nor prizes
## to STACKER (G, 2026-11-07: it must not stack up with PENNY JAR); the box's own are.
func test_packed_pieces_pass_penny_jar_over() -> void:
	var form := _run_form("spur")
	if form == null:
		return
	var box := _run_box(form, "PK-PENNY")
	box.pack(50)
	var piece := {}
	var own := {}
	for t in box.tickets:
		if int(t.prize) <= 0 or t.wins.filter(func(g): return g >= 0).size() != 1:
			continue
		if int(t.get("packed", 0)) > 0 and piece.is_empty():
			piece = t
		elif int(t.get("packed", 0)) == 0 and int(t.tier) == box.smallest_tier() and own.is_empty():
			own = t
	if not check(not piece.is_empty() and not own.is_empty(), "a piece and a smallest prize of the box's own"):
		return
	var s := int(form.tiers[box.smallest_tier()].prize)
	var r := _run()
	r.perks = {"penny": 2}
	eq(r.pay_ticket(Economy.new(), own, form), s * 3, "PENNY JAR 2: the box's own smallest prize x3")
	eq(r.pay_ticket(Economy.new(), piece, form), s, "a piece PACKED broke off: as printed")
	# A ticket with two prizes, one of them a piece: not a stack for STACKER.
	var two := {"no": 100, "tier": box.smallest_tier(), "prize": 2 * s, "wins": [box.smallest_tier(), box.smallest_tier(), -1],
		"packed": 1}
	r.perks = {"stacker": 1}
	eq(r.pay_ticket(Economy.new(), two, form), 2 * s, "STACKER: one of the two is a piece, no x3")
	two.erase("packed")
	eq(r.pay_ticket(Economy.new(), two, form), 6 * s, "both its own: x3")


func test_packed_acts_on_boxes_loaded_while_held() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var r := _run()
	var m := r.new_machine(pack.forms, true)
	r.perks = {"packed": 1}
	r.apply(m)
	eq(m.packed, 25, "the machine has it")
	for box in m.boxes:
		check(box.ops.is_empty(), "%s: a box on the machine when it was bought stays as it was" % box.form.id)
	var e := r.new_economy()
	e.bonus(r.change_fee())
	check(r.change_box(e, m, 0), "NEW BOX")
	eq(m.boxes[0].ops, [{"p": 25}], "the next box loaded is packed")
	var held := _run()
	held.perks = {"packed": 2}
	var m2 := held.new_machine(pack.forms, true)
	for box in m2.boxes:
		eq(box.ops, [{"p": 50}], "%s: a layer's first boxes, loaded while held, are packed" % box.form.id)


func test_crumbs_split_a_prize_over_the_next_losers() -> void:
	var p := Catalog.standard().perk("crumbs")
	eq(p.rarity, "rare", "CRUMBS is rare")
	eq(p.levels.map(func(l): return int(l.value)), [5, 20], "up to 5 / 20 pieces (G, 2026-11-07)")
	for id in ["spur", "catch", "plate", "order", "kabawk", "flock", "nugget", "peckeye"]:
		var form := _run_form(id)
		if form == null:
			return
		var s := int(form.tiers[RunState.smallest_tier(form)].prize)
		for n in [5, 20]:
			var winners := 0
			var winners_split := 0
			var off := 0
			var bad := 0
			for k in 30:
				var plain := _run_box(form, "CR-%02d" % k)
				var box := _run_box(form, "CR-%02d" % k)
				var money := box.prize_total()
				while box.cursor < box.size:
					var at := box.cursor
					if box.wins(at):
						var t: Dictionary = box.tickets[at]
						var dead := []
						for j in range(at + 1, box.size):
							if dead.size() >= n:
								break
							if not box.wins(j):
								dead.append(j)
						var was := int(t.prize)
						var crumb: bool = t.get("crumb", false)
						var made := box.crumble(at, n)
						var table := int(form.tiers[int(t.tier)].prize)
						var want := 0 if crumb else mini(mini(n, table / s - 1), dead.size())
						if made != want:
							bad += 1
						var got := 0
						for q in made:
							var piece: Dictionary = box.tickets[dead[q]]
							if int(piece.prize) != s or not piece.get("crumb", false):
								bad += 1
							got += int(piece.prize)
						if made > 0 and (got + int(t.prize) != was or int(t.cut) != made * s):
							bad += 1
					box.cursor += 1
				var h := _holds(box)
				if h.money != money or box.prize_total() != money or not h.counts_match:
					off += 1
				winners += _winners(plain)
				winners_split += _winners(box)
			eq(off, 0, "%s CRUMBS %d: every box pays what it held" % [id, n])
			eq(bad, 0, "%s CRUMBS %d: pieces are the smallest prize, on the next losers, the rest kept" % [id, n])
			check(winners_split > winners, "%s CRUMBS %d: more winners (%d against %d)" % [id, n, winners_split, winners])
			note("%s CRUMBS %d: winners %d -> %d (30 boxes)" % [id, n, winners, winners_split])
	# Deterministic, logged, replayed.
	var spur := _run_form("spur")
	var a := _run_box(spur, "CR-SAME")
	var b := _run_box(spur, "CR-SAME")
	for at in a.size:
		a.cursor = at
		b.cursor = at
		a.crumble(at, 2)
		b.crumble(at, 2)
	eq(_prizes(a), _prizes(b), "same seed, same split")
	var again := _run_box(spur, "CR-SAME")
	again.replay(a.ops)
	eq(_prizes(again), _prizes(a), "a saved box comes back split")


func test_crumbs_pay_and_edges() -> void:
	var form := _run_form("catch")
	if form == null:
		return
	var low := RunState.smallest_tier(form)
	var s := int(form.tiers[low].prize)
	var mid: int = form.tier_indices("mid")[0]
	var m := int(form.tiers[mid].prize)
	# A middle prize, a loser, a small prize, a loser: split in three, the small prize
	# in the way is passed over.
	var box := TicketBox.new()
	box.form = form
	box.seed = "CR-EDGE"
	box.size = 4
	box.tickets = [{"no": 1, "tier": mid, "prize": m}, {"no": 2, "tier": -1, "prize": 0},
		{"no": 3, "tier": low, "prize": s}, {"no": 4, "tier": -1, "prize": 0}]
	box.counts = [0, 0, 0, 0]
	box.counts[low] = 1
	box.counts[mid] = 1
	eq(box.crumble(2, 2), 0, "the smallest prize does not split")
	eq(box.crumble(0, 2), 2, "split in three")
	eq(_prizes(box), [m - 2 * s, s, s, s], "the rest kept, the losers the smallest prize")
	eq(box.crumble(0, 2), 0, "never split twice")
	eq(box.crumble(1, 2), 0, "a piece is never split")
	# Fewer losers than pieces: as many as are left.
	var short := TicketBox.new()
	short.form = form
	short.seed = "CR-SHORT"
	short.size = 2
	short.tickets = [{"no": 1, "tier": mid, "prize": m}, {"no": 2, "tier": -1, "prize": 0}]
	short.counts = [0, 0, 0, 0]
	short.counts[mid] = 1
	eq(short.crumble(0, 2), 1, "one loser left: split in two")
	# Limited by the prize: the ticket keeps the smallest prize at least.
	var wide := TicketBox.new()
	wide.form = form
	wide.seed = "CR-WIDE"
	wide.size = 1 + m / s + 5
	wide.tickets = [{"no": 1, "tier": mid, "prize": m}]
	for k in wide.size - 1:
		wide.tickets.append({"no": k + 2, "tier": -1, "prize": 0})
	wide.counts = [0, 0, 0, 0]
	wide.counts[mid] = 1
	eq(wide.crumble(0, 20), mini(20, m / s - 1), "CRUMBS 2 on a $%d prize: as many pieces as it holds, less one" % m)
	eq(int(wide.tickets[0].prize), m - mini(20, m / s - 1) * s, "the ticket keeps the rest")
	check(int(wide.tickets[0].prize) >= s, "the smallest prize at least")
	# The run pays what the ticket kept and the pieces the rest: the whole prize.
	var r := _run()
	var e := r.new_economy()
	var sum := 0
	for t in box.tickets:
		if int(t.no) != 3:
			sum += r.pay_ticket(e, t, form)
	eq(sum, m, "the split prize pays its whole, over three tickets")
	var pack := core_pack()
	var rc := _run()
	rc.perks = {"crumbs": 2}
	eq(rc.new_machine([pack.forms[0]], true).crumbs, 20, "the machine has it: up to 20 pieces")
