class_name RunConfig
extends RefCounted
## The numbers of a run (story mode): three layers of debt, each with its days, its
## stake, its wage and its house line. Plain data, no scene access.
##
## Every number here is a placeholder until the balance pass (docs/roadmap.md). The
## debts are the balance lever: set here, tuned against the gambling bots' clear rates
## (roadmap "通关率目标"). The wage is not written here: it is derived from the debt
## (G, 2026-11-07, M9.7 item 11: "债务不能从打工线定，打工线要从债务定"), the smallest
## whole-dollar wage with which working every day, spending nothing on tickets and
## buying SAVINGS along the way pays each layer on its last day (work_line). The line is
## the lowest-priority route, an achievement; it still holds exactly: a dollar a day
## less, or any one day off work, and it falls short (problems() checks it).
##
## The line, as the simulator's work bot and the tests walk it: each morning of a layer
## after the first, cash grows by SAVINGS' percentage; then one level of SAVINGS is
## bought if the layer allows it (level k from layer k on) and the cash is there; then
## the day is worked. The few dollars over the debt on the last day are carried into the
## next layer, as a run carries them. Wages alone, without SAVINGS, fall short in every
## layer.

const STANDARD := {
	"start_cash": 200,
	"loan_interest": 15,     ## percent a day, compounding each morning on what is owed (G: above SAVINGS' first level)
	## Every run box's prize total times this (BoxModel.payout). G, 2026-11-07: a dollar of
	## tickets bought blind, whole boxes bought out, the last sale included, pays back about
	## 0.78 in the run (1.216 before: the last sale was a quarter of a small box). Free play
	## keeps the web build's boxes. Measured with tools/sim_runs (4000 boxes a form, two seeds):
	## no perks 0.783 and 0.780 averaged, each form within 0.77 to 0.80.
	"payout": 0.735,
	"layers": [
		{
			"days": 5,
			"stake": 1,                    ## ticket price, prizes and bills are the pack's times this
			"debt": 700,                   ## what the layer owes, due by its last day (the wage follows from it)
			"loan": 200, "loan_step": 100,        ## house line for the layer, and how much one press borrows
			"change_fee": 25,              ## a new box in one column
			"last_sale": 10,               ## prize for buying the last ticket of a box (about 5% of a box's tickets)
			"box": {"size_min": 180, "size_step": 2, "size_steps": 21},
			## "forms": ["core:catch", ...] would name what this layer's machine sells, column
			## by column; without it the machine sells every form the game was started with.
		},
		{
			"days": 6,
			"stake": 5,
			"debt": 3500,
			"loan": 1000, "loan_step": 500,
			"change_fee": 125,
			"last_sale": 75,
			"box": {"size_min": 270, "size_step": 3, "size_steps": 21},
		},
		{
			"days": 7,
			"stake": 20,
			"debt": 15000,
			"loan": 4000, "loan_step": 2000,
			"change_fee": 500,
			"last_sale": 500,
			"box": {"size_min": 450, "size_step": 5, "size_steps": 21},
		},
	],
}

## The perk the work line buys (its levels' prices and percentages are the catalog's).
const SAVINGS := "savings"

var start_cash := 200
var loan_interest := 15
var payout := 1.0            ## the boxes' prize totals times this (BoxModel.payout)
var layers: Array = []
var catalog: Catalog = null


static func standard() -> RunConfig:
	return from_dict(STANDARD)


## `catalog`: where SAVINGS' levels come from (the standard catalog when null). Each
## layer's `debt` is the config's; its `wage` is the work line's (work_line), unless the
## dict pins one (a `wage` key: a Workshop or dev config may; problems() still holds it
## to the line). The derived wage is written into the layer, with `wage_derived` set, so
## RunState reads it from stage() and feeding these layers back derives it again.
static func from_dict(d: Dictionary, cat: Catalog = null) -> RunConfig:
	var c := RunConfig.new()
	c.start_cash = int(d.get("start_cash", 200))
	c.loan_interest = int(d.get("loan_interest", 15))
	c.payout = float(d.get("payout", 1.0))
	c.layers = d.get("layers", []).duplicate(true)
	c.catalog = cat if cat != null else Catalog.standard()
	var line := c.work_line()
	for i in c.layers.size():
		if not c.wage_pinned(i):
			c.layers[i]["wage"] = line[i].wage
			c.layers[i]["wage_derived"] = true
		# The day of the layer the line buys SAVINGS on (its checkpoint; G: the first
		# day of the run for the first level), 0 when it buys nothing in the layer.
		c.layers[i]["savings_day"] = line[i].day
	return c


## Whether layer `i`'s wage was set by the config rather than derived from its debt.
func wage_pinned(i: int) -> bool:
	var l: Dictionary = layers[i]
	return l.has("wage") and not bool(l.get("wage_derived", false))


func layer(i: int) -> Dictionary:
	return layers[clampi(i, 0, layers.size() - 1)]


## The box model of layer `i`: the standard odds at the layer's box sizes, with the
## forms' own shapes, chance-rounded prizes and the run's payout (G, M9.6 and M9.7: the
## run only; free play keeps the web build's boxes).
func box_model(i: int) -> BoxModel:
	var m := BoxModel.standard()
	m.shapes = true
	m.chance_round = true
	m.payout = payout
	var b: Dictionary = layer(i).get("box", {})
	m.size_min = int(b.get("size_min", m.size_min))
	m.size_step = int(b.get("size_step", m.size_step))
	m.size_steps = int(b.get("size_steps", m.size_steps))
	return m


## What the bill slot takes at a stake.
static func bills(stake: int) -> Array:
	var out := []
	for v in Economy.BILLS:
		out.append(v * stake)
	return out


## Whether the work line buys SAVINGS level `next_level` (1-based) in layer `i` (0-based):
## one level a layer, from the first.
static func line_buys(next_level: int, i: int) -> bool:
	return next_level <= i + 1


## The work line through every layer: per layer {debt, wage, pinned, cash_in, level_in,
## cash, spare, wages, grown, bought, level, day}. `wage` is the smallest whole-dollar
## wage that pays the debt on the last day (or the pinned one); `cash_in` and `level_in`
## what the line brings into the layer; `cash` what it has on the last day, `spare` that
## less the debt (carried into the next layer); `wages` the cash brought in plus the
## wages alone (what working without SAVINGS leaves); `day` the day of the layer SAVINGS
## was bought on (0: none), the checkpoint the player has to keep to walk the line.
func work_line() -> Array:
	var out := []
	var cash := start_cash
	var level := 0
	for i in layers.size():
		var debt := int(layers[i].get("debt", 0))
		var pinned := wage_pinned(i)
		var wage := int(layers[i].wage) if pinned else line_wage(i, cash, level)
		var w := walk_layer(i, cash, level, wage)
		w.merge({"debt": debt, "wage": wage, "pinned": pinned, "cash_in": cash, "level_in": level,
			"spare": int(w.cash) - debt})
		out.append(w)
		cash = maxi(0, int(w.cash) - debt)
		level = int(w.level)
	return out


## The smallest whole-dollar wage with which the line, bringing `cash` and SAVINGS at
## `level` into layer `i`, has the layer's debt on its last day; 0 when it has it
## without working (problems() reports that).
func line_wage(i: int, cash: int, level: int) -> int:
	var debt := int(layers[i].get("debt", 0))
	if int(layers[i].get("days", 0)) < 1 or int(walk_layer(i, cash, level, 0).cash) >= debt:
		return 0
	# A wage of the whole debt pays it on the last day, no wage does not: between the
	# two, keep a wage that falls short (lo) and one that pays (hi).
	var lo := 0
	var hi := debt
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if int(walk_layer(i, cash, level, mid).cash) >= debt:
			hi = mid
		else:
			lo = mid
	return hi


## One layer of the line: {cash, wages, grown, bought, level, day} (see work_line).
## `off`: a day (0-based) not worked; `late`: SAVINGS bought that many days after the
## line would (for problems() and the tests: the line falls short with either).
func walk_layer(i: int, cash: int, level: int, wage: int, off := -1, late := 0) -> Dictionary:
	var levels: Array = catalog.perk(SAVINGS).get("levels", []) if catalog != null else []
	var l: Dictionary = layers[i]
	var stake := int(l.get("stake", 1))
	var plain := cash
	var grown := 0
	var bought := 0
	var on_day := 0
	var wait := late
	for day in int(l.get("days", 0)):
		if day > 0 and level > 0:
			var g := roundi(cash * int(levels[level - 1].value) / 100.0)
			cash += g
			grown += g
		if level < levels.size() and line_buys(level + 1, i) and on_day == 0:
			var price := int(levels[level].price) * stake
			if cash >= price:
				if wait > 0:
					wait -= 1
				else:
					cash -= price
					bought += price
					level += 1
					on_day = day + 1
		if day != off:
			cash += wage
		plain += wage
	return {"cash": cash, "wages": plain, "grown": grown, "bought": bought, "level": level, "day": on_day}


## What is wrong with these numbers, as text; empty when they hold together.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if layers.is_empty():
		out.append("no layers")
	if catalog == null or catalog.perk(SAVINGS).is_empty():
		out.append("no SAVINGS perk for the work line")
		return out
	var line := work_line()
	for i in layers.size():
		var l: Dictionary = layers[i]
		var w: Dictionary = line[i]
		var debt := int(w.debt)
		var days := int(l.get("days", 0))
		if days < 1:
			out.append("layer %d: no days" % (i + 1))
		if debt < 1:
			out.append("layer %d: no debt" % (i + 1))
		if int(w.wage) < 1:
			if w.pinned:
				out.append("layer %d: no wage" % (i + 1))
			elif debt >= 1 and days >= 1:
				out.append("layer %d: the line meets the debt ($%d) without a wage ($%d brought in, SAVINGS %d); the debt is too small" % [
					i + 1, debt, int(w.cash_in), int(w.level_in)])
		if int(w.cash) < debt:
			out.append("layer %d: the work line leaves $%d against a debt of $%d" % [i + 1, int(w.cash), debt])
		if int(w.wages) >= debt:
			out.append("layer %d: wages alone ($%d) meet the debt ($%d); SAVINGS should be needed" % [i + 1, int(w.wages), debt])
		if int(w.wage) >= 1 and int(walk_layer(i, int(w.cash_in), int(w.level_in), int(w.wage) - 1).cash) >= debt:
			out.append("layer %d: the line still pays the debt with a wage of $%d (the wage has room)" % [i + 1, int(w.wage) - 1])
		for k in days:
			if int(walk_layer(i, int(w.cash_in), int(w.level_in), int(w.wage), k).cash) >= debt:
				out.append("layer %d: the line pays the debt with day %d off work" % [i + 1, k + 1])
				break
		if int(l.get("stake", 0)) < 1:
			out.append("layer %d: stake under 1" % (i + 1))
		if int(l.get("loan_step", 0)) < 1:
			out.append("layer %d: loan step under 1" % (i + 1))
	if not line.is_empty() and int(line[line.size() - 1].level) < catalog.perk(SAVINGS).levels.size():
		out.append("the work line never reaches the top of SAVINGS")
	if not line.is_empty() and int(line[0].day) != 1:
		out.append("the work line should buy SAVINGS on the first day (G); it buys on day %d" % int(line[0].day))
	elif not line.is_empty() and int(walk_layer(0, start_cash, 0, int(line[0].wage), -1, 1).cash) >= int(line[0].debt):
		out.append("SAVINGS bought a day late still pays the first layer; the first-day checkpoint does not hold")
	if loan_interest < 1:
		out.append("no loan interest")
	if payout <= 0.0:
		out.append("payout not above 0")
	return out


## The line in a few words, for the simulator and the dev panel: per layer the debt, the
## wage derived from it (or pinned), and when SAVINGS is bought.
func line_text() -> String:
	var parts := PackedStringArray()
	var line := work_line()
	for i in line.size():
		var w: Dictionary = line[i]
		parts.append("layer %d: debt $%d, wage $%d%s x %d days, SAVINGS %d on day %d, $%d over" % [i + 1, int(w.debt),
			int(w.wage), " (pinned)" if w.pinned else "", int(layers[i].get("days", 0)), int(w.level), int(w.day), int(w.spare)])
	return "; ".join(parts)
