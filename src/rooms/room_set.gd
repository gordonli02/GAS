class_name RoomSet
extends Node3D
## The three rooms and their light rigs (web build: `scenes` and setScene). A room is
## built the first time it is shown and kept hidden afterwards.
##
## Lighting: the web build lit with three.js r128 legacy lights and wrote colours out
## without sRGB conversion. The rig keeps its colours, intensities, positions and
## falloff ranges; the conversions are below.
## - Hemisphere light: Godot has none. Ambient carries the sky/ground average and a
##   pair of shadowless directional lights (down, and a negative one up) add and take
##   away half the difference, so up faces get the sky colour, down faces the ground.
## - Spot and point lights: no inverse-square term (attenuation 0) and the web build's
##   linear falloff matched at the table.
## - "gains" (hemisphere, key, points) scale each part of the rig. Godot lights in
##   linear space and the web build did not, so equal numbers look brighter here; the
##   gains were fitted by least squares to renders of the web build from the same
##   camera (tools/preview_rooms --gains, one light at a time).
## - "table_dim" (optional) scales the whole rig while the camera is at the table and
##   fades out on the swing to the machine, so the machine view keeps the fitted light.

const ORDER := ["diner", "bar", "bingo"]
const ROOMS := {
	"diner": {"name": "Diner", "bg": 0x24293a, "fog": [0x24293a, 34, 80], "hemi": [0xfff0dc, 0x70504a, .46],
		"key": [0xfff0cc, .5, Vector3(2, 13, 5)], "p1": [0xffb35c, .22, Vector3(-5, 6, 1)], "p2": [0xff4a6a, .2, Vector3(-6, 4, -11)],
		"machine": [Vector3(10.8, -3.25, -13), -.35], "gains": [.91, .62, .84],
		"table_dim": .81},   # G: table view 5% darker on screen (M5 review); 0.81 on the lights gives that
	"bar": {"name": "Bar", "bg": 0x0e0a10, "fog": [0x0e0a10, 26, 62], "hemi": [0xa07a78, 0x281612, .42],
		"key": [0xffc27a, .8, Vector3(-2, 12, 4)], "p1": [0xd82bd0, .6, Vector3(9, 3, -10)], "p2": [0xff5a2a, .28, Vector3(-5, 4, -12)],
		"machine": [Vector3(11, -3.25, -12.8), -.45], "gains": [1.34, .64, 1.12]},
	"bingo": {"name": "Bingo Hall", "bg": 0x3d463f, "fog": [0x3d463f, 30, 62], "hemi": [0xe8f7e6, 0x756b58, .56],
		"key": [0xf1fff1, .36, Vector3(0, 14, 3)], "p1": [0xcff4d7, .14, Vector3(-6, 8, -3)], "p2": [0xffe08a, .12, Vector3(5, 6, -8)],
		"machine": [Vector3(11.3, -3.25, -13), -.4], "gains": [.47, 1.17, 1.5]},
}
const KEY_RANGE := 40.0        ## web: 70 with linear falloff; matched at the table and the back wall
const POINT_RANGE := 34.0
const POINT_DECAY := 1.4
## Replaces every room's gains when set (for fitting them).
static var gains_override: Array = []

var id := ""
var kit := RoomKit.new()
var env := Environment.new()
var key := SpotLight3D.new()
var _rooms := {}
var _sky_down := DirectionalLight3D.new()
var _sky_up := DirectionalLight3D.new()
var _points: Array[OmniLight3D] = [OmniLight3D.new(), OmniLight3D.new()]
var _view := 0.0      ## 0 at the table, 1 at the machine (CameraRig.cam)
var _energy := {}     ## light -> energy before table_dim


## The rig is made here rather than in _ready so a RoomSet works (and frees cleanly)
## outside the tree too.
func _init() -> void:
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 1.0
	env.fog_depth_curve = 1.0
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	for l in [_sky_down, _sky_up]:
		l.light_specular = 0.0
		l.shadow_enabled = false
		add_child(l)
	_sky_down.rotation = Vector3(-PI / 2, 0, 0)
	_sky_up.rotation = Vector3(PI / 2, 0, 0)
	_sky_up.light_negative = true
	key.spot_range = KEY_RANGE
	key.spot_angle = rad_to_deg(PI / 2.9)
	key.spot_angle_attenuation = 0.6
	key.spot_attenuation = 0.0
	key.shadow_enabled = true
	key.shadow_reverse_cull_face = true
	key.shadow_bias = 0.02
	key.shadow_normal_bias = 0.5
	add_child(key)
	for p in _points:
		p.omni_range = POINT_RANGE
		p.omni_attenuation = 0.0
		add_child(p)


func room(room_id: String) -> Dictionary:
	return ROOMS[room_id]


func machine_pos() -> Vector3:
	return ROOMS[id].machine[0]


func machine_yaw() -> float:
	return ROOMS[id].machine[1]


func set_room(room_id: String) -> void:
	assert(ROOMS.has(room_id), "unknown room " + room_id)
	id = room_id
	if not _rooms.has(room_id):
		var g := Node3D.new()
		g.name = room_id
		add_child(g)
		match room_id:
			"diner": RoomDiner.build(kit, g)
			"bar": RoomBar.build(kit, g)
			"bingo": RoomBingo.build(kit, g)
		_rooms[room_id] = g
	for k in _rooms:
		_rooms[k].visible = k == room_id
	_set_colliders(room_id)
	_light(ROOMS[room_id])


## Hidden rooms must not catch clicks.
func _set_colliders(room_id: String) -> void:
	for k in _rooms:
		for body in _rooms[k].find_children("*", "StaticBody3D", true, false):
			(body as StaticBody3D).collision_layer = 1 if k == room_id else 0


func _light(r: Dictionary) -> void:
	var gains: Array = gains_override if not gains_override.is_empty() else r.gains
	_energy.clear()
	env.background_color = _c(r.bg)
	env.fog_light_color = _c(r.fog[0])
	env.fog_depth_begin = r.fog[1]
	env.fog_depth_end = r.fog[2]
	var h := hemisphere(_c(r.hemi[0]), _c(r.hemi[1]), r.hemi[2] * gains[0])
	env.ambient_light_color = h.ambient
	for l: DirectionalLight3D in [_sky_down, _sky_up]:
		l.visible = h.half_energy > 0.0
		l.light_color = h.half
		_energy[l] = h.half_energy
	key.light_color = _c(r.key[0])
	_energy[key] = r.key[1] * gains[1]
	key.transform = Transform3D(Basis.looking_at(-r.key[2]), r.key[2])   # aimed at the table centre
	for n in 2:
		var p: Array = r["p%d" % (n + 1)]
		var l := _points[n]
		l.light_color = _c(p[0])
		l.position = p[2]
		_energy[l] = p[1] * gains[2] * point_scale(p[2].length())
	_energy[env] = h.ambient_energy
	_apply_dim()


## Follows the camera: table_dim applies at the table and fades out toward the machine.
func set_view(cam: float) -> void:
	if is_equal_approx(cam, _view):
		return
	_view = cam
	_apply_dim()


## How much of the rig is lit now (1 at the machine; the room's table_dim at the table).
func dim() -> float:
	if id == "" or not gains_override.is_empty():
		return 1.0
	return lerpf(float(ROOMS[id].get("table_dim", 1.0)), 1.0, clampf(_view, 0.0, 1.0))


func _apply_dim() -> void:
	var f := dim()
	for o in _energy:
		if o == env:
			env.ambient_light_energy = _energy[o] * f
		else:
			(o as Light3D).light_energy = _energy[o] * f


## A hemisphere light as ambient (the sky/ground average) plus half the difference,
## added from above and taken away from below. Colours in sRGB, mixed in linear.
static func hemisphere(sky: Color, ground: Color, intensity: float) -> Dictionary:
	var s := sky.srgb_to_linear()
	var g := ground.srgb_to_linear()
	var avg := (s + g) / 2.0
	var half := Color(maxf((s.r - g.r) / 2.0, 0.0), maxf((s.g - g.g) / 2.0, 0.0), maxf((s.b - g.b) / 2.0, 0.0))
	var top := maxf(half.r, maxf(half.g, half.b))
	return {
		"ambient": Color(avg.r, avg.g, avg.b).linear_to_srgb(), "ambient_energy": intensity,
		"half": (Color(half.r / top, half.g / top, half.b / top) if top > 0.0 else Color.BLACK).linear_to_srgb(),
		"half_energy": top * intensity,
	}


## The web build's point falloff (1 - d/range)^decay over Godot's window at distance d.
static func point_scale(d: float) -> float:
	var web := pow(clampf(1.0 - d / POINT_RANGE, 0.0, 1.0), POINT_DECAY)
	var godot := pow(maxf(1.0 - pow(d / POINT_RANGE, 4.0), 0.0), 2.0)
	return web / maxf(godot, 0.001)


static func _c(hex: int) -> Color:
	return Color.hex((hex << 8) | 0xff)
