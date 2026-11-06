class_name MachineLogic
extends RefCounted
## The pull-tab machine: one box per form, column presses, PLAY ALL, dispensing
## and restocking. Pure logic. Numbers from MIGRATION.md "Machine" and the web build.

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
var boxes: Array[TicketBox] = []
var loaded: PackedFloat32Array = []   ## tickets loaded in each box (restocking boxes fill up)
var queue: Array = []                 ## [{form: index, n: tickets left}]
var armed := false
var return_at := 0.0                  ## time to go back to the table, 0 when not scheduled
var _acc := 0.0
var _sold := false


func _init(machine_forms: Array, seed_text: String, box_model: BoxModel = null, light := false, box_luck := 0.0, tries := 1) -> void:
	model = box_model
	prizes_only = light
	luck = box_luck
	luck_tries = tries
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
## so a seed always loads the same way.
func _load(f: FormDef, seed_text: String, after_clear := false) -> TicketBox:
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


## A column button (or key 1-3). Sells 1, or with PLAY ALL armed min(100, what credit buys).
## Returns "insert_bill" when there is no credit, else "".
func press(i: int, credit: int) -> String:
	var p := price(i)
	if credit < p:
		return "insert_bill"
	var n := mini(PLAY_ALL_MAX, credit / p) if armed else 1
	armed = false
	queue.append({"form": i, "n": n})
	return ""


## The red PLAY ALL button: arms (or disarms) the next column press.
func press_play_all(credit: int) -> String:
	if credit < min_price():
		return "insert_bill"
	armed = not armed
	return ""


## The NEW BOX key: arms (or disarms) a box change for the next column press.
func press_change() -> void:
	change_armed = not change_armed
	armed = false


## Takes column `i`'s box away and loads the next seed's, which restocks as after a
## sell-out. Tickets already bought from the old box keep it. What it costs is the
## caller's rule.
func change_box(i: int) -> void:
	change_armed = false
	boxes[i] = _load(forms[i], next_seed(boxes[i].seed))
	loaded[i] = 0.0
	var kept: Array = []
	for job in queue:
		if job.form != i:
			kept.append(job)
	queue = kept


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
	if not queue.is_empty() and economy.credit < price(queue[0].form):
		queue.clear()
	var running := not queue.is_empty() and stock_left(queue[0].form) > 0
	ev.motor = running
	if running:
		_acc = minf(3.0, _acc + dt * RATE)
		var k := 0
		while _acc >= 1.0 and not queue.is_empty():
			var job: Dictionary = queue[0]
			var i: int = job.form
			if economy.credit < price(i) or stock_left(i) <= 0:
				break
			_acc -= 1.0
			var box := boxes[i]
			var t: Dictionary = box.tickets[box.cursor]
			box.cursor += 1
			economy.buy(price(i))
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
		if economy.credit < min_price():
			return_at = now + RETURN_DELAY
	return ev


## Sells one ticket of column `i` right now: no motor, no waiting for stock, no tray.
## For simulations. Returns {"ticket", "box", "last_sale": bool}, or {} when the credit is short.
func sell_now(i: int, economy: Economy) -> Dictionary:
	if boxes[i].cursor >= boxes[i].size:
		boxes[i] = _load(forms[i], next_seed(boxes[i].seed), true)
	var box := boxes[i]
	loaded[i] = box.size
	if not economy.buy(price(i)):
		return {}
	var t: Dictionary = box.tickets[box.cursor]
	box.cursor += 1
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
## (generated once and shared with the tray), or null if the form is gone.
## Forms not in the save keep the box they have. Nothing is queued or armed after.
func load_boxes(saved: Array, box_for: Callable) -> void:
	queue.clear()
	armed = false
	change_armed = false
	return_at = 0.0
	_acc = 0.0
	_sold = false
	for d in saved:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var i := -1
		for k in forms.size():
			if forms[k].uid() == str(d.get("form", "")):
				i = k
		if i < 0:
			continue
		var box: TicketBox = box_for.call(forms[i].uid(), str(d.get("seed", "")))
		if box == null:
			continue
		var sh = d.get("shuffles", [])
		if typeof(sh) == TYPE_ARRAY:
			for at in sh:
				box.cursor = clampi(int(at), 0, box.size)
				box.shuffle_rest()
		box.cursor = clampi(int(d.get("cursor", 0)), 0, box.size)
		box.opened = clampi(int(d.get("opened", 0)), 0, box.size)
		boxes[i] = box
		loaded[i] = clampf(float(d.get("loaded", box.size)), 0.0, box.size)


func to_dict() -> Dictionary:
	var out := []
	for i in boxes.size():
		var d := {"form": forms[i].uid(), "seed": boxes[i].seed, "cursor": boxes[i].cursor,
			"opened": boxes[i].opened, "loaded": loaded[i]}
		if not boxes[i].shuffles.is_empty():
			d.shuffles = boxes[i].shuffles.duplicate()
		out.append(d)
	return {"boxes": out}
