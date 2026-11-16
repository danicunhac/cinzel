extends RefCounted
## Floors 2 and 3 are real floors: the boss portal builds them from their own
## templates, their enemies take the floor multipliers and drop that floor's
## materials.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _game() -> Node:
	return _tree().root.get_node("Game")


func _wait(d: Dungeon, floor_num: int, index: int) -> bool:
	for i in 400:
		if d.current_floor == floor_num and d.room_index == index and not d._busy and d.room != null:
			return true
		await _tree().process_frame
	return false


func test_next_floor_portal_builds_floors_2_and_3() -> void:
	_game().new_run()
	_game().run.tutorial_done = true
	_game().run.beat_floor(2)
	var d := (load(Dungeon.SCENE) as PackedScene).instantiate() as Dungeon
	_tree().root.add_child(d)
	T.ok(await _wait(d, 1, 0), "floor 1")
	for f in [2, 3]:
		d._next_floor()
		T.ok(await _wait(d, f, 0), "floor %d first room" % f)
		var templates := Dungeon.templates_for(f)
		for i in d.plan.size() - 1:
			T.ok(d.plan[i] in templates, "floor %d room %d from its templates: %s" % [f, i, d.plan[i]])
		T.eq(d.plan[-1], "res://world/rooms/boss_f%d.tscn" % f)
		T.ok(d.room.has_node(^"Stairs"), "floor %d first room has stairs down" % f)
		var level: int = _game().run.clock.level()
		for e in d.room.enemies:
			T.eq(e.tower_floor(), f, "%s knows its floor" % e.name)
			var base := (load(e.scene_file_path) as PackedScene).instantiate() as EnemyBase
			T.eq(e.health.max_hp, roundi(base.base_hp * Difficulty.enemy_hp_mult(level) * Difficulty.floor_hp_mult(f)),
					"%s hp uses the floor %d multiplier" % [e.name, f])
			T.eq(e.hitbox.damage, roundi(base.base_damage * Difficulty.enemy_dmg_mult(level) * Difficulty.floor_dmg_mult(f)),
					"%s damage uses the floor %d multiplier" % [e.name, f])
			base.free()
			# Half of the kills drop a material: roll until one does.
			var drop: Array[LootDrop] = []
			for k in 40:
				drop = e.roll_loot()
				if not drop.is_empty():
					break
			T.ok(not drop.is_empty(), "%s drops something" % e.name)
			if not drop.is_empty():
				T.ok((LootTable.ENEMY_MATERIALS[f][e.loot_type()] as Array).has(drop[0].id), "%s drops a floor %d material" % [e.name, f])
	d.leave_to_town()
	d.free()
	await _tree().process_frame
	await _tree().process_frame
	var cur := _tree().current_scene
	if cur != null:
		cur.free()
	_game().new_run()


func test_floor_recipes_unlock_with_bosses() -> void:
	_game().new_run()
	var run: RunState = _game().run
	for beaten in [0, 1, 2]:
		if beaten > 0:
			run.beat_floor(beaten)
		for id: StringName in Forge.RECIPES:
			var need := int(Forge.RECIPES[id]["floors"])
			T.eq(Forge.is_unlocked(id, run.floors_beaten), need <= beaten, "%s with %d bosses beaten" % [id, beaten])
	T.ok(Forge.unlocked(2).size() > Forge.unlocked(1).size(), "boss 2 opens more recipes")
	T.ok(Forge.unlocked(1).size() > Forge.unlocked(0).size(), "boss 1 opens more recipes")
	_game().new_run()
