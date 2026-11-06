extends "res://tests/test_case.gd"
## The Godot generator must reproduce the web build bit for bit.
## Golden data: tools/make_generator_golden.js runs the web code under Node.
## Forms that win by group (G, M8.5: Hot Plate, Lucky Spur) keep the web build's box
## (type, size, prize counts); their tickets are dealt differently, so only the box is
## compared. The same forms dealt the old way still match ticket for ticket.

const GOLDEN := "res://tests/fixtures/generator_golden.json"


func _golden() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))


static func ticket_line(t: Dictionary) -> String:
	var groups := PackedStringArray()
	for g in t.groups:
		groups.append("".join(Array(g).map(func(x): return str(x))))
	var marks := PackedStringArray()
	for m in t.marks:
		marks.append("".join(Array(m).map(func(x): return str(x))))
	return ",".join([t.no, t.tier, t.prize, t.win_group, t.serial, ".".join(groups), ".".join(marks), t.verify])


func test_imul_matches_js() -> void:
	eq(SeededRng.imul(0xffffffff, 5), 4294967291, "imul(-1, 5)")
	eq(SeededRng.imul(123456789, 987654321), 4227814277, "imul large")
	eq(SeededRng.imul(-1640531535, 3432918353), 4147092993, "imul negative input")


func test_rng_sequence_matches_js() -> void:
	var g := _golden()
	var r := SeededRng.new(g.rng_seed)
	for i in g.rng.size():
		var v := int(r.next_float() * 4294967296.0)
		if not eq(v, int(g.rng[i]), "draw %d" % i):
			return


func test_boxes_match_js() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var zh_to_id := {}
	for t in BoxModel.STANDARD_TYPES:
		zh_to_id[t.label.zh] = t.id
	for b in _golden().boxes:
		var tag := "%s / %s" % [b.form, b.seed]
		var box := BoxGenerator.build(pack.form(b.form), b.seed)
		eq(box.type_id, zh_to_id[b.heat], tag + " type")
		eq(box.size, int(b.size), tag + " size")
		eq(box.counts, Array(b.counts).map(func(x): return int(x)), tag + " counts")
		if box.form.wins_by_group():
			# Dealt as the web build dealt it (one prize a ticket), it is the web's box still.
			var old: FormDef = box.form.scaled(2)
			old.win_display = "one_group"
			box = BoxGenerator.build(old, b.seed)
			for t in box.tickets:
				t.prize /= 2
		var lines := PackedStringArray()
		for t in box.tickets:
			lines.append(ticket_line(t))
		for i in b.first.size():
			eq(lines[i], b.first[i], tag + " ticket %d" % (i + 1))
		eq("\n".join(lines).sha256_text(), b.sha256, tag + " all tickets (sha256)")
