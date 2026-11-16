class_name Phone
extends CanvasLayer
## The player's phone, screen cracked (G's to-do list, item 10): the LOAN app in both
## modes; in the run also the SHOP (three pages: SHELF, the shelf's perks for sale and
## the build held; TODAY, the day's shelf: items and upgrade slots; ITEMS, the items held)
## and CONTACTS (calling the people in it; who they are and what they sell comes in
## M12, this is the shell).
## Opened by the PHONE key, P, the phone on the table or the PHONE key on the run's card.
##
## Like the run's card it shows what the game hands it (show_state) and reports what was
## pressed (acted); the game decides. Moving between apps happens in here. Text arrives
## translated, except the phone's own words (tr here). While it is up nothing reaches
## the table, the machine or the card behind it.

## loan, buy_perk, buy_upgrade, buy_item, use_item, buy_service
signal acted(action: String, id: String)
signal closed

const SCREEN := Vector2(380, 640)
const BG := Color("#0f171c")
const PANEL := Color("#1a252c")
const LINE := Color("#2a3a44")
const TEXT := Color("#e6eef2")
const DIM := Color("#8798a3")
const GOLD := Color("#e7a83a")
const GREEN := Color("#47c46b")
const BLUE := Color("#3d8fe8")
const RED := Color("#e0503e")
const APPS := {"loan": ["LOAN", GOLD], "shop": ["SHOP", GREEN], "contacts": ["CONTACTS", BLUE]}
const RING_TIME := 1.6          ## seconds of ringing before someone picks up (or nobody does)

var page := "home"               ## home, loan, shop, contacts, call
var shop_tab := "shelf"          ## shelf, today, items
var calling := ""                ## the contact being called
var call_state := ""             ## "ringing", "talking", "no_answer"
var _call_t := 0.0
var _st: Dictionary = {}
var _body: VBoxContainer
var _status_left: Label
var _status_right: Label
var _title: Label
var _back: Button
var _page: VBoxContainer
var _scroll: ScrollContainer
var _buttons := {}
var _rows := {}                  ## tools: the cards on the page by id (shelf_<perk>, build_<perk>, upgrade_<perk>)
var _shade := ColorRect.new()


func _init() -> void:
	layer = 18
	visible = false


func _ready() -> void:
	_shade.color = Color(0, 0, 0, 0.55)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close())
	add_child(_shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var body := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color("#16161a")
	bs.set_corner_radius_all(46)
	bs.border_color = Color("#3a3a42")
	bs.set_border_width_all(3)
	bs.content_margin_left = 16
	bs.content_margin_right = 16
	bs.content_margin_top = 14
	bs.content_margin_bottom = 12
	bs.shadow_color = Color(0, 0, 0, 0.6)
	bs.shadow_size = 24
	bs.shadow_offset = Vector2(0, 12)
	body.add_theme_stylebox_override("panel", bs)
	center.add_child(body)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 10)
	body.add_child(bv)
	var notch := CenterContainer.new()
	var speaker := Panel.new()
	speaker.custom_minimum_size = Vector2(70, 7)
	speaker.add_theme_stylebox_override("panel", _flat(Color("#2b2b33"), 4))
	notch.add_child(speaker)
	bv.add_child(notch)

	var screen := PanelContainer.new()
	screen.custom_minimum_size = SCREEN
	screen.clip_contents = true
	var ss := _flat(BG, 22)
	ss.set_content_margin_all(0)
	screen.add_theme_stylebox_override("panel", ss)
	bv.add_child(screen)
	var inner := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 14)
	screen.add_child(inner)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	inner.add_child(col)
	var bar := HBoxContainer.new()
	_status_left = _label("", 20, DIM)
	_status_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_right = _label("", 20, TEXT)
	bar.add_child(_status_left)
	bar.add_child(_status_right)
	col.add_child(bar)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_back = _button("<", PANEL, TEXT, 22)
	_back.custom_minimum_size = Vector2(44, 38)
	_back.pressed.connect(_go_back)
	head.add_child(_back)
	_title = _label("", 30, TEXT, LcdStyle.FONT_COND)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	col.add_child(head)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_scroll)
	_page = VBoxContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_constant_override("separation", 8)
	_scroll.add_child(_page)
	var cracks := _Cracks.new()
	cracks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(cracks)

	var home_row := CenterContainer.new()
	var home := _button("", Color("#24242b"), TEXT, 18)
	home.custom_minimum_size = Vector2(54, 54)
	home.add_theme_stylebox_override("normal", _ring(Color("#24242b")))
	home.add_theme_stylebox_override("hover", _ring(Color("#2c2c35")))
	home.add_theme_stylebox_override("pressed", _ring(Color("#3a3a44")))
	home.pressed.connect(_home_key)
	home_row.add_child(home)
	bv.add_child(home_row)
	_buttons["home"] = home
	_body = bv


func _process(dt: float) -> void:
	if not visible or page != "call" or call_state != "ringing":
		return
	_call_t += dt
	var c := _contact(calling)
	if _call_t >= (RING_TIME if c.get("answers", false) else RING_TIME * 1.6):
		call_state = "talking" if c.get("answers", false) else "no_answer"
		_draw_page()
	else:
		var dots := ".".repeat(1 + int(_call_t * 3.0) % 3)
		var l: Label = _page.get_node_or_null("ring")
		if l != null:
			l.text = tr("CALLING") + dots


## Opens on the home screen (or `app`) with the state the game hands it.
func open(st: Dictionary, app := "home") -> void:
	_st = st
	page = app if app == "home" or _has_app(app) else "home"
	calling = ""
	visible = true
	_fit()
	_draw_page()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## New numbers from the game (after something was bought or borrowed).
func show_state(st: Dictionary) -> void:
	_st = st
	if visible:
		_draw_page()


## Tools and tests: a key on the screen, or null.
func key(id: String) -> Button:
	var b = _buttons.get(id)
	return b if is_instance_valid(b) else null


## Tools: a card on the page (shelf_<perk id>, build_<perk id>, upgrade_<perk id>), or null.
func row(id: String) -> Control:
	var c = _rows.get(id)
	return c if is_instance_valid(c) else null


func go(app: String) -> void:
	page = app
	_draw_page()


# --- pages -------------------------------------------------------------------------

func _draw_page() -> void:
	for c in _page.get_children():
		_page.remove_child(c)
		c.queue_free()
	for k in _buttons.keys():
		if k != "home":
			_buttons.erase(k)
	_rows.clear()
	_status_left.text = str(_st.get("status", ""))
	_status_right.text = str(_st.get("cash", ""))
	_back.visible = page != "home"
	match page:
		"loan":
			_title.text = tr("LOAN")
			_loan_page()
		"shop":
			_title.text = tr("SHOP")
			_shop_page()
		"contacts":
			_title.text = tr("CONTACTS")
			_contacts_page()
		"call":
			_title.text = str(_contact(calling).get("name", ""))
			_call_page()
		_:
			_title.text = tr("PHONE")
			_home_page()


func _home_page() -> void:
	var big := _label(str(_st.get("headline", "")), 34, TEXT, LcdStyle.FONT_COND)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(big)
	var sub := _label(str(_st.get("subline", "")), 22, DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(sub)
	_gap(18)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 14)
	var center := CenterContainer.new()
	center.add_child(grid)
	_page.add_child(center)
	for id in APPS:
		if not _has_app(id):
			continue
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		var tile := _button("", APPS[id][1], TEXT, 18)
		tile.custom_minimum_size = Vector2(92, 92)
		tile.add_theme_stylebox_override("normal", _flat(APPS[id][1], 22))
		tile.add_theme_stylebox_override("hover", _flat(APPS[id][1].lightened(0.12), 22))
		tile.add_theme_stylebox_override("pressed", _flat(APPS[id][1].darkened(0.2), 22))
		var icon := _Icon.new()
		icon.kind = id
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		tile.add_child(icon)
		tile.pressed.connect(func(): _tap(); go(id))
		v.add_child(tile)
		var name := _label(tr(APPS[id][0]), 20, TEXT)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(name)
		grid.add_child(v)
		_buttons["app_" + id] = tile


func _loan_page() -> void:
	var loan: Dictionary = _st.get("loan", {})
	_page.add_child(_label(tr("HOUSE LINE LEFT"), 22, DIM))
	_page.add_child(_label(str(loan.get("left", "")), 52, GOLD, LcdStyle.FONT_COND))
	for line in loan.get("lines", []):
		var l := _label(str(line), 22, TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_page.add_child(l)
	_gap(10)
	var b := _button(str(loan.get("button", "")), GOLD, Color("#1c1406"), 26)
	b.custom_minimum_size = Vector2(0, 56)
	b.disabled = not loan.get("ok", false)
	b.pressed.connect(func(): acted.emit("loan", ""))
	_page.add_child(b)
	_buttons["loan"] = b


func _shop_page() -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	for t in [["shelf", "SHELF"], ["today", "TODAY"], ["items", "ITEMS"]]:
		var on: bool = shop_tab == t[0]
		var b := _button(tr(t[1]), GREEN if on else PANEL, Color("#08200f") if on else TEXT, 22)
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _tap(); shop_tab = t[0]; _draw_page())
		tabs.add_child(b)
		_buttons["tab_" + t[0]] = b
	_page.add_child(tabs)
	match shop_tab:
		"items":
			_items_tab()
		"today":
			_today_tab()
		_:
			_shelf_tab()


## SHELF: every perk of the shelf, in the catalog's order, each with its level, what it
## does now and next, its price, what it needs and a BUY key; then the build held (the
## dealt perks bought so far), to look at.
func _shelf_tab() -> void:
	for p in _st.get("shelf_perks", []):
		_perk_card(p, "shelf_", "buy_perk", GREEN if int(p.level) > 0 else DIM)
	var build: Array = _st.get("build", [])
	if build.is_empty():
		return
	_gap(4)
	_page.add_child(_label(str(_st.get("build_line", "")), 20, DIM))
	for p in build:
		var v := _card("build_" + str(p.id), str(p.name), str(p.get("kind", "")), _tint(str(p.get("rarity_id", ""))))
		for line in p.get("lines", []):
			var l := _label(str(line[0]) if line is Array else str(line), 20, DIM if line is Array else TEXT)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(l)


## A perk's card with its level, its lines and a BUY key: on SHELF (row shelf_<id>, key
## buy_perk_<id>) and in TODAY's upgrade slots (row upgrade_<id>, key buy_upgrade_<id>).
## `action` is what the key reports, and the key's id with the perk's after it.
func _perk_card(p: Dictionary, row_prefix: String, action: String, note_color: Color) -> void:
	var v := _card(row_prefix + str(p.id), str(p.name), "%d/%d" % [int(p.level), int(p.max)], note_color)
	for line in p.get("lines", []):
		var l := _label(str(line[0]) if line is Array else str(line), 20, DIM if line is Array else TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var buy: Dictionary = p.get("buy", {})
	if buy.is_empty():
		return
	var b := _button(str(buy.text), GREEN.darkened(0.55) if buy.ok else PANEL, TEXT if buy.ok else DIM, 20)
	b.custom_minimum_size = Vector2(0, 42)
	b.disabled = not buy.ok
	var id: String = p.id
	b.pressed.connect(func(): _tap(); acted.emit(action, id))
	v.add_child(b)
	_buttons[action + "_" + id] = b


## TODAY: today's shelf (BUY; it is not rerolled): the items, then the upgrade slots (a
## level of a dealt perk held, each; gone once bought; nothing shown on a day with none).
## A round of perk offers is only on its card (M9.8 step 2), so it is not here.
func _today_tab() -> void:
	_page.add_child(_label(str(_st.get("shelf_line", "")), 20, DIM))
	for it in _st.get("shelf", []):
		_page.add_child(_item_card(it, false))
	var ups: Array = _st.get("upgrades", [])
	if ups.is_empty():
		return
	_gap(4)
	_page.add_child(_label(str(_st.get("upgrades_line", "")), 20, DIM))
	for p in ups:
		_perk_card(p, "upgrade_", "buy_upgrade", _tint(str(p.get("rarity_id", ""))))


## A card on the page with its name and a note at the top right; returns the column the
## rest goes in.
func _card(id: String, head: String, note: String, note_color: Color) -> VBoxContainer:
	var card := PanelContainer.new()
	var cs := _flat(PANEL, 12)
	cs.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", cs)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var top := HBoxContainer.new()
	var n := _label(head, 24, TEXT, LcdStyle.FONT_COND)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(n)
	top.add_child(_label(note, 18, note_color))
	v.add_child(top)
	_page.add_child(card)
	_rows[id] = card
	return v


## A perk's kind in its rarity's colour; common in the plain text colour.
func _tint(r: String) -> Color:
	return TEXT if r == "common" or r == "" else rarity_color(r)


func _rarity_color(r: String) -> Color:
	return rarity_color(r)


## A rarity's colour (the phone's shop, the card of offers): gold, blue, or the dim
## text for common.
static func rarity_color(r: String) -> Color:
	match r:
		"legendary":
			return GOLD
		"rare":
			return BLUE
	return DIM


## ITEMS: what is held, with USE where it is used by hand (today's shelf is on TODAY),
## and under the count how items are used when something is held (G could not find it).
func _items_tab() -> void:
	_page.add_child(_label(str(_st.get("held_line", "")), 20, DIM))
	if str(_st.get("use_line", "")) != "":
		var how := _label(str(_st.use_line), 18, DIM)
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_page.add_child(how)
	for it in _st.get("held", []):
		_page.add_child(_item_card(it, true))


func _item_card(it: Dictionary, held: bool) -> PanelContainer:
	var card := PanelContainer.new()
	var cs := _flat(PANEL, 12)
	cs.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", cs)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var top := HBoxContainer.new()
	var name := _label(str(it.name), 24, TEXT, LcdStyle.FONT_COND)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	top.add_child(_label(str(it.kind), 18, _rarity_color(str(it.get("rarity_id", ""))) if not held else GREEN))
	v.add_child(top)
	var desc := _label(str(it.desc), 20, DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var note := _label(str(it.get("note", "")), 22, TEXT)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(note)
	var id: String = it.id
	if held:
		if it.get("use_text", "") != "":
			var u := _button(str(it.use_text), BLUE, TEXT, 20)
			u.custom_minimum_size = Vector2(84, 40)
			u.disabled = not it.can_use
			u.pressed.connect(func(): acted.emit("use_item", id))
			row.add_child(u)
			_buttons["use_" + id] = u
	else:
		var b := _button(str(it.buy_text), GREEN, Color("#08200f"), 20)
		b.custom_minimum_size = Vector2(96, 40)
		b.disabled = not it.can_buy
		b.pressed.connect(func(): acted.emit("buy_item", id))
		row.add_child(b)
		_buttons["buy_" + id] = b
	v.add_child(row)
	# A held item that cannot be used now, or has no USE key: when and where it is (`why`).
	if held and str(it.get("why", "")) != "" and (str(it.get("use_text", "")) == "" or not it.get("can_use", false)):
		var why := _label(str(it.why), 18, DIM)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(why)
	return card


func _contacts_page() -> void:
	for c in _st.get("contacts", []):
		var b := _button("", PANEL, TEXT, 18)
		b.custom_minimum_size = Vector2(0, 64)
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 10
		h.add_theme_constant_override("separation", 12)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var face := _Avatar.new()
		face.letter = str(c.name).left(1)
		face.custom_minimum_size = Vector2(44, 44)
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(face)
		var n := _label(str(c.name), 24, TEXT, LcdStyle.FONT_COND)
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(n)
		b.add_child(h)
		var id: String = c.id
		b.pressed.connect(func(): _tap(); call_contact(id))
		_page.add_child(b)
		_buttons["contact_" + id] = b


## Rings a contact; after a while they pick up (and say their piece, and offer what
## they sell) or nobody does.
func call_contact(id: String) -> void:
	calling = id
	call_state = "ringing"
	_call_t = 0.0
	page = "call"
	_draw_page()


func _call_page() -> void:
	var c := _contact(calling)
	_gap(16)
	var face := _Avatar.new()
	face.letter = str(c.get("name", "?")).left(1)
	face.custom_minimum_size = Vector2(96, 96)
	var fc := CenterContainer.new()
	fc.add_child(face)
	_page.add_child(fc)
	var state := _label("", 24, DIM)
	state.name = "ring"
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(state)
	match call_state:
		"ringing":
			state.text = tr("CALLING") + "."
		"no_answer":
			state.text = tr("NO ANSWER")
			_say(str(c.get("line", "")))
		_:
			state.text = tr("ON THE LINE")
			state.add_theme_color_override("font_color", GREEN)
			_say(str(c.get("line", "")))
			for s in c.get("services", []):
				var card := PanelContainer.new()
				var cs := _flat(PANEL, 12)
				cs.set_content_margin_all(10)
				card.add_theme_stylebox_override("panel", cs)
				var v := VBoxContainer.new()
				card.add_child(v)
				v.add_child(_label(str(s.name), 24, TEXT, LcdStyle.FONT_COND))
				var d := _label(str(s.desc), 20, DIM)
				d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				v.add_child(d)
				var b := _button(str(s.button), GREEN, Color("#08200f"), 22)
				b.custom_minimum_size = Vector2(0, 44)
				b.disabled = not s.can
				var sid: String = s.id
				b.pressed.connect(func(): acted.emit("buy_service", sid))
				v.add_child(b)
				_buttons["service_" + sid] = b
				_page.add_child(card)
	_gap(8)
	var hang := _button(tr("HANG UP"), RED, TEXT, 24)
	hang.custom_minimum_size = Vector2(0, 50)
	hang.pressed.connect(func(): _tap(); go("contacts"))
	_page.add_child(hang)
	_buttons["hang_up"] = hang


func _say(text: String) -> void:
	var l := _label(text, 22, TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.add_child(l)


func _go_back() -> void:
	_tap()
	go("contacts" if page == "call" else "home")


func _home_key() -> void:
	_tap()
	if page == "home":
		close()
	else:
		go("home")


func _has_app(id: String) -> bool:
	return id == "loan" or (id in ["shop", "contacts"] and _st.get("run", false))


func _contact(id: String) -> Dictionary:
	for c in _st.get("contacts", []):
		if c.id == id:
			return c
	return {}


func _tap() -> void:
	Sfx.play("button")


## Smaller windows: the phone shrinks to fit their height.
func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := minf(1.0, vp.y / 860.0)
	scale = Vector2(s, s)
	offset = vp * (1.0 - s) / 2.0


# --- bits --------------------------------------------------------------------------

func _gap(h: float) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	_page.add_child(c)


func _label(text: String, size: int, color: Color, font: Font = LcdStyle.FONT) -> Label:
	var l := LcdStyle.label(text, size, color, font)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	LcdStyle.menu_look(l, false, size)
	return l


func _button(text: String, fill: Color, ink: Color, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.add_theme_font_override("font", LcdStyle.FONT_COND)
	LcdStyle.set_sizes(b, size)
	LcdStyle.menu_look(b, false, size)
	b.add_theme_stylebox_override("normal", _flat(fill, 10))
	b.add_theme_stylebox_override("hover", _flat(fill.lightened(0.1), 10))
	b.add_theme_stylebox_override("pressed", _flat(fill.darkened(0.2), 10))
	b.add_theme_stylebox_override("disabled", _flat(fill.darkened(0.55), 10))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, ink)
	b.add_theme_color_override("font_disabled_color", Color(ink, 0.35) if ink.v > 0.5 else Color(TEXT, 0.3))
	return b


static func _flat(c: Color, r: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(r)
	s.set_content_margin_all(6)
	return s


static func _ring(c: Color) -> StyleBoxFlat:
	var s := _flat(c, 27)
	s.border_color = Color("#4a4a55")
	s.set_border_width_all(2)
	return s


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		Orphans.free_members(self, ["_shade"])


## The crack: a web of white lines from a knock near the top right corner of the glass.
class _Cracks extends Control:
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7311
		var o := Vector2(size.x * 0.78, size.y * 0.12)
		var ring_r := [18.0, 38.0, 64.0]
		var ends: Array = []
		for k in 11:
			var a := TAU * k / 11.0 + rng.randf_range(-0.2, 0.2)
			var len := rng.randf_range(90.0, 420.0)
			var pts := PackedVector2Array([o])
			var p := o
			var steps := 6
			for s in steps:
				p += Vector2.from_angle(a + rng.randf_range(-0.35, 0.35)) * len / steps
				pts.append(p)
			draw_polyline(pts, Color(1, 1, 1, 0.42), 1.4, true)
			draw_polyline(pts, Color(1, 1, 1, 0.12), 3.5, true)
			ends.append(pts)
		for r in ring_r:
			var pts := PackedVector2Array()
			for k in 12:
				pts.append(o + Vector2.from_angle(TAU * k / 11.0 + rng.randf_range(-0.1, 0.1)) * r * rng.randf_range(0.8, 1.2))
			draw_polyline(pts, Color(1, 1, 1, 0.3), 1.2, true)
		draw_circle(o, 5.0, Color(1, 1, 1, 0.5))


## An app's picture on its tile, drawn: a coin, a shopping bag, a handset.
class _Icon extends Control:
	var kind := ""

	func _draw() -> void:
		var c := size / 2.0
		var ink := Color(1, 1, 1, 0.95)
		match kind:
			"loan":
				draw_circle(c, 26.0, ink, false, 4.0, true)
				var font := LcdStyle.FONT_COND
				draw_string(font, c + Vector2(-11, 13), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, ink)
			"shop":
				var r := Rect2(c + Vector2(-22, -12), Vector2(44, 36))
				draw_rect(r, ink, false, 4.0)
				draw_arc(c + Vector2(0, -12), 12.0, PI, TAU, 16, ink, 4.0, true)
			"contacts":
				draw_arc(c, 22.0, PI * 0.75, PI * 1.75, 20, ink, 9.0, true)
				draw_circle(c + Vector2.from_angle(PI * 0.75) * 22.0, 8.0, ink)
				draw_circle(c + Vector2.from_angle(PI * 1.75) * 22.0, 8.0, ink)


## A contact's picture: a coloured disc with the first letter of the name.
class _Avatar extends Control:
	var letter := "?"

	func _draw() -> void:
		var r := minf(size.x, size.y) / 2.0
		draw_circle(size / 2.0, r, Color("#4a5a66"))
		var font := LcdStyle.FONT_COND
		var fs := int(r * 1.1)
		var w := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, size / 2.0 + Vector2(-w / 2.0, fs * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#e6eef2"))
