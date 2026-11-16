class_name BoxReading
extends RefCounted
## What the box-reading perks tell about a box still in the machine. Pure logic. G
## (docs/roadmap.md 数值方向 三): a player never has the exact contents of a box; a
## reading tells only what has already happened, never what is left. The chain, each
## level adding to the one before:
##   FLARE  READ THE FLARE  whether a top prize is still in the box
##   FLOW   READ THE FLOW   about how many tickets have been sold (to the nearest ROUGH)
##                          and what they paid, exact (flow)
##   LEFT   ROUGH COUNT     about how many tickets are left, to the nearest ROUGH
## A level is a perk's value (Catalog, effect "reading"); the run reads at the highest
## level held (RunState.reading). A level put between two others gets the next number
## and the ones above it move up: callers name the levels, never their numbers.
## "Left" is what the machine still holds: tickets sold are gone, opened or not.

const FLARE := 1             ## READ THE FLARE
const FLOW := 2              ## READ THE FLOW
const LEFT := 3              ## ROUGH COUNT
const TOP_LEVEL := LEFT
## READ THE FLOW and ROUGH COUNT round their counts to this: the same grain both ways,
## so an exact count sold never gives an exact count left.
const ROUGH := 50


## The internal measure of a box: {left, value (prize money left), heat (value per
## dollar of tickets left), roles: {top, mid, low} prizes left of each kind}. The flare,
## the simulator and the flow study use it. No rule may show the player its value, its
## heat or its prize counts (they are what is left); the developer panel may.
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


## What has already happened to a box (READ THE FLOW): {sold, paid}. sold: the tickets
## that have left it, whoever bought them (exact: the player is shown rough(sold));
## paid: their printed prizes at the box's stake, no perk's multiplier (those are the
## buyer's, not the box's). SimData.flow_cut's past money is this at its cut.
static func flow(box: TicketBox) -> Dictionary:
	var paid := 0
	for i in mini(box.cursor, box.size):
		paid += int(box.tickets[i].prize)
	return {"sold": mini(box.cursor, box.size), "paid": paid}


## A count (tickets left, or sold) to the nearest ROUGH (never 0 while there is one).
static func rough(left: int) -> int:
	if left <= 0:
		return 0
	return maxi(ROUGH, roundi(float(left) / ROUGH) * ROUGH)


## A translation key: TOP IN, or NO TOP (sold, or the box never had one: a lean box may not).
static func top(reading: Dictionary) -> String:
	return "TOP IN" if int(reading.roles.top) > 0 else "NO TOP"


## How many of the next `n` tickets of the box win (the PEEK item).
static func winners_next(box: TicketBox, n: int) -> int:
	var k := 0
	for i in range(box.cursor, mini(box.size, box.cursor + n)):
		if int(box.tickets[i].prize) > 0:
			k += 1
	return k
