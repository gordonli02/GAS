class_name ItemTray
extends Node3D
## The run's items held, lying on the table in a little tray of the room's own (M9.7,
## G: built from shapes like the room props): a dented tin serving tray at the diner,
## a cigar box with its lid up at the bar, a plastic organiser with a dauber at the
## bingo hall. Each item held lies in it as a token, a shape for its kind (INFO a card,
## ECONOMY a coin, ACTION a block, SURE a gem) in its rarity's colour (the phone's: cream,
## blue, gold); past MAX_TOKENS the rest are implied. Clicking it opens the item picker
## (ItemPicker). Free play has no items: the tray is put away there (show_tray).

const MAX_TOKENS := 8
## Per room: where the tokens rest (floor height, then the spots' columns and rows in
## x and z).
const ROOMS := {
	"diner": {"floor": .045, "xs": [-.42, -.14, .14, .42], "zs": [-.17, .17]},
	"bar": {"floor": .105, "xs": [-.42, -.14, .14, .42], "zs": [-.16, .16]},
	"bingo": {"floor": .05, "xs": [-.05, .12, .29, .46], "zs": [-.2, .2]},
}
const TOKEN_TOP := .15     ## the tallest token stands this high above the floor
const RARITY := {"common": 0xe9e2cf, "rare": 0x3d8fe8, "legendary": 0xe7a83a}

var room := ""
var kit := RoomKit.new()
var _model := Node3D.new()
var _tokens := Node3D.new()
var _hit := StaticBody3D.new()
var _box := BoxShape3D.new()
var _shown := ""
var _shown_tokens: Array = []


func _init() -> void:
	kit.colliders = false   # one click box for the whole tray, below
	add_child(_model)
	add_child(_tokens)
	var shape := CollisionShape3D.new()
	shape.shape = _box
	_hit.add_child(shape)
	_hit.set_meta("items", true)
	add_child(_hit)
	set_room("diner")
	show_tray(false)


## Builds the tray of a room (the tokens are laid again in it).
func set_room(room_id: String) -> void:
	if room_id == room or not ROOMS.has(room_id):
		return
	room = room_id
	for c in _model.get_children():
		c.free()
	match room_id:
		"diner": _tin_tray(kit, _model)
		"bar": _cigar_box(kit, _model)
		"bingo": _organiser(kit, _model)
	# The click box: the tray's own shape (the bar's lid included), the tokens' height
	# above its floor, a little margin.
	var b := bounds(_model)
	b = b.merge(AABB(Vector3(b.position.x, 0, b.position.z), Vector3(b.size.x, float(ROOMS[room_id].floor) + TOKEN_TOP, b.size.z)))
	b = b.grow(.05)
	_box.size = b.size
	_hit.position = b.get_center()
	var tokens := _shown_tokens
	_shown = ""
	show_items(tokens)


## The run shows it; free play puts it away (hidden, and no longer catching clicks).
func show_tray(on: bool) -> void:
	visible = on
	_hit.collision_layer = 1 if on else 0


## tokens: one {kind, rarity} for each item held. Laid again only when they change.
func show_items(tokens: Array) -> void:
	var key := room + var_to_str(tokens.slice(0, MAX_TOKENS))
	if key == _shown:
		return
	_shown = key
	_shown_tokens = tokens
	for c in _tokens.get_children():
		c.free()
	var r: Dictionary = ROOMS[room]
	var xs: Array = r.xs
	var zs: Array = r.zs
	for i in mini(tokens.size(), MAX_TOKENS):
		var x: float = xs[i % xs.size()]
		var z: float = zs[(i / xs.size()) % zs.size()]
		_token(kit, _tokens, tokens[i], x, r.floor, z, fmod(i * 1.37, 1.0) - .5)


## How many tokens lie in the tray (tests).
func token_count() -> int:
	return _tokens.get_child_count()


## The box around every mesh under `n`, in this tray's space (works outside the tree).
func bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var p: Node = m
		while p != self:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b := xf * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## The click box, in this tray's space (tests).
func hit_box() -> AABB:
	return AABB(_hit.position - _box.size / 2.0, _box.size)


# --- the trays -----------------------------------------------------------------------

## The diner: a dented tin serving tray with a paper napkin in it.
static func _tin_tray(k: RoomKit, g: Node3D) -> void:
	var tin := k.M(0xaeb4b6, {"s": 70, "sp": 0xcccccc})
	k.box(g, 1.3, .04, .85, tin, 0, 0, 0)
	k.box(g, 1.3, .08, .04, tin, 0, .04, -.405)
	k.box(g, .04, .08, .85, tin, -.63, .04, 0)
	k.box(g, .04, .08, .85, tin, .63, .04, 0)
	# The front rim took a knock: bent in toward the right, a dull patch where it hit.
	k.box(g, .7, .08, .04, tin, -.29, .04, .405)
	k.box(g, .62, .07, .04, tin, .32, .04, .39, .06).rotation.z = .08
	k.flat(g, .26, .16, k.M(0x7f8789, {"s": 20}), .36, .041, .3, .4)
	k.flat(g, 1.12, .68, k.M(0xf7f3e6), 0, .043, 0, .03)


## The bar: a cigar box with the lid up, a red paper lining, the label inside the lid.
static func _cigar_box(k: RoomKit, g: Node3D) -> void:
	var wood := k.M(0x6b3519, {"s": 30, "sp": 0x443322})
	k.box(g, 1.3, .1, .85, wood, 0, 0, 0)
	k.box(g, 1.3, .16, .05, wood, 0, .1, .4)
	k.box(g, 1.3, .16, .05, wood, 0, .1, -.4)
	k.box(g, .05, .16, .75, wood, -.625, .1, 0)
	k.box(g, .05, .16, .75, wood, .625, .1, 0)
	k.flat(g, 1.2, .75, k.M(0x8f1f27), 0, .101, 0)
	var lid := k.group(g, 0, .26, -.425)
	lid.rotation.x = -1.9   # hinged at the back edge, opened a little past upright
	k.box(lid, 1.3, .04, .85, wood, 0, 0, .425)
	var label := k.put(lid, RoomKit.plane_geo(1.0, .6), k.M(0xe9dcb4), 0, -.002, .425)
	label.rotation.x = PI / 2   # facing out of the lid's inside
	var band := k.put(lid, RoomKit.plane_geo(1.0, .14), k.M(0xb72a33), 0, -.004, .425)
	band.rotation.x = PI / 2
	var seal := k.put(lid, RoomKit.cylinder_geo(.1, .1, .01, 9), k.M(0xc1902c, {"s": 60, "sp": 0x887744}), 0, -.008, .425)
	seal.rotation.x = PI / 2


## The bingo hall: a plastic organiser tray, a dauber standing and one lying in the
## left compartment, the tokens in the other two.
static func _organiser(k: RoomKit, g: Node3D) -> void:
	var plastic := k.M(0x3fa7d6, {"s": 60, "sp": 0x777777})
	k.box(g, 1.3, .05, .85, plastic, 0, 0, 0)
	k.box(g, 1.3, .14, .04, plastic, 0, .05, .405)
	k.box(g, 1.3, .14, .04, plastic, 0, .05, -.405)
	k.box(g, .04, .14, .85, plastic, -.63, .05, 0)
	k.box(g, .04, .14, .85, plastic, .63, .05, 0)
	k.box(g, .03, .14, .77, plastic, -.2, .05, 0)
	k.box(g, .8, .09, .03, plastic, .21, .05, 0)
	k.cyl(g, .09, .1, .36, 7, k.M(0xd13b3b, {"s": 60, "sp": 0x777777}), -.41, .05, -.18)
	k.cyl(g, .095, .095, .1, 7, k.M(0x2a2a30), -.41, .41, -.18)
	var lying := k.cyl(g, .09, .1, .36, 7, k.M(0x3a9c5d, {"s": 60, "sp": 0x777777}), -.41, .05, .2)
	lying.rotation.z = PI / 2
	lying.position.y = .05 + .1


## A token for an item: a shape for its kind, its rarity's colour.
static func _token(k: RoomKit, p: Node3D, it: Dictionary, x: float, y: float, z: float, ry: float) -> void:
	var g := k.group(p, x, y, z, ry)
	var mat := k.M(RARITY.get(str(it.get("rarity", "")), RARITY.common), {"s": 50, "sp": 0x666666})
	match str(it.get("kind", "")):
		"INFO":
			k.box(g, .2, .02, .14, mat, 0, 0, 0)
			k.box(g, .14, .021, .02, k.M(0x2b3a8a), 0, 0, -.02)
		"ECONOMY":
			k.cyl(g, .075, .075, .03, 9, mat, 0, 0, 0)
		"ACTION":
			k.box(g, .12, .1, .12, mat, 0, 0, 0)
		_:
			k.put(g, RoomKit.ico_geo(.075, 0), mat, 0, .07, 0)
