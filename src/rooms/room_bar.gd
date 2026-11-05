class_name RoomBar
extends RefCounted
## The Bar (web build: buildBar). Wood table, plank floor, back bar with mirror,
## shelves of bottles and COLD BEER neon, counter with stools and a beer tap, a beer
## bottle with its label, a pint on a coaster, an ashtray, peanuts and the flip phone.


const PINT := Vector2(-4.4, -3.2)    ## (x, z)
const PHONE := Vector2(3.6, -1.7)


static func build(k: RoomKit, g: Node3D) -> void:
	var chrome := k.chrome()
	var top := k.phong_tex("bar_wood", Vector2(2.4, 1.4), 60, 0x4a3528)
	RoomKit.no_cast(k.box(g, 15, .5, 12.5, top, 0, -.5, 0))
	var rim := k.M(0x2c1209, {"s": 30})
	k.box(g, 15.2, .28, .3, rim, 0, -.3, 6.3)
	k.box(g, 15.2, .28, .3, rim, 0, -.3, -6.3)
	k.box(g, .3, .28, 12.7, rim, 7.6, -.3, 0)
	k.box(g, .3, .28, 12.7, rim, -7.6, -.3, 0)
	k.cyl(g, .5, .5, 7.5, 8, k.M(0x241108), 0, -8, 0)
	k.cyl(g, 2, 2, .3, 8, k.M(0x241108), 0, -8, 0)
	RoomProps.shell(k, g, k.phong_tex("bar_planks", Vector2(10, 10), 14), k.M(0x2a1a1d), -18.5)
	var back := k.group(g, 0, 0, -9.3)
	k.box(back, 34, 15, 1.8, k.M(0x241108), 0, -8, -8.9)
	k.panel(back, 30, 5, k.M(0x3a3a48, {"s": 90, "sp": 0x9999aa}), 0, 4.3, -7.95)
	for y in [2, 4.15]:
		k.box(back, 30, .14, 1, k.M(0x45200f), 0, y, -7.4)
	k.box(g, 24, 6.8, 2.4, k.M(0x3b1d10), -6, -8, -12.6)
	k.box(g, 24.6, .3, 3, k.M(0x5a2a17, {"s": 50, "sp": 0x554433}), -6, -1.2, -12.6)
	for x in [-13, -9, -5, -1, 3]:
		k.cyl(g, .16, .16, 4.4, 6, chrome, x, -8, -10.4)
		k.cyl(g, .8, .8, .34, 9, k.M(0x7c1f2d, {"s": 30}), x, -3.6, -10.4)
	var cols := [0x2c6e3f, 0x8f3b1c, 0xc1902c, 0x1f3f77, 0x7c1f2d, 0xcfc7a8, 0x3b5d2a, 0xa55a1f]
	for y in 2:
		for i in 26:
			RoomProps.bottle(k, back, k.M(cols[(i * 3 + y) % 8], {"s": 60, "sp": 0x666666}),
				-13 + i * 1.05 + y * .4, -7.35, .56 + ((i * 7) % 5) * .035, 4.29 if y else 2.14)
	k.panel(back, 3.8, 1.45, k.TB("bar_neon"), -4.3, 5.2, -7.7)
	# Beer tap.
	var tap := k.group(g, -4, -.9, -12.6)
	k.box(tap, 5.6, .6, .8, chrome, 0, 2.2, 0)
	k.cyl(tap, .25, .3, 2.3, 7, chrome, 0, 0, 0)
	for i in 3:
		k.cyl(tap, .09, .11, .9, 5, k.M([0xc1902c, 0x8f1f27, 0x1f5f88][i]), -1.5 + i * 1.5, 2.8, .1)
		k.cyl(tap, .05, .05, .5, 5, chrome, -1.5 + i * 1.5, 1.74, .2)
	# Table clutter.
	RoomProps.bottle(k, g, k.M(0x51300f, {"s": 70, "sp": 0x887766}), -6.3, -1.5, .82)
	RoomKit.no_cast(k.box(g, .48, .42, .03, k.M(0xe9dcb4), -6.3, .75, -1.22))
	# Pint on its coaster. G had it and the phone moved apart, clear of the ticket tray
	# (M5; the web build had the pint at 3.2, -2.3 and the phone at 3.9, -.8).
	k.flat(g, 1.5, 1.5, k.M(0xcfc4a6), PINT.x, .015, PINT.y, .4)
	k.lathe(g, [[0, 0], [.43, 0], [.56, 1.6], [.5, 1.6], [.4, .14], [0, .14]], 8,
		k.M(0xcfa24c, {"s": 70, "sp": 0xffffff, "a": .86}), PINT.x, .02, PINT.y)
	k.cyl(g, .53, .47, .2, 8, k.M(0xf5ecd7), PINT.x, 1.42, PINT.y)
	# Ashtray with two butts.
	k.lathe(g, [[0, 0], [1, 0], [1.05, .28], [.92, .3], [.84, .12], [0, .12]], 9, k.M(0x24242c, {"s": 60, "sp": 0x666677}), -3.6, 0, -.1)
	_butt(k, g, .2, .1, -3.9, -.1)
	_butt(k, g, -.3, 1.8, -3.4, .1)
	# Peanuts.
	k.lathe(g, [[0, 0], [.5, 0], [.95, .42], [.9, .45], [.45, .1], [0, .1]], 8, k.M(0x7c5230, {"s": 30}), 1.4, 0, -3.2)
	var r := SeededRng.new("nuts")
	for i in 22:
		var a := r.next_float() * 6.3
		var d := r.next_float() * .7
		var nx := 1.4 + cos(a) * d
		var ny := .26 + r.next_float() * .15
		k.put(g, RoomKit.ico_geo(.13, 0), k.M(0xc6965a), nx, ny, -3.2 + sin(a) * d)
	RoomProps.flip_phone(k, g, PHONE.x, PHONE.y, -.3)


static func _butt(k: RoomKit, g: Node3D, rx: float, ry: float, x: float, z: float) -> void:
	var m := k.cyl(g, .06, .06, 1, 5, k.M(0xf0ebdd), x, .2, z)
	m.rotation = Vector3(rx, ry, 1.2)
	var f := k.cyl(g, .062, .062, .35, 5, k.M(0xd28a3b), x, .2, z)
	f.rotation = Vector3(rx, ry, 1.2)
	f.position.x += .42
	f.position.y += .19
