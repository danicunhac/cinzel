extends SceneTree
## Run from the repo root:
## godot --headless --path game -s res://tests/run_tests.gd
## Project autoloads (e.g. Game) are registered under /root before this script
## runs, but they are not in the global namespace as identifiers when the script
## is compiled. Tests must reach them via get_root().get_node("Game") or
## Engine.get_main_loop().root.get_node("Game").

const UNIT_DIR := "res://tests/unit"


func _initialize() -> void:
	var passed := 0
	var failed := 0
	for file in _find_tests():
		var script := load(file) as GDScript
		if script == null:
			print("FAIL load %s" % file)
			failed += 1
			continue
		var suite: RefCounted = script.new()
		for m in suite.get_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			T.failures.clear()
			suite.call(name)
			if T.failures.is_empty():
				passed += 1
			else:
				failed += 1
				for f in T.failures:
					print("FAIL %s::%s: %s" % [file.get_file(), name, f])
	print("PASS %d / FAIL %d" % [passed, failed])
	quit(1 if failed > 0 else 0)


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
