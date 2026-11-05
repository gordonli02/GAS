class_name Flecks
extends MeshInstance3D
## Paper flecks and win confetti: up to 140 screen-size points with gravity,
## as in the web build.

const MAX := 140
const GRAVITY := 5.2

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _col := PackedColorArray()
var _life := PackedFloat32Array()
var _next := 0
var _mesh := ArrayMesh.new()
var _mat := StandardMaterial3D.new()


func _ready() -> void:
	_pos.resize(MAX)
	_vel.resize(MAX)
	_col.resize(MAX)
	_life.resize(MAX)
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.use_point_size = true
	material_override = _mat
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 100.0


func emit(at: Vector3, color: Color, speed: float, n := 1) -> void:
	for k in n:
		var i := _next
		_next = (_next + 1) % MAX
		_pos[i] = at
		_col[i] = color
		_life[i] = 0.5 + randf() * 0.5
		_vel[i] = Vector3((randf() - 0.5) * speed, randf() * speed * 0.9, (randf() - 0.2) * speed * 0.7)


func _process(dt: float) -> void:
	_mat.point_size = maxf(2.0, roundf(get_viewport().get_visible_rect().size.y / 170.0))
	var pts := PackedVector3Array()
	var cols := PackedColorArray()
	for i in MAX:
		if _life[i] <= 0.0:
			continue
		_life[i] -= dt
		if _life[i] <= 0.0:
			continue
		_vel[i].y -= dt * GRAVITY
		_pos[i] += _vel[i] * dt
		pts.append(_pos[i])
		cols.append(_col[i])
	_mesh.clear_surfaces()
	if pts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pts
	arrays[Mesh.ARRAY_COLOR] = cols
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
