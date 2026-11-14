extends RefCounted
## Floor hazards built from the layouts: ice patches on floor 2 (slow the
## walk), ember vents on floor 3 (warn red, then burn). Floor enemy
## multipliers (Difficulty.floor_*_mult).


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _game() -> Node:
	return _tree().root.get_node("Game")


func _frames(n: int) -> void:
	for i in n:
		await _tree().physics_frame


func _rooms(floor_num: int) -> Array[String]:
	return Dungeon.templates_for(floor_num)


func test_ice_only_on_floor_2_and_vents_only_on_floor_3() -> void:
	var ice_rooms := 0
	var vent_rooms := 0
	for f in [1, 2, 3]:
		for path in _rooms(f):
			var room := (load(path) as PackedScene).instantiate() as Room
			var hz := room.get_node_or_null(^"Hazards")
			var ice := hz != null and hz.has_node(^"Ice")
			var vents := 0
			if hz != null:
				for n in hz.get_children():
					if n is EmberVent:
						vents += 1
			if f != 2:
				T.ok(not ice, "%s has no ice" % path)
			if f != 3:
				T.eq(vents, 0, "%s has no vents" % path)
			ice_rooms += 1 if ice else 0
			vent_rooms += 1 if vents > 0 else 0
			room.free()
	T.eq(ice_rooms, 6, "every floor 2 room has ice")
	T.eq(vent_rooms, 6, "every floor 3 room has vents")


func test_vents_keep_clear_of_entry_exit_stairs_and_chest() -> void:
	for path in _rooms(3):
		var room := (load(path) as PackedScene).instantiate() as Room
		var keep: Array[Vector2] = [(room.get_node(^"Entry") as Node2D).position]
		for np: NodePath in [^"StairsSpot", ^"ChestSpot", ^"Exit"]:
			keep.append((room.get_node(np) as Node2D).position)
		for n in room.get_node(^"Hazards").get_children():
			if n is EmberVent:
				for k in keep:
					T.ok((n as Node2D).position.distance_to(k) >= 40.0,
							"%s %s is %.0f px from %s" % [path, n.name, (n as Node2D).position.distance_to(k), k])
		room.free()


func test_ice_slows_the_walk_and_lets_go() -> void:
	_game().new_run()
	var room := (load("res://world/rooms/f2/f2_fosso.tscn") as PackedScene).instantiate() as Room
	_tree().root.add_child(room)
	var player := (load("res://actors/player/player.tscn") as PackedScene).instantiate() as Player
	room.add_child(player)
	var ice := room.get_node(^"Hazards/Ice") as IcePatch
	var r := ice.rects()[0]
	player.position = r.get_center()
	await _frames(3)
	T.ok(player.is_slowed(), "slowed on the ice")
	player.position = room.entry.position
	await _frames(3)
	T.ok(not player.is_slowed(), "back to full speed off the ice")
	room.free()
	_game().new_run()


func test_vent_warns_then_burns_the_player_then_rests() -> void:
	_game().new_run()
	var room := (load("res://world/rooms/f3/f3_forja.tscn") as PackedScene).instantiate() as Room
	_tree().root.add_child(room)
	room.start(0, false, RandomNumberGenerator.new())
	var vent: EmberVent = null
	for n in room.get_node(^"Hazards").get_children():
		if n is EmberVent:
			vent = n
			break
	var player := (load("res://actors/player/player.tscn") as PackedScene).instantiate() as Player
	player.set_physics_process(false)
	room.add_child(player)
	# Enemies far away and frozen, so only the vent can hurt.
	for e in room.enemies:
		e.set_physics_process(false)
		e.position = Vector2(440, 40)
	player.position = vent.position - Vector2(0, 6)
	T.eq(vent.state, EmberVent.State.IDLE, "starts idle")
	vent.t = EmberVent.IDLE_TIME - 0.02
	await _frames(3)
	T.eq(vent.state, EmberVent.State.WARN, "warns first")
	T.eq(player.health.hp, player.health.max_hp, "no damage while warning")
	vent.t = EmberVent.WARN_TIME - 0.02
	await _frames(6)
	T.eq(vent.state, EmberVent.State.BURN, "then burns")
	T.ok(player.health.hp < player.health.max_hp, "the flame hurts (hp %d)" % player.health.hp)
	# A cleared room puts its vents to rest.
	for e in room.enemies:
		if is_instance_valid(e) and not e.dead:
			e.health.damage(1 << 20, e.global_position)
	await _frames(3)
	T.ok(room.is_cleared, "room cleared")
	T.eq(vent.state, EmberVent.State.IDLE, "vent rests once the room is clear")
	T.ok(not vent.dangerous())
	room.free()
	_game().new_run()


func test_floor_multipliers() -> void:
	T.near(Difficulty.floor_hp_mult(1), 1.0)
	T.near(Difficulty.floor_dmg_mult(1), 1.0)
	T.ok(Difficulty.floor_hp_mult(3) >= Difficulty.floor_hp_mult(2), "floor 3 not softer than floor 2")
	T.near(Difficulty.floor_hp_mult(9), Difficulty.floor_hp_mult(3))
	T.near(Difficulty.floor_dmg_mult(0), 1.0)
