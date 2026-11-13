class_name SimReport
extends RefCounted
## What the simulator says about many runs: a bot's summary (the shares and means a
## balance pass looks at), the row the baseline fixture keeps of one run, percentiles.

const BEST_PCT := [50, 90, 99]   ## the percentiles of each run's best prize summary gives


## `runs` runs of the bot `spec` (SimBots.spec). Returns the shares and means a balance
## pass looks at: `cleared` (overall), `reached` (share that got to each layer),
## `layer_rates` (of the runs that reached a layer, the share that paid it: their
## product is `cleared`), days, tickets, perks and days spared per run; `return` (prizes
## per dollar of tickets) and `return_fees` (per dollar of tickets and NEW BOX fees);
## `best` (the BEST_PCT percentiles of each run's biggest single prize, in dollars: the
## "astronomical" numbers of docs/perk_research.md 5.8).
static func summary(spec: Dictionary, base_forms: Array, runs: int, seed_prefix := "SIM", config: RunConfig = null) -> Dictionary:
	if config == null:
		config = RunConfig.standard()
	var layers := config.layers.size()
	var cleared := 0
	var reached := []
	reached.resize(layers)
	reached.fill(0)
	var paid := []
	paid.resize(layers)
	paid.fill(0)
	var days := 0
	var tickets := 0
	var spent := 0
	var won := 0
	var fees := 0
	var spared := 0
	var perks := 0
	var bests := []
	for i in runs:
		var r := SimRun.play(spec, base_forms, "%s-%d" % [seed_prefix, i], config)
		if r.status == RunState.CLEARED:
			cleared += 1
		for l in int(r.layer) + 1:
			reached[l] += 1
		for l in mini(layers, int(r.stats.layers_cleared)):
			paid[l] += 1
		days += int(r.days)
		tickets += int(r.tickets)
		spent += int(r.spent)
		won += int(r.won)
		fees += int(r.stats.fees)
		spared += int(r.stats.days_spared)
		perks += int(r.stats.perks)
		bests.append(int(r.stats.best_prize))
	var n := maxf(1.0, runs)
	var reach := []
	var rates := []
	for l in layers:
		reach.append(reached[l] / n)
		rates.append(float(paid[l]) / reached[l] if reached[l] > 0 else 0.0)
	return {"bot": str(spec.name), "runs": runs, "cleared": cleared / n, "reached": reach, "layer_rates": rates,
		"days": days / n, "tickets": tickets / n, "return": float(won) / spent if spent > 0 else 0.0,
		"return_fees": float(won) / (spent + fees) if spent + fees > 0 else 0.0, "fees": fees / n,
		"days_spared": spared / n, "perks": perks / n, "best": percentiles(bests, BEST_PCT)}


## One run as the row tests/fixtures/sim_baseline.json keeps (written by
## `sim_runs --baseline=`, compared by test_bots_match_the_baseline): the run's
## outcome and the few stats that show how it was played. status is RunState's
## string ("cleared" / "failed"); everything else is an int.
static func baseline_row(result: Dictionary) -> Dictionary:
	var s: Dictionary = result.stats
	return {"status": str(result.status), "layer": int(result.layer), "days": int(result.days),
		"tickets": int(result.tickets), "cash": int(result.cash), "spent": int(result.spent),
		"won": int(result.won), "idle_days": int(result.idle_days), "perks": int(s.perks),
		"layers_cleared": int(s.layers_cleared), "best_prize": int(s.best_prize), "fees": int(s.fees)}


## The nearest-rank percentiles `pcts` of `values` (non-decreasing in `pcts`).
static func percentiles(values: Array, pcts: Array) -> Array:
	var v := values.duplicate()
	v.sort()
	var out := []
	for p in pcts:
		if v.is_empty():
			out.append(0)
			continue
		out.append(v[clampi(ceili(float(p) / 100.0 * v.size()) - 1, 0, v.size() - 1)])
	return out
