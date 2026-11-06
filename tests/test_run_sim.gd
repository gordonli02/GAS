extends "res://tests/test_case.gd"
## The run simulator (RunSim): bots play whole runs by the game's own rules.
## The numbers themselves are looked at with tools/sim_runs; here, that the bots end
## every run with a balanced ledger and that the work-only rule holds through them.


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
	var n := 12 if full else 3
	for bot in ["blind", "borrow", "mixed"]:
		for i in n:
			var r := RunSim.play(bot, pack.forms, "B-%d" % i)
			check([RunState.CLEARED, RunState.FAILED].has(r.status), "%s %d: the run ends" % [bot, i])
			check(r.balanced and r.cash >= 0, "%s %d: ledger balanced" % [bot, i])
			if r.status == RunState.CLEARED:
				eq(int(r.stats.layers_cleared), 3, "%s %d: three layers paid" % [bot, i])
	var a := RunSim.play("blind", pack.forms, "B-0")
	var b := RunSim.play("blind", pack.forms, "B-0")
	eq(b, a, "the same seed plays the same run")


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
	check(none > 0.85 and none < 1.2, "without perks about even (%.3f)" % none)
	check(prizes > none * 1.2, "FAT PRIZES 3 pays about 30%% more (%.3f)" % prizes)
	check(luck > none, "LUCKY STREAK pays more (%.3f)" % luck)
	check(all > prizes and all > luck, "together more still (%.3f)" % all)
