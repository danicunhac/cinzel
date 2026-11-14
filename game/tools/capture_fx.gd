extends Node
## Combat feel screenshots (Task P1). Runs a real dungeon room, swings at an
## enemy, lands a crit on another and kills a third, capturing the frames.
## godot --position 5000,5000 --path game -s res://tools/run_node.gd -- --node=res://tools/capture_fx.gd --room=res://world/rooms/f1/f1_arena.tscn --out=/abs/dir

var _out := "/tmp"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	_run.call_deferred()


func _run() -> void:
	get_tree().change_scene_to_file("res://world/dungeon.tscn")
	for i in 70:
		await get_tree().process_frame
	var d := get_tree().current_scene as Dungeon
	var player := d.player
	var enemies: Array[EnemyBase] = d.room.enemies.duplicate()
	for e in enemies:
		e.set_physics_process(false)
		e.modulate.a = 1.0
	enemies.sort_custom(func(a: EnemyBase, b: EnemyBase) -> bool: return a.position.x < b.position.x)
	var a := enemies[0]
	# 1) A normal swing on the first enemy: number, white flash, sparks.
	player.global_position = a.global_position + Vector2(-18, 0)
	player.facing = Vector2.RIGHT
	for i in 3:
		await get_tree().physics_frame
	player._start_attack()
	await _until(func() -> bool: return a.health.hp < a.health.max_hp, 40)
	await _real(0.03)
	await _shot("taskP1-hit.png")
	# 2) A crit (crafted hit) on the next enemy.
	var b := enemies[1] if enemies.size() > 1 else a
	var hb := Hitbox.new()
	hb.team = &"player"
	hb.damage = 27
	hb.crit = true
	hb.heavy = true
	d.room.add_child(hb)
	hb.global_position = b.global_position + Vector2(-10, 0)
	await _real(0.25)
	b.hurtbox.receive(hb)
	await _real(0.05)
	await _shot("taskP1-crit.png")
	# 3) Kill the last enemy: dust, shrink, then the gold flies to the HUD.
	var c := enemies[-1]
	await _real(0.5)
	var k := Hitbox.new()
	k.team = &"player"
	k.damage = c.health.hp
	d.room.add_child(k)
	k.global_position = c.global_position + Vector2(-10, 0)
	c.hurtbox.receive(k)
	await _real(0.12)
	await _shot("taskP1-death.png")
	await _real(0.5)
	await _shot("taskP1-death-shrink.png")
	# Walk onto the gold so the coin flies to the counter.
	for n in d.room.get_children():
		if n is PickupGold:
			player.global_position = (n as Node2D).global_position + Vector2(0, -2)
			break
	await _real(0.14)
	await _shot("taskP1-coin-fly.png")
	get_tree().quit(0)


func _until(cond: Callable, frames: int) -> void:
	for i in frames:
		if cond.call():
			return
		await get_tree().physics_frame


func _real(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _shot(name: String) -> void:
	await get_tree().process_frame
	var img := get_tree().root.get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(name))
	print("shot ", name)
