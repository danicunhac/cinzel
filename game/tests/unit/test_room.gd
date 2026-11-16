extends RefCounted


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _game() -> Node:
	return _tree().root.get_node("Game")


func _room(path: String) -> Room:
	var r := (load(path) as PackedScene).instantiate() as Room
	_tree().root.add_child(r)
	await _tree().process_frame
	return r


func _kill(e: EnemyBase) -> void:
	e.health.damage(99999, e.global_position)


func test_exit_stays_locked_until_every_enemy_dies() -> void:
	_game().new_run()
	var room := await _room("res://world/rooms/f1/f1_colunas.tscn")
	var fired: Array[int] = [0]
	room.cleared.connect(func() -> void: fired[0] += 1)
	room.start(0, false, RandomNumberGenerator.new())
	T.eq(room.enemies.size(), 3)
	T.eq(room.exit_door.is_open, false, "locked at start")
	_kill(room.enemies[0])
	_kill(room.enemies[1])
	await _tree().process_frame
	T.eq(fired[0], 0, "cleared before the last kill")
	T.eq(room.exit_door.is_open, false, "locked with one enemy left")
	T.eq(room.walls.get_cell_atlas_coords(room.walls.local_to_map(room.exit_door.position)), RoomTiles.DOOR_LOCKED)
	_kill(room.enemies[2])
	T.eq(fired[0], 1, "cleared once")
	T.ok(room.exit_door.is_open, "open after the last kill")
	T.eq(room.walls.get_cell_atlas_coords(room.walls.local_to_map(room.exit_door.position)), RoomTiles.DOOR_OPEN)
	room.free()


func test_extra_enemies_and_chest_on_clear() -> void:
	_game().new_run()
	var room := await _room("res://world/rooms/f1/f1_arena.tscn")
	room.start(1, true, RandomNumberGenerator.new())
	T.eq(room.enemies.size(), 4, "3 markers + 1 extra")
	for e in room.enemies:
		T.ok(e.position.distance_to(room.entry.position) >= Room.EXTRA_MIN_DIST - 6.0, "no spawn near entry")
	T.eq(room.chest, null, "no chest before clear")
	for e in room.enemies:
		_kill(e)
	T.eq(room.chest, null, "chest made in a deferred call")
	await (Engine.get_main_loop() as SceneTree).process_frame
	T.ok(room.chest != null and room.chest.is_inside_tree(), "chest after clear")
	room.free()


func test_room_freed_before_the_chest_call_leaks_nothing() -> void:
	_game().new_run()
	var room := await _room("res://world/rooms/f1/f1_arena.tscn")
	room.start(0, true, RandomNumberGenerator.new())
	# Counted before the kills: an eagerly made chest would be an orphan
	# from the last kill on.
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for e in room.enemies:
		_kill(e)
	T.eq(room.chest, null, "no chest until the deferred call")
	room.free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	T.eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before, "no orphan chest")


func test_tutorial_rooms_get_no_extra_enemies() -> void:
	_game().new_run()
	var room := await _room("res://world/rooms/tutorial/t1_move_attack.tscn")
	room.start(1, false, RandomNumberGenerator.new())
	T.eq(room.enemies.size(), 1)
	room.free()


func test_heal_room_opens_when_hp_is_full() -> void:
	_game().new_run()
	T.eq(_tree().paused, false, "tree not paused at start")
	T.eq(_tree().get_nodes_in_group(&"player").size(), 0, "no leaked player before the test adds one")
	var player := (load("res://actors/player/player.tscn") as PackedScene).instantiate() as Player
	_tree().root.add_child(player)
	T.eq(_tree().get_nodes_in_group(&"player").size(), 1, "exactly one player")
	var room := await _room("res://world/rooms/tutorial/t3_heal.tscn")
	room.start(0, false, RandomNumberGenerator.new())
	T.eq(player.health.hp, 50, "starts at 50%")
	T.eq(_game().run.hp, 50, "run hp synced")
	await _tree().process_frame
	T.eq(room.is_cleared, false, "locked while hurt")
	player.health.heal(50.0)
	await _tree().process_frame
	T.ok(room.is_cleared, "cleared at full hp")
	T.ok(room.exit_door.is_open, "door open")
	room.free()
	player.free()
	_game().new_run()


func test_templates_follow_layout_rules() -> void:
	for f in [1, 2, 3]:
		var templates := Dungeon.templates_for(f)
		T.eq(templates.size(), 6, "floor %d templates" % f)
		for path in templates:
			var room := (load(path) as PackedScene).instantiate() as Room
			T.ok(room.has_node(^"Exit") and room.has_node(^"ChestSpot"), "%s exit and chest spot" % path)
			T.ok(room.has_node(^"StairsSpot"), "%s stairs spot (any room can open a floor)" % path)
			var entry := (room.get_node(^"Entry") as Marker2D).position
			var n := 0
			for m in room.get_node(^"Spawns").get_children():
				n += 1
				var d := (m as Marker2D).position.distance_to(entry)
				T.ok(d >= Room.EXTRA_MIN_DIST, "%s spawn %s at %.0f px from entry" % [path, m.name, d])
				# Row 1 sits under the painted top wall face.
				T.ok((m as Marker2D).position.y >= 32.0, "%s spawn %s under the top wall" % [path, m.name])
			T.ok((room.get_node(^"ChestSpot") as Marker2D).position.y >= 32.0, "%s chest under the top wall" % path)
			T.ok(n >= 3, "%s has %d enemies" % [path, n])
			if f >= 2:
				var kinds := {}
				for m in room.get_node(^"Spawns").get_children():
					kinds[m.get_meta(&"enemy")] = true
				T.ok(kinds.has("shooter"), "%s has a sentinel" % path)
			room.free()


## Floor 2 rooms carry more sentinels than floor 1; floor 3 mixes all three.
func test_floor_enemy_mix() -> void:
	var shooters: Array[float] = []
	for f in [1, 2, 3]:
		var count := 0
		var total := 0
		var kinds := {}
		for path in Dungeon.templates_for(f):
			var room := (load(path) as PackedScene).instantiate() as Room
			for m in room.get_node(^"Spawns").get_children():
				total += 1
				kinds[m.get_meta(&"enemy")] = true
				if m.get_meta(&"enemy") == "shooter":
					count += 1
			room.free()
		shooters.append(float(count) / float(total))
		if f == 3:
			T.eq(kinds.size(), 3, "floor 3 uses all three enemy kinds")
	T.ok(shooters[1] > shooters[0], "floor 2 has more sentinels (%.2f vs %.2f)" % [shooters[1], shooters[0]])
