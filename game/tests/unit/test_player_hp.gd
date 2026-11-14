extends RefCounted


func test_dead_player_does_not_overwrite_restored_hp() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var game := root.get_node("Game")
	game.new_run()
	var player := (load("res://actors/player/player.tscn") as PackedScene).instantiate() as Player
	root.add_child(player)
	await (Engine.get_main_loop() as SceneTree).process_frame
	T.ok(player.health != null, "player ready")
	if player.health == null:
		return
	player.health.damage(500, Vector2.ZERO)
	T.eq(player.state, Player.State.DEAD)
	game.run.die()
	player._physics_process(0.016)
	player._physics_process(0.016)
	T.eq(game.run.hp, 100)
	player.free()
	game.new_run()


func test_damage_writes_back_to_run() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var game := root.get_node("Game")
	game.new_run()
	var player := (load("res://actors/player/player.tscn") as PackedScene).instantiate() as Player
	root.add_child(player)
	await (Engine.get_main_loop() as SceneTree).process_frame
	T.ok(player.health != null, "player ready")
	if player.health == null:
		return
	player.health.damage(30, Vector2.ZERO)
	T.eq(game.run.hp, 70)
	player.free()
	game.new_run()
