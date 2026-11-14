extends RefCounted
## The run clock stays frozen in town, in the town panels, in the pause menu
## and on the end screens; it only runs in the tower when not paused.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _game() -> Node:
	return _tree().root.get_node("Game")


func _frames(n: int) -> void:
	for i in n:
		await _tree().process_frame


func _spawn(path: String) -> Node:
	var n := (load(path) as PackedScene).instantiate()
	_tree().root.add_child(n)
	await _tree().process_frame
	return n


func test_clock_frozen_in_town() -> void:
	_game().new_run()
	_game().run.clock.seconds = 100.0
	_game().run.clock.running = true
	var town := await _spawn("res://world/town.tscn")
	await _frames(60)
	T.near(_game().run.clock.seconds, 100.0, 0.01)
	T.eq(_game().run.clock.running, false, "town stops the clock")
	town.free()
	_game().new_run()


func test_clock_frozen_with_town_panel_open() -> void:
	_game().new_run()
	_game().run.clock.seconds = 100.0
	var town := await _spawn("res://world/town.tscn")
	for id: StringName in [&"shop", &"smith", &"teleport"]:
		var panel: UiPanel = town.open_panel(id)
		T.ok(panel != null and panel.is_open(), "%s panel opens" % id)
		T.eq(_tree().paused, true, "%s panel pauses" % id)
		await _frames(10)
		panel.close()
		T.eq(_tree().paused, false, "%s panel unpauses" % id)
		await _frames(1)
	T.near(_game().run.clock.seconds, 100.0, 0.01)
	town.free()
	_game().new_run()


func test_pause_menu_freezes_dungeon_clock() -> void:
	_game().new_run()
	var d := await _spawn("res://world/dungeon.tscn") as Dungeon
	var pause := d.get_node("Pause") as PauseMenu
	await _frames(3)
	pause.open()
	T.eq(_tree().paused, true, "pause menu pauses the tree")
	var frozen: float = _game().run.clock.seconds
	await _frames(30)
	T.near(_game().run.clock.seconds, frozen)
	T.ok(d.get_node("Hud").can_process(), "HUD still processes while paused")
	pause.close()
	T.eq(_tree().paused, false)
	await _frames(5)
	T.ok(_game().run.clock.seconds > frozen, "clock runs again after closing")
	d.leave_to_town()
	d.free()
	await _frames(2)
	var cur := _tree().current_scene
	if cur != null and cur.scene_file_path == Dungeon.TOWN_SCENE:
		cur.free()
	_game().new_run()


func test_end_screens_keep_clock_stopped() -> void:
	for path: String in ["res://ui/game_over.tscn", "res://ui/victory.tscn", "res://ui/credits.tscn", "res://ui/title.tscn"]:
		_game().new_run()
		_game().run.clock.seconds = 42.0
		_game().run.clock.running = true
		var s := await _spawn(path)
		await _frames(10)
		T.near(_game().run.clock.seconds, 42.0, 0.01)
		T.eq(_game().run.clock.running, false, "%s stops the clock" % path)
		s.free()
	_game().new_run()
