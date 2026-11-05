class_name CameraRig
extends Camera3D
## Table camera: fixed base pose, slight mouse parallax and win shake.
## The machine swing is added in milestone 4.

const BASE_POS := Vector3(0, 5.6, 10.5)
const LOOK_AT := Vector3(0, 2.2, 0)
const FOV := 42.0

var base_basis := Basis.IDENTITY
var shake := 0.0
var mouse := Vector2.ZERO          ## smoothed pointer, -1..1 (y down)
var _mouse_raw := Vector2.ZERO
var _time := 0.0


func _ready() -> void:
	fov = FOV
	near = 0.5
	far = 130.0
	position = BASE_POS
	look_at(LOOK_AT)
	base_basis = basis


func _process(dt: float) -> void:
	_time += dt
	var vp := get_viewport()
	var size := vp.get_visible_rect().size
	var m := vp.get_mouse_position()
	if size.x > 0 and size.y > 0:
		_mouse_raw = Vector2(m.x / size.x * 2.0 - 1.0, m.y / size.y * 2.0 - 1.0).clamp(Vector2(-1, -1), Vector2(1, 1))
	mouse = mouse.lerp(_mouse_raw, 1.0 - exp(-dt * 7.0))
	shake *= exp(-dt * 9.0)
	var sh := shake * 0.06
	position = BASE_POS + Vector3(sin(_time * 71.0) * sh + mouse.x * 0.16, cos(_time * 83.0) * sh - mouse.y * 0.09, 0)
	basis = base_basis


## Where a held ticket sits in front of the camera, and its facing.
func hold_pose(card: Vector2) -> Transform3D:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	var vis := 2.0 * tan(deg_to_rad(FOV) / 2.0)
	var d := maxf(maxf(card.y, 2.0) / (0.68 * vis), maxf(card.x, 1.4) * 1.5 / (vis * aspect))
	var fwd := -base_basis.z
	var up := base_basis.y
	return Transform3D(base_basis, BASE_POS + fwd * d + up * 0.1)


## Half the visible table width at the depth of the tray, for placing tray and pile.
func table_half_width() -> float:
	var size := get_viewport().get_visible_rect().size
	var vis := 2.0 * tan(deg_to_rad(FOV) / 2.0)
	return vis * 12.0 * size.x / maxf(size.y, 1.0) / 2.0
