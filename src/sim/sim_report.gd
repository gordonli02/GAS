class_name SimReport
extends RefCounted
## What the simulator says about many runs: a bot's summary (the shares and means a
## balance pass looks at, and the measures of docs/roadmap.md 七.3, 七.5, 七.6 and
## 十二.6), the paired comparison of two summaries on the same seeds, the given-cards
## test of a line (given: two criteria, fired and play, judged by judge_fired and
## judge_return, and the signature as a reading), the deal's ceiling of a line (reach:
## how soon a bot taking only its core holds it, with plenty of cash), the paired mean
## (paired_mean), the row the baseline fixture keeps of one run, percentiles, the
## Wilson interval.

const BEST_PCT := [50, 90, 99]   ## the percentiles of each run's best prize summary gives
const Z95 := 1.96                ## the normal quantile of a two-sided 95% interval
const CHUNK := 100               ## runs between the early stop's looks (summary's `band`)
const OFTEN := 0.10              ## a perk off the bot's list is in the trigger table when held in this share of runs
const DEATHS_MIN := 5            ## a layer gets a death block when at least this many runs died there
const FIRED_MIN := 0.9           ## given: a given core perk fires in at least this share of the line arm's runs
							## (a card the control arm also misses is judged against the control instead)


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
##   triggers   the trigger table (七.3), one row a perk: the bot's own (params.engine,
##              perks, shelf and given) and any other held at the end of OFTEN of the
##              runs: {id, held (share of runs), day (mean day bought, of holders), per_run
##              (fired per holder; -1 for a perk RunState.FIRED does not count), per_100
##              (fired per 100 tickets bought while held), pct (mean percent added a
##              firing, -1 when it adds none), won (ALL IN only: pushes won per holder),
##              by_layer ("拿得到", roadmap 十三.10: for each layer, of the runs that
##              played it, the share holding the perk when it ended there, paid or
##              failed; -1 when none played it), offered_by (the same, the share in
##              which it had been dealt as a card by then: "dealt but not bought"
##              against "never dealt", roadmap 十.8)}
##   rounds     {morning, reward, rerolls, free_rerolls}: the rounds dealt a run, the
##              rerolls made and, of them, the free ones, the mean
##   upgrades   {shelf, reward}: levels bought from the shelf's upgrade slots and reward
##              rounds' upgrade cards taken a run (RunState.stats upgrades,
##              reward_upgrades), the mean
##   deaths    share of all runs that failed in each layer
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
	var played_in := []   # runs that played each layer
	played_in.resize(layers)
	played_in.fill(0)
	var held_in := {}     # perk id -> [runs holding it when each layer ended]
	var offered_in := {}  # perk id -> [runs it had been offered in by the time each layer ended]
	var rounds := {"morning": 0, "reward": 0, "rerolls": 0, "free_rerolls": 0}
	var upgrades := {"shelf": 0, "reward": 0}
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
		for l in mini(layers, r.held_by.size()):
			played_in[l] += 1
			for id in r.held_by[l]:
				if not held_in.has(id):
					held_in[id] = []
					held_in[id].resize(layers)
					held_in[id].fill(0)
				held_in[id][l] += 1
			for id in (r.offered_by[l] if l < r.get("offered_by", []).size() else {}):
				if not offered_in.has(id):
					offered_in[id] = []
					offered_in[id].resize(layers)
					offered_in[id].fill(0)
				offered_in[id][l] += 1
		for k in rounds:
			rounds[k] += int(r.get("rounds", {}).get(k, 0))
		upgrades.shelf += int(r.stats.get("upgrades", 0))
		upgrades.reward += int(r.stats.get("reward_upgrades", 0))
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
		"wilson": wilson(cleared, played), "triggers": _triggers(spec, held, played, played_in, held_in, offered_in),
		"rounds": {"morning": rounds.morning / n, "reward": rounds.reward / n, "rerolls": rounds.rerolls / n,
			"free_rerolls": rounds.free_rerolls / n},
		"upgrades": {"shelf": upgrades.shelf / n, "reward": upgrades.reward / n},
		"deaths": _deaths(dead, layers, played),
		"death_blocks": _death_blocks(dead, layers), "carry": carry_rows, "stopped": stopped}


## The trigger table's rows (summary's `triggers`).
static func _triggers(spec: Dictionary, held: Dictionary, runs: int, played_in: Array, held_in: Dictionary,
		offered_in: Dictionary = {}) -> Array:
	var ids := []
	for id in spec.params.engine + spec.params.perks + spec.params.shelf + spec.params.given.keys():
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
		var by := _shares(held_in, id, played_in)
		var dealt := _shares(offered_in, id, played_in)
		rows.append({"id": id, "held": float(h.n) / maxi(1, runs), "day": float(h.day) / hn,
			"per_run": float(h.fired) / hn if counted else -1.0,
			"per_100": float(h.fired) * 100.0 / h.tickets if counted and h.tickets > 0 else (0.0 if counted else -1.0),
			"pct": float(h.pct) / h.fired if h.pct != 0 and h.fired > 0 else -1.0,
			"won": float(h.won) / hn if id == "allin" else -1.0, "by_layer": by, "offered_by": dealt})
	return rows


## For each layer, of the runs that played it (`played_in`), the share counted for `id`
## in `counts` (id -> [runs a layer]); -1 for a layer none played.
static func _shares(counts: Dictionary, id: String, played_in: Array) -> Array:
	var out := []
	for l in played_in.size():
		out.append(float(counts.get(id, [])[l]) / played_in[l] if counts.has(id) and played_in[l] > 0
			else (0.0 if played_in[l] > 0 else -1.0))
	return out


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
	out.merge(_wald(int(out.only_a), int(out.only_b), int(out.n)))
	return out


## The Wald interval for paired proportions (see `paired`): b runs only A, c only B, of
## n: {diff, low, high}.
static func _wald(b: int, c: int, n: int) -> Dictionary:
	var nf := float(maxi(1, n))
	var split := float(b - c)
	var diff := split / nf
	var se := sqrt(maxf(0.0, float(b + c) - split * split / nf)) / nf
	return {"diff": diff, "low": diff - Z95 * se, "high": diff + Z95 * se}


## The mean of paired differences (one a seed: the same seed played two ways) with its
## normal 95% interval: {n, mean, sd, low, high}. With d_i the differences,
##   mean = sum(d_i) / n,   sd = sqrt(sum((d_i - mean)^2) / (n - 1)),
##   mean +- 1.96 sd / sqrt(n)
## (sd 0 and the interval the mean itself for fewer than two; n 0: everything 0).
static func paired_mean(diffs: Array) -> Dictionary:
	var n := diffs.size()
	if n == 0:
		return {"n": 0, "mean": 0.0, "sd": 0.0, "low": 0.0, "high": 0.0}
	var sum := 0.0
	for d in diffs:
		sum += float(d)
	var mean := sum / n
	var sq := 0.0
	for d in diffs:
		sq += (float(d) - mean) * (float(d) - mean)
	var sd := sqrt(sq / (n - 1)) if n > 1 else 0.0
	var half := Z95 * sd / sqrt(float(n))
	return {"n": n, "mean": mean, "sd": sd, "low": mean - half, "high": mean + half}


## The given-cards test of a line (docs/roadmap.md M9.8 step 1 stage 3, "用得上";
## SimBots.GIVEN, SIGNATURE): `runs` seeds `seed_prefix`-0 .., each played by the line
## arm (SimBots.given_spec: the line bot, `overrides` laid over it, holding its core,
## buying no perks) and by the control (SimBots.control_spec: blind holding the same
## core), the same boxes and dice. Returns {line, runs, given, arms: {line, control},
## each {tickets (per run), return (won / spent, pooled), signature (per 100 tickets,
## pooled), fired (perk id -> share of runs it fired in, or was used in), cleared},
## criteria: [two {name, pass, ...}], pass (both), reading}:
##   1 fired    judge_fired of each given perk RunState.FIRED counts (REGULAR is judged by
##              use, a box changed in the run; READ THE FLARE by use, a box left because
##              its flare said the top was gone, SimCtx.counters "flare_left"; any other
##              is not judged). {rows: [{id, how ("fired", "used", "-"), rule, line,
##              control, diff, low, high, pass}], missing}
##   2 play     judge_return of each seed's return difference (line less control; a seed
##              where either arm spent nothing is dropped). {line, control, n, mean, low,
##              high, verdict}
## `reading` (no verdict): the signature per 100 tickets of both arms and their ratio,
## how much play at the machine weighs (机器前决策分量): {line, control, x}.
static func given(line: String, base_forms: Array, runs: int, seed_prefix := "GV", config: RunConfig = null,
		overrides: Dictionary = {}) -> Dictionary:
	if config == null:
		config = RunConfig.standard()
	var specs := {"line": SimBots.given_spec(line, overrides), "control": SimBots.control_spec(line)}
	var core: Dictionary = SimBots.GIVEN.get(line, {})
	var sig: Array = SimBots.SIGNATURE.get(line, ["fired", ""])
	var acc := {}
	for arm in specs:
		acc[arm] = {"tickets": 0, "spent": 0, "won": 0, "sig": 0, "cleared": 0, "fired": {}, "flags": {}}
		for id in core:
			acc[arm].flags[id] = []
	var diffs := []
	for i in runs:
		var rets := {}
		for arm in specs:
			var r := SimRun.play(specs[arm], base_forms, "%s-%d" % [seed_prefix, i], config)
			var a: Dictionary = acc[arm]
			a.tickets += int(r.tickets)
			a.spent += int(r.spent)
			a.won += int(r.won)
			a.sig += int(r[sig[0]].get(sig[1], 0))
			if r.status == RunState.CLEARED:
				a.cleared += 1
			for id in core:
				var used := _used(id, r)
				a.flags[id].append(used)
				if used:
					a.fired[id] = int(a.fired.get(id, 0)) + 1
			rets[arm] = float(r.won) / r.spent if int(r.spent) > 0 else -1.0
		if rets.line >= 0.0 and rets.control >= 0.0:
			diffs.append(rets.line - rets.control)
	var n := maxf(1.0, runs)
	var arms := {}
	for arm in acc:
		var a: Dictionary = acc[arm]
		var fired := {}
		for id in core:
			fired[id] = float(a.fired.get(id, 0)) / n
		arms[arm] = {"tickets": a.tickets / n, "return": float(a.won) / a.spent if a.spent > 0 else 0.0,
			"signature": 100.0 * a.sig / a.tickets if a.tickets > 0 else 0.0, "fired": fired, "cleared": a.cleared / n}
	var rows := []
	var missing := []
	for id in core:
		var how := "fired" if RunState.FIRED.has(id) else ("used" if ["regular", "read1"].has(id) else "-")
		var row := {"id": id, "how": how}
		if how == "-":
			row.merge({"rule": "-", "line": arms.line.fired[id], "control": arms.control.fired[id], "pass": true})
		else:
			row.merge(judge_fired(acc.line.flags[id], acc.control.flags[id]))
			if not row.pass:
				missing.append(id)
		rows.append(row)
	var ls: float = arms.line.signature
	var cs: float = arms.control.signature
	var x := ls / cs if cs > 0.0 else (INF if ls > 0.0 else 0.0)
	var play := judge_return(diffs)
	play.merge({"name": "play", "line": arms.line["return"], "control": arms.control["return"]})
	var criteria := [{"name": "fired", "pass": missing.is_empty(), "rows": rows, "missing": missing}, play]
	return {"line": line, "runs": runs, "given": core.duplicate(), "arms": arms, "criteria": criteria,
		"pass": criteria.all(func(c): return c.pass), "reading": {"line": ls, "control": cs, "x": x}}


## Criterion 1 of `given` for one card: `line` and `control` are per-seed flags (the card
## fired or was used in that seed's run, true / false) of the two arms. PASS when the line
## arm has it in FIRED_MIN of its runs or more (rule "90%"). When the control arm is also
## under FIRED_MIN the card waits on a rare prize and is judged against the control
## (rule "against the control"): PASS when the line arm is not lower, the 95% interval of
## the paired difference (per seed: line 1/0 less control 1/0, the Wald interval of
## `paired`) not wholly below 0. Returns {rule, line, control (the shares), diff, low,
## high (the paired difference), pass}.
static func judge_fired(line: Array, control: Array) -> Dictionary:
	var n := mini(line.size(), control.size())
	var lk := 0
	var ck := 0
	var only_l := 0
	var only_c := 0
	for i in n:
		lk += 1 if line[i] else 0
		ck += 1 if control[i] else 0
		if line[i] and not control[i]:
			only_l += 1
		elif control[i] and not line[i]:
			only_c += 1
	var ls := float(lk) / maxi(1, n)
	var cs := float(ck) / maxi(1, n)
	var w := _wald(only_l, only_c, n)
	var out := {"rule": "90%", "line": ls, "control": cs, "diff": w.diff, "low": w.low, "high": w.high, "pass": ls >= FIRED_MIN}
	if not out.pass and cs < FIRED_MIN:
		out.rule = "against the control"
		out.pass = n > 0 and w.high >= 0.0
	return out


## Criterion 2 of `given` (play): `diffs` the per-seed return differences (line less
## control). PASS when the 95% interval of their paired mean is not wholly below 0.
## Returns {pass, n, mean, low, high, verdict}: verdict "better" (wholly above 0),
## "level" (spans 0), "worse" (wholly below 0), "none" (no seed).
static func judge_return(diffs: Array) -> Dictionary:
	var pm := paired_mean(diffs)
	var verdict := "none"
	if pm.n > 0:
		verdict = "better" if pm.low > 0.0 else ("worse" if pm.high < 0.0 else "level")
	return {"pass": verdict != "none" and verdict != "worse", "n": pm.n, "mean": pm.mean, "low": pm.low,
		"high": pm.high, "verdict": verdict}


## Whether a given perk did its work in run `r` (given's criterion 1): fired (RunState
## FIRED), or for REGULAR a box changed, for READ THE FLARE a box left on its word.
static func _used(id: String, r: Dictionary) -> bool:
	if RunState.FIRED.has(id):
		return int(r.fired.get(id, 0)) > 0
	match id:
		"regular":
			return int(r.stats.box_changes) > 0
		"read1":
			return int(r.counters.get("flare_left", 0)) > 0
	return false


## The deal's ceiling of `line` (docs/roadmap.md 十二.3, "are there enough picks for a
## line to come together", money left out): `runs` whole runs of
## SimBots.reach_spec(line, rerolls), seeds `seed_prefix`-0 .. Returns {line, rerolls,
## runs, core (the dealt core, in GIVEN's order), engines (the line's `engine` perks that
## are dealt), whole ([a share a layer]: of the runs that played the layer, those holding
## the whole core when it ended), engine (the same for at least one engine), done (the
## median round, morning and reward rounds counted, at which the core was complete, of
## the runs that completed it; -1 when none did), never (the share of runs that never
## did), cards ({id: [held share a layer]}), rerolls_run (a run, free and paid),
## free_run and paid_run (of them, the free ones, RunConfig.free_rerolls, and the paid
## ones), cost (dollars paid for them a run), rounds (rounds dealt a run, morning and
## reward)}.
static func reach(line: String, base_forms: Array, runs: int, seed_prefix := "SIM", rerolls := 0,
		config: RunConfig = null) -> Dictionary:
	if config == null:
		config = RunConfig.standard()
	var layers := config.layers.size()
	var spec := SimBots.reach_spec(line, rerolls)
	var core: Array = spec.params.perks
	var engines: Array = spec.params.engine.filter(func(id): return Catalog.kind(Catalog.standard().perk(id)) != "shelf")
	var played := []
	var whole := []
	var engine := []
	for l in layers:
		played.append(0)
		whole.append(0)
		engine.append(0)
	var cards := {}
	for id in core:
		cards[id] = whole.duplicate()
	var done := []
	var n_rerolls := 0
	var n_free := 0
	var cost := 0
	var rounds := 0
	for i in runs:
		var r := SimRun.play(spec, base_forms, "%s-%d" % [seed_prefix, i], config)
		n_rerolls += int(r.stats.rerolls)
		n_free += int(r.stats.free_rerolls)
		cost += int(r.counters.get("reroll_cost", 0))
		rounds += int(r.stats.rounds) + int(r.stats.reward_rounds)
		if r.counters.has("reach_round"):
			done.append(int(r.counters.reach_round))
		for l in mini(layers, r.held_by.size()):
			var held: Dictionary = r.held_by[l]
			played[l] += 1
			if core.all(func(id): return int(held.get(id, 0)) > 0):
				whole[l] += 1
			if engines.any(func(id): return int(held.get(id, 0)) > 0):
				engine[l] += 1
			for id in core:
				if int(held.get(id, 0)) > 0:
					cards[id][l] += 1
	var share := func(counts: Array) -> Array:
		var out := []
		for l in layers:
			out.append(float(counts[l]) / played[l] if played[l] > 0 else -1.0)
		return out
	var card_shares := {}
	for id in core:
		card_shares[id] = share.call(cards[id])
	var n := maxf(1.0, runs)
	return {"line": line, "rerolls": rerolls, "runs": runs, "core": core.duplicate(), "engines": engines,
		"whole": share.call(whole), "engine": share.call(engine), "done": median(done) if not done.is_empty() else -1,
		"never": 1.0 - done.size() / n, "cards": card_shares, "rerolls_run": n_rerolls / n, "free_run": n_free / n,
		"paid_run": (n_rerolls - n_free) / n, "cost": cost / n,
		"rounds": rounds / n}


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
