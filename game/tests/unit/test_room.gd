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
	T.ok(room.chest != null, "chest after clear")
	room.free()


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
	var templates := Dungeon.templates_for(1)
	T.eq(templates.size(), 6)
	for path in templates:
		var room := (load(path) as PackedScene).instantiate() as Room
		T.ok(room.has_node(^"Exit") and room.has_node(^"ChestSpot"), "%s exit and chest spot" % path)
		var n := 0
		for m in room.get_node(^"Spawns").get_children():
			n += 1
			var d := (m as Marker2D).position.distance_to((room.get_node(^"Entry") as Marker2D).position)
			T.ok(d >= Room.EXTRA_MIN_DIST, "%s spawn %s at %.0f px from entry" % [path, m.name, d])
		T.ok(n >= 3, "%s has %d enemies" % [path, n])
		room.free()
