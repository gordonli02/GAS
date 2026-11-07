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
##
## The line that wins more often (docs/perk_research.md section 15) changes tickets
## instead of moving them, logged the same way: CONSOLATION turns a loser into the
## smallest prize (new money, so `counts` grows), CRUMBS splits a prize over the next
## losers (the same money on more tickets: the ticket split keeps `cut` less), PACKED
## breaks a share of the big prizes (tops and middles) into smallest ones when the box
## goes on the machine (the same money). Every change is decided from the seed and the
## box as it stands, so a replayed log changes the box the same way again.

var form: FormDef
var seed := ""
var type_id := ""
var size := 0
var counts: Array = []       ## real count per tier, same order as form.tiers
## Dictionary per ticket: no, tier, prize, win_group, serial, groups, marks, verify.
## A form that wins by group adds wins: the tier each group won, or -1; prize is then
## their sum and tier the best of them. A ticket CRUMBS split has `cut` (what its best
## tier's prize gave away; prize is already that much less), a piece of one `crumb`;
## `packed`: how many of its smallest prizes PACKED made (PENNY JAR and STACKER pass
## those over).
var tickets: Array = []
var cursor := 0              ## next ticket to sell
var opened := 0              ## tickets opened so far (by ticket number)
## Every reorder or change of what was left, in order: {"s": cursor} a SHUFFLE at that
## cursor, {"m": [a, b]} the tickets at a and b swapped, {"w": [i, tier]} the loser at i
## made a winner of tier (CONSOLATION), {"c": [i, n]} the prize at i split over up to n
## losers after it (CRUMBS), {"p": pct} pct% of the big prizes broken into smallest
## ones (PACKED).
var ops: Array = []
var cut_total := 0           ## money CRUMBS took off split tickets (their pieces hold it)


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
		elif op.has("w") and typeof(op.w) == TYPE_ARRAY and op.w.size() == 2:
			make_winner(int(op.w[0]), int(op.w[1]))
		elif op.has("c") and typeof(op.c) == TYPE_ARRAY and op.c.size() == 2:
			crumble(int(op.c[0]), int(op.c[1]))
		elif op.has("p"):
			pack(int(op.p))


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


## The tier of the smallest prize (the first of equals).
func smallest_tier() -> int:
	var best := 0
	for i in form.tiers.size():
		if int(form.tiers[i].prize) < int(form.tiers[best].prize):
			best = i
	return best


## CONSOLATION: the loser at `i` (unsold) wins the smallest prize, `pct` times in a
## hundred; the roll is the seed's and the place's, so it comes out the same each
## time. True when it won.
func console(i: int, pct: int) -> bool:
	if pct <= 0 or i < cursor or i >= size or wins(i):
		return false
	if SeededRng.new("%s|console|%d" % [seed, i]).next_float() * 100.0 >= pct:
		return false
	return make_winner(i, smallest_tier())


## The loser at `i` (unsold) becomes a winner of `tier`: new money in the box. Logged.
## False, and nothing changed, when it wins already or is sold.
func make_winner(i: int, tier: int) -> bool:
	if i < cursor or i >= size or wins(i) or tier < 0 or tier >= form.tiers.size():
		return false
	_win(i, tier)
	ops.append({"w": [i, tier]})
	return true


## CRUMBS: the prize of the ticket at `i` (unsold; its best tier's, when it holds
## several) is broken over up to `n` more tickets, the next losers after it in the box:
## each becomes the smallest prize and the ticket keeps the rest, so the money is the
## same. The ticket keeps at least the smallest prize, so a prize of k smallest ones
## makes k - 1 pieces at most (the smallest prize itself none); fewer when fewer
## losers are left; pieces are never split again.
## Logged when it split. Returns how many pieces were made.
func crumble(i: int, n: int) -> int:
	if n <= 0 or i < cursor or i >= size or not wins(i):
		return 0
	var t: Dictionary = tickets[i]
	if t.get("crumb", false) or t.has("cut"):
		return 0
	var low := smallest_tier()
	var s := int(form.tiers[low].prize)
	var keep := int(form.tiers[int(t.tier)].prize)
	var made := 0
	var j := i + 1
	while made < n and keep >= 2 * s:
		while j < size and wins(j):
			j += 1
		if j >= size:
			break
		_win(j, low)
		tickets[j].crumb = true
		keep -= s
		made += 1
		j += 1
	if made == 0:
		return 0
	t.cut = made * s
	t.prize = int(t.prize) - made * s
	cut_total += made * s
	ops.append({"c": [i, n]})
	return made


## PACKED: `pct`% of the box's prizes bigger than the smallest (tops and middles, every
## prize on a ticket counted, in whole prizes) are broken into smallest prizes:
## each one picked from the seed, its ticket keeping one smallest prize and losers
## picked from the seed taking the rest. The money stays the same to the coin (every
## prize is a multiple of the smallest). A prize needing more losers than are left is
## passed over for another. Only on a box not sold from yet (it goes on the machine).
## Every smallest prize it makes is counted on its ticket (`packed`), so PENNY JAR and
## STACKER pass them over (RunState.pay_ticket; G, 2026-11-07: PACKED must not stack
## up with PENNY JAR). Logged. Returns the smallest prizes added (the broken prizes'
## worth in them).
func pack(pct: int) -> int:
	if pct <= 0 or cursor > 0:
		return 0
	ops.append({"p": pct})
	var low := smallest_tier()
	var s := int(form.tiers[low].prize)
	var big := []
	var dead := []
	for i in range(cursor, size):
		if not wins(i):
			dead.append(i)
			continue
		for g in tickets[i].get("wins", [tickets[i].tier]):
			if int(g) >= 0 and int(form.tiers[int(g)].prize) > s:
				big.append([i, int(g)])
	# The share in whole prizes, the part of one rolled from the seed (a box with one
	# big prize breaks it at 25% a quarter of the time), so every form gets the share.
	var r := SeededRng.new("%s|pack" % seed)
	var exact := big.size() * pct / 100.0
	var want := floori(exact)
	if r.next_float() < exact - want:
		want += 1
	var broken := 0
	var added := 0
	while broken < want and not big.is_empty():
		var pick: Array = big.pop_at(r.next_int(big.size()))
		var pieces := int(form.tiers[pick[1]].prize) / s - 1
		if dead.size() < pieces:
			continue
		_demote(pick[0], pick[1], low)
		tickets[pick[0]].packed = int(tickets[pick[0]].get("packed", 0)) + 1
		for k in pieces:
			var j: int = dead.pop_at(r.next_int(dead.size()))
			_win(j, low)
			tickets[j].packed = 1
		broken += 1
		added += pieces + 1
	return added


## The loser at `i` wins `tier` (in a group from the seed, for a form that wins by
## group); counted. Not logged: the op that called it is.
func _win(i: int, tier: int) -> void:
	var t: Dictionary = tickets[i]
	if form.wins_by_group():
		var w: Array = t.wins
		w[SeededRng.new("%s|win|%d" % [seed, i]).next_int(w.size())] = tier
	t.tier = tier
	t.prize = int(form.tiers[tier].prize)
	counts[tier] += 1


## One prize of `tier` on the ticket at `i` becomes the smallest prize (`low`); its
## best tier, prize and verify code follow. Counted.
func _demote(i: int, tier: int, low: int) -> void:
	var t: Dictionary = tickets[i]
	counts[tier] -= 1
	counts[low] += 1
	if not form.wins_by_group():
		t.tier = low
		t.prize = int(form.tiers[low].prize)
	else:
		var w: Array = t.wins
		w[w.find(tier)] = low
		var best := -1
		var sum := 0
		for g in w:
			if g < 0:
				continue
			sum += int(form.tiers[g].prize)
			if best < 0 or int(form.tiers[g].prize) > int(form.tiers[best].prize):
				best = g
		t.tier = best
		t.prize = sum
	if t.has("verify"):
		var top := false
		for g in t.get("wins", [t.tier]):
			top = top or form.is_top(g)
		if not top:
			t.verify = ""


func gross() -> int:
	return size * form.price


## The box's prize money: every prize it holds (CRUMBS's pieces are counted as
## prizes, so what they took off the tickets they came from is taken off here).
func prize_total() -> int:
	var s := 0
	for i in counts.size():
		s += int(form.tiers[i].prize) * int(counts[i])
	return s - cut_total


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
