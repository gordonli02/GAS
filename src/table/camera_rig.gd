class_name CameraRig
extends Camera3D
## Table camera with slight mouse parallax and win shake, and the swing to the
## machine: 0.6 s, eased, the machine turning to face the player as the camera arrives.

const BASE_POS := Vector3(0, 5.6, 10.5)
const LOOK_AT := Vector3(0, 2.2, 0)
const FOV := 42.0
const SWING_TIME := 0.6

var base_basis := Basis.IDENTITY
var shake := 0.0
var mouse := Vector2.ZERO          ## smoothed pointer, -1..1 (y down)
var at_machine := false            ## where the camera is heading
var cam := 0.0                     ## 0 at the table, 1 at the machine
var machine: Node3D                ## turns to face the camera as it arrives
var machine_yaw := 0.0             ## the machine's resting yaw
var _machine_pose := Transform3D.IDENTITY
var _mouse_raw := Vector2.ZERO
var _time := 0.0


func _ready() -> void:
	fov = FOV
	near = 0.5
	far = 130.0
	position = BASE_POS
	look_at(LOOK_AT)
	base_basis = basis
	get_viewport().size_changed.connect(fit_machine_view)


## Places the machine view for a machine standing at `pos` (world) with resting yaw.
func set_machine(node: Node3D, pos: Vector3, yaw: float) -> void:
	machine = node
	machine_yaw = yaw
	_machine_pose.origin = pos
	fit_machine_view()


## Straight in front of the machine, far enough back to fit it on any window shape.
func fit_machine_view() -> void:
	if machine == null:
		return
	var p := machine.global_position
	var look := Vector3(p.x, 0.4, p.z)
	var base := Vector3(p.x, 0.4, p.z + 15.4)
	var size := get_viewport().get_visible_rect().size
	var vis := 2.0 * tan(deg_to_rad(FOV) / 2.0)
	var length := base.distance_to(look)
	var k := maxf(1.0, 7.6 / (length * vis * size.x / maxf(size.y, 1.0)))
	var pos := look.lerp(base, k)
	_machine_pose = Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos)


func _process(dt: float) -> void:
	_time += dt
	var vp := get_viewport()
	var size := vp.get_visible_rect().size
	var m := vp.get_mouse_position()
	if size.x > 0 and size.y > 0:
		_mouse_raw = Vector2(m.x / size.x * 2.0 - 1.0, m.y / size.y * 2.0 - 1.0).clamp(Vector2(-1, -1), Vector2(1, 1))
	mouse = mouse.lerp(_mouse_raw, 1.0 - exp(-dt * 7.0))
	shake *= exp(-dt * 9.0)
	cam = clampf(cam + (1.0 if at_machine else -1.0) * dt / SWING_TIME, 0.0, 1.0)
	var swing := _ease(cam)
	var sh := shake * 0.06
	var table_pos := BASE_POS + Vector3(sin(_time * 71.0) * sh + mouse.x * 0.16, cos(_time * 83.0) * sh - mouse.y * 0.09, 0)
	position = table_pos.lerp(_machine_pose.origin, swing)
	basis = Basis(base_basis.get_rotation_quaternion().slerp(_machine_pose.basis.get_rotation_quaternion(), swing))
	if machine:
		machine.rotation.y = machine_yaw * (1.0 - swing)


## Where a held ticket sits in front of the table camera, and its facing.
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


static func _ease(t: float) -> float:
	return 2.0 * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0
