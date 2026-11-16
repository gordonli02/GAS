extends "res://tests/test_case.gd"
## The item tray on the table and its picker (M9.7 item 5): a tray for each room with a
## token for each item held, clear of the room's props; the picker lists what the
## phone's ITEMS page lists, USE lit and greyed alike, with the same reasons; USE on
## the picker does what USE on the phone does; and a click on a token uses that item
## (a column item: to the machine with it aimed), its tip naming it and why it cannot be
## used. Runs the game's parts without a window.


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
		check(hit.position.x <= model.position.x and hit.end.x >= model.end.x and hit.position.z <= model.position.z \
			and hit.end.z >= model.end.z, "%s: the tray's click box covers its footprint (%s, %s)" % [id, hit, model])
		check(is_equal_approx(hit.end.y, float(ItemTray.ROOMS[id].floor)), "%s: up to its floor, so the tokens catch their own clicks" % id)
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
	for h: StaticBody3D in t.token_hits():
		eq(h.collision_layer, 0, "nor its tokens")
	t.free()


## Each token has a click box of its own with its item's id, around the token, apart from
## its neighbours'; a ray down onto a token finds it, one onto the tray's floor the tray.
func test_each_token_has_its_own_click_box() -> void:
	var t := ItemTray.new()
	_root().add_child(t)
	t.show_tray(true)
	var kinds := ["INFO", "ECONOMY", "ACTION", "SURE"]
	var held := []
	for i in ItemTray.MAX_TOKENS:
		held.append({"id": "item%d" % i, "kind": kinds[i % 4], "rarity": "common"})
	var space := t.get_world_3d().direct_space_state
	for id in RoomSet.ORDER:
		t.set_room(id)
		t.show_items(held)
		check(t._lid_shape.disabled == (id != "bar"), id + ": a click box for the lid only in the bar")
		var hits := t.token_hits()
		eq(hits.size(), ItemTray.MAX_TOKENS, id + ": a click box per token")
		var boxes := []
		var into := t.global_transform.affine_inverse()
		for i in hits.size():
			var h: StaticBody3D = hits[i]
			eq(str(h.get_meta("item")), "item%d" % i, "%s: token %d knows its item" % [id, i])
			check(h.collision_layer == 1, "%s: token %d catches clicks" % [id, i])
			var size: Vector3 = ((h.get_child(0) as CollisionShape3D).shape as BoxShape3D).size
			var b := (into * h.global_transform) * AABB(-size / 2.0, size)
			var token := t.bounds(t._tokens.get_child(i))
			# (The bingo hall's spots are narrower than a card: the box holds its middle.)
			check(b.has_point(token.get_center()) and b.end.y >= token.end.y - .001, "%s: token %d in its box (%s, %s)" % [id, i, b, token])
			check(b.position.y >= float(ItemTray.ROOMS[id].floor) - .001, "%s: token %d's box above the tray's floor" % [id, i])
			for o: AABB in boxes:
				check(not o.grow(-.001).intersects(b), "%s: token %d's box apart from the others" % [id, i])
			boxes.append(b)
		# Rays straight down: onto a token, and onto the floor clear of them.
		var top := Vector3(0, 3, 0)
		var at := t.token_point("item2")
		var got := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + top, at - top))
		check(not got.is_empty() and str(got.collider.get_meta("item", "")) == "item2", id + ": a click on a token finds that token")
		at = t.floor_point()
		got = space.intersect_ray(PhysicsRayQueryParameters3D.create(at + top, at - top))
		check(not got.is_empty() and got.collider.has_meta("items"), id + ": a click on the floor finds the tray")
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
	g.run.items = {"peek": 1, "slip": 1, "overtime": 2, "happy": 1, "copy": 1}
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
		"before": {"overtime": true, "peek": false, "happy": false, "slip": false, "copy": false},
		"machine": {"overtime": false, "peek": true, "happy": true, "slip": false, "copy": false},
		"table": {"overtime": false, "peek": false, "happy": true, "slip": true, "copy": false},
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
		eq(ids.size(), 5, state + ": every item held is listed")
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
	_quiet()


func _quiet() -> void:
	for p in Sfx._players:
		p.stop()   # a toss still sounding when the tests quit is reported as leaked
		p.stream = null


## A token of an item used from where it lies (RETURN SLIP, HAPPY HOUR, OVERTIME): a click
## on it does what USE on the phone does from the same state.
func test_a_token_does_what_the_phones_use_does() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var orphans := Node.get_orphan_node_ids()
	for c in [["overtime", "before"], ["happy", "table"], ["slip", "table"]]:
		var id: String = c[0]
		var a := _game(pack)
		var b := _game(pack)
		_put_in(a, pack, c[1])
		_put_in(b, pack, c[1])
		var before := a.run.held(id)
		a._on_phone("use_item", id)
		b.use_token(id)
		eq(a.run.held(id), before - 1, id + ": used up once from the phone")
		eq(b.run.to_dict(), a.run.to_dict(), id + ": the run the same")
		eq(b.economy.cash, a.economy.cash, id + ": the cash the same")
		eq(b.tray.size(), a.tray.size(), id + ": the tray the same")
		eq([b.aim, b.at_machine], ["", false], id + ": still at the table, nothing aimed")
		check(not b.item_picker.visible and not b.phone.visible, id + ": nothing opened")
		a.free()
		b.free()
	_sweep(orphans)
	_quiet()


## A column item's token (PEEK) takes the player to the machine with it aimed, as USE on
## the phone at the machine aims it: the next column press there uses it.
func test_a_column_token_goes_to_the_machine_aimed() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var orphans := Node.get_orphan_node_ids()
	var a := _game(pack)
	var b := _game(pack)
	_put_in(a, pack, "machine")
	_put_in(b, pack, "machine")
	b.at_machine = false   # the same day of play, at the table
	a._on_phone("use_item", "peek")
	b.use_token("peek")
	check(b.at_machine and b.camera.at_machine, "at the machine")
	eq(b.aim, "peek", "PEEK aimed: the next column press is it")
	eq(b.aim, a.aim, "as USE on the phone at the machine aims it")
	eq(b.run.held("peek"), 1, "not used up until the column is picked")
	eq(b.run.to_dict(), a.run.to_dict(), "the run the same")
	a.free()
	b.free()
	_sweep(orphans)
	_quiet()


## A token of an item that cannot be used now changes nothing and says why, the phone's
## reason (COPIER: its rule); a column token waits while a ticket is on its way to the hand.
func test_a_token_that_cannot_be_used_changes_nothing() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var orphans := Node.get_orphan_node_ids()
	for c in [["peek", "before", "AT THE MACHINE, ON A DAY OF PLAY"], ["happy", "before", "ON A DAY OF PLAY"],
			["overtime", "table", "BEFORE THE DAY IS CHOSEN, OR AFTER A SHIFT"], ["copy", "table", "COPIES THE LAST ITEM YOU BOUGHT"],
			["peek", "moving", ""]]:
		var id: String = c[0]
		var g := _game(pack)
		_put_in(g, pack, "table" if c[1] == "moving" else c[1])
		if c[1] == "moving":
			g.flow.state = TicketFlow.State.DEAL
		g.hud.set_status("READY")
		var run := g.run.to_dict()
		var cash := g.economy.cash
		var tray := g.tray.size()
		g.use_token(id)
		var name := "%s, %s" % [id, c[1]]
		eq(g.run.to_dict(), run, name + ": the run unchanged")
		eq([g.economy.cash, g.tray.size()], [cash, tray], name + ": cash and tray unchanged")
		eq([g.aim, g.at_machine], ["", false], name + ": still at the table, nothing aimed")
		eq(g.hud._status_key, tr(c[2]) if c[2] != "" else "READY", name + (": says why" if c[2] != "" else ": says nothing yet"))
		g.free()
	_sweep(orphans)
	_quiet()


## Over a token: its tip names the item and what it does, and why when it cannot be used.
func test_a_tokens_tip() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var orphans := Node.get_orphan_node_ids()
	var g := _game(pack)
	_put_in(g, pack, "table")
	var peek := g.run.catalog.item("peek")
	g.hover_item = "peek"
	g.show_item_tip()
	eq(g.hud.tip(), [tr(peek.name), g._item_desc(peek)], "PEEK on a day of play: its name and what it does, no reason")
	var ot := g.run.catalog.item("overtime")
	g.hover_item = "overtime"
	g.show_item_tip()
	eq(g.hud.tip(), [tr(ot.name), g._item_desc(ot) + "\n" + tr("BEFORE THE DAY IS CHOSEN, OR AFTER A SHIFT")], "OVERTIME on a day of play: and why not now")
	g.hover_item = "reel"
	g.show_item_tip()
	eq(g.hud.tip(), ["", ""], "an item not held: no tip")
	g.hover_item = ""
	g.show_item_tip()
	eq(g.hud.tip(), ["", ""], "off the tokens: no tip")
	g.free()
	_sweep(orphans)


## The LCD's reading lines (Game._reading_lines) by the chain (docs/roadmap.md 数值方向
## 三.10): nothing without it; READ THE FLARE, whether a top prize is in; READ THE FLOW,
## a second line, about how many were sold and what they paid; ROUGH COUNT, about how
## many are left beside the flare. Never the prizes left or what the rest would pay.
func test_the_lcd_reads_a_box_by_the_chain() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var orphans := Node.get_orphan_node_ids()
	var g := _game(pack)
	var box: TicketBox = g.machine.boxes[g.columns[1]]
	box.cursor = 37
	var top := tr(BoxReading.top(BoxReading.read(box)))
	g.run.perks = {}
	eq(g._reading_lines(1), [], "no perk of the chain: nothing")
	g.run.perks = {"read1": 1}
	eq(g._reading_lines(1), [top], "READ THE FLARE: whether a top prize is in")
	var paid := 0
	for k in 37:
		paid += int(box.tickets[k].prize)
	var flow := tr("ABOUT %d SOLD · PAID %s") % [50, Hud._money(paid)]
	g.run.perks = {"read1": 1, "flow": 1}
	eq(g._reading_lines(1), [top, flow], "READ THE FLOW: about 50 sold (37), and what they paid")
	g.run.perks = {"read1": 1, "flow": 1, "readleft": 1}
	eq(g._reading_lines(1), [top + " · " + tr("ABOUT %d LEFT") % BoxReading.rough(box.size - 37), flow],
		"ROUGH COUNT: and about how many are left")
	eq(g._reading_lines(-1), [], "no column named: nothing")
	g.free()
	_sweep(orphans)
