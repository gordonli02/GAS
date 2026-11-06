extends "res://tests/test_case.gd"
## Built-in pack loads through the same path as user packs; bad packs are rejected.

const TMP := "user://test_packs"


func test_core_pack_loads() -> void:
	var pack := core_pack()
	if pack == null:
		return
	eq(pack.id, "core", "pack id")
	eq(pack.forms.map(func(f): return f.id), ["catch", "plate", "spur"], "form ids")
	var plate := pack.form("plate")
	eq(plate.name, "Hot Plate", "plate name")
	eq(Array(plate.digit_groups), [4, 3, 4, 3, 4], "plate digit groups")
	eq(plate.win_display, "each_group", "plate wins by group (G, M8.5)")
	eq(pack.form("spur").win_display, "each_group", "spur wins by group")
	eq(pack.form("catch").win_display, "whole", "catch wins as a whole ticket")
	eq(pack.form("spur").layout.flaps.size(), 1, "spur flaps")
	eq(pack.form("plate").layout.flaps.size(), 5, "plate flaps")
	check(pack.form("catch").tiers[0].symbol.ends_with("art/walleye.png"), "walleye symbol path")
	check(pack.form("catch").tiers[0].symbol_large.ends_with("art/walleye_large.png"), "walleye large symbol path")
	eq(pack.form("catch").colors.edge, Color.html("#0033cc"), "catch edge colour")
	eq(pack.tear_clips.size(), 8, "tear clips")
	var marks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://packs/core/audio/tear_marks.json"))
	for c in pack.tear_clips:
		eq(c.marks.size(), marks[c.path.get_file()].size(), c.path.get_file() + " marks")


func test_platform_lists_core_pack() -> void:
	var platform = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Platform")
	if not check(platform != null, "Platform autoload missing"):
		return
	check(platform.pack_dirs().has("res://packs/core"), "core pack dir listed")
	eq(platform.backend_name(), "offline", "backend")


func test_rejects_scripts_and_resources() -> void:
	for bad in ["evil.gd", "scene.tscn", "thing.tres", "lib.dll", "x.cs"]:
		var dir := _make_pack("script_" + bad.get_extension(), {})
		_write(dir.path_join("art/" + bad), "extends Node")
		var res := PackLoader.load_dir(dir)
		check(not res.ok(), bad + " must be rejected")
		check(res.pack == null, bad + ": no pack object on failure")
		check(" ".join(res.errors).contains("not allowed"), bad + ": error names the file type")


func test_rejects_bad_fields() -> void:
	var cases := {
		"price": {"price": 0},
		"color": {"colors": {"edge": "blue", "head": "#fff", "ink": "#000", "tiles": ["#111", "#222", "#333", "#444"]}},
		"role": {"tiers": [_tier("a", 500, "top"), _tier("b", 100, "mid"), _tier("c", 25, "low"), _tier("d", 25, "jackpot")]},
		"no_low": {"tiers": [_tier("a", 500, "top"), _tier("b", 100, "mid"), _tier("c", 100, "mid")]},
		"multiple": {"tiers": [_tier("a", 500, "top"), _tier("b", 110, "mid"), _tier("c", 25, "low")]},
		"escape": {"tiers": [_tier("a", 500, "top", "../../evil.png"), _tier("b", 100, "mid"), _tier("c", 25, "low")]},
		"missing_symbol": {"tiers": [_tier("a", 500, "top", "art/none.png"), _tier("b", 100, "mid"), _tier("c", 25, "low")]},
		"groups": {"digit_groups": [4, 1]},
		"groups_vs_layout": {"digit_groups": [4, 4]},
		"layout_ref": {"layout": "core:spinner"},
		"layout_escape": {"layout": "../layouts/single.json"},
		"no_symbol": {"tiers": [_tier("a", 500, "top", "-"), _tier("b", 100, "mid"), _tier("c", 25, "low")]},
		"id": {"id": "Bad Id"},
	}
	for k in cases:
		var res := PackLoader.load_dir(_make_pack("bad_" + k, cases[k]))
		check(not res.ok(), "case '%s' must be rejected" % k)


func test_accepts_minimal_valid_pack() -> void:
	var dir := _make_pack("good", {})
	var res := PackLoader.load_dir(dir)
	if check(res.ok(), "valid pack rejected: " + "; ".join(res.errors)):
		var box := BoxGenerator.build(res.pack.forms[0], "S-1")
		check(box.tickets.size() == box.size, "generator runs on a user form")


func _tier(key: String, prize: int, role: String, symbol := "") -> Dictionary:
	var t := {"key": key, "label": key.capitalize(), "prize": prize, "printed_count": 3, "role": role, "symbol": "art/s.png"}
	if symbol == "-":
		t.erase("symbol")
	elif symbol != "":
		t.symbol = symbol
	return t


func _make_pack(name: String, form_overrides: Dictionary) -> String:
	var dir := ProjectSettings.globalize_path(TMP.path_join(name))
	if DirAccess.dir_exists_absolute(dir):
		_rm(dir)
	DirAccess.make_dir_recursive_absolute(dir.path_join("art"))
	var form := {
		"id": "test", "name": "Test Form", "title": ["TEST"], "code": "TF-1", "price": 1,
		"colors": {"edge": "#123456", "head": "#abcdef", "ink": "#000000", "tiles": ["#111111", "#222222", "#333333", "#444444"]},
		"tiers": [_tier("a", 500, "top"), _tier("b", 500, "top"), _tier("c", 100, "mid"), _tier("d", 25, "low")],
		"digit_groups": [4, 4, 3], "win_display": "whole", "layout": "core:single",
	}
	form.merge(form_overrides, true)
	_write(dir.path_join("pack.json"), JSON.stringify({"format": 1, "id": "test_" + name.to_lower().replace(".", "_"), "version": "0.1", "name": "Test", "forms": ["form.json"]}))
	_write(dir.path_join("form.json"), JSON.stringify(form))
	Image.create(8, 8, false, Image.FORMAT_RGBA8).save_png(dir.path_join("art/s.png"))
	return dir


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _rm(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_rm(dir.path_join(d))
	DirAccess.remove_absolute(dir)
