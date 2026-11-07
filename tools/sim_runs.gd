extends Node
## Plays many runs of the story mode with simple bots and prints what happened, for
## looking at the numbers in RunConfig (no window needed):
##   godot --headless --path . res://tools/sim_runs.tscn -- --runs=300
##   godot --headless --path . res://tools/sim_runs.tscn -- --runs=500 --bots=blind,borrow --seed=B
## The bots' table (RunSim.summary; 300 runs a bot by default, docs/roadmap.md "怎么量"):
## runs cleared overall; of the runs that reached layer 1 / 2 / 3, the share that paid
## it (the three multiply to the overall); days and tickets per run; prizes won per
## dollar of tickets, and per dollar of tickets and NEW BOX fees; perk levels bought;
## the 50th / 90th / 99th percentile of each run's biggest single prize, in dollars.
## Beside it the roadmap's target for the bots that have one, whether it is met
## (build 20 to 30%; gamble and perks within 5 points of theirs; borrow, blind and skip
## under theirs), and whether the bot keeps its place in the ordering
## build > gamble > perks > borrow >= blind ~ skip (against the next bot down; blind
## and skip within 3 points of each other count as equal).
## Then what a dollar of tickets pays back at some perk levels (whole boxes bought
## out; --ev-boxes=N boxes of each form, 0 to skip), each form alone without perks and
## with DUE A WIN 2, and the churn exploit at fixed perks (--churn-boxes=N boxes a
## column, 0 to skip). Then ALL IN's odds on each form (RunSim.push_odds: of the
## windows of ten after one that paid, the share whose printed prizes beat it;
## --push-boxes=N boxes a form, 0 to skip). Then each form's boxes in the run's model (its shape): return,
## winners per 100 tickets, top prizes a box and how bumpy one ticket's prize is
## (--form-boxes=N, 0 to skip).

## The roadmap's targets (docs/roadmap.md, the bots' table): [text, low, high] in
## percent of runs cleared.
const TARGETS := {
	"build": ["25%", 20.0, 30.0], "gamble": ["15%", 10.0, 20.0], "perks": ["10%", 5.0, 15.0],
	"borrow": ["<8%", 0.0, 8.0], "blind": ["<5%", 0.0, 5.0], "skip": ["<5%", 0.0, 5.0],
}
const ORDER := ["build", "gamble", "perks", "borrow", "blind", "skip"]
const EVEN := 3.0   ## blind and skip within this many points count as equal


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var runs := 300
	var bots: Array = RunSim.BOTS
	var prefix := "SIM"
	var ev_boxes := 6
	var churn_boxes := 200
	var form_boxes := 300
	var push_boxes := 100
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--push-boxes="):
			push_boxes = maxi(0, a.trim_prefix("--push-boxes=").to_int())
		elif a.begins_with("--form-boxes="):
			form_boxes = maxi(0, a.trim_prefix("--form-boxes=").to_int())
		elif a.begins_with("--churn-boxes="):
			churn_boxes = maxi(0, a.trim_prefix("--churn-boxes=").to_int())
		elif a.begins_with("--runs="):
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
	print("work line: " + config.line_text())
	print("%d runs per bot, seeds %s-0 .. %s-%d" % [runs, prefix, prefix, runs - 1])
	print("%-8s %7s %7s %7s %7s %6s %7s %7s %7s %5s %8s %8s %9s  %-6s %-4s %-5s" % ["bot", "cleared", "L1", "L2", "L3",
		"days", "tickets", "return", "w/ fees", "perks", "best 50", "best 90", "best 99", "target", "met", "order"])
	var rates := {}
	var rows := []
	for bot in bots:
		if not RunSim.BOTS.has(bot):
			print("unknown bot: " + str(bot))
			continue
		var t0 := Time.get_ticks_msec()
		var s := RunSim.summary(bot, res.pack.forms, runs, prefix, config)
		rates[bot] = s.cleared * 100.0
		rows.append([bot, s, (Time.get_ticks_msec() - t0) / 1000.0])
	for row in rows:
		var bot: String = row[0]
		var s: Dictionary = row[1]
		var l: Array = s.layer_rates
		var target: Array = TARGETS.get(bot, ["", 0.0, 0.0])
		var met := ""
		if TARGETS.has(bot):
			var r: float = rates[bot]
			var under := str(target[0]).begins_with("<")
			met = "yes" if r >= float(target[1]) and (r < float(target[2]) if under else r <= float(target[2])) else "no"
		print("%-8s %6.1f%% %6.1f%% %6.1f%% %6.1f%% %6.1f %7.0f %7.3f %7.3f %5.1f %8d %8d %9d  %-6s %-4s %-5s (%.1f s)" % [bot,
			s.cleared * 100.0, l[0] * 100.0, l[1] * 100.0, l[2] * 100.0, s.days, s.tickets, s["return"], s.return_fees,
			s.perks, s.best[0], s.best[1], s.best[2], target[0], met, _order(bot, rates), row[2]])
	var held := true
	var known := true
	for b in ORDER:
		known = known and rates.has(b)
	if known:
		var broken := []
		for b in ORDER:
			if _order(b, rates) == "no":
				held = false
				broken.append(b)
		print("ordering build > gamble > perks > borrow >= blind ~ skip: %s" % ("holds" if held else "fails at " + ", ".join(broken)))
	if ev_boxes > 0:
		print("\nreturn per dollar of tickets, %d boxes of each form bought out:" % ev_boxes)
		for levels in RunSim.EV_SETS:
			var label := "no perks" if levels.is_empty() else ", ".join(levels.keys().map(func(k): return "%s %s" % [k, str(levels[k])]))
			print("  %-60s %.3f" % [label, RunSim.box_return(res.pack.forms, levels, ev_boxes)])
		var pity_boxes := ev_boxes * 4
		print("\neach form alone, %d boxes: no perks / DUE A WIN 2 (pity 2):" % pity_boxes)
		for f: FormDef in res.pack.forms:
			print("  %-10s %7.3f %7.3f" % [f.id, RunSim.box_return([f], {}, pity_boxes), RunSim.box_return([f], {"pity": 2}, pity_boxes)])
	if churn_boxes > 0:
		print("\nchurn: %d tickets a box then NEW BOX, %d boxes a column, stake 1 (return / with fees / the fee):" % [RunSim.CHURN, churn_boxes])
		for levels in RunSim.CHURN_SETS:
			var label := "no perks" if levels.is_empty() else ", ".join(levels.keys().map(func(k): return "%s %d" % [k, levels[k]]))
			var c := RunSim.churn_return(res.pack.forms, levels, churn_boxes)
			print("  %-28s %7.3f %7.3f %6d" % [label, c["return"], c.return_fees, c.fee])
	if push_boxes > 0:
		print("\nALL IN: windows of %d, %d boxes a form, no perks (P: the next window's printed prizes beat one that paid):" % [Catalog.WINDOW, push_boxes])
		for row in RunSim.push_odds(res.pack.forms, push_boxes):
			print("  %-10s P %.3f  (%d windows)" % [row.form, row.p, row.windows])
	if form_boxes > 0:
		print("\neach form in the run's model (its shape), %d boxes, no perks:" % form_boxes)
		print("  %-10s %7s %9s %7s %8s" % ["form", "return", "win/100", "tops", "sd $"])
		for row in RunSim.form_table(res.pack.forms, form_boxes):
			print("  %-10s %7.3f %9.1f %7.2f %8.2f" % [row.form, row["return"], row.winners, row.tops, row.sd])
	get_tree().quit(0 if problems.is_empty() else 1)


## Whether `bot` keeps its place in the ordering against the next bot down: "yes",
## "no", or "" when it is not in the ordering or the next bot was not run.
static func _order(bot: String, rates: Dictionary) -> String:
	var k := ORDER.find(bot)
	if k < 0 or k == ORDER.size() - 1 or not rates.has(bot) or not rates.has(ORDER[k + 1]):
		return ""
	var a: float = rates[bot]
	var b: float = rates[ORDER[k + 1]]
	match bot:
		"borrow":
			return "yes" if a >= b else "no"
		"blind":
			return "yes" if absf(a - b) <= EVEN else "no"
	return "yes" if a > b else "no"
