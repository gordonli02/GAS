class_name RoomProps
extends RefCounted
## Props shared by the rooms, ported from the web build (breakfast, flipPhone,
## dentureGlass, bailPig, bottle, mug, room). Numbers are the web build's.


## The room shell: floor, back wall and the two side walls.
static func shell(k: RoomKit, g: Node3D, floor_mat: Material, wall_mat: Material, back_z: float) -> void:
	k.flat(g, 90, 90, floor_mat, 0, -8, -10)
	k.panel(g, 90, 36, wall_mat, 0, 10, back_z)
	k.panel(g, 60, 36, wall_mat, 23, 10, -2, -PI / 2)
	k.panel(g, 60, 36, wall_mat, -23, 10, -2, PI / 2)


## Fried eggs, bacon, toast and hash browns on an oval plate, with a knife and fork.
static func breakfast(k: RoomKit, p: Node3D, x: float, z: float) -> void:
	var g := k.group(p, x, 0, z, -0.2)
	k.lathe(g, [[0, 0], [1.35, 0], [1.85, .14], [1.82, .2], [1.3, .09], [0, .08]], 12,
		k.M(0xf3efe2, {"s": 40, "sp": 0x444444}), 0, 0, 0).scale.z = .84
	for e in [[-.66, .12], [.02, .5]]:
		k.cyl(g, .5, .55, .05, 7, k.M(0xfffdf2, {"s": 50, "sp": 0x555555}), e[0], .09, e[1])
		var yolk := k.put(g, RoomKit.ico_geo(.2, 1), k.M(0xf7a80f, {"s": 60, "sp": 0x777777}), e[0] + .03, .17, e[1])
		yolk.scale.y = .62
	for b in 3:
		for i in 6:
			k.box(g, .24, .05, .15, k.M(0x8c2a1a if i % 2 else 0xd9896c), -.82 + i * .21, .11 + (i % 2) * .035, -.82 + b * .19, .08)
	k.box(g, .95, .13, .62, k.M(0xc98a2d), .75, .09, .42, .25)
	for i in 5:
		k.box(g, .8, .02, .05, k.M(0xe2ae50), .75 + i * .012, .22, .2 + i * .11, .25)
	for t in [[.9, -.42, .3], [.6, -.58, 2.2]]:
		k.put(g, RoomKit.cylinder_geo(.56, .56, .1, 3), k.M(0xd8a24e), t[0], .15, t[1], t[2])
		k.cyl(g, .46, .46, .02, 3, k.M(0xf1cf85), t[0], .2, t[1]).rotation.y = t[2]
	k.box(g, .22, .09, .16, k.M(0xffe98a), .9, .22, -.42, .5)
	k.box(g, .09, .04, 2.5, k.chrome(), -2.3, 0, 0, .08)
	k.box(g, .3, .04, .42, k.chrome(), -2.34, 0, -1.1, .08)


## A flip phone, open, on a betting app: TONYMARKET.
static func flip_phone(k: RoomKit, p: Node3D, x: float, z: float, ry: float) -> void:
	var g := k.group(p, x, 0, z, ry)
	g.scale = Vector3.ONE * 1.55
	var shell_mat := k.M(0x2b2e38, {"s": 60, "sp": 0x777788})
	k.box(g, 1, .13, 1.55, shell_mat, 0, 0, 0)
	k.flat(g, .88, 1.42, k.phong_tex("phone_keys"), 0, .135, 0)
	var hinge := k.cyl(g, .08, .08, 1, 6, shell_mat, 0, .08, -.78)
	hinge.rotation.z = PI / 2
	hinge.position.y = .17
	var lid := k.group(g, 0, .17, -.8)
	lid.rotation.x = -.2
	k.box(lid, 1, 1.72, .1, shell_mat, 0, 0, 0)
	k.panel(lid, .88, 1.5, k.TB("phone_screen"), 0, .86, .056)
	k.cyl(lid, .03, .04, .5, 5, shell_mat, .38, 1.72, -.02)


## False teeth soaking in a glass of water.
static func denture_glass(k: RoomKit, p: Node3D, x: float, z: float) -> void:
	RoomKit.no_cast(k.lathe(p, [[0, 0], [.82, 0], [.92, 2], [.86, 2], [.76, .1], [0, .1]], 9,
		k.M(0xdcecf0, {"s": 90, "sp": 0xffffff, "a": .3}), x, 0, z))
	var g := k.group(p, x, .72, z)
	for row in [[.28, .12], [-.2, -.1]]:
		var y: float = row[0]
		var gum := k.put(g, RoomKit.torus_geo(.42, .13, 5, 10, PI), k.M(0xef7f95, {"s": 40, "sp": 0x884455}), 0, y, .02, 0, false)
		gum.rotation = Vector3(PI / 2 + row[1], 0, PI)
		for i in 8:
			var a := .18 + i * .39
			RoomKit.no_cast(k.box(g, .15, .2, .09, k.M(0xfdf9e8, {"s": 60, "sp": 0x666666}),
				cos(a) * .44, y - (.2 if y > 0 else -.02), .04 + sin(a) * .44, -a + PI / 2))
	RoomKit.no_cast(k.cyl(p, .76, .72, 1.45, 9, k.M(0x9fd4e6, {"s": 60, "sp": 0xffffff, "a": .16}), x, .1, z))


## A pink piggy bank tagged BAIL.
static func bail_pig(k: RoomKit, p: Node3D, x: float, z: float, ry: float) -> void:
	var g := k.group(p, x, 0, z, ry)
	var pink := k.M(0xf49ab2, {"s": 60, "sp": 0x996677})
	k.put(g, RoomKit.ico_geo(.9, 1), pink, 0, 1.02, 0).scale = Vector3(1.25, .92, .92)
	for l in [[-.62, -.42], [.62, -.42], [-.62, .42], [.62, .42]]:
		k.cyl(g, .15, .17, .42, 6, pink, l[0], 0, l[1])
	var snout := k.cyl(g, .27, .33, .3, 7, pink, 1.2, 1.05, 0)
	snout.rotation.z = PI / 2
	snout.position = Vector3(1.22, 1.05, 0)
	for z2 in [-.09, .09]:
		k.box(g, .02, .13, .07, k.M(0x8c3f55), 1.38, .99, z2)
	for z2 in [-.42, .42]:
		var ear := k.put(g, RoomKit.cone_geo(.17, .3, 4), pink, .72, 1.82, z2)
		ear.rotation.x = z2 * .5
		k.box(g, .1, .1, .1, k.M(0x1c1518), 1.02, 1.3, z2 * .82)
	k.box(g, .55, .04, .1, k.M(0x2a2024), 0, 1.84, 0)
	k.panel(g, 1.15, .53, k.TB("pig_tag"), -.05, 1, .88)


static func bottle(k: RoomKit, p: Node3D, mat: Material, x: float, z: float, s := 1.0, y := 0.0) -> MeshInstance3D:
	var profile := [[0, 0], [.3 * s, 0], [.32 * s, 1.4 * s], [.28 * s, 1.75 * s], [.11 * s, 2.2 * s],
		[.1 * s, 2.75 * s], [.13 * s, 2.8 * s], [0, 2.82 * s]]
	return k.lathe(p, profile, 7, mat, x, y, z)


## A diner mug of coffee on its saucer.
static func mug(k: RoomKit, p: Node3D, x: float, z: float) -> void:
	k.lathe(p, [[0, 0], [.95, 0], [1, .06], [.72, .14], [.66, .1], [0, .1]], 9, k.M(0xe9e5d8, {"s": 30}), x, 0, z)
	k.lathe(p, [[0, .14], [.48, .14], [.56, .2], [.6, 1.2], [.5, 1.2], [.46, .3], [0, .3]], 9,
		k.M(0xefeadc, {"s": 40, "sp": 0x444444}), x, 0, z)
	k.cyl(p, .5, .5, .03, 9, k.M(0x2c170d, {"s": 50, "sp": 0x666666}), x, 1.08, z)
	k.put(p, RoomKit.torus_geo(.24, .07, 4, 8), k.M(0xefeadc), x + .7, .72, z)
