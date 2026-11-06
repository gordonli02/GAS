class_name TicketTray
extends RefCounted
## Tickets bought and not yet opened, all forms in one line, opened in purchase order.
## Each entry: {form: FormDef, ticket: Dictionary, box: TicketBox, bet: int} (bet: what
## the ticket was bought at, HIGH ROLLER; prizes pay that many times).

var items: Array = []


func size() -> int:
	return items.size()


func is_empty() -> bool:
	return items.is_empty()


func add(form: FormDef, ticket: Dictionary, box: TicketBox, bet := 1) -> void:
	items.append({"form": form, "ticket": ticket, "box": box, "bet": bet})


## Up to `n` tickets off the front, in order (QUICK HANDS opens them at once).
func take_many(n: int) -> Array:
	var out := items.slice(0, mini(n, items.size()))
	items = items.slice(out.size())
	return out


## Next ticket to open, or {} when empty.
func take() -> Dictionary:
	return items.pop_front() if not items.is_empty() else {}


## An untouched ticket goes back on top, to be opened next.
func put_back(entry: Dictionary) -> void:
	items.push_front(entry)


## A ticket put back by hand goes to the bottom, so the next one comes up first (G).
func put_last(entry: Dictionary) -> void:
	items.push_back(entry)


func peek() -> Dictionary:
	return items[0] if not items.is_empty() else {}


## The ticket bought last, or {} when empty.
func newest() -> Dictionary:
	return items[-1] if not items.is_empty() else {}


func clear() -> void:
	items.clear()
