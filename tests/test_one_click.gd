extends "res://tests/test_case.gd"
## The two hand settings (M9.7): one click opens the whole ticket, and a revealed ticket
## goes to its pile by itself (a winner after a longer look than a loser). Runs TicketFlow on a real TicketView of every
## core form (flaps and band built from the layout, nothing painted) without a window.

const DT := 0.05
const FRAMES := 400


## A TicketView of `form` as use_form builds it, with blank covers instead of paintings.
func _view(form: FormDef) -> TicketView:
	var view := TicketView.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	view.form = form
	var s: Array = form.layout.card.size
	view.size = Vector2(s[0], s[1])
	var covers: Array[Texture2D] = []
	covers.resize(form.layout.flaps.size())
	view._covers[form.art_key()] = covers
	view._band_tex[form.art_key()] = null
	view._build_flaps()
	view._build_band()
	view.reset()
	return view


## A pile that counts what lands and paints nothing.
func _pile(inside: bool) -> DiscardPile:
	var p := DiscardPile.new()
	p.show_inside = inside
	p.find_form = func(_uid: String) -> FormDef: return null
	(Engine.get_main_loop() as SceneTree).root.add_child(p)
	return p


## The flow holding one ticket of `form` with `prize`, dealt front up (or back up), and an
## Economy paid on `revealed` the way the game's free play pays it.
func _rig(form: FormDef, prize: int, back := false) -> Dictionary:
	var root := (Engine.get_main_loop() as SceneTree).root
	var flow := TicketFlow.new()
	flow.view = _view(form)
	flow.camera = CameraRig.new()
	root.add_child(flow.camera)
	flow.flecks = Flecks.new()
	root.add_child(flow.flecks)
	flow.pile = _pile(false)
	flow.win_pile = _pile(true)
	flow.deal_after_toss = func() -> bool: return false
	flow.form = form
	flow.ticket = {"no": 7, "serial": "T-0007", "prize": prize}
	flow.entry = {"form": form, "ticket": flow.ticket}
	flow.state = TicketFlow.State.BACK if back else TicketFlow.State.FRONT
	var rig := {"flow": flow, "economy": Economy.new(), "revealed": 0, "tossed": 0}
	flow.revealed.connect(func(t: Dictionary, _f: FormDef) -> void:
		rig.revealed += 1
		rig.economy.open_ticket(int(t.prize)))
	flow.tossed.connect(func() -> void: rig.tossed += 1)
	return rig


func _free(rig: Dictionary) -> void:
	var flow: TicketFlow = rig.flow
	for n in [flow.view, flow.camera, flow.flecks, flow.pile, flow.win_pile]:
		n.free()
	flow.free()


## Runs frames until the flow is in `want` (or FRAMES pass). `space`: press Space
## whenever the ticket waits for the hand, the existing fast way to open by hand.
func _run_until(flow: TicketFlow, want: TicketFlow.State, space := false) -> int:
	for n in FRAMES:
		if flow.state == want:
			return n
		if space and (flow.state == TicketFlow.State.FRONT or flow.state == TicketFlow.State.BACK):
			flow.primary()
		flow._process(DT)
	return -1


func _forms() -> Array:
	var pack := core_pack()
	return [] if pack == null else pack.forms


func test_one_click_opens_every_form_and_pays_as_by_hand() -> void:
	var forms := _forms()
	check(forms.size() >= 8, "the core pack's eight forms")
	for form: FormDef in forms:
		for back in [false, true]:
			for prize in [0, 25]:
				var name := "%s %s, prize %d" % [form.id, "back up" if back else "front up", prize]
				var hand := _rig(form, prize, back)
				var by_hand := _run_until(hand.flow, TicketFlow.State.REVEALED, true)
				check(by_hand > 0, name + ": opens by hand (Space)")
				var one := _rig(form, prize, back)
				one.flow.one_click = true
				check(not one.flow.press(Vector2.ZERO), name + ": one click grabs no paper")
				var after := _run_until(one.flow, TicketFlow.State.REVEALED)
				check(after > 0, name + ": one click opens it with no more input")
				check(not one.flow.view.band_on, name + ": band gone")
				for s in one.flow.view.sims:
					check(s.is_settled(), name + ": every flap open")
				eq(one.revealed, 1, name + ": revealed once")
				eq(one.revealed, hand.revealed, name + ": as by hand")
				eq(one.economy.cash, hand.economy.cash, name + ": pays what opening by hand pays")
				eq(one.economy.wins, hand.economy.wins, name + ": wins counted the same")
				eq(one.economy.opened, hand.economy.opened, name + ": opened counted the same")
				_free(hand)
				_free(one)


func test_space_with_one_click_opens_it_all() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var rig := _rig(pack.form("plate"), 5)
	var flow: TicketFlow = rig.flow
	flow.one_click = true
	flow.primary()
	eq(flow.state, TicketFlow.State.FLIP, "Space turns it over")
	check(_run_until(flow, TicketFlow.State.REVEALED) > 0, "and every column opens by itself")
	eq(rig.revealed, 1, "revealed once")
	_free(rig)


func test_one_click_off_keeps_the_old_hand() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var rig := _rig(pack.form("spur"), 0)
	var flow: TicketFlow = rig.flow
	flow.press(Vector2.ZERO)
	check(flow.view.band_on, "a click on the front of a banded ticket does not break the band")
	eq(flow.state, TicketFlow.State.FRONT, "nor turn it over")
	_free(rig)


func test_a_winner_goes_to_the_winners_pile_by_itself() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var rig := _rig(pack.form("catch"), 25)
	var flow: TicketFlow = rig.flow
	flow.auto_wins = true
	flow.one_click = true
	flow.press(Vector2.ZERO)
	check(_run_until(flow, TicketFlow.State.REVEALED) > 0, "revealed")
	var shown := _run_until(flow, TicketFlow.State.TOSS)
	check(shown * DT >= TicketFlow.WIN_SHOW_TIME - DT, "shown for a moment first (%.2f s)" % (shown * DT))
	check(_run_until(flow, TicketFlow.State.IDLE) > 0, "tossed")
	eq(flow.win_pile.opened, 1, "on the winners' pile")
	eq(flow.pile.opened, 0, "not the discard pile")
	eq(rig.tossed, 1, "tossed once")
	eq(rig.revealed, 1, "paid once")
	eq(rig.economy.won, 25, "the prize, once")
	_free(rig)


func test_a_loser_goes_to_the_discard_pile_by_itself() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var rig := _rig(pack.form("catch"), 0)
	var flow: TicketFlow = rig.flow
	flow.auto_wins = true
	flow.one_click = true
	flow.press(Vector2.ZERO)
	check(_run_until(flow, TicketFlow.State.REVEALED) > 0, "revealed")
	var shown := _run_until(flow, TicketFlow.State.TOSS)
	check(shown > 0, "a loser goes by itself")
	check(shown * DT >= TicketFlow.LOSE_SHOW_TIME - DT and shown * DT < TicketFlow.WIN_SHOW_TIME,
		"after a shorter look than a winner's (%.2f s)" % (shown * DT))
	check(_run_until(flow, TicketFlow.State.IDLE) > 0, "tossed")
	eq(flow.pile.opened, 1, "onto the discard pile")
	eq(flow.win_pile.opened, 0, "not the winners' pile")
	eq(rig.tossed, 1, "tossed once")
	eq(rig.revealed, 1, "revealed once")
	_free(rig)

	# A click still sends it at once.
	rig = _rig(pack.form("catch"), 0)
	flow = rig.flow
	flow.auto_wins = true
	flow.one_click = true
	flow.press(Vector2.ZERO)
	_run_until(flow, TicketFlow.State.REVEALED)
	flow.press(Vector2.ZERO)
	eq(flow.state, TicketFlow.State.TOSS, "a click before the time is up sends it at once")
	_free(rig)

	# Setting off: a loser stays in hand until clicked.
	rig = _rig(pack.form("catch"), 0)
	flow = rig.flow
	flow.one_click = true
	flow.press(Vector2.ZERO)
	_run_until(flow, TicketFlow.State.REVEALED)
	eq(_run_until(flow, TicketFlow.State.TOSS), -1, "setting off: a loser stays in hand")
	flow.press(Vector2.ZERO)
	eq(flow.state, TicketFlow.State.TOSS, "until clicked")
	_free(rig)


func test_auto_place_waits_for_cards() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var rig := _rig(pack.form("catch"), 0)
	var flow: TicketFlow = rig.flow
	flow.auto_wins = true
	var held := [true]
	flow.may_auto_collect = func() -> bool: return not held[0]
	flow.one_click = true
	flow.press(Vector2.ZERO)
	_run_until(flow, TicketFlow.State.REVEALED)
	eq(_run_until(flow, TicketFlow.State.TOSS), -1, "a card over the table holds a loser too")
	held[0] = false
	eq(_run_until(flow, TicketFlow.State.TOSS), 1, "it goes as soon as the card is gone")
	_free(rig)

	rig = _rig(pack.form("kabawk"), 50)
	flow = rig.flow
	flow.auto_wins = true
	held = [true]
	flow.may_auto_collect = func() -> bool: return not held[0]
	flow.one_click = true
	flow.press(Vector2.ZERO)
	_run_until(flow, TicketFlow.State.REVEALED)
	eq(_run_until(flow, TicketFlow.State.TOSS), -1, "a card over the table holds the winner")
	held[0] = false
	eq(_run_until(flow, TicketFlow.State.TOSS), 1, "it goes as soon as the card is gone")
	_free(rig)

	rig = _rig(pack.form("catch"), 25)
	flow = rig.flow
	flow.one_click = true
	flow.press(Vector2.ZERO)
	_run_until(flow, TicketFlow.State.REVEALED)
	eq(_run_until(flow, TicketFlow.State.TOSS), -1, "setting off: a winner waits for the click")
	_free(rig)
