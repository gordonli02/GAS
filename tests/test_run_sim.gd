extends "res://tests/test_case.gd"
## The run simulator (RunSim): bots play whole runs by the game's own rules.
## The numbers themselves are looked at with tools/sim_runs; here, that the bots end
## every run with a balanced ledger, that the work-only rule holds through them, that
## the churn exploit (FIRST PULL x REGULAR) does not pay, and that summary() carries
## what the roadmap's bots table is measured by.


func test_work_bot_clears_with_nothing_left() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var r := RunSim.play("work", pack.forms, "W-1")
	eq(r.status, RunState.CLEARED, "works every day: cleared")
	eq(r.cash, 0, "to the dollar")
	eq(r.tickets, 0, "no tickets")
	eq(r.days, 18, "every day of the three layers")


func test_bots_finish_and_balance() -> void:
	var pack := core_pack()
	if pack == null:
		return
	check(RunSim.BOTS.has("gamble") and not RunSim.BOTS.has("mixed"), "mixed became gamble")
	for line in RunSim.LINES:
		check(RunSim.BOTS.has(line), "%s is a bot" % line)
		for id in RunSim.LINES[line].perks + RunSim.LINES[line].shelf:
			check(not Catalog.standard().perk(id).is_empty(), "%s: %s is in the catalog" % [line, id])
			check(not Catalog.meta(Catalog.standard().perk(id)), "%s: %s is sold in a run (not parked for M13)" % [line, id])
	var n := 6 if full else 2
	for bot in RunSim.BOTS:
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


## G, 2026-11-07: the slot takes coins under the smallest bill, and every bot asks the
## slot's rule before going to the machine, so no bot spends a day there buying nothing
## (before, the coins under a bill kept the plain bots at the machine for nothing).
func test_bots_never_stand_at_the_machine_unable_to_buy() -> void:
	var pack := core_pack()
	if pack == null:
		return
	var n := 8 if full else 3
	for bot in RunSim.BOTS:
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
	check(RunSim._can_buy(e, 5), "$24 under a $25 bill: four tickets of coins")
	e.cash = 4
	check(not RunSim._can_buy(e, 5), "$4 under a $5 ticket: nothing")
	e.credit = 1
	check(RunSim._can_buy(e, 5), "$4 of coins and $1 of credit: one ticket")
	var fed := Economy.new()
	fed.bills = RunConfig.bills(5)
	fed.cash = 24
	fed.start_cash = 24
	RunSim._feed(fed, 125, 5)
	eq(fed.credit, 20, "the bot feeds the coins: four tickets")
	eq(fed.cash, 4, "the rest stays in the pocket")
	check(fed.balanced(), "balanced")


func test_churn_does_not_pay() -> void:
	# FIRST PULL x REGULAR (docs/perk_research.md 5.11): 20 tickets a box, then a new
	# box; the fee's floor keeps it at 1 or under, counted with the fees.
	var pack := core_pack()
	if pack == null:
		return
	var s := RunSim.summary("churn", pack.forms, 60 if full else 20, "CH")
	note("churn bot: return %.3f, with fees %.3f, fees $%.0f a run" % [s["return"], s.return_fees, s.fees])
	check(s.return_fees <= 1.0, "the churn bot's return with fees is 1 or under (%.3f)" % s.return_fees)
	var boxes := 60 if full else 20
	var fixed := RunSim.churn_return(pack.forms, {"firstpull": 2, "regular": 2}, boxes)
	note("churn at FIRST PULL 2 + REGULAR 2: return %.3f, with fees %.3f, fee $%d" % [fixed["return"], fixed.return_fees, fixed.fee])
	eq(fixed.fee, 100, "the fee is the floor")
	check(fixed["return"] > 2.0, "FIRST PULL pays on the first twenty (%.3f)" % fixed["return"])
	check(fixed.return_fees <= 1.0, "but not once the fee is counted (%.3f)" % fixed.return_fees)


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
	check(s.best[0] <= s.best[1] and s.best[1] <= s.best[2], "they do not decrease: %s" % str(s.best))
	check(s.best[0] > 0, "every run wins something")
	eq(RunSim.percentiles([5, 1, 4, 2, 3], [50, 90, 99]), [3, 5, 5], "nearest rank")
	eq(RunSim.percentiles([], [50]), [0], "nothing: 0")


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
	var rows := RunSim.push_odds(pack.forms, 400 if full else 250, "PT")
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
	for row in RunSim.push_odds(pack.forms, 60, "PT", old):
		check(row.p < 0.4, "%s: more than the window was P %.3f" % [row.form, row.p])


func test_perks_raise_the_return() -> void:
	# M9: blind buying about breaks even; perks make a dollar of tickets pay back more.
	var pack := core_pack()
	if pack == null:
		return
	var n := 20 if full else 8
	var none := RunSim.box_return(pack.forms, {}, n)
	var prizes := RunSim.box_return(pack.forms, {"prizes": 3}, n)
	var luck := RunSim.box_return(pack.forms, {"luck": 3}, n)
	var all := RunSim.box_return(pack.forms, {"prizes": 3, "luck": 3, "closer": 2}, n)
	note("return per dollar: none %.3f, FAT PRIZES 3 %.3f, LUCKY STREAK 3 %.3f, all %.3f" % [none, prizes, luck, all])
	# G, 2026-11-07: blind, whole boxes bought out, the last sale included, about 0.78 a
	# dollar (the run's payout, RunConfig "payout", and a last sale of about 5% of a box).
	check(none > 0.65 and none < 0.92, "without perks about 0.78 (%.3f)" % none)
	check(prizes > none * 1.2, "FAT PRIZES 3 pays about 30%% more (%.3f)" % prizes)
	check(luck > none, "LUCKY STREAK pays more (%.3f)" % luck)
	check(all > prizes and all > luck, "together more still (%.3f)" % all)
	var snow := RunSim.box_return(pack.forms, {"snowball": 1, "snow": 10}, n)
	check(snow > none * 2.0, "SNOWBALL after ten boxes: about x2.6 (%.3f)" % snow)
