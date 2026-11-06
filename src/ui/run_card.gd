class_name RunCard
extends CanvasLayer
## The run's card (story mode): the story beats, the choice each day (the machine or
## a shift of work), leaving for the day and the settlement when the run is over.
## Same plate and LCD look as the menu, under it. Shows what the game hands it and
## reports the key pressed; the game decides what a key does. While it is up, nothing
## reaches the table or the machine.
##
## Text arrives already translated (the game builds it with tr() and the numbers).
## Every card ends with a small MENU key (id "menu"): the card covers the HUD's.

signal picked(id: String)

const WIDTH := 560.0

var _title := LcdStyle.label("", 34)
var _body := VBoxContainer.new()
var _keys := VBoxContainer.new()
var _buttons := {}


func _init() -> void:
	layer = 15
	visible = false


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var plate := LcdStyle.plate()
	plate.custom_minimum_size = Vector2(WIDTH, 0)
	center.add_child(plate)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	plate.add_child(col)
	var head := LcdStyle.glass()
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	LcdStyle.menu_look(_title)
	head.add_child(_title)
	head.add_child(LcdStyle.grid_overlay())
	col.add_child(head)
	_body.add_theme_constant_override("separation", 4)
	col.add_child(_body)
	_keys.add_theme_constant_override("separation", 10)
	col.add_child(_keys)


## title: text. lines: each a text, or [text, style] with style "text" (default),
## "dim", "big" or "story" (wrapped prose). rows: rows of keys, each key
## {id, text, kind: "key" (lit green, default) or "chrome", disabled: bool}.
func show_card(title: String, lines: Array, rows: Array) -> void:
	_title.text = title
	for c in _body.get_children() + _keys.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	_buttons.clear()
	for line in lines:
		var text: String = line if line is String else line[0]
		var style: String = "text" if line is String else line[1]
		var l := LcdStyle.label(text, 30 if style == "big" else 24,
			LcdStyle.DIM_TEXT if style == "dim" else LcdStyle.BRIGHT_TEXT)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		LcdStyle.menu_look(l)
		if style == "story":
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(WIDTH - 40.0, 0)
		_body.add_child(l)
	for row in rows + [[{"id": "menu", "text": tr("MENU"), "kind": "chrome", "small": true}]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		_keys.add_child(h)
		for k in row:
			var chrome: bool = k.get("kind", "key") == "chrome"
			var small: bool = k.get("small", false)
			var b := LcdStyle.chrome(k.text, 18 if small else 20) if chrome else LcdStyle.key(k.text, 26)
			b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			b.custom_minimum_size = Vector2(0, 34 if small else 46)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.disabled = k.get("disabled", false)
			LcdStyle.menu_look(b)
			var id: String = k.id
			b.pressed.connect(func(): picked.emit(id))
			h.add_child(b)
			_buttons[id] = b
	visible = true


func hide_card() -> void:
	visible = false


## Tools and tests: a key on the card, or null.
func key(id: String) -> Button:
	return _buttons.get(id)


func title() -> String:
	return _title.text


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		Orphans.free_members(self, ["_title", "_body", "_keys"])
