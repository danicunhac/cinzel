extends SceneTree
## Runs a Node script as a tool once the autoloads are in place (a -s script
## that names game classes would compile before Game, Fx and Sfx exist).
## godot --path game -s res://tools/run_node.gd -- --node=res://tools/capture_fx.gd [args]


func _initialize() -> void:
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--node="):
			path = a.substr(7)
	if path == "":
		printerr("run_node: pass --node=res://...gd")
		quit(1)
		return
	root.add_child.call_deferred((load(path) as GDScript).new())
