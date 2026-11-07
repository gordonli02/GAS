class_name Hud
extends CanvasLayer
## Player HUD in the "refined LCD" style: a metal plate top left with the cash LCD
## and a one-line count, and the bill plate beside the machine's bill slot.
## The full ledger lives on the notepad on the table. Shows state only; the game
## wires the buttons. Player text is translation keys (auto-translated by the
## controls) or goes through tr(); it follows a language change straight away.

signal bill_pressed(value: int)
signal cash_out_pressed
signal phone_pressed       ## the phone (LOAN, and in the run the shop and contacts)
signal menu_pressed
signal leave_pressed       ## run: leave for today
signal new_box_pressed     ## run: change a column's box
signal open_pressed        ## run: open tickets at once (QUICK HANDS)

const TIP_WIDTH := 300.0      ## the item tip's lines wrap at this width

var _cash := LcdStyle.label("", 46)
var _status := LcdStyle.label("", 24)
var _cash_glass: PanelContainer
var _held := LcdStyle.label("0", 20, LcdStyle.BRIGHT_TEXT)
var _opened := LcdStyle.label("0", 20, LcdStyle.BRIGHT_TEXT)
var _net := LcdStyle.label("$0", 20, LcdStyle.BRIGHT_TEXT)
var _bills: Array[Button] = []
var _bill_values: Array = Economy.BILLS
var _run_line := LcdStyle.label("", 20, LcdStyle.BRIGHT_TEXT)
var _leave: Button
var _new_box: Button
var _open: Button
var _cash_out: Button
var _window: PanelContainer
var _arrow := Polygon2D.new()
var _flash := 0.0
var _status_key := ""
var _status_args := []
var menu_key: Button
var phone_key: Button
## The tip beside the pointer over an item's token in the tray: its name, what it does.
var _tip := PanelContainer.new()
var _tip_name := LcdStyle.label("", 22, LcdStyle.BRIGHT_TEXT)
var _tip_text := LcdStyle.label("", 20, LcdStyle.DIM_TEXT)


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
	_run_line.visible = false
	_run_line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	col.add_child(_run_line)
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 8)
	menu_key = LcdStyle.chrome("MENU", 18)
	phone_key = LcdStyle.chrome("PHONE", 18)
	phone_key.pressed.connect(func(): phone_pressed.emit())
	_leave = LcdStyle.chrome("LEAVE", 18)
	_leave.visible = false
	_leave.pressed.connect(func(): leave_pressed.emit())
	for b in [menu_key, phone_key, _leave]:
		b.custom_minimum_size = Vector2(0, 34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		keys.add_child(b)
	menu_key.pressed.connect(func(): menu_pressed.emit())
	col.add_child(keys)
	_open = LcdStyle.key("", 22)
	_open.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_open.custom_minimum_size = Vector2(0, 40)
	_open.visible = false
	_open.pressed.connect(func(): open_pressed.emit())
	col.add_child(_open)

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
	for i in Economy.BILLS.size():
		var b := LcdStyle.key("$%d" % Economy.BILLS[i], 30)
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.custom_minimum_size = Vector2(74, 74)
		b.pressed.connect(func(): bill_pressed.emit(_bill_values[i]))
		pad.add_child(b)
		_bills.append(b)
	var center := CenterContainer.new()
	center.add_child(pad)
	wv.add_child(center)
	# LOAN moved to the phone (M9); CASH OUT has the row to itself.
	_cash_out = LcdStyle.chrome("CASH OUT", 20)
	_cash_out.custom_minimum_size = Vector2(0, 44)
	_cash_out.pressed.connect(func(): cash_out_pressed.emit())
	wv.add_child(_cash_out)
	_new_box = LcdStyle.chrome("", 20)
	_new_box.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_new_box.toggle_mode = true
	_new_box.custom_minimum_size = Vector2(0, 44)
	_new_box.visible = false
	_new_box.pressed.connect(func(): new_box_pressed.emit())
	wv.add_child(_new_box)
	_window.add_child(wv)
	_arrow.color = LcdStyle.RIM
	_arrow.polygon = PackedVector2Array([Vector2(0, -12), Vector2(0, 12), Vector2(-16, 0)])
	_window.add_child(_arrow)

	var tip_style := StyleBoxFlat.new()
	tip_style.bg_color = LcdStyle.METAL
	tip_style.border_color = LcdStyle.RIM
	tip_style.set_border_width_all(2)
	tip_style.set_corner_radius_all(6)
	tip_style.set_content_margin_all(10)
	_tip.add_theme_stylebox_override("panel", tip_style)
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	var tip_lines := VBoxContainer.new()
	tip_lines.add_theme_constant_override("separation", 2)
	for l: Label in [_tip_name, _tip_text]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(TIP_WIDTH, 0)
		tip_lines.add_child(l)
	_tip.add_child(tip_lines)
	root.add_child(_tip)


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


## Bill plate: shown beside the slot; keys dark while a bill feeds or cash is short.
## change: {} in free play, else {fee, armed, ok} for NEW BOX.
func set_bill_window(show: bool, e: Economy, machine_busy: bool, change := {}) -> void:
	_window.visible = show
	if not show:
		return
	if _bill_values != e.bills:
		_bill_values = e.bills
		for i in _bills.size():
			_bills[i].text = "$%d" % _bill_values[i]
			LcdStyle.set_sizes(_bills[i], 30 if _bills[i].text.length() <= 4 else 24)
	for i in _bills.size():
		_bills[i].disabled = e.bill > 0 or e.cash < int(_bill_values[i])
	_cash_out.disabled = e.credit <= 0 or machine_busy
	_new_box.visible = not change.is_empty()
	if not change.is_empty():
		_new_box.text = tr("NEW BOX %s") % _money(change.fee)
		_new_box.set_pressed_no_signal(change.armed)
		_new_box.disabled = not change.ok


## Run, at the table: the key that opens tickets at once (QUICK HANDS). An empty text
## hides it.
func set_open(text: String, ok := true) -> void:
	_open.visible = text != ""
	_open.text = text
	_open.disabled = not ok


## Run (story mode): the line with what is due and the day, and the LEAVE key.
## An empty text hides both (free play).
func set_run(text: String, can_leave := false) -> void:
	_run_line.visible = text != ""
	_run_line.text = text
	_leave.visible = text != ""
	_leave.disabled = not can_leave


## Tools: the run keys.
func run_key(id: String) -> Button:
	match id:
		"leave":
			return _leave
		"open":
			return _open
	return _new_box


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


## The tip beside the pointer (an item's token): a name and the lines under it, already
## translated, below and right of `at` and kept on the screen; an empty name hides it.
## at (-1, -1) leaves it where it is.
func set_tip(title: String, text := "", at := Vector2(-1, -1)) -> void:
	_tip.visible = title != ""
	if title == "":
		return
	_tip_name.text = title
	_tip_text.text = text
	_tip.reset_size()
	if at.x < 0:
		return
	var screen := _tip.get_viewport_rect().size
	var s := _tip.get_combined_minimum_size()
	var p := at + Vector2(18, 22)
	if p.y + s.y > screen.y - 8.0:
		p.y = at.y - s.y - 12.0   # no room below the pointer: above it
	_tip.position = Vector2(clampf(p.x, 8.0, maxf(8.0, screen.x - s.x - 8.0)), maxf(8.0, p.y))


## Tests: the tip's name and text ("" when it is hidden).
func tip() -> Array:
	return [_tip_name.text, _tip_text.text] if _tip.visible else ["", ""]


static func _num(v: int) -> String:
	var s := str(v)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


static func _money(v: int) -> String:
	return "$" + _num(v)
