class_name TicketView
extends Node3D
## The ticket in the hand: a rigid card, the layout's flaps and an optional band.
## Card local frame: x right, y up, the printed front faces -z, the inside and
## the flaps face +z. Built from the form's layout, so pack layouts work the same.

const THICKNESS := 0.016
const FLAP_Z := THICKNESS / 2.0 + 0.004
const MARGIN := 1.4 * 16.0 / 420.0      ## grab slack around a flap, as in the web build
const GRAB_PAD := 0.05
const SHADER := preload("res://src/paper/paper.gdshader")
const BAND_Z := 0.009
const BAND_FLY_TIME := 0.3

var painter: TicketPainter
var form: FormDef
var size := Vector2(1.4, 2.0)
var sims: Array[FlapSim] = []
var flaps: Array[FlapMesh] = []
var frames: Array = []        ## FlapLayout.build() for the current form
var band_on := false
var band_mode := ""          ## how the band is being dragged or was broken: "slide" or "split"

var _body := MeshInstance3D.new()
var _front := MeshInstance3D.new()
var _inside := MeshInstance3D.new()
var _front_mat := ShaderMaterial.new()
var _inside_mat := ShaderMaterial.new()
var _covers := {}   ## form uid -> Array[Texture2D]
var _band := Node3D.new()          ## slides as a whole
var _halves: Array[Node3D] = []    ## left and right half, pivoting on their outer ends
var _band_tex := {}  ## form uid -> Texture2D
var _band_fly := -1.0   ## 0..1 while the broken band flies off, -1 otherwise
var _band_dir := 1.0
var _band_from := 0.0
var _band_tilt := 0.0


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
	add_child(_band)
	_band.visible = false


## Builds the card, flaps and band for a form. Covers are painted once per form.
func use_form(f: FormDef) -> void:
	if form == f:
		reset()
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

	if not _covers.has(f.art_key()):
		var list: Array[Texture2D] = []
		for i in f.layout.flaps.size():
			var c := TicketArt.cover(f, i)
			list.append(await painter.paint(c.canvas, c.cmds))
		_covers[f.art_key()] = list
	if f.layout.band != null and not _band_tex.has(f.art_key()):
		var b := TicketArt.band(f)
		_band_tex[f.art_key()] = await painter.paint(b.canvas, b.cmds)
	_build_flaps()
	_build_band()
	reset()


## Paints this ticket's front and inside.
func show_ticket(t: Dictionary) -> void:
	var canvas := TicketArt.canvas_size(form)
	var front_tex := await painter.paint(canvas, TicketArt.front(form, t.serial))
	var inside_tex := await painter.paint(canvas, TicketArt.interior(form, t))
	_front_mat.set_shader_parameter("front_tex", front_tex)
	_inside_mat.set_shader_parameter("front_tex", inside_tex)
	reset()


## Fresh ticket: flaps closed, band on (if the layout has one).
func reset() -> void:
	for i in sims.size():
		sims[i].reset()
		flaps[i].refresh()
	band_on = form != null and form.layout.band != null
	band_mode = ""
	_band_fly = -1.0
	_band.visible = band_on
	_rest_band()


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


func _process(dt: float) -> void:
	if _band_fly < 0.0:
		return
	_band_fly = minf(1.0, _band_fly + dt / BAND_FLY_TIME)
	var t := _band_fly
	if band_mode == "split":
		# Torn in the middle: each half flies out to its own side and drops.
		for i in _halves.size():
			var side := -1.0 if i == 0 else 1.0
			var half := _halves[i]
			half.position = Vector3(side * (size.x + 0.03) / 2.0 + side * t * 1.4, -t * t * 0.9, -t * 0.3)
			half.rotation = Vector3(0, 0, (_band_tilt if i == 0 else -_band_tilt) + side * t * 0.9)
	else:
		_band.position = Vector3(_band_from + _band_dir * t * 1.8, -t * t * 0.9, BAND_Z - t * 0.3)
		_band.rotation = Vector3(0, 0, _band_dir * t * 0.9)
	if t >= 1.0:
		_band.visible = false
		_band_fly = -1.0


## The band follows a drag. `delta` is the hand's travel on the card, `mode` from
## BandRules.mode(). Returns true when the band snaps.
func drag_band(delta: Vector2, mode: String) -> bool:
	if not band_on or mode == "":
		return false
	_rest_band()
	if mode == "slide":
		_band.position.x = clampf(delta.x, -BandRules.SLACK, BandRules.SLACK)
	else:
		_split_pose(clampf(delta.y, -BandRules.SLACK, BandRules.SLACK))
	if BandRules.breaks(mode, delta):
		break_band(mode, signf(BandRules.travel(mode, delta)))
		return true
	return false


func release_band() -> void:
	if band_on:
		_rest_band()


func break_band(mode: String, dir: float) -> void:
	if not band_on:
		return
	band_on = false
	band_mode = mode
	_band_dir = dir if dir != 0.0 else 1.0
	_band_from = _band.position.x
	_band_fly = 0.0


## Ways this ticket's band may break (layout "breaks"; sliding when unspecified).
func band_breaks() -> Array:
	if form == null or form.layout.band == null:
		return []
	return form.layout.band.get("breaks", ["slide"])


func _rest_band() -> void:
	_band.position = Vector3(0, 0, BAND_Z)
	_band.rotation = Vector3.ZERO
	_split_pose(0.0)


## Bends the band at its middle: the inner ends move by dy, the outer ends stay.
func _split_pose(dy: float) -> void:
	var half_w := (size.x + 0.03) / 2.0
	_band_tilt = atan2(dy, half_w)
	for i in _halves.size():
		var side := -1.0 if i == 0 else 1.0
		_halves[i].position = Vector3(side * half_w, 0, 0)
		_halves[i].rotation = Vector3(0, 0, _band_tilt if i == 0 else -_band_tilt)


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


## Pointer ray onto the card's plane, in card coordinates (or null).
func card_point(from: Vector3, dir: Vector3) -> Variant:
	var plane := Plane(global_basis.z.normalized(), global_position)
	var hit = plane.intersects_ray(from, dir)
	if hit == null:
		return null
	var p := to_local(hit)
	return Vector2(p.x, p.y)


## True when the ray lands on the card (with the same slack as flaps).
func on_card(from: Vector3, dir: Vector3) -> bool:
	var p = card_point(from, dir)
	return p != null and absf(p.x) <= size.x / 2.0 + GRAB_PAD and absf(p.y) <= size.y / 2.0 + GRAB_PAD


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
		return {"flap": i, "point": p, "mate": FlapLayout.mate(frames, i, p.y, _free)}
	return {}


func shared_edge_y(i: int, j: int) -> float:
	return FlapLayout.shared_edge_y(frames, i, j)


## Point on flap i's free edge, in world space (for paper flecks).
func flap_edge_world(i: int, y_sign: float) -> Vector3:
	var s := sims[i]
	return flaps[i].to_global(Vector3(s.f, y_sign * s.h / 2.0, 0.05))


func _free(i: int) -> bool:
	return not sims[i].open and not sims[i].auto


func _build_flaps() -> void:
	for f in flaps:
		f.queue_free()
	flaps.clear()
	sims.clear()
	frames = FlapLayout.build(form.layout)
	var canvas := TicketArt.canvas_size(form)
	for i in frames.size():
		var fr: Dictionary = frames[i]
		var sim := FlapSim.new(fr.w, fr.h)
		var mesh := FlapMesh.new()
		var xf: Transform2D = fr.xf
		mesh.position = Vector3(xf.origin.x, xf.origin.y, FLAP_Z)
		mesh.rotation = Vector3(0, 0, xf.get_rotation())
		add_child(mesh)
		var r: Rect2 = fr.rect
		var card := size
		var uv_of := func(x: float, y: float) -> Vector2:
			var cp := FlapLayout.to_canvas(xf * Vector2(x, y), canvas, card)
			return Vector2((cp.x - r.position.x) / r.size.x, (cp.y - r.position.y) / r.size.y)
		var seg_y := clampi(roundi(14.0 * fr.h / 1.9), 4, 14)
		mesh.setup(sim, _covers[form.art_key()][i], uv_of, 26, seg_y)
		sims.append(sim)
		flaps.append(mesh)


## A band across the middle, printed on both faces, slightly wider than the card.
## Built as two halves so it can also tear in the middle.
func _build_band() -> void:
	for c in _band.get_children():
		c.queue_free()
	_halves.clear()
	if form.layout.band == null:
		return
	var h := float(form.layout.band.height)
	var w := size.x + 0.03
	var d := THICKNESS + 0.03
	var tex: Texture2D = _band_tex[form.art_key()]
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var pivot := Node3D.new()
		_band.add_child(pivot)
		_halves.append(pivot)
		var piece := Node3D.new()
		piece.position = Vector3(-side * w / 4.0, 0, 0)  # the half reaches inward from its pivot
		pivot.add_child(piece)
		var core := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(w / 2.0, h, d)
		core.mesh = box
		core.material_override = _band_material(tex, 0.0, 1.0)  # thin edges show the print
		piece.add_child(core)
		# The front (-z) face is turned around, so its print runs the other way.
		var u_back := 0.0 if i == 0 else 0.5
		var u_front := 0.5 if i == 0 else 0.0
		for face in [-1.0, 1.0]:
			var q := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(w / 2.0, h)
			q.mesh = quad
			q.material_override = _band_material(tex, u_front if face < 0 else u_back, 0.5)
			q.position = Vector3(0, 0, face * (d / 2.0 + 0.0004))
			if face < 0:
				q.rotation = Vector3(0, PI, 0)
			piece.add_child(q)
	_rest_band()


func _band_material(tex: Texture2D, u0: float, du: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("front_tex", tex)
	m.set_shader_parameter("uv_rect", Vector4(u0, 0.0, du, 1.0))
	return m
