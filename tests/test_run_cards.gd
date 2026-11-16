extends "res://tests/test_case.gd"
## The rounds of perk offers on the run's card and the upgrade slots on the phone (M9.8
## step 2): a morning round is a pick of one and says so, the day is not started around
## it; a layer paid brings its reward rounds (free, no reroll, an upgrade card marked as
## one) after the story card, then the morning's; a save made with a reward round up
## comes back to it; TODAY's upgrade slots are bought from the phone. Runs the game's
## parts without a window.


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _game(pack: PackDef, seed_text := "C-1") -> Game:
	var g := Game.new()
	g.use_save = false
	g.run = RunState.start(RunConfig.standard(), seed_text, ["diner", "bar", "bingo"])
	g.run.story = ""
	g.economy = g.run.new_economy()
	g.machine = g.run.new_machine(pack.forms, true)
	g.columns = range(g.machine.forms.size())
	return g


func _lines(g: Game) -> Array:
	var out := []
	for l in g.run_card._body.get_children():
		if l is Label:
			out.append(l.text)
	return out


## A dealt perk with more than one level and no requirements.
func _levelled(r: RunState) -> String:
	for p in r.catalog.dealt():
		if p.levels.size() > 1 and p.get("requires", {}).is_empty() and not Catalog.meta(p):
			return p.id
	return ""


func _sweep(before: Array) -> void:
	for id in Node.get_orphan_node_ids():
		if before.has(id):
			continue
		var n := instance_from_id(id)
		if is_instance_valid(n) and n is Node and n.get_parent() == null:
			n.free()


func _quiet() -> void:
	for p in Sfx._players:
		p.stop()
		p.stream = null


func test_a_morning_round_is_a_pick_of_one() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var orphans := Node.get_orphan_node_ids()
	var g := _game(pack)
	var r := g.run
	g.economy.bonus(5000)
	g._show_run_card()
	eq(g.run_card.title(), tr("PERK OFFERS"), "the morning round's card")
	check(_lines(g).has(tr("TAKE ONE: THE OTHERS GO")), "it says the pick is one")
	for k in r.offers.size():
		check(g.run_card.key("offer_%d" % k) != null, "a key for card %d" % (k + 1))
	check(g.run_card.key("offer_reroll") != null and g.run_card.key("offer_done") != null, "REROLL and SKIP FOR AN ITEM")
	check(g.run_card.key("play") == null and g.run_card.key("work") == null, "no day keys while the round is up")
	g._on_card("play")
	g._on_card("work")
	check(r.today == "" and r.offers_open, "PLAY and WORK do not get around the round")
	eq(g.run_card.title(), tr("PERK OFFERS"), "the round's card again")
	var id := str(r.offers[0])
	g._on_offer("offer_0")
	check(r.level(id) == 1 and not r.offers_open and r.offers.is_empty(), "one taken: the others go")
	check(g.run_card.key("play") != null and g.run_card.key("offer_0") == null, "then the day's choice")
	g.free()
	_sweep(orphans)
	_quiet()


func test_reward_rounds_after_a_layer_paid() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var orphans := Node.get_orphan_node_ids()
	var g := _game(pack, "C-2")
	var r := g.run
	var up := _levelled(r)
	if not check(up != "", "a dealt perk with levels to give"):
		return
	r.perks[up] = 1
	g.economy.bonus(r.due() + 100)
	g._on_offer("offer_done")
	check(not r.offers_open, "the morning round given up")
	check(r.play(g.economy), "a day at the machine")
	check(r.pay(g.economy, g.machine), "the layer paid early, in the middle of the day")
	g._show_run_card()
	eq(g.run_card.title(), tr("ABOUT THE INTEREST"), "the story card first")
	check(r.offers_open and r.offer_reward, "a reward round waits behind it")
	g._on_card("ok")
	eq(g.run_card.title(), tr("ON THE HOUSE"), "then the reward round's card")
	var lines := _lines(g)
	check(lines.has(tr("THE LAYER IS PAID: TAKE ONE FOR FREE")), "it says why")
	check(r.rewards_pending > 0 and lines.has(tr("%d MORE AFTER THIS ONE") % r.rewards_pending), "and how many follow")
	check(g.run_card.key("offer_reroll") == null and g.run_card.key("offer_done") != null, "no reroll; SKIP FOR AN ITEM stays")
	for k in r.offers.size():
		var key := g.run_card.key("offer_%d" % k)
		check(key != null and key.text == tr("FREE"), "card %d is taken for nothing" % (k + 1))
	var last := str(r.offers[-1])
	eq(last, up, "the last card is the perk held, an upgrade")
	check(lines.has(tr("UPGRADE: LEVEL %d TO %d") % [1, 2]), "marked as an upgrade, from level 1 to 2")
	# A save made now comes back to the same card.
	var g2 := _game(pack)
	g2.run = RunState.from_dict(r.to_dict(), RunConfig.standard())
	g2._show_run_card()
	eq(g2.run_card.title(), tr("ON THE HOUSE"), "reloaded: the reward round's card")
	eq(g2.run.offers, r.offers, "the same cards")
	eq(g2.run.rewards_pending, r.rewards_pending, "the same rounds to come")
	g2.free()
	# The upgrade taken for nothing; the next reward round comes up at once.
	var cash := g.economy.cash
	var pending := r.rewards_pending
	g._on_offer("offer_%d" % (r.offers.size() - 1))
	check(r.level(up) == 2 and g.economy.cash == cash, "the upgrade taken free")
	check(r.offer_reward and r.rewards_pending == pending - 1, "the next reward round up")
	eq(g.run_card.title(), tr("ON THE HOUSE"), "on the same card")
	var guard := 0
	while r.offer_reward and guard < 20:
		guard += 1
		g._on_offer("offer_done")
	eq(g.run_card.title(), tr("PERK OFFERS"), "then the new layer's morning round")
	check(r.offers_open and not r.offer_reward and r.today == "", "before the day is chosen")
	g.free()
	_sweep(orphans)
	_quiet()


func test_upgrade_slots_on_the_phone() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var orphans := Node.get_orphan_node_ids()
	var g := _game(pack, "C-3")
	var r := g.run
	_root().add_child(g.phone)
	g.phone.acted.connect(g._on_phone)
	# None held: nothing on TODAY but the items.
	r.upgrades = []
	var st := g.phone_state()
	check(st.upgrades.is_empty() and st.upgrades_line == "", "no upgrade slots today")
	g.phone.open(st, "shop")
	g.phone.shop_tab = "today"
	g.phone.go("shop")
	check(not _has_text(g.phone, tr("UPGRADES TODAY")), "the page stays quiet")
	g.phone.close()
	var up := _levelled(r)
	if not check(up != "", "a dealt perk with levels to give"):
		return
	r.perks[up] = 1
	r.upgrades = [up]
	st = g.phone_state()
	eq(st.upgrades.size(), 1, "a slot for the perk held")
	eq(st.upgrades_line, tr("UPGRADES TODAY"), "under its line")
	g.economy.pay(g.economy.cash)
	g.phone.open(g.phone_state(), "shop")
	g.phone.shop_tab = "today"
	g.phone.go("shop")
	var key := g.phone.key("buy_upgrade_" + up)
	check(g.phone.row("upgrade_" + up) != null and key != null, "its card and BUY key on TODAY")
	check(key != null and key.disabled, "greyed without the cash")
	check(_has_text(g.phone, tr("NEXT: %s") % g._perk_text(r.catalog.perk(up), 2)), "what the next level does")
	var price := r.perk_price(up)
	g.economy.bonus(price)
	g.phone.show_state(g.phone_state())
	key = g.phone.key("buy_upgrade_" + up)
	check(key != null and not key.disabled, "lit with the cash")
	if key != null:
		key.pressed.emit()
	check(r.level(up) == 2 and g.economy.cash == 0 and not r.upgrades.has(up), "bought: a level up, paid, gone from the slots")
	check(g.phone.row("upgrade_" + up) == null and g.phone.key("buy_upgrade_" + up) == null, "gone from the page")
	g.phone.close()
	_root().remove_child(g.phone)
	g.free()
	_sweep(orphans)
	_quiet()


func _has_text(n: Node, text: String) -> bool:
	for l: Label in n.find_children("*", "Label", true, false):
		if l.text == text:
			return true
	return false
