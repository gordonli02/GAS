class_name BandRules
extends RefCounted
## How a drag on a band is read. Pure logic.
## "slide": drag sideways and the band slides off the card.
## "split": drag up or down and the band tears in the middle, the halves falling
## away to the left and right. A layout lists which of these its band allows.

const BREAK := 0.34      ## drag this far to snap the band
const DECIDE := 0.03     ## hand travel before the drag is read as sideways or vertical
const SLACK := 0.5       ## the band follows the hand at most this far
const MODES := ["slide", "split"]


## `delta` is the pointer travel on the card (x right, y up). Returns "" while undecided
## or when the direction moved in is not allowed.
static func mode(delta: Vector2, allowed: Array) -> String:
	if maxf(absf(delta.x), absf(delta.y)) < DECIDE:
		return ""
	var m := "split" if absf(delta.y) > absf(delta.x) else "slide"
	if allowed.has(m):
		return m
	return "slide" if allowed.has("slide") and absf(delta.x) >= DECIDE else ""


## Travel along the chosen mode's axis.
static func travel(m: String, delta: Vector2) -> float:
	return delta.x if m == "slide" else delta.y


static func breaks(m: String, delta: Vector2) -> bool:
	return m != "" and absf(travel(m, delta)) > BREAK


## Space picks one of the allowed ways at random.
static func random_mode(allowed: Array, roll: float) -> String:
	return allowed[mini(int(roll * allowed.size()), allowed.size() - 1)]
