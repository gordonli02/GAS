class_name RunConfig
extends RefCounted
## The numbers of a run (story mode): three layers of debt, each with its days, its
## stake, its wage and its house line. Plain data, no scene access.
##
## Every number here is a placeholder until the balance pass (docs/roadmap.md); what
## must hold is the rule the tests check (G, 2026-11-06, in place of the hidden raises):
## working every day, spending nothing on tickets and buying SAVINGS along the way pays
## each layer exactly on its last day, to the dollar. The debt of a layer is not written
## here: it is what that line has on the last day (work_line), so the rule holds by
## construction and the debts come out as ugly as compound interest should.
##
## The line, as the simulator's work bot and the tests walk it: each morning of a layer
## after the first, cash grows by SAVINGS' percentage; then one level of SAVINGS is
## bought if the layer allows it (level k from layer k on) and the cash is there; then
## the day is worked. Wages alone, without SAVINGS, fall short in every layer.

const STANDARD := {
	"start_cash": 200,
	"loan_interest": 15,     ## percent a day, compounding each morning on what is owed (G: above SAVINGS' first level)
	"layers": [
		{
			"days": 5,
			"stake": 1,                    ## ticket price, prizes and bills are the pack's times this
			"wage": 150,                   ## pay for a shift, the same every day of the layer
			"loan": 200, "loan_step": 100,        ## house line for the layer, and how much one press borrows
			"change_fee": 25,              ## a new box in one column
			"last_sale": 50,               ## prize for buying the last ticket of a box
			"box": {"size_min": 900, "size_step": 10, "size_steps": 21},
			## "forms": ["core:catch", ...] would name what this layer's machine sells, column
			## by column; without it the machine sells every form the game was started with.
		},
		{
			"days": 6,
			"stake": 5,
			"wage": 700,
			"loan": 1000, "loan_step": 500,
			"change_fee": 125,
			"last_sale": 250,
			"box": {"size_min": 900, "size_step": 10, "size_steps": 21},
		},
		{
			"days": 7,
			"stake": 20,
			"wage": 2500,
			"loan": 4000, "loan_step": 2000,
			"change_fee": 500,
			"last_sale": 1000,
			"box": {"size_min": 900, "size_step": 10, "size_steps": 21},
		},
	],
}

## The perk the work line buys (its levels' prices and percentages are the catalog's).
const SAVINGS := "savings"

var start_cash := 200
var loan_interest := 15
var layers: Array = []
var catalog: Catalog = null


static func standard() -> RunConfig:
	return from_dict(STANDARD)


## `catalog`: where SAVINGS' levels come from (the standard catalog when null). A layer
## without a `debt` gets the work line's.
static func from_dict(d: Dictionary, cat: Catalog = null) -> RunConfig:
	var c := RunConfig.new()
	c.start_cash = int(d.get("start_cash", 200))
	c.loan_interest = int(d.get("loan_interest", 15))
	c.layers = d.get("layers", []).duplicate(true)
	c.catalog = cat if cat != null else Catalog.standard()
	var line := c.work_line()
	for i in c.layers.size():
		if not c.layers[i].has("debt"):
			c.layers[i]["debt"] = line[i].debt
		# The day of the layer the line buys SAVINGS on (its checkpoint; G: the first
		# day of the run for the first level), 0 when it buys nothing in the layer.
		c.layers[i]["savings_day"] = line[i].day
	return c


func layer(i: int) -> Dictionary:
	return layers[clampi(i, 0, layers.size() - 1)]


## The box model of layer `i`: the standard odds at the layer's box sizes, with the
## forms' own shapes (G, M9.6: the run only; free play keeps the web build's boxes).
func box_model(i: int) -> BoxModel:
	var m := BoxModel.standard()
	m.shapes = true
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


## The work line through every layer: [{debt, wages, grown, bought, level, day}] per
## layer. `debt` is the cash on the layer's last day (what the layer's debt is set to);
## `wages` the wages alone with the starting cash (what working without SAVINGS
## leaves); `day` the day of the layer SAVINGS was bought on (0: none), the checkpoint
## the player has to keep to walk the line (buying later grows less).
func work_line() -> Array:
	var out := []
	var levels: Array = catalog.perk(SAVINGS).get("levels", []) if catalog != null else []
	var cash := start_cash
	var plain := start_cash
	var level := 0
	for i in layers.size():
		var l: Dictionary = layers[i]
		var stake := int(l.get("stake", 1))
		var wage := int(l.get("wage", 0))
		var grown := 0
		var bought := 0
		var on_day := 0
		for day in int(l.get("days", 0)):
			if day > 0 and level > 0:
				var g := roundi(cash * int(levels[level - 1].value) / 100.0)
				cash += g
				grown += g
			if level < levels.size() and line_buys(level + 1, i) and on_day == 0:
				var price := int(levels[level].price) * stake
				if cash >= price:
					cash -= price
					bought += price
					level += 1
					on_day = day + 1
			cash += wage
			plain += wage
		out.append({"debt": cash, "wages": plain, "grown": grown, "bought": bought, "level": level, "day": on_day})
		cash = 0
		plain = 0
	return out


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
		if int(l.get("days", 0)) < 1:
			out.append("layer %d: no days" % (i + 1))
		if int(l.get("wage", 0)) < 1:
			out.append("layer %d: no wage" % (i + 1))
		if int(l.get("debt", -1)) != int(line[i].debt):
			out.append("layer %d: the work line leaves $%d against a debt of $%d" % [i + 1, int(line[i].debt), int(l.get("debt", -1))])
		if int(line[i].wages) >= int(line[i].debt):
			out.append("layer %d: wages alone ($%d) meet the debt ($%d); SAVINGS should be needed" % [i + 1, int(line[i].wages), int(line[i].debt)])
		if int(l.get("stake", 0)) < 1:
			out.append("layer %d: stake under 1" % (i + 1))
		if int(l.get("loan_step", 0)) < 1:
			out.append("layer %d: loan step under 1" % (i + 1))
	if int(line[line.size() - 1].level) < catalog.perk(SAVINGS).levels.size():
		out.append("the work line never reaches the top of SAVINGS")
	if not line.is_empty() and int(line[0].day) != 1:
		out.append("the work line should buy SAVINGS on the first day (G); it buys on day %d" % int(line[0].day))
	if loan_interest < 1:
		out.append("no loan interest")
	return out


## The line in a few words, for the simulator and the dev panel.
func line_text() -> String:
	var parts := PackedStringArray()
	var line := work_line()
	for i in line.size():
		parts.append("layer %d: debt $%d, wages $%d, SAVINGS %d on day %d" % [i + 1, int(line[i].debt), int(line[i].wages),
			int(line[i].level), int(line[i].day)])
	return "; ".join(parts)
