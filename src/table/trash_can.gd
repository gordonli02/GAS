class_name TrashCan
extends Node3D
## A small wastebasket on the table: clicking it throws unopened tickets away (the
## one in hand, or the whole tray), after a card asks first. Built in code.

const HEIGHT := 0.8
const TOP_R := 0.4
const BOTTOM_R := 0.31


func _ready() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("#5d6a66")
	metal.roughness = 0.55
	metal.metallic = 0.3
	var bin := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = TOP_R
	c.bottom_radius = BOTTOM_R
	c.height = HEIGHT
	c.radial_segments = 10
	c.cap_top = false
	bin.mesh = c
	bin.material_override = metal
	bin.position.y = HEIGHT / 2.0
	add_child(bin)
	var inside := MeshInstance3D.new()
	var d := CylinderMesh.new()
	d.top_radius = TOP_R - 0.03
	d.bottom_radius = BOTTOM_R - 0.03
	d.height = HEIGHT - 0.04
	d.radial_segments = 10
	d.flip_faces = true
	inside.mesh = d
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("#262b2a")
	inside.material_override = dark
	inside.position.y = HEIGHT / 2.0 + 0.02
	add_child(inside)
	var rim := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = TOP_R - 0.03
	t.outer_radius = TOP_R + 0.03
	t.rings = 10
	t.ring_segments = 6
	rim.mesh = t
	rim.material_override = metal
	rim.position.y = HEIGHT
	add_child(rim)
	# A crumpled losing ticket peeking over the rim, so it reads as a bin for tickets.
	var paper := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.17
	ball.height = 0.3
	ball.radial_segments = 7
	ball.rings = 4
	paper.mesh = ball
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color("#e9e2cf")
	paper.material_override = pm
	paper.position = Vector3(0.08, HEIGHT - 0.04, -0.05)
	paper.rotation = Vector3(0.4, 0.7, 0.2)
	add_child(paper)
	var hit := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = TOP_R + 0.05
	cyl.height = HEIGHT + 0.1
	shape.shape = cyl
	hit.add_child(shape)
	hit.position.y = HEIGHT / 2.0
	hit.set_meta("trash", true)
	add_child(hit)


## Where a ticket thrown in falls to.
func mouth() -> Vector3:
	return global_position + Vector3(0, HEIGHT * 0.8, 0)
