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
		var top := false
		if form.wins_by_group():
			# Every group wins on its own: the prize is their sum, the tier the best of them.
			check(t.wins.size() == t.groups.size(), tag + ": one result per group")
			var sum := 0
			var best := 0
			for w in t.wins:
				if w >= 0:
					tier_hits[w] += 1
					sum += int(form.tiers[w].prize)
					best = maxi(best, int(form.tiers[w].prize))
					top = top or form.is_top(w)
			check(t.prize == sum, tag + ": prize is not the sum of its groups")
			check((t.tier < 0) == (sum == 0), tag + ": tier and prize disagree")
			if t.tier >= 0:
				check(int(form.tiers[t.tier].prize) == best, tag + ": tier is not the best group")
		else:
			if t.tier >= 0:
				tier_hits[t.tier] += 1
				check(t.prize == form.tiers[t.tier].prize, tag + ": prize mismatch")
			else:
				check(t.prize == 0, tag + ": loser with prize")
			check(t.win_group >= 0 and t.win_group < t.groups.size(), tag + ": win group out of range")
			top = form.is_top(t.tier)
		check((t.verify != "") == top, tag + ": verify code only on top prizes")
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


## G, M8.5: Hot Plate and Lucky Spur win by group. The box is the one the old deal
## made (same type, size, prize counts, so the same money); only where the prizes
## sit changes, and now and then one ticket holds two.
func test_group_wins_keep_the_box() -> void:
	var pack := core_pack()
	if pack == null:
		return
	check(not pack.form("catch").wins_by_group(), "Big Catch still wins as a whole ticket")
	for id in ["plate", "spur"]:
		var form := pack.form(id)
		if not check(form.wins_by_group(), id + " wins by group"):
			continue
		var old: FormDef = form.scaled(2)
		old.win_display = "one_group"
		var groups := form.digit_groups.size()
		var doubles := 0
		var most := 0
		var winners := 0
		var prizes := 0
		var by_group := []
		by_group.resize(groups)
		by_group.fill(0)
		for n in 200:
			var seed := "GW-%03d" % n
			var box := BoxGenerator.build(form, seed)
			var was := BoxGenerator.build(old, seed, null, true)
			eq(box.size, was.size, "%s %s: size" % [id, seed])
			eq(box.type_id, was.type_id, "%s %s: type" % [id, seed])
			eq(box.counts, was.counts, "%s %s: prize counts" % [id, seed])
			var paid := 0
			for t in box.tickets:
				var held := 0
				for k in groups:
					if t.wins[k] >= 0:
						held += 1
						by_group[k] += 1
				paid += t.prize
				prizes += held
				most = maxi(most, held)
				if held > 0:
					winners += 1
				if held > 1:
					doubles += 1
			eq(paid, box.prize_total(), "%s %s: the tickets pay the box's prizes" % [id, seed])
			# Opened to the end, nothing is left and everything was paid.
			box.opened = box.size
			var s := box.summary()
			eq(s.paid, box.prize_total(), "%s %s: summary paid" % [id, seed])
			check(s.left.all(func(c): return c == 0), "%s %s: summary leaves no prize" % [id, seed])
		check(doubles > 0, "%s: some tickets hold more than one prize (%d in 200 boxes)" % [id, doubles])
		check(most <= groups, "%s: never more prizes than groups" % id)
		check(winners < prizes, "%s: fewer winning tickets than prizes" % id)
		# Every group gets its share of the prizes: within 5 standard deviations.
		var share := 1.0 / groups
		var sd := sqrt(share * (1.0 - share) / prizes)
		for k in groups:
			check(absf(float(by_group[k]) / prizes - share) <= 5.0 * sd, "%s: group %d holds %.4f of the prizes" % [id, k, float(by_group[k]) / prizes])
		note("%s: %d prizes on %d tickets, %d with two or more, at most %d on one (200 boxes)" % [id, prizes, winners, doubles, most])
