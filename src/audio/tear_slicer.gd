class_name TearSlicer
extends RefCounted
## Maps tear progress steps to a stretch of a recorded rip, crackle by crackle.
## Same mapping as the web build: steps are spread over the crackle marks, and
## the slice runs from one crackle's start to a later crackle's start (or the end).

const FADE := 0.015   ## seconds of fade after the slice end


## Returns Vector2(start, end) in seconds, or Vector2(-1, -1) when no new crackle starts.
static func slice(marks: PackedFloat32Array, duration: float, from_step: int, to_step: int, steps: int) -> Vector2:
	var n := marks.size()
	var i := int(floor(float(from_step) / steps * n))
	var j := int(floor(float(to_step) / steps * n))
	if j <= i:
		return Vector2(-1, -1)
	var start := marks[i]
	var end := marks[j] if j < n else duration
	return Vector2(start, end)
