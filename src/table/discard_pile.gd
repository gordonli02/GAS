class_name DiscardPile
extends Node3D
## Used tickets land face up on a messy pile, capped at 36 meshes.

const CAP := 36
const CARD_THICKNESS := 0.012

var painter: TicketPainter
var _cards: Array[Node3D] = []
var _rng := SeededRng.new("pile")
var _art := {}   ## form uid -> Texture2D


## Where the next ticket should land (world space).
func next_spot() -> Vector3:
	var n := mini(_cards.size(), CAP - 2)
	return global_position + Vector3((randf() - 0.5) * 0.9, 0.03 + n * CARD_THICKNESS, (randf() - 0.5) * 0.8)


func land(form: FormDef, spot: Vector3) -> void:
	var card := Node3D.new()
	add_child(card)
	card.global_position = spot
	card.rotation = Vector3(0, (_rng.next_float() - 0.5) * 1.4, (_rng.next_float() - 0.5) * 0.04)
	var s: Array = form.layout.card.size
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(s[0], CARD_THICKNESS, s[1])
	body.mesh = box
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color("#ece6d7")
	body.material_override = edge
	card.add_child(body)
	var top := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(s[0], s[1])
	top.mesh = quad
	top.rotation = Vector3(-PI / 2.0, 0, 0)
	top.position.y = CARD_THICKNESS / 2.0 + 0.0005
	var mat := StandardMaterial3D.new()
	top.material_override = mat
	card.add_child(top)
	_cards.append(card)
	if _cards.size() > CAP:
		_cards.pop_front().queue_free()
	mat.albedo_texture = await art(form)


func clear() -> void:
	for c in _cards:
		c.queue_free()
	_cards.clear()


## The form's printed front without a serial, as seen on the box art.
func art(form: FormDef) -> Texture2D:
	if not _art.has(form.uid()):
		_art[form.uid()] = await painter.paint(TicketArt.canvas_size(form), TicketArt.front(form, ""))
	return _art[form.uid()]
