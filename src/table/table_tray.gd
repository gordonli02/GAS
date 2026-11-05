class_name TableTray
extends Node3D
## The open wooden tray on the table holding the tickets still to open.

const WOOD := Color("#8d6b42")
const JW := 2.12
const TH := 2.0

var _stack := MeshInstance3D.new()
var _top := MeshInstance3D.new()
var _top_mat := StandardMaterial3D.new()


func _ready() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = WOOD
	for spec in [[Vector3(JW + 0.14, 0.04, TH + 0.14), Vector3(0, 0.02, 0)],
			[Vector3(0.04, 0.36, TH + 0.14), Vector3(-(JW / 2 + 0.07), 0.18, 0)],
			[Vector3(0.04, 0.36, TH + 0.14), Vector3(JW / 2 + 0.07, 0.18, 0)],
			[Vector3(JW + 0.14, 0.36, 0.04), Vector3(0, 0.18, TH / 2 + 0.07)],
			[Vector3(JW + 0.14, 0.36, 0.04), Vector3(0, 0.18, -(TH / 2 + 0.07))]]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = spec[0]
		m.mesh = b
		m.position = spec[1]
		m.material_override = wood
		add_child(m)
	var sb := BoxMesh.new()
	sb.size = Vector3(1.4, 1.0, 2.0)
	_stack.mesh = sb
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color("#ece6d7")
	_stack.material_override = edge
	add_child(_stack)
	var q := QuadMesh.new()
	q.size = Vector2(1.4, 2.0)
	_top.mesh = q
	_top.rotation = Vector3(-PI / 2, 0, 0)
	_top.position = Vector3(0, 0.5005, 0)
	_top.material_override = _top_mat
	_stack.add_child(_top)
	set_stack(0, null, Vector2(1.4, 2.0))


## Height follows the count (as in the web build); the top shows the next ticket's form.
func set_stack(count: int, art: Texture2D, card: Vector2) -> void:
	_stack.visible = count > 0
	var h := clampf(count / 500.0 * 0.9, 0.02, 0.9)
	_stack.scale = Vector3(card.x / 1.4, h, card.y / 2.0)
	_stack.position.y = 0.04 + h / 2.0
	if art:
		_top_mat.albedo_texture = art
