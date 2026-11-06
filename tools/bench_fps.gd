extends Node
## Frame-time benchmark: the heaviest moments of the game in every room, with vsync
## off, so the numbers show headroom over 60 fps (16.7 ms). Run it on the machine
## you want to check (MIGRATION.md: stable 60 fps on integrated graphics at 1080p).
##   godot --path . --resolution 1920x1080 res://tools/bench_fps.tscn [-- <report file>]
## In an exported verify build: LastSaleVerify.exe -- [<report file>] --run-tool=res://tools/bench_fps.tscn
## Prints per scene: mean and worst-1% frame time, and the GPU's render time.

const SAMPLE := 3.0

var game: Game
var lines := PackedStringArray()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	game = load("res://src/game/game.tscn").instantiate()
	game.use_save = false
	add_child(game)
	await _wait(2.0)
	_log("Last Sale frame times, %s, %s, %dx%d" % [RenderingServer.get_video_adapter_name(),
		RenderingServer.get_current_rendering_driver_name(), get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y])
	_log("%-28s %8s %8s %8s %6s" % ["scene", "mean ms", "1% ms", "gpu ms", "fps"])
	for room in RoomSet.ORDER:
		game.set_room(room)
		await _wait(0.5)
		await _measure(room + ": machine")
		# 100 tickets coming out of the machine.
		game.economy.insert(100)
		await _wait(Economy.BILL_TIME + 0.2)
		game.press_play_all()
		game.press_machine(0)
		await _wait(0.4)
		await _measure(room + ": dispensing")
		while game.machine.busy():
			await _wait(0.2)
		await _wait(2.0)
		# At the table with a ticket in hand and a big discard pile.
		if game.at_machine:
			game.toggle_view()
		await game.pile.fill(2000, ["core:catch", "core:plate", "core:spur"] as Array[String])
		await _wait(1.2)
		await _measure(room + ": table, pile of 2000")
		# Tearing: tickets opened one after another with Space (flecks, confetti on wins).
		var t0 := Time.get_ticks_msec()
		var frames := []
		var gpu := []
		while Time.get_ticks_msec() - t0 < SAMPLE * 1000.0:
			game.primary()
			for k in 6:
				var a := Time.get_ticks_usec()
				await get_tree().process_frame
				frames.append((Time.get_ticks_usec() - a) / 1000.0)
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
		_report(room + ": opening tickets", frames, gpu)
		game.dev_reset()
		game.pile.clear()
		await _wait(0.5)
	var args := Array(OS.get_cmdline_user_args()).filter(func(x: String): return not x.begins_with("--"))
	if not args.is_empty():
		var f := FileAccess.open(args[0], FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(lines) + "\n")
	get_tree().quit()


func _measure(name: String) -> void:
	var frames := []
	var gpu := []
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < SAMPLE * 1000.0:
		var a := Time.get_ticks_usec()
		await get_tree().process_frame
		frames.append((Time.get_ticks_usec() - a) / 1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
	_report(name, frames, gpu)


func _report(name: String, frames: Array, gpu: Array) -> void:
	frames = frames.slice(2)
	var mean := 0.0
	for f in frames:
		mean += f
	mean /= maxf(1.0, frames.size())
	var sorted := frames.duplicate()
	sorted.sort()
	var worst: float = sorted[int(sorted.size() * 0.99)] if not sorted.is_empty() else 0.0
	var g := 0.0
	for x in gpu:
		g += x
	g /= maxf(1.0, gpu.size())
	_log("%-28s %8.2f %8.2f %8.2f %6.0f" % [name, mean, worst, g, 1000.0 / maxf(mean, 0.001)])


func _log(s: String) -> void:
	print(s)
	lines.append(s)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
