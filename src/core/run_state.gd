class_name RunState
extends RefCounted
## One run of the story mode: a debt in three layers, each due within its days.
## Pure logic; the money itself stays in Economy, which every method here is handed.
##
## A day is one of two things: a day at the machine (as many tickets as the player
## likes, until they leave) or a shift of work (a sure wage, no tickets that day).
## The debt is paid in one go, any time the money is there, and the next layer starts
## at once; on the last day of a layer, leaving pays it or ends the run.
## Borrowed money goes on top of what is due in the layer, with interest.
## Rules: docs/roadmap.md "一局的结构"; numbers: RunConfig.

const PLAYING := "playing"
const CLEARED := "cleared"
const FAILED := "failed"

var config: RunConfig
var seed := ""
var scenes: Array = []     ## room id of each layer; a bought scene may replace one later
var layer := 0
var day := 1               ## 1 .. days of the layer
var today := ""            ## "" not chosen yet, "play" at the machine, "work" worked a shift
var shifts := 0            ## shifts worked in this layer (the wage follows it)
var borrowed := 0          ## principal borrowed in this layer
var loan_due := 0          ## that plus interest: added to what the layer asks
var loan_bonus := 0        ## extra house line from perks (none yet)
var status := PLAYING
var story := "intro"       ## a story card waiting to be read: "", "intro", "twist", "ending", "failed"
## For the settlement and, later, achievements and the money kept between runs.
var stats := {"days": 0, "play_days": 0, "shifts": 0, "tickets": 0, "wages": 0, "borrowed": 0,
	"interest": 0, "repaid": 0, "box_changes": 0, "fees": 0, "last_sales": 0, "days_spared": 0,
	"layers_cleared": 0, "discarded": 0}   ## discarded: tickets bought and thrown away unopened


static func start(run_config: RunConfig, seed_text: String, layer_scenes: Array) -> RunState:
	var r := RunState.new()
	r.config = run_config
	r.seed = seed_text
	r.scenes = layer_scenes.duplicate()
	return r


## A fresh ledger for this run, at the first layer's stake.
func new_economy() -> Economy:
	var e := Economy.new()
	e.start_cash = config.start_cash
	e.cash = config.start_cash
	e.bills = RunConfig.bills(stake())
	return e


## The layer's machine: the forms at its stake, its boxes and its last-sale prize.
## `light`: boxes without the print on each ticket, for simulations.
func new_machine(base_forms: Array, light := false) -> MachineLogic:
	var m := MachineLogic.new(stage_forms(base_forms), "%s-L%d-0001" % [seed, layer + 1], config.box_model(layer), light)
	m.last_sale = int(stage().get("last_sale", 0))
	return m


## The forms the layer's machine sells, one column each, at the layer's stake: the
## layer's own list ("forms", form ids in column order) or, without one, all of them.
## An id that is not installed leaves its column out.
func stage_forms(base_forms: Array) -> Array:
	var picked: Array = base_forms
	var wanted = stage().get("forms")
	if wanted is Array and not wanted.is_empty():
		picked = []
		for uid in wanted:
			for f: FormDef in base_forms:
				if f.uid() == str(uid):
					picked.append(f)
		if picked.is_empty():
			picked = base_forms
	var out := []
	for f: FormDef in picked:
		out.append(f.scaled(stake()))
	return out


func stage() -> Dictionary:
	return config.layer(layer)


func stake() -> int:
	return int(stage().stake)


func scene() -> String:
	return str(scenes[clampi(layer, 0, scenes.size() - 1)]) if not scenes.is_empty() else ""


func days() -> int:
	return int(stage().days)


func last_day() -> bool:
	return day >= days()


func playing() -> bool:
	return status == PLAYING


## Everything owed in this layer: the debt, and what was borrowed with its interest.
func due() -> int:
	return int(stage().debt) + loan_due


## Pay for the next shift. It rises at fixed shifts; the player only ever sees today's.
func wage() -> int:
	var wages: Array = stage().wages
	return int(wages[mini(shifts, wages.size() - 1)])


## What the last shift worked in this layer paid.
func last_wage() -> int:
	var wages: Array = stage().wages
	return int(wages[clampi(shifts - 1, 0, wages.size() - 1)])


func can_choose() -> bool:
	return playing() and today == ""


## Spends the day at the machine.
func play() -> bool:
	if not can_choose():
		return false
	today = "play"
	stats.play_days += 1
	return true


## Spends the day at work: the wage now, no tickets today.
func work(e: Economy) -> bool:
	if not can_choose():
		return false
	var w := wage()
	e.earn(w)
	today = "work"
	shifts += 1
	stats.shifts += 1
	stats.wages += w
	return true


func loan_step() -> int:
	return int(stage().loan_step)


func loan_limit() -> int:
	return int(stage().loan) + loan_bonus


func loan_left() -> int:
	return maxi(0, loan_limit() - borrowed)


func can_borrow() -> bool:
	return playing() and loan_left() >= loan_step()


## One press of LOAN: cash now, the same plus interest on top of what is due.
func borrow(e: Economy) -> bool:
	if not can_borrow():
		return false
	var amount := loan_step()
	var interest := amount * config.loan_interest / 100
	e.add_loan(amount)
	borrowed += amount
	loan_due += amount + interest
	stats.borrowed += amount
	stats.interest += interest
	return true


func change_fee() -> int:
	return int(stage().get("change_fee", 0))


## A new box in column `i`, for the fee.
func change_box(e: Economy, machine: MachineLogic, i: int) -> bool:
	if not playing() or not e.pay(change_fee()):
		return false
	machine.change_box(i)
	stats.box_changes += 1
	stats.fees += change_fee()
	return true


## The machine sold `n` tickets, `last_sales` of them the last of their box.
func count_sales(n: int, last_sales := 0) -> void:
	stats.tickets += n
	stats.last_sales += last_sales


## Cash and machine credit cover what is due (a bill being fed has to land first).
func can_pay(e: Economy) -> bool:
	return playing() and e.bill == 0 and e.cash + e.credit >= due()


## Pays the layer in full and moves on at once: the next layer starts on a new day,
## or the run is cleared. Days left over are counted as spared.
func pay(e: Economy) -> bool:
	if not can_pay(e):
		return false
	e.cash_out()
	var amount := due()
	e.pay(amount)
	stats.repaid += amount
	stats.days_spared += days() - day
	stats.layers_cleared += 1
	stats.days += 1
	if layer >= config.layers.size() - 1:
		status = CLEARED
		story = "ending"
		return true
	layer += 1
	day = 1
	today = ""
	shifts = 0
	borrowed = 0
	loan_due = 0
	story = "twist"
	e.bills = RunConfig.bills(stake())
	return true


## The player leaves for the day (or has worked the shift). On the last day of a layer
## this settles it: paid if the money is there, otherwise the run is over.
func end_day(e: Economy) -> void:
	if not playing():
		return
	if last_day():
		if not pay(e):
			stats.days += 1
			status = FAILED
			story = "failed"
		return
	stats.days += 1
	day += 1
	today = ""


func to_dict() -> Dictionary:
	return {"seed": seed, "scenes": scenes.duplicate(), "layer": layer, "day": day, "today": today,
		"shifts": shifts, "borrowed": borrowed, "loan_due": loan_due, "loan_bonus": loan_bonus,
		"status": status, "story": story, "stats": stats.duplicate()}


## A run saved with to_dict(), or null if it does not fit the config.
static func from_dict(d: Dictionary, run_config: RunConfig) -> RunState:
	var r := RunState.new()
	r.config = run_config
	r.seed = str(d.get("seed", ""))
	var s = d.get("scenes", [])
	r.scenes = s.duplicate() if typeof(s) == TYPE_ARRAY else []
	for k in ["layer", "day", "shifts", "borrowed", "loan_due", "loan_bonus"]:
		r.set(k, int(d.get(k, r.get(k))))
	r.today = str(d.get("today", ""))
	r.status = str(d.get("status", PLAYING))
	r.story = str(d.get("story", ""))
	var st = d.get("stats", {})
	if typeof(st) == TYPE_DICTIONARY:
		for k in r.stats:
			r.stats[k] = int(st.get(k, 0))
	if r.seed == "" or r.layer < 0 or r.layer >= run_config.layers.size() or r.day < 1 or r.day > r.days() \
			or not ["", "play", "work"].has(r.today) or not [PLAYING, CLEARED, FAILED].has(r.status) \
			or r.shifts < 0 or r.borrowed < 0 or r.loan_due < r.borrowed:
		return null
	return r
