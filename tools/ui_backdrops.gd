extends Node
## Saves clean game backdrops (no HUD) for UI mockups:
##   godot --path . --resolution 1920x1080 res://tools/ui_backdrops.tscn -- <out dir>


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var game: Game = load("res://src/game/game.tscn").instantiate()
	game.use_save = false
	add_child(game)
	await get_tree().create_timer(1.5).timeout
	game.hud.visible = false
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("bg_machine.png"))
	game.economy.cash -= 6
	game.economy.credit += 6
	game.press_play_all()
	game.press_machine(0)
	await get_tree().create_timer(3.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("bg_table.png"))
	get_tree().quit()
