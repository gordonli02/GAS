class_name PackLoader
extends RefCounted
## Reads and validates a data pack directory.
## Packs are data only: a pack containing any file type outside ALLOWED_EXTENSIONS
## is rejected as a whole, and nothing in a pack is ever passed to load().

const FORMAT := 1
const MANIFEST := "pack.json"
const ALLOWED_EXTENSIONS := ["json", "png", "jpg", "jpeg", "webp", "wav", "ogg", "mp3", "txt", "md"]
const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp"]
const AUDIO_EXTENSIONS := ["wav", "ogg", "mp3"]
const LAYOUT_PRESETS := ["single", "windows", "jar"]
const ID_PATTERN := "^[a-z0-9_]{1,32}$"
const MAX_FILES := 2000


class Result:
	var pack: PackDef
	var errors := PackedStringArray()

	func ok() -> bool:
		return errors.is_empty() and pack != null


static func load_dir(dir: String) -> Result:
	var res := Result.new()
	var ctx := _Ctx.new(dir, res.errors)

	var files := _list_files(dir, "", ctx)
	if not res.errors.is_empty():
		return res
	for f in files:
		if not ALLOWED_EXTENSIONS.has(f.get_extension().to_lower()):
			ctx.err("file type not allowed in a data pack: " + f)
	if not res.errors.is_empty():
		return res

	var manifest = ctx.read_json(MANIFEST)
	if not manifest is Dictionary:
		ctx.err("pack.json must be an object")
		return res

	var pack := PackDef.new()
	pack.dir = dir
	pack.format = ctx.req_int(manifest, "format", "pack.json")
	if pack.format != FORMAT:
		ctx.err("pack.json: unsupported format %d (expected %d)" % [pack.format, FORMAT])
		return res
	pack.id = ctx.req_id(manifest, "id", "pack.json")
	pack.version = ctx.req_string(manifest, "version", "pack.json")
	pack.name = ctx.req_text(manifest, "name", "pack.json")
	pack.author = str(manifest.get("author", ""))

	var form_paths = manifest.get("forms", [])
	if not form_paths is Array:
		ctx.err("pack.json: forms must be a list of paths")
		form_paths = []
	var seen := {}
	for p in form_paths:
		var f := _load_form(ctx, pack, str(p))
		if f == null:
			continue
		if seen.has(f.id):
			ctx.err("%s: duplicate form id '%s'" % [p, f.id])
		seen[f.id] = true
		pack.forms.append(f)

	if manifest.has("tear_sounds"):
		pack.tear_clips = _load_tear_sounds(ctx, manifest.tear_sounds, "pack.json")

	if res.errors.is_empty():
		res.pack = pack
	return res


static func _load_form(ctx: _Ctx, pack: PackDef, path: String) -> FormDef:
	var d = ctx.read_json(path)
	if not d is Dictionary:
		ctx.err(path + ": must be an object")
		return null
	var f := FormDef.new()
	f.pack_id = pack.id
	f.source_dir = ctx.dir
	f.id = ctx.req_id(d, "id", path)
	f.name = ctx.req_string(d, "name", path)
	f.code = ctx.req_string(d, "code", path)
	f.price = ctx.req_int(d, "price", path)
	if f.price < 1:
		ctx.err(path + ": price must be at least 1")

	var title = d.get("title")
	if not (title is Array and title.size() >= 1 and title.size() <= 3):
		ctx.err(path + ": title must be a list of 1 to 3 strings")
	else:
		for t in title:
			f.title.append(str(t))

	var c = d.get("colors")
	if not c is Dictionary:
		ctx.err(path + ": colors missing")
	else:
		for k in ["edge", "head", "ink"]:
			f.colors[k] = ctx.req_color(c, k, path + " colors")
		var tiles: Array = []
		if c.get("tiles") is Array:
			for t in c.tiles:
				tiles.append(ctx.color_of(t, path + " colors.tiles"))
		f.colors["tiles"] = tiles

	var tiers = d.get("tiers")
	if not (tiers is Array and tiers.size() >= 3 and tiers.size() <= 8):
		ctx.err(path + ": tiers must be a list of 3 to 8 entries")
		tiers = []
	for i in tiers.size():
		var t = tiers[i]
		var where := "%s tiers[%d]" % [path, i]
		if not t is Dictionary:
			ctx.err(where + ": must be an object")
			continue
		var tier := {
			"key": ctx.req_id(t, "key", where),
			"label": ctx.req_text(t, "label", where),
			"prize": ctx.req_int(t, "prize", where),
			"printed_count": ctx.req_int(t, "printed_count", where),
			"role": ctx.req_string(t, "role", where),
			"symbol": "",
		}
		if not FormDef.ROLES.has(tier.role):
			ctx.err(where + ": role must be one of " + ", ".join(FormDef.ROLES))
		if tier.prize < 1:
			ctx.err(where + ": prize must be at least 1")
		if t.has("symbol"):
			tier.symbol = ctx.req_file(t, "symbol", where, IMAGE_EXTENSIONS, "")
		f.tiers.append(tier)
	if f.colors.has("tiles") and f.colors.tiles.size() < f.tiers.size():
		ctx.err(path + ": colors.tiles needs one colour per tier")
	_check_prize_roles(ctx, f, path)

	var groups = d.get("digit_groups")
	if not (groups is Array and groups.size() >= 1 and groups.size() <= 8):
		ctx.err(path + ": digit_groups must be a list of 1 to 8 lengths")
	else:
		for g in groups:
			if not (g is float or g is int) or int(g) != g or g < 2 or g > 6:
				ctx.err(path + ": each digit group length must be 2 to 6")
			else:
				f.digit_groups.append(int(g))

	f.win_display = str(d.get("win_display", "whole"))
	if not FormDef.WIN_DISPLAYS.has(f.win_display):
		ctx.err(path + ": win_display must be one of " + ", ".join(FormDef.WIN_DISPLAYS))

	var layout = d.get("layout")
	if not layout is Dictionary:
		ctx.err(path + ": layout missing")
	else:
		f.layout = layout
		if not LAYOUT_PRESETS.has(str(layout.get("preset", ""))):
			ctx.err(path + ": layout.preset must be one of " + ", ".join(LAYOUT_PRESETS))

	if d.has("tear_sounds"):
		f.tear_clips = _load_tear_sounds(ctx, d.tear_sounds, path)
	return f


## The box generator needs top tiers of one prize, one mid and one low tier,
## and every prize a whole multiple of the low prize.
static func _check_prize_roles(ctx: _Ctx, f: FormDef, path: String) -> void:
	var tops := f.tier_indices("top")
	var mids := f.tier_indices("mid")
	var lows := f.tier_indices("low")
	if tops.is_empty() or mids.size() != 1 or lows.size() != 1:
		ctx.err(path + ": tiers need at least one 'top', exactly one 'mid' and exactly one 'low'")
		return
	var low: int = f.tiers[lows[0]].prize
	for i in tops:
		if f.tiers[i].prize != f.tiers[tops[0]].prize:
			ctx.err(path + ": all 'top' tiers must have the same prize")
	for t in f.tiers:
		if low > 0 and t.prize % low != 0:
			ctx.err(path + ": every prize must be a multiple of the 'low' prize")
			return


static func _load_tear_sounds(ctx: _Ctx, d, where: String) -> Array:
	var out: Array = []
	if not d is Dictionary:
		ctx.err(where + ": tear_sounds must be an object")
		return out
	var marks_path := ctx.req_file(d, "marks", where + " tear_sounds", ["json"], "")
	var marks = ctx.read_json(marks_path) if marks_path != "" else null
	if not marks is Dictionary:
		ctx.err(where + ": tear marks must be an object keyed by clip file name")
		return out
	var clips = d.get("clips")
	if not (clips is Array and clips.size() >= 1):
		ctx.err(where + ": tear_sounds.clips must list at least one clip")
		return out
	for c in clips:
		var rel := str(c)
		if ctx.check_file(rel, where + " tear clip", AUDIO_EXTENSIONS) == "":
			continue
		var m = marks.get(rel.get_file())
		if not (m is Array and m.size() >= 2):
			ctx.err("%s: no crackle marks for %s" % [marks_path, rel.get_file()])
			continue
		var pm := PackedFloat32Array()
		var prev := -1.0
		for v in m:
			if not (v is float or v is int) or v < prev:
				ctx.err("%s: marks for %s must be rising numbers" % [marks_path, rel.get_file()])
				break
			prev = v
			pm.append(v)
		out.append({"path": ctx.abs_path(rel), "marks": pm})
	return out


static func _list_files(dir: String, rel: String, ctx: _Ctx) -> PackedStringArray:
	var out := PackedStringArray()
	var full := dir.path_join(rel) if rel != "" else dir
	var da := DirAccess.open(full)
	if da == null:
		ctx.err("cannot open pack folder: " + full)
		return out
	da.include_hidden = true
	for f in da.get_files():
		out.append(rel.path_join(f) if rel != "" else f)
	for sub in da.get_directories():
		out.append_array(_list_files(dir, rel.path_join(sub) if rel != "" else sub, ctx))
	if out.size() > MAX_FILES:
		ctx.err("pack has too many files")
	return out


## Shared validation helpers; every error names the file and field.
class _Ctx:
	var dir: String
	var errors: PackedStringArray

	func _init(d: String, e: PackedStringArray) -> void:
		dir = d
		errors = e

	func err(msg: String) -> void:
		errors.append(msg)

	func abs_path(rel: String) -> String:
		return dir.path_join(rel) if rel != "" else dir

	func read_json(rel: String):
		var path := abs_path(rel)
		if not FileAccess.file_exists(path):
			err("missing file: " + rel)
			return null
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string(path)) != OK:
			err("%s: JSON error on line %d: %s" % [rel, j.get_error_line(), j.get_error_message()])
			return null
		return j.data

	## A relative path inside the pack: no absolute paths, no "..", must exist.
	func check_file(rel: String, where: String, exts: Array) -> String:
		if rel == "" or rel.is_absolute_path() or rel.contains(":") or rel.contains("\\") or ".." in rel.split("/"):
			err("%s: '%s' must be a relative path inside the pack" % [where, rel])
			return ""
		if not exts.has(rel.get_extension().to_lower()):
			err("%s: '%s' must be one of %s" % [where, rel, ", ".join(exts)])
			return ""
		if not FileAccess.file_exists(abs_path(rel)):
			err("%s: missing file %s" % [where, rel])
			return ""
		return rel

	func req_file(d: Dictionary, key: String, where: String, exts: Array, base: String) -> String:
		if not d.get(key) is String:
			err("%s: '%s' must be a file path" % [where, key])
			return ""
		var rel: String = base.path_join(d[key]) if base != "" else d[key]
		return check_file(rel, where, exts)

	func req_string(d: Dictionary, key: String, where: String) -> String:
		var v = d.get(key)
		if not v is String or v.strip_edges() == "":
			err("%s: '%s' must be a non-empty string" % [where, key])
			return ""
		return v

	func req_id(d: Dictionary, key: String, where: String) -> String:
		var v := req_string(d, key, where)
		if v != "" and not RegEx.create_from_string(ID_PATTERN).search(v):
			err("%s: '%s' must use a-z, 0-9 and _ only" % [where, key])
		return v

	func req_int(d: Dictionary, key: String, where: String) -> int:
		var v = d.get(key)
		if not (v is float or v is int) or int(v) != v:
			err("%s: '%s' must be a whole number" % [where, key])
			return 0
		return int(v)

	## Localized text: a plain string, or {"en": ..., "zh": ...} with English required.
	func req_text(d: Dictionary, key: String, where: String) -> Dictionary:
		var v = d.get(key)
		if v is String and v != "":
			return {"en": v}
		if v is Dictionary and v.get("en") is String and v.en != "":
			var out := {}
			for k in v:
				out[str(k)] = str(v[k])
			return out
		err("%s: '%s' must be text or {\"en\": ...}" % [where, key])
		return {}

	func req_color(d: Dictionary, key: String, where: String) -> Color:
		return color_of(d.get(key), where + "." + key)

	func color_of(v, where: String) -> Color:
		if v is String and Color.html_is_valid(v):
			return Color.html(v)
		err("%s: '%s' is not a colour like #12abef" % [where, str(v)])
		return Color.MAGENTA
