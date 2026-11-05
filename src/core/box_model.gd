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


static func standard() -> BoxModel:
	return BoxModel.new()


func type_by_id(id: String) -> Dictionary:
	for t in types:
		if t.id == id:
			return t
	return {}
