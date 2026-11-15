extends SceneTree
## Screenshot of a scene as the Godot editor shows it: the nodes saved in the
## .tscn, with every script removed before the scene enters the tree (in the
## editor, non-tool scripts do not run). Collision shapes and Path2D curves
## are drawn (debug hints) and Marker2D nodes get a small cross, as in the
## editor. Checks that a scene is not empty until its script builds it.
## godot --position 5000,5000 --path game -s res://tools/editor_preview.gd -- --scene=res://world/town.tscn --out=/abs/town.png
## `--zoom=N` and `--center=x,y` frame a scene that has no Camera2D (player:
## --zoom=4 --center=0,-8).

const FRAMES := 10
const MARKER_COLOR := Color(1.0, 0.3, 0.3)


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if not args.has("scene"):
		printerr("editor_preview: pass --scene=res://...tscn --out=/abs.png")
		quit(1)
		return
	_capture.call_deferred(String(args["scene"]), String(args.get("out", "/tmp/editor_preview.png")),
			float(args.get("zoom", "0")), String(args.get("center", "")))


func _capture(scene_path: String, out_path: String, zoom: float, center: String) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		printerr("editor_preview: cannot load %s" % scene_path)
		quit(1)
		return
	debug_collisions_hint = true
	debug_paths_hint = true
	var scene := packed.instantiate()
	_strip(scene)
	if scene is Node2D and not _has_camera(scene):
		var cam := Camera2D.new()
		if center != "":
			var xy := center.split(",")
			cam.position = Vector2(float(xy[0]), float(xy[1]))
		else:
			cam.position = Vector2(240, 135)
		if zoom > 0.0:
			cam.zoom = Vector2(zoom, zoom)
		scene.add_child(cam)
	root.add_child(scene)
	for i in FRAMES:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var err := img.save_png(out_path)
	print("editor_preview: %s -> %s (%d)" % [scene_path, out_path, err])
	quit(0 if err == OK else 1)


## Removes every script (and marks Marker2D nodes) below `n`.
func _strip(n: Node) -> void:
	n.set_script(null)
	if n is Marker2D:
		var cross := Line2D.new()
		cross.width = 1.0
		cross.default_color = MARKER_COLOR
		cross.points = PackedVector2Array([Vector2(-4, 0), Vector2(4, 0), Vector2(0, 0), Vector2(0, -4), Vector2(0, 4)])
		cross.z_index = 100
		n.add_child(cross)
	for c in n.get_children():
		_strip(c)


func _has_camera(n: Node) -> bool:
	if n is Camera2D:
		return true
	for c in n.get_children():
		if _has_camera(c):
			return true
	return false
