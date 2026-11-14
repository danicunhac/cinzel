extends RefCounted


func _game() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Game")


func _spawn(path: String) -> EnemyBase:
	var tree := Engine.get_main_loop() as SceneTree
	var enemy := (load(path) as PackedScene).instantiate() as EnemyBase
	tree.root.add_child(enemy)
	await tree.process_frame
	return enemy


func test_crawler_hp_scales_with_level() -> void:
	_game().new_run()
	_game().run.clock.seconds = 180.0
	var enemy := await _spawn("res://actors/enemies/crawler.tscn")
	T.eq(enemy.health.hp, 39)
	T.eq(enemy.health.max_hp, 39)
	T.eq(enemy.hitbox.damage, roundi(10 * 1.24))
	enemy.free()
	_game().new_run()


func test_level_zero_uses_base_values() -> void:
	_game().new_run()
	var shooter := await _spawn("res://actors/enemies/shooter.tscn")
	T.eq(shooter.health.hp, 20)
	T.eq(shooter.hitbox.damage, 8)
	shooter.free()
	var charger := await _spawn("res://actors/enemies/charger.tscn")
	T.eq(charger.health.hp, 40)
	T.eq(charger.hitbox.damage, 15)
	T.eq(charger.hitbox.team, &"enemy")
	charger.free()


func test_gold_drop_uses_gold_mult_and_killed_signal() -> void:
	_game().new_run()
	_game().run.clock.seconds = 120.0
	var tree := Engine.get_main_loop() as SceneTree
	var holder := Node2D.new()
	tree.root.add_child(holder)
	var enemy := (load("res://actors/enemies/charger.tscn") as PackedScene).instantiate() as EnemyBase
	holder.add_child(enemy)
	await tree.process_frame
	var killed: Array[bool] = [false]
	enemy.killed.connect(func() -> void: killed[0] = true)
	T.eq(enemy.gold_amount(), roundi(10 * 1.10))
	enemy.health.damage(9999, Vector2.ZERO)
	await tree.process_frame
	await tree.process_frame
	T.ok(killed[0], "killed emitted")
	var golds := holder.get_children().filter(func(n: Node) -> bool: return n is PickupGold)
	T.eq(golds.size(), 1)
	if golds.size() == 1:
		T.eq((golds[0] as PickupGold).amount, 11)
	holder.free()
	_game().new_run()
