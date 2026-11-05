extends Node
## Thin platform layer (autoload "Platform").
## Everything store- or OS-specific goes through here so a Steam backend
## (GodotSteam) can be dropped in later without touching game code.
## The migration ships only the offline backend below.

const BUILTIN_PACK_DIR := "res://packs/core"
const USER_PACK_DIR := "user://packs"

var backend: PlatformBackend = PlatformBackend.new()


func backend_name() -> String:
	return backend.name()


## Where data packs come from, built-in first. A store backend adds its
## subscribed-item folders (e.g. Steam Workshop) through extra_pack_dirs().
func pack_dirs() -> PackedStringArray:
	var dirs := PackedStringArray([BUILTIN_PACK_DIR])
	if DirAccess.dir_exists_absolute(USER_PACK_DIR):
		for sub in DirAccess.get_directories_at(USER_PACK_DIR):
			dirs.append(USER_PACK_DIR.path_join(sub))
	dirs.append_array(backend.extra_pack_dirs())
	return dirs


## Folder for the save file. A store backend may move it (e.g. a cloud-synced folder).
func save_dir() -> String:
	return backend.save_dir()


func unlock_achievement(id: String) -> void:
	backend.unlock_achievement(id)


func player_name() -> String:
	return backend.player_name()
