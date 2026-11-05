extends "res://tests/test_case.gd"
## Acceptance: generated boxes match the type shares and net ranges, serials are
## unique in a box and no loser group is all one digit.
## Quick run: 300 boxes per form. With --full: 5,000 boxes per form.

const SERIAL := "^[A-Z][1-9][0-9]{5}$"


func test_boxes_per_form() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var n := 5000 if full else 300
	var model := BoxModel.standard()
	var serial_re := RegEx.create_from_string(SERIAL)
	for form in pack.forms:
		var type_hits := {}
		var sorted_groups := Array(form.digit_groups)
		sorted_groups.sort()
		var bad := 0
		for i in n:
			var seed := "D-%05d" % i
			var box := BoxGenerator.build(form, seed)
			var tag := "%s %s" % [form.id, seed]
			type_hits[box.type_id] = type_hits.get(box.type_id, 0) + 1
			bad += _check_box(box, model, serial_re, sorted_groups, tag)
			if failures.size() > 40:
				return
		check(bad == 0, "%s: %d boxes broke a rule" % [form.id, bad])
		# Type shares: each within 4.5 standard deviations of its weight.
		var line := PackedStringArray()
		for t in model.types:
			var hits: int = type_hits.get(t.id, 0)
			var share := float(hits) / n
			var sd := sqrt(t.weight * (1.0 - t.weight) / n)
			check(abs(share - t.weight) <= 4.5 * sd,
				"%s: type %s share %.4f, expected %.2f ± %.4f" % [form.id, t.id, share, t.weight, 4.5 * sd])
			line.append("%s %.3f" % [t.label.zh, share])
		note("%s ×%d: %s" % [form.id, n, ", ".join(line)])


## Returns 1 if the box broke any rule (details go to failures).
func _check_box(box: TicketBox, model: BoxModel, serial_re: RegEx, sorted_groups: Array, tag: String) -> int:
	var before := failures.size()
	var form := box.form
	var type := model.type_by_id(box.type_id)
	check(box.size >= 900 and box.size <= 1100 and box.size % 10 == 0, tag + ": size %d" % box.size)
	check(box.tickets.size() == box.size, tag + ": ticket count")
	# Net share of gross lands in the type's range; prize total is rounded to $25,
	# so allow half of that either side.
	var tol := 12.5 / box.gross()
	var share := float(box.net()) / box.gross()
	check(share >= type["min"] - tol - 1e-9 and share <= type["max"] + tol + 1e-9,
		"%s: net share %.4f outside %s [%.2f, %.2f]" % [tag, share, box.type_id, type["min"], type["max"]])
	var winners := 0
	for c in box.counts:
		check(c >= 0, tag + ": negative tier count")
		winners += c
	check(winners <= box.size, tag + ": more winners than tickets")

	var seen := {}
	var tier_hits := []
	tier_hits.resize(box.counts.size())
	tier_hits.fill(0)
	for t in box.tickets:
		if seen.has(t.serial):
			check(false, "%s: duplicate serial %s" % [tag, t.serial])
		seen[t.serial] = true
		if not serial_re.search(t.serial):
			check(false, "%s: bad serial %s" % [tag, t.serial])
		if t.tier >= 0:
			tier_hits[t.tier] += 1
			check(t.prize == form.tiers[t.tier].prize, tag + ": prize mismatch")
		else:
			check(t.prize == 0, tag + ": loser with prize")
		check(t.win_group >= 0 and t.win_group < t.groups.size(), tag + ": win group out of range")
		check((t.verify != "") == form.is_top(t.tier), tag + ": verify code only on top prizes")
		var lens := []
		for gi in t.groups.size():
			var g: PackedInt32Array = t.groups[gi]
			lens.append(g.size())
			check(t.marks[gi].size() == g.size(), tag + ": marks length")
			var all_same := true
			for k in range(1, g.size()):
				if g[k] != g[0]:
					all_same = false
			if all_same:
				check(false, "%s #%d: all-equal digit group %s" % [tag, t.no, g])
		lens.sort()
		if lens != sorted_groups:
			check(false, "%s #%d: group lengths %s" % [tag, t.no, lens])
		if failures.size() - before > 5:
			break
	check(tier_hits == box.counts, tag + ": tickets don't match tier counts")
	return 1 if failures.size() > before else 0


func test_same_seed_same_box() -> void:
	var pack := core_pack()
	if pack == null:
		return
	for form in pack.forms:
		var a := BoxGenerator.build(form, "repeat-me")
		var b := BoxGenerator.build(form, "repeat-me")
		var c := BoxGenerator.build(form, "repeat-me-2")
		eq(var_to_str(a.tickets), var_to_str(b.tickets), form.id + ": same seed must give the same box")
		check(var_to_str(a.tickets) != var_to_str(c.tickets), form.id + ": different seeds should differ")


func test_forms_get_different_boxes_from_one_seed() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var a := BoxGenerator.build(pack.forms[0], "G-0001")
	var b := BoxGenerator.build(pack.forms[2], "G-0001")
	check(a.tickets[0].serial != b.tickets[0].serial, "each form seeds its own box")


func test_summary_matches_web_numbers() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var box := BoxGenerator.build(pack.form("catch"), "G-0001")
	var s := box.summary()
	eq(s.remain, box.size, "nothing opened yet")
	eq(s.net, box.prize_total() - box.size, "net")
	box.opened = 10
	var paid := 0
	for i in 10:
		paid += box.tickets[i].prize
	eq(box.summary().paid, paid, "paid after 10 opened")
