class_name BoxGenerator
extends RefCounted
## Builds a closed box of tickets from a form and a seed.
## The seed picks a box type first, then prizes are composed to land on it.
## Pure logic: no scene, node or file access, so tests and future modes can call it.

const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"


## Seed string as used by the web build: "<seed>|<form id>".
## prizes_only: skip what is printed on each ticket (serial, digits, marks); the box,
## its counts and the order of the prizes are the same. For simulations.
static func build(form: FormDef, seed_text: String, model: BoxModel = null, prizes_only := false) -> TicketBox:
	if model == null:
		model = BoxModel.standard()
	var r := SeededRng.new(seed_text + "|" + form.id)
	var box := TicketBox.new()
	box.form = form
	box.seed = seed_text
	_roll(form, model, r, box)

	var slots: Array = []
	for i in box.counts.size():
		for n in box.counts[i]:
			slots.append(i)
	assert(slots.size() <= box.size, "more winners than tickets")
	while slots.size() < box.size:
		slots.append(-1)
	r.shuffle(slots)

	if prizes_only:
		var plain: Array = []
		plain.resize(box.size)
		for i in box.size:
			var tier: int = slots[i]
			plain[i] = {"no": i + 1, "tier": tier, "prize": 0 if tier < 0 else int(form.tiers[tier].prize)}
		box.tickets = plain
		return box

	var used := {}
	var tickets: Array = []
	tickets.resize(box.size)
	var groups := Array(form.digit_groups)
	for i in box.size:
		var tier: int = slots[i]
		var lens: Array = r.shuffle(groups.duplicate())
		# Draw order matches the web build: win group, serial, groups, marks, verify.
		var win_group := r.next_int(lens.size())
		var serial := _new_serial(r, used)
		var rows: Array = []
		for n in lens:
			rows.append(_loser_row(r, n))
		var marks: Array = []
		for n in lens:
			var m := PackedInt32Array()
			m.resize(n)
			for k in n:
				m[k] = r.next_int(10)
			marks.append(m)
		var verify := str(100000 + r.next_int(900000)) if form.is_top(tier) else ""
		tickets[i] = {
			"no": i + 1,
			"tier": tier,
			"prize": 0 if tier < 0 else int(form.tiers[tier].prize),
			"win_group": win_group,
			"serial": serial,
			"groups": rows,
			"marks": marks,
			"verify": verify,
		}
	box.tickets = tickets
	return box


static func _roll(form: FormDef, model: BoxModel, r: SeededRng, box: TicketBox) -> void:
	box.size = model.size_min + r.next_int(model.size_steps) * model.size_step
	var gross := box.size * form.price
	var roll := r.next_float()
	var type: Dictionary = model.types[model.types.size() - 1]
	for k in model.types:
		roll -= k.weight
		if roll < 0:
			type = k
			break
	box.type_id = type.id

	var top_ids := form.tier_indices("top")
	var mid_id: int = form.tier_indices("mid")[0]
	var low_id: int = form.tier_indices("low")[0]
	var top_prize: int = form.tiers[top_ids[0]].prize
	var mid_prize: int = form.tiers[mid_id].prize
	var low_prize: int = form.tiers[low_id].prize

	var share: float = 1.0 + type["min"] + (type["max"] - type["min"]) * r.next_float()
	var total := int(_js_round(gross * share / low_prize)) * low_prize
	var tops := int(floor(total * (model.top_share_min + model.top_share_span * r.next_float()) / top_prize))
	var counts := []
	counts.resize(form.tiers.size())
	counts.fill(0)
	for i in tops:
		counts[top_ids[r.next_int(top_ids.size())]] += 1
	var mids := int(floor((total - tops * top_prize) * (model.mid_share_min + model.mid_share_span * r.next_float()) / mid_prize))
	counts[mid_id] = mids
	counts[low_id] = (total - tops * top_prize - mids * mid_prize) / low_prize
	box.counts = counts


## Math.round: halves go up.
static func _js_round(v: float) -> float:
	return floor(v + 0.5)


static func _new_serial(r: SeededRng, used: Dictionary) -> String:
	while true:
		var s := LETTERS[r.next_int(26)] + str(100000 + r.next_int(900000))
		if not used.has(s):
			used[s] = true
			return s
	return ""


## A digit group that is never all one digit.
static func _loser_row(r: SeededRng, n: int) -> PackedInt32Array:
	var d := PackedInt32Array()
	d.resize(n)
	while true:
		var first := -1
		var mixed := false
		for k in n:
			d[k] = r.next_int(10)
			if k == 0:
				first = d[k]
			elif d[k] != first:
				mixed = true
		if mixed:
			return d
	return d
