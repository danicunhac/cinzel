extends RefCounted
## Bosses: BossFinal phases and summons, BossBig scaling and shockwave,
## boss_hp signal, boss rooms clearing.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _game() -> Node:
	return _tree().root.get_node("Game")


func _add(node: Node) -> void:
	_tree().root.add_child(node)
	await _tree().process_frame


func _final() -> BossFinal:
	var boss := (load("res://actors/bosses/boss_final.tscn") as PackedScene).instantiate() as BossFinal
	await _add(boss)
	return boss


func _big(base: String) -> BossBig:
	var boss := (load("res://actors/bosses/boss_big.tscn") as PackedScene).instantiate() as BossBig
	boss.base = load(base) as PackedScene
	await _add(boss)
	return boss


## Damages the boss down to `pct` percent of its max HP (rounded down).
func _set_hp_pct(boss: EnemyBase, pct: int) -> void:
	var target := boss.health.max_hp * pct / 100
	boss.health.damage(boss.health.hp - target, Vector2.ZERO)


func test_final_boss_phase_two_at_49_percent() -> void:
	_game().new_run()
	var boss := await _final()
	T.eq(boss.phase, 1, "starts in phase 1")
	_set_hp_pct(boss, 51)
	T.eq(boss.phase, 1, "51% stays in phase 1")
	_set_hp_pct(boss, 49)
	T.eq(boss.phase, 2, "49% is phase 2")
	T.near(boss.speed_mult(), 1.2)
	boss.free()


func test_final_boss_summons_two_crawlers_in_phase_two_and_they_die_with_it() -> void:
	_game().new_run()
	var holder := Node2D.new()
	await _add(holder)
	var boss := (load("res://actors/bosses/boss_final.tscn") as PackedScene).instantiate() as BossFinal
	boss.position = Vector2(160, 88)
	holder.add_child(boss)
	await _tree().process_frame
	boss._think(0.1)
	T.eq(boss.minions.size(), 0, "no summons in phase 1")
	_set_hp_pct(boss, 49)
	boss._think(0.1)
	T.eq(boss.minions.size(), 2, "2 crawlers on entering phase 2")
	boss._think(BossFinal.SUMMON_INTERVAL - 1.0)
	T.eq(boss.minions.size(), 2, "none before 8 s")
	boss._think(1.1)
	T.eq(boss.minions.size(), 4, "2 more after 8 s")
	boss.health.damage(99999, Vector2.ZERO)
	for m in boss.minions:
		T.ok(m.dead, "minion dies with the boss")
	holder.free()
	_game().new_run()


func test_final_boss_fires_a_fan() -> void:
	_game().new_run()
	var holder := Node2D.new()
	await _add(holder)
	var boss := (load("res://actors/bosses/boss_final.tscn") as PackedScene).instantiate() as BossFinal
	holder.add_child(boss)
	await _tree().process_frame
	boss.fire_fan(Vector2.RIGHT)
	var shots := holder.get_children().filter(func(n: Node) -> bool: return n is Projectile)
	T.eq(shots.size(), BossFinal.FAN_SHOTS)
	holder.free()


func test_big_boss_scales_base_hp_by_8_and_level() -> void:
	_game().new_run()
	_game().run.clock.seconds = 180.0
	var crawler_boss := await _big("res://actors/enemies/crawler.tscn")
	T.eq(crawler_boss.health.max_hp, roundi(30 * 8 * Difficulty.enemy_hp_mult(3)), "crawler x8 at level 3")
	T.eq(crawler_boss.health.hp, crawler_boss.health.max_hp)
	T.eq(crawler_boss.hitbox.damage, roundi(10 * Difficulty.enemy_dmg_mult(3)))
	T.eq(crawler_boss.dashes, false)
	T.eq(crawler_boss.sprite.scale, Vector2(2, 2), "drawn at x2")
	crawler_boss.free()
	_game().new_run()
	var charger_boss := await _big("res://actors/enemies/charger.tscn")
	T.eq(charger_boss.health.max_hp, 40 * 8, "charger x8 at level 0")
	T.eq(charger_boss.dashes, true)
	T.ok(charger_boss.is_in_group(&"boss"), "in group boss")
	charger_boss.free()


func test_big_boss_shockwave_warns_for_0_8_s_then_hits() -> void:
	_game().new_run()
	var player := (load("res://actors/player/player.tscn") as PackedScene).instantiate() as Player
	player.set_physics_process(false)
	await _add(player)
	var boss := await _big("res://actors/enemies/crawler.tscn")
	boss.set_physics_process(false)
	player.global_position = boss.global_position + Vector2(40, 0)
	var wave := boss.shockwave
	var hp_before := player.health.hp
	boss._start_shock()
	T.eq(boss.state, BossBig.State.SHOCK)
	wave._physics_process(0.79)
	T.ok(wave.warning, "still warning at 0.79 s")
	T.eq(player.health.hp, hp_before, "no damage during the warning")
	for i in 30:
		wave._physics_process(0.02)
	T.ok(not wave.warning, "warning over")
	T.ok(player.health.hp < hp_before, "ring hit the player")
	T.eq(boss.state, BossBig.State.RECOVER, "boss recovers after the ring")
	boss.free()
	player.free()
	_game().new_run()


func test_boss_hp_signal_on_spawn_and_damage() -> void:
	_game().new_run()
	var got: Array[Vector2i] = []
	var boss := (load("res://actors/bosses/boss_final.tscn") as PackedScene).instantiate() as BossFinal
	boss.boss_hp.connect(func(hp: int, max_hp: int) -> void: got.append(Vector2i(hp, max_hp)))
	await _add(boss)
	T.eq(got.size(), 1, "emitted on spawn")
	T.eq(got[0], Vector2i(420, 420))
	boss.health.damage(20, Vector2.ZERO)
	T.eq(got.size(), 2, "emitted on damage")
	T.eq(got[-1], Vector2i(400, 420))
	boss.free()
	var big_got: Array[int] = []
	var big := (load("res://actors/bosses/boss_big.tscn") as PackedScene).instantiate() as BossBig
	big.boss_hp.connect(func(hp: int, _max_hp: int) -> void: big_got.append(hp))
	await _add(big)
	big.health.damage(5, Vector2.ZERO)
	T.eq(big_got, [240, 235] as Array[int])
	big.free()


func test_killing_each_boss_clears_its_room() -> void:
	for f in [1, 2, 3]:
		_game().new_run()
		var room := (load("res://world/rooms/boss_f%d.tscn" % f) as PackedScene).instantiate() as Room
		await _add(room)
		var fired: Array[int] = [0]
		room.cleared.connect(func() -> void: fired[0] += 1)
		room.start(3, false, RandomNumberGenerator.new())
		T.eq(room.enemies.size(), 1, "floor %d: only the boss" % f)
		var boss := room.enemies[0]
		T.ok(boss.is_in_group(&"boss"), "floor %d: boss in group" % f)
		T.ok(boss is BossFinal if f == 3 else boss is BossBig, "floor %d: boss type" % f)
		if boss is BossBig:
			T.eq((boss as BossBig).dashes, f == 2, "floor %d: base" % f)
		T.eq(fired[0], 0)
		boss.health.damage(1 << 20, boss.global_position)
		T.eq(fired[0], 1, "floor %d: cleared on boss death" % f)
		room.free()
	_game().new_run()
