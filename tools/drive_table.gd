extends Node
## Drives the test table through one ticket of each core form with synthetic
## input, prints checks and saves screenshots. Runs as a scene so autoloads exist:
##   godot --path . --resolution 1920x1080 res://tools/drive_table.tscn -- <output dir>

var out := ""
var scene: Node
var flow: TicketFlow
var view: TicketView
var failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	scene = load("res://src/table/test_table.tscn").instantiate()
	add_child(scene)
	flow = scene.flow
	view = flow.view
	await _wait(0.6)

	# 1. Big Catch: slow drag across the single flap.
	_key(KEY_SPACE)
	await _wait(0.7)
	_expect(flow.form.id == "catch" and flow.state == TicketFlow.State.FRONT, "catch dealt")
	_click(Vector2(960, 540))
	await _wait(0.5)
	await _drag_flap(0, Vector2(0.9, 0.35), Vector2(-2.0, -0.3), 40, "catch_mid")
	await _wait(0.9)
	_expect(flow.state == TicketFlow.State.REVEALED, "catch revealed")
	await _shot("catch_revealed")
	_click(Vector2(960, 540))
	await _wait(1.0)

	# 2. Hot Plate: press on the boundary between windows 1 and 2, both tear.
	_expect(flow.form.id == "plate" and flow.state == TicketFlow.State.FRONT, "plate dealt")
	await _shot("plate_front")
	_click(Vector2(960, 540))
	await _wait(0.5)
	await _shot("plate_back")
	var h := view.sims[0].h
	await _drag_flap(0, Vector2(0.9, -h / 2.0 + 0.04), Vector2(-2.0, 0.0), 30, "plate_pair_mid")
	await _wait(0.6)
	_expect(view.sims[0].open and view.sims[1].open, "windows 1 and 2 opened together")
	_expect(not view.sims[2].torn, "window 3 untouched")
	await _shot("plate_pair_done")
	for i in 3:
		_key(KEY_SPACE)
		await _wait(0.12)
	await _wait(1.0)
	_expect(flow.state == TicketFlow.State.REVEALED, "plate revealed after Space x3")
	await _shot("plate_revealed")
	_click(Vector2(960, 540))
	await _wait(1.0)

	# 3. Lucky Spur: the band tears in two with a vertical drag; a sideways swipe opens the flap.
	_expect(flow.form.id == "spur" and flow.state == TicketFlow.State.FRONT, "spur dealt")
	_expect(view.band_on, "spur starts banded")
	await _shot("spur_front")
	_click(_screen(view.to_global(Vector3(0.0, 0.3, 0))))
	await _wait(0.4)
	_expect(flow.state == TicketFlow.State.FRONT, "click does not flip a banded ticket")
	await _drag_card(Vector3(0.2, 0.0, 0), Vector3(0.21, 0.2, 0), 6)   # 0.2 up
	_expect(view.band_on, "0.2 up does not break the band")
	await _drag_card(Vector3(0.2, 0.0, 0), Vector3(0.22, -0.45, 0), 10, "spur_band_split")
	_expect(not view.band_on and view.band_mode == "split", "past 0.34 down the band tears in two")
	await _wait(0.12)
	await _shot("spur_band_halves")
	await _wait(0.4)
	_click(_screen(view.to_global(Vector3(0.0, 0.3, 0))))
	await _wait(0.5)
	_expect(flow.state == TicketFlow.State.BACK, "spur flipped after the band")
	await _shot("spur_back")
	# Swipe right along the bottom: flap y runs along the card's width.
	await _drag_flap(0, Vector2(0.85, -0.6), Vector2(0.0, 1.5), 40, "spur_swipe_mid")
	_expect(view.sims[0].torn and view.sims[0].y_grab < 0, "swipe right tears from the bottom-left corner")
	await _wait(0.9)
	_expect(flow.state == TicketFlow.State.REVEALED, "spur revealed after a swipe")
	await _shot("spur_revealed")
	_click(Vector2(960, 540))
	await _wait(1.0)

	# 4. Round two: catch and plate by Space, then spur with a sliding band and an upward pull.
	for form_id in ["catch", "plate"]:
		_expect(flow.form.id == form_id, form_id + " dealt (round two)")
		_key(KEY_SPACE)
		await _wait(0.4)
		for i in 5:
			_key(KEY_SPACE)
			await _wait(0.1)
		await _wait(1.0)
		_expect(flow.state == TicketFlow.State.REVEALED, form_id + " opened by Space")
		_key(KEY_SPACE)
		await _wait(1.0)
	_expect(flow.form.id == "spur" and view.band_on, "second spur dealt, banded")
	await _drag_card(Vector3(-0.3, 0.0, 0), Vector3(0.15, 0.02, 0), 10, "spur_band_slide")
	_expect(not view.band_on and view.band_mode == "slide", "sideways drag slides the band off")
	await _wait(0.4)
	_click(_screen(view.to_global(Vector3(0.0, 0.3, 0))))
	await _wait(0.5)
	await _drag_flap(0, Vector2(0.9, 0.2), Vector2(-2.0, 0.1), 40, "spur_up_mid")
	await _wait(0.9)
	_expect(flow.state == TicketFlow.State.REVEALED, "spur revealed after an upward pull")
	print("tear slices cached: ", get_node("/root/Sfx")._slices.size())
	print("DRIVE %s (%d failed checks)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures > 0 else 0)


## Drags flap i from `start` (x as a share of the flap width, y in flap units)
## by `travel` (shares of the width / flap units), keeping to the flap's plane.
func _drag_flap(i: int, start: Vector2, travel: Vector2, steps: int, mid_shot := "") -> void:
	var s := view.sims[i]
	var a := Vector3(s.w * start.x, start.y, 0)
	var d := Vector3(s.w * travel.x, travel.y, 0)
	_mouse_button(_screen(view.flaps[i].to_global(a)), true)
	for k in steps + 1:
		_mouse_move(_screen(view.flaps[i].to_global(a + d * k / steps)))
		await _wait(1.2 / steps)
		if k == steps / 2 and mid_shot != "":
			await _shot(mid_shot)
	_mouse_button(_screen(view.flaps[i].to_global(a + d)), false)


func _drag_card(start: Vector3, end: Vector3, steps: int, mid_shot := "") -> void:
	_mouse_button(_screen(view.to_global(start)), true)
	for k in steps + 1:
		_mouse_move(_screen(view.to_global(start.lerp(end, float(k) / steps))))
		await _wait(0.03)
		if k == steps - 2 and mid_shot != "":
			await _shot(mid_shot)
	_mouse_button(_screen(view.to_global(end)), false)
	await _wait(0.05)


func _expect(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


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
