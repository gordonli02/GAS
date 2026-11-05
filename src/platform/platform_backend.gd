class_name PlatformBackend
extends RefCounted
## Offline backend: no store, no overlay, no achievements.
## A Steam backend subclasses this and overrides what it supports.


func name() -> String:
	return "offline"


func extra_pack_dirs() -> PackedStringArray:
	return PackedStringArray()


func save_dir() -> String:
	return "user://"


func unlock_achievement(_id: String) -> void:
	pass


func player_name() -> String:
	return ""
