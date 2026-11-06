class_name RunState
extends RefCounted
## One run of the story mode: a debt in three layers, each due within its days.
## Pure logic; the money itself stays in Economy, which every method here is handed.
##
## A day is one of two things: a day at the machine (as many tickets as the player
## likes, until they leave) or a shift of work (a sure wage, no tickets that day).
## The debt is paid in one go, any time the money is there, and the next layer starts
## at once; on the last day of a layer, leaving pays it or ends the run.
## Borrowed money goes on top of what is due in the layer, with interest.
## Rules: docs/roadmap.md "一局的结构"; numbers: RunConfig.
##
## Perks, items and contacts' services are data (Catalog); what they do is here, in the
## effect hooks: effect(name) sums the levels of every perk on that effect, and the
## rules ask it. Perks are offered, not shelved (G, the perk-tree talk): at the start of
## the run and after every day the run deals a few (deal_offers) and the player buys any
## they can pay for; the items on the phone's shelf change every day (deal_shelf).
## Everything is bought from cash at the layer's stake, and counted in the ledger as paid.
## Every prize goes through pay_ticket, which is the one formula of Catalog's header.

const PLAYING := "playing"
const CLEARED := "cleared"
const FAILED := "failed"

var config: RunConfig
var seed := ""
var scenes: Array = []     ## room id of each layer; a bought scene may replace one later
var layer := 0
var day := 1               ## 1 .. days of the layer
var today := ""            ## "" not chosen yet, "play" at the machine, "work" worked a shift
var shifts := 0            ## shifts worked in this layer (the wage follows it)
var borrowed := 0          ## principal borrowed in this layer
var loan_due := 0          ## that plus interest: added to what the layer asks
var loan_bonus := 0        ## extra house line (dollars) from outside the catalog; perks add theirs through effect()
var offer_bonus := 0       ## extra perk offers each time, from outside the run (money kept between runs, M13)
var perks := {}            ## perk id -> level bought
var items := {}            ## item id -> how many are held
var extra_days := 0        ## days this layer was given on top of its own (a service)
var services := {}         ## service id -> times bought in this layer
var reports := {}          ## BOX REPORT: form uid -> seed of the box read in full
var offers: Array = []     ## perk ids offered now (bought ones leave the list)
var offers_open := false   ## the offers are waiting to be looked at (the day's card shows them first)
var offer_rerolls := 0     ## rerolls of this round of offers (each costs double)
var offer_bought := false  ## something was bought from this round
var shelf: Array = []      ## item ids on the phone's shelf today (bought ones leave it)
var shelf_rerolls := 0
var last_item := ""        ## the item bought last (COPIER copies it)
var bet := 1               ## the machine's bet (HIGH ROLLER), 1 .. bet_max()
## What the effects count: losers in a row (DUE A WIN), boxes cleared under SNOWBALL,
## losers and top prizes opened in this layer (TRASH KING, JACKPOT HUNTER).
var dry := 0
var snow := 0
var scrap := 0.0           ## SCRAP DEALER's share of losers not paid out yet (paid in whole dollars)
var layer_losers := 0
var layer_tops := 0
## Today's: a HAPPY HOUR, a SAFETY NET, ALL IN used, the ledger when the day began.
var happy := false
var safety := false
var all_in_used := false
var day_spent := 0
var day_won := 0
var catalog: Catalog = Catalog.standard()
var status := PLAYING
var story := "intro"       ## a story card waiting to be read: "", "intro", "twist", "ending", "failed"
## For the settlement and, later, achievements and the money kept between runs.
var stats := {"days": 0, "play_days": 0, "shifts": 0, "tickets": 0, "wages": 0, "borrowed": 0,
	"interest": 0, "repaid": 0, "box_changes": 0, "fees": 0, "last_sales": 0, "days_spared": 0,
	"layers_cleared": 0, "discarded": 0,   ## discarded: tickets bought and thrown away unopened
	"shop": 0, "perks": 0, "items": 0, "services": 0, "bonus": 0,   ## shop: money spent there; bonus: prize money from perks and coins
	"rerolls": 0, "skipped_offers": 0, "savings": 0, "insured": 0, "boxes_cleared": 0, "all_ins": 0, "best_prize": 0}


static func start(run_config: RunConfig, seed_text: String, layer_scenes: Array) -> RunState:
	var r := RunState.new()
	r.config = run_config
	r.seed = seed_text
	r.scenes = layer_scenes.duplicate()
	r._new_day()
	return r


## A fresh ledger for this run, at the first layer's stake.
func new_economy() -> Economy:
	var e := Economy.new()
	e.start_cash = config.start_cash
	e.cash = config.start_cash
	e.bills = RunConfig.bills(stake())
	return e


## The layer's machine: the forms at its stake, its boxes and its last-sale prize.
## `light`: boxes without the print on each ticket, for simulations.
func new_machine(base_forms: Array, light := false) -> MachineLogic:
	var m := MachineLogic.new(stage_forms(base_forms), "%s-L%d-0001" % [seed, layer + 1], config.box_model(layer), light, luck(),
		Catalog.FORTUNE_TRIES if effect("fortune") > 0 else 1)
	apply(m)
	return m


## Puts the perks that act on the machine into it (after one is bought, or a box cleared).
func apply(m: MachineLogic) -> void:
	m.last_sale = last_sale_prize()
	m.luck = luck()
	m.luck_tries = Catalog.FORTUNE_TRIES if effect("fortune") > 0 else 1
	m.flow_line = effect("flow_line") > 0
	bet = clampi(bet, 1, bet_max())
	m.bet = bet


## The forms the layer's machine sells, one column each, at the layer's stake: the
## layer's own list ("forms", form ids in column order) or, without one, all of them.
## An id that is not installed leaves its column out.
func stage_forms(base_forms: Array) -> Array:
	var picked: Array = base_forms
	var wanted = stage().get("forms")
	if wanted is Array and not wanted.is_empty():
		picked = []
		for uid in wanted:
			for f: FormDef in base_forms:
				if f.uid() == str(uid):
					picked.append(f)
		if picked.is_empty():
			picked = base_forms
	var out := []
	for f: FormDef in picked:
		out.append(f.shaped().scaled(stake()))   # the run's prize table (G, M9.6), then the layer's stake
	return out


func stage() -> Dictionary:
	return config.layer(layer)


func stake() -> int:
	return int(stage().stake)


func scene() -> String:
	return str(scenes[clampi(layer, 0, scenes.size() - 1)]) if not scenes.is_empty() else ""


func days() -> int:
	return int(stage().days) + extra_days


func last_day() -> bool:
	return day >= days()


func playing() -> bool:
	return status == PLAYING


## Everything owed in this layer: the debt, and what was borrowed with its interest.
func due() -> int:
	return int(stage().debt) + loan_due


## Pay for the next shift. It rises at fixed shifts; the player only ever sees today's.
func wage() -> int:
	var wages: Array = stage().wages
	return int(wages[mini(shifts, wages.size() - 1)])


## What the last shift worked in this layer paid.
func last_wage() -> int:
	var wages: Array = stage().wages
	return int(wages[clampi(shifts - 1, 0, wages.size() - 1)])


func can_choose() -> bool:
	return playing() and today == ""


## Spends the day at the machine. `e`: the ledger, to measure the day by (SAFETY NET).
func play(e: Economy = null) -> bool:
	if not can_choose():
		return false
	today = "play"
	stats.play_days += 1
	if e != null:
		day_spent = e.spent
		day_won = e.won
	if effect("free_peek") > 0 and room() > 0:
		items.peek = held("peek") + 1
	return true


## Spends the day at work: the wage now, no tickets today.
func work(e: Economy) -> bool:
	if not can_choose():
		return false
	var w := wage()
	e.earn(w)
	today = "work"
	shifts += 1
	stats.shifts += 1
	stats.wages += w
	return true


func loan_step() -> int:
	return int(stage().loan_step)


## The layer's house line, GOOD CREDIT's share on top of it.
func loan_limit() -> int:
	return int(stage().loan) * (100 + effect("loan_pct")) / 100 + loan_bonus


func loan_left() -> int:
	return maxi(0, loan_limit() - borrowed)


func can_borrow() -> bool:
	return playing() and loan_left() >= loan_step()


## The loan interest in percent, LOW RATE's cut taken off.
func interest() -> int:
	return maxi(0, config.loan_interest - effect("rate_cut"))


## One press of LOAN: cash now, the same plus interest on top of what is due.
func borrow(e: Economy) -> bool:
	if not can_borrow():
		return false
	var amount := loan_step()
	var cost := amount * interest() / 100
	e.add_loan(amount)
	borrowed += amount
	loan_due += amount + cost
	stats.borrowed += amount
	stats.interest += cost
	return true


## What NEW BOX costs now: the stage's fee less the perk's cut, nothing with a BOX KEY.
func change_fee() -> int:
	if held("key") > 0:
		return 0
	return int(stage().get("change_fee", 0)) * (100 - mini(100, effect("fee_cut"))) / 100


## A new box in column `i`, for the fee (or a BOX KEY).
func change_box(e: Economy, machine: MachineLogic, i: int) -> bool:
	var fee := change_fee()
	if not playing() or not e.pay(fee):
		return false
	if held("key") > 0:
		_use_up("key")
	machine.change_box(i)
	reports.erase(machine.forms[i].uid())
	stats.box_changes += 1
	stats.fees += fee
	return true


## The machine sold `n` tickets, `last_sales` of them the last of their box.
func count_sales(n: int, last_sales := 0) -> void:
	stats.tickets += n
	stats.last_sales += last_sales


## The last ticket of a box was bought (its prize is paid): SNOWBALL counts it, and the
## machine gets the bigger last-sale prize that follows.
func cleared_box(m: MachineLogic) -> void:
	stats.boxes_cleared += 1
	if effect("snowball") > 0:
		snow += 1
	apply(m)


## Cash and machine credit cover what is due (a bill being fed has to land first).
func can_pay(e: Economy) -> bool:
	return playing() and e.bill == 0 and e.cash + e.credit >= due()


## Pays the layer in full and moves on at once: the next layer starts on a new day,
## or the run is cleared. Days left over are counted as spared.
func pay(e: Economy) -> bool:
	if not can_pay(e):
		return false
	e.cash_out()
	_settle_day(e)
	var amount := due()
	e.pay(amount)
	stats.repaid += amount
	stats.days_spared += days() - day
	stats.layers_cleared += 1
	stats.days += 1
	if layer >= config.layers.size() - 1:
		status = CLEARED
		story = "ending"
		_close_shop()
		return true
	layer += 1
	day = 1
	today = ""
	shifts = 0
	borrowed = 0
	loan_due = 0
	extra_days = 0
	services = {}
	reports = {}
	layer_losers = 0
	layer_tops = 0
	story = "twist"
	e.bills = RunConfig.bills(stake())
	_new_day()
	return true


## The player leaves for the day (or has worked the shift). On the last day of a layer
## this settles it: paid if the money is there, otherwise the run is over.
func end_day(e: Economy) -> void:
	if not playing():
		return
	var played := today == "play"
	_settle_day(e)
	if last_day():
		if not pay(e):
			stats.days += 1
			status = FAILED
			story = "failed"
			_close_shop()
		return
	stats.days += 1
	day += 1
	today = ""
	var pct := effect("savings")
	if played and pct > 0 and e.cash > 0:
		var grown := roundi(e.cash * pct / 100.0)
		e.earn(grown)
		stats.savings += grown
	_new_day()


## The end of a day of play: a SAFETY NET gives back its share of the day's loss.
func _settle_day(e: Economy) -> void:
	if today == "play" and safety:
		var loss := (e.spent - day_spent) - (e.won - day_won)
		var back := roundi(maxi(0, loss) * int(catalog.item("safety").get("value", 30)) / 100.0)
		if back > 0:
			e.earn(back)
			stats.insured += back
	safety = false
	happy = false


## A new day (or the start of the run, or of a layer): new perk offers, a new shelf.
func _new_day() -> void:
	happy = false
	safety = false
	all_in_used = false
	offer_rerolls = 0
	offer_bought = false
	offers = deal_offers()
	offers_open = not offers.is_empty()
	shelf_rerolls = 0
	shelf = deal_shelf()


func _close_shop() -> void:
	offers = []
	offers_open = false
	shelf = []


# --- effects -------------------------------------------------------------------------

func level(perk_id: String) -> int:
	return int(perks.get(perk_id, 0))


func held(item_id: String) -> int:
	return int(items.get(item_id, 0))


## The effect hook: what every perk on `effect_name` adds up to at its level.
func effect(effect_name: String) -> int:
	var sum := 0
	for p in catalog.perks:
		var lv := level(p.id)
		if p.effect == effect_name and lv > 0:
			sum += int(p.levels[mini(lv, p.levels.size()) - 1].value)
	return sum


## LUCKY STREAK as a chance (0..1).
func luck() -> float:
	return effect("luck") / 100.0


## The box-reading level (BoxReading), 0 without the perk.
func reading() -> int:
	return effect("reading")


## The highest bet the machine takes (HIGH ROLLER), 1 without it.
func bet_max() -> int:
	return maxi(1, effect("bet"))


## The bets the machine offers: 1 and every level of HIGH ROLLER bought.
func bets() -> Array:
	var out := [1]
	var p := catalog.perk("bet")
	for k in mini(level("bet"), p.get("levels", []).size()):
		out.append(int(p.levels[k].value))
	return out


## Tickets opened at once from the tray (QUICK HANDS), 0 without it.
func batch_size() -> int:
	return effect("batch")


## Every box cleared under SNOWBALL multiplies every prize again.
func snow_x() -> float:
	return pow(1.0 + effect("snowball") / 100.0, snow)


func last_sale_prize() -> int:
	return roundi(int(stage().get("last_sale", 0)) * maxi(1, effect("last_sale_x")) * snow_x())


## BORROWED LUCK works while the principal owed is half the line or more (G: so that a
## token loan does not buy it).
func debt_on() -> bool:
	return effect("debt_pct") > 0 and borrowed > 0 and borrowed * 2 >= loan_limit()


## Every "+%" on the next prize, in percent. `cash`: what NET WORTH counts (-1: the
## ledger's cash now).
func prize_pct(e: Economy, cash := -1) -> int:
	var pct := effect("prize_pct")
	if debt_on():
		pct += effect("debt_pct")
	if cash < 0 and e != null:
		cash = e.cash
	if effect("worth_pct") > 0 and cash > 0:
		pct += effect("worth_pct") * (cash / (Catalog.WORTH_STEP * stake()))
	pct += effect("pity_pct") * dry
	pct += effect("trash_pct") * (layer_losers / 100)
	pct += effect("hunter_pct") * layer_tops
	if happy:
		pct += int(catalog.item("happy").get("value", 50))
	return pct


## Pays an opened ticket into the ledger: its prize through every perk (the formula of
## Catalog's header), or, for a loser, what SCRAP DEALER gives back (and a WHITE-OUT,
## when held, turns the loser into the form's smallest prize). `bet`: what the ticket
## was bought at; `x`: the opening's multiplier (CHAIN, ALL IN); `again`: ENCORE hit;
## `cash`: what NET WORTH counts (an opening counts the cash it started with, so the
## prizes of one opening do not feed each other). Returns the money paid.
func pay_ticket(e: Economy, t: Dictionary, form: FormDef, ticket_bet := 1, x := 1.0, again := false, cash := -1) -> int:
	var won_tiers := []
	if int(t.prize) > 0:
		for tier in t.get("wins", [t.tier]):
			if int(tier) >= 0:
				won_tiers.append(int(tier))
	elif held("whiteout") > 0:
		_use_up("whiteout")
		won_tiers = [smallest_tier(form)]
	if won_tiers.is_empty():
		e.open_ticket(0)
		dry += 1
		layer_losers += 1
		# A share of a $1 ticket is cents: it is saved up and paid in whole dollars.
		scrap += form.price * ticket_bet * effect("scrap_pct") / 100.0
		var back := floori(scrap + 1e-6)
		scrap -= back
		if back > 0:
			e.bonus(back)
			stats.bonus += back
		return back
	var base := 0.0
	var top_x := maxi(1, effect("top_x"))
	var tops := 0
	for tier in won_tiers:
		var p := float(form.tiers[tier].prize)
		if form.tiers[tier].role == "top":
			p *= top_x
			tops += 1
		base += p
	var mult := x * snow_x()
	if won_tiers.size() >= 2:
		mult *= maxi(1, effect("stack_x"))
	if int(t.get("no", 0)) <= Catalog.FIRST_TICKETS:
		mult *= maxi(1, effect("first_x"))
	if held("coin") > 0:
		_use_up("coin")
		mult *= 2.0
	var total := roundi(base * ticket_bet * (1.0 + prize_pct(e, cash) / 100.0) * mult)
	if again:
		total *= 2
	dry = 0
	layer_tops += tops
	e.open_ticket(total)
	stats.bonus += total - int(t.prize) * ticket_bet
	stats.best_prize = maxi(int(stats.best_prize), total)
	return total


## A tray entry ({form, ticket, box, bet}) opened by hand.
func open_ticket(e: Economy, entry: Dictionary) -> int:
	var paid := pay_ticket(e, entry.ticket, entry.form, int(entry.get("bet", 1)))
	if entry.get("box") != null:
		entry.box.opened = maxi(entry.box.opened, int(entry.ticket.no))
	return paid


## Tray entries opened at once (QUICK HANDS, ALL IN): CHAIN counts the winners (every
## prize on a ticket, and every ENCORE) and multiplies the whole opening; `x` on top.
## Returns {n, winners, won} (won: everything paid, SCRAP DEALER's included).
func open_batch(e: Economy, entries: Array, x := 1.0) -> Dictionary:
	var again_pct := effect("again_pct")
	var plan := []
	var count := 0
	for en in entries:
		var t: Dictionary = en.ticket
		var g := 0
		if int(t.prize) > 0:
			for tier in t.get("wins", [t.tier]):
				if int(tier) >= 0:
					g += 1
		var hit := again_pct > 0 and g > 0 \
			and SeededRng.new("%s|again|%d" % [en.box.seed if en.get("box") != null else seed, int(t.no)]).next_float() * 100.0 < again_pct
		count += g + (1 if hit else 0)
		plan.append(hit)
	var opening := x * (1.0 + effect("combo_pct") / 100.0 * maxi(0, count - 1))
	var cash := e.cash
	var won := 0
	var winners := 0
	for k in entries.size():
		var en: Dictionary = entries[k]
		var before := e.wins
		won += pay_ticket(e, en.ticket, en.form, int(en.get("bet", 1)), opening, plan[k], cash)
		if e.wins > before:
			winners += 1
		if en.get("box") != null:
			en.box.opened = maxi(en.box.opened, int(en.ticket.no))
	return {"n": entries.size(), "winners": winners, "won": won, "x": opening}


## The tier with the smallest prize of a form (a WHITE-OUT pays it).
static func smallest_tier(form: FormDef) -> int:
	var best := 0
	for i in form.tiers.size():
		if int(form.tiers[i].prize) < int(form.tiers[best].prize):
			best = i
	return best


## ALL IN can buy out column `i` now (once a day of play, money for the whole box).
func can_all_in(e: Economy, m: MachineLogic, i: int) -> bool:
	if not playing() or today != "play" or effect("all_in") <= 0 or all_in_used or m.busy():
		return false
	var left := m.boxes[i].size - m.boxes[i].cursor
	return left > 0 and e.cash + e.credit >= left * m.price(i)


## ALL IN: buys out what is left in column `i` (credit first, then cash), at the bet,
## and opens it all at once at ALL IN's multiplier (CHAIN too). The last sale is paid.
## Returns open_batch's result plus {entries, cost, last_sale}, or {} when it cannot.
func all_in(e: Economy, m: MachineLogic, i: int) -> Dictionary:
	if not can_all_in(e, m, i):
		return {}
	var box: TicketBox = m.boxes[i]
	var left := box.size - box.cursor
	var cost := left * m.price(i)
	e.spend(cost)
	var entries := []
	while box.cursor < box.size:
		entries.append({"form": m.forms[i], "ticket": box.tickets[box.cursor], "box": box, "bet": m.bet})
		box.cursor += 1
	m.loaded[i] = box.size
	var last := m.last_sale
	if last > 0:
		e.bonus(last)
	count_sales(left, 1 if last > 0 else 0)
	cleared_box(m)
	all_in_used = true
	stats.all_ins += 1
	var r := open_batch(e, entries, float(effect("all_in")))
	r.entries = entries
	r.cost = cost
	r.last_sale = last
	return r


# --- perk offers -----------------------------------------------------------------------

## Offers dealt each time.
func offer_count() -> int:
	return Catalog.OFFERS + offer_bonus


## A perk's requirements (perk id -> level) that are not met yet.
func missing(perk_id: String) -> Dictionary:
	var out := {}
	var need: Dictionary = catalog.perk(perk_id).get("requires", {})
	for id in need:
		if level(id) < int(need[id]):
			out[id] = int(need[id])
	return out


## Perks that can be offered: requirements met, not at the top level.
func offerable() -> Array:
	var out := []
	for p in catalog.perks:
		if level(p.id) < p.levels.size() and missing(p.id).is_empty():
			out.append(p.id)
	return out


## This round's offers: offer_count() perks out of offerable(), drawn by rarity, from
## the run's seed, the layer, the day and the reroll (so a save cannot be rerolled by
## loading it). A level up of a perk held, and a perk its requirements opened, weigh
## more, so that a build comes together. Two branches at least, when there are two.
func deal_offers() -> Array:
	var r := SeededRng.new("%s|offer|%d|%d|%d" % [seed, layer, day, offer_rerolls])
	var pool := []
	for id in offerable():
		var p := catalog.perk(id)
		var w := float(Catalog.RARITY_WEIGHT.get(p.rarity, 1))
		if level(id) > 0:
			w *= 1.5
		if not p.get("requires", {}).is_empty():
			w *= 2.0
		pool.append({"id": id, "w": w, "branch": p.branch})
	var out := []
	var branches := {}
	while out.size() < offer_count() and not pool.is_empty():
		var pick := _draw(pool, r)
		if out.size() == offer_count() - 1 and out.size() > 0 and branches.size() == 1 and branches.has(pool[pick].branch):
			var other := []
			for c in pool:
				if not branches.has(c.branch):
					other.append(c)
			if not other.is_empty():
				pick = pool.find(other[_draw(other, r)])
		out.append(pool[pick].id)
		branches[pool[pick].branch] = true
		pool.remove_at(pick)
	return out


## A weighted pick out of [{w}], as an index.
static func _draw(list: Array, r: SeededRng) -> int:
	var total := 0.0
	for c in list:
		total += float(c.w)
	var at := r.next_float() * total
	for k in list.size():
		at -= float(list[k].w)
		if at < 0.0:
			return k
	return list.size() - 1


## The next level's price at this layer's stake, or -1 at the top level.
func perk_price(perk_id: String) -> int:
	var p := catalog.perk(perk_id)
	if p.is_empty() or level(perk_id) >= p.levels.size():
		return -1
	return int(p.levels[level(perk_id)].price) * stake()


func can_buy_perk(perk_id: String, e: Economy) -> bool:
	var price := perk_price(perk_id)
	return playing() and price > 0 and missing(perk_id).is_empty() and e.cash >= price


## Buys the next level of a perk from cash. The caller puts it into the machine (apply).
## The game sells perks only through the offers (buy_offer); this is their rule.
func buy_perk(perk_id: String, e: Economy) -> bool:
	if not can_buy_perk(perk_id, e):
		return false
	var price := perk_price(perk_id)
	e.pay(price)
	_level_up(perk_id)
	stats.shop += price
	return true


func _level_up(perk_id: String) -> void:
	perks[perk_id] = level(perk_id) + 1
	stats.perks += 1


func can_buy_offer(k: int, e: Economy) -> bool:
	return offers_open and k >= 0 and k < offers.size() and can_buy_perk(str(offers[k]), e)


## Offer `k` bought, from cash, or for free with a CHEAT SHEET. It leaves the offers.
func buy_offer(k: int, e: Economy, free := false) -> bool:
	if not offers_open or k < 0 or k >= offers.size():
		return false
	var id := str(offers[k])
	if free:
		if held("cheat") <= 0 or perk_price(id) < 0 or not missing(id).is_empty() or not playing():
			return false
		_use_up("cheat")
		_level_up(id)
	elif not buy_perk(id, e):
		return false
	offers.remove_at(k)
	offer_bought = true
	return true


## What another deal of offers costs now (it doubles each time in a round).
func reroll_price() -> int:
	return Catalog.OFFER_REROLL * stake() * (1 << offer_rerolls)


func reroll_offers(e: Economy) -> bool:
	var price := reroll_price()
	if not playing() or not offers_open or not e.pay(price):
		return false
	stats.shop += price
	offer_rerolls += 1
	stats.rerolls += 1
	offers = deal_offers()
	return true


## Done with this round's offers. A round left without buying anything gives an item
## for skipping it (if there is room). Returns that item's id, or "".
func close_offers() -> String:
	if not offers_open:
		return ""
	offers_open = false
	var gift := ""
	if not offer_bought and playing():
		stats.skipped_offers += 1
		if room() > 0:
			var r := SeededRng.new("%s|skip|%d|%d" % [seed, layer, day])
			var pool := []
			for it in catalog.items:
				if it.use != "offer":
					pool.append({"id": it.id, "w": float(Catalog.ITEM_WEIGHT.get(it.rarity, 1))})
			if not pool.is_empty():
				gift = pool[_draw(pool, r)].id
				items[gift] = held(gift) + 1
	offers = []
	return gift


# --- items -----------------------------------------------------------------------------

## Items held, all kinds.
func items_held() -> int:
	var n := 0
	for k in items:
		n += int(items[k])
	return n


## How many items can be held at once (BIG POCKETS adds room).
func item_cap() -> int:
	return Catalog.ITEM_CAP + effect("pockets")


func room() -> int:
	return maxi(0, item_cap() - items_held())


## Today's shelf: SHELF items drawn by rarity, from the seed, the layer, the day, the reroll.
func deal_shelf() -> Array:
	var r := SeededRng.new("%s|shelf|%d|%d|%d" % [seed, layer, day, shelf_rerolls])
	var pool := []
	for it in catalog.items:
		pool.append({"id": it.id, "w": float(Catalog.ITEM_WEIGHT.get(it.rarity, 1))})
	var out := []
	while out.size() < Catalog.SHELF and not pool.is_empty():
		var k := _draw(pool, r)
		out.append(pool[k].id)
		pool.remove_at(k)
	return out


func shelf_price() -> int:
	return Catalog.SHELF_REROLL * stake() * (1 << shelf_rerolls)


func reroll_shelf(e: Economy) -> bool:
	var price := shelf_price()
	if not playing() or not e.pay(price):
		return false
	stats.shop += price
	shelf_rerolls += 1
	shelf = deal_shelf()
	return true


## An item's price at the layer's stake, HAGGLER's cut taken off.
func item_price(item_id: String) -> int:
	var p := int(catalog.item(item_id).get("price", 0)) * stake()
	return maxi(1, p * (100 - mini(90, effect("item_cut"))) / 100) if p > 0 else 0


func can_buy_item(item_id: String, e: Economy) -> bool:
	return playing() and shelf.has(item_id) and room() > 0 and e.cash >= item_price(item_id)


## Buys an item off today's shelf (it leaves the shelf).
func buy_item(item_id: String, e: Economy) -> bool:
	if not can_buy_item(item_id, e):
		return false
	var price := item_price(item_id)
	e.pay(price)
	items[item_id] = held(item_id) + 1
	shelf.erase(item_id)
	if item_id != "copy":
		last_item = item_id
	stats.shop += price
	stats.items += 1
	return true


func _use_up(item_id: String) -> void:
	items[item_id] = held(item_id) - 1
	if held(item_id) <= 0:
		items.erase(item_id)


## How many tickets a PEEK sees (INFORMANT sees further).
func peek_n() -> int:
	return maxi(int(catalog.item("peek").get("value", 10)), effect("peek_n"))


## Uses up one item that is used on a column on column `i` of the machine. Returns what
## it found: PEEK {winners, of}; MAGNIFIER {wins}; BOX REPORT the reading (that box then
## reads at level 4 until it leaves); FAST FORWARD {skipped}; SHUFFLE {shuffled};
## {} if none is held.
func use_item(item_id: String, machine: MachineLogic, i: int) -> Dictionary:
	if not playing() or held(item_id) <= 0 or i < 0 or i >= machine.boxes.size():
		return {}
	var box: TicketBox = machine.boxes[i]
	var out := {}
	match item_id:
		"peek":
			out = {"winners": BoxReading.winners_next(box, peek_n()), "of": peek_n()}
		"magnifier":
			out = {"wins": BoxReading.winners_next(box, 1) > 0}
		"report":
			reports[box.form.uid()] = box.seed
			out = BoxReading.read(box)
		"skip":
			out = {"skipped": machine.skip(i, int(catalog.item("skip").get("value", 10)))}
		"shuffle":
			machine.shuffle(i)
			out = {"shuffled": box.size - box.cursor}
		_:
			return {}
	_use_up(item_id)
	return out


## Can an item used from the phone be used now (TIP-OFF at the machine on a day of play,
## HAPPY HOUR and SAFETY NET on a day of play, COPIER with something to copy and room)?
func can_use_now(item_id: String) -> bool:
	if not playing() or held(item_id) <= 0:
		return false
	match item_id:
		"tip":
			return today == "play"
		"happy":
			return today == "play" and not happy
		"safety":
			return today == "play" and not safety
		"copy":
			return last_item != "" and room() > 0
	return false


## Uses an item from the phone. TIP-OFF returns {column: machine index of the hottest
## box}; COPIER {copied: item id}; the others {on: true}. {} when it cannot.
func use_now(item_id: String, machine: MachineLogic = null) -> Dictionary:
	if not can_use_now(item_id):
		return {}
	var out := {}
	match item_id:
		"tip":
			if machine == null:
				return {}
			out = {"column": BoxReading.hottest(machine.boxes)}
		"happy":
			happy = true
			out = {"on": true}
		"safety":
			safety = true
			out = {"on": true}
		"copy":
			items[last_item] = held(last_item) + 1
			out = {"copied": last_item}
	_use_up(item_id)
	return out


## The reading level of the box in column `i`: the perk's, or level 4 for a box read by
## a BOX REPORT.
func reading_of(machine: MachineLogic, i: int) -> int:
	var box: TicketBox = machine.boxes[i]
	if str(reports.get(box.form.uid(), "")) == box.seed:
		return maxi(reading(), 4)
	return reading()


# --- contacts --------------------------------------------------------------------------

func service_price(service_id: String) -> int:
	return int(catalog.service(service_id).get("price", 0)) * stake()


func can_buy_service(service_id: String, e: Economy) -> bool:
	var s := catalog.service(service_id)
	return playing() and not s.is_empty() and int(services.get(service_id, 0)) < int(s.get("per_layer", 1)) \
		and e.cash >= service_price(service_id)


## A contact's service, from cash. extra_day: this layer gets another day.
func buy_service(service_id: String, e: Economy) -> bool:
	if not can_buy_service(service_id, e):
		return false
	var price := service_price(service_id)
	e.pay(price)
	services[service_id] = int(services.get(service_id, 0)) + 1
	match str(catalog.service(service_id).get("effect", "")):
		"extra_day":
			extra_days += 1
	stats.shop += price
	stats.services += 1
	return true


# --- save ------------------------------------------------------------------------------

const _INTS := ["layer", "day", "shifts", "borrowed", "loan_due", "loan_bonus", "extra_days", "offer_bonus",
	"offer_rerolls", "shelf_rerolls", "bet", "dry", "snow", "layer_losers", "layer_tops", "day_spent", "day_won"]
const _BOOLS := ["offers_open", "offer_bought", "happy", "safety", "all_in_used"]


func to_dict() -> Dictionary:
	var d := {"seed": seed, "scenes": scenes.duplicate(), "today": today, "status": status, "story": story, "scrap": scrap,
		"stats": stats.duplicate(), "perks": perks.duplicate(), "items": items.duplicate(),
		"services": services.duplicate(), "reports": reports.duplicate(), "offers": offers.duplicate(),
		"shelf": shelf.duplicate(), "last_item": last_item}
	for k in _INTS + _BOOLS:
		d[k] = get(k)
	return d


## A run saved with to_dict(), or null if it does not fit the config. A run saved
## before the perk offers loads with none waiting (they come with the next day).
static func from_dict(d: Dictionary, run_config: RunConfig) -> RunState:
	var r := RunState.new()
	r.config = run_config
	r.seed = str(d.get("seed", ""))
	var s = d.get("scenes", [])
	r.scenes = s.duplicate() if typeof(s) == TYPE_ARRAY else []
	for k in _INTS:
		r.set(k, int(d.get(k, r.get(k))))
	for k in _BOOLS:
		r.set(k, bool(d.get(k, false)))
	r.perks = _counts(d.get("perks"))
	r.items = _counts(d.get("items"))
	r.services = _counts(d.get("services"))
	var rep = d.get("reports", {})
	if typeof(rep) == TYPE_DICTIONARY:
		for k in rep:
			r.reports[str(k)] = str(rep[k])
	for id in r.perks.keys():
		var p := r.catalog.perk(id)
		if p.is_empty():
			r.perks.erase(id)
		else:
			r.perks[id] = mini(r.perks[id], p.levels.size())
	for id in r.items.keys():
		if r.catalog.item(id).is_empty():
			r.items.erase(id)
	r.offers = _ids(d.get("offers"), func(id): return not r.catalog.perk(id).is_empty())
	r.shelf = _ids(d.get("shelf"), func(id): return not r.catalog.item(id).is_empty())
	r.offers_open = r.offers_open and not r.offers.is_empty()
	r.last_item = str(d.get("last_item", ""))
	r.scrap = clampf(float(d.get("scrap", 0.0)), 0.0, 1.0e9)
	if r.catalog.item(r.last_item).is_empty():
		r.last_item = ""
	r.today = str(d.get("today", ""))
	r.status = str(d.get("status", PLAYING))
	r.story = str(d.get("story", ""))
	var st = d.get("stats", {})
	if typeof(st) == TYPE_DICTIONARY:
		for k in r.stats:
			r.stats[k] = int(st.get(k, 0))
	if r.seed == "" or r.layer < 0 or r.layer >= run_config.layers.size() or r.day < 1 or r.day > r.days() \
			or not ["", "play", "work"].has(r.today) or not [PLAYING, CLEARED, FAILED].has(r.status) \
			or r.shifts < 0 or r.borrowed < 0 or r.loan_due < r.borrowed or r.extra_days < 0:
		return null
	r.bet = clampi(r.bet, 1, r.bet_max())
	return r


## A saved {id: count} with whole positive counts only.
static func _counts(v) -> Dictionary:
	var out := {}
	if typeof(v) == TYPE_DICTIONARY:
		for k in v:
			if (typeof(v[k]) == TYPE_INT or typeof(v[k]) == TYPE_FLOAT) and int(v[k]) > 0:
				out[str(k)] = int(v[k])
	return out


## A saved list of ids, those `keep` accepts.
static func _ids(v, keep: Callable) -> Array:
	var out := []
	if typeof(v) == TYPE_ARRAY:
		for id in v:
			if keep.call(str(id)):
				out.append(str(id))
	return out
