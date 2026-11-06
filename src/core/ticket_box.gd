class_name TicketBox
extends RefCounted
## A generated box: its real prize counts and every ticket in sale order.

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
var shuffles: Array = []     ## SHUFFLE: the cursor at each shuffle of what was left, in order


## SHUFFLE (an item): the tickets not sold yet come in another order, from the seed and
## the shuffles before, so a saved box shuffles the same way again. Every ticket takes
## its new place's number (`no` is where it sits in the box).
func shuffle_rest() -> void:
	var r := SeededRng.new("%s|shuffle|%d" % [seed, shuffles.size()])
	shuffles.append(cursor)
	var rest := tickets.slice(cursor)
	for j in range(rest.size() - 1, 0, -1):
		var k := r.next_int(j + 1)
		var tmp = rest[j]
		rest[j] = rest[k]
		rest[k] = tmp
	for j in rest.size():
		tickets[cursor + j] = rest[j]
		rest[j].no = cursor + j + 1


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
