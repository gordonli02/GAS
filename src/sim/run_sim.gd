class_name RunSim
extends RefCounted
## The run simulator's front door: plays whole runs with simple bots, for looking at the
## numbers (tools/sim_runs, tests/test_run_sim.gd). The simulator itself is in src/sim/
## (docs/roadmap.md 七, M9.8 step 1):
##   SimBots    the bots' table: each bot's spec (which variant of each block, its params)
##   SimBlocks  a day cut into six blocks (enter, column, stay, perks, items, box)
##   SimCtx     what a block sees of one run
##   SimRun     one run: the loop over the days that asks the blocks
##   SimReport  many runs: summary (with the trigger table, the deaths, the carry, the
##              Wilson interval), paired, the baseline row, percentiles
##   SimData    the data layer: box_return, churn_return, push_odds, form_table

const BOTS := SimBots.NAMES


## One run of `bot` (a name in BOTS; any other name plays every block's default, as
## blind does, with the same dice: they are the seed's). Returns SimRun.play's {status, layer (0-based, where it ended), days,
## tickets, cash, spent, won, balanced, stats, idle_days, perks, fired, fired_pct,
## carry, death}. The same bot, forms, seed and config always give the same run.
static func play(bot: String, base_forms: Array, seed_text: String, config: RunConfig = null) -> Dictionary:
	return SimRun.play(SimBots.spec(bot), base_forms, seed_text, config)


## `runs` runs of one bot, seeds `seed_prefix`-0 .. (SimReport.summary; `band` the
## early stop's).
static func summary(bot: String, base_forms: Array, runs: int, seed_prefix := "SIM", config: RunConfig = null,
		band: Array = []) -> Dictionary:
	return SimReport.summary(SimBots.spec(bot), base_forms, runs, seed_prefix, config, band)


## One run as the row tests/fixtures/sim_baseline.json keeps (SimReport.baseline_row).
static func baseline_row(result: Dictionary) -> Dictionary:
	return SimReport.baseline_row(result)
