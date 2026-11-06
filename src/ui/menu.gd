class_name Menu
extends CanvasLayer
## Player menu (Esc or the MENU key): mode (free play or the story's run), table,
## volume, sound, full screen, tickets back side up, language, resume and quit. Same plate and LCD look as the HUD; layout after the web build's
## menu. Shows state only; the game applies the choices.

signal mode_picked(id: String)   ## "free" / "run"
signal new_run_pressed           ## give the run up and start another (pressed twice)
signal room_picked(id: String)
signal volume_changed(linear: float)
signal mute_toggled
signal fullscreen_toggled
signal back_first_toggled        ## tickets come to the hand back side up
signal language_picked(code: String)
signal quit_pressed

const ROOMS := [["diner", "DINER"], ["bar", "BAR"], ["bingo", "BINGO"]]
const MODES := [["free", "FREE PLAY"], ["run", "STORY"]]

var _modes := {}
var _new_run: Button
var _sure := false
var _rooms := {}
var _langs := {}
var _volume := HSlider.new()
var _sound: Button
var _full: Button
var _back: Button
var _resume: Button
var _quit: Button
var _shade := ColorRect.new()


func _init() -> void:
	layer = 20
	visible = false


func _ready() -> void:
	_shade.color = Color(0, 0, 0, 0.66)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.gui_input.connect(_on_shade_input)
	add_child(_shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var plate := LcdStyle.plate()
	plate.custom_minimum_size = Vector2(400, 0)
	center.add_child(plate)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	plate.add_child(col)

	var head := LcdStyle.glass()
	head.add_child(LcdStyle.label("MENU", 38))
	head.add_child(LcdStyle.grid_overlay())
	col.add_child(head)

	col.add_child(_caption("MODE"))
	var modes := _row(col)
	for m in MODES:
		var b := _toggle_key(m[1])
		b.pressed.connect(func(): mode_picked.emit(m[0]))
		modes.add_child(b)
		_modes[m[0]] = b
	_new_run = LcdStyle.chrome("NEW RUN", 20)
	_new_run.custom_minimum_size = Vector2(0, 40)
	_new_run.pressed.connect(_on_new_run)
	col.add_child(_new_run)

	col.add_child(_caption("TABLE"))
	var rooms := _row(col)
	for r in ROOMS:
		var b := _toggle_key(r[1])
		b.pressed.connect(func(): room_picked.emit(r[0]))
		rooms.add_child(b)
		_rooms[r[0]] = b

	col.add_child(_caption("VOLUME"))
	LcdStyle.style_slider(_volume)
	_volume.min_value = 0
	_volume.max_value = 100
	_volume.step = 5
	_volume.custom_minimum_size = Vector2(0, 30)
	_volume.value_changed.connect(func(v: float): volume_changed.emit(v / 100.0))
	col.add_child(_volume)

	var two := _row(col)
	_sound = _toggle_key("SOUND")
	_sound.pressed.connect(func(): mute_toggled.emit())
	_full = _toggle_key("FULLSCREEN")
	_full.pressed.connect(func(): fullscreen_toggled.emit())
	two.add_child(_sound)
	two.add_child(_full)
	_back = _toggle_key("TICKETS BACK SIDE UP")
	_back.pressed.connect(func(): back_first_toggled.emit())
	_row(col).add_child(_back)

	col.add_child(_caption("LANGUAGE"))
	var langs := _row(col)
	for code in Lang.LANGUAGES:
		var b := _toggle_key(Lang.NAMES[code])
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.pressed.connect(func(): language_picked.emit(code))
		langs.add_child(b)
		_langs[code] = b

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	col.add_child(gap)
	var last := _row(col)
	_resume = LcdStyle.key("RESUME", 26)
	_resume.custom_minimum_size = Vector2(0, 48)
	_resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resume.pressed.connect(close)
	_quit = LcdStyle.chrome("QUIT", 20)
	_quit.custom_minimum_size = Vector2(0, 48)
	_quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quit.pressed.connect(func(): quit_pressed.emit())
	last.add_child(_resume)
	last.add_child(_quit)
	# Chinese in the menu keeps the larger look; 继续 in bold, at the size 退出 gets.
	for c in plate.find_children("*", "Control", true, false):
		if c.is_in_group(LcdStyle.TEXT_GROUP) and c != _resume:
			LcdStyle.menu_look(c)
	LcdStyle.menu_look(_resume, true, LcdStyle.ZH_MIN_SIZE)


## Opens with the current settings shown.
func open(settings: Dictionary, room: String, language: String, mode := "free") -> void:
	show_state(settings, room, language, mode)
	visible = true


func close() -> void:
	visible = false


## In the run the table is the layer's, so the table keys only show it.
func show_state(settings: Dictionary, room: String, language: String, mode := "free") -> void:
	for id in _modes:
		_modes[id].set_pressed_no_signal(id == mode)
	_new_run.visible = mode == "run"
	_sure = false
	_new_run.text = "NEW RUN"
	for id in _rooms:
		_rooms[id].set_pressed_no_signal(id == room)
		_rooms[id].disabled = mode == "run" and id != room
	for code in _langs:
		_langs[code].set_pressed_no_signal(code == language)
	_volume.set_value_no_signal(roundf(float(settings.get("master", 0.8)) * 100.0))
	var muted := bool(settings.get("muted", false))
	_sound.set_pressed_no_signal(muted)
	_sound.text = "MUTED" if muted else "SOUND"
	_full.set_pressed_no_signal(bool(settings.get("fullscreen", false)))
	_back.set_pressed_no_signal(bool(settings.get("back_first", false)))


## Developer and test access to the keys.
func key(id: String) -> Button:
	match id:
		"sound": return _sound
		"fullscreen": return _full
		"back_first": return _back
		"resume": return _resume
		"quit": return _quit
		"volume": return null
	if id == "new_run":
		return _new_run
	if _modes.has(id):
		return _modes[id]
	if _rooms.has(id):
		return _rooms[id]
	return _langs.get(id)


func volume_slider() -> HSlider:
	return _volume


## NEW RUN throws the run in progress away, so it asks once: the second press does it.
func _on_new_run() -> void:
	if not _sure:
		_sure = true
		_new_run.text = "SURE?"
		return
	_sure = false
	_new_run.text = "NEW RUN"
	new_run_pressed.emit()


func _on_shade_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		close()


func _caption(text: String) -> Label:
	var l := LcdStyle.label(text, 24, LcdStyle.DIM_TEXT)
	return l


func _row(parent: Container) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	parent.add_child(h)
	return h


## A lit key that stays down while its choice is the current one.
func _toggle_key(text: String) -> Button:
	var b := LcdStyle.toggle_key(text, 24)
	b.custom_minimum_size = Vector2(0, 46)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		Orphans.free_members(self, ["_volume", "_shade"])
