extends Node
## Settings, the free-play session and the run in progress (autoload "Save"), kept in one versioned
## file through SaveFile. Nothing is read until the game calls open(), so tools and
## tests can point it at a scratch file first. Changes are written at most once a
## second, and straight away on flush() (quitting, closing the window).

const FLUSH_GAP := 1.0

var path := ""
var settings: Dictionary = SaveFile.SETTINGS.duplicate(true)
var session: Dictionary = {}    ## free play
var run: Dictionary = {}        ## the story mode's run: {state, session}; {} when there is none
var _written := ""
var _dirty := false
var _since := 0.0


func default_path() -> String:
	return Platform.save_dir().path_join("save.json")


## Reads the save at `p` (default: the platform's save folder).
func open(p := "") -> void:
	path = p if p != "" else default_path()
	var r := SaveFile.read(path)
	settings = r.settings
	session = r.session
	run = r.run
	if r.note != "":
		push_warning("Save: " + r.note)
	_written = SaveFile.encode(settings, session, run) if FileAccess.file_exists(path) else ""
	_dirty = false


func setting(key: String) -> Variant:
	return settings.get(key, SaveFile.SETTINGS.get(key))


func set_setting(key: String, value: Variant) -> void:
	if settings.get(key) == value:
		return
	settings[key] = value
	_dirty = true


func set_session(d: Dictionary) -> void:
	session = d
	_dirty = true


func set_run(d: Dictionary) -> void:
	run = d
	_dirty = true


## Writes now if anything changed since the last write.
func flush() -> void:
	_dirty = false
	_since = 0.0
	if path == "":
		return
	var text := SaveFile.encode(settings, session, run)
	if text == _written:
		return
	if SaveFile.write_text(path, text):
		_written = text
	else:
		push_warning("Save: could not write " + path)


func _process(dt: float) -> void:
	if not _dirty:
		return
	_since += dt
	if _since >= FLUSH_GAP:
		flush()
