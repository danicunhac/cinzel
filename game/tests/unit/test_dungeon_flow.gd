extends RefCounted
## Plays floor 1 headless: clears every room, walks into each exit door and
## checks locks, chests and the boss reward, then leaves with Q's signal.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _game() -> Node:
	return _tree().root.get_node("Game")


func _frames(n: int) -> void:
	for i in n:
		await _tree().physics_frame


## Waits up to ~3 s of frames for the dungeon to finish a room change.
func _wait_room(d: Dungeon, index: int) -> bool:
	for i in 400:
		if d.room_index == index and not d._busy:
			return true
		await _tree().process_frame
	return false


func test_floor_one_from_tutorial_to_boss() -> void:
	_game().new_run()
	_game().run.tutorial_done = false
	var d := (load("res://world/dungeon.tscn") as PackedScene).instantiate() as Dungeon
	_tree().root.add_child(d)
	T.ok(await _wait_room(d, 0), "first room loaded")
	var chests := 0
	for i in d.plan.size():
		var room := d.room
		T.eq(room.scene_file_path, d.plan[i], "room %d" % i)
		if room.exit_door != null:
			T.eq(room.exit_door.is_open, false, "room %d locked on entry" % i)
		if room.heal_to_clear:
			T.eq(d.player.health.hp, d.player.health.max_hp / 2, "heal room halves hp")
			d.player.health.heal(1000.0)
		for e in room.enemies:
			e.health.damage(1 << 20, e.global_position)
		await _frames(2)
		T.ok(room.is_cleared, "room %d cleared" % i)
		if i in d.chest_rooms:
			T.ok(room.chest != null, "room %d has its chest" % i)
			chests += 1
		if i == d.plan.size() - 1:
			break
		T.ok(room.exit_door.is_open, "room %d open" % i)
		d.player.global_position = room.exit_door.global_position
		if not await _wait_room(d, i + 1):
			T.ok(false, "never left room %d" % i)
			break
	T.ok(chests >= 1 and chests <= 2, "1 or 2 chests, got %d" % chests)
	T.ok(_game().run.tutorial_done, "tutorial marked done")
	T.ok(d.room.is_boss, "ended in the boss room")
	T.eq(_game().run.unlocked_floors, 2, "boss unlocks floor 2")
	T.eq(_game().in_boss_room, false, "boss room flag cleared after the win")
	var portals := d.room.get_children().filter(func(n: Node) -> bool: return n is Portal)
	T.eq(portals.size(), 2, "town and next-floor portals")
	T.ok(_game().run.clock.running, "clock still running")
	d.player.exited.emit()
	T.eq(_game().run.clock.running, false, "Q exit stops the clock")
	d.free()
	await _tree().process_frame
	await _tree().process_frame
	var cur := _tree().current_scene
	T.ok(cur != null and cur.scene_file_path == Dungeon.TOWN_SCENE, "went to town")
	if cur != null:
		cur.free()
	_game().new_run()


func test_death_resets_run_and_goes_to_town() -> void:
	_game().new_run()
	_game().run.add_gold(30)
	_game().run.clock.seconds = 75.0
	(_game().last_run as Dictionary).clear()
	var d := (load("res://world/dungeon.tscn") as PackedScene).instantiate() as Dungeon
	_tree().root.add_child(d)
	await _tree().process_frame
	d.player.health.damage(1000, Vector2.ZERO)
	T.eq(_game().run.clock.running, false, "clock stops on death")
	T.eq(_game().run.gold, 30, "run reset waits for the death animation")
	await _tree().create_timer(Dungeon.DEATH_DELAY + 0.1).timeout
	T.eq(_game().run.gold, 0, "die() ran")
	T.eq(_game().last_run.get("floor"), 1, "snapshot floor")
	T.eq(_game().last_run.get("gold"), 30, "snapshot gold before die()")
	var secs: float = _game().last_run.get("seconds", -1.0)
	T.ok(secs >= 75.0 and secs < 80.0, "snapshot seconds before die(): %f" % secs)
	T.eq(_game().run.clock.seconds, 0.0, "clock zeroed after")
	d.free()
	await _tree().process_frame
	await _tree().process_frame
	var cur := _tree().current_scene
	T.ok(cur != null and cur.scene_file_path == Dungeon.TOWN_SCENE, "went to town")
	if cur != null:
		cur.free()
	_game().new_run()
