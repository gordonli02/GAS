class_name DiscardPile
extends Node3D
## The discard pile on the table. Growth follows PileModel: one card per ticket for
## the first dozen, then bigger heaps by range, with the latest tickets on top.
## Cards are drawn in one batch per form, so even a big heap is cheap.

const HISTORY := 300

var painter: TicketPainter
var model := PileModel.new()
var opened := 0
var _forms: Array[String] = []     ## form uid shown by each card spot, in drop order
var _history: Array[String] = []   ## recent forms tossed, newest last
var _batches := {}                 ## form uid -> MultiMeshInstance3D
var _art := {}                     ## form uid -> Texture2D
var _rng := RandomNumberGenerator.new()


## World position where the next ticket lands.
func next_spot() -> Vector3:
	return to_global(model.landing_spot(opened))


## How the next ticket lies once it lands (world basis, card frame as TicketView).
func next_basis() -> Basis:
	var i := mini(PileModel.shown(opened + 1) - 1, PileModel.MAX_CARDS - 1)
	return global_basis * _spot_basis(i) * TicketFlow._flat_basis()


## A ticket of `form` has landed.
func land(form: FormDef, _spot := Vector3.ZERO) -> void:
	var uid := form.uid()
	_history.append(uid)
	if _history.size() > HISTORY:
		_history.pop_front()
	var before := PileModel.shown(opened)
	opened += 1
	var after := PileModel.shown(opened)
	if after == before and after > 0:
		# Toppers are full: they shift down and the newest goes on top.
		var heap := PileModel.heap_cards(opened)
		for i in range(heap, after - 1):
			_forms[i] = _forms[i + 1]
		_forms[after - 1] = uid
	else:
		# New spots: a range jump fills them from recent tickets; the top one is this ticket.
		while _forms.size() < after - 1:
			_forms.append(_history[_rng.randi() % _history.size()])
		_forms.append(uid)
	await _rebuild()


## Sets the pile straight to a count, e.g. when restoring a session or previewing.
func fill(count: int, history: Array[String]) -> void:
	opened = 0
	_forms.clear()
	_history.clear()
	_rng.seed = 1
	for i in count:
		_history.append(history[i % history.size()])
		if _history.size() > HISTORY:
			_history.pop_front()
	opened = count
	var n := PileModel.shown(count)
	for i in n:
		_forms.append(_history[_rng.randi() % _history.size()])
	await _rebuild()


func clear() -> void:
	opened = 0
	_forms.clear()
	_history.clear()
	for b in _batches.values():
		b.multimesh.instance_count = 0


## Box art if already painted, else null (and starts painting it).
func cached_art(form: FormDef) -> Texture2D:
	if not _art.has(form.uid()):
		art(form)
		return null
	return _art[form.uid()]


## The form's printed front without a serial, as seen on the box art.
func art(form: FormDef) -> Texture2D:
	if not _art.has(form.uid()):
		_art[form.uid()] = await painter.paint(TicketArt.canvas_size(form), TicketArt.front(form, ""))
	return _art[form.uid()]


func _rebuild() -> void:
	var by_form := {}
	for i in _forms.size():
		if not by_form.has(_forms[i]):
			by_form[_forms[i]] = []
		by_form[_forms[i]].append(i)
	for uid in _batches:
		if not by_form.has(uid):
			_batches[uid].multimesh.instance_count = 0
	for uid in by_form:
		var form := Packs.form(uid)
		if form == null:
			continue
		var mm := await _batch(form)
		var list: Array = by_form[uid]
		mm.instance_count = list.size()
		for k in list.size():
			var i: int = list[k]
			mm.set_instance_transform(k, Transform3D(_spot_basis(i), model.spots[i].pos))


## Card lying flat at spot i: turned by its yaw, tilted with the heap under it.
func _spot_basis(i: int) -> Basis:
	var s: Dictionary = model.spots[i]
	return Basis(Vector3.UP, s.yaw) * Basis.from_euler(Vector3(s.tilt.x, 0, s.tilt.y))


## One batch per form: a thin card with the form's art on top.
func _batch(form: FormDef) -> MultiMesh:
	var uid := form.uid()
	if _batches.has(uid):
		return _batches[uid].multimesh
	var s: Array = form.layout.card.size
	var mesh := ArrayMesh.new()
	var box := BoxMesh.new()
	box.size = Vector3(s[0], PileModel.THICK, s[1])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color("#ece6d7")
	mesh.surface_set_material(0, edge)
	var hx: float = s[0] / 2.0
	var hz: float = s[1] / 2.0
	var y := PileModel.THICK / 2.0 + 0.0005
	var top := []
	top.resize(Mesh.ARRAY_MAX)
	# Print faces up; the top of the print points away from the player (-z).
	top[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-hx, y, -hz), Vector3(hx, y, -hz), Vector3(hx, y, hz), Vector3(-hx, y, hz)])
	top[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	top[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	top[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, top)
	var print_mat := StandardMaterial3D.new()
	print_mat.albedo_texture = await art(form)
	mesh.surface_set_material(1, print_mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	add_child(inst)
	_batches[uid] = inst
	return mm
