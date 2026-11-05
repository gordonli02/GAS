extends Control
## Milestone 1 check screen: fonts render, recorded sounds play, the core pack
## loads and a box generates. Temporary; replaced by the game scene in M2.

const FONT_DIR := "res://assets/fonts/"
const MACHINE := ["bill_insert", "dispense_loop", "dispense_stop", "machine_button"]

var _player := AudioStreamPlayer.new()
var _info := Label.new()


func _ready() -> void:
	add_child(_player)
	var bg := ColorRect.new()
	bg.color = Color("#17161b")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var col := VBoxContainer.new()
	col.position = Vector2(48, 40)
	col.add_theme_constant_override("separation", 14)
	add_child(col)

	col.add_child(_text("BIG CATCH  HOT PLATE  LUCKY SPUR", "alfa-slab-one-latin-400-normal", 56, Color("#ffe14a")))
	col.add_child(_text("PAYABLE IN EGG MONEY.   ©Ben Kraptu apt.   FORM BC-1S", "oswald-latin-600-normal", 28, Color("#f1ead9")))
	col.add_child(_text("INSTANT WINNERS SHOWN ABOVE.  (Oswald 400)", "oswald-latin-400-normal", 28, Color("#a8a194")))
	col.add_child(_text("$  200.00 CREDIT   SELECT A TICKET   SERIAL NO. K482910", "vt323-latin-400-normal", 40, Color("#b8e23e")))

	col.add_child(_heading("Machine sounds (res://assets/audio)"))
	var row := HBoxContainer.new()
	col.add_child(row)
	for id in MACHINE:
		var s: AudioStream = load("res://assets/audio/%s.wav" % id)
		row.add_child(_button(id, s, 1.5 if id == "dispense_loop" else 1.0))

	var res := PackLoader.load_dir("res://packs/core")
	if not res.ok():
		col.add_child(_heading("Core pack FAILED: " + "; ".join(res.errors)))
		return
	var pack := res.pack
	col.add_child(_heading("Tear rips from the core pack (loaded at runtime, no import)"))
	var tears := HBoxContainer.new()
	col.add_child(tears)
	for c in pack.tear_clips:
		tears.add_child(_button(c.path.get_file().get_basename(), PackAssets.audio(c.path), 1.0))

	col.add_child(_heading("Boxes for seed G-0001 (compare with the web build's developer panel)"))
	for f in pack.forms:
		var box := BoxGenerator.build(f, "G-0001")
		var type := BoxModel.standard().type_by_id(box.type_id)
		var counts := PackedStringArray()
		for i in f.tiers.size():
			counts.append("$%d %s ×%d" % [f.tiers[i].prize, f.tiers[i].label.get("zh", ""), box.counts[i]])
		col.add_child(_text("%s   %d tickets   %s   net %+d   first serial %s   |   %s" % [
			f.name, box.size, type.label.zh, box.net(), box.tickets[0].serial, ",  ".join(counts)],
			"", 20, Color("#f1ead9")))
	_info.add_theme_font_size_override("font_size", 18)
	_info.modulate = Color("#a8a194")
	col.add_child(_info)


func _button(label: String, stream: AudioStream, pitch: float) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(150, 44)
	b.pressed.connect(func():
		_player.stop()
		_player.stream = stream
		_player.pitch_scale = pitch
		_player.play()
		_info.text = "%s  %.2f s  pitch %.1f" % [label, stream.get_length(), pitch])
	return b


func _heading(t: String) -> Label:
	return _text(t, "", 22, Color("#b8e23e"))


func _text(t: String, font: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	if font != "":
		l.add_theme_font_override("font", load(FONT_DIR + font + ".woff2"))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
