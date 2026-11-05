extends Node
## Loaded data packs (autoload "Packs"). Reads every pack folder the platform
## layer lists; rejected packs are reported and skipped.

var packs: Array[PackDef] = []
var errors := {}   ## pack dir -> PackedStringArray


func _ready() -> void:
	reload()


func reload() -> void:
	packs.clear()
	errors.clear()
	for dir in Platform.pack_dirs():
		var res := PackLoader.load_dir(dir)
		if res.ok():
			packs.append(res.pack)
		else:
			errors[dir] = res.errors
			push_warning("Data pack rejected: %s\n  %s" % [dir, "\n  ".join(res.errors)])


func forms() -> Array[FormDef]:
	var out: Array[FormDef] = []
	for p in packs:
		for f in p.forms:
			out.append(f)
	return out


func form(uid: String) -> FormDef:
	for f in forms():
		if f.uid() == uid:
			return f
	return null


func pack(id: String) -> PackDef:
	for p in packs:
		if p.id == id:
			return p
	return null


## The rips a form tears with: its own, else its pack's, else the core pack's.
func tear_clips_for(f: FormDef) -> Array:
	if not f.tear_clips.is_empty():
		return f.tear_clips
	var p := pack(f.pack_id)
	if p != null and not p.tear_clips.is_empty():
		return p.tear_clips
	var core := pack("core")
	return core.tear_clips if core != null else []
