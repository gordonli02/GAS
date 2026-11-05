class_name FlapLayout
extends RefCounted
## Where a layout's flaps sit on the card and which ones can tear as a pair.
## Pure logic. Card local frame: x right, y up, origin at the card centre.
## Each flap's own frame starts on its hinge: +x runs across the flap away from
## the hinge, +y along the hinge.

const PAIR_EDGE := 0.095      ## press this close to a shared edge to tear both flaps
const NEIGHBOUR_GAP := 0.06   ## largest gap between flaps that still counts as a shared edge


## One entry per flap: {xf: Transform2D (flap frame -> card), w, h, hinge, rect: Rect2 (canvas),
## below: int, above: int} where below/above are the neighbours across the flap's -y / +y edge.
static func build(layout: Dictionary) -> Array:
	var size := Vector2(layout.card.size[0], layout.card.size[1])
	var canvas := Vector2(layout.card.canvas[0], layout.card.canvas[1])
	var out := []
	for spec in layout.flaps:
		var r := Rect2(spec.rect[0], spec.rect[1], spec.rect[2], spec.rect[3])
		var a := to_card(r.position, canvas, size)
		var b := to_card(r.end, canvas, size)
		var l := a.x
		var rr := b.x
		var t := a.y
		var bt := b.y
		var pos: Vector2
		var rot: float
		var w: float
		var h: float
		match spec.hinge:
			"left":
				pos = Vector2(l, (t + bt) / 2.0); rot = 0.0; w = rr - l; h = t - bt
			"right":
				pos = Vector2(rr, (t + bt) / 2.0); rot = PI; w = rr - l; h = t - bt
			"top":
				pos = Vector2((l + rr) / 2.0, t); rot = -PI / 2.0; w = t - bt; h = rr - l
			_:
				pos = Vector2((l + rr) / 2.0, bt); rot = PI / 2.0; w = t - bt; h = rr - l
		out.append({"xf": Transform2D(rot, pos), "w": w, "h": h, "hinge": spec.hinge, "rect": r, "below": -1, "above": -1})
	if layout.get("pairs", "none") == "adjacent":
		_link(out)
	return out


## Which neighbour tears along with flap i when pressed at local height y, or -1.
## is_free(j) says whether flap j is still closed and not finishing by itself.
static func mate(frames: Array, i: int, y: float, is_free: Callable) -> int:
	var f: Dictionary = frames[i]
	if f.h / 2.0 + y < PAIR_EDGE and f.below >= 0 and is_free.call(f.below):
		return f.below
	if f.h / 2.0 - y < PAIR_EDGE and f.above >= 0 and is_free.call(f.above):
		return f.above
	return -1


## Local y of the edge flap i shares with flap j: each peels from the shared edge.
static func shared_edge_y(frames: Array, i: int, j: int) -> float:
	var f: Dictionary = frames[i]
	return -f.h / 2.0 if f.below == j else f.h / 2.0


static func to_card(p: Vector2, canvas: Vector2, size: Vector2) -> Vector2:
	return Vector2((p.x / canvas.x - 0.5) * size.x, (0.5 - p.y / canvas.y) * size.y)


static func to_canvas(p: Vector2, canvas: Vector2, size: Vector2) -> Vector2:
	return Vector2((p.x / size.x + 0.5) * canvas.x, (0.5 - p.y / size.y) * canvas.y)


## Flaps with the same hinge, the same span across the flap, lying edge to edge.
static func _link(frames: Array) -> void:
	for i in frames.size():
		var fi: Dictionary = frames[i]
		for j in frames.size():
			var fj: Dictionary = frames[j]
			if i == j or fi.hinge != fj.hinge:
				continue
			var o: Vector2 = (fi.xf.affine_inverse() * fj.xf).origin
			if absf(o.x) > 0.01 or absf(fj.w - fi.w) > 0.01:
				continue
			var gap: float = absf(o.y) - (fi.h + fj.h) / 2.0
			if absf(gap) > NEIGHBOUR_GAP:
				continue
			if o.y < 0:
				fi.below = j
			else:
				fi.above = j
