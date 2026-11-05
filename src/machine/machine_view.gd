class_name MachineView
extends Node3D
## The pull-tab machine on the floor, rebuilt from the web build's buildMachine().
## Local units as in the web build; the node is scaled 0.95.
## Shows state only: MachineLogic and Economy decide what happens.

signal ready_to_use

const SCALE := 0.95
const GOLD := Color("#9c7f52")
const DARK := Color("#1b1a20")
const CHROME := Color("#c5ced6")
const LCD_BG := Color("#b8e23e")
const LCD_INK := Color("#26330c")
const RED := Color("#d4242b")
const STICKER := Color("#f5f0e4")
const ROUND_RADIUS := 0.45  ## PLAY ALL's outer ring: as tall as the 0.9-high LCD beside it
## Lamp looks for the red buttons, brightest first. G picks one; 0 is the earlier, brighter
## version and 3 the most muted; 1 and 2 lie evenly between.
const LAMP_BRIGHT := {"on": 0.78, "dim": 0.40, "hot": Color("#ff9c86"), "mid": Color("#e0221a"),
	"rim": Color("#5a0604"), "gloss": 0.35, "halo": Color(1.0, 0.16, 0.1, 0.32), "side": Color("#8a0e09")}
const LAMP_MUTED := {"on": 0.62, "dim": 0.34, "hot": Color("#e9a092"), "mid": Color("#bf3a30"),
	"rim": Color("#4a0e0b"), "gloss": 0.28, "halo": Color(0.9, 0.2, 0.14, 0.2), "side": Color("#5e1612")}
const LAMP_STEPS := 4
static var lamp_preset := 0   ## G went back to the brightest step (M5); the developer panel steps it


## Lamp settings for a preset: an even blend from the brightest to the most muted.
static func lamp(i := lamp_preset) -> Dictionary:
	var t := float(clampi(i, 0, LAMP_STEPS - 1)) / (LAMP_STEPS - 1)
	var out := {}
	for k in LAMP_BRIGHT:
		var a = LAMP_BRIGHT[k]
		var b = LAMP_MUTED[k]
		out[k] = a.lerp(b, t) if a is Color else lerpf(a, b, t)
	return out
const BEZEL := Color("#0c0c10")
const FLY_COUNT := 14
const FONT_LCD := preload("res://assets/fonts/vt323-latin-400-normal.woff2")

var painter: TicketPainter
var forms: Array[FormDef] = []
var buttons: Array[Node3D] = []   ## three column caps, then the PLAY ALL dome
var big_button: Node3D
var body_collider: StaticBody3D

var _press := PackedFloat32Array([0, 0, 0, 0])
var _button_z := PackedFloat32Array()
var _stock: Array[MeshInstance3D] = []
var _tray_pile: MeshInstance3D
var _stack_mat := StandardMaterial3D.new()
var _fly: Array[MeshInstance3D] = []
var _fly_state: Array = []
var _bill: MeshInstance3D
var _bill_mat := StandardMaterial3D.new()
var _bill_tex := {}
var _big_mat: StandardMaterial3D
var _faces: Array = []                      ## [material, round] for each lit button face
var _sides: Array[StandardMaterial3D] = []  ## the red plastic sides of the caps
var _halos: Array[StandardMaterial3D] = []
var _lcd_top := Label.new()
var _lcd_sub := Label.new()
var _time := 0.0


## Builds the machine for these forms (one column each, up to three).
func build(machine_forms: Array) -> void:
	for f in machine_forms:
		forms.append(f)
	scale = Vector3.ONE * SCALE
	var gold := _lit(GOLD, 24)
	var dark := _lit(DARK, 20)
	var chrome := _lit(CHROME, 70, 0.6)
	_box(Vector3(6.2, 13, 3.2), gold, Vector3(0, -5, 0))
	_box(Vector3(6.4, 0.5, 3.4), dark, Vector3(0, 8, 0))
	_panel(Vector2(5.4, 0.7), await _paint(Vector2(540, 70), [
		_rect(0, 0, 540, 70, RED), _text("PULL-TABS", Vector2(270, 54), "slab", 50, Color("#fff4d9"))]), Vector3(0, 7.55, 1.62))
	_box(Vector3(5.4, 3.3, 0.08), _lit(Color("#130c15"), 6), Vector3(0, 3.9, 1.6))
	var rail_cmds := [_rect(0, 0, 64, 256, Color("#d9d6cf"))]
	for i in 11:
		rail_cmds.append(_rect(0, i * 25, 26 if i % 5 == 0 else 14, 2, Color("#2a2428")))
	for i in range(1, 5):
		rail_cmds.append(_text(str(1000 - i * 200), Vector2(44, i * 50 + 6), "cond_bold", 15, Color("#2a2428")))
	var rail := await _paint(Vector2(64, 256), rail_cmds)
	for i in forms.size():
		var x := -1.75 + i * 1.75
		_panel(Vector2(0.28, 3), rail, Vector3(x + 0.7, 5.5, 1.66))
		var edge_cmds := []
		for y in range(0, 64, 2):
			edge_cmds.append(_rect(0, y, 32, 2, Color("#efe7d6") if y % 4 else forms[i].colors.edge))
		var edges := await _paint(Vector2(32, 64), edge_cmds)
		var stock := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(1.25, 1, 0.5)
		stock.mesh = sb
		var sm := _flat_tex(edges)
		sm.uv1_scale = Vector3(1, 4, 1)
		stock.material_override = sm
		stock.position = Vector3(x - 0.12, 4.5, 1.86)
		add_child(stock)
		_stock.append(stock)
	var led := _flat(Color("#ff3bea"))
	for spec in [[5.5, 0.1, 0.0, 7.15], [5.5, 0.1, 0.0, 3.85], [0.1, 3.3, -2.72, 5.5], [0.1, 3.3, 2.72, 5.5]]:
		_box(Vector3(spec[0], spec[1], 0.1), led, Vector3(spec[2], spec[3] - spec[1] / 2.0, 1.72), false)
	var strip_cmds := [_rect(0, 0, 540, 36, STICKER)]
	strip_cmds.append({"k": "stroke", "pts": PackedVector2Array([Vector2(4, 4), Vector2(536, 4), Vector2(536, 32), Vector2(4, 32)]),
		"closed": true, "width": 3.0, "color": RED, "join": "miter", "dash": null})
	for i in forms.size():
		strip_cmds.append(_text(forms[i].name.to_upper(), Vector2(90 + i * 180, 26), "cond_bold", 20, forms[i].colors.edge))
	_panel(Vector2(5.4, 0.36), await _paint(Vector2(540, 36), strip_cmds), Vector3(0, 2.93, 1.62))
	for i in forms.size():
		buttons.append(_square_button(Vector3(-1.8 + i * 1.8, 3.47, 1.64), {"column": i}))
	_box(Vector3(5.4, 2.42, 0.08), dark, Vector3(0, 0.34, 1.6))
	_panel(Vector2(3.1, 0.9), _lcd_texture(), Vector3(-0.95, 2.1, 1.66))
	_panel(Vector2(3.1, 0.84), await _paint(Vector2(320, 92), [
		_rect(0, 0, 320, 92, STICKER),
		{"k": "stroke", "pts": PackedVector2Array([Vector2(6, 6), Vector2(314, 6), Vector2(314, 86), Vector2(6, 86)]),
			"closed": true, "width": 5.0, "color": RED, "join": "miter", "dash": null},
		_text("PLAY ALL", Vector2(160, 44), "cond_bold", 30, RED),
		_text("MAX. 100 TICKETS", Vector2(160, 76), "cond_bold", 26, RED)]), Vector3(-0.95, 1.03, 1.66))
	big_button = _round_button(Vector3(1.6, 2.1, 1.64))
	buttons.append(big_button)
	_box(Vector3(1.7, 0.98, 0.16), _lit(Color("#0b0b0f"), 50), Vector3(1.6, 0.42, 1.68))
	_box(Vector3(1.25, 0.12, 0.34), chrome, Vector3(1.6, 0.78, 1.84))
	_box(Vector3(1, 0.06, 0.05), _flat(Color("#5dff7a")), Vector3(1.6, 0.98, 1.78), false)
	_box(Vector3(0.5, 0.08, 0.04), _flat(Color("#ffb13b")), Vector3(1.6, 0.56, 1.78), false)
	_bill = _card(Vector2(0.62, 1.3), _bill_mat, true)
	_bill.visible = false
	for v in Economy.BILLS:
		_bill_tex[v] = await _paint(Vector2(136, 64), [
			_rect(0, 0, 136, 64, Color("#8fbf8a")),
			{"k": "stroke", "pts": PackedVector2Array([Vector2(5, 5), Vector2(131, 5), Vector2(131, 59), Vector2(5, 59)]),
				"closed": true, "width": 3.0, "color": Color("#27553a"), "join": "miter", "dash": null},
			_text("$%d" % v, Vector2(68, 44), "slab", 34, Color("#17392a"))])
	_box(Vector3(4.1, 0.9, 0.06), _flat(Color("#b8751f")), Vector3(0, -0.52, 1.61), false)
	_box(Vector3(4.5, 0.24, 1.7), chrome, Vector3(0, -0.72, 2.35))
	_box(Vector3(4.5, 0.34, 0.12), chrome, Vector3(0, -0.7, 3.2))
	_tray_pile = _card(Vector2(1.4, 2.0), _stack_mat, false, 1.0)
	_tray_pile.visible = false
	for i in FLY_COUNT:
		var f := _card(Vector2(0.95, 1.3), _stack_mat, false)
		f.visible = false
		_fly.append(f)
		_fly_state.append({"life": 0.0, "x": 0.0, "spin": 0.0})
	body_collider = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(6.2, 13, 3.2)
	shape.shape = bs
	shape.position = Vector3(0, 1.5, 0)
	body_collider.add_child(shape)
	body_collider.set_meta("machine", true)
	add_child(body_collider)
	ready_to_use.emit()


## LCD lines: credit on top, status below.
func set_lcd(top: String, sub: String) -> void:
	_lcd_top.text = top
	_lcd_sub.text = sub


func press_button(i: int) -> void:
	_press[i] = 1.0


## Column stock heights: share of each box still in it (0..1).
func set_stock(shares: Array) -> void:
	for i in mini(shares.size(), _stock.size()):
		var h := maxf(0.03, float(shares[i]) * 2.9)
		_stock[i].scale.y = h
		_stock[i].position.y = 4.0 + h / 2.0


## The stack in the output tray: how many tickets are held and the top one's art.
func set_tray(count: int, art: Texture2D, card: Vector2) -> void:
	_tray_pile.visible = count > 0
	var th := clampf(count / 500.0 * 1.3, 0.02, 1.3)
	_tray_pile.scale = Vector3(card.x / 1.4, th, card.y / 2.0)
	_tray_pile.position = Vector3(0, -0.48 + th / 2.0, 2.3)
	if art:
		_stack_mat.albedo_texture = art


## A ticket shoots out into the tray.
func launch_card() -> void:
	for i in _fly.size():
		if not _fly[i].visible:
			_fly[i].visible = true
			_fly_state[i] = {"life": 0.0, "x": (randf() - 0.5) * 1.1, "spin": (randf() - 0.5) * 3.0}
			_fly[i].position = Vector3(0, 0.15, 1.7)
			return


## The bill sliding into the slot; t is the feed progress 0..1, value 0 hides it.
func show_bill(value: int, t: float) -> void:
	_bill.visible = value > 0
	if value == 0:
		return
	_bill_mat.albedo_texture = _bill_tex.get(value)
	if t < Economy.BILL_SOUND_AT:
		var k := _ease(t / Economy.BILL_SOUND_AT)
		_bill.position = Vector3(1.6, lerpf(-0.3, 0.9, k), lerpf(4.4, 2.45, k))
		_bill.scale.z = 1.0
	else:
		var k := (t - Economy.BILL_SOUND_AT) / (1.0 - Economy.BILL_SOUND_AT)
		_bill.scale.z = maxf(0.01, 1.0 - k)
		_bill.position = Vector3(1.6, 0.9, 1.8 + 0.65 * (1.0 - k))


## PLAY ALL blinks (it blinks while dispensing too, as in the web build).
func set_blink(on: bool) -> void:
	var l := lamp()
	var v: float = l.on if on else l.dim
	_big_mat.albedo_color = Color(v, v, v, 1.0)  # keep alpha 1: the round face is alpha-scissored


## Repaints the lit buttons for the current lamp_preset (the developer panel's lamp steps).
func apply_lamp() -> void:
	var l := lamp()
	var tex := {}
	for f in _faces:
		var round: bool = f[1]
		if not tex.has(round):
			tex[round] = _glow_texture(round)
		var m: StandardMaterial3D = f[0]
		m.albedo_texture = tex[round]
		m.albedo_color = Color(l.on, l.on, l.on, 1.0)
	for m in _sides:
		m.albedo_color = l.side
	var halo := _halo_texture()
	for m in _halos:
		m.albedo_texture = halo


func _process(dt: float) -> void:
	_time += dt
	for i in buttons.size():
		_press[i] *= exp(-dt * 11.0)
		buttons[i].position.z = _button_z[i] - _press[i] * 0.07
	for i in _fly.size():
		if not _fly[i].visible:
			continue
		var s: Dictionary = _fly_state[i]
		s.life += dt / 0.24
		if s.life >= 1.0:
			_fly[i].visible = false
			continue
		var l: float = s.life
		_fly[i].position = Vector3(s.x * l, 0.15 + sin(l * PI) * 0.25 - l * 0.5, 1.7 + l * 0.8)
		_fly[i].rotation = Vector3(l * 0.7, s.spin * l, 0)


## Points in machine space the bill window lines up with (slot, side, window height).
func anchor(name: String) -> Vector3:
	match name:
		"slot":
			return to_global(Vector3(1.6, 0.95, 1.75))
		"side":
			return to_global(Vector3(3.1, 0.95, 1.6))
	return to_global(Vector3(1.6, 2.75, 1.75))


# --- lit push buttons -----------------------------------------------------------

## A square illuminated arcade button: black bezel, translucent red cap lit from
## inside (bright centre, darker rim, a gloss highlight) and a soft red halo.
## The lamp look is painted into an unshaded texture: the Compatibility renderer
## ignores emission textures.
func _square_button(at: Vector3, meta: Dictionary) -> Node3D:
	var bezel := _box(Vector3(0.68, 0.68, 0.1), _lit(BEZEL, 40), at - Vector3(0, 0.34, 0.02))
	bezel.position.z = at.z
	_striped_frame(at + Vector3(0, 0, 0.0503))
	_halo(at + Vector3(0, 0, 0.051), 1.05)
	var cap := Node3D.new()
	cap.position = at + Vector3(0, 0, 0.07)
	add_child(cap)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(SQUARE_CAP, SQUARE_CAP, 0.1)
	body.mesh = bm
	body.material_override = _lit(lamp().side, 60)
	_sides.append(body.material_override)
	cap.add_child(body)
	cap.add_child(_lamp_face(Vector2(SQUARE_CAP, SQUARE_CAP), false, 0.0505))
	_collider(cap, Vector3(0.68, 0.68, 0.2), meta)
	_button_z.append(cap.position.z)
	return cap


## The round PLAY ALL button: a dark grey metal ring (it has to read against the
## black panel) as tall as the LCD beside it, a black inner bezel and a red lit dome.
func _round_button(at: Vector3) -> Node3D:
	var r := ROUND_RADIUS
	var ring := _cyl(r, 0.1, 48, _lit(Color("#5a5d66"), 72, 0.55), at)
	ring.rotation.x = PI / 2
	var bevel := _cyl(r * 0.9, 0.11, 48, _lit(Color("#2a2b31"), 60, 0.3), at + Vector3(0, 0, 0.01))
	bevel.rotation.x = PI / 2
	var lip := _cyl(r * 0.78, 0.12, 48, _lit(BEZEL, 40), at + Vector3(0, 0, 0.03))
	lip.rotation.x = PI / 2
	_halo(at + Vector3(0, 0, 0.051), r * 1.7)
	var cap := Node3D.new()
	cap.position = at + Vector3(0, 0, 0.1)
	add_child(cap)
	var side := _cyl(r * 0.69, 0.1, 48, _lit(lamp().side, 60), Vector3.ZERO)
	_sides.append(side.material_override)
	side.reparent(cap, false)
	side.rotation.x = PI / 2
	var face := _lamp_face(Vector2(r * 1.38, r * 1.38), true, 0.0505)
	_big_mat = face.material_override
	cap.add_child(face)
	_collider(cap, Vector3(r * 2.0, r * 2.0, 0.3), {"play_all": true})
	_button_z.append(cap.position.z)
	return cap


func _lamp_face(size: Vector2, round: bool, z: float) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _glow_texture(round)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var v := float(lamp().on)
	m.albedo_color = Color(v, v, v, 1.0)
	if round:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_faces.append([m, round])
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	q.mesh = qm
	q.material_override = m
	q.position.z = z
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return q


## Lamp behind red plastic: hot pink-white centre to deep red at the edge, with a
## soft gloss highlight up and to the left.
static func _glow_texture(round: bool) -> ImageTexture:
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var l := lamp()
	var hot: Color = l.hot
	var mid: Color = l.mid
	var rim: Color = l.rim
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var r := Vector2(u, v).length()
			# a rounded square for square caps (superellipse), no corners in the glow
			var d := r if round else pow(pow(absf(u), 4.0) + pow(absf(v), 4.0), 0.25)
			var c := hot.lerp(mid, smoothstep(0.0, 0.6, r)).lerp(rim, smoothstep(0.72, 1.0, d))
			var g := Vector2(u + 0.38, v + 0.42)
			var gloss := clampf(1.0 - Vector2(g.x / 0.42, g.y / 0.22).length(), 0.0, 1.0)
			c = c.lerp(Color.WHITE, float(l.gloss) * gloss * gloss)
			c.a = 0.0 if round and r > 1.0 else 1.0
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


const SQUARE_CAP := 0.52       ## square cap face, machine units
## Stripes on the square buttons' bezels, after the banding G liked on the panel around
## PLAY ALL (that banding is the key light's shadow; these are painted). The lit cap has
## none, like PLAY ALL's dome. G picked bezel-only stripes, few and well apart (M5).
const FRAME := 0.68                   ## bezel front, machine units
const FRAME_BASE := Color("#3a3b42")  ## the bezel front, lifted from black so stripes read on it
const STRIPE_PERIOD := 0.17           ## machine units between stripes
const STRIPE_SLOPE := -0.21           ## stripes fall about 12 degrees to the right
const STRIPE_SHARP := 4.0             ## how fast a stripe fades below its dark edge
const STRIPE_DEPTH := 0.65            ## how dark a stripe's edge is
static var _frame_tex: ImageTexture


## Darkening at (x, y) on a bezel (machine units from its centre, y up), 0..1: each
## stripe starts dark at its upper edge and fades out below it.
static func _stripe(x: float, y: float) -> float:
	var p := fposmod((y - x * STRIPE_SLOPE) / STRIPE_PERIOD, 1.0)   # 1 just under a stripe edge, falling to 0 at the next
	return pow(p, STRIPE_SHARP)


static func _frame_texture() -> ImageTexture:
	if _frame_tex == null:
		var n := 128
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var px := ((x + 0.5) / n - 0.5) * FRAME
				var py := (0.5 - (y + 0.5) / n) * FRAME
				img.set_pixel(x, y, FRAME_BASE.darkened(STRIPE_DEPTH * _stripe(px, py)))
		img.generate_mipmaps()
		_frame_tex = ImageTexture.create_from_image(img)
	return _frame_tex


## The striped front of a square button's bezel (lit, so the room's light falls on it).
func _striped_frame(at: Vector3) -> void:
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(FRAME, FRAME)
	q.mesh = qm
	var m := _lit(Color.WHITE, 40)
	m.albedo_texture = _frame_texture()
	q.material_override = m
	q.position = at
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(q)


## Soft red light spilling onto the panel around a lit button.
func _halo(at: Vector3, size: float) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _halo_texture()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halos.append(m)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	q.mesh = qm
	q.material_override = m
	q.position = at
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(q)


static func _halo_texture() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var h: Color = lamp().halo
	for y in n:
		for x in n:
			var d := Vector2((x + 0.5) / n * 2.0 - 1.0, (y + 0.5) / n * 2.0 - 1.0).length()
			img.set_pixel(x, y, Color(h.r, h.g, h.b, h.a * pow(clampf(1.0 - d, 0.0, 1.0), 2.0)))
	return ImageTexture.create_from_image(img)


# --- construction kit ---------------------------------------------------------

func _lit(c: Color, shininess := 6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = clampf(1.0 - shininess / 100.0, 0.2, 1.0)
	m.metallic = metal
	return m


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _flat_tex(t: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## A box whose base sits at `at.y`, like the web build's box() helper.
func _box(size: Vector3, mat: Material, at: Vector3, shadow := true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = at + Vector3(0, size.y / 2.0, 0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


func _cyl(r: float, h: float, seg: int, mat: Material, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	m.mesh = c
	m.material_override = mat
	m.position = at
	add_child(m)
	return m


func _panel(size: Vector2, tex: Texture2D, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	m.mesh = q
	m.material_override = _flat_tex(tex)
	m.position = at
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


## A thin card lying flat with art on top (print top toward -z, or turned a
## quarter for a bill so its text runs along it).
func _card(size: Vector2, top_mat: Material, quarter_turn: bool, height := 0.012) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := ArrayMesh.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, height, size.y)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color("#ece6d7")
	mesh.surface_set_material(0, edge)
	var hx := size.x / 2.0
	var hz := size.y / 2.0
	var y := height / 2.0 + 0.0005
	var uv := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	if quarter_turn:
		uv = PackedVector2Array([Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)])
	var top := []
	top.resize(Mesh.ARRAY_MAX)
	top[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-hx, y, -hz), Vector3(hx, y, -hz), Vector3(hx, y, hz), Vector3(-hx, y, hz)])
	top[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	top[Mesh.ARRAY_TEX_UV] = uv
	top[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, top)
	mesh.surface_set_material(1, top_mat)
	m.mesh = mesh
	add_child(m)
	return m


func _collider(owner_mesh: Node3D, size: Vector3, meta: Dictionary) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	for k in meta:
		body.set_meta(k, meta[k])
	body.set_meta("machine", true)
	owner_mesh.add_child(body)


## The machine LCD is a live 2D view, so its text updates without repainting.
func _lcd_texture() -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(320, 92)
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bg := ColorRect.new()
	bg.color = LCD_BG
	bg.size = Vector2(320, 92)
	vp.add_child(bg)
	for spec in [[_lcd_top, 36, 8.0], [_lcd_sub, 32, 46.0]]:
		var l: Label = spec[0]
		l.add_theme_font_override("font", FONT_LCD)
		l.add_theme_font_size_override("font_size", spec[1])
		l.add_theme_color_override("font_color", LCD_INK)
		l.position = Vector2(12, spec[2])
		l.size = Vector2(296, 40)
		l.clip_text = true
		vp.add_child(l)
	add_child(vp)
	return vp.get_texture()


func _paint(size: Vector2, cmds: Array) -> Texture2D:
	return await painter.paint(size, cmds)


static func _rect(x: float, y: float, w: float, h: float, c: Color) -> Dictionary:
	return {"k": "poly", "pts": PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)]), "color": c}


static func _text(t: String, pos: Vector2, font: String, size: float, c: Color, align := "center") -> Dictionary:
	return {"k": "text", "text": t, "pos": pos, "font": font, "size": size, "align": align, "max_width": 0.0,
		"color": c, "outline": 0.0, "dir": ""}


static func _ease(t: float) -> float:
	return 2.0 * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0
