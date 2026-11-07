class_name ItemPicker
extends CanvasLayer
## The item picker (M9.7): the item tray on the table opens it. The items held with
## their USE keys, on the run card's plate in the LCD look. It shows the very rows of
## the phone's ITEMS page (Game.items_state: one set of rules for USE and for the reason
## under a grey USE) and reports a USE pressed (acted, as the phone does); the game
## carries it out the phone's way (Game.use_item). BACK, Esc or a click beside the plate
## puts it away. While it is up nothing reaches the table, the machine or the card.

## use_item
signal acted(action: String, id: String)
signal closed

const WIDTH := 560.0
const ROW_H := 116.0       ## an item's rows, about: the list scrolls past what fits

var _title := LcdStyle.label("", 34)
var _head := VBoxContainer.new()
var _scroll := ScrollContainer.new()
var _list := VBoxContainer.new()
var _back := LcdStyle.chrome("", 20)
var _st := {}
var _buttons := {}
var _whys := {}


func _init() -> void:
	layer = 16
	visible = false


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close())
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var plate := LcdStyle.plate()
	plate.custom_minimum_size = Vector2(WIDTH, 0)
	center.add_child(plate)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	plate.add_child(col)
	var glass := LcdStyle.glass()
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	LcdStyle.menu_look(_title)
	glass.add_child(_title)
	glass.add_child(LcdStyle.grid_overlay())
	col.add_child(glass)
	_head.add_theme_constant_override("separation", 2)
	col.add_child(_head)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	_scroll.add_child(_list)
	_back.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_back.custom_minimum_size = Vector2(0, 40)
	LcdStyle.menu_look(_back)
	_back.pressed.connect(func():
		Sfx.play("button")
		close())
	col.add_child(_back)


## Opens with the items the game hands it (Game.items_state).
func open(st: Dictionary) -> void:
	_st = st
	visible = true
	_draw()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## New numbers from the game (after an item was used).
func show_state(st: Dictionary) -> void:
	_st = st
	if visible:
		_draw()


## Tools and tests: a key ("use_<item id>", "back"), or null.
func key(id: String) -> Button:
	if id == "back":
		return _back
	var b = _buttons.get(id)
	return b if is_instance_valid(b) else null


## Tests: the reason shown under an item ("" when none is).
func why(id: String) -> String:
	return str(_whys.get(id, ""))


## Tests: the item ids listed, in order.
func listed() -> Array:
	var out := []
	for it in _st.get("held", []):
		out.append(str(it.id))
	return out


func _draw() -> void:
	for c in _head.get_children() + _list.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	_buttons.clear()
	_whys.clear()
	_title.text = tr("ITEMS")
	_back.text = tr("BACK")
	_head.add_child(_label(str(_st.get("held_line", "")), 24, LcdStyle.BRIGHT_TEXT))
	if str(_st.get("use_line", "")) != "":
		_head.add_child(_wrapped(str(_st.use_line), 20, WIDTH - 40.0))
	var held: Array = _st.get("held", [])
	if held.is_empty():
		_head.add_child(_wrapped(tr("NONE HELD · THE PHONE'S SHOP HAS THEM"), 20, WIDTH - 40.0))
	for it in held:
		_list.add_child(_row(it))
	var room := (get_viewport().get_visible_rect().size.y if is_inside_tree() else 720.0) - 330.0
	_scroll.custom_minimum_size = Vector2(WIDTH - 36.0, clampf(held.size() * ROW_H, 0.0, maxf(room, ROW_H)))
	_scroll.visible = not held.is_empty()


## An item held: name, kind (its rarity's colour) and count; what it does; USE, and
## under a grey USE (or none) when and where it is used, as on the phone.
func _row(it: Dictionary) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	var name := _label(str(it.name), 26, LcdStyle.BRIGHT_TEXT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	var r := str(it.get("rarity_id", ""))
	top.add_child(_label(str(it.kind), 20, LcdStyle.BRIGHT_TEXT if r == "common" or r == "" else Phone.rarity_color(r)))
	top.add_child(_label(str(it.get("note", "")), 20, LcdStyle.DIM_TEXT))
	v.add_child(top)
	v.add_child(_wrapped(str(it.desc), 20, WIDTH - 60.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var id: String = it.id
	var can: bool = it.get("can_use", false)
	var use_text := str(it.get("use_text", ""))
	var why := str(it.get("why", ""))
	if why != "" and (use_text == "" or not can):
		var w := _wrapped(why, 18, WIDTH - 200.0)
		w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(w)
		_whys[id] = why
	else:
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(gap)
	if use_text != "":
		var u := LcdStyle.key(use_text, 22)
		u.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		u.custom_minimum_size = Vector2(120, 40)
		u.disabled = not can
		LcdStyle.menu_look(u)
		u.pressed.connect(func(): acted.emit("use_item", id))
		row.add_child(u)
		_buttons["use_" + id] = u
	v.add_child(row)
	return v


func _label(text: String, size: int, color: Color) -> Label:
	var l := LcdStyle.label(text, size, color)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	LcdStyle.menu_look(l)
	return l


func _wrapped(text: String, size: int, width: float) -> Label:
	var l := _label(text, size, LcdStyle.DIM_TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		Orphans.free_members(self, ["_title", "_head", "_scroll", "_list", "_back"])
