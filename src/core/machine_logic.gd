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
var boxes: Array[TicketBox] = []
var loaded: PackedFloat32Array = []   ## tickets loaded in each box (restocking boxes fill up)
var queue: Array = []                 ## [{form: index, n: tickets left}]
var armed := false
var return_at := 0.0                  ## time to go back to the table, 0 when not scheduled
var _acc := 0.0
var _sold := false


func _init(machine_forms: Array, seed_text: String) -> void:
	for f in machine_forms:
		forms.append(f)
		var box := BoxGenerator.build(f, seed_text)
		boxes.append(box)
		loaded.append(box.size)


func busy() -> bool:
	return not queue.is_empty()


func stock_left(i: int) -> int:
	return maxi(0, int(floor(loaded[i])) - boxes[i].cursor)


## A column button (or key 1-3). Sells 1, or with PLAY ALL armed min(100, what credit buys).
## Returns "insert_bill" when there is no credit, else "".
func press(i: int, credit: int) -> String:
	if credit < 1:
		return "insert_bill"
	var price := forms[i].price
	var n := mini(PLAY_ALL_MAX, credit / price) if armed else 1
	armed = false
	queue.append({"form": i, "n": n})
	return ""


## The red PLAY ALL button: arms (or disarms) the next column press.
func press_play_all(credit: int) -> String:
	if credit < 1:
		return "insert_bill"
	armed = not armed
	return ""


## One frame. Buys tickets through `economy` and puts them in `tray`.
## Returns {"motor": running, "sold": [{form, delay}], "stopped": bool}.
func step(dt: float, now: float, economy: Economy, tray: TicketTray) -> Dictionary:
	var ev := {"motor": false, "sold": [], "stopped": false}
	for i in boxes.size():
		var box := boxes[i]
		if loaded[i] < box.size:
			loaded[i] = minf(box.size, loaded[i] + dt * RESTOCK)
		if box.cursor >= box.size:
			# Sold out: the next seed's box loads and restocks.
			boxes[i] = BoxGenerator.build(forms[i], next_seed(box.seed))
			loaded[i] = 0.0
	if not queue.is_empty() and economy.credit < forms[queue[0].form].price:
		queue.clear()
	var running := not queue.is_empty() and stock_left(queue[0].form) > 0
	ev.motor = running
	if running:
		_acc = minf(3.0, _acc + dt * RATE)
		var k := 0
		while _acc >= 1.0 and not queue.is_empty():
			var job: Dictionary = queue[0]
			var i: int = job.form
			if economy.credit < forms[i].price or stock_left(i) <= 0:
				break
			_acc -= 1.0
			var box := boxes[i]
			var t: Dictionary = box.tickets[box.cursor]
			box.cursor += 1
			economy.buy(forms[i].price)
			tray.add(forms[i], t, box)
			ev.sold.append({"form": i, "delay": k * FEED_GAP})
			k += 1
			_sold = true
			job.n -= 1
			if job.n <= 0:
				queue.pop_front()
	if _sold and queue.is_empty():
		_sold = false
		ev.stopped = true
		if economy.credit < 1:
			return_at = now + RETURN_DELAY
	return ev


## "G-0001" -> "G-0002"; a seed without a trailing number gets "-2".
static func next_seed(s: String) -> String:
	var m := RegEx.create_from_string("^(.*?)(\\d+)$").search(s)
	if m == null:
		return s + "-2"
	var digits := m.get_string(2)
	return m.get_string(1) + str(digits.to_int() + 1).pad_zeros(digits.length())


func to_dict() -> Dictionary:
	var out := []
	for i in boxes.size():
		out.append({"form": forms[i].uid(), "seed": boxes[i].seed, "cursor": boxes[i].cursor,
			"opened": boxes[i].opened, "loaded": loaded[i]})
	return {"boxes": out}
