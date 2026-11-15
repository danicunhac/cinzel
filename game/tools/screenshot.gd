extends Node
## Autoload. Inactive unless user args contain --screenshot=<res path>.
## godot --path game -- --screenshot=res://x.tscn --out=/abs/file.png --frames=60
## `--hit=<dmg>` (optional): HIT_LEAD frames before the capture the first
## enemy takes a player hit of <dmg> (checks damage numbers and flashes).
## `--smash=<n>` (optional): n frames before the capture the first breakable
## pot or crate of the room is smashed by a player hit, with coins (checks the
## break animation and the drop).

const HIT_LEAD := 8


func _ready() -> void:
	var args := _parse_args()
	if not args.has("screenshot"):
		return
	_capture(args["screenshot"], args.get("out", "/tmp/cinzel.png"), int(args.get("frames", "60")),
			int(args.get("hit", "0")), int(args.get("smash", "0")))


func _parse_args() -> Dictionary:
	var result := {}
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			continue
		var kv := a.substr(2).split("=", true, 1)
		result[kv[0]] = kv[1] if kv.size() > 1 else ""
	return result


func _capture(scene_path: String, out_path: String, frames: int, hit: int = 0, smash: int = 0) -> void:
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
		if hit > 0 and i == maxi(frames - HIT_LEAD, 0):
			_hit_first_enemy(hit)
		if smash > 0 and i == maxi(frames - smash, 0):
			_smash_first_prop()
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var err := img.save_png(out_path)
	if err != OK:
		push_error("screenshot: save failed %d" % err)
	Sfx.quit_clean(0 if err == OK else 1)


func _hit_first_enemy(dmg: int) -> void:
	var enemies := get_tree().get_nodes_in_group(&"enemy")
	if enemies.is_empty():
		push_warning("screenshot: --hit found no enemy")
		return
	var e := enemies[0] as EnemyBase
	var h := Hitbox.new()
	h.damage = dmg
	h.team = &"player"
	add_child(h)
	h.global_position = e.global_position
	e._on_hit(h)
	h.queue_free()


func _smash_first_prop() -> void:
	var props := get_tree().root.find_children("*", "StaticBody2D", true, false).filter(
			func(n: Node) -> bool: return n is Breakable)
	if props.is_empty():
		push_warning("screenshot: --smash found no breakable")
		return
	var b := props[0] as Breakable
	b.gold_chance = 1.0
	var h := Hitbox.new()
	h.team = &"player"
	add_child(h)
	b.hurtbox.receive(h)
	h.queue_free()
