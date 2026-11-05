class_name Game
extends Node3D
## The game: table, machine, money, tray, discard pile and the camera between them.
## Milestone 4 uses a plain grey room; the three rooms come in milestone 5.
## Rules: MIGRATION.md "Money", "Machine", "Table and machine navigation", "Bill window".

const SEED := "G-0001"
const FORM_UIDS := ["core:catch", "core:plate", "core:spur"]
## Where the machine stands (the Diner's placement from the web build's scenes config).
const MACHINE_POS := Vector3(10.8, -3.25, -13)
const MACHINE_YAW := -0.35
const UI_TICK := 0.09
const MESSAGE_TIME := 1.6

var painter := TicketPainter.new()
var camera := CameraRig.new()
var view := TicketView.new()
var flecks := Flecks.new()
var flow := TicketFlow.new()
var table_tray := TableTray.new()
var pile := DiscardPile.new()
var machine_view := MachineView.new()
var hud := Hud.new()
var notepad := Notepad.new()
var input := GameInput.new()

var economy := Economy.new()
var machine: MachineLogic
var tray := TicketTray.new()
var at_machine := true
var current: Dictionary = {}       ## tray entry of the ticket in hand
var _go_machine := false            ## after this toss, go to the machine instead of dealing
var _time := 0.0
var _ui_at := 0.0
var _msg := ""
var _msg_until := 0.0
var _ready_done := false


func _ready() -> void:
	add_child(painter)
	_build_room()
	add_child(camera)
	camera.current = true
	view.painter = painter
	view.visible = false
	add_child(view)
	add_child(flecks)
	add_child(table_tray)
	pile.painter = painter
	add_child(pile)
	notepad.painter = painter
	add_child(notepad)
	add_child(hud)

	var forms: Array = []
	for uid in FORM_UIDS:
		forms.append(Packs.form(uid))
	machine = MachineLogic.new(forms, SEED)
	machine_view.painter = painter
	machine_view.position = MACHINE_POS
	machine_view.rotation.y = MACHINE_YAW
	add_child(machine_view)
	await machine_view.build(forms)
	var light := OmniLight3D.new()
	light.light_color = Color("#fff0e0")
	light.light_energy = 0.8
	light.omni_range = 22.0
	light.position = MACHINE_POS + Vector3(-3.5, 5, 6)
	add_child(light)
	camera.set_machine(machine_view, MACHINE_POS, MACHINE_YAW)
	camera.at_machine = true
	camera.cam = 1.0

	flow.camera = camera
	flow.view = view
	flow.flecks = flecks
	flow.tray = table_tray
	flow.pile = pile
	flow.next_ticket = _take_ticket
	flow.deal_after_toss = _deal_after_toss
	flow.dealt.connect(_on_dealt)
	flow.revealed.connect(_on_revealed)
	add_child(flow)
	input.game = self
	add_child(input)
	hud.bill_pressed.connect(insert_bill)
	hud.cash_out_pressed.connect(cash_out)
	hud.loan_pressed.connect(take_loan)
	get_viewport().size_changed.connect(_place_tray_and_pile)
	_place_tray_and_pile()
	hud.set_status(tr("READY"))
	_ready_done = true


# --- actions --------------------------------------------------------------------

## A machine button: 0-2 columns, 3 PLAY ALL. Keys 1-3 and Space press the same buttons.
func press_machine(i: int) -> void:
	Sfx.play("button")
	machine_view.press_button(i)
	machine.return_at = 0.0
	var r := machine.press_play_all(economy.credit) if i == 3 else machine.press(i, economy.credit)
	if r == "insert_bill":
		say(tr("INSERT BILL"))


func insert_bill(value: int) -> void:
	if not at_machine or not economy.insert(value):
		return
	hud.set_cash(economy.cash)


func cash_out() -> void:
	if machine.busy() or economy.credit <= 0:
		return
	economy.cash_out()
	machine.armed = false
	Sfx.play("toss")


func take_loan() -> void:
	if not economy.take_loan():
		return
	Sfx.play("toss")
	hud.set_status(tr("HOUSE LOAN"))


## Space / Enter.
func primary() -> void:
	if at_machine:
		if economy.credit >= 1:
			press_machine(3)
		elif not tray.is_empty():
			toggle_view()
		else:
			say(tr("INSERT BILL"))
		return
	if flow.state == TicketFlow.State.IDLE and tray.is_empty():
		open_machine()
		return
	flow.primary()


## B and the view button.
func toggle_view() -> void:
	if at_machine:
		if machine.busy() or economy.bill > 0:
			return
		close_machine()
		if flow.state == TicketFlow.State.IDLE and not tray.is_empty():
			flow.deal()
		else:
			hud.set_status(tr("READY"))
		return
	_leave_table(false)


## The player clicked the machine from the table.
func leave_for_machine() -> void:
	_leave_table(true)


func _leave_table(machine_click: bool) -> void:
	match TableNav.leave(flow.hand(), flow.has_band(), view.band_on, view.any_torn(), machine_click):
		TableNav.Action.GO:
			open_machine()
		TableNav.Action.RETURN_THEN_GO:
			flow.cancel()
			tray.put_back(current)
			current = {}
			open_machine()
		TableNav.Action.DISCARD_THEN_GO:
			_go_machine = true
			flow.collect()


func open_machine() -> void:
	at_machine = true
	camera.at_machine = true
	machine.return_at = 0.0
	hud.set_status(tr("ONE MORE?"))


func close_machine() -> void:
	at_machine = false
	camera.at_machine = false
	machine.return_at = 0.0
	machine.armed = false


func say(text: String) -> void:
	_msg = text
	_msg_until = _time + MESSAGE_TIME


# --- ticket flow hooks ------------------------------------------------------------

func _take_ticket() -> Dictionary:
	if tray.is_empty():
		return {}
	current = tray.take()
	return current


func _deal_after_toss() -> bool:
	if _go_machine:
		_go_machine = false
		open_machine()
		return false
	return true


func _on_dealt(t: Dictionary, _form: FormDef) -> void:
	hud.set_status(str(t.no).pad_zeros(5))


func _on_revealed(t: Dictionary, _form: FormDef) -> void:
	economy.open_ticket(t.prize)
	if current.has("box"):
		current.box.opened = t.no
	if t.prize > 0:
		hud.set_status(tr("WINNER $%d") % t.prize)
		hud.flash_win()
	else:
		hud.set_status(tr("NO WIN"))


# --- frame ----------------------------------------------------------------------

func _process(dt: float) -> void:
	if not _ready_done:
		return
	_time += dt
	var bill := economy.bill
	var ev := economy.step_bill(dt)
	if ev.get("sound", false):
		Sfx.play("bill")
	machine_view.show_bill(economy.bill if economy.bill > 0 else 0, economy.bill_t)
	if bill > 0 and economy.bill == 0:
		machine_view.show_bill(0, 0.0)
	var m := machine.step(dt, _time, economy, tray)
	Sfx.motor(m.motor)
	for s in m.sold:
		machine_view.launch_card()
	if m.stopped:
		Sfx.play("dispense_stop")
	if at_machine and machine.return_at > 0.0 and _time > machine.return_at and not tray.is_empty():
		toggle_view()
	# PLAY ALL blinks only while you stand at the machine; from the table it stays lit.
	machine_view.set_blink(not at_machine or sin(_time * 4.0) > 0.0)
	if _time - _ui_at > UI_TICK:
		_ui_at = _time
		_refresh_ui()
	_place_bill_window()


func _refresh_ui() -> void:
	hud.set_cash(economy.cash)
	hud.set_ledger(tray.size(), economy)
	var n := economy.net()
	notepad.show_ledger([
		tr("OPENED %s") % Hud._num(economy.opened),
		tr("WINS %s") % Hud._num(economy.wins),
		tr("SPENT %s") % Hud._money(economy.spent),
		tr("WON %s") % Hud._money(economy.won),
		tr("NET %s") % (("+" if n > 0 else "-" if n < 0 else "") + Hud._money(absi(n))),
	])
	var sub := tr("READING BILL") if economy.bill > 0 \
		else (tr("PLAYALL") if sin(_time * 7.0) > -0.4 else "") if machine.armed \
		else _msg if _time < _msg_until \
		else tr("SELECT A TICKET") if economy.credit >= 1 else tr("INSERT BILL")
	machine_view.set_lcd("$ %7.2f %s" % [economy.credit, tr("CREDIT")], sub)
	var shares := []
	for i in machine.boxes.size():
		shares.append(float(machine.stock_left(i)) / machine.boxes[i].size)
	machine_view.set_stock(shares)
	var next := tray.peek()
	var art: Texture2D = null
	var card := Vector2(1.4, 2.0)
	if not next.is_empty():
		art = pile.cached_art(next.form)
		var s: Array = next.form.layout.card.size
		card = Vector2(s[0], s[1])
	table_tray.set_stack(tray.size(), art, card)
	machine_view.set_tray(tray.size(), art, card)
	hud.set_bill_window(at_machine and camera.cam > 0.97, economy, machine.busy())


func _place_bill_window() -> void:
	if not hud.bill_window_visible():
		return
	var side := camera.unproject_position(machine_view.anchor("side"))
	var slot := camera.unproject_position(machine_view.anchor("slot"))
	var win := camera.unproject_position(machine_view.anchor("window"))
	hud.place_bill_window(side.x, slot.y, win.y, get_viewport().get_visible_rect().size)


# --- scene ------------------------------------------------------------------------

func _build_room() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2b2d33")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff0dc")
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := SpotLight3D.new()
	key.position = Vector3(2, 13, 5)
	key.look_at_from_position(key.position, Vector3.ZERO)
	key.spot_range = 25.0
	key.spot_angle = rad_to_deg(PI / 2.9)
	key.spot_angle_attenuation = 0.6
	key.light_energy = 1.4
	key.shadow_enabled = true
	key.shadow_reverse_cull_face = true
	key.shadow_bias = 0.02
	key.shadow_normal_bias = 0.5
	add_child(key)
	_solid(Vector3(15, 0.4, 12.5), Vector3(0, -0.2, 0), Color("#8b8b90"))   # table top
	_solid(Vector3(0.9, 7.6, 0.9), Vector3(0, -4.2, 0), Color("#55555a"))   # pedestal
	_solid(Vector3(90, 0.2, 90), Vector3(0, -8.1, -10), Color("#3a3c42"))   # floor


## A plain block that also stops clicks (so clicks respect what is in front).
func _solid(size: Vector3, at: Vector3, c: Color) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.9
	m.material_override = mat
	m.position = at
	add_child(m)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	m.add_child(body)


func _place_tray_and_pile() -> void:
	var sx := minf(5.3, camera.table_half_width() * 0.72)
	table_tray.position = Vector3(sx - 0.05, 0, 1.2)
	table_tray.rotation = Vector3(0, -0.12, 0)
	pile.position = Vector3(-sx, 0, 1.25)
	# The notepad lies in front of the pile, toward the player, clear of the held ticket.
	notepad.position = Vector3(-sx * 0.6, 0, 2.6)
	notepad.rotation = Vector3(0, 0.18, 0)
