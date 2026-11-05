extends "res://tests/test_case.gd"
## Ticket faces are built from data: every ticket prints its own serial, the
## inside shows its own digits, and wins replace the right part.


func _texts(cmds: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for c in cmds:
		if c.k == "text":
			out.append(c.text)
	return out


func _ticket(pack: PackDef, form_id: String, want_win: bool) -> Dictionary:
	# Some boxes hold no top prize at all, so try seeds until one does.
	for n in 50:
		var box := BoxGenerator.build(pack.form(form_id), "ART-%d" % n)
		for t in box.tickets:
			if (t.tier >= 0) == want_win and (not want_win or pack.form(form_id).is_top(t.tier)):
				return t
	return {}


func test_front_prints_serial_and_form_data() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var f := pack.form("catch")
	var texts := _texts(TicketArt.front(f, "Q123456"))
	check(texts.has("SERIAL NO. Q123456"), "serial printed")
	check(texts.has("BIG CATCH"), "title printed")
	check(texts.has("©Ben Kraptu apt.   FORM BC-1S"), "form code printed")
	check(texts.has("PAYABLE IN EGG MONEY."), "exact copy kept")
	check(texts.has("6 WIN") and texts.has("75 WIN"), "printed counts from tiers")
	check(texts.has("$500") and texts.has("$25"), "tier prizes")
	check(_texts(TicketArt.front(f, "")).has("SERIAL NO. "), "box art has an empty serial")


func test_inside_loser_shows_its_digits() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var f := pack.form("catch")
	var t := _ticket(pack, "catch", false)
	var texts := _texts(TicketArt.interior(f, t))
	for gi in t.groups.size():
		for k in t.groups[gi].size():
			var d: int = t.groups[gi][k]
			check(texts.has(str(d)) and texts.has(TicketArt.WORDS[d]), "digit %d with caption" % d)
	check(not texts.has("$0"), "no prize on a loser")


func test_inside_winner_whole() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var f := pack.form("catch")
	var t := _ticket(pack, "catch", true)
	if not check(not t.is_empty(), "found a top winner"):
		return
	var cmds := TicketArt.interior(f, t)
	var texts := _texts(cmds)
	check(texts.has("$%d" % t.prize), "prize printed")
	check(texts.has("VERIFY " + t.verify), "verify code on a top prize")
	check(not texts.has("ZERO") and not texts.has("NINE"), "no loser digits on a whole win")
	var symbol := false
	for c in cmds:
		if c.k == "tex" and c.path == f.tiers[t.tier].symbol_large:
			symbol = true
	check(symbol, "winning tier's large symbol drawn")


func test_inside_winner_one_window() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var f := pack.form("plate")
	var box := BoxGenerator.build(f, "ART-2")
	var t: Dictionary = {}
	for x in box.tickets:
		if x.tier >= 0:
			t = x
			break
	var cmds := TicketArt.interior(f, t)
	var texts := _texts(cmds)
	check(texts.has("$%d" % t.prize), "prize in the winning window")
	# The other four windows still print their digit groups.
	var digits := 0
	for c in cmds:
		if c.k == "text" and c.text.length() == 1 and c.text.is_valid_int() and c.size > 60:
			digits += 1
	var expected := 0
	for gi in t.groups.size():
		if gi != t.win_group:
			expected += t.groups[gi].size()
	eq(digits, expected, "digits in the non-winning windows")
	# The win strip sits inside the winning window's slot.
	var slot: Array = f.layout.interior.slots[t.win_group].rect
	for c in cmds:
		if c.k == "text" and c.text == "$%d" % t.prize:
			check(c.pos.y > slot[1] and c.pos.y < slot[1] + slot[3], "prize inside window %d" % t.win_group)


func test_conditions_and_tier_colours() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var f := pack.form("spur")
	var lose := _ticket(pack, "spur", false)
	var dividers := 0
	for c in TicketArt.interior(f, lose):
		if c.k == "stroke" and c.color == Color("#b9b2a2"):
			dividers += 1
	eq(dividers, 2, "jar loser: two column dividers ('if': lose)")
	var win := _ticket(pack, "spur", true)
	for c in TicketArt.interior(f, win):
		check(not (c.k == "stroke" and c.color == Color("#b9b2a2")), "no dividers on a win")
	var tiles := []
	for c in TicketArt.front(f, "A100000"):
		if c.k == "poly" and f.colors.tiles.has(c.color):
			if not tiles.has(c.color):
				tiles.append(c.color)
	eq(tiles.size(), 4, "each tier cell uses its own tile colour")


func test_covers_number_their_flaps() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var f := pack.form("plate")
	for i in 5:
		check(_texts(TicketArt.cover(f, i).cmds).has(str(i + 1)), "tab %d numbered" % (i + 1))
	eq(TicketArt.cover(f, 0).canvas, Vector2(400, 111), "template canvas")


func test_tear_slice_audio() -> void:
	var sfx = (Engine.get_main_loop() as SceneTree).root.get_node("Sfx")
	var src := AudioStreamWAV.new()
	src.format = AudioStreamWAV.FORMAT_16_BITS
	src.mix_rate = 1000
	var bytes := PackedByteArray()
	bytes.resize(2000)  # 1 s of constant level
	for i in 1000:
		bytes.encode_s16(i * 2, 10000)
	src.data = bytes
	var s: AudioStreamWAV = sfx._slice(src, "test", 0.2, 0.5)
	eq(s.data.size(), (515 - 200) * 2, "slice runs to end + 15 ms fade")
	eq(s.data.decode_s16(0), 10000, "full level at the start")
	eq(s.data.decode_s16((499 - 200) * 2), 10000, "full level up to the end mark")
	check(s.data.decode_s16((514 - 200) * 2) < 1000, "faded out after 15 ms")
