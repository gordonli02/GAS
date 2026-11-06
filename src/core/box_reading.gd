class_name BoxReading
extends RefCounted
## What the box-reading perks (and the BOX REPORT item) tell about a box still in the
## machine. Pure logic. G: reading is a late chain of perks; the low levels give rough,
## qualitative hints so that buying still feels like gambling, the high ones the real
## numbers and the notepad (docs/roadmap.md, the perk-tree talk). Each level adds to
## the one before:
##   1  READ THE FLARE  whether a top prize is still in the box
##   2  READ THE BOX    whether the box was made fat, even or lean (its type, which does
##                      not change as it sells: a fat box half sold may run cold now)
##   3  HOT OR COLD     how what is left feels: HOT, FAIR or COLD (the prize money left
##                      per ticket against the price)
##   4  COUNT IT        the exact count, and how many prizes of each kind are left
##   5  KEEP BOOKS      and the notepad keeps a line for every box on the machine
## "Left" is what the machine still holds: tickets sold are gone, opened or not.

const ROUGH := 50
## Prize money left per dollar of tickets left: at or over HOT the box feels hot, under
## COLD it feels cold. A box pays back about 0.99 on average (BoxModel), between 0.25 and
## 2.6 by its type.
const HOT := 1.25
const COLD := 0.8
const TOP_LEVEL := 5
const BOOKS := 5             ## the level at which the notepad keeps the boxes
const COUNT := 4             ## the level of the exact numbers (and of a BOX REPORT)


## {left, value (prize money left), heat (value per dollar of tickets left), roles:
## {top, mid, low} prizes left of each kind}.
static func read(box: TicketBox) -> Dictionary:
	var counts: Array = box.counts.duplicate()
	var value := 0
	for i in box.size:
		var t: Dictionary = box.tickets[i]
		if i < box.cursor:
			for tier in t.get("wins", [t.tier]):
				if tier >= 0:
					counts[tier] -= 1
		else:
			value += int(t.prize)
	var roles := {"top": 0, "mid": 0, "low": 0}
	for tier in counts.size():
		roles[box.form.tiers[tier].role] += int(counts[tier])
	var left := box.size - box.cursor
	return {"left": left, "value": value, "roles": roles,
		"heat": float(value) / (left * box.form.price) if left > 0 else 0.0}


## Tickets left to the nearest ROUGH (never 0 while one is left).
static func rough(left: int) -> int:
	if left <= 0:
		return 0
	return maxi(ROUGH, roundi(float(left) / ROUGH) * ROUGH)


## A translation key: HOT, FAIR or COLD.
static func feel(heat: float) -> String:
	return "HOT" if heat >= HOT else "COLD" if heat < COLD else "FAIR"


## A translation key: how the box was made (its type): FAT BOX, EVEN BOX or LEAN BOX.
static func nature(box: TicketBox, model: BoxModel = null) -> String:
	var m := model if model != null else BoxModel.standard()
	var t := m.type_by_id(box.type_id)
	if float(t.get("max", 0.0)) < 0.0:
		return "LEAN BOX"
	if float(t.get("min", 0.0)) > 0.0:
		return "FAT BOX"
	return "EVEN BOX"


## A translation key: TOP IN, or NO TOP (sold, or the box never had one: a lean box may not).
static func top(reading: Dictionary) -> String:
	return "TOP IN" if int(reading.roles.top) > 0 else "NO TOP"


## The index of the box whose rest pays most per dollar (a TIP-OFF names its column).
static func hottest(boxes: Array) -> int:
	var best := 0
	var heat := -1.0
	for i in boxes.size():
		var h: float = read(boxes[i]).heat
		if h > heat:
			heat = h
			best = i
	return best


## How many of the next `n` tickets of the box win (the PEEK item).
static func winners_next(box: TicketBox, n: int) -> int:
	var k := 0
	for i in range(box.cursor, mini(box.size, box.cursor + n)):
		if int(box.tickets[i].prize) > 0:
			k += 1
	return k
