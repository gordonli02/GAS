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


## G, M9.6: a form's shape moves the box's money between the tiers and gives the run
## its own prize table, in the run's model only. The box is otherwise the same (type,
## size, and the prize money its type sets, to the rounding of the smallest prize), so
## every form pays back the same on average; free play's boxes do not change at all.
func test_shapes_move_money_between_tiers_only_in_the_run() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var run_model := _shaped_900()   # the run before the smaller boxes: only the shapes are tested here
	check(run_model.shapes, "the run's model asks for shapes")
	check(not BoxModel.standard().shapes, "the standard model (free play) does not")
	# Every form has the run's prize table (the smallest prizes came down for G, after
	# M9.5); the five G shaped carry their own shares too, the plain ones wait for
	# their signature rules.
	var shaped := ["catch", "plate", "spur", "kabawk", "nugget"]
	var stats := {}
	for form in pack.forms:
		check(form.shape.has("prizes"), form.id + ": has the run's prize table")
		eq(form.shape.has("top"), shaped.has(form.id), form.id + ": has its own shares")
		var run_form: FormDef = form.shaped()
		check(run_form.shaped_prizes, form.id + ": shaped() puts the prizes on")
		check(run_form.uid() == form.uid(), form.id + ": the same form")
		var low := int(run_form.tiers[run_form.tier_indices("low")[0]].prize)
		var differ := 0
		var tops := 0
		var lows := 0
		var winners := 0
		var tickets := 0
		var total := 0
		for n in 100:
			var seed := "SH-%03d" % n
			var plain := BoxGenerator.build(form, seed, null, true)
			var run := BoxGenerator.build(run_form, seed, run_model, true)
			eq(run.type_id, plain.type_id, "%s %s: same type" % [form.id, seed])
			eq(run.size, plain.size, "%s %s: same size" % [form.id, seed])
			check(absi(run.prize_total() - plain.prize_total()) <= 25, "%s %s: the same money, to the rounding ($%d against $%d)" % [form.id, seed, run.prize_total(), plain.prize_total()])
			if run.counts != plain.counts:
				differ += 1
			var paid := 0
			for t in run.tickets:
				paid += t.prize
				if t.prize > 0:
					winners += 1
			tickets += run.size
			eq(paid, run.prize_total(), "%s %s: the tickets pay the box" % [form.id, seed])
			for i in run.counts.size():
				if run_form.is_top(i):
					tops += run.counts[i]
			lows += run.counts[run_form.tier_indices("low")[0]]
			total += run.prize_total()
		check(differ > 50, "%s: the run's prize table changes the counts (%d of 100 boxes)" % [form.id, differ])
		stats[form.id] = {"tops": tops / 100.0, "lows": lows / 100.0, "winners": 100.0 * winners / tickets}
		note("%s: %.2f tops and %.0f lows ($%d) a box, %.1f winners in 100, $%.0f a box (100 run boxes)" % [form.id, tops / 100.0, lows / 100.0, low, 100.0 * winners / tickets, total / 100.0])
	# The shapes as G chose them: Ka-Bawk! is all or nothing, Big Catch the jackpot form,
	# Hot Plate and Nugget Rush pay small and often; Pecking Order is the plain form.
	check(stats.kabawk.tops > stats.catch.tops and stats.catch.tops > stats.order.tops, "top prizes: Ka-Bawk! > Big Catch > plain")
	# With the smallest prizes at $5 (G: the forms felt hopeless) every form but Ka-Bawk!
	# wins over ten in a hundred; Ka-Bawk! stays the all-or-nothing form.
	for id in ["nugget", "plate", "order", "catch"]:
		check(stats[id].winners > 10.0, "winners: %s over ten in a hundred (%.1f)" % [id, stats[id].winners])
	for id in ["nugget", "plate", "order", "catch"]:
		check(stats.kabawk.winners < stats[id].winners, "winners: Ka-Bawk! the fewest (%.1f against %s)" % [stats.kabawk.winners, id])
	check(stats.plate.lows > stats.order.lows and stats.order.lows > stats.kabawk.lows, "small prizes: Hot Plate > plain > Ka-Bawk!")


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


## The run's model as it was before the smaller boxes: shapes, 900 to 1100 tickets, no
## chance rounding. Free play's boxes are the standard model's.
func _shaped_900() -> BoxModel:
	var m := BoxModel.standard()
	m.shapes = true
	return m


## The run's model of a layer without chance rounding: the same size, type and total
## (the payout kept).
func _without_chance(m: BoxModel) -> BoxModel:
	var o := BoxModel.standard()
	o.shapes = m.shapes
	o.payout = m.payout
	o.size_min = m.size_min
	o.size_step = m.size_step
	o.size_steps = m.size_steps
	return o


## M9.7: chance rounding is the run's alone. With it off every box is what it was (the
## values below were recorded from the generator before the change: size, type, counts).
func test_chance_rounding_off_changes_nothing() -> void:
	var pack := core_pack()
	if pack == null:
		return
	check(RunConfig.standard().box_model(0).chance_round, "the run's model rounds by chance")
	check(not BoxModel.standard().chance_round, "free play's does not")
	var rows := [
		["catch", "GOLD-1", false, 980, "small_loss", [0, 0, 1, 29]],
		["catch", "GOLD-1", true, 980, "small_loss", [0, 0, 0, 163]],
		["catch", "GOLD-2", true, 1090, "big_loss", [0, 0, 0, 66]],
		["spur", "GOLD-2", false, 1000, "mid_win", [1, 0, 1, 37]],
		["spur", "GOLD-3", true, 1040, "big_win", [0, 0, 10, 290]],
		["kabawk", "GOLD-2", true, 1000, "small_loss", [1, 0, 0, 75]],
		["kabawk", "GOLD-3", true, 980, "small_win", [0, 1, 0, 154]],
		["flock", "GOLD-1", false, 1020, "mid_win", [0, 0, 4, 54]],
		["nugget", "GOLD-3", true, 920, "mid_win", [0, 0, 7, 253]],
		["order", "GOLD-3", false, 1100, "mid_win", [0, 0, 1, 65]],
		["peckeye", "GOLD-1", true, 970, "small_loss", [0, 0, 1, 143]],
		["plate", "GOLD-1", true, 930, "small_win", [0, 0, 0, 242]],
	]
	for row in rows:
		var form: FormDef = pack.form(row[0])
		var box: TicketBox
		if row[2]:
			box = BoxGenerator.build(form.shaped(), row[1], _shaped_900(), true)
		else:
			box = BoxGenerator.build(form, row[1])
		var tag := "%s %s %s" % [row[0], row[1], "run (shapes)" if row[2] else "free play"]
		eq(box.size, row[3], tag + ": size")
		eq(box.type_id, row[4], tag + ": type")
		eq(box.counts, row[5], tag + ": prize counts")


## M9.7: the run's boxes are 200, 300 and 500 tickets (each 10% either way).
func test_run_box_sizes() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var cfg := RunConfig.standard()
	var want := [[180, 220, 2], [270, 330, 3], [450, 550, 5]]
	for layer in 3:
		var model := cfg.box_model(layer)
		var seen := {}
		for form in pack.forms:
			for n in 40:
				var box := BoxGenerator.build(form.shaped(), "SZ-%d" % n, model, true)
				seen[box.size] = true
				check(box.size >= want[layer][0] and box.size <= want[layer][1] and (box.size - want[layer][0]) % want[layer][2] == 0,
					"layer %d: size %d" % [layer + 1, box.size])
				eq(box.tickets.size(), box.size, "layer %d: ticket count" % [layer + 1])
		check(seen.size() > 10, "layer %d: the sizes vary (%d seen)" % [layer + 1, seen.size()])


## The same seed gives the same box with chance rounding on.
func test_chance_rounding_is_deterministic() -> void:
	var pack := core_pack()
	if pack == null:
		return
	for layer in 3:
		var model := RunConfig.standard().box_model(layer)
		for form in pack.forms:
			var f: FormDef = form.shaped()
			var a := BoxGenerator.build(f, "CR-det", model)
			var b := BoxGenerator.build(f, "CR-det", model)
			eq(var_to_str(a.tickets), var_to_str(b.tickets), "%s layer %d: same seed, same box" % [form.id, layer + 1])
			eq(a.counts, b.counts, "%s layer %d: same counts" % [form.id, layer + 1])


## The money a tier is owed becomes the chance of one more prize, so the average box
## pays what its type says. Against the same boxes without chance rounding (the same
## size, type and total), the mean return is the same within the noise: 4.5 standard
## errors of the per-box difference, and the rounding of the smallest prize.
func test_chance_rounding_keeps_the_average() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var n := 3000 if full else 500
	for layer in 3:
		var on := RunConfig.standard().box_model(layer)
		var off := _without_chance(on)
		for form in pack.forms:
			var f: FormDef = form.shaped()
			var low := float(f.tiers[f.tier_indices("low")[0]].prize)
			var sum := 0.0
			var sq := 0.0
			var tops := 0
			for i in n:
				var seed := "CA-%d" % i
				var a := BoxGenerator.build(f, seed, on, true)
				var b := BoxGenerator.build(f, seed, off, true)
				eq(a.size, b.size, "%s %s: same size" % [form.id, seed])
				eq(a.type_id, b.type_id, "%s %s: same type" % [form.id, seed])
				var d := float(a.prize_total() - b.prize_total()) / a.gross()
				sum += d
				sq += d * d
				for k in a.counts.size():
					if f.is_top(k):
						tops += a.counts[k]
			var mean := sum / n
			var se := sqrt(maxf(0.0, sq / n - mean * mean) / n)
			var slack := 4.5 * se + 0.5 * low / (on.size_min * f.price)
			check(absf(mean) <= slack, "%s layer %d: return differs by %.4f from the type's (allowed %.4f)" % [form.id, layer + 1, mean, slack])
			check(tops > 0, "%s layer %d: some box holds a top prize (%d in %d)" % [form.id, layer + 1, tops, n])


## No box holds more winners than tickets (more prizes than groups, by group), whatever
## the form, the box type and the size, in the run's three layers.
func test_chance_rounding_never_overfills_a_box() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var seeds := 3 if full else 1
	var boxes := 0
	for layer in 3:
		var base := RunConfig.standard().box_model(layer)
		for type in BoxModel.STANDARD_TYPES:
			for step in (range(base.size_steps) if full else [0, base.size_steps / 2, base.size_steps - 1]):
				var m := RunConfig.standard().box_model(layer)
				m.types = [{"id": type.id, "weight": 1.0, "min": type["min"], "max": type["max"]}]
				m.size_min = base.size_min + step * base.size_step
				m.size_steps = 1
				for form in pack.forms:
					var f: FormDef = form.shaped()
					var room := 1 if not f.wins_by_group() else f.digit_groups.size()
					for s in seeds:
						var box := BoxGenerator.build(f, "OF-%d" % s, m, true)
						boxes += 1
						var winners := 0
						for c in box.counts:
							winners += c
						if winners > box.size * room or box.size != m.size_min:
							check(false, "%s layer %d %s size %d: %d prizes" % [form.id, layer + 1, type.id, box.size, winners])
	note("overfill sweep: %d boxes" % boxes)
	# The full build (tickets printed) once as well.
	for layer in 3:
		for form in pack.forms:
			var box := BoxGenerator.build(form.shaped(), "OF-full", RunConfig.standard().box_model(layer))
			eq(box.tickets.size(), box.size, "%s layer %d: full build" % [form.id, layer + 1])


## G, 2026-11-07: the run's payout (RunConfig "payout") scales every run box's prize
## total; free play's model keeps 1.0, which changes nothing (the golden boxes of the web
## build are tested in test_generator_golden).
func test_payout_one_changes_nothing() -> void:
	var pack := core_pack()
	if pack == null:
		return
	eq(BoxModel.standard().payout, 1.0, "free play's model pays the web build's boxes")
	var cfg := RunConfig.standard()
	check(cfg.payout > 0.0 and cfg.payout < 1.0, "the run pays back less than its types (%.3f)" % cfg.payout)
	for layer in 3:
		eq(cfg.box_model(layer).payout, cfg.payout, "layer %d: the run's model carries the payout" % (layer + 1))
		eq(cfg.box_model(layer).with_sizes([180, 2, 21]).payout, cfg.payout, "layer %d: and so does a SEALed box's" % (layer + 1))
	eq(RunConfig.from_dict({"layers": RunConfig.STANDARD.layers}).payout, 1.0, "a config without one pays 1.0")
	for form in pack.forms:
		for n in 10:
			var seed := "PO-%d" % n
			var a := BoxGenerator.build(form, seed)
			var m := BoxModel.standard()
			m.payout = 1.0
			var b := BoxGenerator.build(form, seed, m)
			eq(var_to_str(b.tickets), var_to_str(a.tickets), "%s %s: payout 1.0, the same tickets" % [form.id, seed])
			eq(b.counts, a.counts, "%s %s: the same counts" % [form.id, seed])
			eq(a.net_type(), a.type_id, "%s %s: told by its own type" % [form.id, seed])
		# A run model at 1.0 deals the run's boxes of before.
		var run1 := cfg.box_model(0)
		run1.payout = 1.0
		var f: FormDef = form.shaped()
		var c := BoxGenerator.build(f, "PO-run", run1, true)
		eq(c.net_type(), c.type_id, "%s: a run box at 1.0 is told by its type" % form.id)


## The payout scales the prize total and nothing else: the same seed gives the same
## size and type. Without chance rounding the total is exact: the box at 1.0 times the
## payout, to the rounding of the smallest prize. With it (the run), the expected prize
## money scales: over every form's boxes the money paid against the same boxes at 1.0
## is the payout, loosely (the tops a box holds by chance move it).
func test_payout_scales_the_run_boxes() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var cfg := RunConfig.standard()
	var n := 1000 if full else 300
	for layer in 3:
		var on := cfg.box_model(layer)
		var one := cfg.box_model(layer)
		one.payout = 1.0
		var won := 0.0
		var base := 0.0
		for form in pack.forms:
			var f: FormDef = form.shaped()
			var low := int(f.tiers[f.tier_indices("low")[0]].prize)
			for i in n:
				var seed := "PS-%d" % i
				var a := BoxGenerator.build(f, seed, on, true)
				var b := BoxGenerator.build(f, seed, one, true)
				if a.size != b.size or a.type_id != b.type_id:
					check(false, "%s %s layer %d: the payout changed the size or type" % [form.id, seed, layer + 1])
				won += a.prize_total()
				base += b.prize_total()
				if i < 40:
					var x := BoxGenerator.build(f, seed, _without_chance(on), true)
					var y := BoxGenerator.build(f, seed, _without_chance(one), true)
					if absf(x.prize_total() - cfg.payout * y.prize_total()) > low:
						check(false, "%s %s layer %d: without chance the total is $%d, against $%d x %.3f" % [form.id, seed, layer + 1, x.prize_total(), y.prize_total(), cfg.payout])
		var ratio := won / base
		note("layer %d: run boxes pay %.4f of the same boxes at payout 1.0 (payout %.3f)" % [layer + 1, ratio, cfg.payout])
		check(absf(ratio - cfg.payout) < 0.04, "layer %d: the prize money scales by the payout (%.4f against %.3f)" % [layer + 1, ratio, cfg.payout])


## The type a box is told by (TicketBox.net_type): the range that holds its net after the
## payout, so the luck perks (and the dev panel) do not lie in the run. Free play: its type.
func test_run_boxes_are_told_by_their_net() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var std := BoxModel.standard()
	eq(str(std.type_for_net(0.0).id), "break_even", "0 is break even")
	eq(str(std.type_for_net(-0.07).id), "break_even", "a gap: the nearest range")
	eq(str(std.type_for_net(-0.11).id), "small_loss", "a gap: the nearest range, the other way")
	eq(str(std.type_for_net(-0.9).id), "big_loss", "under every range: the biggest loss")
	eq(str(std.type_for_net(3.0).id), "big_win", "over every range: the biggest win")
	var cfg := RunConfig.standard()
	var told := {}
	for layer in 3:
		var on := cfg.box_model(layer)
		var exact := _without_chance(on)
		for form in pack.forms:
			var f: FormDef = form.shaped()
			for i in 60:
				var seed := "NT-%d" % i
				var box := BoxGenerator.build(f, seed, exact, true)
				var net := float(box.net()) / box.gross()
				var tol := float(f.tiers[f.tier_indices("low")[0]].prize) / box.gross()
				var id := box.net_type()
				if not [str(on.type_for_net(net).id), str(on.type_for_net(net - tol).id), str(on.type_for_net(net + tol).id)].has(id):
					check(false, "%s %s layer %d: net %.3f told as %s" % [form.id, seed, layer + 1, net, id])
				eq(BoxGenerator.build(f, seed, on, true).net_type(), id, "%s %s: chance rounding tells the same" % [form.id, seed])
				var key := "%s>%s" % [box.type_id, id]
				told[key] = told.get(key, 0) + 1
				# While the payout keeps a break-even box under the even range, it is told so.
				if box.type_id == "break_even" and cfg.payout * 1.06 < 0.94:
					check(float(on.type_by_id(id)["max"]) < 0.0, "%s %s layer %d: a box drawn break even loses %.0f%% in the run, told %s" % [form.id, seed, layer + 1, -100 * net, id])
					check(MachineLogic.new([f], seed, on, true).losing(box), "and is a losing box to the luck perks")
	var keys := told.keys()
	keys.sort()
	var parts := PackedStringArray()
	for k in keys:
		parts.append("%s %d" % [k, told[k]])
	note("drawn type > told type, run boxes: " + ", ".join(parts))
	# Free play: a box is told by the type it was drawn.
	for form in pack.forms:
		for i in 30:
			var box := BoxGenerator.build(form, "NF-%d" % i, null, true)
			eq(box.net_type(), box.type_id, "%s NF-%d: free play tells its type" % [form.id, i])
