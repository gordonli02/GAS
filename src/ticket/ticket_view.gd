class_name TicketView
extends Node3D
## The ticket in the hand: a rigid card plus the layout's flaps.
## Card local frame: x right, y up, the printed front faces -z, the inside and
## the flaps face +z. Built from the form's layout, so pack layouts work the same.

const THICKNESS := 0.016
const FLAP_Z := THICKNESS / 2.0 + 0.004
const MARGIN := 1.4 * 16.0 / 420.0      ## grab slack around a flap, as in the web build
const GRAB_PAD := 0.05
const PAIR_EDGE := 0.095                 ## press this close to a shared edge to tear both
const SHADER := preload("res://src/paper/paper.gdshader")

var painter: TicketPainter
var form: FormDef
var size := Vector2(1.4, 2.0)
var sims: Array[FlapSim] = []
var flaps: Array[FlapMesh] = []
var below: Array[int] = []   ## neighbour sharing the flap's local -y edge, or -1
var above: Array[int] = []   ## neighbour sharing the flap's local +y edge, or -1

var _body := MeshInstance3D.new()
var _front := MeshInstance3D.new()
var _inside := MeshInstance3D.new()
var _front_mat := ShaderMaterial.new()
var _inside_mat := ShaderMaterial.new()
var _covers := {}   ## form uid -> Array[Texture2D]


func _ready() -> void:
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color("#ece6d7")
	edge.roughness = 1.0
	_body.material_override = edge
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for m in [_front_mat, _inside_mat]:
		m.shader = SHADER
	_front.material_override = _front_mat
	_inside.material_override = _inside_mat
	_front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_inside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_body)
	add_child(_front)
	add_child(_inside)


## Builds the card and flaps for a form. Covers are painted once per form.
func use_form(f: FormDef) -> void:
	if form == f:
		reset_flaps()
		return
	form = f
	var s: Array = f.layout.card.size
	size = Vector2(s[0], s[1])
	var box := BoxMesh.new()
	box.size = Vector3(size.x, size.y, THICKNESS)
	_body.mesh = box
	for q in [_front, _inside]:
		var quad := QuadMesh.new()
		quad.size = size
		q.mesh = quad
	_front.position = Vector3(0, 0, -THICKNESS / 2.0 - 0.0004)
	_front.rotation = Vector3(0, PI, 0)
	_inside.position = Vector3(0, 0, THICKNESS / 2.0 + 0.0004)

	if not _covers.has(f.uid()):
		var list: Array[Texture2D] = []
		for i in f.layout.flaps.size():
			var c := TicketArt.cover(f, i)
			list.append(await painter.paint(c.canvas, c.cmds))
		_covers[f.uid()] = list
	_build_flaps()


## Paints this ticket's front and inside.
func show_ticket(t: Dictionary) -> void:
	var canvas := TicketArt.canvas_size(form)
	var front_tex := await painter.paint(canvas, TicketArt.front(form, t.serial))
	var inside_tex := await painter.paint(canvas, TicketArt.interior(form, t))
	_front_mat.set_shader_parameter("front_tex", front_tex)
	_inside_mat.set_shader_parameter("front_tex", inside_tex)
	reset_flaps()


func reset_flaps() -> void:
	for i in sims.size():
		sims[i].reset()
		flaps[i].refresh()


## Advances every flap. Returns events: {type: "slice", flap, from, to}, {type: "opened", flap}.
func step(dt: float, held: Array) -> Array:
	var events := []
	for i in sims.size():
		var ev := sims[i].step(dt, held.has(i))
		if ev.has("slice"):
			events.append({"type": "slice", "flap": i, "from": ev.slice.x, "to": ev.slice.y})
		if ev.get("opened", false):
			events.append({"type": "opened", "flap": i})
		flaps[i].refresh()
	return events


func all_settled() -> bool:
	for s in sims:
		if not s.is_settled():
			return false
	return not sims.is_empty()


func any_torn() -> bool:
	for s in sims:
		if s.torn:
			return true
	return false


## Largest share open of any flap, 0..1.
func max_open() -> float:
	var m := 0.0
	for s in sims:
		m = maxf(m, s.openness())
	return m


## Pointer ray onto flap i's plane, in that flap's local frame (or null).
func flap_point(i: int, from: Vector3, dir: Vector3) -> Variant:
	var root := flaps[i]
	var plane := Plane(global_basis.z.normalized(), root.global_position)
	var hit = plane.intersects_ray(from, dir)
	if hit == null:
		return null
	var p := root.to_local(hit)
	return Vector2(p.x, p.y)


## Which unopened flap the ray lands on, with an optional pair partner.
## Returns {flap, point, mate} or {}.
func flap_at(from: Vector3, dir: Vector3) -> Dictionary:
	for i in sims.size():
		var s := sims[i]
		if s.open:
			continue
		var p = flap_point(i, from, dir)
		if p == null:
			continue
		if absf(p.y) > s.h / 2.0 + GRAB_PAD or p.x > s.w + MARGIN + GRAB_PAD or p.x < minf(0.0, 2.0 * s.f - s.w) - MARGIN - GRAB_PAD:
			continue
		var mate := -1
		if form.layout.get("pairs", "none") == "adjacent":
			if s.h / 2.0 + p.y < PAIR_EDGE and _free(below[i]):
				mate = below[i]
			elif s.h / 2.0 - p.y < PAIR_EDGE and _free(above[i]):
				mate = above[i]
		return {"flap": i, "point": p, "mate": mate}
	return {}


## Local y of the edge flap i shares with flap j (each peels from the shared edge).
func shared_edge_y(i: int, j: int) -> float:
	return -sims[i].h / 2.0 if below[i] == j else sims[i].h / 2.0


## Point on flap i's free edge, in world space (for paper flecks).
func flap_edge_world(i: int, y_sign: float) -> Vector3:
	var s := sims[i]
	return flaps[i].to_global(Vector3(s.f, y_sign * s.h / 2.0, 0.05))


func _free(i: int) -> bool:
	return i >= 0 and not sims[i].open and not sims[i].auto


func _build_flaps() -> void:
	for f in flaps:
		f.queue_free()
	flaps.clear()
	sims.clear()
	var canvas := TicketArt.canvas_size(form)
	var frames := []
	for i in form.layout.flaps.size():
		var spec: Dictionary = form.layout.flaps[i]
		var r := Rect2(spec.rect[0], spec.rect[1], spec.rect[2], spec.rect[3])
		var l := _to_card(r.position, canvas).x
		var rr := _to_card(r.end, canvas).x
		var t := _to_card(r.position, canvas).y
		var b := _to_card(r.end, canvas).y
		var pos: Vector2
		var rot: float
		var w: float
		var h: float
		match spec.hinge:
			"left":
				pos = Vector2(l, (t + b) / 2.0); rot = 0.0; w = rr - l; h = t - b
			"right":
				pos = Vector2(rr, (t + b) / 2.0); rot = PI; w = rr - l; h = t - b
			"top":
				pos = Vector2((l + rr) / 2.0, t); rot = -PI / 2.0; w = t - b; h = rr - l
			_:
				pos = Vector2((l + rr) / 2.0, b); rot = PI / 2.0; w = t - b; h = rr - l
		var sim := FlapSim.new(w, h)
		var mesh := FlapMesh.new()
		mesh.position = Vector3(pos.x, pos.y, FLAP_Z)
		mesh.rotation = Vector3(0, 0, rot)
		add_child(mesh)
		var xf := Transform2D(rot, pos)
		var uv_of := func(x: float, y: float) -> Vector2:
			var cp := _to_canvas(xf * Vector2(x, y), canvas)
			return Vector2((cp.x - r.position.x) / r.size.x, (cp.y - r.position.y) / r.size.y)
		var seg_y := clampi(roundi(14.0 * h / 1.9), 4, 14)
		mesh.setup(sim, _covers[form.uid()][i], uv_of, 26, seg_y)
		sims.append(sim)
		flaps.append(mesh)
		frames.append({"xf": xf, "w": w, "h": h, "hinge": spec.hinge})
	_find_neighbours(frames)


## Flaps that share a full edge across their hinge direction can tear as a pair.
func _find_neighbours(frames: Array) -> void:
	below.clear()
	above.clear()
	for i in frames.size():
		below.append(-1)
		above.append(-1)
		var fi: Dictionary = frames[i]
		for j in frames.size():
			var fj: Dictionary = frames[j]
			if i == j or fi.hinge != fj.hinge:
				continue
			var inv: Transform2D = fi.xf.affine_inverse() * fj.xf
			var o := inv.origin
			if absf(o.x) > 0.01 or absf(fj.w - fi.w) > 0.01:
				continue
			var gap: float = absf(o.y) - (fi.h + fj.h) / 2.0
			if absf(gap) > 0.06:
				continue
			if o.y < 0:
				below[i] = j
			else:
				above[i] = j


func _to_card(p: Vector2, canvas: Vector2) -> Vector2:
	return Vector2((p.x / canvas.x - 0.5) * size.x, (0.5 - p.y / canvas.y) * size.y)


func _to_canvas(p: Vector2, canvas: Vector2) -> Vector2:
	return Vector2((p.x / size.x + 0.5) * canvas.x, (0.5 - p.y / size.y) * canvas.y)
