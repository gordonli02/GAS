class_name TicketInput
extends Node
## Mouse and keys for the ticket in hand. Turns raw input into TicketFlow actions
## and keeps the cursor honest about what can be grabbed.

var flow: TicketFlow
var _dragging := false


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_dragging = flow.press(e.position)
			_update_cursor(e.position)
		elif _dragging:
			_dragging = false
			flow.release()
			_update_cursor(e.position)
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseMotion:
		if _dragging:
			flow.move(e.position)
		_update_cursor(e.position)
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_SPACE or e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
			flow.primary()
			get_viewport().set_input_as_handled()


func _update_cursor(pos: Vector2) -> void:
	var shape := Input.CURSOR_ARROW
	if _dragging:
		shape = Input.CURSOR_DRAG
	elif flow.can_grab(pos):
		shape = Input.CURSOR_CAN_DROP
	Input.set_default_cursor_shape(shape)
