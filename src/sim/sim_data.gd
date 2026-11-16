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
	{"closer": 2, "firstpull": 2, "regular": 2, "readleft": 1},           # 清盒 (the chain's top; was HOT OR COLD)
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


## Where the flow study cuts each box: percent of its tickets sold.
const FLOW_CUTS := [25, 50, 75]


## One box cut after `cut` tickets sold in order (the box as built; its cursor is put
## back as it was): {past_money, past_cost: the prizes and the price of the tickets
## sold; rest_money, rest_cost: of the tickets left (BoxReading.read's value, what the
## machine still holds); past, rest: money over cost (0 for no tickets); top_in: a top
## prize is still in the box (READ THE FLARE)}.
static func flow_cut(box: TicketBox, cut: int) -> Dictionary:
	cut = clampi(cut, 0, box.size)
	var was := box.cursor
	box.cursor = cut
	var fl := BoxReading.flow(box)   # what READ THE FLOW says was sold and paid
	var past_money := int(fl.paid)
	var r := BoxReading.read(box)
	box.cursor = was
	# The tickets bought (a FAST FORWARD's unsold ones are not: the study's boxes, as
	# built, have none, so this is `cut` there).
	var past_cost := int(fl.sold) * box.form.price
	var rest_cost := (box.size - cut) * box.form.price
	return {"past_money": past_money, "past_cost": past_cost, "rest_money": int(r.value), "rest_cost": rest_cost,
		"past": float(past_money) / past_cost if past_cost > 0 else 0.0,
		"rest": float(r.value) / rest_cost if rest_cost > 0 else 0.0,
		"top_in": int(r.roles.top) > 0}


## The indexes of `values` split in three by value, lowest third first: sorted (equal
## values by index), the k-th of n going to third floor(3k / n), so the thirds differ
## in size by one at most and every index is in exactly one.
static func terciles(values: Array) -> Array:
	var order := range(values.size())
	order.sort_custom(func(a, b): return values[a] < values[b] or (values[a] == values[b] and a < b))
	var out := [[], [], []]
	var n := order.size()
	for k in n:
		out[3 * k / n].append(order[k])
	return out


## Pearson's correlation of two lists of the same length; 0 when either does not vary.
static func pearson(xs: Array, ys: Array) -> float:
	var n := xs.size()
	if n < 2:
		return 0.0
	var mx := 0.0
	var my := 0.0
	for i in n:
		mx += xs[i]
		my += ys[i]
	mx /= n
	my /= n
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in n:
		sxy += (xs[i] - mx) * (ys[i] - my)
		sxx += (xs[i] - mx) * (xs[i] - mx)
		syy += (ys[i] - my) * (ys[i] - my)
	if sxx <= 0.0 or syy <= 0.0:
		return 0.0
	return sxy / sqrt(sxx * syy)


## Spearman's rank correlation: Pearson's on the ranks (equal values share their mean
## rank). Less moved than Pearson's by the few boxes whose rest is far out (a top prize
## still in a small rest).
static func spearman(xs: Array, ys: Array) -> float:
	return pearson(_ranks(xs), _ranks(ys))


static func _ranks(values: Array) -> Array:
	var order := range(values.size())
	order.sort_custom(func(a, b): return values[a] < values[b])
	var out := []
	out.resize(values.size())
	var k := 0
	while k < order.size():
		var j := k
		while j + 1 < order.size() and values[order[j + 1]] == values[order[k]]:
			j += 1
		for m in range(k, j + 1):
			out[order[m]] = (k + j) / 2.0
		k = j + 1
	return out


## What the past of a box says about its rest (docs/roadmap.md 数值方向 三.2, 十二.1:
## the flow, 流水): for each form, `boxes` boxes as the run makes them in layer 1
## (`config`'s box model 0: its sizes, shapes, chance rounding and payout; stake 1, no
## perks), each cut at FLOW_CUTS percent of its tickets sold in order (flow_cut). Per
## form and cut, and over all forms pooled ("all": every form has the same count of
## boxes, so each weighs the same; the thirds are still taken within each form):
## {cut, n, past, rest (means of the boxes' ratios), r (Pearson of past and rest), rho
## (Spearman's, on ranks),
## thirds: [{n, lo, hi (the third's past range), rest}] lowest past first, spread (the
## highest third's rest less the lowest's), top_in / no_top: {n, share, rest, thirds}
## (the boxes with a top prize still in, and without; thirds by past within each),
## best / worst: the rest of the best and worst third by past (and which, 0 to 2)}.
## Returns {boxes, cuts, sizes: [smallest, biggest], payout, forms: [ids],
## rows: {form id or "all": [a row a cut]}}.
static func flow_study(base_forms: Array, boxes: int, config: RunConfig = null, seed_prefix := "FLOW") -> Dictionary:
	if config == null:
		config = RunConfig.standard()
	var model := config.box_model(0)
	var rows := {}
	var ids := []
	# all[c]: every form's boxes at cut c, with the third each fell in within its form.
	var all := []
	for c in FLOW_CUTS.size():
		all.append({"cuts": [], "third": [], "third_top": []})
	for base: FormDef in base_forms:
		var f := base.shaped()
		ids.append(f.id)
		var per := []
		for c in FLOW_CUTS.size():
			per.append([])
		for n in boxes:
			var box := BoxGenerator.build(f, "%s-%d" % [seed_prefix, n], model, true)
			for c in FLOW_CUTS.size():
				per[c].append(flow_cut(box, box.size * int(FLOW_CUTS[c]) / 100))
		var form_rows := []
		for c in FLOW_CUTS.size():
			var row := _flow_row(per[c], [], [])
			row.cut = FLOW_CUTS[c]
			form_rows.append(row)
			all[c].cuts.append_array(per[c])
			all[c].third.append_array(row._third)
			all[c].third_top.append_array(row._third_top)
		rows[f.id] = form_rows
	var pooled := []
	for c in FLOW_CUTS.size():
		var row := _flow_row(all[c].cuts, all[c].third, all[c].third_top)
		row.cut = FLOW_CUTS[c]
		pooled.append(row)
	rows["all"] = pooled
	for key in rows:
		for row in rows[key]:
			row.erase("_third")
			row.erase("_third_top")
	return {"boxes": boxes, "cuts": FLOW_CUTS.duplicate(), "payout": model.payout, "forms": ids, "rows": rows,
		"sizes": [model.size_min, model.size_min + model.size_step * (model.size_steps - 1)]}


## One row of flow_study from a list of flow_cut results. `third` / `third_top`: each
## box's third by past (overall, and within its top-in or no-top group) when already
## taken (the pooled row: taken within each form); empty: taken here. The row carries
## them back as _third / _third_top.
static func _flow_row(cuts: Array, third: Array, third_top: Array) -> Dictionary:
	var n := cuts.size()
	var pasts := []
	var rests := []
	for x in cuts:
		pasts.append(x.past)
		rests.append(x.rest)
	if third.is_empty():
		third = _thirds_of(pasts, range(n))
		var ins := range(n).filter(func(i): return cuts[i].top_in)
		var outs := range(n).filter(func(i): return not cuts[i].top_in)
		third_top = []
		third_top.resize(n)
		for group in [ins, outs]:
			var t := _thirds_of(group.map(func(i): return pasts[i]), range(group.size()))
			for k in group.size():
				third_top[group[k]] = t[k]
	var row := {"n": n, "past": _mean(pasts), "rest": _mean(rests), "r": pearson(pasts, rests), "rho": spearman(pasts, rests),
		"thirds": _thirds_rows(cuts, range(n), third), "_third": third, "_third_top": third_top}
	for key in ["top_in", "no_top"]:
		var want: bool = key == "top_in"
		var idx := range(n).filter(func(i): return cuts[i].top_in == want)
		row[key] = {"n": idx.size(), "share": float(idx.size()) / n if n > 0 else 0.0,
			"rest": _mean(idx.map(func(i): return rests[i])), "thirds": _thirds_rows(cuts, idx, third_top)}
	var th: Array = row.thirds
	row.spread = float(th[2].rest) - float(th[0].rest)
	var best := 0
	var worst := 0
	for k in 3:
		if th[k].n > 0 and (th[best].n == 0 or th[k].rest > th[best].rest):
			best = k
		if th[k].n > 0 and (th[worst].n == 0 or th[k].rest < th[worst].rest):
			worst = k
	row.best = {"third": best, "rest": th[best].rest}
	row.worst = {"third": worst, "rest": th[worst].rest}
	return row


## Each of `idx`'s places in `values` order: its third (0, 1 or 2) by terciles.
static func _thirds_of(values: Array, idx: Array) -> Array:
	var out := []
	out.resize(idx.size())
	var t := terciles(values)
	for k in 3:
		for i in t[k]:
			out[i] = k
	return out


## The three thirds of the boxes `idx` (by `third`, a box's third): {n, lo, hi, rest}.
static func _thirds_rows(cuts: Array, idx: Array, third: Array) -> Array:
	var out := []
	for k in 3:
		var ins := idx.filter(func(i): return third[i] == k)
		var ps := ins.map(func(i): return cuts[i].past)
		out.append({"n": ins.size(), "lo": ps.min() if not ps.is_empty() else 0.0, "hi": ps.max() if not ps.is_empty() else 0.0,
			"rest": _mean(ins.map(func(i): return cuts[i].rest))})
	return out


static func _mean(xs: Array) -> float:
	if xs.is_empty():
		return 0.0
	var s := 0.0
	for x in xs:
		s += x
	return s / xs.size()


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
