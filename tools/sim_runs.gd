extends Node
## Plays many runs of the story mode with simple bots and prints what happened, for
## looking at the numbers in RunConfig (no window needed):
##   godot --headless --path . res://tools/sim_runs.tscn -- --runs=200
##   godot --headless --path . res://tools/sim_runs.tscn -- --runs=500 --bots=blind,borrow --seed=B
## Columns: runs cleared; share that reached layers 2 and 3; days and tickets per run;
## prizes won per dollar spent on tickets (last-sale prizes included); days spared;
## perk levels bought. Then what a dollar of tickets pays back at some perk levels
## (whole boxes bought out; --ev-boxes=N boxes of each form, 0 to skip). Then each
## form's boxes in the run's model (its shape): return, winners per 100 tickets, top
## prizes a box and how bumpy one ticket's prize is (--form-boxes=N, 0 to skip).


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var runs := 200
	var bots: Array = RunSim.BOTS
	var prefix := "SIM"
	var ev_boxes := 6
	var form_boxes := 300
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--form-boxes="):
			form_boxes = maxi(0, a.trim_prefix("--form-boxes=").to_int())
		if a.begins_with("--runs="):
			runs = maxi(1, a.trim_prefix("--runs=").to_int())
		elif a.begins_with("--bots="):
			bots = Array(a.trim_prefix("--bots=").split(","))
		elif a.begins_with("--ev-boxes="):
			ev_boxes = maxi(0, a.trim_prefix("--ev-boxes=").to_int())
		elif a.begins_with("--seed="):
			prefix = a.trim_prefix("--seed=")
	var res := PackLoader.load_dir("res://packs/core")
	if not res.ok():
		push_error("core pack failed to load: " + "; ".join(res.errors))
		get_tree().quit(1)
		return
	var config := RunConfig.standard()
	var problems := config.problems()
	for p in problems:
		print("CONFIG: " + p)
	print("%d runs per bot, seeds %s-0 .. %s-%d" % [runs, prefix, prefix, runs - 1])
	print("%-8s %8s %8s %8s %8s %9s %8s %8s %6s" % ["bot", "cleared", "layer 2", "layer 3", "days", "tickets", "return", "spared", "perks"])
	for bot in bots:
		if not RunSim.BOTS.has(bot):
			print("unknown bot: " + str(bot))
			continue
		var t0 := Time.get_ticks_msec()
		var s := RunSim.summary(bot, res.pack.forms, runs, prefix, config)
		print("%-8s %7.1f%% %7.1f%% %7.1f%% %8.1f %9.0f %8.3f %8.2f %6.1f   (%.1f s)" % [bot, s.cleared * 100.0,
			s.reached[1] * 100.0, s.reached[2] * 100.0, s.days, s.tickets, s["return"], s.days_spared, s.perks,
			(Time.get_ticks_msec() - t0) / 1000.0])
	if ev_boxes > 0:
		print("\nreturn per dollar of tickets, %d boxes of each form bought out:" % ev_boxes)
		for levels in RunSim.EV_SETS:
			var label := "no perks" if levels.is_empty() else ", ".join(levels.keys().map(func(k): return "%s %d" % [k, levels[k]]))
			print("  %-28s %.3f" % [label, RunSim.box_return(res.pack.forms, levels, ev_boxes)])
	if form_boxes > 0:
		print("\neach form in the run's model (its shape), %d boxes, no perks:" % form_boxes)
		print("  %-10s %7s %9s %7s %8s" % ["form", "return", "win/100", "tops", "sd $"])
		for row in RunSim.form_table(res.pack.forms, form_boxes):
			print("  %-10s %7.3f %9.1f %7.2f %8.2f" % [row.form, row["return"], row.winners, row.tops, row.sd])
	get_tree().quit(0 if problems.is_empty() else 1)
