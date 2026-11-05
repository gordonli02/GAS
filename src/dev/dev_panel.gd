class_name DevPanel
extends CanvasLayer
## Developer panel, hidden from players: backquote toggles it in debug builds.
## After the web build's bench: switch tables, show a form's box and hand out a free
## ticket of it, open a new box from a seed, reset the tickets and money, the red
## buttons' lamp step, and per-sound file replacement and volume. Labels are Chinese
## (developer only), in the system's CJK font.

const WIDTH := 360.0
const INK := Color("#f1ead9")
const MUTED := Color("#a8a194")
const SIGNAL := Color("#d4242b")
const STICKER := Color("#f5f0e4")
const SLOT_LABELS := {
	"tear": "撕票整段（随手速切片）", "pop": "破孔第一下", "deal": "票到手上", "flip": "翻面",
	"toss": "丢票", "dispense": "出票机循环", "dispense_stop": "出票结束", "bill": "投钞",
	"button": "机器按钮", "win": "中奖",
}

var game: Game
var form_index := 0
var _font := SystemFont.new()
var _rooms := {}
var _forms: Array[Button] = []
var _lamps: Array[Button] = []
var _seed := LineEdit.new()
var _tiers := GridContainer.new()
var _facts := GridContainer.new()
var _slots := VBoxContainer.new()
var _dialog := FileDialog.new()
var _dialog_slot := ""
var _tick := 0.0


func _init() -> void:
	layer = 15
	visible = false


func _ready() -> void:
	_font.font_names = PackedStringArray(["Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "Noto Sans SC", "sans-serif"])
	var root := PanelContainer.new()
	root.theme = _theme()
	root.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	root.anchor_left = 1.0
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = -WIDTH - 16
	root.offset_right = -16
	root.offset_top = 16
	root.offset_bottom = -16
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#25232b")
	bg.border_color = Color("#4d4955")
	bg.set_border_width_all(1)
	bg.set_content_margin_all(14)
	bg.shadow_color = Color(0, 0, 0, 0.55)
	bg.shadow_size = 18
	root.add_theme_stylebox_override("panel", bg)
	add_child(root)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 14)   # room for the scroll bar
	scroll.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	pad.add_child(col)

	col.add_child(_sticker("Table", "桌面"))
	var rooms := _cols(col, 3)
	for id in RoomSet.ORDER:
		var b := _pick(RoomSet.ROOMS[id].name)
		b.pressed.connect(func(): game.set_room(id))
		rooms.add_child(b)
		_rooms[id] = b

	col.add_child(_sticker("Ticket", "票款"))
	var forms := _cols(col, 3)
	for i in game.machine.forms.size():
		var b := _pick(game.machine.forms[i].name)
		b.pressed.connect(func(): _pick_form(i))
		forms.add_child(b)
		_forms.append(b)

	col.add_child(_sticker("Deal", "这一盒"))
	var seed_row := HBoxContainer.new()
	_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed.max_length = 24
	_seed.add_theme_font_override("font", LcdStyle.FONT)
	_seed.add_theme_font_size_override("font_size", 22)
	_seed.add_theme_color_override("font_color", LcdStyle.LCD)
	_seed.text_submitted.connect(func(_t): _new_box())
	seed_row.add_child(_seed)
	var go := _plain("开新盒")
	go.pressed.connect(_new_box)
	seed_row.add_child(go)
	col.add_child(seed_row)
	_tiers.columns = 2
	_tiers.add_theme_constant_override("h_separation", 12)
	col.add_child(_tiers)
	_facts.columns = 2
	_facts.add_theme_constant_override("h_separation", 12)
	col.add_child(_facts)

	var reset := _plain("重置桌上的票和钱")
	var red := StyleBoxFlat.new()
	red.bg_color = SIGNAL
	red.set_content_margin_all(9)
	reset.add_theme_stylebox_override("normal", red)
	reset.add_theme_stylebox_override("hover", red)
	reset.pressed.connect(func(): game.dev_reset())
	col.add_child(reset)

	col.add_child(_sticker("Lamp", "红灯亮度"))
	var lamps := _cols(col, MachineView.LAMP_STEPS)
	for i in MachineView.LAMP_STEPS:
		var b := _pick(str(i + 1) + ("  最亮" if i == 0 else ""))
		b.pressed.connect(func(): game.set_lamp(i))
		lamps.add_child(b)
		_lamps.append(b)

	col.add_child(_sticker("Sound", "音效试听"))
	col.add_child(_slots)
	_dialog.use_native_dialog = true
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.filters = PackedStringArray(["*.wav, *.ogg, *.mp3 ; Audio"])
	_dialog.file_selected.connect(func(p: String): game.dev_sound_file(_dialog_slot, p); _draw_slots())
	add_child(_dialog)
	_draw_slots()


func toggle() -> void:
	visible = not visible
	if visible:
		_seed.text = game.machine.boxes[form_index].seed
		_refresh()
		_draw_slots()


func _process(dt: float) -> void:
	if not visible:
		return
	_tick += dt
	if _tick > 0.25:
		_tick = 0.0
		_refresh()


func _pick_form(i: int) -> void:
	form_index = i
	_seed.text = game.machine.boxes[i].seed
	game.dev_free_ticket(i)
	_refresh()


func _new_box() -> void:
	var s := _seed.text.strip_edges()
	game.dev_new_box(form_index, s if s != "" else Game.SEED)
	_seed.release_focus()
	_refresh()


func _refresh() -> void:
	for id in _rooms:
		_rooms[id].set_pressed_no_signal(id == game.rooms.id)
	for i in _forms.size():
		_forms[i].set_pressed_no_signal(i == form_index)
	for i in _lamps.size():
		_lamps[i].set_pressed_no_signal(i == MachineView.lamp_preset)
	var box: TicketBox = game.machine.boxes[form_index]
	var s := box.summary()
	for c in _tiers.get_children():
		c.queue_free()
	_cell(_tiers, "奖项", MUTED)
	_cell(_tiers, "剩 / 总", MUTED, true)
	for i in box.form.tiers.size():
		var t: Dictionary = box.form.tiers[i]
		var gone: bool = s.left[i] == 0
		var c := Color("#6f6a72") if gone else INK
		_cell(_tiers, "$%d %s" % [t.prize, _zh(t.label)], c)
		_cell(_tiers, "%d / %d" % [s.left[i], box.counts[i]], c, true)
	for c in _facts.get_children():
		c.queue_free()
	var serial := str(game.flow.ticket.serial) if game.flow.has_ticket() and game.flow.ticket.has("serial") else "-"
	var type: Dictionary = BoxModel.standard().type_by_id(box.type_id)
	var facts := [
		["本张序列号", serial],
		["这盒张数", "%s 张" % Hud._num(box.size)],
		["已开", "%s 张" % Hud._num(box.opened)],
		["已卖", "%s 张" % Hud._num(box.cursor)],
		["这盒类型", _zh(type.label) if not type.is_empty() else box.type_id],
		["买完整盒", ("+" if s.net > 0 else "-" if s.net < 0 else "") + Hud._money(absi(s.net))],
		["下一张期望", "$%.2f" % s.ev if s.remain > 0 else "已卖完"],
	]
	for f in facts:
		_cell(_facts, f[0], MUTED)
		_cell(_facts, f[1], INK, true)


func _draw_slots() -> void:
	for c in _slots.get_children():
		c.queue_free()
	var sounds: Dictionary = Save.setting("sounds")
	for slot in Sfx.SLOTS:
		var d: Dictionary = sounds.get(slot, {})
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var top := HBoxContainer.new()
		var name := Label.new()
		name.text = SLOT_LABELS[slot]
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name)
		var file := _plain("选文件")
		file.pressed.connect(func(): _dialog_slot = slot; _dialog.popup_file_dialog())
		var listen := _plain("听")
		listen.pressed.connect(func(): Sfx.audition(slot))
		var clear := _plain("清除")
		clear.disabled = not d.has("file")
		clear.pressed.connect(func(): game.dev_sound_clear(slot); _draw_slots())
		for b in [file, listen, clear]:
			top.add_child(b)
		row.add_child(top)
		var src := Label.new()
		src.text = str(d.get("name", "")) if d.has("file") else "内置录音"
		src.add_theme_color_override("font_color", MUTED)
		src.add_theme_font_size_override("font_size", 12)
		row.add_child(src)
		var vol := HSlider.new()
		vol.min_value = 0
		vol.max_value = 200
		vol.step = 5
		vol.value = float(d.get("volume", 1.0)) * 100.0
		vol.focus_mode = Control.FOCUS_NONE
		vol.value_changed.connect(func(v: float): game.dev_sound_volume(slot, v / 100.0))
		row.add_child(vol)
		var line := HSeparator.new()
		row.add_child(line)
		_slots.add_child(row)


static func _zh(text) -> String:
	if typeof(text) == TYPE_DICTIONARY:
		return str(text.get("zh", text.get("en", "")))
	return str(text)


func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = _font
	t.default_font_size = 14
	t.set_color("font_color", "Label", INK)
	var flat := func(c: Color, edge: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = c
		s.border_color = edge
		s.set_border_width_all(1)
		s.content_margin_left = 7
		s.content_margin_right = 7
		s.content_margin_top = 4
		s.content_margin_bottom = 4
		return s
	t.set_stylebox("normal", "Button", flat.call(Color("#111014"), Color("#45414e")))
	t.set_stylebox("hover", "Button", flat.call(Color("#1b1a20"), Color("#5a5566")))
	t.set_stylebox("pressed", "Button", flat.call(SIGNAL, Color("#ff8d7f")))
	t.set_stylebox("hover_pressed", "Button", flat.call(SIGNAL, Color("#ff8d7f")))
	t.set_stylebox("disabled", "Button", flat.call(Color("#111014"), Color("#2a2830")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(k, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color("#5d5862"))
	t.set_stylebox("normal", "LineEdit", flat.call(Color("#0d1205"), Color("#45414e")))
	t.set_stylebox("focus", "LineEdit", flat.call(Color("#0d1205"), Color("#ffbf47")))
	return t


func _sticker(en: String, zh: String) -> Control:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = STICKER
	s.border_color = SIGNAL
	s.set_border_width_all(2)
	s.set_content_margin_all(3)
	p.add_theme_stylebox_override("panel", s)
	var l := Label.new()
	l.text = en.to_upper() + "  " + zh
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", SIGNAL)
	l.add_theme_font_size_override("font_size", 13)
	p.add_child(l)
	return p


func _cols(parent: Container, n: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = n
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	parent.add_child(g)
	return g


func _pick(text: String) -> Button:
	var b := _plain(text)
	b.toggle_mode = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _plain(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return b


func _cell(g: GridContainer, text: String, color: Color, right := false) -> void:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_color_override("font_color", color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if right:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	g.add_child(l)
