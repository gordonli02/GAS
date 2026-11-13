class_name SimProbes
extends RefCounted
## The simulator's adversarial layer (docs/roadmap.md 七.1 and 七.7: "每个新规则配一个找漏洞的机器人"):
## probes. The strategy bots (SimBots.NAMES) play to win by their line; a probe plays to
## break a rule, and asserts the rule held. A probe is
##   name    what tools/sim_runs --probes prints it as
##   rule    one line on the rule it attacks
##   how     one line on how it is run
##   check   a Callable(forms, runs, boxes) -> {ok: bool, text: String, numbers: Dictionary}
##           (runs: whole runs of the probe bot; boxes: boxes a column at fixed perks)
## To add a probe for a new rule (the next ones, not written yet: boxes partly sold by
## other customers x the last sale; the held column): write its check here, in two parts
## where it can be two (the data layer at fixed perks, SimData; whole runs of a bot
## holding the perks the exploit needs, SimBots.given, so the run really has them), add a
## row to all(), and if it needs a bot of its own put it in SPECS and name it in
## SimBots.PROBES (a probe bot is not a strategy bot: it stays out of NAMES, the tables
## and the CI matrix, but tests/fixtures/sim_baseline.json still freezes it). A probe
## passing says only that this attack does not pay; a failing one is a rule to fix.

## The seed prefix of the probes' runs.
const SEED := "CH"
## Boxes a column of the fixed-perk part, and runs of the whole-run part, when asked for
## nothing (tools/sim_runs --churn-boxes, --probe-runs; the test uses fewer).
const BOXES := 200
const RUNS := 100


## Every probe, in the order tools/sim_runs prints them.
static func all() -> Array:
	return [
		{"name": "churn",
		"rule": "FIRST PULL x REGULAR (docs/perk_research.md 5.11): 20 tickets a box, then a new box, must not pay once the fees count (the fee's floor)",
		"how": "fixed perks (SimData.churn_return at each of CHURN_SETS), then the churn bot playing whole runs holding FIRST PULL 2 and REGULAR 2",
		"check": Callable(SimProbes, "check_churn")},
	]


## The probe called `name` (an empty dictionary: none).
static func find(name: String) -> Dictionary:
	for p in all():
		if p.name == name:
			return p
	return {}


## Runs the probe `name`: its row of all() plus the check's {ok, text, numbers}.
static func run(name: String, forms: Array, runs := RUNS, boxes := BOXES) -> Dictionary:
	var p := find(name)
	if p.is_empty():
		return {"name": name, "ok": false, "text": "no such probe", "numbers": {}}
	var r: Dictionary = p.check.call(forms, runs, boxes)
	r.name = name
	return r


## The churn bot's spec holding FIRST PULL 2 and REGULAR 2 from the start (free), buying
## no perks: the whole-run part of the churn probe. Before `given` existed the churn bot
## never held FIRST PULL in a run (it could not pay for it before its first box was
## churned), so the whole-run check tested nothing; this one starts with the exploit's
## perks in hand.
static func churn_given_spec() -> Dictionary:
	var s := SimBots.spec("churn")
	s.blocks.perks = "none"
	s.params.given = {"firstpull": 2, "regular": 2}
	return s


## The churn probe. 1: SimData.churn_return at each of CHURN_SETS, return with the fees
## 1 or under for every set. 2: `runs` whole runs of the churn bot holding FIRST PULL 2
## and REGULAR 2, its return with the fees (summary's `return_fees`) 1 or under.
## numbers: {sets: [{levels, return, return_fees, fee}], whole_return, whole_return_fees,
## whole_fees (dollars of fees a run), worst (the highest return_fees of part 1)}.
static func check_churn(forms: Array, runs: int, boxes: int) -> Dictionary:
	var ok := true
	var lines := []
	var sets := []
	var worst := 0.0
	for levels in SimData.CHURN_SETS:
		var c := SimData.churn_return(forms, levels, boxes)
		var label := "no perks" if levels.is_empty() else ", ".join(levels.keys().map(func(k): return "%s %d" % [k, levels[k]]))
		var under: bool = c.return_fees <= 1.0
		ok = ok and under
		worst = maxf(worst, c.return_fees)
		sets.append({"levels": levels, "return": c["return"], "return_fees": c.return_fees, "fee": c.fee})
		lines.append("  fixed perks, %d boxes a column: %-28s return %.3f, with fees %.3f, fee $%d  %s" % [boxes, label,
			c["return"], c.return_fees, c.fee, "ok" if under else "OVER 1"])
	var s := SimReport.summary(churn_given_spec(), forms, runs, SEED)
	var whole_ok: bool = s.return_fees <= 1.0
	ok = ok and whole_ok
	lines.append("  whole runs, %d, holding FIRST PULL 2 + REGULAR 2: return %.3f, with fees %.3f, fees $%.0f a run  %s" % [runs,
		s["return"], s.return_fees, s.fees, "ok" if whole_ok else "OVER 1"])
	return {"ok": ok, "text": "\n".join(lines), "numbers": {"sets": sets, "worst": worst, "whole_return": s["return"],
		"whole_return_fees": s.return_fees, "whole_fees": s.fees}}
