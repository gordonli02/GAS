class_name DiscardPile
extends Node3D
## A pile of opened tickets on the table. Growth follows PileModel: one card per ticket
## for the first dozen, then bigger heaps by range, with the latest tickets on top.
## Cards are drawn in one batch per face, so even a big heap is cheap.
##
## The discard pile shows each ticket's printed front, one face per form. The winners'
## pile (show_inside) lies inside up and shows each ticket's own inside, the prizes it
## held: there a face is one ticket, "<form uid>#<box seed>#<ticket number>".

const HISTORY := 300
const INSIDE_SCALE := 1.0   ## paint scale of an inside on the pile (the hand's is 2)

var painter: TicketPainter
## Form for a uid; the game points this at the forms of the stage in play, whose print
## shows that stage's price and prizes.
var find_form: Callable = func(uid: String) -> FormDef: return Packs.form(uid)
## Winners' pile: the ticket for (form uid, box seed, ticket number), or {} if it cannot
## be found any more (its card then shows the form's front).
var find_ticket: Callable = func(_uid: String, _seed: String, _no: int) -> Dictionary: return {}
var show_inside := false           ## cards lie inside up, each showing its own ticket
var model := PileModel.new()
var opened := 0
var _forms: Array[String] = []     ## face shown by each card spot, in drop order
var _history: Array[String] = []   ## recent faces tossed, newest last
var _batches := {}                 ## face key -> MultiMeshInstance3D
var _art := {}                     ## form art key -> Texture2D (printed fronts)
var _rng := RandomNumberGenerator.new()
var _building := false
var _again := false


## A pile of its own shape: the drop sequence comes from `seed_text`, and `spread`
## under 1 keeps it tighter than the discard pile.
func use_seed(seed_text: String, spread := 1.0) -> void:
	model = PileModel.new(seed_text, spread)


## World position where the next ticket lands.
func next_spot() -> Vector3:
	return to_global(model.landing_spot(opened))


## How the next ticket lies once it lands (world basis, card frame as TicketView).
func next_basis() -> Basis:
	var i := mini(PileModel.shown(opened + 1) - 1, PileModel.MAX_CARDS - 1)
	return global_basis * _spot_basis(i) * flat_basis(show_inside)


## A card lying on the table, its top edge away from the player: printed front up, or
## inside up.
static func flat_basis(inside_up: bool) -> Basis:
	return Basis(Vector3.RIGHT, -PI / 2.0) if inside_up else TicketFlow._flat_basis()


## The face a ticket shows on this pile. `entry` is its tray entry ({form, ticket, box});
## without a box (or on the discard pile) the face is the form's front.
func face_id(form: FormDef, entry := {}) -> String:
	if show_inside and entry.get("box") != null and entry.has("ticket"):
		return "%s#%s#%d" % [form.uid(), entry.box.seed, int(entry.ticket.no)]
	return form.uid()


## A ticket of `form` has landed (`entry`: its tray entry, see face_id).
func land(form: FormDef, _spot := Vector3.ZERO, entry := {}) -> void:
	var id := face_id(form, entry)
	_remember(_history, id)
	PileModel.add_card(_forms, _history, opened, id, _rng)
	opened += 1
	await _rebuild()


## The pile as plain data for the save file. `landing` is the face (face_id) of a ticket
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


static func _remember(history: Array[String], id: String) -> void:
	history.append(id)
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
	for key in _batches.keys():
		_drop_batch(key)
	_again = _building   # cards being shown right now are taken away by one more pass


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


## Shows the cards of `_forms`. Painting a new face takes a frame or more: a change that
## arrives meanwhile is picked up by one more pass, never by a second one alongside.
func _rebuild() -> void:
	if _building:
		_again = true
		return
	_building = true
	_again = true
	while _again:
		_again = false
		await _show_cards()
	_building = false


func _show_cards() -> void:
	var by_face := {}
	for i in _forms.size():
		if not by_face.has(_forms[i]):
			by_face[_forms[i]] = []
		by_face[_forms[i]].append(i)
	var used := {}
	var forms := {}
	for id in by_face:
		var form: FormDef = find_form.call(_uid_of(id))
		if form != null:
			forms[id] = form
			used[_key(form, id)] = true
	for key in _batches.keys():
		if not used.has(key):
			_drop_batch(key)
	for id in forms:
		var mm := await _batch(forms[id], id)
		var list: Array = by_face[id]
		mm.instance_count = list.size()
		for k in list.size():
			var i: int = list[k]
			mm.set_instance_transform(k, Transform3D(_spot_basis(i), model.spots[i].pos))


## A face no card shows any more: a form's batch is kept empty for the next one, a single
## ticket's inside is let go.
func _drop_batch(key: String) -> void:
	if key.contains("#"):
		_batches[key].queue_free()
		_batches.erase(key)
	else:
		_batches[key].multimesh.instance_count = 0


static func _uid_of(id: String) -> String:
	return id.get_slice("#", 0)


## Batch key of a face: the form's art key (its stake), plus the ticket for an inside.
static func _key(form: FormDef, id: String) -> String:
	return form.art_key() + id.substr(_uid_of(id).length())


## Card lying flat at spot i: turned by its yaw, tilted with the heap under it.
func _spot_basis(i: int) -> Basis:
	var s: Dictionary = model.spots[i]
	return Basis(Vector3.UP, s.yaw) * Basis.from_euler(Vector3(s.tilt.x, 0, s.tilt.y))


## What a face shows on top: the form's front, or one ticket's inside (the front if that
## ticket cannot be found).
func _face(form: FormDef, id: String) -> Texture2D:
	var parts := id.split("#")
	if parts.size() >= 3:
		var seed_text := "#".join(parts.slice(1, parts.size() - 1))
		var t: Dictionary = find_ticket.call(parts[0], seed_text, int(parts[parts.size() - 1]))
		if not t.is_empty() and t.has("serial"):
			return await painter.paint(TicketArt.canvas_size(form), TicketArt.interior(form, t), INSIDE_SCALE)
	return await art(form)


## One batch per face: a thin card with the face on top.
func _batch(form: FormDef, id: String) -> MultiMesh:
	var key := _key(form, id)
	if _batches.has(key):
		return _batches[key].multimesh
	var face := await _face(form, id)
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
	# The face looks up; its top edge points away from the player (-z).
	top[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-hx, y, -hz), Vector3(hx, y, -hz), Vector3(hx, y, hz), Vector3(-hx, y, hz)])
	top[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	top[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	top[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, top)
	var print_mat := StandardMaterial3D.new()
	print_mat.albedo_texture = face
	mesh.surface_set_material(1, print_mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	add_child(inst)
	_batches[key] = inst
	return mm
