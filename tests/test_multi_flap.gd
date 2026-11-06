extends "res://tests/test_case.gd"
## Five windows and jar tickets: flap geometry, pairs from every boundary, the band.

const TM := 1.4 * 16.0 / 420.0


func _near(a: float, b: float, msg: String) -> void:
	check(absf(a - b) < 1e-3, "%s: expected %.4f, got %.4f" % [msg, b, a])


func test_single_geometry() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var fr := FlapLayout.build(pack.form("catch").layout)
	eq(fr.size(), 1, "one flap")
	_near(fr[0].w, 1.4 - 2 * TM, "width")
	_near(fr[0].h, 2.0 - 2 * TM, "height")
	_near(fr[0].xf.origin.x, -0.7 + TM, "hinged on the left edge")
	eq(fr[0].below, -1, "no partner")


func test_windows_geometry_and_neighbours() -> void:
	var pack := core_pack()
	if pack == null:
		return
	# Hot Plate is a square card (G, after M8.6): 1.7 a side on a canvas of 510.
	var fr := FlapLayout.build(pack.form("plate").layout)
	eq(fr.size(), 5, "five windows")
	for i in 5:
		_near(fr[i].w, 1.7 - 2 * TM, "window %d width" % i)
		_near(fr[i].h, 89.2 * 1.7 / 510.0, "window %d height" % i)
		_near(fr[i].xf.origin.x, -0.85 + TM, "window %d hinged left" % i)
		eq(fr[i].below, i + 1 if i < 4 else -1, "window %d neighbour below" % i)
		eq(fr[i].above, i - 1 if i > 0 else -1, "window %d neighbour above" % i)
	check(fr[0].xf.origin.y > fr[4].xf.origin.y, "window 1 is the top one")


func test_pairs_from_every_boundary() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var fr := FlapLayout.build(pack.form("plate").layout)
	var all_free := func(_j: int) -> bool: return true
	var h: float = fr[0].h
	for b in 4:
		var upper := b
		var lower := b + 1
		# Pressing near the shared edge from either side tears both.
		eq(FlapLayout.mate(fr, upper, -h / 2.0 + 0.05, all_free), lower, "boundary %d from above" % (b + 1))
		eq(FlapLayout.mate(fr, lower, h / 2.0 - 0.05, all_free), upper, "boundary %d from below" % (b + 1))
		# Each peels from the shared edge.
		_near(FlapLayout.shared_edge_y(fr, upper, lower), -h / 2.0, "upper window peels from its bottom")
		_near(FlapLayout.shared_edge_y(fr, lower, upper), h / 2.0, "lower window peels from its top")
		# Just outside the 0.095 band: only one.
		eq(FlapLayout.mate(fr, upper, -h / 2.0 + 0.1, all_free), -1, "boundary %d, 0.1 away: single" % (b + 1))
	eq(FlapLayout.mate(fr, 0, 0.0, all_free), -1, "middle of a window: single")
	eq(FlapLayout.mate(fr, 0, h / 2.0 - 0.01, all_free), -1, "top edge of the top window: no partner")
	eq(FlapLayout.mate(fr, 4, -h / 2.0 + 0.01, all_free), -1, "bottom edge of the bottom window: no partner")
	# An opened (or finishing) neighbour is not torn again.
	var only_even := func(j: int) -> bool: return j % 2 == 0
	eq(FlapLayout.mate(fr, 1, -h / 2.0 + 0.02, only_even), 2, "free neighbour below pairs")
	eq(FlapLayout.mate(fr, 2, -h / 2.0 + 0.02, only_even), -1, "opened neighbour below does not")


func test_no_pairs_when_layout_says_none() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var layout: Dictionary = pack.form("plate").layout.duplicate(true)
	layout.pairs = "none"
	var fr := FlapLayout.build(layout)
	eq(FlapLayout.mate(fr, 0, -fr[0].h / 2.0 + 0.01, func(_j): return true), -1, "pairs off")


func test_jar_geometry() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var fr := FlapLayout.build(pack.form("spur").layout)
	eq(fr.size(), 1, "one flap")
	eq(fr[0].hinge, "top", "hinged at the top")
	_near(fr[0].w, 1.325 - 2 * TM, "peels across the card's height")
	_near(fr[0].h, 2.12 - 2 * TM, "hinge runs across the card's width")
	_near(fr[0].xf.origin.y, 1.325 / 2 - TM, "hinge on the top edge")
	# Flap +x points down the card: the free edge is the bottom.
	var free_edge: Vector2 = fr[0].xf * Vector2(fr[0].w, 0)
	_near(free_edge.y, -1.325 / 2 + TM, "free edge at the bottom")


## The long 21:9 cards (G, after M8.6). One Flock lies: one flap hinged along the top.
## Ka-Bawk! stands: one flap hinged on the left, as on Big Catch.
func test_long_card_geometry() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var layout: Dictionary = pack.form("flock").layout
	var fr := FlapLayout.build(layout)
	eq(fr.size(), 1, "flock: one flap")
	eq(fr[0].hinge, "top", "flock: hinged at the top")
	check(bool(layout.flaps[0].get("side_pull", false)), "flock: a sideways swipe opens it")
	_near(fr[0].w, 328.0 / 360.0 * 1.11, "flock: peels across the card's height")
	_near(fr[0].h, 808.0 / 840.0 * 2.59, "flock: hinge runs across the card's width")
	var free_edge: Vector2 = fr[0].xf * Vector2(fr[0].w, 0)
	check(free_edge.y < 0 and fr[0].xf.origin.y > 0, "flock: free edge at the bottom")
	fr = FlapLayout.build(pack.form("kabawk").layout)
	eq(fr.size(), 1, "kabawk: one flap")
	eq(fr[0].hinge, "left", "kabawk: hinged on the left")
	_near(fr[0].w, 328.0 / 360.0 * 1.11, "kabawk: peels across the card's width")
	_near(fr[0].h, 808.0 / 840.0 * 2.59, "kabawk: hinge runs down the card's height")
	check(fr[0].xf.origin.x < 0, "kabawk: hinge on the left edge")


func _band_rig() -> Dictionary:
	var pack := core_pack()
	var tree := Engine.get_main_loop() as SceneTree
	var view := TicketView.new()
	tree.root.add_child(view)
	view.form = pack.form("spur")
	view.size = Vector2(2.12, 1.325)
	view.reset()
	var flow := TicketFlow.new()
	flow.view = view
	flow.camera = CameraRig.new()
	flow.flecks = Flecks.new()
	tree.root.add_child(flow.flecks)
	flow.form = view.form
	flow.state = TicketFlow.State.FRONT
	return {"view": view, "flow": flow}


func _free_rig(rig: Dictionary) -> void:
	rig.view.queue_free()
	rig.flow.flecks.queue_free()
	rig.flow.camera.free()
	rig.flow.free()


func test_jar_cannot_flip_with_band_on() -> void:
	var rig := _band_rig()
	var view: TicketView = rig.view
	var flow: TicketFlow = rig.flow
	check(view.band_on, "jar ticket starts banded")
	flow.flip()
	eq(flow.state, TicketFlow.State.FRONT, "flip refused while banded")
	# A short drag does not break it and springs back.
	check(not view.drag_band(Vector2(0.3, 0), "slide"), "0.3 sideways: holds")
	check(view.band_on, "still banded")
	view.release_band()
	check(view.drag_band(Vector2(-0.35, 0.05), "slide"), "past 0.34 sideways: slides off (either way)")
	check(not view.band_on, "band off")
	eq(view.band_mode, "slide", "broke by sliding")
	flow.flip()
	eq(flow.state, TicketFlow.State.FLIP, "flips once the band is off")
	_free_rig(rig)


func test_band_splits_with_a_vertical_drag() -> void:
	var rig := _band_rig()
	var view: TicketView = rig.view
	var flow: TicketFlow = rig.flow
	eq(view.band_breaks(), ["slide", "split"], "Lucky Spur's band can slide or split")
	check(not view.drag_band(Vector2(0.02, 0.3), "split"), "0.3 up: holds")
	view.release_band()
	check(view.drag_band(Vector2(0.0, -0.35), "split"), "past 0.34 down: tears in two")
	eq(view.band_mode, "split", "broke by splitting")
	flow.flip()
	eq(flow.state, TicketFlow.State.FLIP, "flips once the band is off")
	_free_rig(rig)


func test_band_drag_direction() -> void:
	var both := ["slide", "split"]
	eq(BandRules.mode(Vector2(0.01, 0.02), both), "", "too little travel: undecided")
	eq(BandRules.mode(Vector2(0.2, 0.05), both), "slide", "left/right: slide")
	eq(BandRules.mode(Vector2(-0.2, 0.05), both), "slide", "either way")
	eq(BandRules.mode(Vector2(0.05, 0.2), both), "split", "up/down: split")
	eq(BandRules.mode(Vector2(0.05, -0.2), both), "split", "either way")
	eq(BandRules.mode(Vector2(0.0, 0.2), ["slide"]), "", "split not allowed: a pure vertical drag does nothing")
	eq(BandRules.mode(Vector2(0.05, 0.2), ["slide"]), "slide", "split not allowed: the sideways part slides")
	eq(BandRules.random_mode(both, 0.1), "slide", "space roll low")
	eq(BandRules.random_mode(both, 0.9), "split", "space roll high")
	eq(BandRules.random_mode(["slide"], 0.9), "slide", "space with one way")


func test_space_picks_a_band_break_at_random() -> void:
	var seen := {}
	for n in 40:
		var rig := _band_rig()
		rig.flow.primary()
		check(not rig.view.band_on, "space breaks the band")
		seen[rig.view.band_mode] = true
		_free_rig(rig)
	check(seen.has("slide") and seen.has("split"), "both ways come up over 40 presses: %s" % [seen.keys()])


func test_space_breaks_band_first() -> void:
	var rig := _band_rig()
	var view: TicketView = rig.view
	var flow: TicketFlow = rig.flow
	flow.primary()
	check(not view.band_on, "space breaks the band")
	eq(flow.state, TicketFlow.State.FRONT, "and does not flip in the same press")
	flow.primary()
	eq(flow.state, TicketFlow.State.FLIP, "second space flips")
	_free_rig(rig)


## Dealt back side up (the setting), a jar still wears its band: Space breaks the band
## first and only then starts the tear; a drag on the card takes the band, not the flap.
func test_band_comes_first_from_the_back_too() -> void:
	var rig := _band_rig()
	var view: TicketView = rig.view
	var flow: TicketFlow = rig.flow
	view.sims.append(FlapSim.new(1.9, 1.1))
	flow.state = TicketFlow.State.BACK
	eq(flow.hand(), TableNav.Hand.BACK, "in hand, back up")
	eq(TableNav.leave(flow.hand(), flow.has_band(), view.band_on, view.any_torn(), false), TableNav.Action.RETURN_THEN_GO,
		"untouched: it can go back to the tray")
	flow.primary()
	check(not view.band_on, "space breaks the band")
	check(not view.sims[0].torn and not view.sims[0].auto, "and does not start the tear in the same press")
	eq(TableNav.leave(flow.hand(), flow.has_band(), view.band_on, view.any_torn(), false), TableNav.Action.STAY,
		"band broken: it stays in hand")
	view.sims.clear()
	_free_rig(rig)


func test_jar_opens_with_a_sideways_swipe() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var spur := pack.form("spur")
	check(spur.layout.flaps[0].get("side_pull", false), "Lucky Spur's flap allows sideways swipes")
	check(not pack.form("catch").layout.flaps[0].get("side_pull", false), "Big Catch's does not")
	var fr := FlapLayout.build(spur.layout)
	var s := FlapSim.new(fr[0].w, fr[0].h)
	# Reading the drag: along the hinge (flap y) is a swipe, toward the hinge (-x) a pull.
	eq(FlapSim.drag_mode(Vector2(-0.01, 0.02), true), "", "undecided at first")
	eq(FlapSim.drag_mode(Vector2(-0.02, 0.2), true), "side", "swipe")
	eq(FlapSim.drag_mode(Vector2(-0.2, 0.05), true), "up", "pull up")
	eq(FlapSim.drag_mode(Vector2(0.0, 0.2), false), "up", "flaps without side_pull always pull")
	# Swiping toward card right (+y) tears from the bottom-left corner (-y), and back.
	s.grab(0.3)
	check(not s.side_pull_to(0.15), "0.15 swipe: still holding")
	_near(s.y_grab, -s.h / 2.0, "swipe right: bottom-left corner")
	_near(s.target, s.w - 0.05, "held near closed before the break")
	check(s.side_pull_to(0.25), "0.25 swipe: breaks")
	_near(s.target, s.w - 0.125, "opens half the swipe distance")
	eq(s.k_target, 0.0, "no tilt from a swipe")
	s.f = s.w * 0.6
	check(s.fold_at(-s.h / 2.0) < s.fold_at(s.h / 2.0), "more open at the grabbed corner")
	var t := FlapSim.new(fr[0].w, fr[0].h)
	t.side_pull_to(-0.2)
	_near(t.y_grab, t.h / 2.0, "swipe left: bottom-right corner")
	# The tear finishes the usual way.
	t.side_pull_to(-1.4)
	t.f = t.target
	t.release()
	check(t.auto, "a long swipe finishes by itself on release")


func test_single_has_no_band() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var view := TicketView.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	view.form = pack.form("catch")
	view.reset()
	check(not view.band_on, "single tickets have no band")
	check(not view.drag_band(Vector2(1.0, 0), "slide"), "nothing to drag")
	view.queue_free()
