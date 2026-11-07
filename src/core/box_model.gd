class_name BoxModel
extends RefCounted
## Odds for how a box of tickets is composed. Plain data, no scene access.
## Numbers and the order of random draws match the web build exactly.

## id, dev-panel label, weight, net share min, net share max. Order matters: the roll walks this list.
const STANDARD_TYPES := [
	{"id": "big_loss", "label": {"en": "Big loss", "zh": "大亏"}, "weight": 0.1, "min": -0.75, "max": -0.55},
	{"id": "mid_loss", "label": {"en": "Medium loss", "zh": "中亏"}, "weight": 0.15, "min": -0.55, "max": -0.35},
	{"id": "small_loss", "label": {"en": "Small loss", "zh": "小亏"}, "weight": 0.2, "min": -0.35, "max": -0.12},
	{"id": "break_even", "label": {"en": "Break even", "zh": "盈亏平衡"}, "weight": 0.2, "min": -0.06, "max": 0.06},
	{"id": "small_win", "label": {"en": "Small win", "zh": "小赚"}, "weight": 0.18, "min": 0.12, "max": 0.35},
	{"id": "mid_win", "label": {"en": "Medium win", "zh": "中赚"}, "weight": 0.12, "min": 0.35, "max": 0.8},
	{"id": "big_win", "label": {"en": "Big win", "zh": "大赚"}, "weight": 0.05, "min": 0.8, "max": 1.6},
]

var types: Array = STANDARD_TYPES
var size_min := 900
var size_step := 10
var size_steps := 21          # 900, 910 ... 1100
## Share of the prize total spent on top prizes: min + span * r (0.10 to 0.40).
var top_share_min := 0.1
var top_share_span := 0.3
## Share of what is left spent on mid prizes: min + span * r (0.10 to 0.25).
var mid_share_min := 0.1
var mid_share_span := 0.15
## Forms that win by group only (not in the web build). The chance that a prize lands
## on a ticket that already holds one, in one of its free groups, instead of anywhere
## in the box. At 0 a box of about 34 prizes in 3,000 to 5,000 groups has a ticket with
## two prizes once in two boxes; at 0.12 it has about four, and one with three now and
## then. The box's prizes and money are the same either way. G settled on 0.12
## (2026-11-06, M8.5).
var stack_share := 0.12
## Whether a form's own shape (FormDef.shape: its top and mid shares) replaces the
## shares above. The run's model says yes (RunConfig.box_model), so Big Catch is the
## jackpot form and Hot Plate pays small and often; free play keeps the web build's
## boxes, shape or no shape (G, M9.6). The same draws are made either way, so a seed
## gives the same type and size, and the same prize total, with shapes on or off.
var shapes := false
## Chance rounding, for boxes too small to hold a whole top or mid prize (the run's
## boxes of 200 to 500 tickets, G 2026-11-07). The money a tier is meant to get is kept
## as a float: the box holds floor(money / prize) of that prize, and one more with the
## chance of the remainder (money / prize - floor), so the box's expected prize money is
## the same as if prizes could be cut. The smallest prizes take what is left of the
## total after the full top and mid money, rounded to the nearest prize; a box that
## hits a top therefore pays more than its type says, one that misses pays less. Two
## draws more than the standard deal, the top's chance right after the top share and
## the mid's right after the mid share. With it off (free play, the web build) the draws
## and every number are exactly the web build's.
var chance_round := false
## The run's payout (G, 2026-11-07): every box's prize total is what its type sets times
## this, so a dollar of tickets bought blind, whole boxes bought out, pays back about
## this much (plus the last-sale prize). Set by RunConfig.box_model from the run
## config's "payout"; the draws are the same, so a seed gives the same type and size.
## The type's label would then lie (a "Break even" box loses), so the box is also told
## by its net after the payout (TicketBox.net_type_id, type_for_net). At 1.0 (free play,
## the web build) every draw and number is the web build's.
var payout := 1.0


static func standard() -> BoxModel:
	return BoxModel.new()


## The three numbers that set a box's size, [size_min, size_step, size_steps]. A saved
## box that was built under another layer's sizes (SEAL carries one over) keeps them.
func sizes_key() -> Array:
	return [size_min, size_step, size_steps]


## This model with other box sizes (a key from sizes_key): the same odds otherwise.
func with_sizes(key: Array) -> BoxModel:
	var m := BoxModel.new()
	m.types = types
	m.top_share_min = top_share_min
	m.top_share_span = top_share_span
	m.mid_share_min = mid_share_min
	m.mid_share_span = mid_share_span
	m.stack_share = stack_share
	m.shapes = shapes
	m.chance_round = chance_round
	m.payout = payout
	m.size_min = int(key[0])
	m.size_step = int(key[1])
	m.size_steps = int(key[2])
	return m


func type_by_id(id: String) -> Dictionary:
	for t in types:
		if t.id == id:
			return t
	return {}


## The type whose net share range holds `net` (prize money over ticket money, less 1):
## the first that holds it, else the nearest (the ranges leave gaps: -0.12 to -0.06,
## 0.06 to 0.12; past either end, the end's type). What a box with the payout is told.
func type_for_net(net: float) -> Dictionary:
	var best: Dictionary = {}
	var gap := INF
	for t in types:
		var lo := float(t["min"])
		var hi := float(t["max"])
		if net >= lo and net <= hi:
			return t
		var d := lo - net if net < lo else net - hi
		if d < gap:
			gap = d
			best = t
	return best
