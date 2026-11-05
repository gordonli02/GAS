extends SceneTree
## Measures where Chinese (through each Latin font's CJK fallback) sits against that
## font's capitals: ink height and vertical centre, in pixels. Used to check the cuts
## made by tools/subset_cjk_fonts.py (heights equal, shift within half a pixel).
##   godot --path . -s res://tools/measure_cjk.gd

const FONTS := {
	"vt323": "res://assets/fonts/vt323-latin-400-normal.woff2",
	"oswald600": "res://assets/fonts/oswald-latin-600-normal.woff2",
	"oswald400": "res://assets/fonts/oswald-latin-400-normal.woff2",
}
const SIZES := [18, 20, 22, 24, 26, 30, 38, 46]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(400, 120)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var l := Label.new()
	l.position = Vector2(10, 10)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	vp.add_child(l)
	for id in FONTS:
		l.add_theme_font_override("font", load(FONTS[id]))
		for s in SIZES:
			l.add_theme_font_size_override("font_size", s)
			var caps := await _ink(vp, l, "HEXBD")
			var zh := await _ink(vp, l, "菜单继续退出语言")
			print("%-9s %2d  caps h %4.1f c %5.1f   zh h %4.1f c %5.1f   shift %+5.1f" % [id, s, caps.y - caps.x, (caps.x + caps.y) / 2.0, zh.y - zh.x, (zh.x + zh.y) / 2.0, (caps.x + caps.y) / 2.0 - (zh.x + zh.y) / 2.0])
	quit()


## Top and bottom ink rows (x, y) of `text`.
func _ink(vp: SubViewport, l: Label, text: String) -> Vector2:
	l.text = text
	l.add_theme_color_override("font_color", Color.WHITE)
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var top := -1
	var bottom := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.4:
				if top < 0:
					top = y
				bottom = y
				break
	return Vector2(top, bottom + 1)
