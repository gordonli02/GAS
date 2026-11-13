class_name SimData
extends RefCounted
## The simulator's data layer (docs/roadmap.md 七.1): no bot and no run, only what the
## boxes and the perks pay at fixed levels. What a dollar of tickets pays back
## (box_return), the churn exploit at fixed perks (churn_return), ALL IN's odds on each
## form (push_odds), each form's shape (form_table), and the perk levels tools/sim_runs
## prints them at (EV_SETS, CHURN_SETS).

## Perk levels whose return tools/sim_runs prints (box_return), one build per line. A
## "snow" key is not a perk: SNOWBALL's count of boxes already cleared; a "form" key
## (a FormDef.id) plays that form's boxes alone. NET WORTH (the cash, kept at 0 here),
## SEAL, the reading chain and the items (REEL IN) do nothing in box_return; ALL IN
## is played on every window it can be (box_return). Rows marked M13 hold QUICK HANDS,
## CHAIN or ENCORE, which no run sells now (they wait for the shop outside the run):
## kept as "what if" rows, they still compute.
const EV_SETS := [
	{}, {"prizes": 1}, {"prizes": 3}, {"scrap": 2}, {"luck": 3}, {"luck": 3, "fortune": 1},
	{"prizes": 1, "bigfish": 2}, {"luck": 1, "firstpull": 2}, {"luck": 1, "pity": 2},
	# The lines' full sets.
	{"closer": 2, "firstpull": 2, "assembly": 1, "snowball": 1, "regular": 2},
	{"bigfish": 2, "pity": 2, "hunter": 1, "read1": 1},
	{"penny": 2, "stacker": 1, "scrap": 2, "trashking": 1},
	{"multi": 2, "combo": 2, "again": 2, "streak": 2},                     # M13
	{"streak": 2, "allin": 1, "magnet": 2},                                # the window line, in a run now
	{"middle": 2},
	# The draft's combos: daily small prizes (batches of 20 with CHAIN), the
	# astronomical one (after ten boxes cleared), FLARE ONLY on BIG FISH.
	{"magnet": 2, "penny": 2, "stacker": 1, "multi": 2, "combo": 1},      # M13
	{"bigfish": 2, "bet": 3, "snowball": 1, "snow": 10},
	{"flare": 2, "bigfish": 2},
	{"prizes": 3, "bigfish": 2, "luck": 3, "fortune": 1, "closer": 2, "firstpull": 2, "snowball": 1},
	# The combo table (docs/perk_research.md section 5 part 14), a row each, for its
	# 期望回报 column.
	{"read1": 1, "bet": 3, "bigfish": 2},                                 # 猎大奖 (REEL IN is an item: not here)
	{"closer": 2, "firstpull": 2, "regular": 2, "read3": 1},              # 清盒
	{"magnet": 2, "penny": 2, "stacker": 1, "multi": 2, "combo": 2},      # 小奖 (M13)
	{"magnet": 2, "penny": 2, "stacker": 1},                              # 小奖 in a run now
	{"insurance": 2, "pity": 2, "form": "kabawk"},                        # 保险 (on Ka-Bawk!)
	{"allin": 1, "streak": 1, "read1": 1},                                # 梭哈 (needs STREAK 1)
	{"streak": 2, "magnet": 2, "multi": 2, "combo": 1},                   # 连庄 (M13)
	{"streak": 2, "magnet": 2},                                           # 连庄 in a run now
	{"savings": 3, "lowrate": 2, "shark": 2, "worth": 1},                 # 钱生钱 (NET WORTH needs cash: 0 here)
	{"seal": 2, "snowball": 1, "snow": 10, "bet": 3},                     # 封盒 (SEAL itself does nothing here)
	{"read1": 1, "allin": 1, "streak": 1},                                # 跨：信息换胜率
	{"magnet": 2, "insurance": 2, "pity": 2, "form": "kabawk"},           # 跨：确定性叠大奖票
	# The line that wins more often (section 15): CONSOLATION adds a little, PACKED and
	# CRUMBS alone add nothing; with PENNY JAR, CHAIN and STREAK they do.
	{"consolation": 1}, {"consolation": 2}, {"packed": 1}, {"packed": 2}, {"crumbs": 1}, {"crumbs": 2},
	{"packed": 2, "penny": 2, "consolation": 2},
	{"crumbs": 2, "multi": 2, "combo": 2},                                   # M13
	{"crumbs": 2, "consolation": 2, "streak": 2, "multi": 2, "combo": 1},    # M13
	# How they stack with PENNY JAR and STREAK (G, 2026-11-07: PACKED must not make
	# PENNY JAR much stronger), each beside the same without it.
	{"penny": 2}, {"packed": 2, "penny": 2}, {"crumbs": 2, "penny": 2},
	{"penny": 2, "streak": 2}, {"packed": 2, "penny": 2, "streak": 2},
]
## Perk levels the churn table (churn_return) prints: CHURN tickets a box, then NEW BOX.
const CHURN_SETS := [{}, {"regular": 2}, {"firstpull": 1, "regular": 2}, {"firstpull": 2, "regular": 2}]
## The tickets bought at once (box_return's cap on QUICK HANDS' batch; the bots' default
## batch, SimBots.PARAMS).
const BATCH := 25
const CHURN := 20        ## the churn exploit's tickets a box (Catalog.FIRST_TICKETS; the churn bot's batch)


## Each form's boxes in the run's model (the forms' shapes, G, M9.6), `boxes` boxes
## at stake 1, no perks: what a dollar of tickets pays back, winners per 100 tickets,
## top prizes a box, and the standard deviation of one ticket's prize (how bumpy the
## form is). Every form should pay back about the same; the rest is its shape.
static func form_table(base_forms: Array, boxes: int, seed_prefix := "FM") -> Array:
	var model := RunConfig.standard().box_model(0)
	var out := []
	for base: FormDef in base_forms:
		var f := base.shaped()
		var spent := 0
		var won := 0
		var winners := 0
		var tops := 0
		var sq := 0.0
		var tickets := 0
		for n in boxes:
			var box := BoxGenerator.build(f, "%s-%d" % [seed_prefix, n], model, true)
			spent += box.gross()
			won += box.prize_total()
			tickets += box.size
			for i in box.counts.size():
				if f.is_top(i):
					tops += box.counts[i]
			for t in box.tickets:
				if t.prize > 0:
					winners += 1
				sq += float(t.prize) * t.prize
		var mean := float(won) / tickets
		out.append({"form": f.id, "return": float(won) / spent, "winners": 100.0 * winners / tickets,
			"tops": float(tops) / boxes, "sd": sqrt(maxf(0.0, sq / tickets - mean * mean))})
	return out


## What a dollar of tickets pays back at given perk levels ({perk id: level}; a "snow"
## key sets SNOWBALL's count of boxes already cleared), over `boxes` whole boxes of
## every form bought out at stake 1 and at the bet, perks' bonuses and the
## last-sale prize included. The boxes load through the machine, so luck counts too.
## With QUICK HANDS the tickets are opened in batches of its size (at most BATCH), so
## CHAIN and ENCORE count; SNOWBALL grows as boxes are cleared; STREAK counts its
## windows. The cash is kept at zero (the ledger is not kept here), so NET WORTH adds
## nothing. With ALL IN every window that can be staked is (the stake counts as
## spent, the x3 as won). Pass one form in `base_forms`, or a "form" key in
## `perk_levels`, for that form's return alone.
static func box_return(base_forms: Array, perk_levels: Dictionary, boxes: int, seed_prefix := "EV") -> float:
	var run := RunState.start(RunConfig.standard(), seed_prefix, ["diner"])
	run.perks = perk_levels.duplicate()
	run.snow = int(run.perks.get("snow", 0))
	run.perks.erase("snow")
	if run.perks.has("form"):
		var only := str(run.perks.form)
		run.perks.erase("form")
		base_forms = base_forms.filter(func(f): return f.id == only)
	var pushes := run.effect("all_in") > 0
	var e := run.new_economy()
	e.cash = 0
	var m := run.new_machine(base_forms, true)
	var spent := 0
	var won := 0
	var batch := run.batch_size() > 0
	for col in m.forms.size():
		var done := 0
		var held := []
		while done < boxes:
			e.credit += m.price(col)
			var sold := m.sell_now(col, e)
			spent += m.price(col)
			if sold.last_sale:
				won += m.last_sale
				run.cleared_box(m)
			held.append({"form": m.forms[col], "ticket": sold.ticket, "box": sold.box, "bet": m.bet})
			# Asked each ticket: with ALL IN the batch stops at the window's end.
			var n := mini(BATCH, run.batch_size()) if batch else 1
			if held.size() >= n or m.boxes[col].cursor >= m.boxes[col].size:
				var before := e.won
				if batch:
					run.open_batch(e, held)
				else:
					run.open_ticket(e, held[0])
				won += e.won - before
				held = []
				e.cash = 0
				if pushes and run.window_n == 0 and run.push_stake == 0 and run.push_offer() > 0:
					e.cash = run.push_offer()
					spent += e.cash
					run.push(e)
			if m.boxes[col].cursor >= m.boxes[col].size:
				done += 1
	return float(won) / spent


## The churn exploit at fixed perk levels: in every column, CHURN tickets bought and
## opened one at a time, then NEW BOX for the fee, `boxes` times, at stake 1. Returns
## {return: prizes per dollar of tickets, return_fees: per dollar of tickets and fees,
## fee: the fee paid}. FIRST PULL's floor on the fee (RunState.change_fee) is what
## keeps return_fees at 1 or under.
static func churn_return(base_forms: Array, perk_levels: Dictionary, boxes: int, seed_prefix := "CH") -> Dictionary:
	var run := RunState.start(RunConfig.standard(), seed_prefix, ["diner"])
	run.perks = perk_levels.duplicate()
	var e := run.new_economy()
	var m := run.new_machine(base_forms, true)
	var spent := 0
	var won := 0
	var fees := 0
	for col in m.forms.size():
		for b in boxes:
			for k in CHURN:
				e.credit += m.price(col)
				var sold := m.sell_now(col, e)
				spent += m.price(col)
				if sold.last_sale:
					run.cleared_box(m)
				var before := e.won
				run.open_ticket(e, {"form": m.forms[col], "ticket": sold.ticket, "box": sold.box, "bet": m.bet})
				won += e.won - before
			var fee := run.change_fee()
			e.cash += fee
			run.change_box(e, m, col)
			fees += fee
	return {"return": float(won) / spent if spent > 0 else 0.0,
		"return_fees": float(won) / (spent + fees) if spent + fees > 0 else 0.0, "fee": run.change_fee()}


## ALL IN's odds on each form, no perks, stake 1: `boxes` boxes of the form in the
## run's model, their tickets opened in order in windows of Catalog.WINDOW (the boxes
## one after another). Of the windows after one that paid, the share whose printed
## prizes reach its bar (the form's Catalog.all_in_share, or `shares`' {form id:
## percent} to try another; the push wins). Returns [{form, p, windows, share}]
## (windows: how many were counted).
static func push_odds(base_forms: Array, boxes: int, seed_prefix := "PU", shares := {}) -> Array:
	var model := RunConfig.standard().box_model(0)
	var out := []
	for base: FormDef in base_forms:
		var f := base.shaped()
		var share := int(shares.get(f.id, Catalog.all_in_share(f.uid())))
		var prev := -1
		var sum := 0
		var n := 0
		var counted := 0
		var beat := 0
		for b in boxes:
			var box := BoxGenerator.build(f, "%s-%d" % [seed_prefix, b], model, true)
			for t in box.tickets:
				sum += maxi(0, int(t.prize))
				n += 1
				if n < Catalog.WINDOW:
					continue
				if prev > 0:
					counted += 1
					if sum >= Catalog.all_in_bar(prev * share):
						beat += 1
				prev = sum
				sum = 0
				n = 0
		out.append({"form": f.id, "p": float(beat) / counted if counted > 0 else 0.0, "windows": counted, "share": share})
	return out
