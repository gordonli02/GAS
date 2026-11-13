extends "res://tests/test_case.gd"
## The run simulator (RunSim and src/sim/): bots play whole runs by the game's own rules.
## The numbers themselves are looked at with tools/sim_runs; here, that the bots end
## every run with a balanced ledger, that the work-only rule holds through them, that
## the churn exploit (FIRST PULL x REGULAR) does not pay, that summary() carries
## what the roadmap's bots table is measured by, and the measuring tools of M9.8 step 1
## stage 2 (the perks' trigger counts, the deaths, the carry, the common dice, the
## Wilson interval and the paired comparison) and stage 3 (the given-cards test's
## mechanics, the line bots' blocks, their variants).


func test_work_bot_clears_on_the_last_day() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var r := RunSim.play("work", pack.forms, "W-1")
	eq(r.status, RunState.CLEARED, "works every day: cleared")
	eq(r.cash, int(RunConfig.standard().work_line()[2].spare), "with the line's few dollars over (whole-dollar wages)")
	eq(r.tickets, 0, "no tickets")
	eq(r.days, 18, "every day of the three layers")


func test_bots_finish_and_balance() -> void:
	var pack := core_pack()
	if pack == null:
		return
	check(RunSim.BOTS.has("gamble") and not RunSim.BOTS.has("mixed"), "mixed became gamble")
	for line in SimBots.SPECS:
		check(RunSim.BOTS.has(line) or SimBots.PROBES.has(line), "%s is a bot" % line)
		var s := SimBots.spec(line)
		for id in s.params.perks + s.params.shelf:
			check(not Catalog.standard().perk(id).is_empty(), "%s: %s is in the catalog" % [line, id])
			check(not Catalog.meta(Catalog.standard().perk(id)), "%s: %s is sold in a run (not parked for M13)" % [line, id])
	var n := 6 if full else 2
	for bot in RunSim.BOTS + SimBots.PROBES:
		if bot == "work":
			continue
		for i in n:
			var r := RunSim.play(bot, pack.forms, "B-%d" % i)
			check([RunState.CLEARED, RunState.FAILED].has(r.status), "%s %d: the run ends" % [bot, i])
			check(r.balanced and r.cash >= 0, "%s %d: ledger balanced" % [bot, i])
			if r.status == RunState.CLEARED:
				eq(int(r.stats.layers_cleared), 3, "%s %d: three layers paid" % [bot, i])
	var a := RunSim.play("blind", pack.forms, "B-0")
	var b := RunSim.play("blind", pack.forms, "B-0")
	eq(b, a, "the same seed plays the same run")


## This fixture freezes the bots before the M9.8 refactor (docs/roadmap.md, M9.8 step 1,
## stage 0): each bot's first runs, seeds BASE-0 .., must replay exactly. If a number
## change is meant, regenerate it (a run is deterministic) with
##   godot --headless --path . res://tools/sim_runs.tscn -- --baseline=tests/fixtures/sim_baseline.json
## (--baseline-runs=N for another count) and say why in the commit.
func test_bots_match_the_baseline() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/sim_baseline.json"))
	if not check(fixture is Dictionary, "sim_baseline.json parses"):
		return
	var prefix: String = fixture.seed_prefix
	var k := int(fixture.runs) if full else mini(3, int(fixture.runs))
	for bot in fixture.bots:
		var rows: Array = fixture.bots[bot]
		for i in mini(k, rows.size()):
			var got := RunSim.baseline_row(RunSim.play(bot, pack.forms, "%s-%d" % [prefix, i]))
			var want: Dictionary = rows[i]
			for field in want:
				var a = got.get(field)
				var b = want[field]
				if b is float:
					b = int(b)
				eq(a, b, "%s %s-%d: %s" % [bot, prefix, i, field])
			eq(got.size(), want.size(), "%s %s-%d: same fields" % [bot, prefix, i])


## G, 2026-11-07: the slot takes coins under the smallest bill, and every bot asks the
## slot's rule before going to the machine, so no bot spends a day there buying nothing
## (before, the coins under a bill kept the plain bots at the machine for nothing).
func test_bots_never_stand_at_the_machine_unable_to_buy() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var n := 8 if full else 3
	for bot in RunSim.BOTS + SimBots.PROBES:
		if bot == "work":
			continue
		var idle := 0
		for i in n:
			idle += int(RunSim.play(bot, pack.forms, "ID-%d" % i).idle_days)
		eq(idle, 0, "%s: no day at the machine without a ticket bought (%d runs)" % [bot, n])
	# The rule itself: coins under the smallest bill buy, under one ticket they do not.
	var e := Economy.new()
	e.bills = RunConfig.bills(5)
	e.cash = 24
	check(SimRun.can_buy(e, 5), "$24 under a $25 bill: four tickets of coins")
	e.cash = 4
	check(not SimRun.can_buy(e, 5), "$4 under a $5 ticket: nothing")
	e.credit = 1
	check(SimRun.can_buy(e, 5), "$4 of coins and $1 of credit: one ticket")
	var fed := Economy.new()
	fed.bills = RunConfig.bills(5)
	fed.cash = 24
	fed.start_cash = 24
	SimRun.feed(fed, 125, 5)
	eq(fed.credit, 20, "the bot feeds the coins: four tickets")
	eq(fed.cash, 4, "the rest stays in the pocket")
	check(fed.balanced(), "balanced")


func test_churn_does_not_pay() -> void:
	# FIRST PULL x REGULAR (docs/perk_research.md 5.11): 20 tickets a box, then a new
	# box; the fee's floor keeps it at 1 or under, counted with the fees. Through
	# SimProbes: the fixed perks, and whole runs of the churn bot holding both perks.
	var pack := core_pack()
	if pack == null:
		return
	var boxes := 60 if full else 20
	var r := SimProbes.run("churn", pack.forms, 60 if full else 20, boxes)
	note(r.text)
	check(r.ok, "the churn probe holds")
	var n: Dictionary = r.numbers
	check(n.whole_return_fees <= 1.0, "the churn bot holding FIRST PULL 2 + REGULAR 2: return with fees is 1 or under (%.3f)" % n.whole_return_fees)
	eq(n.sets.size(), SimData.CHURN_SETS.size(), "every churn set is checked")
	for row in n.sets:
		check(row.return_fees <= 1.0, "%s: return with fees is 1 or under (%.3f)" % [str(row.levels), row.return_fees])
	var fixed: Dictionary = n.sets[n.sets.size() - 1]
	eq(fixed.levels, {"firstpull": 2, "regular": 2}, "the last set is FIRST PULL 2 + REGULAR 2")
	eq(fixed.fee, 100, "the fee is the floor")
	check(fixed["return"] > 2.0, "FIRST PULL pays on the first twenty (%.3f)" % fixed["return"])
	check(fixed.return_fees <= 1.0, "but not once the fee is counted (%.3f)" % fixed.return_fees)
	# The bot really holds the perks (before `given`, it never held FIRST PULL in a run).
	var spec := SimProbes.churn_given_spec()
	eq(spec.params.given, {"firstpull": 2, "regular": 2}, "the probe's bot is given FIRST PULL 2 + REGULAR 2")
	check(SimBots.PROBES.has("churn") and not SimBots.NAMES.has("churn"), "churn is a probe bot, not a strategy bot")
	check(not SimProbes.find("churn").is_empty() and SimProbes.find("nobody").is_empty(), "find: a probe by name")


func test_summary_carries_the_targets_numbers() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var s := RunSim.summary("blind", pack.forms, 12 if full else 6, "SU")
	eq(s.layer_rates.size(), 3, "a conditional rate per layer")
	var product := 1.0
	for r in s.layer_rates:
		check(r >= 0.0 and r <= 1.0, "a conditional rate is a share (%.3f)" % r)
		product *= r
	check(absf(product - s.cleared) < 1e-6, "the three multiply to the overall (%.4f, %.4f)" % [product, s.cleared])
	eq(s.best.size(), 3, "the 50th, 90th and 99th percentiles of the best prize")
	var line := RunSim.summary("small", pack.forms, 4, "SU")
	for t in line.triggers:
		eq(t.by_layer.size(), 3, "%s: a holding share a layer (拿得到)" % t.id)
		check(t.by_layer[0] >= 0.0 and t.by_layer[0] <= 1.0, "%s: layer 1 was played by every run (%.2f)" % [t.id, t.by_layer[0]])
	check(s.best[0] <= s.best[1] and s.best[1] <= s.best[2], "they do not decrease: %s" % str(s.best))
	check(s.best[0] > 0, "every run wins something")
	eq(SimReport.percentiles([5, 1, 4, 2, 3], [50, 90, 99]), [3, 5, 5], "nearest rank")
	eq(SimReport.percentiles([], [50]), [0], "nothing: 0")


func test_all_in_wins_about_half() -> void:
	# G (2026-11-07): a push wins about half the time on every form, the x3 kept; each
	# form's bar (Catalog.ALL_IN_SHARE) was found with push_odds on 400 boxes of the
	# run's small boxes (M9.7). Here other seeds: the blind P within 0.45 to 0.55 on
	# every form but two. Big Catch and Ka-Bawk! pay on so few tickets (4.7 and 2.6 in
	# 100) that a window of ten prints anything only 0.38 and 0.23 of the time, so no
	# bar gets them to half: they only have to keep their floor (a rule change is for G).
	var pack := core_pack()
	if pack == null:
		return
	# Bars measured at the run's payout (0.735, G 2026-11-07), 800 to 1000 boxes a form:
	# the six read 0.45 to 0.53; Big Catch and Ka-Bawk! kept their bars and read 0.28
	# and 0.19 (0.30 and 0.16 on other seeds), so their floors have margin.
	const LOW := 0.45
	var capped := {"catch": 0.2, "kabawk": 0.12}
	var rows := SimData.push_odds(pack.forms, 400 if full else 250, "PT")
	eq(rows.size(), pack.forms.size(), "a row per form")
	for row in rows:
		note("ALL IN on %s: share %d%%, P %.3f (%d windows)" % [row.form, row.share, row.p, row.windows])
		if capped.has(row.form):
			check(row.p >= capped[row.form] and row.p <= 0.55, "%s: P %.3f (this form cannot reach half; at least %.2f)" % [row.form, row.p, capped[row.form]])
		else:
			check(row.p >= LOW and row.p <= 0.55, "%s: P %.3f within %.2f to 0.55" % [row.form, row.p, LOW])
		check(row.windows > 500, "%s: enough windows (%d)" % [row.form, row.windows])
	# The old bar (more than the window) was about a third or less.
	var old := {}
	for f in pack.forms:
		old[f.id] = 101
	for row in SimData.push_odds(pack.forms, 60, "PT", old):
		check(row.p < 0.4, "%s: more than the window was P %.3f" % [row.form, row.p])


func test_perks_raise_the_return() -> void:
	# M9: blind buying about breaks even; perks make a dollar of tickets pay back more.
	var pack := core_pack()
	if pack == null:
		return
	var n := 20 if full else 8
	var none := SimData.box_return(pack.forms, {}, n)
	var prizes := SimData.box_return(pack.forms, {"prizes": 3}, n)
	var luck := SimData.box_return(pack.forms, {"luck": 3}, n)
	var all := SimData.box_return(pack.forms, {"prizes": 3, "luck": 3, "closer": 2}, n)
	note("return per dollar: none %.3f, FAT PRIZES 3 %.3f, LUCKY STREAK 3 %.3f, all %.3f" % [none, prizes, luck, all])
	# G, 2026-11-07: blind, whole boxes bought out, the last sale included, about 0.78 a
	# dollar (the run's payout, RunConfig "payout", and a last sale of about 5% of a box).
	check(none > 0.65 and none < 0.92, "without perks about 0.78 (%.3f)" % none)
	check(prizes > none * 1.2, "FAT PRIZES 3 pays about 30%% more (%.3f)" % prizes)
	check(luck > none, "LUCKY STREAK pays more (%.3f)" % luck)
	check(all > prizes and all > luck, "together more still (%.3f)" % all)
	var snow := SimData.box_return(pack.forms, {"snowball": 1, "snow": 10}, n)
	check(snow > none * 2.0, "SNOWBALL after ten boxes: about x2.6 (%.3f)" % snow)


## RunState.fired (docs/roadmap.md 七.3): a perk fires when it changes a number, never
## for being held; the table is not saved.
func test_perks_fire_where_they_act() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var form: FormDef = null
	var top := -1
	var low := -1
	for f: FormDef in pack.forms:
		top = -1
		low = -1
		for i in f.tiers.size():
			if str(f.tiers[i].role) == "top" and top < 0:
				top = i
			if str(f.tiers[i].role) == "low" and low < 0:
				low = i
		if top >= 0 and low >= 0:
			form = f
			break
	if not check(form != null, "a form with a top and a small prize"):
		return
	var run := RunState.start(RunConfig.standard(), "FIRE", ["diner", "bar", "bingo"])
	var e := run.new_economy()
	var loser := {"no": 50, "prize": 0, "tier": -1}
	var jackpot := {"no": 50, "prize": int(form.tiers[top].prize), "tier": top}
	var small := {"no": 50, "prize": int(form.tiers[low].prize), "tier": low}
	run.pay_ticket(e, jackpot, form)
	run.pay_ticket(e, loser, form)
	check(run.fired.is_empty(), "no perk held: nothing fires (%s)" % str(run.fired))
	run.perks["bigfish"] = 1
	run.pay_ticket(e, small, form)
	run.pay_ticket(e, loser, form)
	eq(run.fired.get("bigfish", 0), 0, "BIG FISH held: a small prize and a loser do not fire it")
	run.pay_ticket(e, jackpot, form)
	eq(run.fired.get("bigfish", 0), 1, "BIG FISH: a top prize fires it")
	eq(run.fired.get("flare", 0), 0, "FLARE ONLY (the same effect) is counted apart")
	run.perks["scrap"] = 1
	run.pay_ticket(e, small, form)
	eq(run.fired.get("scrap", 0), 0, "SCRAP DEALER: a winner does not fire it")
	run.pay_ticket(e, loser, form)
	eq(run.fired.get("scrap", 0), 1, "SCRAP DEALER: a loser fires it")
	run.perks["pity"] = 1
	run.pay_ticket(e, loser, form)
	run.pay_ticket(e, loser, form)
	run.pay_ticket(e, small, form)
	eq(run.fired.get("pity", 0), 1, "DUE A WIN: a prize after losers fires it")
	eq(run.fired_pct.get("pity", 0), 3, "with what it added: three losers in a row at 1%")
	var m := run.new_machine(pack.forms, true)
	if check(m.last_sale > 0, "the first layer has a last-sale prize"):
		run.cleared_box(m)
		eq(run.fired.get("closer", 0), 0, "a last sale without CLOSER")
		run.perks["closer"] = 1
		run.apply(m)
		run.cleared_box(m)
		eq(run.fired.get("closer", 0), 1, "CLOSER: a last sale fires it")
	check(is_same(m.fired, run.fired), "the machine counts into the run's table")
	var d := run.to_dict()
	check(not d.has("fired") and not d.has("fired_pct"), "the counts are not saved")
	check(RunState.from_dict(d, RunConfig.standard()).fired.is_empty(), "a loaded run starts counting afresh")
	var blind := RunSim.play("blind", pack.forms, "FI-0")
	check(blind.fired.is_empty() and blind.perks.is_empty(), "blind holds nothing and nothing fires (%s)" % str(blind.fired))
	var small_bot := RunSim.play("small", pack.forms, "FI-0")
	for id in small_bot.perks:
		check(int(small_bot.perks[id].day) >= 1 and int(small_bot.perks[id].tickets) >= 0, "small: %s has its day and tickets" % id)


## SimRun.play's death report (七.5) and carry (十二.6).
func test_deaths_and_carry() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var died := RunSim.play("blind", pack.forms, "DE-0")
	if check(died.status == RunState.FAILED, "blind dies on DE-0"):
		check(int(died.death.layer) >= 1 and int(died.death.layer) <= 3, "a layer (%s)" % str(died.death.get("layer")))
		check(int(died.death.short) > 0, "it was short of what was due (%s)" % str(died.death.get("short")))
		check(int(died.death.day) >= 1, "a day of the layer")
		eq(died.carry.size(), int(died.death.layer) - 1, "a carry for each layer paid")
	var work := RunSim.play("work", pack.forms, "W-1")
	eq(work.status, RunState.CLEARED, "work clears")
	check(work.death.is_empty(), "a cleared run has no death")
	eq(work.carry.size(), 2, "two layers carried into")
	for c in work.carry:
		check(c >= 0.0 and c < 1.0, "the work line carries its few dollars (%.3f)" % c)


## The Wilson interval, the paired comparison, the early stop (七.6), on known answers.
func test_intervals_and_pairs() -> void:
	var w0 := SimReport.wilson(0, 10)
	check(absf(w0[0]) < 1e-9 and absf(w0[1] - 0.2775) < 1e-3, "0 of 10: 0 to 0.2775 (%s)" % str(w0))
	var w5 := SimReport.wilson(5, 10)
	check(absf(w5[0] - 0.2366) < 1e-3 and absf(w5[1] - 0.7634) < 1e-3, "5 of 10: 0.2366 to 0.7634 (%s)" % str(w5))
	eq(SimReport.wilson(0, 0), [0.0, 1.0], "no runs: anything")
	var a := {"layers": 3, "outcomes": [3, 3, 3, 0, 0, 0, 3, 0, 1, 2]}
	var b := {"layers": 3, "outcomes": [3, 0, 0, 3, 0, 0, 3, 0, 0, 0]}
	var p := SimReport.paired(a, b)
	eq([p.n, p.only_a, p.only_b, p.both, p.neither], [10, 2, 1, 2, 5], "the four counts (1 or 2 layers is not cleared)")
	# diff = (2 - 1) / 10; se = sqrt(3 - 1 / 10) / 10
	check(absf(p.diff - 0.1) < 1e-9, "A's rate less B's: 0.1")
	var half := 1.96 * sqrt(2.9) / 10.0
	check(absf(p.low - (0.1 - half)) < 1e-9 and absf(p.high - (0.1 + half)) < 1e-9, "the paired interval (%.4f, %.4f)" % [p.low, p.high])
	eq(SimReport.paired(a, {"layers": 3, "outcomes": [3]}), {}, "other seeds do not pair")
	var same := SimReport.paired(a, a)
	check(same.only_a == 0 and same.only_b == 0 and same.low == 0.0 and same.high == 0.0, "a summary against itself: no difference")
	var pack := core_pack()
	if pack == null:
		return
	# work clears every run: an interval wholly over a band of 0 to 50% stops at 100.
	var s := RunSim.summary("work", pack.forms, 150, "EA", null, [0.0, 0.5])
	eq(s.stopped, 100, "the early stop after the first chunk")
	eq(s.runs, 100, "every number of the runs played")
	eq(s.outcomes.size(), 100, "an outcome a run")


## The given-cards test's mechanics (M9.8 step 1 stage 3), not its verdicts: given perks
## are held from day 1 and cost nothing, with what they require; the line arm buys no
## perk; the control is blind holding the same; the report carries its two criteria (and the signature as a reading).
func test_given_cards() -> void:
	var run := RunState.start(RunConfig.standard(), "GV", ["diner", "bar", "bingo"])
	SimRun.give(run, {"hunter": 1})
	for id in ["hunter", "bigfish", "read1"]:
		eq(run.level(id), 1, "JACKPOT HUNTER given: %s held" % id)
	for id in run.perks:
		check(run.missing(id).is_empty(), "%s: its requirements are held" % id)
	eq(int(run.stats.perks), 0, "nothing counted as bought")
	var pack := core_pack()
	if pack == null:
		return
	for line in SimBots.GIVEN:
		var r := SimRun.play(SimBots.given_spec(line), pack.forms, "GV-0")
		for id in SimBots.GIVEN[line]:
			check(r.perks.has(id) and int(r.perks[id].day) == 1, "%s: %s held from day 1" % [line, id])
			check(r.held_by.size() >= 1 and r.held_by[0].has(id), "%s: %s held at the end of layer 1" % [line, id])
		eq(int(r.stats.perks), 0, "%s: the line arm buys no perk" % line)
		eq(int(r.stats.shop), 0, "%s: the given perks cost nothing" % line)
		check(r.balanced, "%s: the ledger balances" % line)
		var c := SimRun.play(SimBots.control_spec(line), pack.forms, "GV-0")
		eq(c, SimRun.play(SimBots.spec("blind", {"params": {"given": SimBots.GIVEN[line]}}), pack.forms, "GV-0"),
			"%s: the control is blind holding the same" % line)
	var g := SimReport.given("money", pack.forms, 2, "GV")
	eq(g.criteria.map(func(x): return x.name), ["fired", "play"], "two criteria")
	check(g.reading.has("x"), "the signature ratio is a reading")
	eq(g.arms.keys(), ["line", "control"], "two arms")
	eq(g.criteria[0].rows.size(), SimBots.GIVEN.money.size(), "a row per given perk")
	# The paired mean: [1, 2, 3] has mean 2, sd 1, half 1.96 / sqrt(3).
	var pm := SimReport.paired_mean([1.0, 2.0, 3.0])
	check(absf(pm.mean - 2.0) < 1e-9 and absf(pm.sd - 1.0) < 1e-9, "mean 2, sd 1 (%s)" % str(pm))
	check(absf(pm.low - (2.0 - 1.96 / sqrt(3.0))) < 1e-9 and absf(pm.high - (2.0 + 1.96 / sqrt(3.0))) < 1e-9, "the interval")
	eq(SimReport.paired_mean([]).n, 0, "none: n 0")
	# The new judging, on hand-made inputs: 20 seeds.
	var yes := []
	var no := []
	var some := []   # fired in 5 of 20
	for i in 20:
		yes.append(true)
		no.append(false)
		some.append(i < 5)
	var j := SimReport.judge_fired(yes, yes)
	check(j.pass and j.rule == "90%", "fired in all: passes by the 90 percent rule")
	j = SimReport.judge_fired(some, some)
	check(j.pass and j.rule == "against the control", "a rare card level with its control passes (%s)" % str(j))
	j = SimReport.judge_fired(no, some)
	check(not j.pass and j.rule == "against the control", "a rare card the line never gets, the control sometimes: fails (%s)" % str(j))
	j = SimReport.judge_fired(some, yes)
	check(not j.pass and j.rule == "90%", "under 90 percent with the control at 100 percent: fails by the 90 percent rule (%s)" % str(j))
	var low := []
	for i in 20:
		low.append(-0.1 + (0.001 if i % 2 == 0 else -0.001))
	var jr := SimReport.judge_return(low)
	check(not jr.pass and jr.verdict == "worse", "a return interval wholly below 0 fails (%s)" % str(jr))
	jr = SimReport.judge_return([0.1, -0.1, 0.05, -0.05])
	check(jr.pass and jr.verdict == "level", "a return interval spanning 0 passes (%s)" % str(jr))
	jr = SimReport.judge_return([0.1, 0.11, 0.09, 0.1])
	check(jr.pass and jr.verdict == "better", "a return interval wholly above 0: better (%s)" % str(jr))
	check(not SimReport.judge_return([]).pass, "no seed: no pass")


## The line bots' blocks (M9.8 step 1 stage 3), on states set by hand.
func test_line_blocks() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var run := RunState.start(RunConfig.standard(), "LB", ["diner", "bar", "bingo"])
	var e := run.new_economy()
	var m := run.new_machine(pack.forms, true)
	# clearing: the box already started (the fewest tickets left).
	var ctx := SimCtx.of(run, e, m, SimBots.spec("clearing"))
	m.boxes[3].cursor = 50
	eq(SimBlocks.column(ctx), 3, "clearing plays the started box")
	m.boxes[5].cursor = m.boxes[5].size - 10
	eq(SimBlocks.column(ctx), 5, "the one nearest its end")
	ctx.col = 5
	eq(SimBlocks.stay(ctx), 10, "never past the end of the box")
	# money: nothing over the floor ($100 here, at stake 1), nothing bought.
	var mc := SimCtx.of(run, e, m, SimBots.spec("money", {"params": {"floor": 100}}))
	mc.col = 0
	e.cash = 100
	eq(SimBlocks.stay(mc), 0, "money leaves at its floor")
	check(not SimBlocks.enter(mc), "and works rather than go to the machine at it")
	e.cash = 103
	eq(SimBlocks.stay(mc), 3, "and buys only what keeps the floor")
	e.cash = 200
	eq(SimBlocks.stay(mc), 5, "its batch above it")
	SimBlocks.feed(mc, 5)
	check(e.credit == 5 and e.cash == 195, "small bills: $5 fed for five tickets (credit %d, cash %d)" % [e.credit, e.cash])
	e.cash_out()
	# batch: the window closed, not half open.
	var bc := SimCtx.of(run, e, m, SimBots.spec("batch"))
	run.window_n = 3
	eq(SimBlocks.stay(bc), Catalog.WINDOW - 3, "batch buys the rest of the window")
	run.window_n = 0
	# The stop-loss: only while buying perks, never in the endgame.
	var sc := SimCtx.of(run, e, m, SimBots.spec("clearing", {"params": {"stop": 0.5}}))
	sc.day_money = 200
	e.cash = 90
	check(SimBlocks.stopped(sc), "lost more than half the day's money: stopped")
	run.day = run.days()
	check(not SimBlocks.stopped(sc), "the layer's last day: no stop-loss")
	run.day = 1
	var off := SimCtx.of(run, e, m, SimBots.given_spec("clearing", {"params": {"stop": 0.5}}))
	off.day_money = 200
	check(not SimBlocks.stopped(off), "perks off: no stop-loss")
	sc.spec = SimBots.spec("clearing", {"params": {"stop": 1.0}})
	check(not SimBlocks.stopped(sc), "stop 1: never")


## Common random numbers (七.6): the bots' dice are the seed's, so two bots on a seed
## draw the same column, and an unknown name plays blind's run exactly.
func test_bots_share_the_dice() -> void:
	var pack := core_pack()
	if pack == null:
		return
	for seed_text in ["CR-0", "CR-1", "CR-2"]:
		var cols := []
		for bot in ["blind", "borrow", "gamble"]:
			var run := RunState.start(RunConfig.standard(), seed_text, ["diner", "bar", "bingo"])
			var e := run.new_economy()
			var ctx := SimCtx.of(run, e, run.new_machine(pack.forms, true), SimBots.spec(bot))
			ctx.rng = SimRun.dice(seed_text)
			cols.append(SimBlocks.column(ctx))
		eq(cols[1], cols[0], "%s: borrow draws blind's first column" % seed_text)
		eq(cols[2], cols[0], "%s: gamble draws blind's first column" % seed_text)
	eq(RunSim.play("nobody", pack.forms, "CR-0"), RunSim.play("blind", pack.forms, "CR-0"), "an unknown bot plays blind's run")


## The bots' table (SimBots): every bot has a spec, every spec names only blocks and
## variants that exist (SimBlocks.VARIANTS) and only params a block reads (PARAMS); a
## spec is plain data, a fresh copy, and can be overridden by a named variant.
func test_bot_specs_are_data() -> void:
	eq(RunSim.BOTS, SimBots.NAMES, "RunSim.BOTS is the table's names")
	eq(SimBots.NAMES.size(), 12, "twelve strategy bots")
	eq(SimBots.PROBES, ["churn"], "one probe bot")
	for bot in SimBots.SPECS:
		check(SimBots.NAMES.has(bot) or SimBots.PROBES.has(bot), "%s: a spec for a named bot or a probe bot" % bot)
	for bot in SimBots.PROBES:
		check(not SimBots.NAMES.has(bot), "%s: a probe bot is not a strategy bot" % bot)
	for bot in SimBots.NAMES + SimBots.PROBES:
		var own: Dictionary = SimBots.SPECS.get(bot, {})
		check(SimBots.SPECS.has(bot), "%s has a spec" % bot)
		for k in own:
			check(["blocks", "params"].has(k), "%s: %s is blocks or params" % [bot, k])
		var blocks: Dictionary = own.get("blocks", {})
		for b in blocks:
			check(SimBlocks.VARIANTS.has(b), "%s: %s is a block" % [bot, b])
			check(SimBlocks.VARIANTS.get(b, []).has(blocks[b]), "%s: %s=%s is a variant" % [bot, b, blocks[b]])
		var params: Dictionary = own.get("params", {})
		for k in params:
			check(SimBots.PARAMS.has(k), "%s: %s is a param" % [bot, k])
		var s := SimBots.spec(bot)
		eq(s.name, bot, "%s: the spec carries its name" % bot)
		eq(s.blocks.size(), SimBlocks.VARIANTS.size(), "%s: every block resolved" % bot)
		eq(s.params.size(), SimBots.PARAMS.size(), "%s: every param resolved" % bot)
		check(SimBots.describe(s).begins_with(bot + ": "), "%s: printable (%s)" % [bot, SimBots.describe(s)])
	# A fresh copy; overrides lay a variant over the bot.
	var a := SimBots.spec("jackpot")
	a.params.forms.append("spur")
	eq(SimBots.spec("jackpot").params.forms, ["catch", "kabawk"], "changing a spec changes nothing in the table")
	var v := SimBots.spec("jackpot", {"params": {"share": 0.4}, "blocks": {"box": "churn"}})
	eq(v.params.share, 0.4, "an override's param")
	eq(v.blocks.box, "churn", "an override's block")
	eq(v.params.perks, ["bigfish", "pity", "hunter"], "the rest kept")
	eq(SimBots.describe(SimBots.spec("blind")), "blind: defaults", "blind is all defaults")
	# An unknown name: every default, as RunSim.play always treated one (blind's rules).
	var u := SimBots.spec("nobody")
	eq(u.blocks, SimBots.spec("blind").blocks, "unknown: blind's blocks")
	eq(u.params, SimBots.spec("blind").params, "unknown: blind's params")
	var pack := core_pack()
	if pack == null:
		return
	var r := RunSim.play("nobody", pack.forms, "U-0")
	check([RunState.CLEARED, RunState.FAILED].has(r.status) and r.balanced, "an unknown bot plays a whole run")
	var blind := SimBots.spec("blind")
	eq(SimRun.play(blind, pack.forms, "U-1"), RunSim.play("blind", pack.forms, "U-1"), "RunSim.play is SimRun.play of the spec")
	# The line bots' named variants (七.4), the given-cards sets and signatures.
	for line in SimBots.VARIANTS:
		check(SimBots.NAMES.has(line), "%s: variants of a bot" % line)
		var vs: Dictionary = SimBots.VARIANTS[line]
		check(vs.size() >= 3 and vs.size() <= 5, "%s: 3 to 5 variants (%d)" % [line, vs.size()])
		for name in vs:
			var o: Dictionary = vs[name]
			for k in o:
				check(["blocks", "params"].has(k), "%s/%s: %s is blocks or params" % [line, name, k])
			for b in o.get("blocks", {}):
				check(SimBlocks.VARIANTS.get(b, []).has(o.blocks[b]), "%s/%s: %s=%s is a variant" % [line, name, b, o.blocks[b]])
			for k in o.get("params", {}):
				check(SimBots.PARAMS.has(k), "%s/%s: %s is a param" % [line, name, k])
	for line in ["clearing", "jackpot", "small", "batch", "money"]:
		check(SimBots.VARIANTS.has(line) and SimBots.GIVEN.has(line) and SimBots.SIGNATURE.has(line), "%s: variants, given set, signature" % line)
		for id in SimBots.GIVEN.get(line, {}):
			check(not Catalog.standard().perk(id).is_empty(), "%s: given %s is in the catalog" % [line, id])
		var sig: Array = SimBots.SIGNATURE.get(line, ["", ""])
		check(["fired", "fired_pct"].has(sig[0]) and RunState.FIRED.has(sig[1]), "%s: the signature is a counted perk (%s)" % [line, str(sig)])
