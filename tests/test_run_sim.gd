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
