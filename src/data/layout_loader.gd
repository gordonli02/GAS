class_name LayoutLoader
extends RefCounted
## Validates a ticket layout (format 1) against the form that uses it.
## Every error names the file and the field. See packs/README.md for the format.

const FORMAT := 1
const FONTS := ["slab", "cond", "cond_bold", "lcd"]
const FONT_EXTENSIONS := ["ttf", "otf", "woff", "woff2"]
const SHAPES := ["rect", "circle", "ellipse", "path"]
const LAYER_TYPES := ["rect", "circle", "ellipse", "path", "text", "image", "symbol", "group", "each_tier"]
const HINGES := ["left", "right", "top", "bottom"]
const CONDITIONS := ["verify", "win", "lose"]
const CARD_MIN := 0.8
const CARD_MAX := 2.6
const MAX_FLAPS := 12
const MAX_LAYERS := 600

## Text variables allowed in each part of a layout.
const VARS_COMMON := ["title", "name", "code", "price"]
const VARS := {
	"front": ["serial"],
	"tier": ["serial", "count", "tier_prize"],
	"interior": ["serial", "prize", "verify"],
	"win": ["serial", "prize", "verify"],
	"cover": ["flap_no"],
	"band": [],
}

static var _var_re := RegEx.create_from_string("\\{([a-z_]+)\\}")


## `ctx` is PackLoader's validation context; `form` is the FormDef being loaded.
static func validate(ctx, layout, form: FormDef, where: String) -> Dictionary:
	var v := _V.new(ctx, form, where)
	if not layout is Dictionary:
		v.err("", "must be an object")
		return {}
	if layout.get("format") != FORMAT and layout.get("format") != float(FORMAT):
		v.err("format", "must be %d" % FORMAT)
		return {}

	var card = layout.get("card")
	if not card is Dictionary:
		v.err("card", "missing")
		return {}
	var size := v.vec2(card, "size", "card.size")
	if size.x < CARD_MIN or size.x > CARD_MAX or size.y < CARD_MIN or size.y > CARD_MAX:
		v.err("card.size", "width and height must be %.1f to %.1f" % [CARD_MIN, CARD_MAX])
	var canvas := v.vec2(card, "canvas", "card.canvas")
	if canvas.x < 16 or canvas.y < 16 or canvas.x > 4096 or canvas.y > 4096:
		v.err("card.canvas", "must be 16 to 4096")

	v.layers(layout.get("front"), "front", "front")

	var inside = layout.get("interior")
	if not inside is Dictionary:
		v.err("interior", "missing")
	else:
		if inside.has("base"):
			v.layers(inside.base, "interior.base", "interior")
		var slots = inside.get("slots")
		if not slots is Array or slots.size() != form.digit_groups.size():
			v.err("interior.slots", "needs one slot per digit group (%d)" % form.digit_groups.size())
		else:
			for i in slots.size():
				var s = slots[i]
				var p := "interior.slots[%d]" % i
				if not s is Dictionary:
					v.err(p, "must be an object")
					continue
				v.vec2(s, "anchor", p + ".anchor")
				if form.win_display == "one_group" or s.has("rect"):
					v.rect(s, "rect", p + ".rect")
		v.digits(inside.get("digits"), "interior.digits")
		if form.win_display == "whole":
			v.layers(inside.get("winner"), "interior.winner", "win")
		else:
			v.layers(inside.get("win_slot"), "interior.win_slot", "win")

	var templates = layout.get("cover_templates", {})
	if not templates is Dictionary:
		v.err("cover_templates", "must be an object")
		templates = {}
	for k in templates:
		v.cover(templates[k], "cover_templates." + str(k))

	var flaps = layout.get("flaps")
	if not flaps is Array or flaps.is_empty() or flaps.size() > MAX_FLAPS:
		v.err("flaps", "needs 1 to %d flaps" % MAX_FLAPS)
		flaps = []
	var rects: Array[Rect2] = []
	for i in flaps.size():
		var f = flaps[i]
		var p := "flaps[%d]" % i
		if not f is Dictionary:
			v.err(p, "must be an object")
			continue
		var r := v.rect(f, "rect", p + ".rect")
		if r.position.x < -0.5 or r.position.y < -0.5 or r.end.x > canvas.x + 0.5 or r.end.y > canvas.y + 0.5:
			v.err(p + ".rect", "must lie inside the card")
		for j in rects.size():
			var o := rects[j].intersection(r)
			if o.get_area() > 0.5:
				v.err(p + ".rect", "overlaps flaps[%d]" % j)
		rects.append(r)
		if not HINGES.has(f.get("hinge")):
			v.err(p + ".hinge", "must be one of " + ", ".join(HINGES))
		if f.has("side_pull") and not f.side_pull is bool:
			v.err(p + ".side_pull", "must be true or false")
		var c = f.get("cover")
		if c is String:
			if not templates.has(c):
				v.err(p + ".cover", "no cover template named '%s'" % c)
		else:
			v.cover(c, p + ".cover")

	var pairs = layout.get("pairs", "none")
	if not pairs in ["none", "adjacent"]:
		v.err("pairs", "must be 'none' or 'adjacent'")

	var band = layout.get("band")
	if band != null:
		if not band is Dictionary:
			v.err("band", "must be an object or null")
		else:
			var h := v.num(band, "height", "band.height")
			if h < 0.05 or h > 0.6:
				v.err("band.height", "must be 0.05 to 0.6")
			v.vec2(band, "canvas", "band.canvas")
			v.layers(band.get("layers"), "band.layers", "band")
			if band.has("breaks"):
				var b = band.breaks
				var good: bool = b is Array and not b.is_empty()
				if good:
					for m in b:
						good = good and BandRules.MODES.has(m)
				if not good:
					v.err("band.breaks", "must list one or both of " + ", ".join(BandRules.MODES))

	var slide := v.vec2(layout, "reveal_slide", "reveal_slide")
	if absf(slide.x) > 1 or absf(slide.y) > 1:
		v.err("reveal_slide", "each value must be -1 to 1")

	if v.count > MAX_LAYERS:
		v.err("", "too many layers (%d, max %d)" % [v.count, MAX_LAYERS])
	return layout if v.ok else {}


class _V:
	var ctx
	var form: FormDef
	var where: String
	var ok := true
	var count := 0

	func _init(c, f: FormDef, w: String) -> void:
		ctx = c
		form = f
		where = w

	func err(field: String, msg: String) -> void:
		ok = false
		ctx.err("%s %s: %s" % [where, field, msg] if field != "" else "%s: %s" % [where, msg])

	func num(d: Dictionary, key: String, p: String) -> float:
		var x = d.get(key)
		if not (x is float or x is int):
			err(p, "must be a number")
			return 0.0
		return float(x)

	func vec2(d: Dictionary, key: String, p: String) -> Vector2:
		var x = d.get(key)
		if not (x is Array and x.size() == 2 and (x[0] is float or x[0] is int) and (x[1] is float or x[1] is int)):
			err(p, "must be [x, y]")
			return Vector2.ZERO
		return Vector2(x[0], x[1])

	func rect(d: Dictionary, key: String, p: String) -> Rect2:
		var x = d.get(key)
		if not (x is Array and x.size() == 4):
			err(p, "must be [x, y, w, h]")
			return Rect2()
		for n in x:
			if not (n is float or n is int):
				err(p, "must be [x, y, w, h]")
				return Rect2()
		if x[2] <= 0 or x[3] <= 0:
			err(p, "width and height must be positive")
		return Rect2(x[0], x[1], x[2], x[3])

	func color(c, p: String, part: String) -> void:
		if c is String:
			if c.begins_with("#"):
				if Color.html_is_valid(c):
					return
			elif c in ["edge", "head", "ink"]:
				return
			elif c == "tile":
				if part == "tier":
					return
				err(p, "'tile' only works inside each_tier")
				return
			elif c == "win_tile":
				if part == "win":
					return
				err(p, "'win_tile' only works in winner / win_slot")
				return
			elif c.begins_with("tile.") and c.trim_prefix("tile.").is_valid_int():
				var i: int = c.trim_prefix("tile.").to_int()
				if i >= 0 and i < form.tiers.size():
					return
				err(p, "%s: the form has %d tiers" % [c, form.tiers.size()])
				return
		err(p, "'%s' is not a colour (#rrggbb, #rrggbbaa, edge, head, ink, tile.N, tile, win_tile)" % str(c))

	func font(f, p: String) -> void:
		if f is String and FONTS.has(f):
			return
		if f is String and FONT_EXTENSIONS.has(f.get_extension().to_lower()):
			ctx.check_file(f, where + " " + p, FONT_EXTENSIONS)
			return
		err(p, "font must be one of %s or a font file in the pack" % ", ".join(FONTS))

	func text_style(d, p: String) -> void:
		if not d is Dictionary:
			err(p, "must be an object")
			return
		font(d.get("font"), p + ".font")
		if num(d, "size", p + ".size") <= 0:
			err(p + ".size", "must be positive")
		vec2(d, "offset", p + ".offset")

	func digits(d, p: String) -> void:
		if not d is Dictionary:
			err(p, "missing")
			return
		if not d.get("direction") in ["row", "column"]:
			err(p + ".direction", "must be 'row' or 'column'")
		if num(d, "pitch", p + ".pitch") <= 0:
			err(p + ".pitch", "must be positive")
		color(d.get("color"), p + ".color", "interior")
		for k in ["digit", "caption", "mark"]:
			text_style(d.get(k), p + "." + k)

	func cover(c, p: String) -> void:
		if not c is Dictionary:
			err(p, "must be an object or a cover template name")
			return
		if c.has("canvas"):
			vec2(c, "canvas", p + ".canvas")
		layers(c.get("layers"), p + ".layers", "cover")

	func layers(list, p: String, part: String, clip := false) -> void:
		if not list is Array:
			err(p, "must be a list of layers")
			return
		for i in list.size():
			layer(list[i], "%s[%d]" % [p, i], part, clip)

	func layer(l, p: String, part: String, clip: bool) -> void:
		count += 1
		if not l is Dictionary:
			err(p, "must be an object")
			return
		var t = l.get("type")
		if not LAYER_TYPES.has(t):
			err(p + ".type", "unknown layer type '%s'" % str(t))
			return
		if clip and not SHAPES.has(t):
			err(p, "only rect, circle, ellipse and path can sit inside a clipped group")
		if l.has("repeat"):
			var r = l.repeat
			if not r is Dictionary or num(r, "count", p + ".repeat.count") < 1 or r.count > 200:
				err(p + ".repeat", "count must be 1 to 200")
			elif r is Dictionary:
				vec2(r, "step", p + ".repeat.step")
		if l.has("if") and not CONDITIONS.has(l.get("if")):
			err(p + ".if", "must be one of " + ", ".join(CONDITIONS))
		match t:
			"rect":
				rect(l, "rect", p + ".rect")
				color(l.get("fill"), p + ".fill", part)
			"circle":
				vec2(l, "center", p + ".center")
				num(l, "radius", p + ".radius")
				color(l.get("fill"), p + ".fill", part)
			"ellipse":
				vec2(l, "center", p + ".center")
				vec2(l, "radii", p + ".radii")
				if l.has("rotation"):
					num(l, "rotation", p + ".rotation")
				color(l.get("fill"), p + ".fill", part)
			"path":
				var pts = l.get("points")
				if not pts is Array or pts.size() < 2:
					err(p + ".points", "needs at least 2 points")
				else:
					for k in pts.size():
						vec2({"p": pts[k]}, "p", "%s.points[%d]" % [p, k])
				if not l.has("fill") and not l.has("stroke"):
					err(p, "needs fill or stroke")
				if l.has("fill"):
					color(l.fill, p + ".fill", part)
				if l.has("stroke"):
					color(l.stroke, p + ".stroke", part)
					if num(l, "width", p + ".width") <= 0:
						err(p + ".width", "must be positive")
					if clip:
						err(p, "strokes cannot sit inside a clipped group")
				if l.has("dash"):
					var dsh = l.dash
					if not (dsh is Array and dsh.size() == 2 and dsh[0] > 0 and dsh[1] > 0):
						err(p + ".dash", "must be [on, off] lengths")
				if l.has("join") and not l.join in ["miter", "round"]:
					err(p + ".join", "must be 'miter' or 'round'")
			"text":
				if not l.get("text") is String:
					err(p + ".text", "must be text")
				else:
					var allowed: Array = VARS_COMMON + VARS[part]
					for m in LayoutLoader._var_re.search_all(l.text):
						if not allowed.has(m.get_string(1)):
							err(p + ".text", "{%s} is not available here" % m.get_string(1))
				vec2(l, "pos", p + ".pos")
				font(l.get("font"), p + ".font")
				if num(l, "size", p + ".size") <= 0:
					err(p + ".size", "must be positive")
				if not l.has("fill") and not l.has("stroke"):
					err(p, "needs fill or stroke")
				if l.has("fill"):
					color(l.fill, p + ".fill", part)
				if l.has("stroke"):
					color(l.stroke, p + ".stroke", part)
					num(l, "stroke_width", p + ".stroke_width")
				if l.has("align") and not l.align in ["left", "center", "right"]:
					err(p + ".align", "must be left, center or right")
				if l.has("max_width") and num(l, "max_width", p + ".max_width") <= 0:
					err(p + ".max_width", "must be positive")
			"image":
				ctx.check_file(str(l.get("src", "")), where + " " + p + ".src", PackLoader.IMAGE_EXTENSIONS)
				rect(l, "rect", p + ".rect")
			"symbol":
				var tier = l.get("tier", null)
				if tier == null:
					if part != "tier":
						err(p + ".tier", "required outside each_tier")
				elif tier is String and tier == "win":
					if part != "win":
						err(p + ".tier", "'win' only works in winner / win_slot")
				elif not ((tier is float or tier is int) and int(tier) >= 0 and int(tier) < form.tiers.size()):
					err(p + ".tier", "must be a tier index, 'win', or left out inside each_tier")
				vec2(l, "center", p + ".center")
				if num(l, "size", p + ".size") <= 0:
					err(p + ".size", "must be positive")
				if l.has("variant") and l.variant != "large":
					err(p + ".variant", "only 'large' is supported")
			"group":
				if l.has("offset"):
					vec2(l, "offset", p + ".offset")
				var c := clip
				if l.has("clip"):
					rect(l, "clip", p + ".clip")
					c = true
				layers(l.get("layers"), p + ".layers", part, c)
			"each_tier":
				if part != "front":
					err(p, "each_tier only works on the front")
				vec2(l, "origin", p + ".origin")
				vec2(l, "step", p + ".step")
				if num(l, "columns", p + ".columns") < 1:
					err(p + ".columns", "must be at least 1")
				layers(l.get("layers"), p + ".layers", "tier", clip)
