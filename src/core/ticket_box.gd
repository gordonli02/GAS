class_name TicketBox
extends RefCounted
## A generated box: its real prize counts and every ticket in sale order.
##
## What is left in a box can be reordered: SHUFFLE permutes it, and the run's
## certainty perks and items (G, M9.5: "a sure win is a prize of this box moved
## forward, never a new one") swap a winner still in the box into an earlier place.
## Every reorder is logged in `ops` in order, so a saved box is rebuilt from its seed
## and the log replayed (MachineLogic.load_boxes) and comes back as it was. Reading the
## box (BoxReading) counts what is left, so nothing it says is made false by a move.

var form: FormDef
var seed := ""
var type_id := ""
var size := 0
var counts: Array = []       ## real count per tier, same order as form.tiers
## Dictionary per ticket: no, tier, prize, win_group, serial, groups, marks, verify.
## A form that wins by group adds wins: the tier each group won, or -1; prize is then
## their sum and tier the best of them.
var tickets: Array = []
var cursor := 0              ## next ticket to sell
var opened := 0              ## tickets opened so far (by ticket number)
## Every reorder of what was left, in order: {"s": cursor} a SHUFFLE at that cursor,
## {"m": [a, b]} the tickets at a and b swapped.
var ops: Array = []


## SHUFFLE (an item): the tickets not sold yet come in another order, from the seed and
## the shuffles before, so a saved box shuffles the same way again. Every ticket takes
## its new place's number (`no` is where it sits in the box).
func shuffle_rest() -> void:
	var r := SeededRng.new("%s|shuffle|%d" % [seed, shuffles()])
	ops.append({"s": cursor})
	var rest := tickets.slice(cursor)
	for j in range(rest.size() - 1, 0, -1):
		var k := r.next_int(j + 1)
		var tmp = rest[j]
		rest[j] = rest[k]
		rest[k] = tmp
	for j in rest.size():
		tickets[cursor + j] = rest[j]
		rest[j].no = cursor + j + 1


## How many times the box was shuffled.
func shuffles() -> int:
	var n := 0
	for op in ops:
		if op.has("s"):
			n += 1
	return n


## The tickets at `a` and `b` (both unsold) change places, numbered by their new
## places. Logged. False, and nothing moved, when either is sold or out of the box.
func swap(a: int, b: int) -> bool:
	if a == b or a < cursor or b < cursor or a >= size or b >= size:
		return false
	var tmp = tickets[a]
	tickets[a] = tickets[b]
	tickets[b] = tmp
	tickets[a].no = a + 1
	tickets[b].no = b + 1
	ops.append({"m": [a, b]})
	return true


## Replays a saved log on a box built fresh from its seed (its own log is emptied first).
func replay(saved: Array) -> void:
	ops = []
	for op in saved:
		if typeof(op) != TYPE_DICTIONARY:
			continue
		if op.has("s"):
			cursor = clampi(int(op.s), 0, size)
			shuffle_rest()
		elif op.has("m") and typeof(op.m) == TYPE_ARRAY and op.m.size() == 2:
			swap(int(op.m[0]), int(op.m[1]))


func wins(i: int) -> bool:
	return int(tickets[i].prize) > 0


## The role (top, mid, low) of a ticket's best tier, "" for a loser.
func role_of(i: int) -> String:
	var t: Dictionary = tickets[i]
	return str(form.tiers[int(t.tier)].role) if int(t.prize) > 0 and int(t.tier) >= 0 else ""


## The index of a winner at or after `from` (unsold): the first one ("next"), the first
## low prize ("small"; any winner when no low prize is left), the biggest prize
## ("biggest"; the first of equals), or one at random ("random", from the seed and the
## log, so the same each time). -1 when none is left.
func find_winner(from: int, which := "next") -> int:
	from = maxi(from, cursor)
	match which:
		"small":
			for i in range(from, size):
				if wins(i) and role_of(i) == "low":
					return i
			return find_winner(from, "next")
		"biggest":
			var best := -1
			for i in range(from, size):
				if wins(i) and (best < 0 or int(tickets[i].prize) > int(tickets[best].prize)):
					best = i
			return best
		"random":
			var all := []
			for i in range(from, size):
				if wins(i):
					all.append(i)
			if all.is_empty():
				return -1
			return all[SeededRng.new("%s|pull|%d" % [seed, ops.size()]).next_int(all.size())]
		_:
			for i in range(from, size):
				if wins(i):
					return i
	return -1


## Puts a winner at `to` (unsold): the one find_winner(to + 1, which) names is swapped
## in, unless the ticket at `to` wins already ("biggest" swaps the biggest prize in
## unless it is there already). True when `to` wins afterwards.
func pull_winner(to: int, which := "next") -> bool:
	if to < cursor or to >= size:
		return false
	if which == "biggest":
		var best := find_winner(to, "biggest")
		if best < 0:
			return false
		return best == to or swap(to, best)
	if wins(to):
		return true
	var from := find_winner(to + 1, which)
	if from < 0:
		return false
	return swap(to, from)


## Within the `n` tickets from `start`, the winners come first (their order kept). For
## MARKED. Returns how many winners are in the window.
func front_load(start: int, n: int) -> int:
	start = maxi(start, cursor)
	var stop := mini(size, start + n)
	var put := start
	for i in range(start, stop):
		if wins(i):
			if i != put:
				swap(put, i)
			put += 1
	return put - start


## Up to `count` winners from beyond the window of `n` tickets at `start` are swapped
## into losing places of the window (the first winners after it, into places chosen
## from the seed and the log). For QUEUE JUMP. Returns how many were moved.
func scatter(start: int, n: int, count: int) -> int:
	start = maxi(start, cursor)
	var stop := mini(size, start + n)
	var holes := []
	for i in range(start, stop):
		if not wins(i):
			holes.append(i)
	var r := SeededRng.new("%s|scatter|%d" % [seed, ops.size()])
	var moved := 0
	var from := stop
	while moved < count and not holes.is_empty():
		from = find_winner(from, "next")
		if from < 0:
			break
		var hole: int = holes[r.next_int(holes.size())]
		holes.erase(hole)
		swap(hole, from)
		from += 1
		moved += 1
	return moved


func gross() -> int:
	return size * form.price


func prize_total() -> int:
	var s := 0
	for i in counts.size():
		s += int(form.tiers[i].prize) * int(counts[i])
	return s


func net() -> int:
	return prize_total() - gross()


## Same numbers as the web build's developer panel.
func summary() -> Dictionary:
	var left := counts.duplicate()
	var paid := 0
	for i in opened:
		var t: Dictionary = tickets[i]
		for tier in t.get("wins", [t.tier]):
			if tier >= 0:
				left[tier] -= 1
		paid += t.prize
	var remain := size - opened
	var prizes := prize_total()
	return {
		"left": left,
		"paid": paid,
		"gross": gross(),
		"prizes": prizes,
		"net": prizes - gross(),
		"rtp": float(prizes) / gross(),
		"remain": remain,
		"ev": float(prizes - paid) / remain if remain > 0 else 0.0,
	}
