extends "res://tests/test_case.gd"
## The three rooms: config against the web build, the three.js geometry port, building
## each room, click colliders, and the light conversions.

const SOURCE := "res://reference/last-sale-source.html"


## bg, fog, hemisphere, key, point lights and machine placement are the web build's.
func test_room_configs_match_web() -> void:
	var html := FileAccess.get_file_as_string(SOURCE)
	if not check(html != "", "web source readable"):
		return
	for id in RoomSet.ORDER:
		var line := ""
		for l in html.split("\n"):
			if l.strip_edges().begins_with(id + ":{name:"):
				line = l
		if not check(line != "", "%s: found in the web scenes config" % id):
			continue
		var r: Dictionary = RoomSet.ROOMS[id]
		_near(_nums(_field(line, "bg:([^,]+)")), [r.bg], id + " bg")
		_near(_nums(_field(line, "fog:\\[([^\\]]*)\\]")), [r.fog[0], r.fog[1], r.fog[2]], id + " fog")
		_near(_nums(_field(line, "hemi:\\[([^\\]]*)\\]")), [r.hemi[0], r.hemi[1], r.hemi[2]], id + " hemisphere")
		for k in ["key", "p1", "p2"]:
			var light: Array = r[k]
			var pos: Vector3 = light[2]
			_near(_nums(_field(line, k + ":\\[([^\\[]*)\\[([^\\]]*)\\]\\]", true)), [light[0], light[1], pos.x, pos.y, pos.z], id + " " + k)
		# The machine no longer stands where the web build put it: the M8.6 machine is more
		# than twice as wide, so each room moves it right and turns it less (docs/decisions.md).
		# It still stands on the web build's floor.
		var m: Array = r.machine
		var mp: Vector3 = m[0]
		_near(_nums(_field(line, "machine:\\{pos:\\[([^\\]]*)\\]")).slice(1, 2), [mp.y], id + " machine on the floor")


## Triangle counts follow three.js r128; every face points outward and is wound
## clockwise (Godot's front face) around that normal.
func test_geometry_port() -> void:
	_solid(RoomKit.box_geo(1, 2, 3), 12, "box")
	_solid(RoomKit.cylinder_geo(.5, .7, 1, 8), 8 * 2 + 8 + 8, "cylinder")
	_solid(RoomKit.cone_geo(.5, 1, 4), 4 * 2 - 4 + 4, "cone (no top cap, apex triangles degenerate)")
	_solid(RoomKit.ico_geo(1, 1), 80, "icosahedron detail 1")
	_solid(RoomKit.ico_geo(1, 0), 20, "icosahedron detail 0")
	_solid(RoomKit.lathe_geo([[0, 0], [.3, 0], [.32, 1.4], [.1, 2.7], [0, 2.8]], 7), 7 * 4 * 2 - 7 * 2, "bottle lathe")
	var ico := RoomKit.ico_geo(.9, 1).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var on_sphere := true
	for v in ico:
		on_sphere = on_sphere and is_equal_approx(v.length(), .9)
	check(on_sphere, "icosahedron vertices on the sphere")
	# three.js puts a cylinder's first vertex at +z (sin 0, cos 0): the facets line up.
	var tri := RoomKit.cylinder_geo(1, 1, 1, 3).get_aabb()
	check(is_equal_approx(tri.end.z, 1.0) and is_equal_approx(tri.position.z, -0.5), "3-sided cylinder points at +z (%s)" % tri)
	var torus := RoomKit.torus_geo(.42, .13, 5, 10, PI).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	eq(torus.size(), 5 * 10 * 2 * 3, "half torus triangles")
	var plane := RoomKit.plane_geo(2, 1).surface_get_arrays(0)
	var n: Vector3 = (plane[Mesh.ARRAY_NORMAL] as PackedVector3Array)[0]
	check(n.dot(Vector3(0, 0, 1)) > 0.9999, "plane faces +z (%s)" % n)   # normals are stored compressed


## Every room builds, every mesh catches clicks, and only the shown room does.
func test_rooms_build_with_colliders() -> void:
	var rooms := RoomSet.new()
	for id in RoomSet.ORDER:
		rooms.set_room(id)
	var counts := {}
	for id in RoomSet.ORDER:
		var g: Node3D = rooms.get_node(NodePath(id))
		var meshes := g.find_children("*", "MeshInstance3D", true, false)
		counts[id] = meshes.size()
		var bare := 0
		var unlit := 0
		for m: MeshInstance3D in meshes:
			if m.find_children("*", "StaticBody3D", false, false).is_empty():
				bare += 1
			var mat := m.material_override as BaseMaterial3D
			if mat == null:
				unlit += 1
		eq(bare, 0, id + ": meshes without a click collider")
		eq(unlit, 0, id + ": meshes without a material")
	note("meshes: %s" % counts)
	check(counts.diner > 100 and counts.bar > 100 and counts.bingo > 100, "rooms have their props (%s)" % counts)
	# Bingo was shown last: only its colliders are live.
	for id in RoomSet.ORDER:
		var live := 0
		var g: Node3D = rooms.get_node(NodePath(id))
		for b: StaticBody3D in g.find_children("*", "StaticBody3D", true, false):
			live += 1 if b.collision_layer != 0 else 0
		if id == "bingo":
			check(live > 0, "bingo colliders on")
		else:
			eq(live, 0, id + " colliders off while hidden")
	check(rooms.get_node(NodePath("bingo")).visible and not rooms.get_node(NodePath("diner")).visible, "only bingo visible")
	rooms.set_room("bar")
	check(rooms.machine_pos().is_equal_approx(Vector3(14.2, -3.25, -13.2)) and is_equal_approx(rooms.machine_yaw(), -.22), "bar machine placement")
	# A room's machine sells every form (eight columns: 12.73 wide, 3.04 deep) or the
	# forms the room names (the bingo hall's four: one cabinet and the console, 7.79
	# wide). It keeps clear of the side wall at x = 23, of the room's back wall and of
	# what stands at its depth on the left (the diner's counter, the bar's counter, the
	# bingo hall's long table), at rest and turned to face the player.
	eq(RoomSet.machine_forms("bingo"), ["core:catch", "core:plate", "core:spur", "core:order"], "the bingo hall's machine sells four forms")
	eq(RoomSet.machine_forms("diner"), [], "the diner's sells every form")
	eq(RoomSet.machine_forms("nowhere"), [], "an unknown room names none")
	for id in RoomSet.ORDER:
		var m: Array = RoomSet.ROOMS[id].machine
		var p: Vector3 = m[0]
		var n := RoomSet.machine_forms(id).size()
		var wide := 12.73 if n == 0 or n > MachineView.SINGLE_MAX else (n * MachineView.PITCH + 0.6 + MachineView.CONSOLE_W) * MachineView.SCALE
		var reach := wide / 2.0 * cos(m[1]) + 1.52 * absf(sin(m[1]))
		var depth := wide / 2.0 * absf(sin(m[1])) + 1.52 * cos(m[1])
		check(p.x + reach < 22.8, id + ": the machine clears the side wall")
		check(p.z - depth > {"diner": -17.8, "bar": -17.3, "bingo": -21.8}[id], id + ": the machine clears the back wall")
		check(p.x - maxf(reach, wide / 2.0) > {"diner": -2.0, "bar": 6.3, "bingo": 5.6}[id], id + ": the machine clears the furniture")
	for name in ["diner_formica", "diner_tiles", "diner_dusk", "diner_neon", "diner_juke", "bar_wood", "bar_planks", "bar_neon",
			"phone_keys", "phone_screen", "bingo_laminate", "bingo_board", "bingo_sheet", "pig_tag"]:
		check(RoomKit.tex(name) != null, "texture " + name)
	rooms.free()


## Diner: the table view is dimmed (G, M5 review), the machine view keeps the fitted rig,
## and the swing between them fades. Rooms without table_dim are the same in both views.
func test_table_dim() -> void:
	var rooms := RoomSet.new()
	rooms.set_room("diner")
	rooms.set_view(1.0)
	var key_m := rooms.key.light_energy
	var amb_m := rooms.env.ambient_light_energy
	rooms.set_view(0.0)
	check(is_equal_approx(rooms.key.light_energy, key_m * .81) and is_equal_approx(rooms.env.ambient_light_energy, amb_m * .81),
		"diner table view at 0.81 of the machine view's light")
	rooms.set_view(0.5)
	check(is_equal_approx(rooms.key.light_energy, key_m * lerpf(.81, 1.0, .5)), "halfway through the swing, halfway dimmed")
	rooms.set_room("bar")
	rooms.set_view(1.0)
	var bar_m := rooms.key.light_energy
	rooms.set_view(0.0)
	check(is_equal_approx(rooms.key.light_energy, bar_m), "bar: no table dimming")
	rooms.set_room("diner")
	check(is_equal_approx(rooms.key.light_energy, key_m * .81), "switching rooms at the table keeps the table dimming")
	rooms.free()


func test_light_conversions() -> void:
	# Hemisphere: ambient + half = sky, ambient - half = ground (in linear light).
	var sky := Color("#e8f7e6")
	var ground := Color("#756b58")
	var h := RoomSet.hemisphere(sky, ground, 1.0)
	var amb: Color = h.ambient.srgb_to_linear()
	var half: Color = h.half.srgb_to_linear() * h.half_energy
	for c in 3:
		check(is_equal_approx(snappedf(amb[c] + half[c], 1e-4), snappedf(sky.srgb_to_linear()[c], 1e-4)), "up faces get the sky (channel %d)" % c)
		check(is_equal_approx(snappedf(amb[c] - half[c], 1e-4), snappedf(ground.srgb_to_linear()[c], 1e-4)), "down faces get the ground (channel %d)" % c)
	# Point falloff: Godot's window times the scale gives the web's (1 - d/34)^1.4.
	for d in [3.0, 8.0, 13.0, 20.0]:
		var godot := pow(1.0 - pow(d / 34.0, 4.0), 2.0)
		check(is_equal_approx(snappedf(godot * RoomSet.point_scale(d), 1e-6), snappedf(pow(1.0 - d / 34.0, 1.4), 1e-6)), "falloff at %s" % d)


# --- helpers ---------------------------------------------------------------------

func _solid(mesh: ArrayMesh, tris: int, what: String) -> void:
	var a := mesh.surface_get_arrays(0)
	var v := a[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var n := a[Mesh.ARRAY_NORMAL] as PackedVector3Array
	eq(v.size() / 3, tris, what + " triangles")
	var centre := mesh.get_aabb().get_center()
	var outward := 0
	var clockwise := 0
	for i in range(0, v.size(), 3):
		var mid := (v[i] + v[i + 1] + v[i + 2]) / 3.0
		if n[i].dot(mid - centre) > 0.0:
			outward += 1
		if (v[i + 1] - v[i]).cross(v[i + 2] - v[i]).dot(n[i]) < 0.0:
			clockwise += 1
	eq(outward, v.size() / 3, what + " faces pointing outward")
	eq(clockwise, v.size() / 3, what + " faces wound clockwise")


func _near(got: Array, want: Array, what: String) -> void:
	var ok := got.size() == want.size()
	for i in mini(got.size(), want.size()):
		ok = ok and absf(float(got[i]) - float(want[i])) < 1e-5
	check(ok, "%s: web %s, here %s" % [what, got, want])


func _field(line: String, pattern: String, join := false) -> String:
	var re := RegEx.create_from_string(pattern)
	var m := re.search(line)
	if m == null:
		return ""
	return m.get_string(1) + ("," + m.get_string(2) if join else "")


func _nums(s: String) -> Array:
	var out := []
	for part in s.split(",", false):
		part = part.strip_edges()
		out.append(part.hex_to_int() if part.begins_with("0x") else float(part))
	return out
