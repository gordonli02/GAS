class_name DiscardPile
extends Node3D
## The discard pile on the table. Growth follows PileModel: one card per ticket for
## the first dozen, then bigger heaps by range, with the latest tickets on top.
## Cards are drawn in one batch per form, so even a big heap is cheap.

const HISTORY := 300

var painter: TicketPainter
## Form for a uid; the game points this at the forms of the stage in play, whose print
## shows that stage's price and prizes.
var find_form: Callable = func(uid: String) -> FormDef: return Packs.form(uid)
var model := PileModel.new()
var opened := 0
var _forms: Array[String] = []     ## form uid shown by each card spot, in drop order
var _history: Array[String] = []   ## recent forms tossed, newest last
var _batches := {}                 ## form art key -> MultiMeshInstance3D
var _art := {}                     ## form art key -> Texture2D
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
	_remember(_history, uid)
	PileModel.add_card(_forms, _history, opened, uid, _rng)
	opened += 1
	await _rebuild()


## The pile as plain data for the save file. `landing` is the form uid of a ticket
## still on its way (already paid), counted as if it had landed.
func to_dict(landing := "") -> Dictionary:
	var forms := _forms.duplicate()
	var history := _history.duplicate()
	var n := opened
	if landing != "":
		var r := RandomNumberGenerator.new()
		r.seed = _rng.seed
		r.state = _rng.state
		_remember(history, landing)
		PileModel.add_card(forms, history, n, landing, r)
		n += 1
	return {"opened": n, "history": history, "forms": forms}


## Restores a pile saved with to_dict(); rebuilt from its history if the cards don't fit.
func from_dict(d: Dictionary) -> void:
	var n := maxi(0, int(d.get("opened", 0)))
	var history: Array[String] = []
	history.assign(d.get("history", []))
	if n == 0 or history.is_empty():
		clear()
		return
	var forms: Array[String] = []
	forms.assign(d.get("forms", []))
	if forms.size() != PileModel.shown(n):
		await fill(n, history)
		return
	opened = n
	_history = history
	_forms = forms
	await _rebuild()


static func _remember(history: Array[String], uid: String) -> void:
	history.append(uid)
	if history.size() > HISTORY:
		history.pop_front()


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
	if not _art.has(form.art_key()):
		art(form)
		return null
	return _art[form.art_key()]


## The form's printed front without a serial, as seen on the box art.
func art(form: FormDef) -> Texture2D:
	var key := form.art_key()
	if not _art.has(key):
		_art[key] = null   # being painted: a second caller waits for the same picture
		_art[key] = await painter.paint(TicketArt.canvas_size(form), TicketArt.front(form, ""))
	while _art[key] == null:
		await get_tree().process_frame
	return _art[key]


func _rebuild() -> void:
	var by_form := {}
	for i in _forms.size():
		if not by_form.has(_forms[i]):
			by_form[_forms[i]] = []
		by_form[_forms[i]].append(i)
	var used := {}
	var forms := {}
	for uid in by_form:
		var form: FormDef = find_form.call(uid)
		if form != null:
			forms[uid] = form
			used[form.art_key()] = true
	for key in _batches:
		if not used.has(key):
			_batches[key].multimesh.instance_count = 0
	for uid in forms:
		var form: FormDef = forms[uid]
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
	var key := form.art_key()
	if _batches.has(key):
		return _batches[key].multimesh
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
	_batches[key] = inst
	return mm
