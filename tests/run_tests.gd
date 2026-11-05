extends Node
## Headless test runner, no third-party addons. Runs as a scene so autoloads exist.
##   godot --headless --path . res://tests/run_tests.tscn
##   godot --headless --path . res://tests/run_tests.tscn -- --full        (acceptance sizes)
##   godot --headless --path . res://tests/run_tests.tscn -- --only=generator
## Exit code 0 when every test passes, 1 otherwise.

const TEST_DIR := "res://tests"

var _started := false
var _errors := _ErrorLog.new()


## Any engine or script error raised while a test runs fails that test,
## even when the test itself never reaches its checks.
class _ErrorLog extends Logger:
	var lines := PackedStringArray()
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		lines.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])
		_mutex.unlock()

	func take() -> PackedStringArray:
		_mutex.lock()
		var out := lines
		lines = PackedStringArray()
		_mutex.unlock()
		return out


func _process(_dt: float) -> void:
	if _started:
		return
	_started = true
	var args := OS.get_cmdline_user_args()
	var full := args.has("--full")
	var only := ""
	for a in args:
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")

	OS.add_logger(_errors)
	var files: Array = []
	for f in DirAccess.get_files_at(TEST_DIR):
		if f.begins_with("test_") and f.ends_with(".gd") and (only == "" or f.contains(only)):
			files.append(f)
	files.sort()

	var passed := 0
	var failed := 0
	var t0 := Time.get_ticks_msec()
	for f in files:
		_errors.take()
		var script: GDScript = load(TEST_DIR.path_join(f))
		if script == null or not script.can_instantiate():
			failed += 1
			print("  FAIL  %s  (does not compile)" % f.get_basename())
			for e in _errors.take().slice(0, 6):
				print("          - " + e)
			continue
		var methods: Array = []
		for m in script.get_script_method_list():
			if m.name.begins_with("test_") and not methods.has(m.name):
				methods.append(m.name)
		for m in methods:
			var tc = script.new()
			tc.full = full
			var t1 := Time.get_ticks_msec()
			_errors.take()
			tc.call(m)
			for e in _errors.take():
				tc.failures.append("engine error: " + e)
			var ms := Time.get_ticks_msec() - t1
			if tc.failures.is_empty():
				passed += 1
				print("  ok    %s.%s  (%d ms)" % [f.get_basename(), m, ms])
			else:
				failed += 1
				print("  FAIL  %s.%s  (%d ms)" % [f.get_basename(), m, ms])
				for msg in tc.failures.slice(0, 12):
					print("          - " + msg)
				if tc.failures.size() > 12:
					print("          ... %d more" % (tc.failures.size() - 12))
			for line in tc.notes:
				print("          " + line)
	print("\n%d passed, %d failed, %.1f s%s" % [passed, failed, (Time.get_ticks_msec() - t0) / 1000.0, " (full)" if full else ""])
	get_tree().quit(1 if failed > 0 or passed == 0 else 0)
