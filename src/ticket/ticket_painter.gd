class_name TicketPainter
extends Node
## Renders TicketArt commands to textures through an off-screen SubViewport.
## Drawing happens at SCALE times the layout canvas so print stays crisp up close.

const SCALE := 2.0
const BUILTIN_FONTS := {
	"slab": "res://assets/fonts/alfa-slab-one-latin-400-normal.woff2",
	"cond": "res://assets/fonts/oswald-latin-400-normal.woff2",
	"cond_bold": "res://assets/fonts/oswald-latin-600-normal.woff2",
	"lcd": "res://assets/fonts/vt323-latin-400-normal.woff2",
	"hand": "res://assets/fonts/patrick-hand-latin-400-normal.woff2",
}

static var _fonts := {}
static var _textures := {}


## Draws commands into a new texture of canvas_size * SCALE pixels.
func paint(canvas_size: Vector2, cmds: Array, scale := SCALE) -> ImageTexture:
	var img := await paint_image(canvas_size, cmds, scale)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func paint_image(canvas_size: Vector2, cmds: Array, scale := SCALE) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(ceili(canvas_size.x * scale), ceili(canvas_size.y * scale))
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var canvas := _Canvas.new()
	canvas.cmds = cmds
	canvas.scale_factor = scale
	vp.add_child(canvas)
	add_child(vp)
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img


static func font(key: String, dir: String) -> Font:
	var path: String = BUILTIN_FONTS.get(key, dir.path_join(key))
	if not _fonts.has(path):
		if BUILTIN_FONTS.has(key):
			_fonts[path] = load(path)
		else:
			var f := FontFile.new()
			f.load_dynamic_font(path)  # raw bytes from the pack, never load()
			_fonts[path] = f
	return _fonts[path]


static func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = PackAssets.texture(path)
	return _textures[path]


class _Canvas extends Node2D:
	var cmds: Array = []
	var scale_factor := 2.0

	func _draw() -> void:
		var s := scale_factor
		for c in cmds:
			match c.k:
				"poly":
					var pts: PackedVector2Array = Transform2D.IDENTITY.scaled(Vector2(s, s)) * c.pts
					if pts.size() >= 3:
						draw_colored_polygon(pts, c.color)
						# No 2D MSAA in the Compatibility renderer: a thin antialiased rim smooths the edge.
						var rim := pts.duplicate()
						rim.append(pts[0])
						draw_polyline(rim, c.color, 1.0, true)
				"stroke":
					_stroke(Transform2D.IDENTITY.scaled(Vector2(s, s)) * c.pts, c.closed, c.width * s, c.color, c.join, c.dash * s if c.dash != null else null)
				"text":
					_text(c, s)
				"tex":
					var t := TicketPainter.texture(c.path)
					if t:
						var r: Rect2 = c.rect
						draw_texture_rect(t, Rect2(r.position * s, r.size * s), false)

	func _text(c: Dictionary, s: float) -> void:
		var f := TicketPainter.font(c.font, c.dir)
		var size := maxi(1, roundi(c.size * s))
		var w := f.get_string_size(c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var sx := 1.0
		if c.max_width > 0 and w > c.max_width * s:
			sx = c.max_width * s / w  # squeeze like canvas fillText(maxWidth)
		var x: float = c.pos.x * s
		match c.align:
			"center":
				x -= w * sx / 2.0
			"right":
				x -= w * sx
		draw_set_transform(Vector2(x, c.pos.y * s), 0.0, Vector2(sx, 1.0))
		if c.outline > 0:
			draw_string_outline(f, Vector2.ZERO, c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, roundi(c.outline * s), c.color)
		else:
			draw_string(f, Vector2.ZERO, c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c.color)
		draw_set_transform(Vector2.ZERO)

	## Polyline stroke with butt caps and miter (limit 10, like canvas) or round joins.
	func _stroke(pts: PackedVector2Array, closed: bool, width: float, color: Color, join: String, dash) -> void:
		var runs: Array = [pts]
		if dash != null:
			runs = _dash(pts, closed, dash)
			closed = false
		for run in runs:
			var p: PackedVector2Array = run
			var n := p.size()
			if n < 2:
				continue
			var segs := n if closed else n - 1
			var h := width / 2.0
			for i in segs:
				var a := p[i]
				var b := p[(i + 1) % n]
				var nrm := (b - a).normalized().orthogonal() * h
				draw_colored_polygon(PackedVector2Array([a + nrm, b + nrm, b - nrm, a - nrm]), color)
				draw_line(a + nrm, b + nrm, color, 1.0, true)
				draw_line(a - nrm, b - nrm, color, 1.0, true)
			var joints := n if closed else n - 2
			for j in joints:
				var i := (j + (0 if closed else 1)) % n
				var prev := p[(i - 1 + n) % n]
				var cur := p[i]
				var nxt := p[(i + 1) % n]
				if join == "round":
					draw_circle(cur, h, color)
					continue
				var d1 := (cur - prev).normalized()
				var d2 := (nxt - cur).normalized()
				var turn := d1.cross(d2)
				if absf(turn) < 1e-6:
					continue
				var side := -1.0 if turn > 0 else 1.0  # outer side of the bend
				var o1 := cur + d1.orthogonal() * h * side
				var o2 := cur + d2.orthogonal() * h * side
				var miter_dir := (d1.orthogonal() + d2.orthogonal()).normalized() * side
				var cos_half := miter_dir.dot(d1.orthogonal() * side)
				var miter_len := h / maxf(cos_half, 1e-4)
				if miter_len / h <= 10.0:
					draw_colored_polygon(PackedVector2Array([cur, o1, cur + miter_dir * miter_len, o2]), color)
				else:
					draw_colored_polygon(PackedVector2Array([cur, o1, o2]), color)

	## Splits a polyline into dash runs; the pattern continues around corners.
	func _dash(pts: PackedVector2Array, closed: bool, dash: Vector2) -> Array:
		var p := pts.duplicate()
		if closed:
			p.append(pts[0])
		var runs: Array = []
		var on := true
		var left := dash.x
		var cur := PackedVector2Array([p[0]])
		for i in p.size() - 1:
			var a := p[i]
			var b := p[i + 1]
			var seg := a.distance_to(b)
			var t := 0.0
			while seg - t > 1e-6:
				var take := minf(left, seg - t)
				t += take
				left -= take
				var at := a.lerp(b, t / seg)
				if on:
					cur.append(at)
				if left <= 1e-6:
					if on:
						runs.append(cur)
					on = not on
					left = dash.y if not on else dash.x
					cur = PackedVector2Array([at])
		if on and cur.size() > 1:
			runs.append(cur)
		return runs
