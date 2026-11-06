extends Node
## Holds a ticket of each form at the table and saves three pictures of it: dealt, turned
## over, and open. For looking at a card's shape and layout in the game itself:
##   godot --path . --resolution 1920x1080 res://tools/preview_tickets.tscn -- <out dir> [--forms=plate,kabawk]
## Writes <form>_1_front.png, <form>_2_back.png and <form>_3_open.png. No save file is used.


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var only := []
	for a in args:
		if a.begins_with("--forms="):
			only = Array(a.trim_prefix("--forms=").split(","))
	var game: Game = load("res://src/game/game.tscn").instantiate()
	game.use_save = false
	add_child(game)
	await _wait(3.0)
	for i in game.machine.forms.size():
		var form: FormDef = game.machine.forms[i]
		if not only.is_empty() and not only.has(form.id):
			continue
		game.dev_free_ticket(i)
		await _wait(2.0)
		if game.view.band_on:
			game.primary()   # the paper band comes off first
			await _wait(1.2)
		await _shot(out.path_join(form.id + "_1_front.png"))
		game.primary()
		await _wait(1.2)
		await _shot(out.path_join(form.id + "_2_back.png"))
		for flap in form.layout.flaps.size():
			game.primary()
			await _wait(0.9)
		await _wait(1.0)
		await _shot(out.path_join(form.id + "_3_open.png"))
		game.primary()
		await _wait(1.6)
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
