extends RefCounted
## Base for test files. Methods named test_* are run by run_tests.gd.

var full := false
var failures := PackedStringArray()
var notes := PackedStringArray()


func check(cond: bool, msg: String) -> bool:
	if not cond:
		failures.append(msg)
	return cond


func eq(actual, expected, msg: String) -> bool:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s: expected %s, got %s" % [msg, var_to_str(expected), var_to_str(actual)])
		return false
	return true


func note(msg: String) -> void:
	notes.append(msg)


func core_pack() -> PackDef:
	var res := PackLoader.load_dir("res://packs/core")
	if not res.ok():
		failures.append("core pack failed to load: " + "; ".join(res.errors))
		return null
	return res.pack
