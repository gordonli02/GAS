class_name Orphans
extends RefCounted
## Nodes made in a script's member declarations (`var x := Label.new()`) belong to it
## only once added to the tree. When a node is freed before that happens (the game
## stopping early: missing ticket data, a developer tool taking over), they would be
## left behind and reported as leaked at exit. Call free_members(self, [names]) on
## NOTIFICATION_PREDELETE, naming only the members this script made itself: a member
## that merely points at another node (GameInput.game) must never be freed here.
## In a normal run every named member has a parent and nothing happens.


static func free_members(owner: Object, names: Array) -> void:
	for n in names:
		var v = owner.get(n)
		if is_instance_valid(v) and v is Node and v.get_parent() == null:
			v.free()
