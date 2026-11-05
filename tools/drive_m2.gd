extends Node
## Drives the M2 table through a full ticket with synthetic input and saves
## screenshots. Runs as a scene so autoloads exist. Needs a display:
##   godot --path . res://tools/drive_m2.tscn -- <output dir> [slow|fast|space]

var out := ""
var scene: Node
var shots := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	var mode: String = args[1] if args.size() > 1 else "slow"
	DirAccess.make_dir_recursive_absolute(out)
	scene = load("res://src/table/table_m2.tscn").instantiate()
	add_child(scene)
	var flow: TicketFlow = scene.flow
	var slices := [0]
	var sfx := get_node("/root/Sfx")
	await get_tree().create_timer(0.6).timeout
	await _shot("0_table")
	_key(KEY_SPACE)
	await get_tree().create_timer(0.7).timeout
	await _shot("1_front")
	print("state after deal: ", TicketFlow.State.keys()[flow.state])
	_click(Vector2(960, 540))
	await get_tree().create_timer(0.5).timeout
	await _shot("2_back")
	print("state after flip: ", TicketFlow.State.keys()[flow.state])
	if mode == "space":
		_key(KEY_SPACE)
		await get_tree().create_timer(0.25).timeout
		await _shot("3_mid")
	else:
		var view: TicketView = flow.view
		var s := view.sims[0]
		var start_local := Vector3(s.w * 0.9, 0.35, 0)
		var p0 := _screen(view.flaps[0].to_global(start_local))
		_mouse_button(p0, true)
		var steps := 60 if mode == "slow" else 8
		var travel := s.w * 2.0
		for i in steps + 1:
			var local := start_local + Vector3(-travel * i / steps, -0.3 * i / steps, 0)
			# keep the drag on the flap's plane while the card slides
			_mouse_move(_screen(view.flaps[0].to_global(local)))
			await get_tree().create_timer(1.2 / steps if mode == "slow" else 0.02).timeout
			if i == steps / 2:
				await _shot("3_mid")
		_mouse_button(_screen(view.flaps[0].to_global(start_local + Vector3(-travel, -0.3, 0))), false)
	await get_tree().create_timer(0.9).timeout
	await _shot("4_revealed")
	print("state after tear: ", TicketFlow.State.keys()[flow.state], "  prize ", flow.ticket.prize, "  serial ", flow.ticket.serial)
	print("flap torn=%s open=%s ticks=%d clip=%d" % [flow.view.sims[0].torn, flow.view.sims[0].open, flow.view.sims[0].ticks, flow.view.sims[0].tear_clip])
	print("tear slices cached: ", sfx._slices.size())
	_click(Vector2(960, 540))
	await get_tree().create_timer(0.25).timeout
	await _shot("5_toss")
	await get_tree().create_timer(1.0).timeout
	await _shot("6_next")
	print("state at end: ", TicketFlow.State.keys()[flow.state], "  pile ", scene.pile._cards.size())
	get_tree().quit()


func _screen(world: Vector3) -> Vector2:
	return scene.camera.unproject_position(world)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))


func _key(k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	Input.parse_input_event(e)
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)


func _click(p: Vector2) -> void:
	_mouse_button(p, true)
	_mouse_button(p, false)


func _mouse_button(p: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = p
	e.global_position = p
	Input.parse_input_event(e)


func _mouse_move(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	Input.parse_input_event(e)
