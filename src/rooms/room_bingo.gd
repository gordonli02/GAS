class_name RoomBingo
extends RefCounted
## The Bingo Hall (web build: buildBingo). Laminate folding table, long tables and
## chairs, the number board, strip lights, a bingo sheet, the false-teeth glass, the
## BAIL piggy bank, a foam coffee cup, a tip jar of candy and a radio.


static func build(k: RoomKit, g: Node3D) -> void:
	var chrome := k.chrome()
	var grey := k.M(0x777777)
	var top := k.phong_tex("bingo_laminate", Vector2(1.8, 1), 22, 0x302c24)
	RoomKit.no_cast(k.box(g, 15, .3, 12.5, top, 0, -.3, 0))
	k.box(g, 15.1, .34, .1, chrome, 0, -.34, 6.3)
	k.box(g, 15.1, .34, .1, chrome, 0, -.34, -6.3)
	k.box(g, .1, .34, 12.6, chrome, 7.55, -.34, 0)
	k.box(g, .1, .34, 12.6, chrome, -7.55, -.34, 0)
	for l in [[-7, -5.8], [7, -5.8], [-7, 5.8], [7, 5.8]]:
		k.box(g, .25, 7.7, .25, grey, l[0], -8, l[1])
	RoomProps.shell(k, g, k.M(0x6a6d62), k.M(0xa3a892), -22)
	k.box(g, 92, 6, .2, k.M(0x7c6a4e), 0, -8, -21.8)
	for x in [-14, 0]:
		k.box(g, 11, .25, 4.2, k.M(0xbdaa84), x, -2.6, -13.8)
		for l in [[-5, -1.8], [5, -1.8], [-5, 1.8], [5, 1.8]]:
			k.box(g, .2, 5.4, .2, grey, x + l[0], -8, -13.8 + l[1])
	for x in [-12, -8, -4, 3]:
		k.box(g, 1.6, .2, 1.6, k.M(0x3f4c59), x, -4.4, -11.2)
		k.box(g, 1.6, 2.3, .2, k.M(0x3f4c59), x, -4.3, -10.5)
		for l in [[-.7, -.7], [.7, -.7], [-.7, .7], [.7, .7]]:
			k.box(g, .12, 3.6, .12, grey, x + l[0], -8, -11.2 + l[1])
	k.panel(g, 18, 6.75, k.TB("bingo_board"), 0, 4.7, -21.6)
	for x in [-14, 0, 14]:
		for z in [-16, -6, 3]:
			RoomKit.no_cast(k.box(g, .9, .1, 8, k.B(0xf4fff4), x, 10, z))
	# Bingo sheet.
	k.flat(g, 3, 4, k.phong_tex("bingo_sheet"), -2.3, .02, -2.4, .18)
	RoomProps.denture_glass(k, g, 3.7, -2.2)
	RoomProps.bail_pig(k, g, -5.2, -3.3, .3)
	# Foam cup of coffee.
	k.lathe(g, [[0, 0], [.42, 0], [.6, 1.4], [.65, 1.45], [.55, 1.45], [.4, .15], [0, .15]], 9, k.M(0xf5f4ec), -6.1, 0, -.8)
	k.cyl(g, .56, .56, .03, 9, k.M(0x3c2413, {"s": 50}), -6.1, 1.26, -.8)
	# Tip jar of candy.
	k.lathe(g, [[0, 0], [.95, 0], [1, 1.9], [.8, 2.1], [.8, 2.25], [.72, 2.25], [.72, 2.12], [.9, 1.9], [.85, .1], [0, .1]], 9,
		k.M(0xcfe6ea, {"s": 80, "sp": 0xffffff, "a": .5}), .3, 0, -4)
	var r := SeededRng.new("jar")
	var candy := [0xd13b3b, 0xe7b32b, 0x3a9c5d, 0xf4ece0]
	for i in 34:
		var a := r.next_float() * 6.3
		var d := r.next_float() * .68
		var cx := .3 + cos(a) * d
		var cy := .12 + r.next_float() * 1.05
		var cz := -4 + sin(a) * d
		var m := k.box(g, .3, .1, .18, k.M(candy[i % 4]), cx, cy, cz, r.next_float() * 3)
		m.rotation.z = r.next_float()
	# Radio.
	k.box(g, 1.9, .75, 1.3, k.M(0x4f6a72, {"s": 30, "sp": 0x777777}), 5.4, 0, -3.2, .2)
	k.box(g, .5, .08, .2, chrome, 5.55, .45, -2.52, .2)
