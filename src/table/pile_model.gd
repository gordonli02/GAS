class_name PileModel
extends RefCounted
## How the discard pile grows. Pure logic.
##
## The first INDIVIDUAL tickets each add a card. After that the pile grows in
## steps: each range of tickets opened shows a fixed heap, plus up to TOPPERS of
## the latest tickets lying on top, so every toss still visibly lands. The next
## range's heap is at least as big as the last one with all its toppers, so the
## pile never shrinks.
##
## Card spots come from one seeded drop sequence: card i always lands in the same
## place, so a bigger heap is the smaller one with more cards dropped on it, and
## because drops stay near the middle the pile rises into a mound as it grows.

const INDIVIDUAL := 12
const TOPPERS := 5
## [first ticket of the range, heap cards shown]
const RANGES := [
	[13, 13], [20, 18], [30, 24], [50, 30], [100, 40], [200, 55],
	[400, 75], [700, 95], [1000, 120], [2000, 150], [4000, 180],
]
const MAX_CARDS := 185
const CARD := Vector2(1.4, 2.0)
const THICK := 0.012
const CELL := 0.05
const MAX_SLOPE := 0.5    ## steepest a card may lean on the pile (rise per unit)
const SINK := 0.008       ## a resting card may dip this far into the cards under it
const REPOSE := 0.32      ## steeper than this, a landing card slides downhill
const SLIDE_STEP := 0.1
const SLIDE_STEPS := 30
const CANDIDATES := 3

var spots: Array = []   ## {pos: Vector3 (relative to the pile centre), yaw, tilt: Vector2}


func _init(seed_text := "pile") -> void:
	_drop_all(SeededRng.new(seed_text))


## Heap cards (not counting toppers) for a number of tickets opened.
static func heap_cards(opened: int) -> int:
	if opened <= INDIVIDUAL:
		return maxi(opened, 0)
	var n := INDIVIDUAL
	for r in RANGES:
		if opened >= r[0]:
			n = r[1]
	return n


## First ticket number of the range `opened` falls in.
static func range_start(opened: int) -> int:
	if opened <= INDIVIDUAL:
		return 0
	var s := INDIVIDUAL + 1
	for r in RANGES:
		if opened >= r[0]:
			s = r[0]
	return s


## Cards on show in total (heap plus toppers).
static func shown(opened: int) -> int:
	if opened <= INDIVIDUAL:
		return maxi(opened, 0)
	return heap_cards(opened) + mini(TOPPERS, opened - range_start(opened) + 1)


## Where the next tossed ticket lands: the spot it will occupy (relative to the centre).
func landing_spot(opened_before: int) -> Vector3:
	var i := mini(shown(opened_before + 1) - 1, MAX_CARDS - 1)
	return spots[i].pos


## A drop sequence: each card falls near the centre (more often the closer it is).
## Where the pile under it is steeper than REPOSE it slides downhill until it can
## rest, so the pile spreads into a mound instead of a tower. It then settles onto
## the slope (a plane fitted to what it lands on) and becomes part of the slope.
func _drop_all(r: SeededRng) -> void:
	var half := 4.0
	var n := int(half * 2.0 / CELL)
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for i in MAX_CARDS:
		var radius := 0.35 + 0.075 * sqrt(float(i))
		var spread := 0.7 if i < INDIVIDUAL else 1.3
		var yaw := (r.next_float() - 0.5) * 2.0 * spread
		var axis_x := Vector2(cos(yaw), -sin(yaw))     # card width direction on the table
		var axis_z := Vector2(sin(yaw), cos(yaw))      # card length direction
		# Of a few spots near the middle, the card ends up in the lowest: valleys fill
		# first, so the pile rises as a mound rather than a column.
		var c := Vector2.ZERO
		var fit := {}
		for k in (1 if i < INDIVIDUAL else CANDIDATES):
			var a := r.next_float() * TAU
			var d := radius * pow(r.next_float(), 1.3)
			var cc := Vector2(cos(a) * d, sin(a) * d * 0.85)
			var ff := _fit(heights, n, half, cc, axis_x, axis_z)
			if fit.is_empty() or ff.top < fit.top:
				c = cc
				fit = ff
		for k in SLIDE_STEPS:
			var grad: Vector2 = axis_x * fit.bu + axis_z * fit.bv
			if grad.length() <= REPOSE:
				break
			c -= grad.normalized() * SLIDE_STEP
			fit = _fit(heights, n, half, c, axis_x, axis_z)
		var bu := clampf(fit.bu, -MAX_SLOPE, MAX_SLOPE)
		var bv := clampf(fit.bv, -MAX_SLOPE, MAX_SLOPE)
		# Lift the plane just enough that the card does not sink into what is under it.
		var a0: float = fit.a0
		var lift := 0.0
		for sm in fit.samples:
			lift = maxf(lift, sm.z - (a0 + bu * sm.x + bv * sm.y) - SINK)
		a0 += lift
		spots.append({"pos": Vector3(c.x, a0 + THICK / 2.0, c.y), "yaw": yaw, "tilt": Vector2(-atan(bv), atan(bu))})
		for gu in range(-4, 5):
			for gv in range(-6, 7):
				var u := gu / 8.0 * CARD.x
				var v := gv / 12.0 * CARD.y
				_set_height(heights, n, half, c + axis_x * u + axis_z * v, a0 + bu * u + bv * v + THICK)


## Least-squares plane h = a0 + bu * u + bv * v over a grid under a card at c.
static func _fit(heights: PackedFloat32Array, n: int, half: float, c: Vector2, axis_x: Vector2, axis_z: Vector2) -> Dictionary:
	var samples := []
	var sum := 0.0
	var su := 0.0
	var sv := 0.0
	var uu := 0.0
	var vv := 0.0
	for gu in range(-2, 3):
		for gv in range(-3, 4):
			var u := gu / 4.0 * CARD.x
			var v := gv / 6.0 * CARD.y
			var h := _height(heights, n, half, c + axis_x * u + axis_z * v)
			samples.append(Vector3(u, v, h))
			sum += h
			su += u * h
			sv += v * h
			uu += u * u
			vv += v * v
	var top := -1.0
	for sm in samples:
		top = maxf(top, sm.z)
	return {"a0": sum / samples.size(), "bu": su / uu, "bv": sv / vv, "samples": samples, "top": top}


static func _cell(n: int, half: float, p: Vector2) -> int:
	var x := clampi(int((p.x + half) / CELL), 0, n - 1)
	var z := clampi(int((p.y + half) / CELL), 0, n - 1)
	return z * n + x


static func _height(h: PackedFloat32Array, n: int, half: float, p: Vector2) -> float:
	return h[_cell(n, half, p)]


static func _set_height(h: PackedFloat32Array, n: int, half: float, p: Vector2, v: float) -> void:
	var i := _cell(n, half, p)
	h[i] = maxf(h[i], v)
