class_name SimBots
extends RefCounted
## The bots' table: each bot is a spec, plain data, naming the variant of each day's
## block it uses (SimBlocks.VARIANTS; a block left out is its default) and the params
## those variants read (PARAMS, overridden by the bot's own). The targets for most of
## them are docs/roadmap.md's bots table.
##   work     works every day, never buys a ticket; buys SAVINGS as the work line does
##            (RunConfig.line_buys), so it clears every layer on its last day (the wage
##            is derived from the debt for that, RunConfig)
##   blind    plays whenever it can pay for a ticket, works when it cannot
##   borrow   as blind, but takes the whole house line before giving a day up
##   gamble   plays by default, works only when its cash cannot pay for a day's tickets
##            (`gamble_day` tickets at the machine's cheapest price): the steady gambler
##            who builds nothing
##   perks    as blind, but every round of perk offers it buys the cheapest offer that
##            costs no more than half its cash, then the next, and so on (the perks
##            are where a run grows); it opens in batches when it has QUICK HANDS
##            (never in a run now: QUICK HANDS waits for M13)
##   skip     as blind, but never buys a perk: every round of offers is skipped for its
##            item (which it never uses)
##   build    as blind, but each morning it buys its shelf perks, then the first of its
##            dealt perks offered (in its order of preference), each while it costs at
##            most `share` of the cash and leaves `reserve` tickets, and skips the rest:
##            the perks that lift the return of any ticket. HIGH ROLLER is the bet
##            (fixed): a level is bought only when the cash left after it holds
##            `high_roller_cash` tickets at the new price. With ALL IN it stakes a
##            window whenever it can while the stake is under half its cash (one ticket
##            at a time, so every window can be staked)
##   the line bots, one a line (docs/roadmap.md M9.5, M9.8 step 1 stage 3): `clearing`,
##            `jackpot`, `small`, `batch` (the window line: STREAK, ALL IN, MAGNET;
##            QUICK HANDS, CHAIN and ENCORE wait for the shop outside the run, M13) and
##            `money`. The morning (perks "core"): the line's core first; holding none
##            of its `engine` perks it buys the first it can with all its cash, then as
##            build does (enter "line": it may work instead, `work_below`). At the
##            machine each plays its line, with a daily stop-loss (`stop`) while it buys
##            perks, off on the layer's last `endgame` days; with `work_out` it works
##            when working the days left reaches the debt. Feeding small bills, so the
##            cash stays in the pocket.
##            clearing  the box with the fewest tickets left, never past its end, and
##                      stays on it until it is cleared (the last sale, CLOSER,
##                      SNOWBALL, ASSEMBLY LINE; FIRST PULL from each new box)
##            jackpot   Big Catch / Ka-Bawk!; with READ THE FLARE only a box whose top
##                      prize is still in (any form's: BIG FISH doubles every top), and
##                      when the flare says it is gone, another such box or NEW BOX
##                      while the fee is under `fee_max` tickets (REGULAR cuts it);
##                      small batches to read it often
##            small     Hot Plate / Nugget Rush, in volume
##            batch     the forms that win most often, in windows of ten (never left
##                      half open), leaving only after a window without a winner (STREAK
##                      kept alive); ALL IN under `push` of the cash, on a window that
##                      paid `push_paid` tickets
##            money     Lucky Spur, small batches, leaving at a cash `floor` (NET WORTH
##                      pays by the cash in the pocket; SAVINGS grows what is left)
##            Each has 3 to 5 named variants of its params (VARIANTS: a line's strength is
##            its best variant, roadmap 七.4), and a core set for the given-cards test
##            (GIVEN, SIGNATURE: tools/sim_runs --given)
##   churn    a probe bot (PROBES, SimProbes), not a strategy bot: the exploit check for FIRST PULL x REGULAR (docs/perk_research.md 5.11):
##            buys both whenever it can pay for them, and at the machine buys CHURN
##            tickets of a column, then changes the box, again and again. Its return
##            counted with the fees (summary's `return_fees`) must stay at 1 or under
## A bot that cannot work (NO WAY BACK bought) plays instead.
## "Can pay for a ticket" is the slot's rule (SimRun.can_buy): bills, and coins under the
## smallest bill (Economy.coins_for, G 2026-11-07), so every bot that goes to the machine
## buys at least one ticket there; the result's `idle_days` counts the days one did not.

## The bots, in the order the tools print them. Keep this declaration on one line, in
## this form: .github/workflows/sim.yml's `plan` job reads the names out of it with sed.
const NAMES := ["work", "blind", "borrow", "gamble", "perks", "skip", "build", "clearing", "jackpot", "small", "batch", "money"]

## The probe bots (SimProbes): bots built to break a rule, not to win. Their specs are in
## SPECS like any bot's, so the loop plays them; they stay out of NAMES (the tables and
## the CI matrix) and are named when asked for (`--bots=churn`) and in the baseline fixture.
const PROBES := ["churn"]

## Every param a block reads, with the value a bot gets when its spec leaves it out.
const PARAMS := {
	"gamble_day": 25,        # enter "gamble": the bot works when its cash is less than this many tickets
	"forms": [],             # column "pick": the forms (FormDef.id) picked among when sold (none: any column)
	"batch": SimData.BATCH,  # stay "batches": tickets a batch
	"push": 0.5,             # stay: ALL IN's window is staked while the stake is under this share of the cash
	"share": 0.6,            # perks "cheapest" and "line": the share of the cash a perk may cost
	"perks": [],             # perks "line": the dealt perks taken, best first
	"shelf": [],             # perks "line": the shelf perks bought, every level, in this order (SAVINGS only on the work line's checkpoints)
	"reserve": 0,            # perks "line": a dealt perk is bought only if the cash left holds this many tickets of the cheapest price
	"high_roller_cash": 25,  # perks "line": HIGH ROLLER only if the cash then holds this many tickets (G: 20 to 30)
	"given": {},             # the run: perks held from the start, free ({id: level}; the given-cards test)
	"engine": [],            # perks "core", enter "line": the line's engines (holding none, it buys the first it can with all its cash)
	"work_below": 0,         # enter "line": holding no engine, it works while the cash is under this (times the stake); 0 never
	"work_out": 0,           # enter "line": 1 works out a layer the wages for the days left can pay (0: plays and pays at once)
	"stop": 1.0,             # the line stays: the share of the day's money it may lose while it buys perks (1: no stop-loss)
	"endgame": 1,            # the line stays: on the layer's last this many days no stop-loss and no floor
	"floor": 0,              # stay "floor": the cash kept, in dollars times the stake
	"push_paid": 0,          # stay "windows": ALL IN only on a window that paid this many tickets of the cheapest price
	"fee_max": 30,           # box "flare", column "top": NEW BOX only while the fee is at most this many tickets
	"hunt": 0,               # stay "hunt": with JACKPOT HUNTER on, the tickets it plays on before paying a layer it can pay
}

## Each bot's blocks and params ({} for a bot that is all defaults). `build` takes the
## perks that lift the return of any ticket, cheapest and surest first (G, 2026-11-07,
## wants build to clear highest; a player who builds does not buy CLOSER or FIRST PULL
## in a layer whose boxes hold 900 tickets or more; `clearing` measures those), and
## keeps 100 tickets of cash. jackpot buys REGULAR for what it opens: READ THE FLARE
## needs CLOSER or REGULAR, and JACKPOT HUNTER needs READ THE FLARE.
const SPECS := {
	"work": {"blocks": {"enter": "work", "perks": "savings"}},
	"blind": {},
	"borrow": {"blocks": {"enter": "borrow"}},
	"gamble": {"blocks": {"enter": "gamble"}},
	"perks": {"blocks": {"perks": "cheapest"}, "params": {"share": 0.5}},
	"skip": {"blocks": {"perks": "skip"}},
	"build": {"blocks": {"perks": "line"}, "params": {"perks": ["prizes", "luck", "scrap", "penny", "bigfish", "streak",
		"stacker", "fortune", "pity", "middle"], "shelf": [], "share": 0.6, "reserve": 100, "forms": []}},
	"clearing": {"blocks": {"enter": "line", "perks": "core", "column": "clear", "stay": "clear"},
		"params": {"engine": ["closer", "firstpull"], "perks": ["closer", "firstpull", "assembly", "snowball"], "shelf": [],
		"share": 0.6, "forms": [], "stop": 1.0}},
	"jackpot": {"blocks": {"enter": "line", "perks": "core", "column": "top", "stay": "hunt", "box": "flare"},
		"params": {"engine": ["bigfish", "pity"], "perks": ["bigfish", "pity", "hunter"], "shelf": ["regular", "read1"],
		"share": 0.6, "forms": ["catch", "kabawk"], "batch": 5, "stop": 0.5, "fee_max": 30, "hunt": 200, "work_below": 300}},
	"small": {"blocks": {"enter": "line", "perks": "core", "stay": "stop"},
		"params": {"engine": ["penny", "scrap", "stacker"], "perks": ["penny", "stacker", "consolation", "packed", "scrap",
		"crumbs", "trashking"], "shelf": [], "share": 0.6, "forms": ["plate", "nugget"], "stop": 1.0, "work_below": 100}},
	"batch": {"blocks": {"enter": "line", "perks": "core", "stay": "windows", "box": "magnet"},
		"params": {"engine": ["streak", "magnet"], "perks": ["streak", "allin", "magnet", "crumbs", "consolation"],
		"shelf": ["bet"], "share": 0.6, "forms": ["plate", "peckeye", "nugget"], "stop": 1.0, "push": 0.5, "work_below": 300}},
	"money": {"blocks": {"enter": "line", "perks": "core", "stay": "floor"},
		"params": {"engine": ["savings", "middle"], "perks": ["worth", "middle"], "shelf": ["savings"], "share": 0.6,
		"forms": ["spur"], "batch": 5, "floor": 150, "stop": 0.5}},
	"churn": {"blocks": {"perks": "line", "box": "churn"}, "params": {"perks": ["firstpull"], "shelf": ["regular"],
		"share": 1.0, "forms": [], "batch": SimData.CHURN}},
}


## Each line bot's named variants: overrides laid over its spec (spec's `overrides`).
## tools/sim_runs --variants runs them all; a line's strength is its best (roadmap 七.4).
## The bot's own spec is one of them (named so, to be compared with the others).
const VARIANTS := {
	"clearing": {"stop50": {"params": {"stop": 0.5}}, "stop30": {"params": {"stop": 0.3}},
		"nostop": {"params": {"stop": 1.0}}, "work": {"params": {"work_below": 150}}},
	"jackpot": {"nowork": {"params": {"stop": 0.5, "work_below": 0}}, "nostop": {"params": {"stop": 1.0}},
		"work300": {"params": {"work_below": 300}}, "fee15": {"params": {"fee_max": 15}}, "hunt0": {"params": {"hunt": 0}}},
	"small": {"nowork": {"params": {"stop": 0.5, "work_below": 0}}, "nostop": {"params": {"stop": 1.0}},
		"stop50": {"params": {"stop": 0.5}}, "plate": {"params": {"forms": ["plate"]}}},
	"batch": {"push50": {"params": {"push": 0.5}}, "push25": {"params": {"push": 0.25}},
		"work0": {"params": {"work_below": 0}}, "paid5": {"params": {"push_paid": 5}}, "stop50": {"params": {"stop": 0.5}}},
	"money": {"floor100": {"params": {"floor": 100}}, "floor50": {"params": {"floor": 50}},
		"nostop": {"params": {"stop": 1.0}}, "batch10": {"params": {"batch": 10}}},
}


## The given-cards test (docs/roadmap.md M9.8 step 1 stage 3, "用得上"): each line's
## core, level 1 each, held from the start (with what they require: READ THE FLARE
## needs CLOSER or REGULAR, JACKPOT HUNTER BIG FISH and READ THE FLARE, TRASH KING
## SCRAP DEALER, ALL IN STREAK, NET WORTH SAVINGS, ASSEMBLY LINE and SNOWBALL CLOSER).
## clearing has no REGULAR: the clearing line never changes a box.
const GIVEN := {
	"clearing": {"closer": 1, "firstpull": 1, "assembly": 1, "snowball": 1},
	"jackpot": {"bigfish": 1, "pity": 1, "hunter": 1, "read1": 1, "regular": 1},
	"small": {"penny": 1, "stacker": 1, "scrap": 1, "trashking": 1, "consolation": 1},
	"batch": {"streak": 1, "allin": 1, "magnet": 1},
	"money": {"savings": 1, "worth": 1, "middle": 1},
}

## Each line's signature measure in the given-cards test: [table, key] of a run's
## `fired` or `fired_pct` (SimRun.play), counted per 100 tickets: boxes cleared (CLOSER
## firings), top prizes hit (BIG FISH firings), PENNY JAR firings, STREAK's percent
## added, NET WORTH's percent added.
const SIGNATURE := {
	"clearing": ["fired", "closer"], "jackpot": ["fired", "bigfish"], "small": ["fired", "penny"],
	"batch": ["fired_pct", "streak"], "money": ["fired_pct", "worth"],
}


## The given-cards test's line arm: the line bot (with `overrides`, a variant) holding
## its GIVEN core from the start, the morning's perk buying off (perks "none"), so it
## spends nothing on perks and differs from the control only in its play.
static func given_spec(line: String, overrides: Dictionary = {}) -> Dictionary:
	var s := spec(line, overrides)
	s.blocks.perks = "none"
	s.params.given = GIVEN.get(line, {}).duplicate()
	return s


## The given-cards test's control arm: blind (every block's default) holding the same
## core, on the same seeds (and dice). Named "<line> control".
static func control_spec(line: String) -> Dictionary:
	var s := spec("blind", {"params": {"given": GIVEN.get(line, {}).duplicate()}})
	s.name = line + " control"
	return s


## The bot `name`'s spec, whole: {name, blocks: every block's variant, params: every
## param}. `overrides` ({blocks: {...}, params: {...}}, either optional) is laid over
## it: a named variant of the bot. A name not in the table gets every default (it plays
## as blind does; the dice are the seed's, SimRun.play). A fresh copy: changing it
## changes nothing here.
static func spec(name: String, overrides: Dictionary = {}) -> Dictionary:
	var own: Dictionary = SPECS.get(name, {})
	var blocks := {}
	for b in SimBlocks.VARIANTS:
		blocks[b] = SimBlocks.VARIANTS[b][0]
	var params: Dictionary = PARAMS.duplicate(true)
	for layer in [own, overrides]:
		var lb: Dictionary = layer.get("blocks", {})
		for b in lb:
			blocks[b] = lb[b]
		var lp: Dictionary = layer.get("params", {})
		for k in lp:
			params[k] = lp[k].duplicate(true) if lp[k] is Array or lp[k] is Dictionary else lp[k]
	return {"name": name, "blocks": blocks, "params": params}


## A spec as one line of text: the blocks off their default, then the params off
## PARAMS (what stage 2's reports print as "what this bot is").
static func describe(s: Dictionary) -> String:
	var parts := []
	for b in SimBlocks.VARIANTS:
		if s.blocks[b] != SimBlocks.VARIANTS[b][0]:
			parts.append("%s=%s" % [b, s.blocks[b]])
	for k in PARAMS:
		if s.params[k] != PARAMS[k]:
			parts.append("%s=%s" % [k, str(s.params[k])])
	return "%s: %s" % [s.name, ", ".join(parts) if not parts.is_empty() else "defaults"]
