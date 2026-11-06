extends SceneTree
## Turns SVG files into PNG with the engine's own SVG reader, for tools/make_ticket_art.py:
##   godot --headless --path . -s res://tools/raster_svg.gd -- <jobs.json>
## jobs.json: [{"svg": path, "png": path, "scale": pixels per SVG unit}, ...]

func _initialize() -> void:
	var jobs = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	var failed := 0
	for j in jobs:
		var img := Image.new()
		var err := img.load_svg_from_string(FileAccess.get_file_as_string(j.svg), float(j.scale))
		if err == OK:
			err = img.save_png(j.png)
		if err != OK:
			failed += 1
			printerr("could not render ", j.svg, " (error ", err, ")")
	quit(1 if failed > 0 else 0)
