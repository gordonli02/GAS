class_name SaveFile
extends RefCounted
## The one save file: settings and the session in progress, with a version number.
## Pure file logic (no scene access) so tests can run it on a scratch path.
##
## File: {"version": VERSION, "settings": {...}, "session": {...}}. Older versions are
## migrated step by step on load. A file that cannot be read, or that comes from a
## newer build, is moved aside (".bad" / ".v<n>") and the game starts from defaults.
## Writes go to "<path>.tmp" first and then replace the file, so a crash mid-write
## leaves the previous save intact.

const VERSION := 1

## Defaults for every setting. Unknown keys in a file are dropped; missing ones filled.
const SETTINGS := {
	"room": "diner",
	"master": 0.8,           ## master volume 0..1
	"muted": false,
	"fullscreen": false,
	"language": "",          ## "" follows the system, else "en" / "zh"
	"sounds": {},            ## developer: sound id -> {file, name, volume}
	"lamp": 0,               ## developer: red button brightness step
}


## Reads a save. Returns {settings, session, note}; note says what went wrong, if anything.
static func read(path: String) -> Dictionary:
	var out := {"settings": SETTINGS.duplicate(true), "session": {}, "note": ""}
	if not FileAccess.file_exists(path):
		return out
	var json := JSON.new()
	var data = json.data if json.parse(FileAccess.get_file_as_string(path)) == OK else null
	if typeof(data) != TYPE_DICTIONARY or not data.has("version"):
		_move_aside(path, path + ".bad")
		out.note = "unreadable save moved to %s.bad" % path.get_file()
		return out
	var v := int(data.version)
	if v > VERSION:
		_move_aside(path, "%s.v%d" % [path, v])
		out.note = "save from a newer build (v%d) moved aside" % v
		return out
	data = migrate(data)
	out.settings = clean_settings(data.get("settings", {}))
	var session = data.get("session", {})
	out.session = session if typeof(session) == TYPE_DICTIONARY else {}
	return out


## Writes settings and session. Returns true on success.
static func write(path: String, settings: Dictionary, session: Dictionary) -> bool:
	return write_text(path, encode(settings, session))


static func encode(settings: Dictionary, session: Dictionary) -> String:
	return JSON.stringify({"version": VERSION, "settings": settings, "session": session}, "\t", false)


static func write_text(path: String, text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK


## Brings an older file up to VERSION. Each step handles one version.
static func migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("version", VERSION))
	while v < VERSION:
		match v:
			_:
				pass   # no older versions yet
		v += 1
	data.version = VERSION
	return data


## Known keys only, each with the default's type; anything off falls back to the default.
static func clean_settings(s) -> Dictionary:
	var out := SETTINGS.duplicate(true)
	if typeof(s) != TYPE_DICTIONARY:
		return out
	for k in SETTINGS:
		if not s.has(k):
			continue
		var want := typeof(SETTINGS[k])
		var got = s[k]
		if want == TYPE_FLOAT and typeof(got) == TYPE_INT:
			got = float(got)
		elif want == TYPE_INT and typeof(got) == TYPE_FLOAT:
			got = int(got)
		if typeof(got) == want:
			out[k] = got
	out.master = clampf(out.master, 0.0, 1.0)
	return out


static func _move_aside(path: String, to: String) -> void:
	if FileAccess.file_exists(to):
		DirAccess.remove_absolute(to)
	DirAccess.rename_absolute(path, to)
