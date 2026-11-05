extends "res://tests/test_case.gd"
## Chinese and English: every player string in the code has both, the format codes
## agree, and the bundled CJK fonts draw every Chinese character in the table.

const CSV := "res://locale/ui.csv"
## Player text set from tables rather than a literal call.
const EXTRA_KEYS := ["DINER", "BAR", "BINGO", "MUTED", "SOUND", "HELD", "OPENED", "NET"]
const PATTERNS := [
	"\\btr\\(\"([^\"]+)\"",
	"\\bset_status\\(\"([^\"]+)\"",
	"\\bsay\\(\"([^\"]+)\"",
	"\\b_caption\\(\"([^\"]+)\"",
	"\\b_toggle_key\\(\"([^\"]+)\"",
	"LcdStyle\\.(?:label|key|chrome|toggle_key)\\(\"([^\"]+)\"",
]


func _table() -> Dictionary:
	var rows := {}
	var f := FileAccess.open(CSV, FileAccess.READ)
	var head := f.get_csv_line()
	check(head == PackedStringArray(["keys", "en", "zh"]), "columns keys, en, zh")
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() >= 3:
			rows[r[0]] = {"en": r[1], "zh": r[2]}
	return rows


func _used_keys() -> Array:
	var found := {}
	var regs := []
	for p in PATTERNS:
		regs.append(RegEx.create_from_string(p))
	var dirs := ["res://src"]
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(d):
			if sub != "dev":   # the developer panel is Chinese-only on purpose
				dirs.append(d.path_join(sub))
		for file in DirAccess.get_files_at(d):
			if not file.ends_with(".gd"):
				continue
			var text := FileAccess.get_file_as_string(d.path_join(file))
			for re: RegEx in regs:
				for m in re.search_all(text):
					var k := m.get_string(1)
					if RegEx.create_from_string("[A-Z]").search(k) != null:
						found[k] = file
	for k in EXTRA_KEYS:
		found[k] = "tables"
	return found.keys()


func test_every_player_string_has_both_languages() -> void:
	var rows := _table()
	var spec := RegEx.create_from_string("%[0-9.]*[sdf]")
	for k in _used_keys():
		if not check(rows.has(k), "missing from locale/ui.csv: \"%s\"" % k):
			continue
		var zh: String = rows[k].zh
		check(zh.strip_edges() != "", "no Chinese for \"%s\"" % k)
		var a := []
		for m in spec.search_all(rows[k].en):
			a.append(m.get_string())
		var b := []
		for m in spec.search_all(zh):
			b.append(m.get_string())
		eq(b, a, "format codes of \"%s\"" % k)
	var used := _used_keys()
	for k in rows:
		check(used.has(k), "locale/ui.csv has a row nothing uses: \"%s\"" % k)


func test_translations_load() -> void:
	var was := TranslationServer.get_locale()
	TranslationServer.set_locale("zh")
	eq(str(TranslationServer.translate("RESUME")), "继续", "zh")
	eq(str(TranslationServer.translate("WINNER $%d")) % 25, "中奖 $25", "zh with an argument")
	TranslationServer.set_locale("en")
	eq(str(TranslationServer.translate("RESUME")), "RESUME", "en")
	TranslationServer.set_locale(was)
	eq(Lang.resolve("", "zh"), "zh", "follows a Chinese system")
	eq(Lang.resolve("", "de"), "en", "anything else: English")
	eq(Lang.resolve("en", "zh"), "en", "a choice beats the system")
	eq(Lang.resolve("fr", "zh"), "zh", "an unsupported choice follows the system")


func test_cjk_fonts_cover_the_table() -> void:
	var rows := _table()
	for path in [Lang.CJK_PIXEL, Lang.CJK_PIXEL_LCD, Lang.CJK_PIXEL_COND, Lang.CJK_HAND]:
		var f: Font = load(path)
		if not check(f != null, "font loads: " + path):
			continue
		var missing := {}
		var texts := []
		for k in rows:
			texts.append(rows[k].zh)
		texts.append_array(Lang.NAMES.values())   # the language keys on the menu
		for t in texts:
			for c in t:
				if c.unicode_at(0) > 127 and not f.has_char(c.unicode_at(0)):
					missing[c] = true
		check(missing.is_empty(), "%s lacks %s (run tools/subset_cjk_fonts.py)" % [path.get_file(), "".join(missing.keys())])
	var vt: Font = load("res://assets/fonts/vt323-latin-400-normal.woff2")
	check(vt.fallbacks.has(load(Lang.CJK_PIXEL_LCD)), "the LCD font falls back to the pixel Chinese cut to its capitals")
	var cond: Font = load("res://assets/fonts/oswald-latin-600-normal.woff2")
	check(cond.fallbacks.has(load(Lang.CJK_PIXEL_COND)), "the chrome keys' font falls back to the cut for its capitals")
	var menu: Font = Lang.menu_font(vt)
	check(menu.fallbacks.size() == 1 and menu.fallbacks[0] == load(Lang.CJK_PIXEL), "the menu's variation falls back to the larger pixel Chinese")
	var bold: Font = Lang.menu_font(vt, true)
	check(bold.fallbacks[0] is FontVariation and bold.fallbacks[0].variation_embolden > 0.0, "bold menu Chinese is emboldened")
	var hand: Font = load("res://assets/fonts/patrick-hand-latin-400-normal.woff2")
	check(hand.fallbacks.has(load(Lang.CJK_HAND)), "the notepad hand falls back to the CJK hand")
