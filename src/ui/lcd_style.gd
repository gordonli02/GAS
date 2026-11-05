class_name LcdStyle
extends RefCounted
## The UI look (G's pick "A, refined LCD"): dark metal plates with screws, recessed
## backlit LCD glass with a pixel grid, lit green keycaps and chrome keys.
## Textures are generated here so the look needs no image files.

const LCD := Color("#b8e23e")
const INK := Color("#1f2b08")
const DIM_TEXT := Color("#a9d433")
const BRIGHT_TEXT := Color("#d4f45a")
const GREY_TEXT := Color("#8a8893")
const METAL := Color("#232228")
const FRAME := Color("#0a0a0c")
const RIM := Color("#3a3842")
const FONT := preload("res://assets/fonts/vt323-latin-400-normal.woff2")
const FONT_COND := preload("res://assets/fonts/oswald-latin-600-normal.woff2")

static var _cache := {}


## A dark metal plate with a screw in each corner.
static func plate() -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = METAL
	s.set_corner_radius_all(10)
	s.border_color = FRAME
	s.set_border_width_all(2)
	s.shadow_color = Color(0, 0, 0, 0.55)
	s.shadow_size = 16
	s.shadow_offset = Vector2(0, 10)
	s.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", s)
	var screws := _Screws.new()
	screws.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(screws)
	return p


## Recessed backlit LCD glass; put labels inside. The pixel grid is drawn over them.
static func glass() -> PanelContainer:
	var g := PanelContainer.new()
	var s := StyleBoxTexture.new()
	s.texture = _texture("glass")
	s.set_content_margin_all(10)
	s.content_margin_left = 14
	s.content_margin_right = 14
	g.add_theme_stylebox_override("panel", s)
	return g


static func grid_overlay() -> Control:
	var c := _Grid.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func label(text: String, size: int, color := INK, font: Font = FONT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## A lit green keycap in a black bezel: inverted when pressed, dark when disabled.
static func key(text: String, size: int) -> Button:
	return _button(text, size, "key", INK, Color("#2a3a10"))


## A chrome push key.
static func chrome(text: String, size: int) -> Button:
	return _button(text, size, "chrome", Color("#1b1a1f"), Color("#a3a4ab"), FONT_COND)


static func _button(text: String, size: int, kind: String, ink: Color, off_ink: Color, font: Font = FONT) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", size)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s := StyleBoxTexture.new()
		var tex_state: String = "normal" if state == "hover" else state
		s.texture = _texture(kind + "_" + tex_state)
		s.texture_margin_left = 14
		s.texture_margin_right = 14
		s.texture_margin_top = 14
		s.texture_margin_bottom = 14
		s.set_content_margin_all(6)
		b.add_theme_stylebox_override(state, s)
	b.add_theme_color_override("font_color", ink)
	b.add_theme_color_override("font_hover_color", ink)
	b.add_theme_color_override("font_pressed_color", ink)
	b.add_theme_color_override("font_disabled_color", off_ink)
	return b


static func _texture(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var img: Image
	match id:
		"glass":
			img = _gradient_image(64, 40, Color("#d4f45a"), Color("#a9d433"), Color("#86ad1d"), 0.0, Color("#2b3a0b"), 2)
		"key_normal":
			img = _keycap(Color("#f3ffd0"), Color("#9fe33c"), Color("#3d7d0c"))
		"key_pressed":
			img = _keycap(Color("#cbe89a"), Color("#6fb424"), Color("#2b5a08"))
		"key_disabled":
			img = _keycap(Color("#5b6b3a"), Color("#3a4a1c"), Color("#232e10"))
		"chrome_normal":
			img = _chrome(Color("#e7ebef"), Color("#9aa2ab"), Color("#cfd5db"))
		"chrome_pressed":
			img = _chrome(Color("#b9bfc6"), Color("#7d848d"), Color("#a9b0b8"))
		"chrome_disabled":
			img = _chrome(Color("#77797f"), Color("#55575d"), Color("#66686e"))
	var t := ImageTexture.create_from_image(img)
	_cache[id] = t
	return t


## Radial backlight gradient with an inner-shadow edge.
static func _gradient_image(w: int, h: int, hot: Color, mid: Color, edge: Color, radius: float, line: Color, line_w: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u := (x + 0.5) / w * 2.0 - 1.0
			var v := ((y + 0.5) / h * 2.0 - 1.0) + 0.4
			var d := clampf(Vector2(u, v * 0.8).length(), 0.0, 1.4)
			var c := hot.lerp(mid, smoothstep(0.0, 0.7, d)).lerp(edge, smoothstep(0.7, 1.4, d))
			var inset := mini(mini(x, w - 1 - x), mini(y, h - 1 - y))
			if inset < line_w:
				c = line
			elif y < line_w + 4:
				c = c.lerp(Color.BLACK, 0.35 * (1.0 - float(y - line_w) / 4.0))
			img.set_pixel(x, y, c)
	return img


## A keycap: black rounded bezel, lit cap inset with a glow in the middle.
static func _keycap(hot: Color, mid: Color, edge: Color) -> Image:
	var n := 48
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var a := _rounded(p, Vector2(n, n), 8.0)
			var c := Color("#0d0d10")
			var cap := _rounded(p - Vector2(5, 5), Vector2(n - 10, n - 10), 6.0)
			if cap > 0.0:
				var u := (p.x / n) * 2.0 - 1.0
				var v := (p.y / n) * 2.0 - 1.1
				var d := Vector2(u, v).length()
				c = hot.lerp(mid, smoothstep(0.0, 0.6, d)).lerp(edge, smoothstep(0.6, 1.2, d))
			c.a = a
			img.set_pixel(x, y, c)
	return img


static func _chrome(top: Color, mid: Color, bottom: Color) -> Image:
	var w := 48
	var h := 40
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var t := (y + 0.5) / h
			var c := top.lerp(mid, smoothstep(0.0, 0.55, t)).lerp(bottom, smoothstep(0.55, 1.0, t))
			if y == 0:
				c = c.lerp(Color.WHITE, 0.6)
			if y >= h - 2:
				c = Color.BLACK
			c.a = _rounded(Vector2(x + 0.5, y + 0.5), Vector2(w, h), 6.0)
			img.set_pixel(x, y, c)
	return img


## Coverage (0..1) of a rounded rectangle at point p.
static func _rounded(p: Vector2, size: Vector2, r: float) -> float:
	if p.x < 0 or p.y < 0 or p.x > size.x or p.y > size.y:
		return 0.0
	var q := Vector2(clampf(p.x, r, size.x - r), clampf(p.y, r, size.y - r))
	return clampf(r - p.distance_to(q) + 0.5, 0.0, 1.0)


## Four screw heads at the corners of the plate (drawn just outside the content).
class _Screws extends Control:
	func _draw() -> void:
		for c in [Vector2(-9, -9), Vector2(size.x + 9, -9), Vector2(-9, size.y + 9), Vector2(size.x + 9, size.y + 9)]:
			draw_circle(c, 5.0, Color("#2a2b30"))
			draw_circle(c - Vector2(0.8, 0.8), 4.0, Color("#8d9098"))
			draw_circle(c - Vector2(1.5, 1.5), 1.6, Color("#d9dbe0"))
			draw_line(c + Vector2(-3, 1.8), c + Vector2(3, -1.8), Color("#222"), 1.5)


## Faint pixel grid over LCD glass.
class _Grid extends Control:
	func _draw() -> void:
		var col := Color(0, 0, 0, 0.06)
		var y := 2.0
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), col, 1.0)
			y += 3.0
		var x := 2.0
		while x < size.x:
			draw_line(Vector2(x, 0), Vector2(x, size.y), col, 1.0)
			x += 3.0
