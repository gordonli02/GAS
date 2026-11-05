class_name Hud
extends CanvasLayer
## Player HUD in the "refined LCD" style: a metal plate top left with the cash LCD
## and a one-line count, and the bill plate beside the machine's bill slot.
## The full ledger lives on the notepad on the table. Shows state only; the game
## wires the buttons. Player text is translation keys (auto-translated by the
## controls) or goes through tr(); it follows a language change straight away.

signal bill_pressed(value: int)
signal cash_out_pressed
signal loan_pressed
signal menu_pressed

var _cash := LcdStyle.label("", 46)
var _status := LcdStyle.label("", 24)
var _cash_glass: PanelContainer
var _held := LcdStyle.label("0", 20, LcdStyle.BRIGHT_TEXT)
var _opened := LcdStyle.label("0", 20, LcdStyle.BRIGHT_TEXT)
var _net := LcdStyle.label("$0", 20, LcdStyle.BRIGHT_TEXT)
var _bills: Array[Button] = []
var _cash_out: Button
var _loan: Button
var _line := LcdStyle.label("", 20, LcdStyle.GREY_TEXT)
var _window: PanelContainer
var _arrow := Polygon2D.new()
var _flash := 0.0
var _status_key := ""
var _status_args := []
var menu_key: Button


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := LcdStyle.plate()
	top.position = Vector2(22, 22)
	top.custom_minimum_size = Vector2(300, 0)
	root.add_child(top)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	top.add_child(col)
	_cash_glass = LcdStyle.glass()
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", -4)
	lines.add_child(_cash)
	_status.modulate = Color(1, 1, 1, 0.85)
	lines.add_child(_status)
	_cash_glass.add_child(lines)
	_cash_glass.add_child(LcdStyle.grid_overlay())
	col.add_child(_cash_glass)
	var mini := HBoxContainer.new()
	mini.add_theme_constant_override("separation", 6)
	for pair in [["HELD", _held], ["OPENED", _opened], ["NET", _net]]:
		mini.add_child(LcdStyle.label(pair[0], 20, LcdStyle.DIM_TEXT))
		mini.add_child(pair[1])
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(8, 0)
		mini.add_child(gap)
	col.add_child(mini)
	menu_key = LcdStyle.chrome("MENU", 18)
	menu_key.custom_minimum_size = Vector2(0, 34)
	menu_key.pressed.connect(func(): menu_pressed.emit())
	col.add_child(menu_key)

	_window = LcdStyle.plate()
	_window.custom_minimum_size = Vector2(270, 0)
	_window.visible = false
	root.add_child(_window)
	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 14)
	var head := LcdStyle.glass()
	var head_lines := VBoxContainer.new()
	head_lines.add_theme_constant_override("separation", -6)
	head_lines.add_child(LcdStyle.label("INSERT BILL", 26))
	var nochange := LcdStyle.label("NO CHANGE GIVEN", 22)
	nochange.modulate = Color(1, 1, 1, 0.85)
	head_lines.add_child(nochange)
	head.add_child(head_lines)
	head.add_child(LcdStyle.grid_overlay())
	wv.add_child(head)
	var pad := GridContainer.new()
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 12)
	pad.add_theme_constant_override("v_separation", 12)
	for v in Economy.BILLS:
		var b := LcdStyle.key("$%d" % v, 30)
		b.custom_minimum_size = Vector2(74, 74)
		b.pressed.connect(func(): bill_pressed.emit(v))
		pad.add_child(b)
		_bills.append(b)
	var center := CenterContainer.new()
	center.add_child(pad)
	wv.add_child(center)
	var two := HBoxContainer.new()
	two.add_theme_constant_override("separation", 10)
	_cash_out = LcdStyle.chrome("CASH OUT", 20)
	_loan = LcdStyle.chrome("LOAN $200", 20)
	for b in [_cash_out, _loan]:
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		two.add_child(b)
	_cash_out.pressed.connect(func(): cash_out_pressed.emit())
	_loan.pressed.connect(func(): loan_pressed.emit())
	wv.add_child(two)
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wv.add_child(_line)
	_window.add_child(wv)
	_arrow.color = LcdStyle.RIM
	_arrow.polygon = PackedVector2Array([Vector2(0, -12), Vector2(0, 12), Vector2(-16, 0)])
	_window.add_child(_arrow)


func _process(dt: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - dt)
		# Four steps over 0.9 s, bright on the first and third.
		var step := int((0.9 - _flash) / 0.225)
		_cash_glass.self_modulate = Color(1.35, 1.35, 1.1) if step % 2 == 0 and _flash > 0.0 else Color.WHITE


func set_cash(cash: int) -> void:
	_cash.text = "$ %.2f" % cash


## The line under the cash: a translation key (with format args), or plain text
## such as a ticket number.
func set_status(key: String, args := []) -> void:
	_status_key = key
	_status_args = args
	_show_status()


func _show_status() -> void:
	var t := tr(_status_key)
	_status.text = tr("CASH") + " · " + (t % _status_args if not _status_args.is_empty() else t)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _status_key != "":
		_show_status()


func flash_win() -> void:
	_flash = 0.9


func set_ledger(held: int, e: Economy) -> void:
	_held.text = _num(held)
	_opened.text = _num(e.opened)
	var n := e.net()
	_net.text = ("+" if n > 0 else "-" if n < 0 else "") + _money(absi(n))


## Bill plate: shown beside the slot; keys dark while a bill feeds or cash is short;
## LOAN always there, dark once the house line is used up.
func set_bill_window(show: bool, e: Economy, machine_busy: bool) -> void:
	_window.visible = show
	if not show:
		return
	for i in _bills.size():
		_bills[i].disabled = e.bill > 0 or e.cash < Economy.BILLS[i]
	_cash_out.disabled = e.credit <= 0 or machine_busy
	_loan.disabled = not e.loan_available()
	_line.text = tr("HOUSE LINE %s LEFT") % _money(e.loan_left())


## Lines the plate up beside the machine: x right of the slot side, centred on the
## machine LCD's height, the arrow pointing at the slot.
func place_bill_window(side_x: float, slot_y: float, window_y: float, screen: Vector2) -> void:
	var w := _window.size.x
	var h := _window.size.y
	var x := clampf(side_x + 30.0, 16.0, screen.x - w - 16.0)
	var y := clampf(window_y - h / 2.0, 16.0, screen.y - h - 16.0)
	_window.position = Vector2(x, y)
	_arrow.position = Vector2(-2, clampf(slot_y - y, 24.0, h - 24.0))


func bill_window_visible() -> bool:
	return _window.visible


static func _num(v: int) -> String:
	var s := str(v)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


static func _money(v: int) -> String:
	return "$" + _num(v)
