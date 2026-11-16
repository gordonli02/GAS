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
## Beside it the target of docs/roadmap.md 一 for the bots that have one and whether it
## is met (the five lines, clearing, jackpot, small, batch and money, 25%: 20 to 30;
## gamble, borrow, blind and skip under 5%; build and perks none yet, "量完再定"), and
## whether the bot keeps its place in the ordering: every line > build > perks > each
## of gamble, borrow, blind and skip, and borrow <= gamble (a bot is compared with the
## bots of the nearest rank below that was run; the line under the table names every
## comparison that fails and the bots not run).
## Under the table, a few lines a bot: its spec (SimBots.describe), the 95% Wilson
## interval of its clear rate, the share of runs that died in each layer, and the cash
## carried into the next layer over its due (median, share at 1 or more). With
## --detail also the trigger table (what each perk did: RunState.fired) and a block a
## layer of how the runs died there (SimReport.summary says what each number is).
## --early: runs in chunks of 100 and stops a bot with a target once the Wilson interval
## lies wholly outside the target's band ("(stopped at N)"). Off by default: the death
## report wants every run.
## --save=<path>: writes each bot's per-seed outcomes and headline numbers as JSON.
## --against=<path>: reads such a file (one saved before a field was added still reads:
## only the outcomes, the clear rate and the run count are used) and, for each bot in
## both with the same seed prefix and run count, prints the paired comparison (SimReport.paired: the same bot
## before and after a number change; the bots' dice are seeded by the seed alone, so the
## same seeds play the same boxes and draw the same dice).
## Then what a dollar of tickets pays back at some perk levels (whole boxes bought
## out; --ev-boxes=N boxes of each form, 0 to skip), each form alone without perks and
## with DUE A WIN 2, and the churn exploit at fixed perks (--churn-boxes=N boxes a
## column, 0 to skip). Then ALL IN's odds on each form (SimData.push_odds: of the
## windows of ten after one that paid, the share whose printed prizes reach its bar,
## the form's Catalog.ALL_IN_SHARE of it; --push-boxes=N boxes a form, 0 to skip). Then each form's boxes in the run's model (its shape): return,
## winners per 100 tickets, top prizes a box and how bumpy one ticket's prize is
## (--form-boxes=N, 0 to skip).
## With --baseline=<path> the tool does only this: for each bot of --bots= (default all)
## it plays seeds BASE-0 .. BASE-(N-1) (--baseline-runs=N, default 20) with the standard
## config and writes the rows (RunSim.baseline_row) as JSON to <path> (res://, user:// or
## a file path; a relative path is from the project folder), printing one timing line a
## bot. That file, tests/fixtures/sim_baseline.json, freezes the bots (test_run_sim.gd).
## With --list-bots it prints the strategy bots' names (RunSim.BOTS, src/sim/sim_bots.gd;
## not the probe bots, SimBots.PROBES), one a line, and quits. --bots=churn still plays
## a probe bot in the table when asked for by name.
## With --probes the tool does only the adversarial layer (SimProbes; docs/roadmap.md 七):
## every probe is run (--probe-runs=N whole runs of its bot, default 100; --churn-boxes=N
## boxes a column of its fixed-perk part, default 200) and printed with its rule, its
## numbers and PASS / FAIL. Unlike the other modes this one is a check: the exit code is
## 1 if any probe fails.
## With --given the tool does only the given-cards test (SimReport.given; docs/roadmap.md
## M9.8 step 1 stage 3, "用得上") for the line bots of --bots= (default the five): each
## seed played by the line bot holding its core (SimBots.GIVEN) and buying no perks, and
## by blind holding the same; per line the numbers of both arms and PASS / FAIL for each
## of the two criteria (fired, play) and the line, and the signature ratio as a reading
## (no verdict). Exit code 0 either way: it is a report.
## With --variants the table is of every named variant of the bots of --bots= that have
## some (SimBots.VARIANTS: the five lines and build; default the five lines), a row each
## (<bot>/<variant>) beside the bot's own spec, paired with it on the same seeds, with
## its rerolls a run, and the best by clear rate named; on a tie the higher layer-1 rate
## decides, then the higher return, and the line says which.
## In --detail's trigger table, L1 / L2 / L3 ("拿得到", roadmap 十三.10): of the runs
## that played the layer, the share holding the perk when it ended there; beside them
## D1 / D2 / D3, the share in which it had been dealt as a card by then (any round,
## reroll or reward round), so "never dealt" and "dealt but not bought" read apart (a
## shelf perk, never dealt, prints "-"). And under each bot the rounds a run (morning,
## reward), the rerolls paid for and the upgrades taken a run (from the shelf's upgrade
## slots, and reward rounds' upgrade cards); --save writes the upgrades too.
## With --reach the tool does only the deal's ceiling (SimReport.reach; roadmap 十二.3,
## "are there enough picks for a line to come together", money left out) for the line
## bots of --bots= (default the five), each at 0, 1, 2 and 3 paid rerolls a morning round
## (--rerolls=a,b,... for other counts, e.g. --rerolls=0): a
## bot with plenty of cash that works every day (each layer paid on its last day, one
## reward round a layer), buys the shelf perks of the line's core and takes from every
## round the first core card it lacks, rerolling when none is there. Per line and reroll
## count: the share of runs holding the whole core, and at least one engine, by the end
## of layer 1 / 2 / 3; the median round (morning and reward counted) the core was
## complete at and the share that never completed it; rerolls a run and their cost; then
## each core card's held share by layer. Exit code 0: it is a report.
## --set=key=value[,key=value...]: the run's config with those fields overridden
## (RunConfig.SETTABLE: shelf_upgrades and the dealing experiments of roadmap 十三.5,
## deal_bias, reward_bias, free_rerolls, starter, offer_bonus; RunConfig.parse_set) for
## the table, --variants, --given and --reach (not --baseline: the fixture is the
## standard config's). An unknown key or a bad value is an error (exit code 1). The
## header names the overrides, --save writes them, and --against prints the saved
## file's beside them, so --set=deal_bias=3 --against=<a file saved without> pairs the
## experiment against the standard deal on the same seeds. --upgrades=N is
## --set=shelf_upgrades=N.

## The roadmap's targets (docs/roadmap.md 一): [text, low, high] in percent of runs
## cleared ("<": under high). build and perks have none yet.
const TARGETS := {
	"clearing": ["25%", 20.0, 30.0], "jackpot": ["25%", 20.0, 30.0], "small": ["25%", 20.0, 30.0],
	"batch": ["25%", 20.0, 30.0], "money": ["25%", 20.0, 30.0],
	"gamble": ["<5%", 0.0, 5.0], "borrow": ["<5%", 0.0, 5.0], "blind": ["<5%", 0.0, 5.0], "skip": ["<5%", 0.0, 5.0],
}
## The ordering (docs/roadmap.md 一.3), rank by rank, highest first: every bot of a rank
## clears more than every bot of the next rank run. And borrow <= gamble (一.2).
const RANKS := [["clearing", "jackpot", "small", "batch", "money"], ["build"], ["perks"], ["gamble", "borrow", "blind", "skip"]]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var runs := 300
	var bots: Array = RunSim.BOTS
	var prefix := "SIM"
	var ev_boxes := 6
	var churn_boxes := SimProbes.BOXES
	var form_boxes := 300
	var push_boxes := 100
	var baseline := ""
	var baseline_runs := 20
	var detail := false
	var early := false
	var save := ""
	var against := ""
	var given := false
	var variants := false
	var probes := false
	var probe_runs := SimProbes.RUNS
	var bots_set := false
	var reach := false
	var reach_rerolls := [0, 1, 2, 3]
	var overrides := {}
	for a in OS.get_cmdline_user_args():
		var set_text := ""
		if a.begins_with("--set="):
			set_text = a.trim_prefix("--set=")
		elif a.begins_with("--upgrades="):
			set_text = "shelf_upgrades=" + a.trim_prefix("--upgrades=")
		if a.begins_with("--set=") or a.begins_with("--upgrades="):
			var parsed := RunConfig.parse_set(set_text)
			if parsed.error != "":
				print("--set: " + str(parsed.error))
				get_tree().quit(1)
				return
			overrides.merge(parsed.set, true)
			continue
		if a.begins_with("--rerolls="):
			reach_rerolls = []
			for t in a.trim_prefix("--rerolls=").split(",", false):
				if not t.strip_edges().is_valid_int() or t.to_int() < 0:
					print("--rerolls: a list of whole numbers, 0 or more: " + a)
					get_tree().quit(1)
					return
				reach_rerolls.append(t.to_int())
			if reach_rerolls.is_empty():
				print("--rerolls: no count given")
				get_tree().quit(1)
				return
			continue
		if a == "--detail":
			detail = true
		elif a == "--given":
			given = true
		elif a == "--variants":
			variants = true
		elif a == "--probes":
			probes = true
		elif a == "--reach":
			reach = true
		elif a.begins_with("--probe-runs="):
			probe_runs = maxi(1, a.trim_prefix("--probe-runs=").to_int())
		elif a == "--early":
			early = true
		elif a.begins_with("--save="):
			save = a.trim_prefix("--save=")
		elif a.begins_with("--against="):
			against = a.trim_prefix("--against=")
		elif a.begins_with("--baseline-runs="):
			baseline_runs = maxi(1, a.trim_prefix("--baseline-runs=").to_int())
		elif a.begins_with("--baseline="):
			baseline = a.trim_prefix("--baseline=")
		elif a.begins_with("--push-boxes="):
			push_boxes = maxi(0, a.trim_prefix("--push-boxes=").to_int())
		elif a.begins_with("--form-boxes="):
			form_boxes = maxi(0, a.trim_prefix("--form-boxes=").to_int())
		elif a.begins_with("--churn-boxes="):
			churn_boxes = maxi(0, a.trim_prefix("--churn-boxes=").to_int())
		elif a.begins_with("--runs="):
			runs = maxi(1, a.trim_prefix("--runs=").to_int())
		elif a.begins_with("--bots="):
			bots = Array(a.trim_prefix("--bots=").split(","))
			bots_set = true
		elif a.begins_with("--ev-boxes="):
			ev_boxes = maxi(0, a.trim_prefix("--ev-boxes=").to_int())
		elif a.begins_with("--seed="):
			prefix = a.trim_prefix("--seed=")
		elif a == "--list-bots":
			for b in RunSim.BOTS:
				print(b)
			get_tree().quit(0)
			return
	var res := PackLoader.load_dir("res://packs/core")
	if not res.ok():
		push_error("core pack failed to load: " + "; ".join(res.errors))
		get_tree().quit(1)
		return
	var config := RunConfig.standard()
	if baseline != "":
		# The fixture freezes the probe bots too (SimBots.PROBES), unless --bots= names some.
		var frozen: Array = bots if bots_set else RunSim.BOTS + SimBots.PROBES
		get_tree().quit(_write_baseline(baseline, frozen, baseline_runs, res.pack.forms, config))
		return
	var slots := ""
	if not overrides.is_empty():
		slots = ", overrides: " + RunConfig.set_text(overrides)
		config.apply_set(overrides)
	if probes:
		get_tree().quit(_probes(probe_runs, churn_boxes, res.pack.forms))
		return
	var lines: Array = (bots if bots_set else SimBots.GIVEN.keys()).filter(func(b): return SimBots.GIVEN.has(b))
	if given:
		if slots != "":
			print(slots.trim_prefix(", "))
		_given(lines, runs, prefix, res.pack.forms, config)
		get_tree().quit(0)
		return
	if reach:
		_reach(lines, runs, prefix, res.pack.forms, config, slots, reach_rerolls)
		get_tree().quit(0)
		return
	if variants:
		var with_variants: Array = (bots if bots_set else SimBots.GIVEN.keys()).filter(func(b): return SimBots.VARIANTS.has(b))
		_variants(with_variants, runs, prefix, res.pack.forms, config, detail, slots)
		get_tree().quit(0)
		return
	var problems := config.problems()
	for p in problems:
		print("CONFIG: " + p)
	print("work line: " + config.line_text())
	print("%d runs per bot, seeds %s-0 .. %s-%d%s" % [runs, prefix, prefix, runs - 1, slots])
	print("%-8s %7s %7s %7s %7s %6s %7s %7s %7s %5s %8s %8s %9s  %-6s %-4s %-5s" % ["bot", "cleared", "L1", "L2", "L3",
		"days", "tickets", "return", "w/ fees", "perks", "best 50", "best 90", "best 99", "target", "met", "order"])
	var rates := {}
	var rows := []
	for bot in bots:
		if not RunSim.BOTS.has(bot) and not SimBots.PROBES.has(bot):
			print("unknown bot: " + str(bot))
			continue
		var t0 := Time.get_ticks_msec()
		var band := []
		if early and TARGETS.has(bot):
			band = [float(TARGETS[bot][1]) / 100.0, float(TARGETS[bot][2]) / 100.0]
		var s := RunSim.summary(bot, res.pack.forms, runs, prefix, config, band)
		rates[bot] = s.cleared * 100.0
		rows.append([bot, s, (Time.get_ticks_msec() - t0) / 1000.0])
	var order := _ordering(rates)
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
		var stop := " (stopped at %d)" % s.stopped if int(s.stopped) > 0 else ""
		print("%-8s %6.1f%% %6.1f%% %6.1f%% %6.1f%% %6.1f %7.0f %7.3f %7.3f %5.1f %8d %8d %9d  %-6s %-4s %-5s (%.1f s)%s" % [bot,
			s.cleared * 100.0, l[0] * 100.0, l[1] * 100.0, l[2] * 100.0, s.days, s.tickets, s["return"], s.return_fees,
			s.perks, s.best[0], s.best[1], s.best[2], target[0], met, order.marks.get(bot, ""), row[2], stop])
	for line in order.lines:
		print(line)
	for row in rows:
		_print_bot(row[1], detail)
	if save != "":
		_save(save, prefix, runs, rows, config.shelf_upgrades, overrides)
	if against != "":
		_against(against, prefix, rows, overrides)
	if ev_boxes > 0:
		print("\nreturn per dollar of tickets, %d boxes of each form bought out:" % ev_boxes)
		for levels in SimData.EV_SETS:
			var label := "no perks" if levels.is_empty() else ", ".join(levels.keys().map(func(k): return "%s %s" % [k, str(levels[k])]))
			print("  %-60s %.3f" % [label, SimData.box_return(res.pack.forms, levels, ev_boxes)])
		var pity_boxes := ev_boxes * 4
		print("\neach form alone, %d boxes: no perks / DUE A WIN 2 (pity 2):" % pity_boxes)
		for f: FormDef in res.pack.forms:
			print("  %-10s %7.3f %7.3f" % [f.id, SimData.box_return([f], {}, pity_boxes), SimData.box_return([f], {"pity": 2}, pity_boxes)])
	if churn_boxes > 0:
		print("\nchurn: %d tickets a box then NEW BOX, %d boxes a column, stake 1 (return / with fees / the fee):" % [SimData.CHURN, churn_boxes])
		for levels in SimData.CHURN_SETS:
			var label := "no perks" if levels.is_empty() else ", ".join(levels.keys().map(func(k): return "%s %d" % [k, levels[k]]))
			var c := SimData.churn_return(res.pack.forms, levels, churn_boxes)
			print("  %-28s %7.3f %7.3f %6d" % [label, c["return"], c.return_fees, c.fee])
	if push_boxes > 0:
		print("\nALL IN: windows of %d, %d boxes a form, no perks (P: the next window's printed prizes reach the bar, the form's share of one that paid):" % [Catalog.WINDOW, push_boxes])
		for row in SimData.push_odds(res.pack.forms, push_boxes):
			print("  %-10s share %3d%%  P %.3f  (%d windows)" % [row.form, row.share, row.p, row.windows])
	if form_boxes > 0:
		print("\neach form in the run's model (its shape), %d boxes, no perks:" % form_boxes)
		print("  %-10s %7s %9s %7s %8s" % ["form", "return", "win/100", "tops", "sd $"])
		for row in SimData.form_table(res.pack.forms, form_boxes):
			print("  %-10s %7.3f %9.1f %7.2f %8.2f" % [row.form, row["return"], row.winners, row.tops, row.sd])
	get_tree().quit(0 if problems.is_empty() else 1)


## Plays seeds BASE-0 .. BASE-(runs-1) for each bot and writes the fixture at `path`.
## Returns the exit code.
func _write_baseline(path: String, bots: Array, runs: int, forms: Array, config: RunConfig) -> int:
	var out := {}
	for bot in bots:
		if not RunSim.BOTS.has(bot) and not SimBots.PROBES.has(bot):
			print("unknown bot: " + str(bot))
			return 1
		var t0 := Time.get_ticks_msec()
		var rows := []
		for i in runs:
			rows.append(RunSim.baseline_row(RunSim.play(bot, forms, "BASE-%d" % i, config)))
		out[bot] = rows
		print("baseline %s: %d runs, %.1f s" % [bot, runs, (Time.get_ticks_msec() - t0) / 1000.0])
	var file_path := _file_path(path)
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + file_path)
		return 1
	f.store_string(JSON.stringify({"seed_prefix": "BASE", "runs": runs, "bots": out}, "\t") + "\n")
	f.close()
	print("wrote " + file_path)
	return 0


## --probes: every probe of SimProbes run and printed, PASS or FAIL each. Returns the
## exit code: 1 if any failed.
func _probes(runs: int, boxes: int, forms: Array) -> int:
	print("probes (SimProbes, the adversarial layer): %d runs a probe bot, %d boxes a column at fixed perks" % [runs, boxes])
	var failed := []
	for p in SimProbes.all():
		var t0 := Time.get_ticks_msec()
		var r := SimProbes.run(p.name, forms, runs, boxes)
		print("
%s: %s" % [p.name, p.rule])
		print("  how: " + p.how)
		print(r.text)
		print("  %s %s (%.1f s)" % [p.name, "PASS" if r.ok else "FAIL", (Time.get_ticks_msec() - t0) / 1000.0])
		if not r.ok:
			failed.append(p.name)
	print("
probes: %s" % ("all passed" if failed.is_empty() else "FAILED: " + ", ".join(failed)))
	return 0 if failed.is_empty() else 1


## The ordering's comparisons among the bots run (`rates`: bot -> percent cleared):
## each bot of a rank against every bot of the nearest rank below that was run, and
## borrow <= gamble. Returns {marks: {bot: "yes" / "no"} (no: one of its comparisons
## fails; a bot in none has no mark), lines: what to print (the comparisons that fail,
## the ones that could not be made)}.
static func _ordering(rates: Dictionary) -> Dictionary:
	var marks := {}
	var fails := []
	var made := 0
	var mark := func(bot: String, ok: bool) -> void:
		if not ok:
			marks[bot] = "no"
		elif not marks.has(bot):
			marks[bot] = "yes"
	for i in RANKS.size():
		var below := []
		for j in range(i + 1, RANKS.size()):
			below = RANKS[j].filter(func(b): return rates.has(b))
			if not below.is_empty():
				break
		for a in RANKS[i]:
			if not rates.has(a):
				continue
			for b in below:
				var ok: bool = rates[a] > rates[b]
				made += 1
				mark.call(a, ok)
				mark.call(b, ok)
				if not ok:
					fails.append("%s %.1f%% <= %s %.1f%%" % [a, rates[a], b, rates[b]])
	if rates.has("borrow") and rates.has("gamble"):
		var ok: bool = rates.borrow <= rates.gamble
		made += 1
		mark.call("borrow", ok)
		mark.call("gamble", ok)
		if not ok:
			fails.append("borrow %.1f%% > gamble %.1f%%" % [rates.borrow, rates.gamble])
	var lines := []
	var missing := []
	for rank in RANKS:
		for b in rank:
			if not rates.has(b):
				missing.append(b)
	if made > 0:
		lines.append("ordering lines > build > perks > gamble, borrow, blind, skip; borrow <= gamble: %s" % (
			"holds (%d comparisons)" % made if fails.is_empty() else "fails: " + "; ".join(fails)))
	if not missing.is_empty():
		lines.append("ordering: not run, so not compared: %s%s" % [", ".join(missing),
			"" if made > 0 else " (no comparison could be made)"])
	return {"marks": marks, "lines": lines}


## A bot's lines under the table: its spec, the Wilson interval, the deaths by layer,
## the carry; with `detail` the trigger table and the death blocks.
func _print_bot(s: Dictionary, detail: bool) -> void:
	print("\n" + SimBots.describe(SimBots.spec(s.bot)))
	var stop := ", stopped at %d" % s.stopped if int(s.stopped) > 0 else ""
	print("  cleared %.1f%%, 95%% interval %.1f-%.1f%% (%d runs%s)" % [s.cleared * 100.0, s.wilson[0] * 100.0,
		s.wilson[1] * 100.0, s.runs, stop])
	var d := []
	for l in s.deaths.size():
		d.append("L%d %.1f%%" % [l + 1, s.deaths[l] * 100.0])
	print("  died: " + ", ".join(d))
	var c := []
	for k in s.carry.size():
		var row: Dictionary = s.carry[k]
		if int(row.n) > 0:
			c.append("%d>%d median %.2f, >=1 in %.0f%% (%d)" % [k + 1, k + 2, row.median, row.at_least_1 * 100.0, row.n])
		else:
			c.append("%d>%d none" % [k + 1, k + 2])
	print("  carry (cash / next due): " + "; ".join(c))
	if not detail:
		return
	var rd: Dictionary = s.get("rounds", {})
	var ud: Dictionary = s.get("upgrades", {})
	print("  rounds a run: morning %.1f, reward %.1f; rerolls %.2f (free %.2f); upgrades: shelf %.2f, reward %.2f" % [
		float(rd.get("morning", 0.0)), float(rd.get("reward", 0.0)), float(rd.get("rerolls", 0.0)),
		float(rd.get("free_rerolls", 0.0)), float(ud.get("shelf", 0.0)), float(ud.get("reward", 0.0))])
	var cat := Catalog.standard()
	if not s.triggers.is_empty():
		print("  %-12s %5s %5s %8s %8s %6s  %5s %5s %5s  %5s %5s %5s" % ["perk", "held", "day", "fired/r", "/100 tk", "mean%",
			"L1", "L2", "L3", "D1", "D2", "D3"])
	for t in s.triggers:
		var by := []
		for v in t.by_layer:
			by.append("%4.0f%%" % (v * 100.0) if v >= 0.0 else "    -")
		var dealt := []
		var shelf := Catalog.kind(cat.perk(t.id)) == "shelf"   # never dealt
		for v in t.get("offered_by", []):
			dealt.append("%4.0f%%" % (v * 100.0) if v >= 0.0 and not shelf else "    -")
		var layers := "  " + " ".join(by) + "  " + " ".join(dealt)
		if t.held <= 0.0:
			print("  %-12s %4.0f%% %5s %8s %8s %6s%s" % [t.id, 0.0, "-", "-", "-", "", layers])
			continue
		var fired := "-" if t.per_run < 0 else "%.1f" % t.per_run
		var per := "-" if t.per_100 < 0 else "%.2f" % t.per_100
		var pct := "" if t.pct < 0 else "%.1f" % t.pct
		var won := "" if t.won < 0 else "  won %.1f/r" % t.won
		print("  %-12s %4.0f%% %5.1f %8s %8s %6s%s%s" % [t.id, t.held * 100.0, t.day, fired, per, pct, layers, won])
	for b in s.death_blocks:
		var sets := []
		for st in b.sets:
			sets.append("%s %.0f%%" % [st[0], st[1] * 100.0])
		print("  died in L%d (%d): median cash $%d, short $%d, shifts %d, tickets %d; perks: %s" % [b.layer, b.n,
			b.cash, b.short, b.shifts, b.tickets, " | ".join(sets)])


## --given: the given-cards test of each line in `lines` (SimReport.given), printed.
func _given(lines: Array, runs: int, prefix: String, forms: Array, config: RunConfig) -> void:
	print("given cards (docs/roadmap.md M9.8 step 1 stage 3): %d runs a line, seeds %s-0 .. %s-%d" % [runs, prefix, prefix, runs - 1])
	print("line arm: the line bot holding its core, buying no perks; control: blind holding the same")
	var verdicts := []
	for line in lines:
		var t0 := Time.get_ticks_msec()
		var g := SimReport.given(line, forms, runs, prefix, config)
		var core := []
		for id in g.given:
			core.append("%s %d" % [id, g.given[id]])
		print("\n%s: %s (%.1f s)" % [line, ", ".join(core), (Time.get_ticks_msec() - t0) / 1000.0])
		var sig: Array = SimBots.SIGNATURE[line]
		print("  %-8s %8s %7s %8s %12s" % ["arm", "tickets", "return", "cleared", "%s %s/100" % [sig[1], "pct" if sig[0] == "fired_pct" else "fired"]])
		for arm in ["line", "control"]:
			var a: Dictionary = g.arms[arm]
			print("  %-8s %8.0f %7.3f %7.1f%% %12.3f" % [arm, a.tickets, a["return"], a.cleared * 100.0, a.signature])
		var c1: Dictionary = g.criteria[0]
		print("  1 fired: every given perk fired (or used) in >= %.0f%% of runs; a card the control is also under that is judged against the control" % (SimReport.FIRED_MIN * 100.0))
		for row in c1.rows:
			if row.how == "-":
				print("    %-12s not judged (no counter, no use to count)" % row.id)
			elif row.rule == "90%":
				print("    %-12s %s, rule 90%%: line %.0f%% (control %.0f%%)  %s" % [row.id, row.how, row.line * 100.0, row.control * 100.0, "PASS" if row.pass else "FAIL"])
			else:
				print("    %-12s %s, rule against the control: line %.0f%%, control %.0f%%, paired %+.3f, 95%% %+.3f to %+.3f  %s" % [row.id, row.how,
					row.line * 100.0, row.control * 100.0, row.diff, row.low, row.high, "PASS" if row.pass else "FAIL"])
		print("    %s%s" % ["PASS" if c1.pass else "FAIL", "" if c1.missing.is_empty() else " (short: %s)" % ", ".join(c1.missing)])
		var c2: Dictionary = g.criteria[1]
		var how_play := "level with the control"
		if c2.verdict == "better":
			how_play = "better by %+.4f, 95%% %+.4f to %+.4f" % [c2.mean, c2.low, c2.high]
		elif c2.verdict == "worse":
			how_play = "worse by %+.4f, 95%% %+.4f to %+.4f" % [c2.mean, c2.low, c2.high]
		elif c2.verdict == "none":
			how_play = "no seed to pair"
		print("  2 play: return per dollar: line %.3f, control %.3f; paired by seed (%d): mean %+.4f, 95%% %+.4f to %+.4f: %s" % [c2.line,
			c2.control, c2.n, c2.mean, c2.low, c2.high, how_play])
		print("    %s" % ("PASS" if c2.pass else "FAIL"))
		var rd: Dictionary = g.reading
		print("  reading (no verdict), how much play at the machine weighs: %s %s per 100 tickets, line %.3f, control %.3f, x%.2f" % [sig[1],
			"percent added" if sig[0] == "fired_pct" else "firings", rd.line, rd.control, rd.x])
		var marks := []
		for c in g.criteria:
			marks.append("%s %s" % [c.name, "PASS" if c.pass else "FAIL"])
		verdicts.append("%-8s %s  (%s)" % [line, "PASS" if g.pass else "FAIL", ", ".join(marks)])
	print("\nverdicts:")
	for v in verdicts:
		print("  " + v)


## --reach: the deal's ceiling of each line in `lines` (SimReport.reach) at each count
## of `rerolls` a morning round (--rerolls=, default 0 to 3), printed.
func _reach(lines: Array, runs: int, prefix: String, forms: Array, config: RunConfig, slots: String,
		rerolls: Array = [0, 1, 2, 3]) -> void:
	print("reach, the deal's ceiling (docs/roadmap.md 十二.3; money left out): %d runs a line and reroll count, seeds %s-0 .. %s-%d%s" % [
		runs, prefix, prefix, runs - 1, slots])
	print("the bot: $%d in the pocket, works every day (each layer paid on its last day: one reward round a layer), buys the shelf perks of the line's core, takes from every round the first core card it lacks; on a morning round with none, up to N paid rerolls (free ones, --set=free_rerolls, on top)" % SimBots.REACH_CASH)
	for line in lines:
		var t0 := Time.get_ticks_msec()
		var rows := []
		for n in rerolls:
			rows.append(SimReport.reach(line, forms, runs, prefix, n, config))
		var first: Dictionary = rows[0]
		var shelf: Array = SimBots.reach_spec(line, 0).params.shelf
		print("\n%s: core %s%s; engines %s (%.1f s)" % [line, ", ".join(first.core),
			"" if shelf.is_empty() else " (shelf bought: %s)" % ", ".join(shelf), ", ".join(first.engines),
			(Time.get_ticks_msec() - t0) / 1000.0])
		print("  %-7s %5s %5s %5s   %5s %5s %5s   %7s %6s   %7s %8s %6s" % ["rerolls", "core1", "core2", "core3", "eng1", "eng2",
			"eng3", "done at", "never", "rr/run", "$ a run", "rounds"])
		for r in rows:
			var done := "-" if int(r.done) < 0 else str(int(r.done))
			print("  %-7d %s   %s   %7s %5.0f%%   %7.2f %8.0f %6.1f" % [r.rerolls, _pcts(r.whole), _pcts(r.engine), done,
				r.never * 100.0, r.rerolls_run, r.cost, r.rounds])
		print("  each core card held by the end of layer 1 / 2 / 3, percent of runs, at %s rerolls:" % ", ".join(rerolls.map(func(n): return str(n))))
		for id in first.core:
			var parts := []
			for r in rows:
				var c: Array = r.cards[id]
				parts.append("/".join(c.map(func(v): return "-" if v < 0.0 else "%.0f" % (v * 100.0))))
			print("    %-12s %s" % [id, "   ".join(parts)])


## Three shares (a layer each) as "  56%" columns, "-" for a layer none played.
static func _pcts(v: Array) -> String:
	var out := []
	for x in v:
		out.append("    -" if x < 0.0 else "%4.0f%%" % (x * 100.0))
	return " ".join(out)


## --variants: each line in `lines` by its own spec and by every named variant
## (SimBots.VARIANTS), a row each, paired with the bot's own spec; the best by clear
## rate (then return) named.
func _variants(lines: Array, runs: int, prefix: String, forms: Array, config: RunConfig, detail: bool, slots := "") -> void:
	print("variants: %d runs each, seeds %s-0 .. %s-%d%s (paired: the variant less the bot's own spec)" % [runs, prefix,
		prefix, runs - 1, slots])
	for line in lines:
		print("\n%-20s %7s %13s %7s %7s %5s %7s  %s" % ["bot", "cleared", "95%", "L1", "return", "perks", "rerolls", "paired"])
		var own := SimReport.summary(SimBots.spec(line), forms, runs, prefix, config)
		var rows := [[line + "/own", own, {}]]
		var names: Array = SimBots.VARIANTS.get(line, {}).keys()
		for v in names:
			var s := SimReport.summary(SimBots.spec(line, SimBots.VARIANTS[line][v]), forms, runs, prefix, config)
			rows.append(["%s/%s" % [line, v], s, SimBots.VARIANTS[line][v]])
		var best: Array = rows[0]
		var decided := "clear rate"
		for row in rows:
			var s: Dictionary = row[1]
			var p := SimReport.paired(s, own)
			var pair := "" if row[0] == line + "/own" else "%+.1f points, 95%% %+.1f to %+.1f" % [p.diff * 100.0, p.low * 100.0, p.high * 100.0]
			print("%-20s %6.1f%% %5.1f-%5.1f%% %6.1f%% %7.3f %5.1f %7.2f  %s" % [row[0], s.cleared * 100.0, s.wilson[0] * 100.0,
				s.wilson[1] * 100.0, s.layer_rates[0] * 100.0, s["return"], s.perks, float(s.rounds.get("rerolls", 0.0)), pair])
			var b: Dictionary = best[1]
			var by := ""
			if s.cleared > b.cleared:
				by = "clear rate"
			elif s.cleared == b.cleared:
				if s.layer_rates[0] > b.layer_rates[0]:
					by = "the layer-1 rate, a tie on clear rate"
				elif s.layer_rates[0] == b.layer_rates[0] and s["return"] > b["return"]:
					by = "the return, a tie on clear and layer-1 rate"
			if by != "":
				best = row
				decided = by
		print("best of %s by clear rate: %s (decided by %s)" % [line, best[0], decided])
		if detail:
			for row in rows:
				print("  %s: %s" % [row[0], str(row[2]) if not row[2].is_empty() else SimBots.describe(SimBots.spec(line))])


## A path from the command line as a file path (res://, user:// or a file path; a
## relative path is from the project folder).
static func _file_path(path: String) -> String:
	if not path.contains("://") and path.is_relative_path():
		return ProjectSettings.globalize_path("res://").path_join(path)
	return path


## --save: every bot's per-seed outcomes and headline numbers, as JSON, with the
## config's upgrade slots (--upgrades).
func _save(path: String, prefix: String, runs: int, rows: Array, shelf_upgrades: int, overrides: Dictionary) -> void:
	var bots := {}
	for row in rows:
		var s: Dictionary = row[1]
		bots[row[0]] = {"runs": s.runs, "layers": s.layers, "outcomes": s.outcomes, "cleared": s.cleared,
			"wilson": s.wilson, "layer_rates": s.layer_rates, "days": s.days, "tickets": s.tickets,
			"return": s["return"], "return_fees": s.return_fees, "perks": s.perks, "stopped": s.stopped,
			"rounds": s.rounds, "upgrades": s.upgrades}
	var f := FileAccess.open(_file_path(path), FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + _file_path(path))
		return
	f.store_string(JSON.stringify({"seed_prefix": prefix, "runs": runs, "shelf_upgrades": shelf_upgrades,
		"overrides": overrides, "bots": bots}, "\t") + "\n")
	f.close()
	print("\nsaved " + _file_path(path))


## Overrides ({key: value}) for a line of text: "none" (the standard config) or each
## key=value.
static func _overrides_text(overrides: Dictionary) -> String:
	if overrides.is_empty():
		return "none (the standard config)"
	var parts := PackedStringArray()
	for key in overrides:
		parts.append("%s=%s" % [key, str(overrides[key])])
	return ", ".join(parts)


## --against: each bot run now and in the saved file, on the same seeds, paired; the
## overrides of both (--set) printed first.
func _against(path: String, prefix: String, rows: Array, overrides: Dictionary) -> void:
	var saved = JSON.parse_string(FileAccess.get_file_as_string(_file_path(path)))
	if not saved is Dictionary or not saved.has("bots"):
		print("\nagainst %s: cannot read it" % path)
		return
	print("\nagainst %s (A: now, B: saved; seeds %s; shelf upgrade slots there: %s):" % [path, saved.get("seed_prefix", "?"),
		str(int(saved.shelf_upgrades)) if saved.has("shelf_upgrades") else "not saved"])
	var there = saved.get("overrides")
	print("  overrides: A %s; B %s" % [_overrides_text(overrides),
		_overrides_text(there) if there is Dictionary else "not saved (a file from before --set)"])
	for row in rows:
		var bot: String = row[0]
		var s: Dictionary = row[1]
		var old = saved.bots.get(bot)
		if old == null:
			print("  %-8s not in the file" % bot)
			continue
		if str(saved.get("seed_prefix", "")) != prefix or int(old.get("runs", 0)) != int(s.runs):
			print("  %-8s not paired: seeds %s, %d runs there" % [bot, saved.get("seed_prefix", "?"), int(old.get("runs", 0))])
			continue
		var p := SimReport.paired(s, old)
		if p.is_empty():
			print("  %-8s not paired" % bot)
			continue
		print("  %-8s %.1f%% vs %.1f%%: only A %d, only B %d, both %d, neither %d; A - B %+.1f points, 95%% %+.1f to %+.1f" % [
			bot, s.cleared * 100.0, float(old.get("cleared", 0.0)) * 100.0, p.only_a, p.only_b, p.both, p.neither,
			p.diff * 100.0, p.low * 100.0, p.high * 100.0])
