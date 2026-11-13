class_name SimReport
extends RefCounted
## What the simulator says about many runs: a bot's summary (the shares and means a
## balance pass looks at, and the measures of docs/roadmap.md 七.3, 七.5, 七.6 and
## 十二.6), the paired comparison of two summaries on the same seeds, the row the
## baseline fixture keeps of one run, percentiles, the Wilson interval.

const BEST_PCT := [50, 90, 99]   ## the percentiles of each run's best prize summary gives
const Z95 := 1.96                ## the normal quantile of a two-sided 95% interval
const CHUNK := 100               ## runs between the early stop's looks (summary's `band`)
const OFTEN := 0.10              ## a perk off the bot's list is in the trigger table when held in this share of runs
const DEATHS_MIN := 5            ## a layer gets a death block when at least this many runs died there


## `runs` runs of the bot `spec` (SimBots.spec), seeds `seed_prefix`-0 ... Returns:
##   cleared (overall), reached (share that got to each layer), layer_rates (of the
##   runs that reached a layer, the share that paid it: their product is `cleared`),
##   days, tickets, perks and days spared per run; return (prizes per dollar of
##   tickets) and return_fees (per dollar of tickets and NEW BOX fees); best (the
##   BEST_PCT percentiles of each run's biggest single prize, in dollars: the
##   "astronomical" numbers of docs/perk_research.md 5.8)
##   outcomes   layers paid (0 .. layers) of each run, by its index (the seed's number):
##              what `paired` compares; `layers` the config's count
##   wilson     [low, high]: the 95% Wilson interval of `cleared`
##   triggers   the trigger table (七.3), one row a perk: the bot's own (params.perks and
##              params.shelf) and any other held at the end of OFTEN of the runs:
##              {id, held (share of runs), day (mean day bought, of holders), per_run
##              (fired per holder; -1 for a perk RunState.FIRED does not count), per_100
##              (fired per 100 tickets bought while held), pct (mean percent added a
##              firing, -1 when it adds none), won (ALL IN only: pushes won per holder)}
##   deaths     share of all runs that failed in each layer
##   death_blocks  per layer with DEATHS_MIN deaths or more: {layer (1-based), n, cash,
##              short, shifts, tickets (medians), sets ([[perk ids joined, share of the
##              layer's deaths]], the three most common)}
##   carry      per transition (1 to 2, 2 to 3): {n, median, at_least_1 (share >= 1.0)}
##   stopped    runs played when the early stop ended it (0: all of them)
## `band` ([low, high] shares, optional): the early stop (七.6). After every CHUNK runs,
## when the Wilson interval lies wholly outside the band, the bot stops there; every
## number is then of the runs played (`runs` says how many).
static func summary(spec: Dictionary, base_forms: Array, runs: int, seed_prefix := "SIM", config: RunConfig = null,
		band: Array = []) -> Dictionary:
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
	var outcomes := []
	var held := {}   # perk id -> {n, day, tickets, fired, pct, won}
	var dead := []   # the death of each failed run
	var carry := []
	carry.resize(maxi(0, layers - 1))
	for k in carry.size():
		carry[k] = []
	var stopped := 0
	var played := 0
	for i in runs:
		var r := SimRun.play(spec, base_forms, "%s-%d" % [seed_prefix, i], config)
		played += 1
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
		outcomes.append(int(r.stats.layers_cleared))
		for id in r.perks:
			var h: Dictionary = held.get(id, {"n": 0, "day": 0, "tickets": 0, "fired": 0, "pct": 0, "won": 0})
			h.n += 1
			h.day += int(r.perks[id].day)
			h.tickets += int(r.perks[id].tickets)
			h.fired += int(r.fired.get(id, 0))
			h.pct += int(r.fired_pct.get(id, 0))
			if id == "allin":
				h.won += int(r.fired.get("allin_won", 0))
			held[id] = h
		if not r.death.is_empty():
			dead.append(r.death)
		for k in mini(carry.size(), r.carry.size()):
			carry[k].append(float(r.carry[k]))
		if not band.is_empty() and played % CHUNK == 0 and played < runs:
			var w := wilson(cleared, played)
			if w[1] < float(band[0]) or w[0] > float(band[1]):
				stopped = played
				break
	var n := maxf(1.0, played)
	var reach := []
	var rates := []
	for l in layers:
		reach.append(reached[l] / n)
		rates.append(float(paid[l]) / reached[l] if reached[l] > 0 else 0.0)
	var carry_rows := []
	for list in carry:
		var at_least := 0
		for c in list:
			if c >= 1.0:
				at_least += 1
		carry_rows.append({"n": list.size(), "median": median(list),
			"at_least_1": float(at_least) / list.size() if not list.is_empty() else 0.0})
	return {"bot": str(spec.name), "runs": played, "layers": layers, "cleared": cleared / n, "reached": reach,
		"layer_rates": rates, "days": days / n, "tickets": tickets / n, "return": float(won) / spent if spent > 0 else 0.0,
		"return_fees": float(won) / (spent + fees) if spent + fees > 0 else 0.0, "fees": fees / n,
		"days_spared": spared / n, "perks": perks / n, "best": percentiles(bests, BEST_PCT), "outcomes": outcomes,
		"wilson": wilson(cleared, played), "triggers": _triggers(spec, held, played), "deaths": _deaths(dead, layers, played),
		"death_blocks": _death_blocks(dead, layers), "carry": carry_rows, "stopped": stopped}


## The trigger table's rows (summary's `triggers`).
static func _triggers(spec: Dictionary, held: Dictionary, runs: int) -> Array:
	var ids := []
	for id in spec.params.perks + spec.params.shelf:
		if not ids.has(id):
			ids.append(id)
	var others := []
	for id in held:
		if not ids.has(id) and runs > 0 and float(held[id].n) / runs >= OFTEN:
			others.append(id)
	others.sort_custom(func(a, b): return held[a].n > held[b].n or held[a].n == held[b].n and a < b)
	var rows := []
	for id in ids + others:
		var h: Dictionary = held.get(id, {"n": 0, "day": 0, "tickets": 0, "fired": 0, "pct": 0, "won": 0})
		var counted := RunState.FIRED.has(id)
		var hn := maxi(1, int(h.n))
		rows.append({"id": id, "held": float(h.n) / maxi(1, runs), "day": float(h.day) / hn,
			"per_run": float(h.fired) / hn if counted else -1.0,
			"per_100": float(h.fired) * 100.0 / h.tickets if counted and h.tickets > 0 else (0.0 if counted else -1.0),
			"pct": float(h.pct) / h.fired if h.pct != 0 and h.fired > 0 else -1.0,
			"won": float(h.won) / hn if id == "allin" else -1.0})
	return rows


## The share of all `runs` that died in each layer.
static func _deaths(dead: Array, layers: int, runs: int) -> Array:
	var out := []
	out.resize(layers)
	out.fill(0.0)
	for d in dead:
		var l := clampi(int(d.layer) - 1, 0, layers - 1)
		out[l] += 1.0 / maxi(1, runs)
	return out


## The death blocks (summary's `death_blocks`).
static func _death_blocks(dead: Array, layers: int) -> Array:
	var out := []
	for l in range(1, layers + 1):
		var here := dead.filter(func(d): return int(d.layer) == l)
		if here.size() < DEATHS_MIN:
			continue
		var sets := {}
		for d in here:
			var ids: Array = d.perks.keys()
			ids.sort()
			var key := ",".join(ids) if not ids.is_empty() else "none"
			sets[key] = int(sets.get(key, 0)) + 1
		var keys := sets.keys()
		keys.sort_custom(func(a, b): return sets[a] > sets[b] or sets[a] == sets[b] and a < b)
		var top := []
		for k in mini(3, keys.size()):
			top.append([keys[k], float(sets[keys[k]]) / here.size()])
		out.append({"layer": l, "n": here.size(), "cash": median(here.map(func(d): return d.cash)),
			"short": median(here.map(func(d): return d.short)), "shifts": median(here.map(func(d): return d.shifts)),
			"tickets": median(here.map(func(d): return d.tickets)), "sets": top})
	return out


## Two summaries of the same seeds (the same prefix and run count: the same bot before
## and after a number change, or two bots), run by run: {n, only_a, only_b, both,
## neither, diff (A's clear rate less B's), low, high}, or {} when they do not pair.
## The interval is the Wald interval for paired proportions: with b = only_a and
## c = only_b, diff = (b - c) / n and
##   se = sqrt(b + c - (b - c)^2 / n) / n,   diff +- 1.96 se
## (only the runs that split count; the runs both or neither cleared add nothing).
static func paired(a: Dictionary, b: Dictionary) -> Dictionary:
	var oa: Array = a.get("outcomes", [])
	var ob: Array = b.get("outcomes", [])
	if oa.is_empty() or oa.size() != ob.size():
		return {}
	var la := int(a.get("layers", 3))
	var lb := int(b.get("layers", 3))
	var out := {"n": oa.size(), "only_a": 0, "only_b": 0, "both": 0, "neither": 0}
	for i in oa.size():
		var ca := int(oa[i]) >= la
		var cb := int(ob[i]) >= lb
		if ca and cb:
			out.both += 1
		elif ca:
			out.only_a += 1
		elif cb:
			out.only_b += 1
		else:
			out.neither += 1
	var n := float(out.n)
	var split := float(int(out.only_a) - int(out.only_b))
	var diff := split / n
	var se := sqrt(maxf(0.0, float(int(out.only_a) + int(out.only_b)) - split * split / n)) / n
	out.diff = diff
	out.low = diff - Z95 * se
	out.high = diff + Z95 * se
	return out


## The 95% Wilson score interval of `k` successes in `n`: [low, high] ([0, 1] for none).
##   centre = (p + z^2 / 2n) / (1 + z^2 / n),
##   half = z sqrt(p (1 - p) / n + z^2 / 4n^2) / (1 + z^2 / n),   p = k / n, z = 1.96
static func wilson(k: int, n: int) -> Array:
	if n <= 0:
		return [0.0, 1.0]
	var p := float(k) / n
	var z2 := Z95 * Z95
	var d := 1.0 + z2 / n
	var centre := (p + z2 / (2.0 * n)) / d
	var half := Z95 * sqrt(p * (1.0 - p) / n + z2 / (4.0 * n * n)) / d
	return [maxf(0.0, centre - half), minf(1.0, centre + half)]


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


## The nearest-rank median (the lower of the middle two), 0 for none.
static func median(values: Array) -> Variant:
	return percentiles(values, [50])[0]
