extends SceneTree
## Run from the repo root:
## godot --headless --path game -s res://tests/run_tests.gd
## Project autoloads (e.g. Game) are registered under /root before this script
## runs, but they are not in the global namespace as identifiers when the script
## is compiled. Tests must reach them via get_root().get_node("Game") or
## Engine.get_main_loop().root.get_node("Game").
##
## Errors fail tests. A Logger counts every engine error raised while a test
## runs. Any SCRIPT ERROR (null access, bad call...) fails the test. An ERROR
## (push_error, engine ERR_PRINT) fails it too, unless the suite lists the
## test in `const EXPECTS_ERRORS: Array[String] = ["test_name"]` because the
## test exercises an intended rejection. Warnings never fail.

const UNIT_DIR := "res://tests/unit"


## Collects errors from any thread; the runner drains it after each test.
class ErrorCounter extends Logger:
	var _lock := Mutex.new()
	var _errors: Array[String] = []
	var _script_errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var text := "%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function]
		_lock.lock()
		if error_type == ERROR_TYPE_SCRIPT:
			_script_errors.append(text)
		else:
			_errors.append(text)
		_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	## Returns [errors, script_errors] seen since the last call and clears them.
	func take() -> Array[Array]:
		_lock.lock()
		var out: Array[Array] = [_errors.duplicate(), _script_errors.duplicate()]
		_errors.clear()
		_script_errors.clear()
		_lock.unlock()
		return out


func _initialize() -> void:
	var passed := 0
	var failed := 0
	var files := _find_tests()
	if files.is_empty():
		printerr("ERROR: no test suites found in %s" % UNIT_DIR)
		quit(1)
		return
	var counter := ErrorCounter.new()
	OS.add_logger(counter)
	for file in files:
		var script := load(file) as GDScript
		if script == null or not script.can_instantiate():
			print("FAIL load %s" % file)
			failed += 1
			continue
		var suite: RefCounted = script.new()
		var expects: Array = script.get_script_constant_map().get("EXPECTS_ERRORS", [])
		var names: Array[String] = []
		for m in script.get_script_method_list():
			var method_name: String = m["name"]
			if method_name.begins_with("test_"):
				names.append(method_name)
		names.sort()
		for name in names:
			T.failures.clear()
			counter.take()
			await suite.call(name)
			var seen := counter.take()
			for e: String in seen[1]:
				T.failures.append("script error: %s" % e)
			if not expects.has(name):
				for e: String in seen[0]:
					T.failures.append("unexpected error: %s" % e)
			if T.failures.is_empty():
				passed += 1
			else:
				failed += 1
				for f in T.failures:
					print("FAIL %s::%s: %s" % [file.get_file(), name, f])
	OS.remove_logger(counter)
	print("PASS %d / FAIL %d" % [passed, failed])
	# Through Sfx: the audio server needs a moment to let go of the sounds.
	root.get_node(^"Sfx").call(&"quit_clean", 1 if failed > 0 else 0)


func _find_tests() -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(UNIT_DIR)
	if dir == null:
		return files
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append("%s/%s" % [UNIT_DIR, f])
	files.sort()
	return files
