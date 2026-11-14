extends RefCounted
## Fx autoload: the hit-stop always gives time back, numbers and bursts free
## themselves.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _fx() -> Node:
	return _tree().root.get_node("Fx")


func _c(name: String) -> Variant:
	return _fx().get_script().get_script_constant_map()[name]


func _wait_real(seconds: float) -> void:
	await _tree().create_timer(seconds, true, false, true).timeout


func test_hit_stop_returns_time_scale_to_one() -> void:
	var fx := _fx()
	fx.hit_stop(3)
	T.ok(Engine.time_scale < 1.0, "time slows during the stop")
	T.ok(fx.is_stopped(), "is_stopped")
	await _wait_real(0.15)
	T.eq(Engine.time_scale, 1.0, "back to 1 after 3 frames")


func test_overlapping_stops_end_once() -> void:
	var fx := _fx()
	fx.hit_stop(3)
	fx.hit_stop(5)
	await _wait_real(0.06)
	T.ok(Engine.time_scale < 1.0, "the longer stop still holds after the short one")
	await _wait_real(0.15)
	T.eq(Engine.time_scale, 1.0)


func test_hit_stop_ends_while_paused() -> void:
	var fx := _fx()
	_tree().paused = true
	fx.hit_stop(5)
	await _wait_real(0.2)
	T.eq(Engine.time_scale, 1.0, "the stop timer runs while paused")
	_tree().paused = false


func test_reset_on_scene_change_restores_time() -> void:
	var fx := _fx()
	fx.hit_stop(30)
	T.ok(Engine.time_scale < 1.0)
	# Game.goto calls Fx.reset before changing scene.
	fx.reset()
	T.eq(Engine.time_scale, 1.0, "reset gives time back at once")
	await _wait_real(0.6)
	T.eq(Engine.time_scale, 1.0, "the old timer does not slow anything later")


func test_safety_net_restores_time_without_timer() -> void:
	var fx := _fx()
	# A stop whose timer was lost (freed tree, scene swap): _process ends it.
	Engine.time_scale = _c("STOP_SCALE")
	fx.set(&"_stop_left", 0.03)
	await _wait_real(0.3)
	T.eq(Engine.time_scale, 1.0)


func test_number_spawns_and_frees() -> void:
	var fx := _fx()
	var l: Label = fx.number(Vector2(100, 100), 12, Color.WHITE)
	T.ok(l != null and l.is_inside_tree(), "label in the tree")
	T.eq(l.text, "12")
	var c: Label = fx.number(Vector2(100, 100), 30, Color.YELLOW, true)
	T.eq(c.text, "30!", "crit marked")
	T.ok(c.scale.x > 1.0, "crit pops")
	await _wait_real(_c("NUMBER_LIFE") + 0.25)
	T.ok(not is_instance_valid(l), "number freed")
	T.ok(not is_instance_valid(c), "crit number freed")


func test_burst_presets_spawn_and_free() -> void:
	var fx := _fx()
	for id: StringName in (_c("BURSTS") as Dictionary):
		var p: CPUParticles2D = fx.burst(id, Vector2(50, 50))
		T.ok(p != null and p.emitting, "%s emits" % id)
	T.eq(fx.burst(&"nope", Vector2.ZERO), null, "unknown burst id is a no-op")
	var last: CPUParticles2D = fx.burst(&"hit", Vector2.ZERO)
	await _wait_real(0.6)
	T.ok(not is_instance_valid(last), "burst freed after its lifetime")


func test_flash_tints_then_restores() -> void:
	var fx := _fx()
	var s := Sprite2D.new()
	s.self_modulate = Color(0.5, 0.5, 1.0)
	_tree().root.add_child(s)
	fx.flash(s, _c("FLASH_WHITE"), 0.05)
	T.eq(s.self_modulate, _c("FLASH_WHITE"), "flashing")
	fx.flash(s, _c("FLASH_CRIT"), 0.05)
	await _wait_real(0.15)
	T.eq(s.self_modulate, Color(0.5, 0.5, 1.0), "back to its own tint after two flashes")
	s.free()


func test_enemy_hit_shows_number_and_stops() -> void:
	_tree().root.get_node("Game").new_run()
	var e := (load("res://actors/enemies/crawler.tscn") as PackedScene).instantiate() as EnemyBase
	_tree().root.add_child(e)
	await _tree().process_frame
	var world: Node = _fx().get_node("World")
	var before := world.get_child_count()
	var hb := Hitbox.new()
	hb.team = &"player"
	hb.damage = 3
	_tree().root.add_child(hb)
	e.hurtbox.receive(hb)
	T.ok(world.get_child_count() > before, "number and sparks spawned")
	T.ok(Engine.time_scale < 1.0, "player hit stops time")
	await _wait_real(0.15)
	T.eq(Engine.time_scale, 1.0)
	hb.free()
	e.free()
