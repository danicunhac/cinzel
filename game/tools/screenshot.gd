extends Node
## Autoload. Inactive unless user args contain --screenshot=<res path>.
## godot --path game -- --screenshot=res://x.tscn --out=/abs/file.png --frames=60


func _ready() -> void:
	var args := _parse_args()
	if not args.has("screenshot"):
		return
	_capture(args["screenshot"], args.get("out", "/tmp/cinzel.png"), int(args.get("frames", "60")))


func _parse_args() -> Dictionary:
	var result := {}
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			continue
		var kv := a.substr(2).split("=", true, 1)
		result[kv[0]] = kv[1] if kv.size() > 1 else ""
	return result


func _capture(scene_path: String, out_path: String, frames: int) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("screenshot: cannot load %s" % scene_path)
		get_tree().quit(1)
		return
	var current := get_tree().current_scene
	if current != null:
		current.queue_free()
	var scene := packed.instantiate()
	get_tree().root.add_child.call_deferred(scene)
	for i in frames:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var err := img.save_png(out_path)
	if err != OK:
		push_error("screenshot: save failed %d" % err)
	Sfx.quit_clean(0 if err == OK else 1)
