class_name SimCtx
extends RefCounted
## What a bot's blocks (SimBlocks) see of one run: the run's own state, the ledger and
## the machine, the bot's dice and its spec (SimBots.spec: which variant of each block,
## and the params they read), and the day so far. One per run (SimRun.play); the loop
## keeps `m`, `col` and `bought` current.

var run: RunState
var e: Economy
var m: MachineLogic
## The bot's dice, seeded by the seed alone (SimRun.play: every bot on a seed draws the
## same dice, docs/roadmap.md 七.6). Drawn only
## when a column is picked (SimBlocks.column): the order and the number of draws are
## part of every run's replay (tests/fixtures/sim_baseline.json).
var rng: RandomNumberGenerator
## SimBots.spec's {name, blocks: {block: variant}, params: {name: value}}.
var spec: Dictionary
var col := -1        ## today's column (-1 before one is picked)
var bought := 0      ## tickets bought today
var day_layer := 0   ## the layer the day began in
## Room for what a bot or a report wants to count over the run (nothing today).
var counters := {}


## A context over an existing run (tests, or a bot's block asked outside a run). `spec`
## defaults to an unknown bot's: every block's default.
static func of(p_run: RunState, p_e: Economy, p_m: MachineLogic = null, p_spec: Dictionary = {}) -> SimCtx:
	var c := SimCtx.new()
	c.run = p_run
	c.e = p_e
	c.m = p_m
	c.rng = RandomNumberGenerator.new()
	c.spec = p_spec if not p_spec.is_empty() else SimBots.spec("")
	return c


## The variant the bot uses for `block` (SimBlocks.VARIANTS).
func variant(block: String) -> String:
	return str(spec.blocks[block])


## One of the bot's params (SimBots.PARAMS, overridden by its own).
func param(key: String) -> Variant:
	return spec.params[key]


## A new day: nothing bought, no column yet.
func start_day() -> void:
	col = -1
	bought = 0
	day_layer = run.layer
