class_name RoomKit
extends RefCounted
## The web build's low-poly construction kit (box, cyl, lathe, panel, flat, M, B, TB),
## so the room builders read line for line like the source.
##
## Geometry is three.js r128's, vertex for vertex (same segment start angles, same
## triangle order), so the facets of the low-poly props land where they did on the web.
## Faces are flat shaded like MeshPhong flatShading. three.js winds front faces
## counter-clockwise, Godot clockwise: triangles are emitted reversed.
## Rotations use three.js's XYZ Euler order.
##
## Every mesh gets a click collider (three.js raycast hit every visible mesh of the
## room, front faces only), so props in front of the machine block clicks on it.

const TEX_DIR := "res://assets/rooms/"

var colliders := true
var _mats := {}
var _plain := {}

static var _geo := {}
static var _shapes := {}
static var _tex := {}


# --- materials ---------------------------------------------------------------------

## MeshPhongMaterial({color, flatShading, shininess: o.s ?? 6, specular: o.sp ?? 0x151515,
## opacity: o.a ?? 1}), cached like the web build's M().
func M(color: int, o := {}) -> StandardMaterial3D:
	var key := "%x|%s" % [color, str(o)]
	if _mats.has(key):
		return _mats[key]
	var m := phong(_hex(color), o.get("s", 6), o.get("sp", 0x151515))
	var a: float = o.get("a", 1.0)
	if a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = a
	_mats[key] = m
	return m


## The web build's shared chrome.
func chrome() -> StandardMaterial3D:
	return M(0xc5ced6, {"s": 70, "sp": 0xffffff})


func phong(c: Color, shininess := 6.0, specular := 0x151515) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	m.roughness = clampf(1.0 - shininess / 100.0, 0.2, 1.0)
	var sp := _hex(specular)
	m.metallic_specular = clampf((sp.r + sp.g + sp.b) / 3.0 * 1.2, 0.05, 1.0)
	return m


## A lit material with a room texture (MeshPhongMaterial({map})).
func phong_tex(name: String, repeat := Vector2.ONE, shininess := 30.0, specular := 0x111111) -> StandardMaterial3D:
	var m := phong(Color.WHITE, shininess, specular)
	m.albedo_texture = tex(name)
	m.uv1_scale = Vector3(repeat.x, repeat.y, 1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	return m


## MeshBasicMaterial({color}).
func B(color: int) -> StandardMaterial3D:
	var key := "B%x" % color
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = _hex(color)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mats[key] = m
	return _mats[key]


## MeshBasicMaterial({map}).
func TB(name: String) -> StandardMaterial3D:
	var key := "TB" + name
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex(name)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_mats[key] = m
	return _mats[key]


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(TEX_DIR + name + ".png")
	return _tex[name]


static func _hex(c: int) -> Color:
	return Color.hex((c << 8) | 0xff)


# --- placing (the web build's put/box/cyl/lathe/panel/flat) ---------------------------

func group(p: Node3D, x := 0.0, y := 0.0, z := 0.0, ry := 0.0) -> Node3D:
	var g := Node3D.new()
	g.rotation_order = EULER_ORDER_XYZ
	g.position = Vector3(x, y, z)
	g.rotation.y = ry
	p.add_child(g)
	return g


## put(): castShadow and receiveShadow both follow `shadow`.
func put(p: Node3D, mesh: ArrayMesh, mat: Material, x: float, y: float, z: float, ry := 0.0, shadow := true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.rotation_order = EULER_ORDER_XYZ
	m.mesh = mesh
	m.material_override = mat if shadow else plain(mat)
	m.position = Vector3(x, y, z)
	m.rotation.y = ry
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(m)
	if colliders:
		_collide(m)
	return m


func box(p: Node3D, w: float, h: float, d: float, mat: Material, x: float, y: float, z: float, ry := 0.0) -> MeshInstance3D:
	return put(p, box_geo(w, h, d), mat, x, y + h / 2.0, z, ry)


func cyl(p: Node3D, rt: float, rb: float, h: float, seg: int, mat: Material, x: float, y: float, z: float) -> MeshInstance3D:
	return put(p, cylinder_geo(rt, rb, h, seg), mat, x, y + h / 2.0, z)


func lathe(p: Node3D, pts: Array, seg: int, mat: Material, x: float, y: float, z: float) -> MeshInstance3D:
	return put(p, lathe_geo(pts, seg), mat, x, y, z)


## panel(): an upright plane that neither casts nor receives shadows (three.js defaults).
func panel(p: Node3D, w: float, h: float, mat: Material, x: float, y: float, z: float, ry := 0.0) -> MeshInstance3D:
	return put(p, plane_geo(w, h), mat, x, y, z, ry, false)


## flat(): a plane lying face up; receives shadows, casts none.
func flat(p: Node3D, w: float, d: float, mat: Material, x: float, y: float, z: float, rz := 0.0) -> MeshInstance3D:
	var m := put(p, plane_geo(w, d), mat, x, y, z)
	m.rotation = Vector3(-PI / 2.0, 0, rz)
	no_cast(m)
	return m


static func no_cast(m: MeshInstance3D) -> MeshInstance3D:
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## The same material without received shadows (receiveShadow is per mesh in three.js,
## per material here).
func plain(mat: Material) -> Material:
	if not mat is BaseMaterial3D:
		return mat
	if not _plain.has(mat):
		var m: BaseMaterial3D = mat.duplicate()
		m.disable_receive_shadows = true
		_plain[mat] = m
	return _plain[mat]


func _collide(m: MeshInstance3D) -> void:
	var mesh: ArrayMesh = m.mesh
	if not _shapes.has(mesh):
		_shapes[mesh] = mesh.create_trimesh_shape()
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = _shapes[mesh]
	body.add_child(shape)
	m.add_child(body)


# --- three.js r128 geometry ------------------------------------------------------------

static func box_geo(w: float, h: float, d: float) -> ArrayMesh:
	var key := "box %s %s %s" % [w, h, d]
	if _geo.has(key):
		return _geo[key]
	var g := _Geo.new()
	# buildPlane(u, v, w, udir, vdir, width, height, depth) for px, nx, py, ny, pz, nz.
	g.box_face(2, 1, 0, -1, -1, d, h, w)
	g.box_face(2, 1, 0, 1, -1, d, h, -w)
	g.box_face(0, 2, 1, 1, 1, w, d, h)
	g.box_face(0, 2, 1, 1, -1, w, d, -h)
	g.box_face(0, 1, 2, 1, -1, w, h, d)
	g.box_face(0, 1, 2, -1, -1, w, h, -d)
	_geo[key] = g.mesh()
	return _geo[key]


static func plane_geo(w: float, h: float) -> ArrayMesh:
	var key := "plane %s %s" % [w, h]
	if _geo.has(key):
		return _geo[key]
	var g := _Geo.new()
	for iy in 2:
		for ix in 2:
			g.vert(Vector3(ix * w - w / 2.0, -(iy * h - h / 2.0), 0), Vector2(ix, 1 - iy))
	g.quad(0, 2, 3, 1)
	_geo[key] = g.mesh()
	return _geo[key]


static func cylinder_geo(rt: float, rb: float, h: float, seg: int, theta_start := 0.0, theta_len := TAU) -> ArrayMesh:
	var key := "cyl %s %s %s %d %s %s" % [rt, rb, h, seg, theta_start, theta_len]
	if _geo.has(key):
		return _geo[key]
	var g := _Geo.new()
	var idx := []
	for y in 2:
		var row := []
		var r := y * (rb - rt) + rt
		for x in seg + 1:
			var th := float(x) / seg * theta_len + theta_start
			row.append(g.vert(Vector3(r * sin(th), -y * h + h / 2.0, r * cos(th)), Vector2(float(x) / seg, 1 - y)))
		idx.append(row)
	for x in seg:
		g.quad(idx[0][x], idx[1][x], idx[1][x + 1], idx[0][x + 1])
	for top in [true, false]:
		var r := rt if top else rb
		if r <= 0.0:
			continue
		var sgn := 1.0 if top else -1.0
		var c0 := g.count()
		for x in seg:
			g.vert(Vector3(0, h / 2.0 * sgn, 0), Vector2(0.5, 0.5))
		var r0 := g.count()
		for x in seg + 1:
			var th := float(x) / seg * theta_len + theta_start
			g.vert(Vector3(r * sin(th), h / 2.0 * sgn, r * cos(th)), Vector2(cos(th) * 0.5 + 0.5, sin(th) * 0.5 * sgn + 0.5))
		for x in seg:
			if top:
				g.tri(r0 + x, r0 + x + 1, c0 + x)
			else:
				g.tri(r0 + x + 1, r0 + x, c0 + x)
	_geo[key] = g.mesh()
	return _geo[key]


static func cone_geo(r: float, h: float, seg: int) -> ArrayMesh:
	return cylinder_geo(0.0, r, h, seg)


static func lathe_geo(pts: Array, seg: int) -> ArrayMesh:
	var key := "lathe %s %d" % [str(pts), seg]
	if _geo.has(key):
		return _geo[key]
	var g := _Geo.new()
	var n := pts.size()
	for i in seg + 1:
		var phi := float(i) / seg * TAU
		for j in n:
			var p: Array = pts[j]
			g.vert(Vector3(p[0] * sin(phi), p[1], p[0] * cos(phi)), Vector2(float(i) / seg, float(j) / (n - 1)))
	for i in seg:
		for j in n - 1:
			var base := j + i * n
			g.quad(base, base + n, base + n + 1, base + 1)
	_geo[key] = g.mesh()
	return _geo[key]


static func ico_geo(radius: float, detail: int) -> ArrayMesh:
	var key := "ico %s %d" % [radius, detail]
	if _geo.has(key):
		return _geo[key]
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v := [-1, t, 0, 1, t, 0, -1, -t, 0, 1, -t, 0, 0, -1, t, 0, 1, t, 0, -1, -t, 0, 1, -t, t, 0, -1, t, 0, 1, -t, 0, -1, -t, 0, 1]
	var f := [0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
		3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1]
	var g := _Geo.new()
	var cols := detail + 1
	for fi in range(0, f.size(), 3):
		var a := Vector3(v[f[fi] * 3], v[f[fi] * 3 + 1], v[f[fi] * 3 + 2])
		var b := Vector3(v[f[fi + 1] * 3], v[f[fi + 1] * 3 + 1], v[f[fi + 1] * 3 + 2])
		var c := Vector3(v[f[fi + 2] * 3], v[f[fi + 2] * 3 + 1], v[f[fi + 2] * 3 + 2])
		var grid := []
		for i in cols + 1:
			var aj := a.lerp(c, float(i) / cols)
			var bj := b.lerp(c, float(i) / cols)
			var rows := cols - i
			var row := []
			for j in rows + 1:
				row.append(aj if (j == 0 and i == cols) else aj.lerp(bj, float(j) / rows))
			grid.append(row)
		for i in cols:
			for j in 2 * (cols - i) - 1:
				var k := j / 2
				var tri: Array = [grid[i][k + 1], grid[i + 1][k], grid[i][k]] if j % 2 == 0 \
					else [grid[i][k + 1], grid[i + 1][k + 1], grid[i + 1][k]]
				var s := g.count()
				for p: Vector3 in tri:
					g.vert(p.normalized() * radius, Vector2.ZERO)
				g.tri(s, s + 1, s + 2)
	_geo[key] = g.mesh()
	return _geo[key]


static func torus_geo(radius: float, tube: float, radial: int, tubular: int, arc := TAU) -> ArrayMesh:
	var key := "torus %s %s %d %d %s" % [radius, tube, radial, tubular, arc]
	if _geo.has(key):
		return _geo[key]
	var g := _Geo.new()
	for j in radial + 1:
		for i in tubular + 1:
			var u := float(i) / tubular * arc
			var w := float(j) / radial * TAU
			g.vert(Vector3((radius + tube * cos(w)) * cos(u), (radius + tube * cos(w)) * sin(u), tube * sin(w)),
				Vector2(float(i) / tubular, float(j) / radial))
	for j in range(1, radial + 1):
		for i in range(1, tubular + 1):
			var a := (tubular + 1) * j + i - 1
			var b := (tubular + 1) * (j - 1) + i - 1
			var c := (tubular + 1) * (j - 1) + i
			var d := (tubular + 1) * j + i
			g.quad(a, b, c, d)
	_geo[key] = g.mesh()
	return _geo[key]


## Indexed three.js-style geometry turned into a flat-shaded Godot mesh.
class _Geo:
	var pos := PackedVector3Array()
	var uv := PackedVector2Array()
	var tris := PackedInt32Array()

	func count() -> int:
		return pos.size()

	func vert(p: Vector3, t: Vector2) -> int:
		pos.append(p)
		uv.append(t)
		return pos.size() - 1

	func tri(a: int, b: int, c: int) -> void:
		tris.append_array([a, b, c])

	## three.js's quad split: (a, b, d) and (b, c, d).
	func quad(a: int, b: int, c: int, d: int) -> void:
		tri(a, b, d)
		tri(b, c, d)

	func box_face(u: int, v: int, w: int, udir: float, vdir: float, width: float, height: float, depth: float) -> void:
		var s := count()
		for iy in 2:
			for ix in 2:
				var p := Vector3()
				p[u] = (ix * width - width / 2.0) * udir
				p[v] = (iy * height - height / 2.0) * vdir
				p[w] = depth / 2.0
				vert(p, Vector2(ix, 1 - iy))
		quad(s, s + 2, s + 3, s + 1)

	func mesh() -> ArrayMesh:
		var vs := PackedVector3Array()
		var ns := PackedVector3Array()
		var ts := PackedVector2Array()
		for i in range(0, tris.size(), 3):
			var a := pos[tris[i]]
			var n := (pos[tris[i + 1]] - a).cross(pos[tris[i + 2]] - a)
			if n.length_squared() < 1e-14:
				continue   # degenerate (lathe and cylinder centres)
			n = n.normalized()
			for k in [0, 2, 1]:   # counter-clockwise (three.js) to clockwise (Godot)
				vs.append(pos[tris[i + k]])
				ns.append(n)
				var t := uv[tris[i + k]]
				ts.append(Vector2(t.x, 1.0 - t.y))   # three.js v runs up, Godot's down
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vs
		arrays[Mesh.ARRAY_NORMAL] = ns
		arrays[Mesh.ARRAY_TEX_UV] = ts
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m
