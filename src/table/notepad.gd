class_name Notepad
extends Node3D
## A small spiral notepad on the table with the session ledger written on it
## (G kept this from the "in the world" UI idea). Repainted only when a number changes.
## Written in Patrick Hand.

const PAGE := Vector2(260, 330)
const SIZE := Vector2(1.3, 1.65)
const INK := Color("#2b3a8a")
const HAND_FONT := "hand"

var painter: TicketPainter
var _page := StandardMaterial3D.new()
var _shown := ""
var _busy := false
var _pending: Array = []


func _ready() -> void:
	var block := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(SIZE.x, 0.06, SIZE.y)
	block.mesh = b
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color("#efe8d0")
	block.material_override = paper
	block.position.y = 0.03
	add_child(block)
	var top := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = SIZE
	top.mesh = q
	top.rotation = Vector3(-PI / 2, 0, 0)
	top.position.y = 0.0605
	_page.disable_receive_shadows = true  # the page sits a hair above the block: no self-shadow stripes
	top.material_override = _page
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(top)


func show_ledger(lines: Array) -> void:
	var key := "|".join(lines)
	if key == _shown:
		return
	_shown = key
	_pending = lines
	if _busy:
		return
	_busy = true
	while not _pending.is_empty():
		var now := _pending
		_pending = []
		_page.albedo_texture = await painter.paint(PAGE, _page_cmds(now))
	_busy = false


static func _page_cmds(lines: Array) -> Array:
	var cmds := [_rect(0, 0, PAGE.x, PAGE.y, Color("#fffbe6"))]
	for i in 9:
		cmds.append(_rect(0, 62 + i * 30, PAGE.x, 2, Color("#9cc1e8")))
	cmds.append(_rect(30, 34, 2, PAGE.y - 34, Color("#e8a0a0")))
	for i in 9:
		cmds.append(_rect(16 + i * 28, 6, 10, 16, Color("#6b6d73")))
	for i in lines.size():
		cmds.append({"k": "text", "text": lines[i], "pos": Vector2(42, 88 + i * 30), "font": HAND_FONT,
			"size": 27.0, "align": "left", "max_width": PAGE.x - 54.0, "color": INK, "outline": 0.0, "dir": ""})
	return cmds


static func _rect(x: float, y: float, w: float, h: float, c: Color) -> Dictionary:
	return {"k": "poly", "pts": PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)]), "color": c}
