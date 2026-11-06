extends SceneTree
## Renders the core forms' ticket art with TicketPainter at canvas scale 1, using the
## same sample ticket as tools/export_web_art.js, for side-by-side checks against
## tests/fixtures/web_ref. Needs a display (not --headless):
##   godot --path . -s res://tools/render_ticket_art.gd -- <output dir>

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var painter := TicketPainter.new()
	root.add_child(painter)
	var pack := PackLoader.load_dir("res://packs/core").pack
	var lose := {"no": 1, "tier": -1, "prize": 0, "win_group": 2, "serial": "K482910", "verify": "",
		"groups": [PackedInt32Array([3, 1, 4, 1]), PackedInt32Array([5, 9, 2]), PackedInt32Array([6, 5, 3, 5])],
		"marks": [PackedInt32Array([2, 7, 1, 8]), PackedInt32Array([2, 8, 1]), PackedInt32Array([8, 2, 8, 4])]}
	var lose5 := lose.duplicate()
	lose5.groups = [PackedInt32Array([3, 1, 4, 1]), PackedInt32Array([5, 9, 2]), PackedInt32Array([6, 5, 3, 5]), PackedInt32Array([2, 7, 1]), PackedInt32Array([8, 2, 8, 4])]
	lose5.marks = [PackedInt32Array([1, 2, 3, 4]), PackedInt32Array([5, 6, 7]), PackedInt32Array([8, 9, 0, 1]), PackedInt32Array([2, 3, 4]), PackedInt32Array([5, 6, 7, 8])]
	for f in pack.forms:
		var t: Dictionary = lose5 if f.digit_groups.size() == 5 else lose
		var w := t.duplicate()
		w.tier = 0
		w.prize = 500
		w.verify = "123456"
		if f.wins_by_group():
			# By group: a top prize in the first group and the smallest in the last.
			t = t.duplicate()
			t.wins = []
			t.wins.resize(f.digit_groups.size())
			t.wins.fill(-1)
			w.wins = t.wins.duplicate()
			w.wins[0] = 0
			w.wins[-1] = f.tiers.size() - 1
			w.prize = int(f.tiers[0].prize) + int(f.tiers[-1].prize)
		var size := TicketArt.canvas_size(f)
		await _save(painter, size, TicketArt.front(f, "K482910"), out_dir.path_join(f.id + "_front.png"))
		await _save(painter, size, TicketArt.interior(f, t), out_dir.path_join(f.id + "_inside_lose.png"))
		await _save(painter, size, TicketArt.interior(f, w), out_dir.path_join(f.id + "_inside_win.png"))
	var catch_cover := TicketArt.cover(pack.form("catch"), 0)
	await _save(painter, catch_cover.canvas, catch_cover.cmds, out_dir.path_join("flap.png"))
	var tab := TicketArt.cover(pack.form("plate"), 2)
	await _save(painter, tab.canvas, tab.cmds, out_dir.path_join("tab_3.png"))
	var jar := TicketArt.cover(pack.form("spur"), 0)
	await _save(painter, jar.canvas, jar.cmds, out_dir.path_join("jar_cover.png"))
	var band := TicketArt.band(pack.form("spur"))
	await _save(painter, band.canvas, band.cmds, out_dir.path_join("band.png"))
	print("rendered to ", out_dir)
	quit()


func _save(painter: TicketPainter, size: Vector2, cmds: Array, path: String) -> void:
	var img: Image = await painter.paint_image(size, cmds, 1.0)
	img.save_png(path)
