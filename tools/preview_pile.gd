extends Node
## Renders the discard pile at several ticket counts on the test table, for review.
##   godot --path . --resolution 1920x1080 res://tools/preview_pile.tscn -- <output dir>

const COUNTS := [3, 8, 12, 19, 29, 49, 99, 199, 399, 699, 999, 1999, 4000]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	var scene: Node = load("res://src/table/test_table.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(0.8).timeout
	var pile: DiscardPile = scene.pile
	var history: Array[String] = []
	# A mixed session: mostly Big Catch, then Hot Plate and some Lucky Spur.
	for i in 20:
		history.append("core:catch" if i < 10 else "core:plate" if i < 16 else "core:spur")
	for n in COUNTS:
		await pile.fill(n, history)
		await get_tree().create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("pile_%04d.png" % n))
		print("%d opened -> %d cards shown" % [n, PileModel.shown(n)])
	get_tree().quit()
