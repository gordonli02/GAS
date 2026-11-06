extends "res://tests/test_case.gd"
## The save file (SaveFile) and the session it carries (SessionState): what is kept,
## what a reload gives back, and that bad or foreign files never break a start.

const DIR := "user://test_save"


func _path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var p := DIR.path_join(name)
	for suffix in ["", ".tmp", ".bad", ".v2", ".v3", ".v99"]:
		if FileAccess.file_exists(p + suffix):
			DirAccess.remove_absolute(p + suffix)
	return p


func test_round_trip_and_overwrite() -> void:
	var p := _path("a.json")
	var r := SaveFile.read(p)
	eq(r.settings, SaveFile.SETTINGS, "no file: default settings")
	eq(r.session, {}, "no file: no session")
	var s := SaveFile.SETTINGS.duplicate(true)
	s.room = "bar"
	s.master = 0.35
	s.language = "zh"
	s.sounds = {"toss": {"file": "user://sounds/toss.wav", "name": "x.wav", "volume": 1.5}}
	check(SaveFile.write(p, s, {"economy": {"cash": 1}}), "first write")
	s.room = "bingo"
	check(SaveFile.write(p, s, {"economy": {"cash": 2}}), "second write replaces the file")
	check(not FileAccess.file_exists(p + ".tmp"), "no temp file left behind")
	r = SaveFile.read(p)
	eq(r.settings.room, "bingo", "room")
	check(is_equal_approx(r.settings.master, 0.35), "volume")
	eq(r.settings.language, "zh", "language")
	eq(r.settings.sounds.toss.name, "x.wav", "sound replacement")
	eq(int(r.session.economy.cash), 2, "session")
	eq(r.note, "", "no complaint")
	var data = JSON.parse_string(FileAccess.get_file_as_string(p))
	eq(int(data.version), SaveFile.VERSION, "version number written")


func test_run_slot_and_version_1() -> void:
	var p := _path("r.json")
	var run := {"state": {"seed": "R-1", "layer": 1}, "session": {"economy": {"cash": 7}}}
	check(SaveFile.write(p, SaveFile.SETTINGS, {"economy": {"cash": 1}}, run), "write with a run")
	var r := SaveFile.read(p)
	eq(int(r.session.economy.cash), 1, "free play keeps its own session")
	eq(str(r.run.state.seed), "R-1", "the run beside it")
	eq(int(r.run.session.economy.cash), 7, "with its own table and money")
	# A version 1 file (the demo): free play carries over, there is no run, the mode is free.
	SaveFile.write_text(p, JSON.stringify({"version": 1, "settings": {"room": "bar"}, "session": {"economy": {"cash": 3}}}))
	r = SaveFile.read(p)
	eq(r.note, "", "version 1 reads without complaint")
	eq(r.settings.room, "bar", "settings kept")
	eq(r.settings.mode, "free", "opens in free play")
	eq(int(r.session.economy.cash), 3, "session kept")
	eq(r.run, {}, "no run")
	SaveFile.write_text(p, JSON.stringify({"version": 2, "settings": {"mode": "arcade"}, "session": {}, "run": []}))
	r = SaveFile.read(p)
	eq(r.settings.mode, "free", "an unknown mode falls back to free play")
	eq(r.run, {}, "a run that is not an object is dropped")


func test_bad_files_start_fresh() -> void:
	var p := _path("b.json")
	SaveFile.write_text(p, "{ not json")
	var r := SaveFile.read(p)
	eq(r.settings, SaveFile.SETTINGS, "unreadable: defaults")
	check(not FileAccess.file_exists(p) and FileAccess.file_exists(p + ".bad"), "unreadable file moved aside, not lost")
	check(r.note != "", "and reported")
	SaveFile.write_text(p, JSON.stringify({"version": 99, "settings": {"room": "bar"}, "session": {"x": 1}}))
	r = SaveFile.read(p)
	eq(r.settings.room, "diner", "newer build's save is not read")
	check(FileAccess.file_exists(p + ".v99") and not FileAccess.file_exists(p), "newer build's save kept aside")
	SaveFile.write_text(p, JSON.stringify({"version": 1, "settings": {"room": 5, "master": 7, "muted": "yes", "lamp": 2.0, "junk": 1}, "session": []}))
	r = SaveFile.read(p)
	eq(r.settings.room, "diner", "wrong type falls back to the default")
	check(is_equal_approx(r.settings.master, 1.0), "volume clamped to 0..1")
	eq(r.settings.muted, false, "a string is not a bool")
	eq(r.settings.lamp, 2, "whole float read as int")
	check(not r.settings.has("junk"), "unknown setting dropped")
	eq(r.session, {}, "a session that is not an object is dropped")


func _forms() -> Array:
	var pack := core_pack()
	return [] if pack == null else pack.forms


func _find(forms: Array) -> Callable:
	return func(uid: String) -> FormDef:
		for f in forms:
			if f.uid() == uid:
				return f
		return null


## Buys `n` tickets of column `i` the way the machine does.
func _buy(m: MachineLogic, e: Economy, tray: TicketTray, i: int, n: int) -> void:
	m.armed = n > 1
	m.press(i, e.credit)
	if n > 1:
		m.queue[0].n = n
	var t := 0.0
	while m.busy():
		t += 0.05
		m.step(0.05, t, e, tray)


func test_session_round_trip() -> void:
	var forms := _forms()
	if forms.is_empty():
		return
	var e := Economy.new()
	var m := MachineLogic.new(forms, "S-0001")
	var tray := TicketTray.new()
	e.insert(50)
	e.step_bill(Economy.BILL_TIME)
	_buy(m, e, tray, 0, 5)
	_buy(m, e, tray, 2, 4)
	# Open two: the first in the tray, then the next one is "in hand" unrevealed.
	var first: Dictionary = tray.take()
	e.open_ticket(first.ticket.prize)
	first.box.opened = first.ticket.no
	var hand: Dictionary = tray.take()
	e.take_loan()
	e.insert(10)
	e.step_bill(0.5)   # a bill half fed
	check(e.balanced(), "set-up balanced")
	var pile := {"opened": 1, "history": [first.form.uid()], "forms": [first.form.uid()]}
	var d := SessionState.capture(e, m, tray, hand, pile)
	eq(int(d.economy.credit), e.credit + 10, "the bill being fed is saved as credit")
	eq(d.tray.size(), 8, "hand plus seven in the tray")
	eq(d.tray[0].no, hand.ticket.no, "the ticket in hand goes back first")
	# Through the file, as the game does.
	var p := _path("s.json")
	SaveFile.write(p, SaveFile.SETTINGS, d)
	var back: Dictionary = SaveFile.read(p).session
	var e2 := Economy.new()
	var m2 := MachineLogic.new(forms, "OTHER")
	var tray2 := TicketTray.new()
	check(SessionState.restore(back, e2, m2, tray2, _find(forms)), "restores")
	check(e2.balanced(), "cash + credit = 200 + loans + won - spent after the reload")
	eq(e2.cash, e.cash, "cash")
	eq(e2.credit, e.credit + 10, "credit (bill landed)")
	for k in ["loans", "spent", "won", "opened", "wins"]:
		eq(e2.get(k), e.get(k), k)
	eq(e2.bill, 0, "no bill in flight")
	eq(m2.boxes[0].seed, "S-0001", "box seed")
	eq(m2.boxes[0].cursor, 5, "box progress")
	eq(m2.boxes[0].opened, first.ticket.no, "box opened")
	eq(m2.boxes[2].cursor, 4, "other box progress")
	eq(tray2.size(), 8, "tray size")
	eq(tray2.peek().ticket.serial, hand.ticket.serial, "hand ticket first")
	var serials := []
	for it in tray.items:
		serials.append(it.ticket.serial)
	var got := []
	for it in tray2.items.slice(1):
		got.append(it.ticket.serial)
	eq(got, serials, "tray in purchase order")
	check(tray2.items[1].box == m2.boxes[0], "tray tickets share the machine's box object")
	check(not m2.busy() and not m2.armed, "nothing queued or armed after a reload")


func test_session_keeps_sold_out_boxes_and_rejects_bad_money() -> void:
	var forms := _forms()
	if forms.is_empty():
		return
	var e := Economy.new()
	e.cash = 2000
	e.loans = 1800
	var m := MachineLogic.new(forms, "Z-0009")
	var tray := TicketTray.new()
	var size: int = m.boxes[0].size
	e.insert(100)
	e.step_bill(Economy.BILL_TIME)
	# Sell the first box to its last ticket, then one more step loads the next seed.
	m.boxes[0].cursor = size - 3
	_buy(m, e, tray, 0, 3)
	m.step(0.01, 99.0, e, tray)
	eq(m.boxes[0].seed, "Z-0010", "sold out: the next seed loads")
	var d := SessionState.capture(e, m, tray, {}, {})
	var e2 := Economy.new()
	var m2 := MachineLogic.new(forms, "Z-0009")
	var tray2 := TicketTray.new()
	check(SessionState.restore(d, e2, m2, tray2, _find(forms)), "restores")
	eq(tray2.size(), 3, "tickets from the sold-out box come back")
	eq(tray2.peek().box.seed, "Z-0009", "from their own box")
	eq(tray2.peek().ticket.serial, tray.peek().ticket.serial, "same ticket")
	check(is_equal_approx(m2.loaded[0], m.loaded[0]), "restocking box keeps its fill")
	# A ticket of a form that is gone is left out; it stays spent.
	d.tray[0].form = "gone:pack"
	tray2 = TicketTray.new()
	check(SessionState.restore(d, Economy.new(), MachineLogic.new(forms, "Z"), tray2, _find(forms)), "restores without the missing form")
	eq(tray2.size(), 2, "missing form's ticket dropped")
	# Money that does not add up is refused, and nothing changes.
	d.economy.cash += 1
	var e3 := Economy.new()
	var tray3 := TicketTray.new()
	check(not SessionState.restore(d, e3, MachineLogic.new(forms, "Z"), tray3, _find(forms)), "unbalanced money refused")
	eq(e3.cash, Economy.START_CASH, "economy untouched")
	eq(tray3.size(), 0, "tray untouched")
	check(not SessionState.restore({}, e3, MachineLogic.new(forms, "Z"), tray3, _find(forms)), "an empty session is refused")


func test_pile_cards_follow_landing_order() -> void:
	# add_card is what DiscardPile.land uses; the card count always matches the model.
	var forms: Array[String] = []
	var history: Array[String] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ok := true
	for n in 1200:
		var uid := "p:%d" % (n % 3)
		history.append(uid)
		PileModel.add_card(forms, history, n, uid, rng)
		ok = ok and forms.size() == PileModel.shown(n + 1) and forms[forms.size() - 1] == uid
	check(ok, "after every toss: one form per shown card, the newest on top")
