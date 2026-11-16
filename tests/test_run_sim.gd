extends "res://tests/test_case.gd"
## The run simulator (RunSim and src/sim/): bots play whole runs by the game's own rules.
## The numbers themselves are looked at with tools/sim_runs; here, that the bots end
## every run with a balanced ledger, that the work-only rule holds through them, that
## the churn exploit (FIRST PULL x REGULAR) does not pay, that summary() carries
## what the roadmap's bots table is measured by, and the measuring tools of M9.8 step 1
## stage 2 (the perks' trigger counts, the deaths, the carry, the common dice, the
## Wilson interval and the paired comparison) and stage 3 (the given-cards test's
## mechanics, the line bots' blocks, their variants); and M9.8 step 2 stage 2 (paying for
## a reroll, a reward round's listed card, the bankroll rule, the deal's ceiling).


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


## The rounds probe (M9.8 step 2): a bot with plenty of cash that tries every card of
## every round, rerolling before and after, never gets more than one perk a round, nor
## rerolls a reward round.
func test_rounds_probe() -> void:
	var pack := core_pack()
	if pack == null:
		return
	eq(SimProbes.all().map(func(p): return p.name), ["churn", "rounds"], "two probes")
	var r := SimProbes.run("rounds", pack.forms, 12 if full else 4)
	note(r.text)
	check(r.ok, "the rounds probe holds")
	var n: Dictionary = r.numbers
	eq(n.over, 0, "no run took more perks than it was dealt rounds")
	eq(n.twice, 0, "no second card from a round")
	eq(n.reward_rerolls, 0, "no reward round rerolled")
	check(n.reward_rounds > 0 and n.taken > 0 and n.rerolls > 0, "it took cards, rerolled, and saw reward rounds (%s)" % str(n))
	eq(n.taken, n.rounds + n.reward_rounds, "with the cash for all of them, one card from every round")
	eq(SimProbes.rounds_spec().blocks.perks, "grab", "the probe's bot")


## How the bots meet the rounds (M9.8 step 2), and the measures of them: the perks dealt
## by the end of each layer (offered_by) and the rounds a run.
func test_bots_and_the_rounds() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var skip := RunSim.play("skip", pack.forms, "RO-0")
	eq(int(skip.stats.perks), 0, "skip takes no perk")
	eq(int(skip.stats.skipped_offers), int(skip.stats.rounds) + int(skip.stats.reward_rounds), "skip gives up every round it is dealt")
	var blind := RunSim.play("blind", pack.forms, "RO-0")
	eq(int(blind.stats.skipped_offers), 0, "blind gives up none (it walks away)")
	eq(blind.offered_by.size(), blind.held_by.size(), "offered_by beside held_by")
	check(not blind.offered_by[0].is_empty(), "perks were dealt in layer 1")
	eq(blind.rounds.morning, int(blind.stats.rounds), "the rounds a run")
	var perks := RunSim.play("perks", pack.forms, "RO-1")
	for l in perks.held_by.size():
		for id in perks.held_by[l]:
			if Catalog.kind(Catalog.standard().perk(id)) != "shelf":
				check(perks.offered_by[l].has(id), "perks: %s held at the end of layer %d was dealt by then" % [id, l + 1])
	var dealt_held := 0
	for id in perks.perks:
		if Catalog.kind(Catalog.standard().perk(id)) != "shelf":
			dealt_held += 1
	check(dealt_held > 0 and dealt_held <= int(perks.stats.rounds) + int(perks.stats.reward_rounds),
		"perks: no more dealt perks held than rounds dealt (%d)" % dealt_held)
	var s := RunSim.summary("small", pack.forms, 4, "RO")
	for t in s.triggers:
		eq(t.offered_by.size(), 3, "%s: a dealt share a layer" % t.id)
		check(t.offered_by[0] >= t.by_layer[0] or Catalog.kind(Catalog.standard().perk(t.id)) == "shelf",
			"%s: held by the end of layer 1 means dealt by then, for a dealt perk" % t.id)
	check(s.rounds.morning > 0.0, "morning rounds a run (%.1f)" % s.rounds.morning)


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
		check(vs.size() >= 3 and vs.size() <= 14, "%s: 3 to 14 variants (%d)" % [line, vs.size()])
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
	check(SimBots.VARIANTS.has("build"), "build has variants (the rerolls)")
	# The defaults the 300-run variants pass chose (M9.8 step 2, stage 2).
	var rerolls := {"clearing": 2, "jackpot": 0, "small": 2, "batch": 2, "money": 0}
	for line in rerolls:
		eq(SimBots.spec(line).params.work_held, 1, "%s banks" % line)
		eq(SimBots.spec(line).params.rerolls, rerolls[line], "%s rerolls %d a round" % [line, rerolls[line]])
		check(SimBots.VARIANTS[line].has("nobank") and not SimBots.VARIANTS[line].has("bank"), "%s: nobank, its old default" % line)
		check(SimBots.VARIANTS[line].has("reroll0") == (rerolls[line] > 0), "%s: reroll0 when it rerolls" % line)
		check(SimBots.VARIANTS[line].has("reroll2") == (rerolls[line] == 0), "%s: reroll2 when it does not" % line)
	for line in SimBots.VARIANTS:
		for name in ["reroll1", "reroll3", "reroll3t"]:
			check(SimBots.VARIANTS[line].has(name), "%s: a %s variant" % [line, name])
	# The items block (M9.8 step 3): its variants, the params it reads, each line's and
	# build's `use` and `usebuy` (and jackpot's `informant`); no bot uses items by default.
	eq(SimBlocks.VARIANTS.items, ["none", "use", "blind"], "items: none (the default), use, blind")
	for k in ["peek_min", "peek_scale", "happy_min", "slip_max", "coin_wait", "item_share", "item_list", "daily_items"]:
		check(SimBots.PARAMS.has(k), "%s is a param" % k)
	eq(float(SimBots.PARAMS.item_share), 0.0, "no item bought by default")
	eq(SimBots.PARAMS.daily_items, {}, "no daily items by default")
	for id in SimBots.PARAMS.item_list:
		check(not Catalog.standard().item(id).is_empty(), "item_list: %s is an item" % id)
	for f in SimBots.PARAMS.peek_min:
		check(float(SimBots.PARAMS.peek_min[f]) > 0.0, "peek_min: %s in winners per 100" % f)
	for bot in SimBots.NAMES + SimBots.PROBES:
		eq(SimBots.spec(bot).blocks.items, "none", "%s uses no item by default" % bot)
	for line in ["clearing", "jackpot", "small", "batch", "money", "build"]:
		var vs: Dictionary = SimBots.VARIANTS[line]
		check(vs.has("use") and vs.has("usebuy"), "%s: use and usebuy" % line)
		eq(SimBots.spec(line, vs.get("use", {})).blocks.items, "use", "%s/use uses its items" % line)
		eq(float(SimBots.spec(line, vs.get("use", {})).params.item_share), 0.0, "%s/use buys none" % line)
		check(float(SimBots.spec(line, vs.get("usebuy", {})).params.item_share) > 0.0, "%s/usebuy buys" % line)
	var inf := SimBots.spec("jackpot", SimBots.VARIANTS.jackpot.informant)
	check(inf.blocks.items == "use" and inf.params.shelf.has("informant"), "jackpot/informant buys INFORMANT and uses its items")
	for id in SimBots.GIVEN_ITEMS:
		check(not Catalog.standard().item(id).is_empty(), "GIVEN_ITEMS: %s is an item" % id)
	var gl := SimBots.given_spec("small", SimBots.VARIANTS.small.use, SimBots.GIVEN_ITEMS)
	check(gl.blocks.items == "use" and gl.params.daily_items == SimBots.GIVEN_ITEMS, "the line arm with items")
	var gc := SimBots.control_spec("small", SimBots.GIVEN_ITEMS)
	check(gc.blocks.items == "blind" and gc.params.daily_items == SimBots.GIVEN_ITEMS, "the control with items: blind")
	eq(SimBots.control_spec("small").blocks.items, "none", "the control without items uses none")
	eq(SimBots.merged({"params": {"a": 1, "b": 2}}, {"params": {"b": 3}, "blocks": {"items": "none"}}),
		{"blocks": {"items": "none"}, "params": {"a": 1, "b": 3}}, "merged: the second over the first")


## A morning (or, with `reward`, a reward) round set by hand: a fresh run at stake 1,
## the bot `spec` with `cash` in the pocket, the round's cards `offers`.
func _hand_round(forms: Array, spec: Dictionary, cash: int, offers: Array, reward := false) -> SimCtx:
	var run := RunState.start(RunConfig.standard(), "RR", ["diner", "bar", "bingo"])
	var e := run.new_economy()
	if cash > e.cash:
		e.bonus(cash - e.cash)
	elif cash < e.cash:
		e.pay(e.cash - cash)
	var ctx := SimCtx.of(run, e, run.new_machine(forms, true), spec)
	run.offers = offers.duplicate()
	run.offers_open = true
	run.offer_reward = reward
	run.offer_rerolls = 0
	return ctx


## M9.8 step 2, stage 2: paying for a reroll (SimBlocks._reroll). Only a morning round
## with no card the bot would take, never past `rerolls`, never over `reroll_share` of
## the cash, only when the cash left still buys a card it rerolls for; never a reward
## round; `rerolls` 0 never.
func test_rerolls() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var off := ["closer", "firstpull", "assembly"]   # none on build's list
	var rich := 100000
	var build := func(over: Dictionary) -> Dictionary: return SimBots.spec("build", {"params": over})
	var c := _hand_round(pack.forms, build.call({}), rich, off)
	SimBlocks._line_round(c)
	eq(int(c.run.stats.rerolls), 0, "rerolls 0 (the default): never")
	eq(int(c.run.stats.skipped_offers), 1, "the round given up for its item")
	for i in 4:
		c = _hand_round(pack.forms, build.call({"rerolls": 2, "reroll_share": 1.0}), rich, off)
		c.run.seed = "RR-%d" % i
		SimBlocks._line_round(c)
		var n := int(c.run.stats.rerolls)
		check(n >= 1 and n <= 2, "no card it wants: rerolls, at most 2 (%d)" % n)
		check(int(c.run.stats.perks) == 1 or n == 2, "it stops rerolling once a card it wants is up (%d rerolls)" % n)
		eq(int(c.counters.get("reroll_cost", 0)), [0, 20, 60][n], "what they cost: $20, then $40")
	c = _hand_round(pack.forms, build.call({"rerolls": 2, "reroll_share": 1.0}), rich, ["closer", "penny", "firstpull"])
	SimBlocks._line_round(c)
	check(int(c.run.stats.rerolls) == 0 and c.run.level("penny") == 1, "a card it wants is up: taken, no reroll")
	c = _hand_round(pack.forms, build.call({"rerolls": 2, "reroll_share": 0.0001}), rich, off)
	SimBlocks._line_round(c)
	eq(int(c.run.stats.rerolls), 0, "the price over reroll_share of the cash: no reroll")
	c = _hand_round(pack.forms, build.call({"rerolls": 2, "reroll_share": 1.0, "reserve": 0}), 25, off)
	SimBlocks._line_round(c)
	eq(int(c.run.stats.rerolls), 0, "$25: the $20 reroll would leave nothing to buy a card with: no reroll")
	c = _hand_round(pack.forms, build.call({"rerolls": 2, "reroll_share": 1.0}), rich, off, true)
	SimBlocks._line_round(c)
	eq(int(c.run.stats.rerolls), 0, "a reward round is never rerolled")
	# core, holding no engine (jackpot: BIG FISH $300, DUE A WIN $200 at stake 1).
	var jack := SimBots.spec("jackpot", {"params": {"rerolls": 2, "reroll_share": 1.0}})
	c = _hand_round(pack.forms, jack, rich, ["closer", "penny", "scrap"])
	SimBlocks._engine_round(c)
	check(int(c.run.stats.rerolls) >= 1 and int(c.run.stats.rerolls) <= 2, "core, no engine up: rerolls (%d)" % int(c.run.stats.rerolls))
	c = _hand_round(pack.forms, jack, 250, ["closer", "penny", "scrap"])
	SimBlocks._engine_round(c)
	check(int(c.run.stats.rerolls) >= 1, "$250: $230 left still pays DUE A WIN: rerolls")
	c = _hand_round(pack.forms, jack, 210, ["closer", "penny", "scrap"])
	SimBlocks._engine_round(c)
	eq(int(c.run.stats.rerolls), 0, "$210: $190 left pays no engine: no reroll")
	c = _hand_round(pack.forms, jack, rich, ["closer", "penny", "scrap"], true)
	SimBlocks._engine_round(c)
	eq(int(c.run.stats.rerolls), 0, "core: a reward round is never rerolled")
	# Whole runs: never more than `rerolls` a morning round; the count in the result.
	var any := 0
	for line in ["clearing", "jackpot", "small", "batch", "money", "build"]:
		for i in (3 if full else 1):
			var r := SimRun.play(SimBots.spec(line, SimBots.VARIANTS[line].reroll3), pack.forms, "RR-%d" % i)
			check(int(r.stats.rerolls) <= 3 * int(r.stats.rounds), "%s reroll3: at most 3 a morning round" % line)
			eq(int(r.rounds.rerolls), int(r.stats.rerolls), "%s: the rerolls in the result" % line)
			any += int(r.stats.rerolls)
			check(r.balanced, "%s reroll3: balanced" % line)
			var d := SimRun.play(SimBots.spec(line), pack.forms, "RR-%d" % i)
			var own := int(SimBots.spec(line).params.rerolls)
			check(int(d.stats.rerolls) <= own * int(d.stats.rounds), "%s: its own spec rerolls at most %d a round" % [line, own])
	check(any > 0, "the reroll variants reroll (%d)" % any)


## sim_runs --set=key=value,... (RunConfig.parse_set, apply_set, set_text): the
## upgrade slots and the dealing switches (starter, starter_cards, offer_bonus, deal1 ..
## deal3); an unknown key or a bad value is an error.
func test_set_overrides() -> void:
	var p := RunConfig.parse_set("starter=1, offer_bonus=1,shelf_upgrades=2,starter_cards=penny/scrap/consolation/closer,"
		+ "deal1=10/5/2,deal3=10/0/9")
	eq(p.error, "", "parsed")
	eq(p.set, {"starter": 1, "offer_bonus": 1, "shelf_upgrades": 2, "starter_cards": ["penny", "scrap", "consolation", "closer"],
		"deal1": [10, 5, 2], "deal3": [10, 0, 9]}, "each key with its type")
	var c := RunConfig.standard()
	c.apply_set(p.set)
	check(c.starter == 1 and c.offer_bonus == 1 and c.shelf_upgrades == 2, "put into the config")
	eq(c.starter_cards, ["penny", "scrap", "consolation", "closer"], "the starter pool")
	eq(c.starter_pool(), ["penny", "scrap", "consolation", "closer"], "in place of Catalog's")
	eq(c.deal[0].rarity, {"common": 10, "rare": 5, "legendary": 2}, "layer 1's weights")
	eq(c.deal[1], Catalog.DEAL[1], "layer 2 untouched")
	eq(c.deal[2].rarity, {"common": 10, "rare": 0, "legendary": 9}, "layer 3's weights")
	eq(c.deal[0].no_kinds, ["risk"], "layer 1's no_kinds stay Catalog's")
	eq(c.problems(), PackedStringArray(), "and it holds together")
	eq(RunConfig.standard().deal, Catalog.DEAL, "another config: Catalog's weights still")
	eq(RunConfig.set_text({"deal2": [10, 8, 4]}), "deal2=10/8/4 (standard 10/5/2)", "the text names the standard weights")
	eq(RunConfig.set_text({"starter_cards": ["penny", "closer"]}),
		"starter_cards=penny/closer (standard penny/scrap/consolation)", "and the standard pool")
	check(RunConfig.set_text({"starter": 1}).contains("starter=1 (standard 0)"), "the text names the standard value")
	eq(RunConfig.set_text({}), "", "no overrides: no text")
	eq(RunConfig.parse_set("").set, {}, "nothing given: nothing set")
	for bad in ["deal_bias=2", "free_rerolls=1", "reward_bias=2", "starter", "starter=1.5", "starter=-1", "payout=1",
			"deal1=10/5", "deal1=10/5/2/1", "deal1=0/0/0", "deal1=10/x/2", "deal1=10/-1/2", "deal4=10/5/2",
			"starter_cards=", "starter_cards=penny//scrap", "starter_cards=penny/"]:
		check(str(RunConfig.parse_set(bad).error) != "", "an error: %s" % bad)
	eq(RunConfig.parse_set("starter=1,starter=0").set, {"starter": 0}, "a key twice: the last")
	# A card that does not fit is the config's problem, not the parser's.
	var odd := RunConfig.standard()
	odd.apply_set(RunConfig.parse_set("starter=1,starter_cards=penny/nothing").set)
	check(not odd.problems().is_empty(), "a card not there: a problem")


## M9.8 step 2, stage 2: a reward round for a `core` bot holding no engine: an engine
## first (free), else the first card on its `perks` list, else the item.
func test_reward_round_without_an_engine() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var small := SimBots.spec("small")
	var c := _hand_round(pack.forms, small, 200, ["consolation", "bigfish", "closer"], true)
	SimBlocks._engine_round(c)
	eq(c.run.level("consolation"), 1, "no engine up: the listed CONSOLATION, free")
	eq(c.e.cash, 200, "for nothing")
	c = _hand_round(pack.forms, small, 200, ["consolation", "scrap", "closer"], true)
	SimBlocks._engine_round(c)
	check(c.run.level("scrap") == 1 and c.run.level("consolation") == 0, "an engine up: the engine first")
	c = _hand_round(pack.forms, small, 200, ["bigfish", "closer", "firstpull"], true)
	SimBlocks._engine_round(c)
	eq(int(c.run.stats.perks), 0, "nothing listed: no card")
	eq(int(c.run.stats.skipped_offers), 1, "the item")
	c = _hand_round(pack.forms, small, 200, ["consolation", "bigfish", "closer"])
	SimBlocks._engine_round(c)
	eq(c.run.level("consolation"), 0, "a morning round, no engine up: no listed card bought, as before")


## M9.8 step 2, stage 2: work_held, the bankroll rule (enter "line").
func test_work_held() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var run := RunState.start(RunConfig.standard(), "WH", ["diner", "bar", "bingo"])
	var e := run.new_economy()
	var m := run.new_machine(pack.forms, true)
	run.perks["bigfish"] = 1
	var own := SimCtx.of(run, e, m, SimBots.spec("jackpot", SimBots.VARIANTS.jackpot.nobank))
	var held := SimCtx.of(run, e, m, SimBots.spec("jackpot"))
	eq(held.param("work_held"), 1, "jackpot banks by default (the 300-run variants pass)")
	check(e.cash < int(own.param("work_below")) * run.stake(), "the cash under work_below ($%d)" % e.cash)
	check(SimBlocks.enter(own), "holding an engine: to the machine (work_held 0)")
	check(not SimBlocks.enter(held), "work_held 1: works first for a bankroll")
	e.bonus(1000)
	check(SimBlocks.enter(held), "work_held 1, the bankroll there: to the machine")
	e.pay(1000)
	run.day = run.days()
	check(SimBlocks.enter(held), "the endgame: to the machine")
	run.day = 1
	run.perks.erase("bigfish")
	check(not SimBlocks.enter(own), "holding none: works under work_below, as before")


## M9.8 step 2, stage 2: the deal's ceiling (SimReport.reach), through the code path on
## a few seeds: a bot with plenty of cash that works every day takes only its core,
## rerolls only as asked, and with more rerolls holds no fewer core cards.
func test_reach() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var seeds := 3 if full else 2
	var held := [0, 0]
	for line in SimBots.GIVEN:
		for i in seeds:
			for k in 2:
				var spec := SimBots.reach_spec(line, [0, 3][k])
				var r := SimRun.play(spec, pack.forms, "RC-%d" % i)
				eq(r.status, RunState.CLEARED, "%s r%d: cleared (plenty of cash)" % [line, spec.params.rerolls])
				eq(int(r.tickets), 0, "%s: works every day" % line)
				eq(int(r.rounds.reward), 2, "%s: one reward round a layer paid, none early" % line)
				for id in spec.params.shelf:
					check(r.perks.has(id) and int(r.perks[id].day) == 1, "%s: shelf %s bought on day 1" % [line, id])
				for id in r.perks:
					check(spec.params.perks.has(id) or spec.params.shelf.has(id), "%s: %s is of its core" % [line, id])
				if k == 0:
					eq(int(r.stats.rerolls), 0, "%s r0: no reroll" % line)
				else:
					check(int(r.stats.rerolls) <= 3 * int(r.stats.rounds), "%s r3: at most 3 a morning round" % line)
				var whole: bool = spec.params.perks.all(func(id): return r.held_by[2].has(id))
				eq(r.counters.has("reach_round"), whole, "%s: the round it was complete at, when it was" % line)
				for l in r.held_by.size():
					for id in spec.params.perks:
						held[k] += 1 if r.held_by[l].has(id) else 0
	note("core cards held at the layers' ends, summed: r0 %d, r3 %d" % held)
	check(held[1] >= held[0], "more rerolls hold no fewer core cards (%d >= %d)" % [held[1], held[0]])
	var s := SimReport.reach("small", pack.forms, 2, "RC", 1)
	for key in ["whole", "engine", "done", "never", "cards", "at_least", "rerolls_run", "cost", "rounds"]:
		check(s.has(key), "reach reports %s" % key)
	eq(s.whole.size(), 3, "a share a layer")
	eq(s.cards.keys(), SimBots.reach_spec("small", 1).params.perks, "a row a core card")
	# At least k of the core's cards: k from 1 to the core's size, the last the whole core,
	# each no more than the one before, the first at least any one card's share, and over
	# k they sum to the cards held on average (the cards' shares summed).
	for line in SimBots.GIVEN:
		var a := SimReport.reach(line, pack.forms, 4 if full else 3, "RK", 0)
		var core: Array = a.core
		eq(a.at_least.size(), core.size(), "%s: a row for each k, 1 .. %d" % [line, core.size()])
		eq(a.at_least[core.size() - 1], a.whole, "%s: all of the core is the whole core" % line)
		for l in 3:
			var sum := 0.0
			var cards := 0.0
			for k in core.size():
				sum += a.at_least[k][l]
				if k > 0:
					check(a.at_least[k][l] <= a.at_least[k - 1][l], "%s L%d: at least %d no more than at least %d" % [line, l + 1, k + 1, k])
			for id in core:
				cards += a.cards[id][l]
				check(a.at_least[0][l] >= a.cards[id][l], "%s L%d: at least one, no less than %s alone" % [line, l + 1, id])
			check(absf(sum - cards) < 1e-9, "%s L%d: summed over k, the cards held (%.3f, %.3f)" % [line, l + 1, sum, cards])
	eq(SimBots.reach_spec("jackpot", 0).params.shelf, ["read1", "regular"], "jackpot's shelf: READ THE FLARE and REGULAR")
	eq(SimBots.reach_spec("money", 0).params.perks, ["worth", "middle"], "money's dealt core")


## The upgrades counted (RunState.stats upgrades, reward_upgrades; summary's `upgrades`):
## a level bought from the shelf's upgrade slots, and a reward round's upgrade card; a
## reward round's new perk is neither.
func test_upgrades_counted() -> void:
	var run := RunState.start(RunConfig.standard(), "UP", ["diner", "bar", "bingo"])
	var e := run.new_economy()
	e.bonus(10000)
	run.perks["penny"] = 1
	run.perks["closer"] = 1
	run.upgrades = ["penny"]
	check(run.buy_upgrade("penny", e), "PENNY JAR's next level off the upgrade slot")
	eq(int(run.stats.upgrades), 1, "one upgrade bought from the shelf")
	run.offers = ["scrap", "closer"]
	run.offers_open = true
	run.offer_reward = true
	check(run.buy_offer(1, e), "the reward round's upgrade card")
	eq(int(run.stats.reward_upgrades), 1, "one reward upgrade")
	run.offers = ["scrap", "stacker"]
	run.offers_open = true
	run.offer_reward = true
	check(run.buy_offer(0, e), "a new perk from a reward round")
	eq(int(run.stats.reward_upgrades), 1, "a new perk is not an upgrade")
	eq(int(run.stats.upgrades), 1, "nor a shelf upgrade")
	var pack := core_pack()
	if pack == null:
		return
	var s := RunSim.summary("perks", pack.forms, 3, "UP")
	check(s.upgrades.has("shelf") and s.upgrades.has("reward"), "summary: the upgrades a run (%s)" % str(s.upgrades))


## The flow study (SimData.flow_study, sim_runs --flow): what a box paid before a cut
## and what it holds after add up to the box; the thirds split the boxes; the shares
## add up; the same seed gives the same numbers.
func test_flow_study() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var model := RunConfig.standard().box_model(0)
	var f: FormDef = pack.forms[0].shaped()
	var box := BoxGenerator.build(f, "FLOWT-0", model, true)
	for cut in [0, box.size / 4, box.size / 2, box.size - 1, box.size]:
		var x := SimData.flow_cut(box, cut)
		var before := 0
		for i in cut:
			before += int(box.tickets[i].prize)
		eq(int(x.past_money), before, "cut %d: past is the tickets before the cut" % cut)
		eq(int(x.past_money) + int(x.rest_money), box.prize_total(), "cut %d: past and rest money are the box's" % cut)
		eq(int(x.past_cost) + int(x.rest_cost), box.gross(), "cut %d: past and rest cost are the box's" % cut)
		eq(int(x.past_cost), cut * f.price, "cut %d: the tickets sold" % cut)
		eq(box.cursor, 0, "cut %d: the box is put back" % cut)
		var tops := 0
		for i in range(cut, box.size):
			for g in box.tickets[i].get("wins", [box.tickets[i].tier]):
				if int(g) >= 0 and f.is_top(int(g)):
					tops += 1
		eq(bool(x.top_in), tops > 0, "cut %d: a top prize in after the cut" % cut)
	# The thirds: every index once, sizes within one, the lower third's values not above the next's.
	var vals := [0.5, 0.1, 0.1, 0.9, 0.3, 0.3, 0.7, 0.2, 0.0, 0.6, 0.6]
	var t := SimData.terciles(vals)
	var seen := []
	for k in 3:
		seen.append_array(t[k])
		check(absi(t[k].size() - vals.size() / 3) <= 1, "third %d: %d of %d" % [k, t[k].size(), vals.size()])
	seen.sort()
	eq(seen, range(vals.size()), "the thirds partition the indexes")
	for k in 2:
		var hi: float = t[k].map(func(i): return vals[i]).max()
		var lo: float = t[k + 1].map(func(i): return vals[i]).min()
		check(hi <= lo, "third %d's values under third %d's" % [k, k + 1])
	check(is_equal_approx(SimData.pearson([1, 2, 3], [2, 4, 6]), 1.0), "Pearson: a line up is 1")
	check(is_equal_approx(SimData.pearson([1, 2, 3], [3, 2, 1]), -1.0), "Pearson: a line down is -1")
	check(is_equal_approx(SimData.spearman([1.0, 2.0, 3.0, 4.0], [1.0, 8.0, 27.0, 1000.0]), 1.0), "Spearman: any rise is 1")
	eq(SimData._ranks([3.0, 1.0, 3.0, 2.0]), [2.5, 0.0, 2.5, 1.0], "ties share their mean rank")
	# A small study.
	var forms := pack.forms.slice(0, 3)
	const N := 30
	var s := SimData.flow_study(forms, N, null, "FLOWT")
	eq(s.cuts, SimData.FLOW_CUTS, "the cuts")
	eq(s.rows.size(), forms.size() + 1, "a row set a form and one over all")
	for key in s.rows:
		var want := N * (forms.size() if key == "all" else 1)
		eq(s.rows[key].size(), SimData.FLOW_CUTS.size(), "%s: a row a cut" % key)
		for row in s.rows[key]:
			eq(int(row.n), want, "%s at %d%%: the boxes" % [key, row.cut])
			eq(int(row.top_in.n) + int(row.no_top.n), want, "%s at %d%%: top in and no top are every box" % [key, row.cut])
			check(is_equal_approx(row.top_in.share + row.no_top.share, 1.0), "%s at %d%%: the shares add up" % [key, row.cut])
			var sum := 0
			for th in row.thirds:
				sum += int(th.n)
			eq(sum, want, "%s at %d%%: the thirds are every box" % [key, row.cut])
			for g in [row.top_in, row.no_top]:
				var gs := 0
				for th in g.thirds:
					gs += int(th.n)
				eq(gs, int(g.n), "%s at %d%%: the thirds within a group are its boxes" % [key, row.cut])
			if key != "all":
				for k in 2:
					check(float(row.thirds[k].hi) <= float(row.thirds[k + 1].lo), "%s at %d%%: third %d's past under the next" % [key, row.cut, k])
			var mixed: float = (row.thirds[0].rest * row.thirds[0].n + row.thirds[1].rest * row.thirds[1].n
				+ row.thirds[2].rest * row.thirds[2].n) / float(want)
			check(is_equal_approx(mixed, float(row.rest)), "%s at %d%%: the thirds' rests make the mean" % [key, row.cut])
			check(row.r >= -1.0 and row.r <= 1.0, "%s at %d%%: r %.3f" % [key, row.cut, row.r])
	eq(SimData.flow_study(forms, N, null, "FLOWT"), s, "the same seed, the same numbers")
	check(SimData.flow_study(forms, N, null, "FLOWU") != s, "another seed, other numbers")


## A day at the machine set by hand for the items block: a fresh run at stake 1 on a day
## of play, `cash` in the pocket, blind's blocks with items "use" and `params`, no item
## held, today's column 0.
func _items_ctx(forms: Array, params: Dictionary = {}, cash := 10000) -> SimCtx:
	var run := RunState.start(RunConfig.standard(), "IT", ["diner", "bar", "bingo"])
	var e := run.new_economy()
	e.bonus(cash - e.cash)
	var ctx := SimCtx.of(run, e, run.new_machine(forms, true), SimBots.spec("blind", {"blocks": {"items": "use"}, "params": params}))
	run.play(e)
	run.items = {}
	ctx.start_day()
	ctx.col = 0
	ctx.day_money = e.cash + e.credit
	return ctx


## [a column whose next ticket wins (column 1, a winner moved there when it has none),
## a column whose next ticket loses (-1 when none)].
func _next_yes_no(ctx: SimCtx) -> Array:
	var b1: TicketBox = ctx.m.boxes[1]
	b1.pull_winner(b1.cursor, "next")
	var no := -1
	for i in ctx.m.boxes.size():
		var b: TicketBox = ctx.m.boxes[i]
		if i != 1 and not b.wins(b.cursor):
			no = i
			break
	return [1 if b1.wins(b1.cursor) else -1, no]


## A PEEK threshold just under (`under` false: at) the winners of column 0's next PEEK.
func _peek_at(ctx: SimCtx, under: bool) -> void:
	var box: TicketBox = ctx.m.boxes[0]
	var n := ctx.run.peek_n()
	var k := BoxReading.winners_next(box, n)
	ctx.spec.params.peek_min = {box.form.id: k * 100.0 / n + (1.0 if under else 0.0)}


## The items block (M9.8 step 3), each rule of items "use" on a state set by hand; `none`
## never uses anything; the daily items (only the simulator) topped up; whole runs with
## the variants balance.
func test_items_block() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var forms: Array = pack.forms
	# none: nothing, anywhere.
	var c := _items_ctx(forms)
	c.spec = SimBots.spec("blind")
	c.run.items = {"peek": 1, "magnifier": 1, "coin": 1, "happy": 1, "safety": 1, "sure": 1, "slip": 1}
	var held: Dictionary = c.run.items.duplicate()
	for at in ["morning", "work", "machine"]:
		check(SimBlocks.items(c, at), "none, %s: carries on" % at)
	eq(SimBlocks.one_more(c), 0, "none: no ticket more when leaving")
	eq(c.run.items, held, "none: every item still held")
	check(c.counters.is_empty() and not c.run.happy and not c.run.safety, "none: nothing used, nothing counted")
	# PEEK at peek_min: it buys into the window.
	var p := _items_ctx(forms)
	_peek_at(p, false)
	p.run.items = {"peek": 1}
	check(SimBlocks.items(p, "machine"), "PEEK at peek_min: plays")
	check(p.col == 0 and p.run.held("peek") == 0, "on its column, the PEEK used")
	check(p.peeks.size() == 1 and p.peeks.values()[0].good, "the answer kept")
	# Under it, holding nothing else: another column; back on it, left again without a PEEK.
	var u := _items_ctx(forms)
	_peek_at(u, true)
	u.run.items = {"peek": 1}
	check(SimBlocks.items(u, "machine"), "PEEK under peek_min: plays elsewhere")
	check(u.col != 0 and u.left_today.has(0), "it left column 0 (for %d)" % u.col)
	check(int(u.counters.get("peek_bad", 0)) == 1 and int(u.counters.get("peek_moved", 0)) == 1, "counted (%s)" % str(u.counters))
	u.col = 0
	check(SimBlocks.items(u, "machine") and u.col != 0, "the window known to be under: left again")
	eq(int(u.counters.get("peek_known", 0)), 1, "without another PEEK")
	# Under it with a FAST FORWARD: the window skipped, on the same column.
	var f := _items_ctx(forms)
	_peek_at(f, true)
	f.run.items = {"peek": 1, "skip": 1}
	var fb: TicketBox = f.m.boxes[0]
	var at := fb.cursor
	check(SimBlocks.items(f, "machine") and f.col == 0, "FAST FORWARD: stays on its column")
	eq(fb.cursor, at + 50, "the window skipped")
	eq(int(f.counters.get("peek_skip", 0)), 1, "counted")
	# Under it, nowhere else to go: home; in the endgame it plays the window.
	var h := _items_ctx(forms)
	_peek_at(h, true)
	h.run.items = {"peek": 1}
	for i in range(1, h.m.boxes.size()):
		h.left_today.append(i)
	check(not SimBlocks.items(h, "machine"), "nowhere else: home for the day")
	eq(int(h.counters.get("peek_stop", 0)), 1, "counted")
	h.run.day = h.run.days()
	check(SimBlocks.items(h, "machine") and h.col == 0, "the layer's last day: it plays the window")
	eq(int(h.counters.get("peek_stayed", 0)), 1, "counted")
	# LUCKY COIN: at once, the MAGNIFIER kept for the day's end (one_more).
	var z := _items_ctx(forms)
	var yn := _next_yes_no(z)
	if check(yn[0] >= 0 and yn[1] >= 0, "a column whose next ticket wins and one whose next loses"):
		z.col = yn[1]
		z.run.items = {"magnifier": 1, "coin": 1}
		SimBlocks.items(z, "machine")
		eq(z.run.items, {"magnifier": 1}, "the coin at once, the MAGNIFIER kept")
		eq(z.run.coin_on, {z.m.forms[yn[1]].uid(): 1}, "on the column's form")
		eq(SimBlocks.one_more(z), 0, "leaving, the next one loses: no ticket more")
		z.run.items = {"magnifier": 1}
		z.col = yn[0]
		eq(SimBlocks.one_more(z), 1, "leaving, the next one wins: that ticket")
		eq(int(z.counters.get("one_more", 0)), 1, "counted")
	# coin_wait 1: the coin only after a MAGNIFIER's yes.
	var w := _items_ctx(forms, {"coin_wait": 1})
	yn = _next_yes_no(w)
	if yn[0] >= 0 and yn[1] >= 0:
		w.col = yn[1]
		w.run.items = {"magnifier": 1, "coin": 1}
		SimBlocks.items(w, "machine")
		eq(w.run.items, {"coin": 1}, "coin_wait 1, a no: the coin kept")
		w.run.items = {"magnifier": 1, "coin": 1}
		w.col = yn[0]
		SimBlocks.items(w, "machine")
		check(w.run.items.is_empty() and w.run.coin_on.has(w.m.forms[yn[0]].uid()), "a yes: the coin goes on")
	# SURE THING: with a MAGNIFIER only on a no; without, at once.
	var s := _items_ctx(forms)
	yn = _next_yes_no(s)
	if yn[0] >= 0 and yn[1] >= 0:
		s.run.items = {"sure": 1, "magnifier": 1}
		s.col = yn[0]
		SimBlocks.items(s, "machine")
		eq(s.run.items, {"sure": 1}, "the next one wins: the SURE THING kept")
		s.run.items = {"sure": 1, "magnifier": 1}
		s.col = yn[1]
		var sb: TicketBox = s.m.boxes[yn[1]]
		SimBlocks.items(s, "machine")
		check(s.run.items.is_empty() and sb.wins(sb.cursor), "the next one loses: SURE THING on it, it wins now")
		s.run.items = {"sure": 1}
		s.col = 2 if yn[1] != 2 else 3
		SimBlocks.items(s, "machine")
		eq(s.run.held("sure"), 0, "no MAGNIFIER: at once")
	# HAPPY HOUR: only with happy_min tickets' money today; SAFETY NET at once.
	var hh := _items_ctx(forms, {"happy_min": 50})
	var price := hh.m.price(0)
	hh.run.items = {"happy": 1}
	hh.day_money = 50 * price - 1
	SimBlocks.items(hh, "machine")
	check(not hh.run.happy and hh.run.held("happy") == 1, "under happy_min tickets' money: kept")
	hh.day_money = 50 * price
	SimBlocks.items(hh, "machine")
	check(hh.run.happy and hh.run.held("happy") == 0, "at it: on")
	hh.run.items = {"safety": 1}
	SimBlocks.items(hh, "machine")
	check(hh.run.safety and hh.run.held("safety") == 0, "SAFETY NET: on, a day of play")
	# RETURN SLIP: the rest of a box bought, the last sale taken, every ticket given back.
	var sl := _items_ctx(forms, {"slip_max": 10})
	var lb: TicketBox = sl.m.boxes[0]
	lb.cursor = lb.size - 11
	sl.run.items = {"slip": 1}
	SimBlocks.items(sl, "machine")
	eq(sl.run.held("slip"), 1, "eleven left, slip_max 10: kept")
	lb.cursor = lb.size - 10
	var money := sl.e.cash + sl.e.credit
	var last: int = sl.m.last_sale
	check(last > 0, "the layer has a last-sale prize")
	SimBlocks.items(sl, "machine")
	eq(sl.run.held("slip"), 0, "ten left: used")
	eq(int(sl.counters.get("slip_tickets", 0)), 10, "the ten bought and given back")
	eq(sl.e.cash + sl.e.credit, money + last, "the money back, and the last sale")
	check(lb.cursor >= lb.size and int(sl.run.stats.boxes_cleared) == 1, "the box cleared")
	check(sl.e.balanced(), "balanced")
	# OVERTIME after a shift: the shift paid again.
	var orun := RunState.start(RunConfig.standard(), "OT", ["diner", "bar", "bingo"])
	var oe := orun.new_economy()
	var oc := SimCtx.of(orun, oe, orun.new_machine(forms, true), SimBots.spec("blind", {"blocks": {"items": "use"}}))
	orun.items = {"overtime": 1}
	SimBlocks.items(oc, "morning")
	eq(orun.held("overtime"), 1, "not in the morning: the day is not chosen yet")
	check(orun.work(oe), "a shift")
	var earned := oe.earned
	SimBlocks.items(oc, "work")
	check(oe.earned - earned == orun.shift_wage() and orun.held("overtime") == 0, "OVERTIME after it: paid again")
	# CHEAT SHEET: the dearest card on the bot's list, free.
	var ch := _hand_round(forms, SimBots.spec("build", {"blocks": {"items": "use"}}), 100000, ["prizes", "luck", "closer"])
	ch.run.items = {"cheat": 1}
	var want := "prizes" if ch.run.perk_price("prizes") >= ch.run.perk_price("luck") else "luck"
	var cash := ch.e.cash
	SimBlocks.perks(ch)
	check(ch.run.level(want) == 1 and ch.run.level("closer") == 0, "CHEAT SHEET: %s, the dearest on its list (CLOSER is not)" % want)
	check(ch.e.cash == cash and ch.run.held("cheat") == 0, "for free, the sheet used")
	# The daily items: topped up, never down; only the simulator.
	var st := RunState.start(RunConfig.standard(), "ST", ["diner", "bar", "bingo"])
	st.items = {"peek": 1, "coin": 5}
	SimRun.stock(st, {"peek": 2, "coin": 1, "nothing": 3})
	eq(st.items, {"peek": 2, "coin": 5}, "topped up to the count, never down; an unknown id ignored")
	check(not ("daily_items" in st), "the run has no such thing: only the simulator")
	var used := SimRun.play(SimBots.spec("small", {"blocks": {"items": "use"}, "params": {"daily_items": {"coin": 1}}}), forms, "IT-0")
	check(int(used.counters.get("item_coin", 0)) >= 1, "use: the morning's coin used (%s)" % str(used.counters))
	var kept := SimRun.play(SimBots.spec("small", {"params": {"daily_items": {"coin": 1}}}), forms, "IT-0")
	check(not kept.counters.keys().any(func(k): return str(k).begins_with("item_")), "none: held, never used")
	check(used.balanced and kept.balanced, "balanced")
	# Whole runs: every line's and build's item variants, and the control with items.
	for line in ["clearing", "jackpot", "small", "batch", "money", "build"]:
		for v in SimBots.VARIANTS[line]:
			if not str(v).begins_with("use") and v != "informant":
				continue
			for i in (2 if full else 1):
				var r := SimRun.play(SimBots.spec(line, SimBots.VARIANTS[line][v]), forms, "IU-%d" % i)
				check([RunState.CLEARED, RunState.FAILED].has(r.status) and r.balanced, "%s/%s %d: ends, balanced" % [line, v, i])
	var gi := SimReport.given("money", forms, 1, "GV", null, {}, SimBots.GIVEN_ITEMS)
	eq(gi.arms.keys(), ["line", "control", "noitems"], "with items: three arms")
	check(gi.has("items") and gi.items.has("over_none") and gi.items.has("blind_over_none"), "and what use adds")
	check(gi.arms.control.items.has("item_peek"), "the control uses its items (%s)" % str(gi.arms.control.items))
	check(not gi.arms.noitems.items.keys().any(func(k): return str(k).begins_with("item_")), "no use: none used")
	check(not SimReport.given("money", forms, 1, "GV").has("items"), "without items: as before")
