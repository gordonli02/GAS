class_name BoxGenerator
extends RefCounted
## Builds a closed box of tickets from a form and a seed.
## The seed picks a box type first, then prizes are composed to land on it.
## A form that wins as a whole ticket (or in one group) is dealt exactly as the web build
## did. A form that wins by group gets the same box (type, size, prize counts), and each
## prize then lands on one group of one ticket, so a ticket can hold several.
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

	var groups := Array(form.digit_groups)
	var each := form.wins_by_group()
	var slots: Array = []    # the tier each ticket wins, or -1
	var cells := {}          # by group: ticket index * groups + group -> tier
	if each:
		cells = _deal_cells(box, groups.size(), model, r)
	else:
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
			plain[i] = _result(form, i, slots, cells, groups.size())
		box.tickets = plain
		return box

	var used := {}
	var tickets: Array = []
	tickets.resize(box.size)
	for i in box.size:
		var t := _result(form, i, slots, cells, groups.size())
		var lens: Array = r.shuffle(groups.duplicate())
		# Draw order matches the web build: win group, serial, groups, marks, verify.
		# (By group there is no one winning group to draw.)
		var win_group := -1 if each else r.next_int(lens.size())
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
		var top := false
		for tier in t.get("wins", [t.tier]):
			top = top or form.is_top(tier)
		t.win_group = win_group
		t.serial = serial
		t.groups = rows
		t.marks = marks
		t.verify = str(100000 + r.next_int(900000)) if top else ""
		tickets[i] = t
	box.tickets = tickets
	return box


## By group: every prize of the box lands on a free group of a ticket. The prizes are
## dealt in a shuffled order; each goes anywhere in the box, or, with the model's
## stack_share, onto a ticket that already holds one (so some tickets hold several).
## Returns ticket index * groups + group -> tier.
static func _deal_cells(box: TicketBox, groups: int, model: BoxModel, r: SeededRng) -> Dictionary:
	var prizes: Array = []
	for tier in box.counts.size():
		for n in box.counts[tier]:
			prizes.append(tier)
	var total := box.size * groups
	assert(prizes.size() <= total, "more prizes than groups")
	r.shuffle(prizes)
	var cells := {}
	var holders: Array = []   # tickets holding a prize and a free group
	for tier in prizes:
		var c := -1
		if not holders.is_empty() and r.next_float() < model.stack_share:
			var at := r.next_int(holders.size())
			var free: Array = []
			for k in groups:
				if not cells.has(holders[at] * groups + k):
					free.append(k)
			c = holders[at] * groups + free[r.next_int(free.size())]
			if free.size() == 1:
				holders.remove_at(at)
		else:
			c = r.next_int(total)
			while cells.has(c):
				c = r.next_int(total)
			var ticket := c / groups
			var held := 0
			for k in groups:
				if cells.has(ticket * groups + k):
					held += 1
			if held == 0 and groups > 1:
				holders.append(ticket)
			elif held == groups - 1:
				holders.erase(ticket)
		cells[c] = tier
	return cells


## What ticket `i` wins: {no, tier, prize}, plus wins (the tier per group) by group.
## By group, prize is the sum and tier the tier of the biggest prize (the first of equals).
static func _result(form: FormDef, i: int, slots: Array, cells: Dictionary, groups: int) -> Dictionary:
	if not form.wins_by_group():
		var tier: int = slots[i]
		return {"no": i + 1, "tier": tier, "prize": 0 if tier < 0 else int(form.tiers[tier].prize)}
	var wins := []
	var best := -1
	var prize := 0
	for k in groups:
		var tier: int = cells.get(i * groups + k, -1)
		wins.append(tier)
		if tier < 0:
			continue
		var p := int(form.tiers[tier].prize)
		prize += p
		if best < 0 or p > int(form.tiers[best].prize):
			best = tier
	return {"no": i + 1, "tier": best, "prize": prize, "wins": wins}


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
