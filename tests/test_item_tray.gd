extends "res://tests/test_case.gd"
## The item tray on the table and its picker (M9.7 item 5): a tray for each room with a
## token for each item held, clear of the room's props; the picker lists what the
## phone's ITEMS page lists, USE lit and greyed alike, with the same reasons; and USE on
## the picker does what USE on the phone does. Runs the game's parts without a window.


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func test_a_tray_for_each_room_with_a_token_per_item() -> void:
	var t := ItemTray.new()
	_root().add_child(t)
	check(not t.visible and t._hit.collision_layer == 0, "put away until the run shows it")
	t.show_tray(true)
	check(t.visible and t._hit.collision_layer == 1 and t._hit.has_meta("items"), "shown, it catches clicks as the item tray")
	var kinds := ["INFO", "ECONOMY", "ACTION", "SURE"]
	var rarities := ["common", "rare", "legendary"]
	var many := []
	for i in 11:
		many.append({"kind": kinds[i % 4], "rarity": rarities[i % 3]})
	for id in RoomSet.ORDER:
		t.set_room(id)
		eq(t.room, id, "the room's tray")
		for n in [0, 1, 3, 8, 11]:
			t.show_items(many.slice(0, n))
			eq(t.token_count(), mini(n, ItemTray.MAX_TOKENS), "%s: tokens for %d items" % [id, n])
		var hit := t.hit_box()
		var model := t.bounds(t._model)
		var tokens := t.bounds(t._tokens)
		check(hit.encloses(model) and hit.encloses(tokens), "%s: the click box holds the tray and its tokens (%s, %s, %s)" % [id, hit, model, tokens])
		check(model.size.x < 1.5 and model.size.z < 1.2, "%s: a small tray (%s)" % [id, model.size])
		check(model.position.y > -0.01, "%s: it stands on the table" % id)
		# Tokens lie inside the tray's walls.
		check(tokens.position.x > model.position.x and tokens.end.x < model.end.x \
			and tokens.position.z > model.position.z and tokens.end.z < model.end.z, "%s: tokens inside the tray" % id)
	t.set_room("diner")
	t.show_items(many.slice(0, 2))
	t.set_room("bar")
	eq(t.token_count(), 2, "the tokens move to the next room's tray")
	t.show_tray(false)
	check(not t.visible and t._hit.collision_layer == 0, "free play: hidden, and no longer caught by clicks")
	t.free()


## Where the game lays it (Game.ITEM_TRAY_AT, on a wide and a 4:3 window) it is on the
## table and clear of every room's props.
func test_the_tray_clears_the_room_props() -> void:
	var rooms := RoomSet.new()
	_root().add_child(rooms)
	var t := ItemTray.new()
	_root().add_child(t)
	t.show_tray(true)
	for id in RoomSet.ORDER:
		rooms.set_room(id)
		t.set_room(id)
		for sx in [5.3, 4.42]:
			t.position = Game.ITEM_TRAY_AT * Vector3(sx, 1, 1)
			t.rotation = Vector3(0, Game.ITEM_TRAY_YAW, 0)
			var mine := t.global_transform * t.bounds(t._model)
			check(mine.position.x > -7.5 and mine.end.z < 6.25, "%s at %.2f: on the table (%s)" % [id, sx, mine])
			var g: Node3D = rooms.get_node(NodePath(id))
			for m: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
				var b := m.global_transform * m.get_aabb()
				if b.position.y < -0.05 or b.position.y > mine.end.y:
					continue   # the table, the room, what hangs above
				var apart := b.end.x < mine.position.x or b.position.x > mine.end.x or b.end.z < mine.position.z or b.position.z > mine.end.z
				check(apart, "%s at %.2f: the tray clears %s (%s)" % [id, sx, m.get_path(), b])
	t.free()
	rooms.free()


## A Game never added to the tree leaves its parts' own parts behind (they are made in
## _ready otherwise): free the nodes left without a parent since `before`, as the
## game's run-tool path does.
func _sweep(before: Array) -> void:
	for id in Node.get_orphan_node_ids():
		if before.has(id):
			continue
		var n := instance_from_id(id)
		if is_instance_valid(n) and n is Node and n.get_parent() == null:
			n.free()


func _game(pack: PackDef) -> Game:
	var g := Game.new()
	g.use_save = false
	g.run = RunState.start(RunConfig.standard(), "I-1", ["diner", "bar", "bingo"])
	g.economy = g.run.new_economy()
	g.machine = g.run.new_machine(pack.forms, true)
	g.columns = range(g.machine.forms.size())
	g.run.items = {"peek": 1, "slip": 1, "overtime": 2, "happy": 1, "tip": 1, "copy": 1}
	return g


## before: the day not chosen yet, at the table. machine: a day of play at the machine,
## no tickets bought. table: a day of play at the table, two tickets in the tray.
func _put_in(g: Game, pack: PackDef, state: String) -> void:
	g.at_machine = state == "machine"
	if state != "before":
		g.run.play(g.economy)
	if state == "table":
		for i in 2:
			g.tray.items.append({"form": pack.forms[0], "ticket": {"no": i + 1, "prize": 0}, "bet": 1})


func _texts(n: Node) -> Array:
	var out := []
	for l: Label in n.find_children("*", "Label", true, false):
		out.append(l.text)
	return out


func test_the_picker_lists_what_the_phone_lists() -> void:
	var pack := core_pack()
	if pack == null:
		return
	# What each state lights (the rules are the phone's: Game._can_use).
	var orphans := Node.get_orphan_node_ids()
	var lit := {
		"before": {"overtime": true, "peek": false, "tip": false, "happy": false, "slip": false, "copy": false},
		"machine": {"overtime": false, "peek": true, "tip": true, "happy": true, "slip": false, "copy": false},
		"table": {"overtime": false, "peek": false, "tip": false, "happy": true, "slip": true, "copy": false},
	}
	for state in ["before", "machine", "table"]:
		var g := _game(pack)
		_put_in(g, pack, state)
		var st := g.items_state()
		var ps := g.phone_state()
		eq(ps.held, st.held, state + ": the phone's rows are the picker's")
		eq(ps.held_line, st.held_line, state + ": the count line")
		var phone := Phone.new()
		_root().add_child(phone)
		phone.open(ps, "shop")
		phone.shop_tab = "items"
		phone.go("shop")
		var picker := ItemPicker.new()
		_root().add_child(picker)
		picker.open(st)
		var ids := []
		for it in st.held:
			ids.append(it.id)
		eq(picker.listed(), ids, state + ": the items held, in the phone's order")
		eq(ids.size(), 6, state + ": every item held is listed")
		var phone_texts := _texts(phone)
		for it in st.held:
			var id: String = it.id
			var mine := picker.key("use_" + id)
			var theirs := phone.key("use_" + id)
			check((mine == null) == (theirs == null), "%s, %s: USE on both or on neither" % [state, id])
			if mine != null and theirs != null:
				eq(mine.disabled, theirs.disabled, "%s, %s: lit or grey alike" % [state, id])
			var on: bool = mine != null and not mine.disabled
			if lit[state].has(id):
				eq(on, lit[state][id], "%s, %s: USE lit" % [state, id])
			var why: String = it.why if it.why != "" and (it.use_text == "" or not it.can_use) else ""
			eq(picker.why(id), why, "%s, %s: the reason under it" % [state, id])
			if why != "":
				check(phone_texts.has(why), "%s, %s: the phone gives the same reason" % [state, id])
		picker.free()
		phone.free()
		g.free()
	# Nothing held: the count, and where to get some.
	var g := _game(pack)
	g.run.items = {}
	var picker := ItemPicker.new()
	_root().add_child(picker)
	picker.open(g.items_state())
	eq(picker.listed(), [], "nothing held, nothing listed")
	check(_texts(picker).has(g.items_state().held_line), "the count line still shows")
	picker.free()
	g.free()
	_sweep(orphans)


## USE pressed on the picker against USE pressed on the phone, from the same state:
## the run, the cash and the tray end up the same.
func test_use_from_the_picker_does_what_the_phone_does() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var orphans := Node.get_orphan_node_ids()
	for c in [["overtime", "before"], ["happy", "table"], ["slip", "table"], ["peek", "machine"]]:
		var id: String = c[0]
		var a := _game(pack)
		var b := _game(pack)
		_put_in(a, pack, c[1])
		_put_in(b, pack, c[1])
		var before := a.run.held(id)
		a._on_phone("use_item", id)
		_root().add_child(b.item_picker)
		b.item_picker.acted.connect(b._on_picker)
		b.item_picker.open(b.items_state())
		var k := b.item_picker.key("use_" + id)
		if check(k != null and not k.disabled, id + ": USE lit on the picker"):
			k.pressed.emit()
		eq(b.run.to_dict(), a.run.to_dict(), id + ": the run the same")
		eq(b.economy.cash, a.economy.cash, id + ": the cash the same")
		eq(b.tray.size(), a.tray.size(), id + ": the tray the same")
		eq(b.aim, a.aim, id + ": the column aim the same")
		if id == "peek":
			eq(b.aim, "peek", "a column item waits for a column")
			check(not b.item_picker.visible, "the picker is put away for the column press")
		else:
			eq(a.run.held(id), before - 1, id + ": used up once")
			check(b.item_picker.visible, id + ": the picker stays up")
			var ids := []
			for it in b.items_state().held:
				ids.append(it.id)
			eq(b.item_picker.listed(), ids, id + ": with the new numbers")
		_root().remove_child(b.item_picker)
		a.free()
		b.free()
	_sweep(orphans)
	for p in Sfx._players:
		p.stop()   # a toss still sounding when the tests quit is reported as leaked
		p.stream = null
