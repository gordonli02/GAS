class_name FlapMesh
extends Node3D
## Draws one FlapSim: a subdivided sheet bent every frame, plus the soft dark
## gradient on the revealed paper next to the fold. The node sits on the hinge;
## local +x runs across the flap away from the hinge, +y along the hinge.

const SHADER := preload("res://src/paper/paper.gdshader")
const SHADE_WIDTH := 0.3
const SHADE_Z := 0.0015

var sim: FlapSim
var _seg_x := 26
var _seg_y := 14
var _uvs := PackedVector2Array()
var _index := PackedInt32Array()
var _base := PackedVector2Array()   ## flat (x, y) of every vertex
var _mesh := ArrayMesh.new()
var _shade_mesh := ArrayMesh.new()
var _sheet := MeshInstance3D.new()
var _shade := MeshInstance3D.new()
var _material := ShaderMaterial.new()

static var _speckle: Texture2D
static var _shade_material: StandardMaterial3D


## uv_of maps a flat flap point (x, y) to the cover texture's UV.
func setup(flap_sim: FlapSim, cover: Texture2D, uv_of: Callable, seg_x := 26, seg_y := 14) -> void:
	sim = flap_sim
	_seg_x = seg_x
	_seg_y = seg_y
	_build_grid(uv_of)
	_material.shader = SHADER
	_material.set_shader_parameter("front_tex", cover)
	_material.set_shader_parameter("back_tex", _speckle_texture())
	_material.set_shader_parameter("has_back", true)
	_sheet.mesh = _mesh
	_sheet.material_override = _material
	_sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_shade.mesh = _shade_mesh
	_shade.material_override = _shade_mat()
	_shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shade.position.z = SHADE_Z
	if _sheet.get_parent() == null:
		add_child(_sheet)
		add_child(_shade)
	refresh()


func set_cover(cover: Texture2D) -> void:
	_material.set_shader_parameter("front_tex", cover)


func refresh() -> void:
	var verts := PackedVector3Array()
	verts.resize(_base.size())
	for i in _base.size():
		var p := _base[i]
		var b := sim.deform(p.x, p.y)
		verts[i] = Vector3(b.x, p.y, b.y)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _index
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_refresh_shade()


func _refresh_shade() -> void:
	_shade.visible = sim.f > 0.01
	if not _shade.visible:
		return
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()
	for j in _seg_y + 1:
		var y := sim.h / 2.0 - sim.h * j / _seg_y
		var fy := minf(sim.w, sim.fold_at(y))
		verts.append(Vector3(fy, y, 0))
		verts.append(Vector3(minf(sim.w, fy + SHADE_WIDTH), y, 0))
		colors.append(Color(0, 0, 0, 0.5))
		colors.append(Color(0, 0, 0, 0))
		if j > 0:
			var a := (j - 1) * 2
			idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	_shade_mesh.clear_surfaces()
	_shade_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _build_grid(uv_of: Callable) -> void:
	_base.clear()
	_uvs.clear()
	_index.clear()
	for j in _seg_y + 1:
		for i in _seg_x + 1:
			var x := sim.w * i / _seg_x
			var y := sim.h / 2.0 - sim.h * j / _seg_y
			_base.append(Vector2(x, y))
			_uvs.append(uv_of.call(x, y))
	var row := _seg_x + 1
	for j in _seg_y:
		for i in _seg_x:
			var a := j * row + i
			_index.append_array([a, a + 1, a + row, a + 1, a + row + 1, a + row])


## Dark grey speckled paper for the flap's inner face (same seed as the web build).
static func _speckle_texture() -> Texture2D:
	if _speckle == null:
		var img := Image.create(100, 144, false, Image.FORMAT_RGB8)
		img.fill(Color("#2a2a30"))
		var r := SeededRng.new("flap")
		for i in 500:
			var c := Color("#34343b") if r.next_float() > 0.5 else Color("#202026")
			img.set_pixel(int(r.next_float() * 100), int(r.next_float() * 144), c)
		_speckle = ImageTexture.create_from_image(img)
	return _speckle


static func _shade_mat() -> StandardMaterial3D:
	if _shade_material == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = false
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_shade_material = m
	return _shade_material
