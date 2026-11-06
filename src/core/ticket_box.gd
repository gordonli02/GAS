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
