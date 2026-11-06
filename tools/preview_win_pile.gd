extends Node
## Renders the table of every room with the discard pile and the winners' pile at
## several sizes, and prints where the room's props stand on the table, for placing
## the winners' pile (Game.WIN_PILE_AT).
##   godot --path . --resolution 1920x1080 res://tools/preview_win_pile.tscn -- <output dir> [--at=x,z]
##   --at=x,z   try another place: x as a share of the tray/pile offset, z in table units

## [tickets on the discard pile, tickets on the winners' pile]: about one win in thirty.
const COUNTS := [[6, 1], [60, 3], [400, 14], [2000, 60]]

var game: Game


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	game = load("res://src/game/game.tscn").instantiate()
	game.use_save = false
	add_child(game)
	await _wait(1.5)
	for a in args:
		if a.begins_with("--at="):
			var p := a.trim_prefix("--at=").split(",")
			game.win_pile.position = Vector3(float(p[0]) * absf(game.pile.position.x), 0, float(p[1]))
	var history: Array[String] = []
	for i in 20:
		history.append("core:catch" if i < 10 else "core:plate" if i < 16 else "core:spur")
	# The winners' pile shows each ticket's inside: real winners from the machine's boxes.
	var winners: Array[String] = []
	for k in 40:
		for box in game.machine.boxes:
			var found := 0
			for t in box.tickets:
				if t.prize > 0:
					found += 1
					if found == k + 1:
						winners.append(game.win_pile.face_id(box.form, {"ticket": t, "box": box}))
						break
	game.close_machine()
	for id in RoomSet.ORDER:
		game.set_room(id, false)
		await _wait(0.8)
		print("%s: winners' pile at (%.2f, %.2f), discard pile at (%.2f, %.2f)" % [id,
			game.win_pile.position.x, game.win_pile.position.z, game.pile.position.x, game.pile.position.z])
		var g: Node3D = game.rooms.get_node(NodePath(id))
		for m: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
			var b := m.global_transform * m.get_aabb()
			if b.position.y < -0.05 or b.position.y > 1.0 or absf(b.get_center().x) > 7.5 or absf(b.get_center().z) > 6.25:
				continue   # not standing on the table top
			print("  prop  x %.2f..%.2f  z %.2f..%.2f" % [b.position.x, b.end.x, b.position.z, b.end.z])
		for c in COUNTS:
			await game.pile.fill(c[0], history)
			await game.win_pile.fill(c[1], winners)
			await _wait(0.2)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("%s_%04d.png" % [id, c[0]]))
	get_tree().quit()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
