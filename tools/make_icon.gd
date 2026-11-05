extends SceneTree
## Renders the game icon from the Big Catch front (box art, no serial), centred on a
## transparent square: assets/icon/icon.png (1024 px, the window icon and the source of
## the Windows .exe icon). Needs a display (not --headless):
##   godot --path . -s res://tools/make_icon.gd

const FORM := "catch"
const SIZE := 1024
const MARGIN := 0.04  ## of SIZE, on the long side
const OUT := "res://assets/icon/icon.png"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var painter := TicketPainter.new()
	root.add_child(painter)
	var form := PackLoader.load_dir("res://packs/core").pack.form(FORM)
	var canvas := TicketArt.canvas_size(form)
	var scale := SIZE * (1.0 - 2.0 * MARGIN) / maxf(canvas.x, canvas.y)
	var art: Image = await painter.paint_image(canvas, TicketArt.front(form, ""), scale)
	art.convert(Image.FORMAT_RGBA8)
	var icon := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	icon.fill(Color(0, 0, 0, 0))
	var at := (Vector2i(SIZE, SIZE) - art.get_size()) / 2
	icon.blit_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), at)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	icon.save_png(ProjectSettings.globalize_path(OUT))
	print("icon written to ", OUT, " (art ", art.get_size(), ")")
	quit()
