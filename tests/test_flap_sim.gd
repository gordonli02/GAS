extends "res://tests/test_case.gd"
## Paper model and hand-following rules from MIGRATION.md "Tearing".

const W := 1.2933  # single flap width (1.4 minus margins)
const H := 1.8933
const DT := 1.0 / 60.0


func _near(a: float, b: float, tol: float, msg: String) -> void:
	check(absf(a - b) <= tol, "%s: expected %.5f, got %.5f" % [msg, b, a])


func test_fold_formula() -> void:
	var s := FlapSim.new(W, H)
	# Closed: every point of the flap lies before the fold, so it stays flat.
	for y in [-H / 2, 0.0, H / 2]:
		for x in [0.0, W / 2, W]:
			eq(s.deform(x, y), Vector2(x, 0.0), "closed flap is flat at %s,%s" % [x, y])
	s.f = W * 0.5
	s.y_grab = 0.0
	s.k = 0.0
	# open = 0.5, slope = 0.55 * (1 - 0.25)
	_near(s.fold_at(0.0), W * 0.5, 1e-6, "fold at grab height")
	_near(s.fold_at(0.4), W * 0.5 + 0.55 * 0.75 * 0.4, 1e-6, "fold spreads away from grab")
	s.k = 0.3
	_near(s.fold_at(0.4), W * 0.5 + 0.55 * 0.75 * 0.4 + 0.3 * 0.4, 1e-6, "k tilts the fold")
	s.f = W
	s.k = 0.42
	_near(s.fold_at(H / 2), minf(W + 0.55 * H / 2 + 0.42 * H / 2, W + 0.6), 1e-6, "fold clamps at w + 0.6")


func test_curl_geometry() -> void:
	var s := FlapSim.new(W, H)
	s.f = 0.6
	s.y_grab = 0.0
	var r := s.r
	# Just past the fold: on the curl.
	var d := r * PI / 2.0
	var p := s.deform(0.6 + d, 0.0)
	_near(p.x, 0.6 + r, 1e-6, "quarter curl x")
	_near(p.y, r, 1e-6, "quarter curl z")
	# Far past the fold: flipped flat at height 2r.
	p = s.deform(0.6 + PI * r + 0.3, 0.0)
	_near(p.x, 0.6 - 0.3, 1e-6, "folded-back x")
	_near(p.y, 2 * r, 1e-6, "folded-back z")


func test_resists_until_pop() -> void:
	var s := FlapSim.new(W, H)
	s.grab(0.2)
	_near(s.y_grab, 0.2, 1e-6, "tear starts where the player pressed")
	check(not s.pull_to(W - 0.09, 0.0), "no break before 0.1 pull")
	_near(s.target, W - 0.05, 1e-6, "held within 0.05 of closed")
	check(not s.torn, "still whole")
	check(s.pull_to(W - 0.11, 0.0), "breaks past 0.1")
	check(s.torn, "torn")
	_near(s.target, W - 0.11, 1e-6, "follows after the break")
	s.grab(-0.5)
	_near(s.y_grab, 0.2, 1e-6, "a torn flap keeps its tear line")


func test_k_follows_vertical_drag() -> void:
	var s := FlapSim.new(W, H)
	s.pull_to(W, 0.5)
	_near(s.k_target, 0.225, 1e-6, "k = dy * 0.45")
	s.pull_to(W, 5.0)
	_near(s.k_target, 0.42, 1e-6, "k clamps at 0.42")
	s.pull_to(W, -5.0)
	_near(s.k_target, -0.42, 1e-6, "k clamps at -0.42")


func test_release_finishes_or_springs_back() -> void:
	var s := FlapSim.new(W, H)
	s.pull_to(0.0, 0.0)
	s.f = W * 0.54  # 46% open
	s.release()
	check(s.auto, "past 45% open: finishes by itself")
	s = FlapSim.new(W, H)
	s.pull_to(0.0, 0.0)
	s.f = W * 0.56  # 44% open
	s.release()
	check(not s.auto, "under 45% open: springs back")
	_near(s.target, W - 0.02, 1e-6, "torn flap rests just open")
	s = FlapSim.new(W, H)
	s.pull_to(W - 0.04, 0.0)
	s.release()
	_near(s.target, W, 1e-6, "untorn flap closes fully")


func test_follow_rates() -> void:
	var s := FlapSim.new(W, H)
	s.torn = true
	s.target = 0.0
	s.step(DT, true)
	_near(s.f, W * exp(-30.0 * DT), 1e-6, "held: rate 30/s")
	s = FlapSim.new(W, H)
	s.torn = true
	s.target = 0.0
	s.step(DT, false)
	_near(s.f, W * exp(-16.0 * DT), 1e-6, "free: rate 16/s")


func test_auto_finish_speed_and_open() -> void:
	var s := FlapSim.new(W, H)
	check(s.start_auto(true), "space starts the tear")
	_near(s.y_grab, H / 2, 1e-6, "from the top corner")
	var t := 0.0
	var opened_at := -1.0
	while t < 2.0:
		var ev := s.step(DT, false)
		t += DT
		if ev.get("opened", false):
			opened_at = t
			break
	check(opened_at > 0, "auto flap opens")
	# Target runs to 0 in 1/2.8 s; f trails it at 16/s, so it opens a little later.
	# Space runs the flap SPACE_SPEED times as fast as a tear the hand let go of.
	var pace := 1.0 / 2.8 / FlapSim.SPACE_SPEED
	check(opened_at > pace and opened_at < pace + 0.3 / FlapSim.SPACE_SPEED, "opens at the auto-finish pace (%.3f s)" % opened_at)


## Seconds until a flap that finishes by itself has settled open.
func _settle_time(s: FlapSim) -> float:
	var t := 0.0
	while not s.is_settled() and t < 3.0:
		s.step(DT, false)
		t += DT
	return t


func test_space_opens_half_again_as_fast() -> void:
	eq(FlapSim.SPACE_SPEED, 1.5, "Space: 50% faster (G, M8.5)")
	var space := FlapSim.new(W, H)
	space.start_auto(true)
	# The same tear at the hand's pace: torn at the same corner, let go, finishing by itself.
	var hand := FlapSim.new(W, H)
	hand.start_auto(true)
	hand.speed = 1.0
	var a := _settle_time(space)
	var b := _settle_time(hand)
	check(absf(b / a - 1.5) < 0.05, "Space settles 1.5 times as fast (%.3f s against %.3f s)" % [a, b])
	# A tear the hand lets go of keeps the old pace, and a fresh ticket starts over.
	var let_go := FlapSim.new(W, H)
	let_go.pull_to(W * 0.3, 0.0)
	let_go.f = let_go.target
	let_go.release()
	check(let_go.auto and let_go.speed == 1.0, "released by hand: the usual pace")
	space.reset()
	eq(space.speed, 1.0, "reset: the usual pace again")


func test_settles_open() -> void:
	var s := FlapSim.new(W, H)
	s.start_auto(false)
	var t := 0.0
	while not s.is_settled() and t < 3.0:
		s.step(DT, false)
		t += DT
	check(s.is_settled(), "settles")
	eq(s.f, 0.0, "fully open")
	_near(s.r, FlapSim.R_END, 1e-6, "curl eases to 0.04")


func test_crackle_steps_cover_the_tear_once() -> void:
	# Whatever the hand speed, the slices cover steps 0..15 exactly once, in order.
	for speed in [0.2, 1.0, 6.0]:
		var s := FlapSim.new(W, H)
		s.grab(0.0)
		var covered := 0
		var target := W
		var t := 0.0
		var held := true
		while not s.open and t < 20.0:
			if held:
				target = maxf(0.0, target - W * speed * DT)
				s.pull_to(target, 0.0)
				# Let go once the hand is well past halfway and the paper has caught up.
				if s.openness() > 0.6:
					s.release()
					held = false
			var ev := s.step(DT, held)
			if ev.has("slice"):
				eq(ev.slice.x, covered, "slice starts where the last ended (speed %s)" % speed)
				check(ev.slice.y > ev.slice.x, "slice moves forward")
				covered = ev.slice.y
			t += DT
		eq(covered, FlapSim.STEPS, "all %d steps played at speed %s" % [FlapSim.STEPS, speed])


func test_slow_hands_make_slow_crackles() -> void:
	var marks := PackedFloat32Array([0.0, 0.0855, 0.1686, 0.2083, 0.2328, 0.269, 0.3341, 0.3819])
	var dur := 0.439
	# One step at a time: each crackle plays on its own, in order, and they join up.
	var pieces := []
	for s in FlapSim.STEPS:
		var v := TearSlicer.slice(marks, dur, s, s + 1, FlapSim.STEPS)
		if v.x >= 0:
			pieces.append(v)
	eq(pieces.size(), marks.size(), "slow: one slice per crackle")
	for i in pieces.size():
		eq(pieces[i].x, marks[i], "slice %d starts at its crackle" % i)
	_near(pieces[pieces.size() - 1].y, dur, 1e-6, "last slice runs to the end")
	# All at once: one slice, the whole rip.
	var whole := TearSlicer.slice(marks, dur, 0, 15, 15)
	_near(whole.x, 0.0, 1e-6, "fast: from the start")
	_near(whole.y, dur, 1e-6, "fast: to the end")
	eq(TearSlicer.slice(marks, dur, 3, 3, 15), Vector2(-1, -1), "no progress, no sound")
