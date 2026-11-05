extends "res://tests/test_case.gd"
## Leaving the table with a ticket in hand, and how the discard pile grows.

const N := TableNav.Hand
const A := TableNav.Action


func test_leaving_the_table() -> void:
	# Empty hands: go.
	eq(TableNav.leave(N.NONE, false, false, false, false), A.GO, "empty tray / no ticket: go")
	# An opened ticket: clicking the machine discards it first; B does nothing (web build).
	eq(TableNav.leave(N.OPENED, false, false, false, true), A.DISCARD_THEN_GO, "opened + click machine")
	eq(TableNav.leave(N.OPENED, false, false, false, false), A.STAY, "opened + B")
	# Untouched tickets go back to the tray.
	eq(TableNav.leave(N.FRONT, false, false, false, false), A.RETURN_THEN_GO, "front up")
	eq(TableNav.leave(N.BACK, false, false, false, true), A.RETURN_THEN_GO, "flipped, not torn")
	eq(TableNav.leave(N.FRONT, true, true, false, false), A.RETURN_THEN_GO, "jar with its band on")
	# Partly torn, or a jar whose band is broken, blocks leaving.
	eq(TableNav.leave(N.BACK, false, false, true, true), A.STAY, "partly torn")
	eq(TableNav.leave(N.FRONT, true, false, false, true), A.STAY, "jar, band broken")
	eq(TableNav.leave(N.BACK, true, false, false, true), A.STAY, "jar flipped (band gone)")
	eq(TableNav.leave(N.MOVING, false, false, false, true), A.STAY, "mid deal / flip / toss")


func test_pile_growth_rules() -> void:
	for n in 13:
		eq(PileModel.shown(n), n, "%d tickets: one card each" % n)
	var prev := 0
	for n in range(0, 5001):
		var s := PileModel.shown(n)
		if s < prev:
			check(false, "pile shrank at %d (%d -> %d)" % [n, prev, s])
			return
		check(s <= PileModel.MAX_CARDS, "within the card budget at %d" % n)
		prev = s
	eq(PileModel.shown(4000), 181, "4000 tickets")
	# Within a range the toppers still show each new toss, up to 5.
	eq(PileModel.shown(50), 31, "range start: heap 30 + 1")
	eq(PileModel.shown(54), 35, "heap 30 + 5")
	eq(PileModel.shown(60), 35, "toppers full")


func test_pile_spots_stable_and_rising() -> void:
	var a := PileModel.new()
	var b := PileModel.new()
	eq(a.spots.size(), PileModel.MAX_CARDS, "a spot for every card")
	for i in a.spots.size():
		if a.spots[i].pos != b.spots[i].pos:
			check(false, "spot %d differs between builds" % i)
			return
	var top_small := 0.0
	var top_big := 0.0
	for i in a.spots.size():
		check(a.spots[i].pos.y >= PileModel.THICK / 2.0 - 1e-4, "card %d rests on or above the table" % i)
		if i < PileModel.shown(199):
			top_small = maxf(top_small, a.spots[i].pos.y)
		top_big = maxf(top_big, a.spots[i].pos.y)
	check(top_big > top_small * 1.5, "the pile rises as it grows (%.2f -> %.2f)" % [top_small, top_big])
	eq(a.landing_spot(0), a.spots[0].pos, "first ticket lands on the first spot")
	eq(a.landing_spot(53), a.spots[PileModel.shown(54) - 1].pos, "a toss lands where it will stay")
