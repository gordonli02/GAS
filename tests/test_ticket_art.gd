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


## The old way, still in the format: one prize a ticket, shown in one window.
func test_inside_winner_one_window() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var f: FormDef = pack.form("plate").scaled(2)
	f.win_display = "one_group"
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
		if c.k == "text" and c.text.length() == 1 and c.text.is_valid_int() and c.size == float(f.layout.interior.digits.digit.size):
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


## Every window (Hot Plate) or column (Lucky Spur) shows its own result: its prize where
## it won, its digits where it did not.
func test_inside_wins_by_group() -> void:
	var pack := core_pack()
	if pack == null:
		return
	for id in ["plate", "spur"]:
		var f := pack.form(id)
		# A ticket holding two prizes, one of them a top prize if the seeds give one.
		var t: Dictionary = {}
		for n in 400:
			for x in BoxGenerator.build(f, "ART-%d" % n).tickets:
				if x.wins.count(-1) <= x.wins.size() - 2 and (t.is_empty() or (x.verify != "" and t.verify == "")):
					t = x
			if not t.is_empty() and t.verify != "":
				break
		if not check(not t.is_empty(), id + ": found a ticket with two prizes"):
			continue
		var cmds := TicketArt.interior(f, t)
		var digits := 0
		var digit_size: float = f.layout.interior.digits.digit.size
		for c in cmds:
			if c.k == "text" and c.text.length() == 1 and c.text.is_valid_int() and c.size == digit_size:
				digits += 1
		var expected := 0
		var top := false
		for gi in t.wins.size():
			var slot := Rect2(f.layout.interior.slots[gi].rect[0], f.layout.interior.slots[gi].rect[1],
				f.layout.interior.slots[gi].rect[2], f.layout.interior.slots[gi].rect[3])
			var tier: int = t.wins[gi]
			var prize_here := false
			var symbol_here := false
			for c in cmds:
				if c.k == "text" and c.text.begins_with("$") and slot.has_point(c.pos):
					prize_here = true
					if tier >= 0:
						eq(c.text, "$%d" % int(f.tiers[tier].prize), "%s group %d: its own prize" % [id, gi])
				if c.k == "tex" and tier >= 0 and slot.has_point(c.rect.get_center()) \
						and (c.path == f.tiers[tier].symbol or c.path == f.tiers[tier].symbol_large):
					symbol_here = true
			eq(prize_here, tier >= 0, "%s group %d: a prize only where it won" % [id, gi])
			eq(symbol_here, tier >= 0, "%s group %d: its tier's symbol" % [id, gi])
			if tier < 0:
				expected += t.groups[gi].size()
			top = top or f.is_top(tier)
		eq(digits, expected, id + ": digits in the groups that did not win")
		eq(t.verify != "", top, id + ": a verify code with a top prize")


func test_conditions_and_tier_colours() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var f := pack.form("spur")
	# The jar's columns win one by one, so their dividers are always printed.
	for want_win in [false, true]:
		var dividers := 0
		for c in TicketArt.interior(f, _ticket(pack, "spur", want_win)):
			if c.k == "stroke" and c.color == Color("#b9b2a2"):
				dividers += 1
		eq(dividers, 2, "jar: two column dividers")
	# 'if': verify prints only on a top prize (Big Catch's winner).
	var plain := _ticket(pack, "catch", false)
	check(not "".join(_texts(TicketArt.interior(pack.form("catch"), plain))).contains("VERIFY"), "no verify line on a loser")
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
	eq(TicketArt.cover(f, 0).canvas, Vector2(480, 90), "template canvas")


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


## each_tier with "tiers" draws those tiers only, in that order, each in the next cell.
func test_each_tier_can_pick_tiers() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var f := pack.form("catch").scaled(1)
	var layout: Dictionary = f.layout.duplicate(true)
	layout.front = [{"type": "each_tier", "tiers": [3, 0], "origin": [100, 0], "columns": 2, "step": [50, 0], "layers": [
		{"type": "text", "text": "${tier_prize}", "pos": [0, 20], "font": "slab", "size": 10, "fill": "tile"},
		{"type": "rect", "rect": [0, 0, 40, 20], "fill": "tile", "radius": 5}]}]
	var g := FormDef.new()
	for k in ["pack_id", "id", "name", "title", "code", "colors", "digit_groups", "win_display", "tear_clips", "source_dir", "tiers", "price"]:
		g.set(k, f.get(k))
	g.layout = layout
	var cmds := TicketArt.front(g, "")
	var texts := cmds.filter(func(c): return c.k == "text")
	eq(texts.map(func(c): return c.text), ["$25", "$500"], "the picked tiers, in the order given")
	eq(texts.map(func(c): return c.pos.x), [100.0, 150.0], "each in the next cell")
	eq(texts[0].color, f.colors.tiles[3], "with its own tile colour")
	var polys := cmds.filter(func(c): return c.k == "poly")
	eq(polys.size(), 2, "one rect each")
	var box := Rect2(polys[0].pts[0], Vector2.ZERO)
	for p in polys[0].pts:
		box = box.expand(p)
	check(box.is_equal_approx(Rect2(100, 0, 40, 20)), "a rounded rect keeps its bounds")
	check(polys[0].pts.size() > 4 and not Array(polys[0].pts).has(Vector2(100, 0)), "and loses its corners")


## The M8.6 forms print what the form says: prizes follow the stake, every tier is shown.
func test_new_fronts_follow_the_form() -> void:
	var pack := core_pack()
	if pack == null:
		return
	for id in ["order", "kabawk", "flock", "nugget", "peckeye"]:
		var f := pack.form(id)
		var texts := _texts(TicketArt.front(f, "Q123456"))
		check(texts.has("SERIAL NO. Q123456"), id + ": serial printed")
		check(texts.has("$1"), id + ": price printed")
		var joined := " ".join(texts)
		check(joined.contains("$500") and joined.contains("$100") and joined.contains("$25"), id + ": every prize printed")
		var five := " ".join(_texts(TicketArt.front(f.scaled(5), "")))
		check(five.contains("$2500") and five.contains("$125") and five.contains("$5") and not five.contains("$100"),
			id + ": price and prizes at five times the stake")
		var shown := {}
		for c in TicketArt.front(f, ""):
			if c.k == "tex":
				shown[c.path] = true
		for t in f.tiers:
			check(shown.has(t.symbol) or shown.has(t.symbol_large), "%s: %s is on the front" % [id, t.key])
