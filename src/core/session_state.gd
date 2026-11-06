class_name SessionState
extends RefCounted
## The session in progress as plain data for the save file, and back. Pure logic.
##
## What is kept (G, milestone 6): money and the ledger, every box's seed and progress,
## the tray and the discard pile. A ticket in hand that is not revealed yet (even
## partly torn, or with its band broken) goes back to the front of the tray and is
## dealt again untouched; a revealed one was already paid and counts on the pile.
## A bill being fed counts as credit; tickets still queued in the machine are dropped
## (they were never paid for).


## hand: the tray entry of a ticket in hand that is not revealed yet, or {}.
## pile: DiscardPile.to_dict(), with a revealed ticket in hand already counted.
static func capture(economy: Economy, machine: MachineLogic, tray: TicketTray, hand: Dictionary, pile: Dictionary) -> Dictionary:
	var money := economy.to_dict()
	money.credit += economy.bill
	var items := []
	if not hand.is_empty():
		items.append(_entry(hand))
	for e in tray.items:
		items.append(_entry(e))
	return {"economy": money, "machine": machine.to_dict(), "tray": items, "pile": pile}


## Loads a captured session into `economy`, `machine` and `tray`. find_form(uid) gives
## a FormDef or null. Returns false, changing nothing, if the money does not add up.
## Tickets of forms no longer installed are left out (they stay counted as spent).
## Boxes are rebuilt with the machine's own box model.
static func restore(d: Dictionary, economy: Economy, machine: MachineLogic, tray: TicketTray, find_form: Callable) -> bool:
	var money = d.get("economy")
	if typeof(money) != TYPE_DICTIONARY:
		return false
	var check := Economy.new()
	check.from_dict(money)
	if not check.balanced() or check.cash < 0 or check.credit < 0:
		return false
	var cache := {}
	var box_for := func(uid: String, seed_text: String) -> TicketBox:
		var key := uid + "|" + seed_text
		if not cache.has(key):
			var f: FormDef = find_form.call(uid)
			cache[key] = BoxGenerator.build(f, seed_text, machine.model) if f != null and seed_text != "" else null
		return cache[key]
	var m = d.get("machine", {})
	if typeof(m) == TYPE_DICTIONARY and typeof(m.get("boxes")) == TYPE_ARRAY:
		machine.load_boxes(m.boxes, box_for)
	tray.clear()
	var items = d.get("tray", [])
	if typeof(items) == TYPE_ARRAY:
		for it in items:
			if typeof(it) != TYPE_DICTIONARY:
				continue
			var box: TicketBox = box_for.call(str(it.get("form", "")), str(it.get("seed", "")))
			var no := int(it.get("no", 0))
			if box == null or no < 1 or no > box.size:
				continue
			tray.add(box.form, box.tickets[no - 1], box)
	economy.from_dict(money)
	return true


static func _entry(e: Dictionary) -> Dictionary:
	return {"form": e.form.uid(), "seed": e.box.seed, "no": int(e.ticket.no)}
