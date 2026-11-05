class_name RoomDiner
extends RefCounted
## The Diner (web build: buildDiner). Formica table, checkered floor, red vinyl booth,
## counter and stools, dusk windows, EAT neon, hanging lamp, napkins and condiments,
## tabletop jukebox selector, coffee, pie and the breakfast plate.
## Layout changes from the web build are G's (M5 review) and marked where they are.


const BREAKFAST := Vector2(1.3, 1.8)   ## plate centre (x, z); knife and fork lie to its left
const PIE := Vector2(-5.85, -4.2)


static func build(k: RoomKit, g: Node3D) -> void:
	var chrome := k.chrome()
	var top := k.phong_tex("diner_formica", Vector2(3, 1.6), 50, 0x3a3a3a)
	RoomKit.no_cast(k.box(g, 15, .4, 12.5, top, 0, -.4, 0))
	k.box(g, 15.2, .46, .1, chrome, 0, -.46, 6.3)
	k.box(g, 15.2, .46, .1, chrome, 0, -.46, -6.3)
	k.box(g, .1, .46, 12.7, chrome, 7.6, -.46, 0)
	k.box(g, .1, .46, 12.7, chrome, -7.6, -.46, 0)
	k.cyl(g, .45, .45, 7.6, 8, chrome, 0, -8, 0)
	RoomProps.shell(k, g, k.phong_tex("diner_tiles", Vector2(30, 30), 30, 0x333333), k.M(0x9fc6b3), -18)
	k.box(g, 92, 3.2, .2, k.M(0xb72a33), 0, -8, -17.8)
	k.box(g, 92, .25, .3, chrome, 0, -4.8, -17.8)
	k.box(g, .2, 3.2, 60, k.M(0xb72a33), 22.8, -8, -2)
	for x in [-11, 0, 11]:
		k.panel(g, 9, 5.4, k.TB("diner_dusk"), x, 1.8, -17.75)
		k.box(g, 9.3, .2, .25, chrome, x, -1.1, -17.7)
		k.box(g, 9.3, .2, .25, chrome, x, 4.5, -17.7)
		k.box(g, .2, 5.8, .25, chrome, x - 4.6, -1.1, -17.7)
		k.box(g, .2, 5.8, .25, chrome, x + 4.6, -1.1, -17.7)
	k.panel(g, 4, 1.5, k.TB("diner_neon"), 0, 5.7, -17.6)
	var vinyl := k.M(0xb72a33, {"s": 26, "sp": 0x663333})
	for i in range(-4, 5):
		k.box(g, 1.62, 11.4, .9, vinyl, i * 1.68, -8, -7.5)
	k.box(g, 15.6, .16, 1.05, chrome, 0, 3.4, -7.5)
	k.box(g, .16, 11.4, 1.05, chrome, 7.8, -8, -7.5)
	k.box(g, .16, 11.4, 1.05, chrome, -7.8, -8, -7.5)
	k.box(g, 18, 6.6, 2.4, k.M(0xdcd5c3, {"s": 30}), -11, -8, -14.6)
	k.box(g, 18.4, .25, 2.8, chrome, -11, -1.4, -14.6)
	for x in [-17, -13, -9, -5]:
		k.cyl(g, .16, .16, 4, 6, chrome, x, -8, -12.4)
		k.cyl(g, .8, .8, .34, 9, k.M(0xb72a33, {"s": 30}), x, -4, -12.4)
	# Hanging lamp.
	RoomKit.no_cast(k.cyl(g, .05, .05, 3, 5, k.M(0x222228), -1.8, 8, 1))
	RoomKit.no_cast(k.lathe(g, [[.05, 2], [.6, 1.3], [1.15, .6], [1.2, .6]], 8, k.M(0xbd3b36, {"s": 30}), -1.8, 6.55, 1))
	RoomKit.no_cast(k.cyl(g, .42, .42, .3, 8, k.B(0xfff1be), -1.8, 6.85, 1))
	# Napkin dispenser.
	k.box(g, 1.5, 1.6, 1, chrome, -4.6, 0, -2.6, .25)
	k.box(g, 1, .8, .05, k.M(0xf7f3e6), -4.48, .45, -2.09, .25)
	k.box(g, .72, .06, .08, k.M(0x2d2d33), -4.48, .5, -2.03, .25)
	# Ketchup, mustard, salt, pepper.
	var squeeze := [[0, 0], [.3, 0], [.34, 1.2], [.28, 1.5], [.08, 1.85], [.03, 2.25], [0, 2.25]]
	k.lathe(g, squeeze, 7, k.M(0xc8201f, {"s": 40, "sp": 0x884444}), -2.75, 0, -3.2)
	k.lathe(g, squeeze, 7, k.M(0xe6b616, {"s": 40, "sp": 0x887744}), -2.05, 0, -3.45)
	for s in [[-.9, 0xece8df], [-.35, 0x45403c]]:
		k.cyl(g, .2, .27, .75, 7, k.M(0xcfe0e0, {"s": 60, "sp": 0xffffff, "a": .75}), s[0], 0, -3.3)
		k.cyl(g, .21, .2, .14, 7, k.M(s[1]), s[0], .42, -3.3)
		k.lathe(g, [[.21, 0], [.2, .2], [.1, .32], [0, .34]], 7, chrome, s[0], .75, -3.3)
	# Tabletop jukebox selector. G moved it in from the back edge, where it hung over (M5).
	var jx := 4.2
	var jz := -4.3
	k.box(g, 2.5, 2.2, 1.5, chrome, jx, 0, jz, -.22)
	k.panel(g, 2.2, 1.9, k.TB("diner_juke"), jx - .15, 1.14, jz + .78, -.22)
	var cap := k.cyl(g, .75, .75, 2.5, 8, chrome, jx, 1.0, jz)
	cap.rotation = Vector3(0, -.22, PI / 2)
	cap.position = Vector3(jx, 2.2, jz)
	# Coffee and pie.
	RoomProps.mug(k, g, -5.7, -.7)
	# The pie plate hung half a unit over the left edge in the web build (-6.7, -3.5);
	# moved in with the jukebox (M5), clear of the napkin dispenser.
	k.lathe(g, [[0, 0], [1.2, 0], [1.32, .08], [1.3, .14], [1.05, .1], [0, .08]], 10, k.M(0xeee8d9, {"s": 30}), PIE.x, 0, PIE.y)
	k.put(g, RoomKit.cylinder_geo(.92, .92, .42, 4, 0, .9), k.M(0xd19a4c), PIE.x - .15, .3, PIE.y - .15, 2.7)
	# The breakfast sits in front of the player (G, M5; the web build had it at 4, -2.2).
	RoomProps.breakfast(k, g, BREAKFAST.x, BREAKFAST.y)
