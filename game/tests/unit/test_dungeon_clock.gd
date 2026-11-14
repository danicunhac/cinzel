extends RefCounted


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _game() -> Node:
	return _tree().root.get_node("Game")


func _spawn_dungeon() -> Dungeon:
	var d := (load("res://world/dungeon.tscn") as PackedScene).instantiate() as Dungeon
	_tree().root.add_child(d)
	await _tree().process_frame
	return d


## leave_to_town changes scene; drop the town it adds so later tests start clean.
func _cleanup(d: Dungeon) -> void:
	if is_instance_valid(d):
		d.free()
	await _tree().process_frame
	await _tree().process_frame
	var cur := _tree().current_scene
	if cur != null and cur.scene_file_path == Dungeon.TOWN_SCENE:
		cur.free()
	_game().new_run()


func test_ready_starts_clock_and_leave_stops_it() -> void:
	_game().new_run()
	_game().run.clock.running = false
	var d := await _spawn_dungeon()
	T.eq(_game().run.clock.running, true, "running after _ready")
	d.leave_to_town()
	T.eq(_game().run.clock.running, false, "running after leave_to_town")
	T.eq(_game().in_boss_room, false)
	await _cleanup(d)


func test_clock_ticks_only_while_not_paused() -> void:
	_game().new_run()
	var d := await _spawn_dungeon()
	var before: float = _game().run.clock.seconds
	for i in 5:
		await _tree().process_frame
	var ticked: float = _game().run.clock.seconds
	T.ok(ticked > before, "clock advanced in the dungeon")
	_tree().paused = true
	for i in 5:
		await _tree().process_frame
	T.near(_game().run.clock.seconds, ticked)
	_tree().paused = false
	d.leave_to_town()
	await _cleanup(d)


func test_first_floor_plan_starts_with_tutorial_and_ends_with_boss() -> void:
	_game().new_run()
	_game().run.tutorial_done = false
	var d := await _spawn_dungeon()
	T.eq(d.plan.slice(0, 3), FloorPlan.TUTORIAL_ROOMS)
	T.eq(d.plan[-1], "res://world/rooms/boss_f1.tscn")
	T.ok(d.plan.size() >= 8 and d.plan.size() <= 9, "3 + 4..5 + boss")
	for i in d.chest_rooms:
		T.ok(i >= 3 and i < d.plan.size() - 1, "chest in a random room: %d" % i)
	T.eq(d.room_index, 0)
	T.eq(d.room.scene_file_path, FloorPlan.TUTORIAL_ROOMS[0])
	d.leave_to_town()
	await _cleanup(d)


func test_finished_tutorial_is_skipped_until_death() -> void:
	_game().new_run()
	_game().run.tutorial_done = true
	var d := await _spawn_dungeon()
	T.ok(not d.plan.has(FloorPlan.TUTORIAL_ROOMS[0]), "no tutorial once done in this run")
	d.leave_to_town()
	await _cleanup(d)
	_game().run.tutorial_done = true
	_game().run.die()
	d = await _spawn_dungeon()
	T.eq(d.plan.slice(0, 3), FloorPlan.TUTORIAL_ROOMS, "tutorial again after death")
	d.leave_to_town()
	await _cleanup(d)
