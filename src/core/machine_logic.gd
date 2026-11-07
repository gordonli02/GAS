class_name MachineLogic
extends RefCounted
## The pull-tab machine: one box per form, column presses, PLAY ALL, dispensing
## and restocking. Pure logic. Numbers from MIGRATION.md "Machine" and the web build.
##
## The run's perks reach the machine through a few fields RunState.apply sets (luck,
## the bet, the last sale, MAGNET, CONSOLATION, CRUMBS, PACKED) and one callable
## (`sure_next`), asked before every ticket is taken whether this one has to win; the
## box then moves a winner of its own forward (TicketBox.pull_winner).

const RATE := 16.35            ## tickets per second while dispensing
const RESTOCK := 18.0          ## tickets per second while a new box loads
const PLAY_ALL_MAX := 100
const RETURN_DELAY := 0.7      ## seconds after dispensing ends before the camera goes back
const FEED_GAP := 0.061        ## spacing of feed sounds within one frame

var forms: Array[FormDef] = []
var model: BoxModel = null            ## how boxes are composed; null is the standard model
var last_sale := 0                    ## prize for buying the last ticket of a box (0: none)
var prizes_only := false              ## simulations: boxes without the print on each ticket
var change_armed := false             ## the next column press changes that column's box
## Run perk (LUCKY STREAK): the chance that a losing box loaded into the machine is passed
## over for the next seed's box. Rolled once per box from its seed, so a seed always
## loads the same way and a saved box (kept by its seed) is never touched.
var luck := 0.0
var luck_tries := 1                   ## FORTUNE: losing boxes passed over again, up to this many
var flow_line := false                ## ASSEMBLY LINE: a box loaded after a sell-out never loses
var bet := 1                          ## HIGH ROLLER: tickets cost and pay this many times more
## MAGNET: in every window of this many tickets of a box (counted from its first) one
## wins at least: when the window's last ticket is sold and none of it won, the next
## small prize of the box is moved onto it. 0: off.
var magnet := 0
## CONSOLATION: of the losers taken from a box, this many in a hundred (rolled from the
## seed) win the smallest prize instead. 0: off.
var consolation := 0
## CRUMBS: a winner taken from a box splits its prize over up to this many of the next
## losers in the box (TicketBox.crumble). 0: off.
var crumbs := 0
## PACKED: a box that goes on the machine gets up to this many percent more smallest
## prizes, paid for by its middle ones (TicketBox.pack). Boxes already on it stay as
## they are.
var packed := 0
## Asked with the box before a ticket is taken: whether this one has to win (a sure
## win is a winner of the box moved onto it). The run's rule (STAKEOUT, INSURANCE).
var sure_next: Callable
var boxes: Array[TicketBox] = []
var loaded: PackedFloat32Array = []   ## tickets loaded in each box (restocking boxes fill up)
var queue: Array = []                 ## [{form: index, n: tickets left}]
var armed := false
var return_at := 0.0                  ## time to go back to the table, 0 when not scheduled
var _acc := 0.0
var _sold := false


func _init(machine_forms: Array, seed_text: String, box_model: BoxModel = null, light := false, box_luck := 0.0, tries := 1,
		box_packed := 0) -> void:
	model = box_model
	prizes_only = light
	luck = box_luck
	luck_tries = tries
	packed = box_packed
	for f in machine_forms:
		forms.append(f)
		var box := _load(f, seed_text)
		boxes.append(box)
		loaded.append(box.size)


func _build(f: FormDef, seed_text: String) -> TicketBox:
	return BoxGenerator.build(f, seed_text, model, prizes_only)


## The box a seed loads into the machine: that seed's or, with luck, when it is a losing
## one, the next seed's (passed over once, or up to luck_tries times with FORTUNE, each
## time on its own roll). `after_clear`: the box before it was sold out, so with
## ASSEMBLY LINE the seeds go on until one does not lose. Every roll comes from a seed,
## so a seed always loads the same way. PACKED, when on, packs the box that loads.
func _load(f: FormDef, seed_text: String, after_clear := false) -> TicketBox:
	var box := _pick(f, seed_text, after_clear)
	if packed > 0:
		box.pack(packed)
	return box


func _pick(f: FormDef, seed_text: String, after_clear: bool) -> TicketBox:
	var box := _build(f, seed_text)
	var s := seed_text
	var tries := 0
	if flow_line and after_clear:
		while losing(box) and tries < Catalog.FORTUNE_TRIES:
			s = next_seed(s)
			box = _build(f, s)
			tries += 1
		return box
	while luck > 0.0 and tries < luck_tries and losing(box) and SeededRng.new(s + "|luck").next_float() < luck:
		s = next_seed(s)
		box = _build(f, s)
		tries += 1
	return box


## A box of a type that pays back less than it takes (a big, medium or small loss).
func losing(box: TicketBox) -> bool:
	var m := model if model != null else BoxModel.standard()
	return float(m.type_by_id(box.type_id).get("max", 0.0)) < 0.0


## The cheapest ticket at the bet: with less credit than this the machine sells nothing.
func min_price() -> int:
	var p: int = forms[0].price
	for f in forms:
		p = mini(p, f.price)
	return p * bet


## What a ticket of column `i` costs at the bet.
func price(i: int) -> int:
	return forms[i].price * bet


func busy() -> bool:
	return not queue.is_empty()


func stock_left(i: int) -> int:
	return maxi(0, int(floor(loaded[i])) - boxes[i].cursor)


## A column button (or key 1-3). Sells 1, or with PLAY ALL armed min(100, what the
## money buys). Returns "insert_bill" when the money is short, else "".
func press(i: int, e: Economy) -> String:
	var p := price(i)
	if not e.can_buy(p):
		return "insert_bill"
	var n := mini(PLAY_ALL_MAX, e.power() / p) if armed else 1
	armed = false
	queue.append({"form": i, "n": n})
	return ""


## The red PLAY ALL button: arms (or disarms) the next column press.
func press_play_all(e: Economy) -> String:
	if not e.can_buy(min_price()):
		return "insert_bill"
	armed = not armed
	return ""


## The NEW BOX key: arms (or disarms) a box change for the next column press.
func press_change() -> void:
	change_armed = not change_armed
	armed = false


## Takes column `i`'s box away and loads the next seed's, which restocks as after a
## sell-out. With `new_form` (PICKY) the column sells that form from now on. Tickets
## already bought from the old box keep it. What it costs is the caller's rule.
func change_box(i: int, new_form: FormDef = null) -> void:
	change_armed = false
	if new_form != null:
		forms[i] = new_form
	boxes[i] = _load(forms[i], next_seed(boxes[i].seed))
	loaded[i] = 0.0
	var kept: Array = []
	for job in queue:
		if job.form != i:
			kept.append(job)
	queue = kept


## MOVER: columns `i` and `j` trade boxes (form, box and stock). Nothing queued after.
func swap_columns(i: int, j: int) -> void:
	if i == j or i < 0 or j < 0 or i >= boxes.size() or j >= boxes.size():
		return
	var f := forms[i]
	forms[i] = forms[j]
	forms[j] = f
	var b := boxes[i]
	boxes[i] = boxes[j]
	boxes[j] = b
	var l := loaded[i]
	loaded[i] = loaded[j]
	loaded[j] = l
	queue.clear()
	armed = false
	change_armed = false


## The next ticket of column `i` leaves the box, paid for: the run's sure win and
## MAGNET act on it first, then CONSOLATION on a loser and CRUMBS on a winner (so the
## ticket is what it shows: a real winner, counted as one everywhere).
func _take(i: int, economy: Economy) -> Dictionary:
	var box := boxes[i]
	var at := box.cursor
	if sure_next.is_valid() and not box.wins(at):
		sure_next.call(box)
	if magnet > 0 and (at + 1) % magnet == 0 and not box.wins(at):
		var dry := true
		for k in range(at - magnet + 1, at):
			if box.wins(k):
				dry = false
				break
		if dry:
			box.pull_winner(at, "small")
	if consolation > 0 and not box.wins(at):
		box.console(at, consolation)
	if crumbs > 0 and box.wins(at):
		box.crumble(at, crumbs)
	var t: Dictionary = box.tickets[at]
	box.cursor += 1
	economy.buy(price(i))
	return t


## One frame. Buys tickets through `economy` and puts them in `tray`.
## Returns {"motor": running, "sold": [{form, delay}], "stopped": bool, "last_sale": [form, ...]}
## (last_sale: columns whose last ticket was just bought; the prize is already paid).
func step(dt: float, now: float, economy: Economy, tray: TicketTray) -> Dictionary:
	var ev := {"motor": false, "sold": [], "stopped": false, "last_sale": []}
	for i in boxes.size():
		var box := boxes[i]
		if loaded[i] < box.size:
			loaded[i] = minf(box.size, loaded[i] + dt * RESTOCK)
		if box.cursor >= box.size:
			# Sold out: the next seed's box loads and restocks.
			boxes[i] = _load(forms[i], next_seed(box.seed), true)
			loaded[i] = 0.0
	if not queue.is_empty() and not economy.can_buy(price(queue[0].form)):
		queue.clear()
	var running := not queue.is_empty() and stock_left(queue[0].form) > 0
	ev.motor = running
	if running:
		_acc = minf(3.0, _acc + dt * RATE)
		var k := 0
		while _acc >= 1.0 and not queue.is_empty():
			var job: Dictionary = queue[0]
			var i: int = job.form
			if not economy.can_buy(price(i)) or stock_left(i) <= 0:
				break
			_acc -= 1.0
			var box := boxes[i]
			var t := _take(i, economy)
			tray.add(forms[i], t, box, bet)
			ev.sold.append({"form": i, "delay": k * FEED_GAP})
			if last_sale > 0 and box.cursor >= box.size:
				economy.bonus(last_sale)
				ev.last_sale.append(i)
			k += 1
			_sold = true
			job.n -= 1
			if job.n <= 0:
				queue.pop_front()
	if _sold and queue.is_empty():
		_sold = false
		ev.stopped = true
		if not economy.can_buy(min_price()):
			return_at = now + RETURN_DELAY
	return ev


## Sells one ticket of column `i` right now: no motor, no waiting for stock, no tray.
## For simulations. Returns {"ticket", "box", "last_sale": bool}, or {} when the credit
## is short.
func sell_now(i: int, economy: Economy) -> Dictionary:
	if boxes[i].cursor >= boxes[i].size:
		boxes[i] = _load(forms[i], next_seed(boxes[i].seed), true)
	var box := boxes[i]
	loaded[i] = box.size
	if not economy.can_buy(price(i)):
		return {}
	var t := _take(i, economy)
	var last := last_sale > 0 and box.cursor >= box.size
	if last:
		economy.bonus(last_sale)
	return {"ticket": t, "box": box, "last_sale": last}


## FAST FORWARD: the next `n` tickets of column `i` go unsold (never paid for, never
## opened), one at least left in the box. Returns how many went.
func skip(i: int, n: int) -> int:
	var box := boxes[i]
	var k := clampi(mini(n, stock_left(i) - 1), 0, maxi(0, box.size - box.cursor - 1))
	box.cursor += k
	return k


## SHUFFLE: what is left in column `i`'s box comes in another order.
func shuffle(i: int) -> void:
	boxes[i].shuffle_rest()


## "G-0001" -> "G-0002"; a seed without a trailing number gets "-2".
static func next_seed(s: String) -> String:
	var m := RegEx.create_from_string("^(.*?)(\\d+)$").search(s)
	if m == null:
		return s + "-2"
	var digits := m.get_string(2)
	return m.get_string(1) + str(digits.to_int() + 1).pad_zeros(digits.length())


## Restores boxes saved with to_dict(). box_for(form uid, seed) returns that box
## (generated once and shared with the tray), or null if the form is gone. A save
## made with columns (PICKY, MOVER) is read column by column: a column takes the
## form of the box saved for it; without columns, forms are matched by uid. Forms
## not in the save keep the box they have. Nothing is queued or armed after.
func load_boxes(saved: Array, box_for: Callable) -> void:
	queue.clear()
	armed = false
	change_armed = false
	return_at = 0.0
	_acc = 0.0
	_sold = false
	for k in saved.size():
		var d = saved[k]
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var i := -1
		if d.has("column"):
			i = int(d.column) if int(d.column) >= 0 and int(d.column) < forms.size() else -1
		else:
			for c in forms.size():
				if forms[c].uid() == str(d.get("form", "")):
					i = c
		if i < 0:
			continue
		var box: TicketBox = box_for.call(str(d.get("form", "")), str(d.get("seed", "")))
		if box == null:
			continue
		if box.form != null and box.form.uid() != forms[i].uid():
			forms[i] = box.form
		var ops = d.get("ops", null)
		if typeof(ops) == TYPE_ARRAY:
			box.replay(ops)
		else:
			var sh = d.get("shuffles", [])   # saves before M9.5
			if typeof(sh) == TYPE_ARRAY:
				var old := []
				for at in sh:
					old.append({"s": int(at)})
				box.replay(old)
		box.cursor = clampi(int(d.get("cursor", 0)), 0, box.size)
		box.opened = clampi(int(d.get("opened", 0)), 0, box.size)
		boxes[i] = box
		loaded[i] = clampf(float(d.get("loaded", box.size)), 0.0, box.size)


func to_dict() -> Dictionary:
	var out := []
	for i in boxes.size():
		var d := {"column": i, "form": forms[i].uid(), "seed": boxes[i].seed, "cursor": boxes[i].cursor,
			"opened": boxes[i].opened, "loaded": loaded[i]}
		if not boxes[i].ops.is_empty():
			d.ops = boxes[i].ops.duplicate(true)
		out.append(d)
	return {"boxes": out}
