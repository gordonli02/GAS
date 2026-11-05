class_name GameInput
extends Node
## Mouse and keys for the whole game. Clicks respect occlusion: the front-most
## thing under the pointer decides (MIGRATION.md "Table and machine navigation").

var game: Game
var _dragging := false


func _unhandled_input(e: InputEvent) -> void:
	if game == null or game.machine == null:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press(e.position)
		elif _dragging:
			_dragging = false
			game.flow.release()
		_update_cursor(e.position)
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseMotion:
		if _dragging:
			game.flow.move(e.position)
		_update_cursor(e.position)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				game.primary()
			KEY_B:
				game.toggle_view()
			KEY_1, KEY_2, KEY_3:
				if game.at_machine and game.camera.cam > 0.9:
					game.press_machine(e.keycode - KEY_1)
			KEY_F1, KEY_F2, KEY_F3:
				# Developer room switch until the developer panel (milestone 6) takes it over.
				if not OS.is_debug_build():
					return
				game.set_room(RoomSet.ORDER[e.keycode - KEY_F1])
			KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
				# Developer lamp brightness for the red buttons: [ dimmer, ] brighter.
				if not OS.is_debug_build():
					return
				game.step_lamp(1 if e.keycode == KEY_BRACKETLEFT else -1)
			_:
				return
		get_viewport().set_input_as_handled()


func _press(pos: Vector2) -> void:
	var cam := game.camera
	if game.at_machine:
		if cam.cam <= 0.9:
			return
		var hit := _pick(pos)
		if hit.has_meta("column"):
			game.press_machine(hit.get_meta("column"))
		elif hit.has_meta("play_all"):
			game.press_machine(3)
		elif not hit.has_meta("machine"):
			game.toggle_view()
		return
	if cam.cam > 0.1:
		return
	var flow := game.flow
	# Paper first: grabbing a flap, or the band of a banded ticket.
	if flow.state == TicketFlow.State.BACK or (flow.state == TicketFlow.State.FRONT and game.view.band_on):
		if flow.can_grab(pos):
			_dragging = flow.press(pos)
			return
	if _pick(pos).has_meta("machine"):
		game.leave_for_machine()
		return
	if flow.state == TicketFlow.State.IDLE and game.tray.is_empty():
		return   # an empty table: clicking it does nothing
	if flow.state != TicketFlow.State.BACK:
		_dragging = flow.press(pos)


## The front-most collider under the pointer (a dummy Node when nothing is hit).
func _pick(pos: Vector2) -> Node:
	var cam := game.camera
	var from := cam.project_ray_origin(pos)
	var q := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(pos) * 200.0)
	var hit := game.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return _nothing
	return hit.collider


var _nothing := Node.new()


func _update_cursor(pos: Vector2) -> void:
	var shape := Input.CURSOR_ARROW
	if _dragging:
		shape = Input.CURSOR_DRAG
	elif game.at_machine:
		if game.camera.cam > 0.9:
			var hit := _pick(pos)
			if hit.has_meta("column") or hit.has_meta("play_all") or not hit.has_meta("machine"):
				shape = Input.CURSOR_POINTING_HAND
	elif game.camera.cam < 0.1:
		if game.flow.can_grab(pos):
			shape = Input.CURSOR_CAN_DROP
		elif _pick(pos).has_meta("machine"):
			shape = Input.CURSOR_POINTING_HAND
	Input.set_default_cursor_shape(shape)


func _exit_tree() -> void:
	_nothing.free()
