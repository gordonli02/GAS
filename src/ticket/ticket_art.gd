class_name TicketArt
extends RefCounted
## Turns a layout plus ticket data into flat draw commands in canvas units.
## Pure logic: no nodes, no rendering. TicketPainter draws the commands.
##
## Commands (Dictionary, key "k"):
##   poly   {pts: PackedVector2Array, color}
##   stroke {pts, closed, width, color, join, dash: Vector2 or null}
##   text   {text, pos, font, size, color, align, max_width, outline (width) / outline_color}
##   tex    {path, rect}

const WORDS := ["ZERO", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE"]
const CIRCLE_SEGMENTS := 96
const ROUND_STEPS := 8        ## segments per rounded corner of a rect


## Printed front. `serial` is empty for box art (tray stack, discard pile).
static func front(form: FormDef, serial: String) -> Array:
	var ctx := _ctx(form, {"serial": serial}, -1, {})
	return _layers(form.layout.front, ctx, Transform2D.IDENTITY)


## The inside the flaps cover, for one ticket.
static func interior(form: FormDef, t: Dictionary) -> Array:
	var inside: Dictionary = form.layout.interior
	var win: bool = t.tier >= 0
	var flags := {"win": win, "lose": not win, "verify": t.get("verify", "") != ""}
	var vars := {"serial": t.serial, "prize": str(t.prize), "verify": t.get("verify", "")}
	var ctx := _ctx(form, vars, t.tier if win else -1, flags)
	var out := _layers(inside.get("base", []), ctx, Transform2D.IDENTITY)
	if win and form.win_display == "whole":
		out.append_array(_layers(inside.winner, ctx, Transform2D.IDENTITY))
		return out
	for i in inside.slots.size():
		var slot: Dictionary = inside.slots[i]
		if form.wins_by_group() and t.wins[i] >= 0:
			# This group's own prize: its tier, its amount, a verify code on a top prize.
			var tier: int = t.wins[i]
			var own := _ctx(form, {"serial": t.serial, "prize": str(int(form.tiers[tier].prize)),
				"verify": t.get("verify", "")}, tier,
				{"win": true, "lose": false, "verify": form.is_top(tier) and t.get("verify", "") != ""})
			var r: Array = slot.rect
			out.append_array(_layers(inside.win_slot, own, Transform2D(0, Vector2(r[0], r[1]))))
		elif win and not form.wins_by_group() and i == t.win_group:
			var r: Array = slot.rect
			out.append_array(_layers(inside.win_slot, ctx, Transform2D(0, Vector2(r[0], r[1]))))
		else:
			out.append_array(_digit_group(inside.digits, slot, t.groups[i], t.marks[i], ctx))
	return out


## Canvas size and commands for one flap's cover.
static func cover(form: FormDef, flap_index: int) -> Dictionary:
	var flap: Dictionary = form.layout.flaps[flap_index]
	var c = flap.cover
	if c is String:
		c = form.layout.cover_templates[c]
	var r: Array = flap.rect
	var size := Vector2(r[2], r[3])
	if c.has("canvas"):
		size = Vector2(c.canvas[0], c.canvas[1])
	var ctx := _ctx(form, {"flap_no": str(flap_index + 1)}, -1, {})
	return {"canvas": size, "cmds": _layers(c.layers, ctx, Transform2D.IDENTITY)}


static func band(form: FormDef) -> Dictionary:
	var b: Dictionary = form.layout.band
	var ctx := _ctx(form, {}, -1, {})
	return {"canvas": Vector2(b.canvas[0], b.canvas[1]), "cmds": _layers(b.layers, ctx, Transform2D.IDENTITY)}


static func canvas_size(form: FormDef) -> Vector2:
	var c: Array = form.layout.card.canvas
	return Vector2(c[0], c[1])


## Replaces {name} with values; unknown names stay as they are.
static func fill_text(text: String, vars: Dictionary) -> String:
	var out := text
	for k in vars:
		out = out.replace("{" + k + "}", str(vars[k]))
	return out


static func _ctx(form: FormDef, vars: Dictionary, win_tier: int, flags: Dictionary) -> Dictionary:
	var v := {
		"title": " ".join(form.title),
		"name": form.name,
		"code": form.code,
		"price": str(form.price),
	}
	v.merge(vars, true)
	return {"form": form, "vars": v, "tier": -1, "win_tier": win_tier, "flags": flags,
		"dir": form.layout.get("_dir", form.source_dir), "clip": null}


static func _color(c: String, ctx: Dictionary) -> Color:
	var form: FormDef = ctx.form
	match c:
		"edge", "head", "ink":
			return form.colors[c]
		"tile":
			return form.colors.tiles[ctx.tier]
		"win_tile":
			return form.colors.tiles[ctx.win_tier]
	if c.begins_with("tile."):
		return form.colors.tiles[c.trim_prefix("tile.").to_int()]
	return Color.html(c)


static func _layers(list: Array, ctx: Dictionary, xf: Transform2D) -> Array:
	var out := []
	for l in list:
		if l.has("if") and not ctx.flags.get(l["if"], false):
			continue
		var n := 1
		var step := Vector2.ZERO
		if l.has("repeat"):
			n = int(l.repeat.count)
			step = Vector2(l.repeat.step[0], l.repeat.step[1])
		for i in n:
			out.append_array(_layer(l, ctx, xf * Transform2D(0, step * i)))
	return out


static func _layer(l: Dictionary, ctx: Dictionary, xf: Transform2D) -> Array:
	match l.type:
		"rect":
			var r: Array = l.rect
			if float(l.get("radius", 0.0)) > 0.0:
				return _shape(_round_rect(Rect2(r[0], r[1], r[2], r[3]), float(l.radius)), _color(l.fill, ctx), ctx, xf)
			return _shape(PackedVector2Array([Vector2(r[0], r[1]), Vector2(r[0] + r[2], r[1]),
				Vector2(r[0] + r[2], r[1] + r[3]), Vector2(r[0], r[1] + r[3])]), _color(l.fill, ctx), ctx, xf)
		"circle":
			return _shape(_ellipse(Vector2(l.center[0], l.center[1]), Vector2(l.radius, l.radius), 0.0),
				_color(l.fill, ctx), ctx, xf)
		"ellipse":
			return _shape(_ellipse(Vector2(l.center[0], l.center[1]), Vector2(l.radii[0], l.radii[1]),
				float(l.get("rotation", 0.0))), _color(l.fill, ctx), ctx, xf)
		"path":
			var pts := PackedVector2Array()
			for p in l.points:
				pts.append(Vector2(p[0], p[1]))
			var out := []
			if l.has("fill"):
				out.append_array(_shape(pts, _color(l.fill, ctx), ctx, xf))
			if l.has("stroke"):
				out.append({"k": "stroke", "pts": xf * pts, "closed": l.get("closed", false),
					"width": float(l.width), "color": _color(l.stroke, ctx), "join": l.get("join", "miter"),
					"dash": Vector2(l.dash[0], l.dash[1]) if l.has("dash") else null})
			return out
		"text":
			var cmd := {"k": "text", "text": fill_text(l.text, ctx.vars), "pos": xf * Vector2(l.pos[0], l.pos[1]),
				"font": l.font, "size": float(l.size), "align": l.get("align", "left"),
				"max_width": float(l.get("max_width", 0.0)), "dir": ctx.dir}
			var out := []
			if l.has("stroke"):
				var o := cmd.duplicate()
				o.color = _color(l.stroke, ctx)
				o.outline = float(l.get("stroke_width", 1.0))
				out.append(o)
			if l.has("fill"):
				var f := cmd.duplicate()
				f.color = _color(l.fill, ctx)
				f.outline = 0.0
				out.append(f)
			return out
		"image":
			var r: Array = l.rect
			return [{"k": "tex", "path": ctx.dir.path_join(l.src), "rect": _xrect(xf, Rect2(r[0], r[1], r[2], r[3]))}]
		"symbol":
			var tier_i: int = ctx.tier
			var t = l.get("tier", null)
			if t is String and t == "win":
				tier_i = ctx.win_tier
			elif t != null:
				tier_i = int(t)
			var tier: Dictionary = ctx.form.tiers[tier_i]
			var path: String = tier.symbol_large if l.get("variant", "") == "large" else tier.symbol
			var s := float(l.size)
			var c := Vector2(l.center[0], l.center[1])
			return [{"k": "tex", "path": path, "rect": _xrect(xf, Rect2(c - Vector2(s, s) / 2, Vector2(s, s)))}]
		"group":
			var g := xf
			if l.has("offset"):
				g = xf * Transform2D(0, Vector2(l.offset[0], l.offset[1]))
			var sub := ctx
			if l.has("clip"):
				var r: Array = l.clip
				sub = ctx.duplicate()
				sub.clip = g * PackedVector2Array([Vector2(r[0], r[1]), Vector2(r[0] + r[2], r[1]),
					Vector2(r[0] + r[2], r[1] + r[3]), Vector2(r[0], r[1] + r[3])])
			return _layers(l.layers, sub, g)
		"each_tier":
			var out := []
			var cols := int(l.columns)
			# "tiers" picks which tiers get a cell, in that order; without it, all of them.
			var picked: Array = l.get("tiers", range(ctx.form.tiers.size()))
			for n in picked.size():
				var i := int(picked[n])
				var sub := ctx.duplicate()
				sub.tier = i
				sub.vars = ctx.vars.duplicate()
				sub.vars.count = str(ctx.form.tiers[i].printed_count)
				sub.vars.tier_prize = str(ctx.form.tiers[i].prize)
				var cell := Vector2(l.origin[0] + (n % cols) * l.step[0], l.origin[1] + (n / cols) * l.step[1])
				out.append_array(_layers(l.layers, sub, xf * Transform2D(0, cell)))
			return out
	return []


static func _shape(pts: PackedVector2Array, color: Color, ctx: Dictionary, xf: Transform2D) -> Array:
	var p := xf * pts
	if ctx.clip == null:
		return [{"k": "poly", "pts": p, "color": color}]
	var out := []
	for piece in Geometry2D.intersect_polygons(p, ctx.clip):
		out.append({"k": "poly", "pts": piece, "color": color})
	return out


static func _ellipse(c: Vector2, r: Vector2, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in CIRCLE_SEGMENTS:
		var a := TAU * i / CIRCLE_SEGMENTS
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	return pts


## A rectangle with rounded corners (the radius is held to half the shorter side).
static func _round_rect(r: Rect2, radius: float) -> PackedVector2Array:
	var rad := minf(radius, minf(r.size.x, r.size.y) / 2.0)
	var pts := PackedVector2Array()
	var corners := [r.position + Vector2(r.size.x - rad, rad), r.end - Vector2(rad, rad),
		r.position + Vector2(rad, r.size.y - rad), r.position + Vector2(rad, rad)]
	for c in 4:
		for i in ROUND_STEPS + 1:
			var a := -PI / 2.0 + (c + float(i) / ROUND_STEPS) * PI / 2.0
			pts.append(corners[c] + Vector2(cos(a), sin(a)) * rad)
	return pts


static func _xrect(xf: Transform2D, r: Rect2) -> Rect2:
	return Rect2(xf * r.position, r.size)


static func _digit_group(style: Dictionary, slot: Dictionary, digits: PackedInt32Array, marks: PackedInt32Array, ctx: Dictionary) -> Array:
	var out := []
	var anchor := Vector2(slot.anchor[0], slot.anchor[1])
	var axis := Vector2.RIGHT if style.direction == "row" else Vector2.DOWN
	var n := digits.size()
	var color := _color(style.color, ctx)
	for k in n:
		var at := anchor + axis * (k - (n - 1) / 2.0) * float(style.pitch)
		var d := digits[k]
		out.append(_styled(str(d), at, style.digit, color, ctx))
		out.append(_styled(WORDS[d], at, style.caption, color, ctx))
		out.append(_styled(str(marks[k]), at, style.mark, color, ctx))
	return out


static func _styled(text: String, at: Vector2, st: Dictionary, color: Color, ctx: Dictionary) -> Dictionary:
	return {"k": "text", "text": text, "pos": at + Vector2(st.offset[0], st.offset[1]), "font": st.font,
		"size": float(st.size), "align": "center", "max_width": float(st.get("max_width", 0.0)),
		"color": color, "outline": 0.0, "dir": ctx.dir}
