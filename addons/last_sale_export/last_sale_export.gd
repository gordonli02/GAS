@tool
class_name LastSaleExport
extends EditorExportPlugin
## After every export, next to the game's executable:
##   packs/      the built-in data packs (packs/.gdignore keeps them out of the .pck;
##               Platform.builtin_pack_dir() reads them from here)
##   licenses/   the OFL texts of the bundled fonts and Godot's licence and
##               third-party notices, which their licences ask to travel with the game

const PACKS := "res://packs"
const FONTS := "res://assets/fonts"

var _out_dir := ""


func _get_name() -> String:
	return "LastSaleExport"


func _export_begin(_features: PackedStringArray, _is_debug: bool, path: String, _flags: int) -> void:
	_out_dir = path.get_base_dir()
	if _out_dir.is_relative_path():
		_out_dir = ProjectSettings.globalize_path("res://").path_join(_out_dir)
	# An export folder inside the project (builds/) must not be scanned by the editor:
	# it would import the copied pack files and could pull them into the next .pck.
	var root := ProjectSettings.globalize_path("res://").simplify_path()
	if _out_dir.simplify_path().begins_with(root):
		DirAccess.make_dir_recursive_absolute(_out_dir)
		# The top folder under the project (builds/), so none lands beside the game.
		var top := root.path_join(_out_dir.simplify_path().substr(root.length()).trim_prefix("/").get_slice("/", 0))
		if not FileAccess.file_exists(top.path_join(".gdignore")):
			_write(top.path_join(".gdignore"), "")


func _export_end() -> void:
	if _out_dir == "":
		return
	var packs := _out_dir.path_join("packs")
	if DirAccess.dir_exists_absolute(packs):
		_remove(packs)
	_copy_dir(ProjectSettings.globalize_path(PACKS), packs)
	var lic := _out_dir.path_join("licenses")
	DirAccess.make_dir_recursive_absolute(lic)
	for f in DirAccess.get_files_at(FONTS):
		if f.begins_with("OFL-") and f.ends_with(".txt"):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(FONTS.path_join(f)), lic.path_join(f))
	_write(lic.path_join("GODOT-LICENSE.txt"), Engine.get_license_text())
	var notices := PackedStringArray()
	for c in Engine.get_copyright_info():
		for part in c.parts:
			notices.append("%s\n  files: %s\n  %s\n  licence: %s\n" % [c.name, ", ".join(part.files), "\n  ".join(part.copyright), part.license])
	_write(lic.path_join("GODOT-THIRDPARTY.txt"), "\n".join(notices))
	print("LastSaleExport: packs and licences copied to ", _out_dir)


func _copy_dir(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	for f in DirAccess.get_files_at(from):
		if f == ".gdignore":
			continue
		DirAccess.copy_absolute(from.path_join(f), to.path_join(f))
	for d in DirAccess.get_directories_at(from):
		_copy_dir(from.path_join(d), to.path_join(d))


func _remove(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_remove(dir.path_join(d))
	DirAccess.remove_absolute(dir)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
