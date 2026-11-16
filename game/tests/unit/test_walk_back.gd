extends RefCounted
## Walking back through the tower: the entry door returns to the previous
## room, rooms keep their state, the stairs of a floor's first room go down.

const PickupScene := preload("res://world/pickup_item.tscn")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _game() -> Node:
	return _tree().root.get_node("Game")


func _spawn() -> Dungeon:
	var d := (load(Dungeon.SCENE) as PackedScene).instantiate() as Dungeon
	_tree().root.add_child(d)
	await _wait(d, 1, 0)
	return d


## Waits up to ~3 s for the dungeon to settle in room `index` of `floor_num`.
func _wait(d: Dungeon, floor_num: int, index: int) -> bool:
	for i in 400:
		if d.current_floor == floor_num and d.room_index == index and not d._busy and d.room != null:
			return true
		await _tree().process_frame
	return false


func _frames(n: int) -> void:
	for i in n:
		await _tree().physics_frame


func _clear(d: Dungeon) -> void:
	if d.room.heal_to_clear:
		d.player.health.heal(1000.0)
	for e in d.room.enemies:
		if is_instance_valid(e) and not e.dead:
			e.health.damage(1 << 20, e.global_position)
	await _frames(2)


func _stairs(d: Dungeon) -> Stairs:
	return d.room.get_node_or_null(^"Stairs") as Stairs


func _portals(d: Dungeon) -> Array[Node]:
	return d.room.get_children().filter(func(n: Node) -> bool: return n is Portal)


## Frees the dungeon and whatever scene a leave_to_town/death put up.
func _cleanup(d: Dungeon) -> void:
	if is_instance_valid(d):
		d.free()
	await _tree().process_frame
	await _tree().process_frame
	var cur := _tree().current_scene
	if cur != null and cur != d:
		cur.free()
	_game().new_run()


func _f1_templates() -> Array[String]:
	return Dungeon.templates_for(1)


func test_back_and_forth_keeps_cleared_rooms_chests_and_items() -> void:
	_game().new_run()
	_game().run.tutorial_done = true
	var d := await _spawn()
	T.eq(d.room.back_door.is_open, false, "first room: no way back through the entry door")
	await _clear(d)
	T.ok(d.room.is_cleared, "room 0 cleared")
	if not d.chest_rooms.has(1):
		d.chest_rooms.append(1)
	d.player.global_position = d.room.exit_door.global_position
	T.ok(await _wait(d, 1, 1), "reached room 1")
	T.eq(d.room.back_door.is_open, false, "back door locked while enemies live")
	T.ok(not d.room.enemies.is_empty(), "room 1 has enemies")
	await _clear(d)
	T.ok(d.room.back_door.is_open, "back door opens with the room")
	T.ok(d.room.chest != null, "chest appeared")
	await d.room.chest.open()
	var drop := PickupScene.instantiate() as PickupItem
	drop.item_id = &"sword_iron"
	drop.position = Vector2(200, 150)
	d.room.add_child(drop)
	var stack := PickupScene.instantiate() as PickupItem
	stack.item_id = &"mat_old_leather"
	stack.qty = 3
	stack.position = Vector2(300, 60)
	d.room.add_child(stack)
	var clock_before: float = _game().run.clock.seconds
	# Back to room 0 through the entry door.
	d.player.global_position = d.room.back_door.global_position
	T.ok(await _wait(d, 1, 0), "walked back to room 0")
	T.ok(d.room.is_cleared, "room 0 still cleared")
	T.eq(d.room.enemies.size(), 0, "no respawn in room 0")
	T.ok(d.room.exit_door.is_open, "exit open on return")
	T.ok(d.player.global_position.distance_to(d.room.exit_door.global_position) < 40.0, "arrived at the exit door")
	T.ok(_stairs(d) != null, "stairs in the first room")
	T.ok(_game().run.clock.running and _game().run.clock.seconds > clock_before, "clock keeps running")
	# And forward again.
	d.player.global_position = d.room.exit_door.global_position
	T.ok(await _wait(d, 1, 1), "forward to room 1 again")
	T.ok(d.room.is_cleared, "room 1 still cleared")
	T.eq(d.room.enemies.size(), 0, "no respawn in room 1")
	T.ok(d.room.chest != null and d.room.chest.is_open, "chest stays open")
	var items := d.room.get_children().filter(func(n: Node) -> bool: return n is PickupItem)
	var found := items.filter(func(n: Node) -> bool:
		var p := n as PickupItem
		return p.item_id == &"sword_iron" and p.position == Vector2(200, 150))
	T.eq(found.size(), 1, "dropped item still on the floor")
	var stacks := items.filter(func(n: Node) -> bool:
		var p := n as PickupItem
		return p.item_id == &"mat_old_leather" and p.qty == 3 and p.position == Vector2(300, 60))
	T.eq(stacks.size(), 1, "material stack keeps its qty")
	T.ok(_stairs(d) == null, "no stairs past the first room")
	d.leave_to_town()
	await _cleanup(d)


func test_stairs_on_floor_one_go_to_town_and_stop_the_clock() -> void:
	_game().new_run()
	_game().run.tutorial_done = false
	var d := await _spawn()
	T.eq(d.room.scene_file_path, FloorPlan.TUTORIAL_ROOMS[0], "t1 first")
	var st := _stairs(d)
	T.ok(st != null, "stairs in t1")
	if st == null:
		await _cleanup(d)
		return
	T.ok(_game().run.clock.running)
	st.use()
	T.eq(_game().run.clock.running, false, "clock stops in town")
	d.free()
	await _tree().process_frame
	await _tree().process_frame
	var cur := _tree().current_scene
	T.ok(cur != null and cur.scene_file_path == Dungeon.TOWN_SCENE, "went to town")
	await _cleanup(null)


func test_stairs_on_floor_two_go_to_beaten_floor_one_boss() -> void:
	_game().new_run()
	_game().run.tutorial_done = true
	_game().run.beat_floor(1)
	var d := await _spawn()
	var plan: Array[String] = Dungeon.templates_for(2).slice(0, 4)
	plan.append("res://world/rooms/boss_f2.tscn")
	var none: Array[int] = []
	d.state.start_floor(2, plan, none)
	var f1_plan: Array[String] = d.plan.duplicate()
	d.enter_floor(2)
	T.ok(await _wait(d, 2, 0), "floor 2 first room")
	T.ok(_stairs(d) != null, "stairs on floor 2")
	_stairs(d).use()
	var last := f1_plan.size() - 1
	T.ok(await _wait(d, 1, last), "down to floor 1's last room")
	T.eq(d.plan, f1_plan, "floor 1 plan kept")
	T.ok(d.room.is_boss, "boss room")
	T.ok(d.room.is_cleared, "boss room cleared")
	T.eq(d.room.enemies.size(), 0, "boss stays dead")
	T.eq(_portals(d).size(), 2, "portals back")
	T.eq(_game().in_boss_room, false, "Q works in the beaten boss room")
	T.ok(_game().run.clock.running, "clock running")
	T.ok(d.player.global_position.distance_to(d.room.entry.global_position) < 4.0, "arrives on the entrance side")
	# The next-floor portal goes back up to floor 2's first room.
	(_portals(d)[1] as Portal).used.emit()
	T.ok(await _wait(d, 2, 0), "portal starts floor 2 at its first room")
	T.eq(d.plan, plan, "floor 2 plan kept")
	d.leave_to_town()
	await _cleanup(d)


func test_descending_to_an_unvisited_floor_builds_it_with_the_boss_beaten() -> void:
	_game().new_run()
	_game().run.tutorial_done = true
	_game().run.beat_floor(1)
	var d := await _spawn()
	d.state.reset()
	var plan: Array[String] = Dungeon.templates_for(2).slice(0, 4)
	plan.append("res://world/rooms/boss_f2.tscn")
	var none: Array[int] = []
	d.state.start_floor(2, plan, none)
	d.enter_floor(2)
	T.ok(await _wait(d, 2, 0), "floor 2 first room")
	_stairs(d).use()
	T.ok(d.state.has_floor(1), "floor 1 built at once")
	T.ok(await _wait(d, 1, d.state.get_floor(1).plan.size() - 1), "floor 1 boss room")
	T.ok(d.room.is_boss and d.room.is_cleared, "beaten boss room")
	T.eq(_portals(d).size(), 2, "portals")
	var rec := d.state.get_floor(1)
	for i in rec.rooms.size():
		T.ok(rec.rooms[i].cleared, "room %d cleared on an unvisited lower floor" % i)
		T.eq(rec.rooms[i].chests_opened.has(0), i in rec.chest_rooms, "room %d chest looted" % i)
	# Walking back from the boss room: the room before it has nobody.
	d.player.global_position = d.room.back_door.global_position
	T.ok(await _wait(d, 1, rec.plan.size() - 2), "back from the boss room")
	T.eq(d.room.enemies.size(), 0, "no enemies next to the arrival door")
	if d.room.chest != null:
		T.ok(d.room.chest.is_open, "chest shown looted")
	d.leave_to_town()
	await _cleanup(d)


func test_reentry_from_town_regenerates_the_plan() -> void:
	_game().new_run()
	_game().run.tutorial_done = true
	var d := await _spawn()
	await _clear(d)
	var old_state := d.state
	T.ok(d.state.room(1, 0).cleared, "room 0 saved as cleared")
	d.leave_to_town()
	await _cleanup(d)
	_game().run.tutorial_done = true
	d = await _spawn()
	T.ok(d.state != old_state, "new FloorState")
	T.eq(d.state.floor_count(), 1)
	T.eq(d.state.room(1, 0).cleared, false, "fresh room 0")
	d.leave_to_town()
	await _cleanup(d)


func test_quick_exit_works_but_not_in_an_unbeaten_boss_room() -> void:
	_game().new_run()
	_game().run.tutorial_done = true
	var d := await _spawn()
	await _clear(d)
	d.player.global_position = d.room.exit_door.global_position
	T.ok(await _wait(d, 1, 1))
	d.player.global_position = d.room.back_door.global_position
	await _frames(10)
	T.eq(d.room_index, 1, "back door locked: stays in room 1")
	await _clear(d)
	d.player.global_position = d.room.back_door.global_position
	T.ok(await _wait(d, 1, 0), "back in room 0")
	T.eq(_game().in_boss_room, false, "Q allowed in a revisited room")
	# Jump to the boss room: Q is blocked while the boss lives.
	d._go_to_room(d.plan.size() - 1, false)
	T.ok(await _wait(d, 1, d.plan.size() - 1))
	T.eq(_game().in_boss_room, true, "Q blocked in the boss room")
	d.player.exited.emit()
	T.eq(_game().run.clock.running, false, "Q exit stops the clock")
	await _cleanup(d)


func test_death_resets_floor_state() -> void:
	_game().new_run()
	_game().run.tutorial_done = true
	var d := await _spawn()
	await _clear(d)
	T.eq(d.state.floor_count(), 1)
	d.player.health.damage(1000, Vector2.ZERO)
	await _tree().create_timer(Dungeon.DEATH_DELAY + 0.1).timeout
	T.eq(d.state.floor_count(), 0, "floor state forgotten on death")
	await _cleanup(d)


func test_last_run_keeps_the_highest_floor_after_walking_down() -> void:
	_game().new_run()
	_game().run.tutorial_done = true
	_game().run.beat_floor(1)
	var d := await _spawn()
	var plan: Array[String] = Dungeon.templates_for(2).slice(0, 4)
	plan.append("res://world/rooms/boss_f2.tscn")
	var none: Array[int] = []
	d.state.start_floor(2, plan, none)
	d.enter_floor(2)
	T.ok(await _wait(d, 2, 0), "floor 2 first room")
	_stairs(d).use()
	T.ok(await _wait(d, 1, d.plan.size() - 1), "walked down to floor 1")
	T.eq(d.max_floor, 2, "max floor of the trip")
	d._snapshot_run()
	T.eq(_game().last_run.get("floor"), 2, "last_run keeps floor 2")
	d.leave_to_town()
	await _cleanup(d)
