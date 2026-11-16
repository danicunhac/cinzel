extends RefCounted


func _game() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Game")


## Spawns a ready player under the root. Caller must pass it to _cleanup.
func _spawn() -> Player:
	var player := (load("res://actors/player/player.tscn") as PackedScene).instantiate() as Player
	(Engine.get_main_loop() as SceneTree).root.add_child(player)
	await (Engine.get_main_loop() as SceneTree).process_frame
	return player


func _cleanup(player: Player) -> void:
	player.free()
	_game().new_run()


func test_dead_player_does_not_overwrite_restored_hp() -> void:
	_game().new_run()
	var player := await _spawn()
	if player.health != null:
		player.health.damage(500, Vector2.ZERO)
		T.eq(player.state, Player.State.DEAD)
		_game().run.die()
		player._physics_process(0.016)
		player._physics_process(0.016)
		T.eq(_game().run.hp, 100)
	else:
		T.ok(false, "player ready")
	_cleanup(player)


func test_damage_writes_back_to_run() -> void:
	_game().new_run()
	var player := await _spawn()
	if player.health != null:
		player.health.damage(30, Vector2.ZERO)
		T.eq(_game().run.hp, 70)
	else:
		T.ok(false, "player ready")
	_cleanup(player)


func test_lifesteal_heal_is_written_to_run() -> void:
	_game().new_run()
	_game().run.add_item(&"fang")
	var player := await _spawn()
	if player.health != null:
		player.health.damage(50, Vector2.ZERO)
		player.invincible_time = 0.0
		player.hitbox.damage = 100
		player._on_hitbox_landed(null)
		T.eq(player.health.hp, 60)
		T.eq(_game().run.hp, 60)
	else:
		T.ok(false, "player ready")
	_cleanup(player)


func test_lowering_max_hp_clamps_health_and_run() -> void:
	_game().new_run()
	_game().run.add_item(&"stone_heart")
	_game().run.hp = 140
	var player := await _spawn()
	if player.health != null:
		T.eq(player.health.hp, 140)
		_game().run.remove_item(0)
		T.eq(player.health.max_hp, 100)
		T.eq(player.health.hp, 100)
		T.eq(_game().run.hp, 100)
	else:
		T.ok(false, "player ready")
	_cleanup(player)
