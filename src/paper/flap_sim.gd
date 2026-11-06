class_name FlapSim
extends RefCounted
## One paper flap: the fold model and how it follows the hand.
## Pure logic, ported from the web build. A flap is hinged at x = 0 and spans
## x in [0, w], y in [-h/2, h/2] in its own frame; f is where the free edge's fold sits
## (f = w closed, f = 0 fully open).

const CORNER := 0.55          ## fold slope near closed: the peel leads from the grabbed height
const R_START := 0.085        ## curl radius while peeling
const R_END := 0.04           ## curl radius once settled open
const FOLD_LIMIT := 0.6       ## fold may run this far past the free edge
const POP_PULL := 0.1         ## pull needed to break the paper
const POP_HOLD := 0.05        ## before the break, f stays within this of closed
const AUTO_OPEN := 0.45       ## released past this share open, the flap finishes itself
const TORN_REST := 0.02       ## a torn flap that springs back stays this far open
const RATE_HELD := 30.0
const RATE_FREE := 16.0
const RATE_K := 14.0
const AUTO_SPEED := 2.8       ## widths per second when finishing by itself
const SPACE_SPEED := 1.5      ## a flap opened with Space tears and settles this much faster (G, M8.5)
const SETTLE_TIME := 0.22
const STEPS := 15             ## progress steps that drive tear crackles
const K_GAIN := 0.45
const K_MAX := 0.42
const DRAG_DECIDE := 0.03     ## hand travel before a drag is read as up or sideways

var w: float
var h: float
var f: float
var target: float
var k := 0.0
var k_target := 0.0
var y_grab := 0.0
var slope := CORNER
var r := R_START
var torn := false
var auto := false
var open := false
var speed := 1.0            ## time scale of this flap's own motion (SPACE_SPEED once Space opens it)
var settle := 0.0
var ticks := 0              ## progress steps already turned into crackles
var tear_clip := -1         ## which recorded rip this flap uses; chosen by the audio side


func _init(width: float, height: float) -> void:
	w = width
	h = height
	reset()


func reset() -> void:
	f = w
	target = w
	k = 0.0
	k_target = 0.0
	y_grab = h / 2.0
	slope = CORNER
	r = R_START
	torn = false
	auto = false
	open = false
	speed = 1.0
	settle = 0.0
	ticks = 0
	tear_clip = -1


## Share of the flap that is open, 0..1.
func openness() -> float:
	return 1.0 - f / w


## Where the fold line crosses height y.
func fold_at(y: float) -> float:
	var o := 1.0 - f / w
	var s := slope * (1.0 - o * o)
	var d := y - y_grab
	return clampf(f + s * absf(d) + k * d, 0.0, w + FOLD_LIMIT)


## Bent position (x, z) of a flat flap point (x, y).
func deform(x: float, y: float) -> Vector2:
	var fx := fold_at(y)
	var dist := x - fx
	if dist <= 0.0:
		return Vector2(x, 0.0)
	var theta := dist / r
	if theta < PI:
		return Vector2(fx + r * sin(theta), r * (1.0 - cos(theta)))
	return Vector2(fx - (dist - PI * r), 2.0 * r)


## Press on the flap at height y. A torn flap keeps its original tear line.
func grab(y: float) -> void:
	if not torn:
		y_grab = clampf(y, -h / 2.0, h / 2.0)


## How a drag on a flap is read, decided once the hand has moved DRAG_DECIDE:
## "up" pulls the free edge toward the hinge (the original way); "side" is a
## swipe along the hinge, allowed only on flaps marked side_pull.
## `delta` is the pointer travel in the flap frame. Returns "" while undecided.
static func drag_mode(delta: Vector2, side_allowed: bool) -> String:
	if not side_allowed:
		return "up"
	if maxf(absf(delta.x), absf(delta.y)) < DRAG_DECIDE:
		return ""
	return "side" if absf(delta.y) > absf(delta.x) else "up"


## Pointer moved: `pull` is the requested f, `dy` the vertical drag since the press.
## Returns true on the frame the paper first breaks.
func pull_to(pull: float, dy: float) -> bool:
	k_target = clampf(dy * K_GAIN, -K_MAX, K_MAX)
	return _set_pull(pull)


## Sideways swipe along the hinge: the tear starts at the corner the hand moves
## away from (swipe toward +y: the -y corner) and opens as far as the hand travels,
## at the same rate as an upward pull. Returns true on the first break.
func side_pull_to(side: float) -> bool:
	if not torn and side != 0.0:
		y_grab = -signf(side) * h / 2.0
	k_target = 0.0
	return _set_pull(w - absf(side) / 2.0)


func _set_pull(pull: float) -> bool:
	var popped := false
	if not torn:
		if pull < w - POP_PULL:
			torn = true
			popped = true
		else:
			pull = maxf(pull, w - POP_HOLD)
	target = clampf(pull, 0.0, w)
	return popped


func release() -> void:
	k_target = 0.0
	if f < w * (1.0 - AUTO_OPEN):
		auto = true
	else:
		target = w - TORN_REST if torn else w


## Space: tear from a random top or bottom corner and finish by itself.
## Returns true if this started the tear (so the caller can play the break).
func start_auto(from_top: bool) -> bool:
	auto = true
	speed = SPACE_SPEED
	if torn:
		return false
	y_grab = h / 2.0 if from_top else -h / 2.0
	torn = true
	return true


## Advances one frame. Returns events:
##   "slice": Vector2i(from_step, to_step) when progress crossed crackle steps
##   "opened": true on the frame the flap finishes opening
func step(dt: float, held: bool) -> Dictionary:
	var ev := {}
	dt *= speed
	if open:
		settle = minf(1.0, settle + dt / SETTLE_TIME)
		f = lerpf(f, 0.0, 1.0 - pow(0.65, dt * 60.0))
		k = lerpf(k, 0.0, 1.0 - pow(0.7, dt * 60.0))
		r = lerpf(R_START, R_END, _ease(settle))
		if settle >= 1.0:
			f = 0.0
			k = 0.0
		return ev
	if auto:
		target = maxf(0.0, target - dt * w * AUTO_SPEED)
	f = lerpf(f, target, 1.0 - exp(-dt * (RATE_HELD if held else RATE_FREE)))
	k = lerpf(k, k_target, 1.0 - exp(-dt * RATE_K))
	var steps := int(floor((1.0 - f / w) * STEPS))
	if torn and steps > ticks:
		ev.slice = Vector2i(ticks, steps)
		ticks = steps
	if auto and f < 0.05:
		if ticks < STEPS:
			ev.slice = Vector2i(ev.slice.x if ev.has("slice") else ticks, STEPS)
			ticks = STEPS
		auto = false
		open = true
		settle = 0.0
		k_target = 0.0
		ev.opened = true
	return ev


func is_settled() -> bool:
	return open and settle >= 1.0


static func _ease(t: float) -> float:
	return 2.0 * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0
