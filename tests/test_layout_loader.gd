extends "res://tests/test_case.gd"
## Ticket layouts: the three built-in layouts are valid, broken layouts are rejected
## with an error that names the field.

const SINGLE := "res://packs/core/layouts/single.json"


func _validate(layout, form: FormDef) -> PackedStringArray:
	var errors := PackedStringArray()
	var ctx = PackLoader._Ctx.new("res://packs/core", errors)
	LayoutLoader.validate(ctx, layout, form, "test.json")
	return errors


func _single() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(SINGLE))


func test_core_layouts_valid() -> void:
	var pack := core_pack()
	if pack == null:
		return
	for f in pack.forms:
		check(not f.layout.is_empty(), f.id + " layout loaded")
	eq(pack.form("plate").layout.pairs, "adjacent", "plate pairs")
	eq(pack.form("spur").layout.flaps[0].hinge, "top", "spur hinge")
	check(pack.form("spur").layout.band != null, "spur has a band")
	check(pack.form("catch").layout.band == null, "catch has no band")


func test_rejects_broken_layouts() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var form := pack.form("catch")
	var cases := {
		"unknown layer": func(l): l.front.append({"type": "sparkle"}),
		"bad colour": func(l): l.front[0].fill = "blue",
		"tile out of range": func(l): l.front[0].fill = "tile.9",
		"tile outside each_tier": func(l): l.front[0].fill = "tile",
		"win_tile on front": func(l): l.front[0].fill = "win_tile",
		"unknown variable": func(l): l.front.append({"type": "text", "text": "{cash}", "pos": [0, 0], "font": "slab", "size": 10, "fill": "ink"}),
		"prize on front": func(l): l.front.append({"type": "text", "text": "{prize}", "pos": [0, 0], "font": "slab", "size": 10, "fill": "ink"}),
		"unknown font": func(l): l.front.append({"type": "text", "text": "x", "pos": [0, 0], "font": "comic", "size": 10, "fill": "ink"}),
		"text in clip": func(l): l.front.append({"type": "group", "clip": [0, 0, 10, 10], "layers": [{"type": "text", "text": "x", "pos": [0, 0], "font": "slab", "size": 10, "fill": "ink"}]}),
		"slots vs groups": func(l): l.interior.slots.pop_back(),
		"no winner": func(l): l.interior.erase("winner"),
		"overlapping flaps": func(l): l.flaps.append(l.flaps[0].duplicate(true)),
		"flap outside": func(l): l.flaps[0].rect = [300, 16, 388, 568],
		"bad hinge": func(l): l.flaps[0].hinge = "middle",
		"missing template": func(l): l.flaps[0].cover = "tab",
		"card too big": func(l): l.card.size = [3.0, 2.0],
		"bad pairs": func(l): l.pairs = "all",
		"bad band": func(l): l.band = {"height": 2.0, "canvas": [10, 10], "layers": []},
		"bad slide": func(l): l.reveal_slide = [2, 0],
		"bad condition": func(l): l.front[0]["if"] = "sometimes",
		"symbol win on front": func(l): l.front.append({"type": "symbol", "tier": "win", "center": [0, 0], "size": 10}),
		"missing image": func(l): l.front.append({"type": "image", "src": "art/nope.png", "rect": [0, 0, 10, 10]}),
		"repeat too many": func(l): l.front[0].repeat = {"count": 5000, "step": [1, 0]},
		"side_pull not bool": func(l): l.flaps[0].side_pull = "yes",
		"unknown band break": func(l): l.band = {"height": 0.24, "canvas": [64, 8], "layers": [], "breaks": ["melt"]},
		"empty band breaks": func(l): l.band = {"height": 0.24, "canvas": [64, 8], "layers": [], "breaks": []},
	}
	eq(_validate(_single(), form).size(), 0, "unchanged single layout is valid")
	for name in cases:
		var l := _single()
		cases[name].call(l)
		var errors := _validate(l, form)
		check(errors.size() > 0, "'%s' must be rejected" % name)
		for e in errors:
			check(e.begins_with("test.json"), "error names the file: " + e)


func test_windows_layout_needs_win_slot() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var plate := pack.form("plate")
	var l: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://packs/core/layouts/windows.json"))
	eq(_validate(l, plate).size(), 0, "windows layout valid for plate")
	l.interior.erase("win_slot")
	check(_validate(l, plate).size() > 0, "one_group form needs win_slot")
	l = JSON.parse_string(FileAccess.get_file_as_string("res://packs/core/layouts/windows.json"))
	l.interior.slots[0].erase("rect")
	check(_validate(l, plate).size() > 0, "one_group slots need a rect")


## each_tier can be held to some tiers ("tiers"), and a rect can have round corners.
func test_tier_filter_and_radius() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var form := pack.form("catch")
	var l := _single()
	l.front.append({"type": "each_tier", "tiers": [1, 0], "origin": [0, 0], "columns": 2, "step": [10, 0],
		"layers": [{"type": "rect", "rect": [0, 0, 8, 8], "fill": "tile", "radius": 3}]})
	eq(_validate(l, form).size(), 0, "tiers and radius are valid")
	l.front[-1].tiers = [4]
	check(_validate(l, form).size() > 0, "a tier the form does not have")
	l.front[-1].tiers = []
	check(_validate(l, form).size() > 0, "an empty tier list")
	l.front[-1].tiers = [0]
	l.front[-1].layers[0].radius = -1
	check(_validate(l, form).size() > 0, "a negative radius")
	for f in ["order", "kabawk", "flock", "nugget", "peckeye"]:
		check(not pack.form(f).layout.is_empty(), f + " layout loaded")
