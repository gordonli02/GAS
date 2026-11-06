class_name RunConfig
extends RefCounted
## The numbers of a run (story mode): three layers of debt, each with its days, its
## stake, its wages and its house line. Plain data, no scene access.
##
## Every number here is a placeholder until the balance pass (docs/roadmap.md); what
## must hold is the rule the tests check: working every day of every layer and
## spending nothing pays each layer exactly on its last day, to the dollar.
## So for each layer: sum(wages) = debt, less the starting cash in the first.

const STANDARD := {
	"start_cash": 200,
	"loan_interest": 25,     ## percent, added once when the money is borrowed
	"layers": [
		{
			"days": 5, "debt": 1000,
			"stake": 1,                    ## ticket price, prizes and bills are the pack's times this
			"wages": [120, 120, 120, 220, 220],   ## pay for the 1st, 2nd ... shift worked in this layer
			"loan": 200, "loan_step": 100,        ## house line for the layer, and how much one press borrows
			"change_fee": 25,              ## a new box in one column
			"last_sale": 50,               ## prize for buying the last ticket of a box
			"box": {"size_min": 900, "size_step": 10, "size_steps": 21},
			## "forms": ["core:catch", ...] would name what this layer's machine sells, column
			## by column; without it the machine sells every form the game was started with.
		},
		{
			"days": 6, "debt": 5000,
			"stake": 5,
			"wages": [500, 500, 1000, 1000, 1000, 1000],
			"loan": 1000, "loan_step": 500,
			"change_fee": 125,
			"last_sale": 250,
			"box": {"size_min": 900, "size_step": 10, "size_steps": 21},
		},
		{
			"days": 7, "debt": 20000,
			"stake": 20,
			"wages": [2000, 2000, 2000, 3500, 3500, 3500, 3500],
			"loan": 4000, "loan_step": 2000,
			"change_fee": 500,
			"last_sale": 1000,
			"box": {"size_min": 900, "size_step": 10, "size_steps": 21},
		},
	],
}

var start_cash := 200
var loan_interest := 25
var layers: Array = []


static func standard() -> RunConfig:
	return from_dict(STANDARD)


static func from_dict(d: Dictionary) -> RunConfig:
	var c := RunConfig.new()
	c.start_cash = int(d.get("start_cash", 200))
	c.loan_interest = int(d.get("loan_interest", 25))
	c.layers = d.get("layers", []).duplicate(true)
	return c


func layer(i: int) -> Dictionary:
	return layers[clampi(i, 0, layers.size() - 1)]


## The box model of layer `i`: the standard odds at the layer's box sizes.
func box_model(i: int) -> BoxModel:
	var m := BoxModel.standard()
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


## What is wrong with these numbers, as text; empty when they hold together.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if layers.is_empty():
		out.append("no layers")
	var cash := start_cash
	for i in layers.size():
		var l: Dictionary = layers[i]
		var wages: Array = l.get("wages", [])
		if wages.size() != int(l.get("days", 0)):
			out.append("layer %d: %d wages for %d days" % [i + 1, wages.size(), int(l.get("days", 0))])
		for w in wages:
			cash += int(w)
		if cash != int(l.get("debt", 0)):
			out.append("layer %d: working every day leaves $%d against a debt of $%d" % [i + 1, cash, int(l.get("debt", 0))])
		cash = 0
		if int(l.get("stake", 0)) < 1:
			out.append("layer %d: stake under 1" % (i + 1))
		if int(l.get("loan_step", 0)) < 1:
			out.append("layer %d: loan step under 1" % (i + 1))
	return out
