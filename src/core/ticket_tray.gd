class_name TicketTray
extends RefCounted
## Tickets bought and not yet opened, all forms in one line, opened in purchase order.
## Each entry: {form: FormDef, ticket: Dictionary, box: TicketBox}.

var items: Array = []


func size() -> int:
	return items.size()


func is_empty() -> bool:
	return items.is_empty()


func add(form: FormDef, ticket: Dictionary, box: TicketBox) -> void:
	items.append({"form": form, "ticket": ticket, "box": box})


## Next ticket to open, or {} when empty.
func take() -> Dictionary:
	return items.pop_front() if not items.is_empty() else {}


## An untouched ticket goes back on top, to be opened next.
func put_back(entry: Dictionary) -> void:
	items.push_front(entry)


func peek() -> Dictionary:
	return items[0] if not items.is_empty() else {}


func clear() -> void:
	items.clear()
