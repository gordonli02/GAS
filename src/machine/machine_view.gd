class_name MachineView
extends Node3D
## The pull-tab machine on the floor (M8.6), after the machines in bars and bingo halls.
## Up to four columns: one gold cabinet with the black console on its right. More: two
## cabinets with the console between them, half the columns on each side.
## Each column shows its ticket's front over the stack of tickets left, with a lit button
## and a name and price plate under it; the console holds the sign, the LCD, PLAY ALL and
## the bill slot.
## Local units as in the web build's machine; the node is scaled 0.95.
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
const ROUND_RADIUS := 0.45  ## PLAY ALL's outer ring
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
const FLY_SIZE := Vector2(0.95, 1.3)   ## a flying ticket of the usual card (1.4 x 2.0), as the web build drew it
const FONT_LCD := preload("res://assets/fonts/vt323-latin-400-normal.woff2")

# --- the cabinet, in machine units ------------------------------------------------
const PITCH := 1.2             ## one column
const SINGLE_MAX := 4          ## up to this many columns stand in one cabinet, the console on its right
const FRAME_W := 0.25          ## gold left and right of a cabinet's window
const CONSOLE_W := 2.8
const BODY_BASE := -5.0        ## the floor
const BODY_H := 13.0
const BODY_D := 3.2
const FACE_Z := 1.6
const WINDOW_Y := Vector2(2.15, 7.65)   ## the glass, bottom and top
const SHOW_H := 1.31           ## the ticket shown at the top of a column (0.92 wide for the usual card)
const SHOW_W := 0.92           ## and the widest it may be (a square card is fitted to this)
const SHOW_Y := 6.9
const STACK_W := 0.84
const STACK_BASE := 2.3
const STACK_MAX := 3.75        ## a full box
const BUTTON_Y := 1.5
const PLATE_Y := 0.82          ## the name and price plate
const PLATE_SIZE := Vector2(1.08, 0.5)
const TRAY_Y := -0.71          ## where tickets land
const TRAY_DEPTH := 2.0        ## the longest card that lies in a tray front to back
const LCD_AT := Vector2(0, 5.62)
const LCD_SIZE := Vector2(2.36, 0.96)
const LCD_PX := Vector2(368, 150)
const PLAY_ALL_Y := 4.42
const SLOT_BASE := 1.86        ## the bill acceptor's lower edge

var painter: TicketPainter
var forms: Array[FormDef] = []
var buttons: Array[Node3D] = []   ## one cap per column, then the PLAY ALL dome
var big_button: Node3D
var body_collider: StaticBody3D
var built := false                ## false while the machine is being (re)built
var width := 0.0                  ## the whole machine, machine units

var _press := PackedFloat32Array()
var _button_z := PackedFloat32Array()
var _column_x := PackedFloat32Array()
var _left := 0                              ## columns in the left cabinet
var _cabinets: Array = []                   ## [{x, w}] left, right
var _console_x := 0.0
var _stock: Array[MeshInstance3D] = []
var _tray_piles: Array[MeshInstance3D] = []
var _stack_mats: Array[StandardMaterial3D] = []
var _fly: Array[MeshInstance3D] = []
var _fly_mats: Array[StandardMaterial3D] = []   ## each flying ticket shows its own form
var _fly_state: Array = []
var _bill: MeshInstance3D
var _bill_mat := StandardMaterial3D.new()
var _bill_tex := {}
var _big_mat: StandardMaterial3D
var _faces: Array = []                      ## [material, round] for each lit button face
var _sides: Array[StandardMaterial3D] = []  ## the red plastic sides of the caps
var _halos: Array[StandardMaterial3D] = []
var _lcd_top: Label
var _lcd_sub: Label
var _lcd_info: Label
var _built_key := ""
var _build_no := 0                ## a build that another one overtook gives up
var _time := 0.0


## What a build shows of these forms: a stage's stake changes the print and the price.
static func build_key(machine_forms: Array) -> String:
	var keys := PackedStringArray()
	for f: FormDef in machine_forms:
		keys.append(f.art_key())
	return "|".join(keys)


## True when the machine already stands as these forms need it.
func shows(machine_forms: Array) -> bool:
	return built and _built_key == build_key(machine_forms)


## Builds the machine for these forms, one column each. `art_for` paints a form's front
## (awaited). Building again takes the old machine down first.
func build(machine_forms: Array, art_for: Callable) -> void:
	built = false
	_build_no += 1
	var build_no := _build_no
	_clear()
	for f in machine_forms:
		forms.append(f)
	scale = Vector3.ONE * SCALE
	var n := forms.size()
	_left = n if n <= SINGLE_MAX else (n + 1) / 2
	var widths := [_left * PITCH + 0.1 + FRAME_W * 2.0, (n - _left) * PITCH + 0.1 + FRAME_W * 2.0]
	if n - _left == 0:
		widths[1] = 0.0
	width = widths[0] + CONSOLE_W + widths[1]
	_cabinets = [{"x": -width / 2.0 + widths[0] / 2.0, "w": widths[0], "n": _left, "first": 0},
		{"x": width / 2.0 - widths[1] / 2.0, "w": widths[1], "n": n - _left, "first": _left}]
	_console_x = -width / 2.0 + widths[0] + CONSOLE_W / 2.0
	var gold := _lit(GOLD, 24)
	var dark := _lit(DARK, 20)
	_box(Vector3(width, BODY_H, BODY_D), gold, Vector3(0, BODY_BASE, 0))
	_box(Vector3(width + 0.2, 0.5, BODY_D + 0.2), dark, Vector3(0, BODY_BASE + BODY_H, 0))
	# Every picture is painted in the same frame, so a new machine stands within a few
	# frames (a new layer of the run builds one, at its stake).
	var jobs := _console_jobs()
	jobs["rail"] = _rail_job()
	for i in n:
		jobs["edge%d" % i] = _edge_job(forms[i])
		jobs["plate%d" % i] = _plate_job(i, forms[i])
	var tex := {}
	for k in jobs:
		_paint_into(tex, k, jobs[k][0], jobs[k][1])
	for i in n:
		_front_into(tex, "front%d" % i, forms[i], art_for)
	while tex.size() < jobs.size() + n:
		await get_tree().process_frame
	if build_no != _build_no:
		return   # the room changed again meanwhile: that build stands
	# Columns first: buttons[i] must be column i, with PLAY ALL after the last.
	for cab in _cabinets:
		if cab.n > 0:
			_build_cabinet(cab, tex)
	_build_console(dark, tex)
	for i in FLY_COUNT:
		var mat := StandardMaterial3D.new()
		var f := _card(FLY_SIZE, mat, false)
		f.visible = false
		_fly.append(f)
		_fly_mats.append(mat)
		_fly_state.append({"life": 0.0, "x": 0.0, "from": 0.0, "spin": 0.0})
	body_collider = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, BODY_H, BODY_D)
	shape.shape = bs
	shape.position = Vector3(0, BODY_BASE + BODY_H / 2.0, 0)
	body_collider.add_child(shape)
	body_collider.set_meta("machine", true)
	add_child(body_collider)
	_built_key = build_key(forms)
	built = true
	ready_to_use.emit()


func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	forms.clear()
	buttons.clear()
	_press = PackedFloat32Array()
	_button_z = PackedFloat32Array()
	_column_x = PackedFloat32Array()
	_stock.clear()
	_tray_piles.clear()
	_stack_mats.clear()
	_fly.clear()
	_fly_mats.clear()
	_fly_state.clear()
	_faces.clear()
	_sides.clear()
	_halos.clear()
	_bill = null
	_big_mat = null
	big_button = null
	body_collider = null


## One cabinet: the lit window with a column per form, the buttons and plates under
## it, and the tray its tickets fall into.
func _build_cabinet(cab: Dictionary, tex: Dictionary) -> void:
	var cx: float = cab.x
	var ww: float = cab.n * PITCH + 0.1
	var wy := (WINDOW_Y.x + WINDOW_Y.y) / 2.0
	var wh := WINDOW_Y.y - WINDOW_Y.x
	_box(Vector3(ww, wh, 0.08), _lit(Color("#130c15"), 6), Vector3(cx, WINDOW_Y.x, FACE_Z))
	var led := _flat(Color("#ff3bea"))
	for spec in [[ww + 0.1, 0.1, 0.0, WINDOW_Y.y], [ww + 0.1, 0.1, 0.0, WINDOW_Y.x - 0.1],
			[0.1, wh + 0.2, -ww / 2.0 - 0.05, WINDOW_Y.x - 0.1], [0.1, wh + 0.2, ww / 2.0 + 0.05, WINDOW_Y.x - 0.1]]:
		_box(Vector3(spec[0], spec[1], 0.1), led, Vector3(cx + spec[2], spec[3], FACE_Z + 0.12), false)
	for j in int(cab.n):
		var i: int = int(cab.first) + j
		var form := forms[i]
		var x: float = cx - cab.n * PITCH / 2.0 + (j + 0.5) * PITCH
		_column_x.append(x)
		# The ticket this column sells, behind the glass. A wide ticket stands on its side.
		var card: Array = form.layout.card.size
		var tall: float = minf(SHOW_H, SHOW_W * card[1] / card[0])
		var shown := _panel(Vector2(tall * card[0] / card[1], tall), tex["front%d" % i], Vector3(x - 0.1, SHOW_Y, FACE_Z + 0.1))
		if card[0] > card[1]:
			var long: float = minf(SHOW_H, SHOW_W * card[0] / card[1])
			shown.mesh.size = Vector2(long, long * card[1] / card[0])
			shown.rotation.z = -PI / 2.0
		# The stack of tickets left, with a rule beside it.
		_panel(Vector2(0.2, STACK_MAX), tex.rail, Vector3(x + 0.44, STACK_BASE + STACK_MAX / 2.0, FACE_Z + 0.06))
		var stock := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(STACK_W, 1, 0.3)
		stock.mesh = sb
		var sm := _flat_tex(tex["edge%d" % i])
		sm.uv1_scale = Vector3(1, 5, 1)
		stock.material_override = sm
		stock.position = Vector3(x - 0.1, STACK_BASE + STACK_MAX / 2.0, FACE_Z + 0.2)
		stock.scale.y = STACK_MAX
		add_child(stock)
		_stock.append(stock)
		_square_button(Vector3(x, BUTTON_Y, FACE_Z + 0.04), {"column": i})
		_panel(PLATE_SIZE, tex["plate%d" % i], Vector3(x, PLATE_Y, FACE_Z + 0.02))
		# The whole column answers the pointer (the LCD names it); only the button sells.
		var info := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(PITCH, WINDOW_Y.y - PLATE_Y + PLATE_SIZE.y / 2.0, 0.2)
		shape.shape = bs
		info.add_child(shape)
		info.position = Vector3(x, (WINDOW_Y.y + PLATE_Y - PLATE_SIZE.y / 2.0) / 2.0, FACE_Z + 0.02)
		info.set_meta("machine", true)
		info.set_meta("column_info", i)
		add_child(info)
	# The tray: a lit recess, a chrome shelf and its lip.
	var tw: float = cab.w - 0.7
	_box(Vector3(tw - 0.3, 0.95, 0.06), _flat(Color("#17141b")), Vector3(cx, TRAY_Y, FACE_Z + 0.01), false)
	_box(Vector3(tw - 0.5, 0.09, 0.05), _flat(Color("#ffe9b0")), Vector3(cx, TRAY_Y + 0.8, FACE_Z + 0.03), false)
	var chrome := _lit(CHROME, 70, 0.6)
	_box(Vector3(tw, 0.24, 1.7), chrome, Vector3(cx, TRAY_Y - 0.24, 2.35))
	_box(Vector3(tw, 0.34, 0.12), chrome, Vector3(cx, TRAY_Y - 0.22, 3.2))
	var mat := StandardMaterial3D.new()
	var pile := _card(Vector2(1.4, 2.0), mat, false, 1.0)
	pile.visible = false
	_stack_mats.append(mat)
	_tray_piles.append(pile)


## The console between the cabinets: sign, LCD, PLAY ALL, a notice and the bill slot.
func _build_console(dark: StandardMaterial3D, tex: Dictionary) -> void:
	var cx := _console_x
	_box(Vector3(CONSOLE_W, WINDOW_Y.y + 0.25 - TRAY_Y + 0.6, 0.1), dark, Vector3(cx, TRAY_Y - 0.6, FACE_Z + 0.02))
	_panel(Vector2(2.36, 1.3), tex.sign, Vector3(cx, 7.0, FACE_Z + 0.08))
	_box(Vector3(LCD_SIZE.x + 0.16, LCD_SIZE.y + 0.16, 0.06), _lit(BEZEL, 40), Vector3(cx + LCD_AT.x, LCD_AT.y - LCD_SIZE.y / 2.0 - 0.08, FACE_Z + 0.08))
	_panel(LCD_SIZE, _lcd_texture(), Vector3(cx + LCD_AT.x, LCD_AT.y, FACE_Z + 0.12))
	_panel(Vector2(1.22, 0.84), tex.play_all, Vector3(cx - 0.56, PLAY_ALL_Y, FACE_Z + 0.08))
	big_button = _round_button(Vector3(cx + 0.72, PLAY_ALL_Y, FACE_Z + 0.06))
	_panel(Vector2(2.36, 0.56), tex.notice, Vector3(cx, 3.42, FACE_Z + 0.08))
	# The bill acceptor.
	var chrome := _lit(CHROME, 70, 0.6)
	_box(Vector3(1.7, 0.98, 0.16), _lit(Color("#0b0b0f"), 50), Vector3(cx, SLOT_BASE, FACE_Z + 0.08))
	_box(Vector3(1.25, 0.12, 0.34), chrome, Vector3(cx, SLOT_BASE + 0.36, FACE_Z + 0.24))
	_box(Vector3(1, 0.06, 0.05), _flat(Color("#5dff7a")), Vector3(cx, SLOT_BASE + 0.56, FACE_Z + 0.18), false)
	_box(Vector3(0.5, 0.08, 0.04), _flat(Color("#ffb13b")), Vector3(cx, SLOT_BASE + 0.14, FACE_Z + 0.18), false)
	_panel(Vector2(1.7, 0.36), tex.insert, Vector3(cx, SLOT_BASE - 0.3, FACE_Z + 0.08))
	_bill = _card(Vector2(0.62, 1.3), _bill_mat, true)
	_bill.visible = false


## Paint jobs, each [canvas size, commands].
func _console_jobs() -> Dictionary:
	return {
		"sign": [Vector2(472, 260), [
			_rect(0, 0, 472, 260, RED),
			_frame(10, 10, 452, 240, 5.0, Color("#fff4d9")),
			_text("PULL", Vector2(236, 122), "slab", 112, Color("#fff4d9")),
			_text("TABS", Vector2(236, 228), "slab", 112, Color("#fff4d9"))]],
		"play_all": [Vector2(244, 168), [
			_rect(0, 0, 244, 168, STICKER),
			_frame(7, 7, 230, 154, 6.0, RED),
			_text("PLAY ALL", Vector2(122, 76), "cond_bold", 50, RED),
			_text("MAX. 100", Vector2(122, 116), "cond_bold", 30, RED),
			_text("TICKETS", Vector2(122, 148), "cond_bold", 30, RED)]],
		"notice": [Vector2(472, 112), [
			_rect(0, 0, 472, 112, STICKER),
			_text("WINNING TICKETS ARE PAID", Vector2(236, 46), "cond_bold", 32, DARK),
			_text("IN EGG MONEY. NO CHANGE GIVEN.", Vector2(236, 88), "cond_bold", 32, DARK)]],
		"insert": [Vector2(340, 72), [
			_rect(0, 0, 340, 72, Color("#ffd23a")),
			_text("INSERT BILLS HERE", Vector2(170, 50), "cond_bold", 38, DARK)]],
	}


## The rule beside a stack: a tick every 100 tickets, a number every 200.
func _rail_job() -> Array:
	var cmds := [_rect(0, 0, 40, 256, Color("#d9d6cf"))]
	for i in 11:
		cmds.append(_rect(0, i * 25, 18 if i % 5 == 0 else 10, 2, Color("#2a2428")))
	for i in range(1, 5):
		cmds.append(_text(str(1000 - i * 200), Vector2(27, i * 50 + 6), "cond_bold", 15, Color("#2a2428")))
	return [Vector2(40, 256), cmds]


## The edge of a stack of tickets: paper and the form's colour, turn about.
func _edge_job(form: FormDef) -> Array:
	var cmds := []
	for y in range(0, 64, 2):
		cmds.append(_rect(0, y, 32, 2, Color("#efe7d6") if y % 4 else form.colors.edge))
	return [Vector2(32, 64), cmds]


## The plate under a column's button: the key that presses it, the form's name and the price.
func _plate_job(i: int, form: FormDef) -> Array:
	var ink: Color = form.colors.edge
	if ink.get_luminance() > 0.45:
		ink = form.colors.ink   # a pale edge colour would not read on the plate
	var name_cmd := _text(form.name.to_upper(), Vector2(108, 38), "cond_bold", 27, ink)
	name_cmd.max_width = 196.0
	var price := _text("$%d" % form.price, Vector2(126, 87), "slab", 38, RED)
	price.max_width = 150.0
	return [Vector2(216, 100), [
		_rect(0, 0, 216, 100, STICKER),
		_frame(3, 3, 210, 94, 4.0, RED),
		name_cmd,
		_rect(10, 54, 34, 36, DARK),
		_text(str(i + 1), Vector2(27, 83), "lcd", 34, LCD_BG),
		price]]


func _paint_into(out: Dictionary, key, size: Vector2, cmds: Array) -> void:
	out[key] = await painter.paint(size, cmds)


func _front_into(out: Dictionary, key: String, form: FormDef, art_for: Callable) -> void:
	out[key] = await art_for.call(form)


## LCD lines: credit on top, status below, then the column the pointer is on.
func set_lcd(top: String, sub: String, info := "") -> void:
	if not built:
		return
	_lcd_top.text = top
	_lcd_sub.text = sub
	_lcd_info.text = info


func press_button(i: int) -> void:
	if built and i >= 0 and i < _press.size():
		_press[i] = 1.0


## Which cabinet column `i` is in: 0 left, 1 right.
func side_of(column: int) -> int:
	return 0 if column < _left else 1


## Column stock heights: share of each box still in it (0..1).
func set_stock(shares: Array) -> void:
	if not built:
		return
	for i in mini(shares.size(), _stock.size()):
		var h := maxf(0.03, float(shares[i]) * STACK_MAX)
		_stock[i].scale.y = h
		_stock[i].position.y = STACK_BASE + h / 2.0


## The stacks in the two output trays (left cabinet, right cabinet). Each entry:
## {count, art, card}: how many tickets from that cabinet are held, and the art and
## card size of the one on top (the ticket sold last there).
func set_trays(piles: Array) -> void:
	if not built:
		return
	for k in mini(piles.size(), _tray_piles.size()):
		var p: Dictionary = piles[k]
		var pile := _tray_piles[k]
		var count: int = p.get("count", 0)
		pile.visible = count > 0
		var th := clampf(count / 500.0 * 1.3, 0.02, 1.3)
		var card: Vector2 = p.get("card", Vector2(1.4, 2.0))
		pile.scale = Vector3(card.x / 1.4, th, card.y / 2.0)
		# A card longer than the shelf is deep lies along it.
		pile.rotation.y = PI / 2.0 if card.y > TRAY_DEPTH else 0.0
		pile.position = Vector3(_tray_x(k), TRAY_Y + th / 2.0, 2.3)
		if p.get("art") != null:
			_stack_mats[k].albedo_texture = p.art


## Where the tickets of a cabinet pile up (the only cabinet's tray when there is one).
func _tray_x(side: int) -> float:
	return _cabinets[side if _cabinets[side].n > 0 else 0].x


## A ticket shoots out of column `column` into its cabinet's tray, showing the front of
## the form that was bought (`art`, with `card` its size in table units).
func launch_card(art: Texture2D = null, card := Vector2(1.4, 2.0), column := 0) -> void:
	if not built:
		return
	for i in _fly.size():
		if not _fly[i].visible:
			_fly[i].visible = true
			_fly_mats[i].albedo_texture = art
			_fly[i].scale = Vector3(card.x / 1.4, 1.0, card.y / 2.0)
			var from: float = _column_x[clampi(column, 0, _column_x.size() - 1)]
			_fly_state[i] = {"life": 0.0, "from": from, "x": _tray_x(side_of(column)) + (randf() - 0.5) * 1.1,
				"spin": (randf() - 0.5) * 3.0}
			_fly[i].position = Vector3(from, 0.15, 1.7)
			return


## Paints the bills the slot takes (a stage's stake changes their values).
func paint_bills(values: Array) -> void:
	var fresh := {}
	var count := 0
	for v in values:
		if _bill_tex.has(v):
			continue
		_bill_tex[v] = null
		count += 1
		var label := "$%d" % v
		_paint_into(fresh, v, Vector2(136, 64), [
			_rect(0, 0, 136, 64, Color("#8fbf8a")),
			_frame(5, 5, 126, 54, 3.0, Color("#27553a")),
			_text(label, Vector2(68, 44), "slab", 34 if label.length() <= 4 else 27, Color("#17392a"))])
	while fresh.size() < count:
		await get_tree().process_frame
	for v in fresh:
		_bill_tex[v] = fresh[v]


## The bill sliding into the slot; t is the feed progress 0..1, value 0 hides it.
func show_bill(value: int, t: float) -> void:
	if not built:
		return
	_bill.visible = value > 0
	if value == 0:
		return
	_bill_mat.albedo_texture = _bill_tex.get(value)
	var y := SLOT_BASE + 0.48
	if t < Economy.BILL_SOUND_AT:
		var k := _ease(t / Economy.BILL_SOUND_AT)
		_bill.position = Vector3(_console_x, lerpf(y - 1.2, y, k), lerpf(4.4, 2.45, k))
		_bill.scale.z = 1.0
	else:
		var k := (t - Economy.BILL_SOUND_AT) / (1.0 - Economy.BILL_SOUND_AT)
		_bill.scale.z = maxf(0.01, 1.0 - k)
		_bill.position = Vector3(_console_x, y, 1.8 + 0.65 * (1.0 - k))


## PLAY ALL blinks (it blinks while dispensing too, as in the web build).
func set_blink(on: bool) -> void:
	if not built:
		return
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
	if not built:
		return
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
		_fly[i].position = Vector3(lerpf(s.from, s.x, l), 0.15 + sin(l * PI) * 0.25 - l * 0.75, 1.7 + l * 0.8)
		_fly[i].rotation = Vector3(l * 0.7, s.spin * l, 0)


## Points in machine space the bill window lines up with (slot, side, window height).
func anchor(name: String) -> Vector3:
	match name:
		"slot":
			return to_global(Vector3(_console_x, SLOT_BASE + 0.5, FACE_Z + 0.15))
		"side":
			return to_global(Vector3(width / 2.0, SLOT_BASE + 0.5, FACE_Z))
	return to_global(Vector3(_console_x, SLOT_BASE + 1.4, FACE_Z + 0.15))


## The machine's width in world units, for the camera.
func world_width() -> float:
	return width * SCALE

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
	_register(cap)
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
	_register(cap)
	return cap


func _register(cap: Node3D) -> void:
	buttons.append(cap)
	_press.append(0.0)
	_button_z.append(cap.position.z)


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
## Three lines: the credit, the status, and the column under the pointer.
func _lcd_texture() -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(LCD_PX)
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bg := ColorRect.new()
	bg.color = LCD_BG
	bg.size = LCD_PX
	vp.add_child(bg)
	var rule := ColorRect.new()
	rule.color = Color(LCD_INK, 0.35)
	rule.position = Vector2(12, 99)
	rule.size = Vector2(LCD_PX.x - 24, 2)
	vp.add_child(rule)
	_lcd_top = Label.new()
	_lcd_sub = Label.new()
	_lcd_info = Label.new()
	for spec in [[_lcd_top, 38, 6.0], [_lcd_sub, 32, 52.0], [_lcd_info, 32, 104.0]]:
		var l: Label = spec[0]
		l.add_theme_font_override("font", FONT_LCD)
		l.add_theme_font_size_override("font_size", spec[1])
		l.add_theme_color_override("font_color", LCD_INK)
		l.position = Vector2(14, spec[2])
		l.size = Vector2(LCD_PX.x - 28, 40)
		l.clip_text = true
		vp.add_child(l)
	add_child(vp)
	return vp.get_texture()


static func _rect(x: float, y: float, w: float, h: float, c: Color) -> Dictionary:
	return {"k": "poly", "pts": PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)]), "color": c}


static func _frame(x: float, y: float, w: float, h: float, width: float, c: Color) -> Dictionary:
	return {"k": "stroke", "pts": PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)]),
		"closed": true, "width": width, "color": c, "join": "miter", "dash": null}


static func _text(t: String, pos: Vector2, font: String, size: float, c: Color, align := "center") -> Dictionary:
	return {"k": "text", "text": t, "pos": pos, "font": font, "size": size, "align": align, "max_width": 0.0,
		"color": c, "outline": 0.0, "dir": ""}


static func _ease(t: float) -> float:
	return 2.0 * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0
