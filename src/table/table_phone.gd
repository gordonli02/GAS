class_name TablePhone
extends Node3D
## The player's phone lying on the table, its screen cracked: clicking it opens the
## phone (Phone). Built in code, the screen's picture drawn into an image here.

const SIZE := Vector3(0.78, 0.07, 1.5)
const SCREEN := Vector2(0.68, 1.34)
const TEX := Vector2i(136, 268)


func _ready() -> void:
	var body := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = SIZE
	body.mesh = b
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color("#1b1b20")
	shell.roughness = 0.45
	body.material_override = shell
	body.position.y = SIZE.y / 2.0
	add_child(body)
	var glass := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = SCREEN
	glass.mesh = q
	glass.rotation = Vector3(-PI / 2, 0, 0)
	glass.position.y = SIZE.y + 0.002
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(_screen())
	m.roughness = 0.15
	m.metallic_specular = 0.8
	m.disable_receive_shadows = true
	glass.material_override = m
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)
	var hit := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE + Vector3(0.1, 0.1, 0.1)
	shape.shape = box
	hit.add_child(shape)
	hit.position.y = SIZE.y / 2.0
	hit.set_meta("phone", true)
	add_child(hit)


## A dark screen with a faint glow, three app squares and the crack.
static func _screen() -> Image:
	var img := Image.create(TEX.x, TEX.y, false, Image.FORMAT_RGBA8)
	for y in TEX.y:
		var t := float(y) / TEX.y
		img.fill_rect(Rect2i(0, y, TEX.x, 1), Color("#16252c").lerp(Color("#0b1216"), t))
	var apps := [Color("#e7a83a"), Color("#47c46b"), Color("#3d8fe8")]
	for k in 3:
		img.fill_rect(Rect2i(14 + k * 40, 120, 28, 28), apps[k].darkened(0.25))
	img.fill_rect(Rect2i(30, 50, 76, 10), Color("#c9d6dc").darkened(0.35))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	var o := Vector2(TEX.x * 0.78, TEX.y * 0.12)
	for k in 9:
		var a := TAU * k / 9.0 + rng.randf_range(-0.2, 0.2)
		var p := o
		for s in 6:
			var q := p + Vector2.from_angle(a + rng.randf_range(-0.35, 0.35)) * rng.randf_range(10.0, 34.0)
			_line(img, p, q, Color(1, 1, 1, 0.6))
			p = q
	return img


static func _line(img: Image, a: Vector2, b: Vector2, c: Color) -> void:
	var n := int(maxf(1.0, a.distance_to(b)))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		var x := int(p.x)
		var y := int(p.y)
		if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(c, 1.0), c.a))
