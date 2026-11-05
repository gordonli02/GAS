class_name FormDef
extends RefCounted
## One ticket form as loaded from a pack. Plain data, no scene access.

const ROLES := ["top", "mid", "low"]
const WIN_DISPLAYS := ["whole", "one_group"]

var pack_id := ""
var id := ""                 ## unique inside its pack
var name := ""               ## printed on the ticket and the machine strip
var title: PackedStringArray = []
var code := ""
var price := 1
var colors := {}             ## edge, head, ink: Color; tiles: Array[Color]
var tiers: Array = []        ## {key, label: Dictionary, prize, printed_count, role, symbol}
var digit_groups: PackedInt32Array = []   ## loser digit group lengths, shuffled per ticket
var win_display := "whole"   ## "whole": winner replaces the inside; "one_group": one group shows the win
var layout := {}             ## presentation; see packs/README.md
var tear_clips: Array = []    ## optional per-form rips; empty means use the pack or core rips
var source_dir := ""         ## pack directory; every path in a pack is relative to it


## Full id used across packs, e.g. "core:catch".
func uid() -> String:
	return pack_id + ":" + id


func tier_indices(role: String) -> Array:
	var out := []
	for i in tiers.size():
		if tiers[i].role == role:
			out.append(i)
	return out


func is_top(tier_index: int) -> bool:
	return tier_index >= 0 and tiers[tier_index].role == "top"
