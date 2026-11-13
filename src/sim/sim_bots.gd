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
##   build and the line bots: as blind, but each morning they buy their shelf perks,
##            then the first of their dealt perks offered (in their order of
##            preference), each while it costs at most `share` of the cash, and skip
##            the rest; at the machine they pick a column of their line's forms when
##            one is there. `build` takes any line's engines; `clearing`, `jackpot`,
##            `small`, `batch` and `money` one line each (docs/roadmap.md M9.5: a bot
##            per line). HIGH ROLLER is the bet (fixed): a level is bought only when
##            the cash left after it holds `high_roller_cash` tickets at the new price.
##            With ALL IN they stake a window whenever they can while the stake is
##            under half their cash (one ticket at a time, so every window can be
##            staked). `batch` is the window line now (STREAK, ALL IN, MAGNET): QUICK
##            HANDS, CHAIN and ENCORE wait for the shop outside the run (M13)
##   churn    the exploit check for FIRST PULL x REGULAR (docs/perk_research.md 5.11):
##            buys both whenever it can pay for them, and at the machine buys CHURN
##            tickets of a column, then changes the box, again and again. Its return
##            counted with the fees (summary's `return_fees`) must stay at 1 or under
## A bot that cannot work (NO WAY BACK bought) plays instead.
## "Can pay for a ticket" is the slot's rule (SimRun.can_buy): bills, and coins under the
## smallest bill (Economy.coins_for, G 2026-11-07), so every bot that goes to the machine
## buys at least one ticket there; the result's `idle_days` counts the days one did not.

## The bots, in the order the tools print them. Keep this declaration on one line, in
## this form: .github/workflows/sim.yml's `plan` job reads the names out of it with sed.
const NAMES := ["work", "blind", "borrow", "gamble", "perks", "skip", "build", "clearing", "jackpot", "small", "batch", "money", "churn"]

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
	"clearing": {"blocks": {"perks": "line"}, "params": {"perks": ["closer", "firstpull", "assembly", "snowball"],
		"shelf": ["regular"], "share": 0.6, "forms": []}},
	"jackpot": {"blocks": {"perks": "line"}, "params": {"perks": ["bigfish", "pity", "hunter"], "shelf": ["regular", "read1"],
		"share": 0.6, "forms": ["catch", "kabawk"]}},
	"small": {"blocks": {"perks": "line"}, "params": {"perks": ["penny", "stacker", "consolation", "packed", "scrap", "crumbs",
		"trashking"], "shelf": [], "share": 0.6, "forms": ["plate", "nugget"]}},
	"batch": {"blocks": {"perks": "line"}, "params": {"perks": ["streak", "allin", "magnet", "crumbs", "consolation"],
		"shelf": ["bet"], "share": 0.6, "forms": []}},
	"money": {"blocks": {"perks": "line"}, "params": {"perks": ["worth", "middle"], "shelf": ["savings"], "share": 0.6,
		"forms": ["spur"]}},
	"churn": {"blocks": {"perks": "line", "box": "churn"}, "params": {"perks": ["firstpull"], "shelf": ["regular"],
		"share": 1.0, "forms": [], "batch": SimData.CHURN}},
}


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
