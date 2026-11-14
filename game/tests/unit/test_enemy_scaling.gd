extends RefCounted


func _game() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Game")


func _spawn(path: String) -> EnemyBase:
	var tree := Engine.get_main_loop() as SceneTree
	var enemy := (load(path) as PackedScene).instantiate() as EnemyBase
	tree.root.add_child(enemy)
	await tree.process_frame
	return enemy


## Base hp and damage of an enemy scene (tuned in docs/balance.md), read
## from the scene instead of repeated here.
func _base(path: String) -> Vector2i:
	var e := (load(path) as PackedScene).instantiate() as EnemyBase
	var out := Vector2i(e.base_hp, e.base_damage)
	e.free()
	return out


func test_crawler_hp_scales_with_level() -> void:
	_game().new_run()
	_game().run.clock.seconds = 180.0
	var base := _base("res://actors/enemies/crawler.tscn")
	var enemy := await _spawn("res://actors/enemies/crawler.tscn")
	T.eq(enemy.health.hp, roundi(base.x * 1.3), "+10% hp per level")
	T.eq(enemy.health.max_hp, roundi(base.x * 1.3))
	T.eq(enemy.hitbox.damage, roundi(base.y * 1.24), "+8% damage per level")
	enemy.free()
	_game().new_run()


func test_level_zero_uses_base_values() -> void:
	_game().new_run()
	var shooter_base := _base("res://actors/enemies/shooter.tscn")
	var shooter := await _spawn("res://actors/enemies/shooter.tscn")
	T.eq(shooter.health.hp, shooter_base.x)
	T.eq(shooter.hitbox.damage, shooter_base.y)
	shooter.free()
	var charger_base := _base("res://actors/enemies/charger.tscn")
	var charger := await _spawn("res://actors/enemies/charger.tscn")
	T.eq(charger.health.hp, charger_base.x)
	T.eq(charger.hitbox.damage, charger_base.y)
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
