extends RefCounted
## HUD kit logic: heart beat rate, gold count-up, new-item ring.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _game() -> Node:
	return _tree().root.get_node("Game")


func test_heart_beats_faster_under_30_percent() -> void:
	T.eq(Hud.heart_period(100, 100), Hud.BEAT_SLOW, "full life: slow beat")
	T.eq(Hud.heart_period(30, 100), Hud.BEAT_SLOW, "30% is not low yet")
	T.eq(Hud.heart_period(29, 100), Hud.BEAT_FAST, "under 30%: fast beat")
	T.eq(Hud.heart_period(1, 100), Hud.BEAT_FAST)
	T.eq(Hud.heart_period(0, 100), 0.0, "dead: no beat")
	T.ok(Hud.BEAT_FAST < Hud.BEAT_SLOW, "fast is faster")


func test_heart_frame_beats_then_rests() -> void:
	T.eq(Hud.heart_frame(0.0), 1, "beat starts swelling")
	T.eq(Hud.heart_frame(Hud.BEAT_TIME * 0.6), 3)
	T.eq(Hud.heart_frame(Hud.BEAT_TIME), 0, "rest after the beat")
	T.eq(Hud.heart_frame(0.9), 0)


func test_gold_count_up_reaches_target_without_overshoot() -> void:
	var shown := 0.0
	var steps := 0
	while shown != 137.0 and steps < 600:
		var next := Hud.count_step(shown, 137, 1.0 / 60.0)
		T.ok(next >= shown and next <= 137.0, "monotonic, never past the target")
		shown = next
		steps += 1
	T.eq(shown, 137.0, "lands on the target")
	T.ok(steps < 60, "a 137 gain lands in under a second (%d frames)" % steps)
	T.eq(Hud.count_step(5.0, 5, 0.016), 5.0, "at rest stays put")


func test_hud_counts_gold_and_rings_new_item() -> void:
	_game().new_run()
	var town := (load("res://world/town.tscn") as PackedScene).instantiate()
	_tree().root.add_child(town)
	await _tree().process_frame
	var hud := town.get_node("Hud") as Hud
	T.eq(hud.rings_played, [] as Array[int], "no ring at start")
	_game().run.add_gold(25)
	await _tree().process_frame
	T.ok(hud.gold_shown < 25.0, "counter starts below the new total")
	for i in 90:
		await _tree().process_frame
	T.eq(hud.gold_shown, 25.0, "counter reached the gold")
	T.eq(hud.gold_label.text, "25")
	_game().run.add_item(&"fang")
	await _tree().process_frame
	T.eq(hud.rings_played, [0] as Array[int], "ring on the slot that got the item")
	T.ok(hud.slot_icons[0].texture != null, "icon shown")
	_game().run.add_item(&"spark")
	await _tree().process_frame
	T.eq(hud.rings_played, [0, 1] as Array[int], "second item rings its own slot")
	town.free()
	_game().new_run()


func test_exit_bar_fill_and_tip() -> void:
	_game().new_run()
	var hud := (load("res://ui/hud.tscn") as PackedScene).instantiate() as Hud
	_tree().root.add_child(hud)
	await _tree().process_frame
	hud._on_exit_progress(0.5)
	var inner := Hud.EXIT_SIZE.x - Hud.HP_MARGIN.x - Hud.HP_MARGIN.z
	T.eq(hud.exit_box.visible, true)
	T.eq(hud.exit_fill.size.x, roundf(inner * 0.5), "half full")
	T.ok(hud.exit_tip.visible, "light pulse rides the fill end")
	T.eq(hud.exit_tip.position.x, hud.exit_fill.size.x + hud.exit_fill.position.x - 2)
	hud._on_exit_progress(0.0)
	T.eq(hud.exit_box.visible, false)
	hud.free()
