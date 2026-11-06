class_name FormDef
extends RefCounted
## One ticket form as loaded from a pack. Plain data, no scene access.

const ROLES := ["top", "mid", "low"]
const WIN_DISPLAYS := ["whole", "one_group", "each_group"]

var pack_id := ""
var id := ""                 ## unique inside its pack
var name := ""               ## printed on the ticket and the machine strip
var title: PackedStringArray = []
var code := ""
var price := 1
var colors := {}             ## edge, head, ink: Color; tiles: Array[Color]
var tiers: Array = []        ## {key, label: Dictionary, prize, printed_count, role, symbol}
var digit_groups: PackedInt32Array = []   ## loser digit group lengths, shuffled per ticket
## How a ticket wins: "whole": one prize, it replaces the inside; "one_group": one prize,
## shown in one group; "each_group": every group can win on its own, so a ticket holds
## up to as many prizes as it has groups.
var win_display := "whole"
var layout := {}             ## presentation; see packs/README.md
var tear_clips: Array = []    ## optional per-form rips; empty means use the pack or core rips
var source_dir := ""         ## pack directory; every path in a pack is relative to it
var stake := 1               ## 1 as the pack wrote it; a stage may sell the form at a multiple (scaled())


## Full id used across packs, e.g. "core:catch".
func uid() -> String:
	return pack_id + ":" + id


func tier_indices(role: String) -> Array:
	var out := []
	for i in tiers.size():
		if tiers[i].role == role:
			out.append(i)
	return out


## Every digit group of a ticket wins on its own (win_display "each_group").
func wins_by_group() -> bool:
	return win_display == "each_group"


func is_top(tier_index: int) -> bool:
	return tier_index >= 0 and tiers[tier_index].role == "top"


## Key for painted art: the print shows the price and the prizes, so each stake has its own.
func art_key() -> String:
	return uid() if stake == 1 else "%s@%d" % [uid(), stake]


## The same form at `times` the pack's price and prizes (a stage's stake). Same id, so
## a seed gives the same box at every stake. Returns this form itself for 1.
func scaled(times: int) -> FormDef:
	if times == stake:
		return self
	var f := FormDef.new()
	for k in ["pack_id", "id", "name", "title", "code", "colors", "digit_groups", "win_display", "layout",
			"tear_clips", "source_dir"]:
		f.set(k, get(k))
	f.stake = times
	f.price = price / stake * times
	for t in tiers:
		var copy: Dictionary = t.duplicate()
		copy.prize = int(t.prize) / stake * times
		f.tiers.append(copy)
	return f
