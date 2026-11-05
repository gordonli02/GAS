extends Node3D
## Milestone 2 test scene: one ticket form on a plain grey table, for judging
## the tear against the web build. Rooms, machine and economy come later.

const FORM_UID := "core:catch"
const SEED := "G-0001"
const TABLE_COLOR := Color("#8b8b90")
const TRAY_COLOR := Color("#8d6b42")

var painter := TicketPainter.new()
var camera := CameraRig.new()
var view := TicketView.new()
var flecks := Flecks.new()
var flow := TicketFlow.new()
var input := TicketInput.new()
var tray := Node3D.new()
var pile := DiscardPile.new()
var _box: TicketBox
var _stack: MeshInstance3D
var _stack_mat := StandardMaterial3D.new()


func _ready() -> void:
	add_child(painter)
	_build_room()
	add_child(camera)
	camera.current = true
	view.painter = painter
	view.visible = false
	add_child(view)
	add_child(flecks)
	add_child(tray)
	_build_tray()
	pile.painter = painter
	add_child(pile)

	var form := Packs.form(FORM_UID)
	_box = BoxGenerator.build(form, SEED)
	flow.camera = camera
	flow.view = view
	flow.flecks = flecks
	flow.tray = tray
	flow.pile = pile
	flow.next_ticket = _next_ticket
	add_child(flow)
	input.flow = flow
	add_child(input)
	get_viewport().size_changed.connect(_place_tray_and_pile)
	_place_tray_and_pile()
	_stack_mat.albedo_texture = await pile.art(form)


func _next_ticket() -> Dictionary:
	if _box.cursor >= _box.size:
		_box = BoxGenerator.build(_box.form, _box.seed + "+")
	var t: Dictionary = _box.tickets[_box.cursor]
	_box.cursor += 1
	return {"form": _box.form, "ticket": t}


func _build_room() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2b2d33")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff0dc")
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var key := SpotLight3D.new()
	key.position = Vector3(2, 13, 5)
	key.look_at_from_position(key.position, Vector3.ZERO)
	key.spot_range = 40.0
	key.spot_angle = rad_to_deg(PI / 2.9)
	key.spot_angle_attenuation = 0.6
	key.light_energy = 1.4
	key.shadow_enabled = true
	key.shadow_bias = 0.2
	key.shadow_normal_bias = 3.0
	add_child(key)

	var table := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(15, 0.4, 12.5)
	table.mesh = box
	table.position = Vector3(0, -0.2, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = TABLE_COLOR
	mat.roughness = 0.9
	table.material_override = mat
	add_child(table)


## The open tray the tickets come from, with a stack in it.
func _build_tray() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = TRAY_COLOR
	var jw := 2.12
	var th := 2.0
	for spec in [[Vector3(jw + 0.14, 0.04, th + 0.14), Vector3(0, 0.02, 0)],
			[Vector3(0.04, 0.36, th + 0.14), Vector3(-(jw / 2 + 0.07), 0.18, 0)],
			[Vector3(0.04, 0.36, th + 0.14), Vector3(jw / 2 + 0.07, 0.18, 0)],
			[Vector3(jw + 0.14, 0.36, 0.04), Vector3(0, 0.18, th / 2 + 0.07)],
			[Vector3(jw + 0.14, 0.36, 0.04), Vector3(0, 0.18, -(th / 2 + 0.07))]]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = spec[0]
		m.mesh = b
		m.position = spec[1]
		m.material_override = wood
		tray.add_child(m)
	_stack = MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(1.4, 0.36, 2.0)
	_stack.mesh = sb
	_stack.position = Vector3(0, 0.04 + 0.18, 0)
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color("#ece6d7")
	_stack.material_override = edge
	tray.add_child(_stack)
	var top := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.4, 2.0)
	top.mesh = q
	top.rotation = Vector3(-PI / 2, 0, 0)
	top.position = Vector3(0, 0.181, 0)
	top.material_override = _stack_mat
	_stack.add_child(top)


func _place_tray_and_pile() -> void:
	var sx := minf(5.3, camera.table_half_width() * 0.72)
	tray.position = Vector3(sx - 0.05, 0, 1.2)
	tray.rotation = Vector3(0, -0.12, 0)
	pile.position = Vector3(-sx, 0, 1.25)
