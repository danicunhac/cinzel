extends RefCounted
## Sfx autoload: every id has a file, unknown ids do nothing, the pool is
## reused, music crossfades, volume is per bus.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _sfx() -> Node:
	return _tree().root.get_node("Sfx")


func _c(name: String) -> Variant:
	return _sfx().get_script().get_script_constant_map()[name]


func test_every_id_has_a_file() -> void:
	for id: StringName in (_c("IDS") as Array):
		T.ok(ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % id), "sfx %s" % id)
	for id: StringName in (_c("MUSIC_IDS") as Array):
		T.ok(ResourceLoader.exists("res://assets/audio/music/%s.ogg" % id), "music %s" % id)


func test_unknown_id_is_a_no_op() -> void:
	var sfx := _sfx()
	var busy_before := 0
	for p: AudioStreamPlayer in sfx.pool():
		busy_before += 1 if p.playing else 0
	T.eq(sfx.play(&"no_such_sound"), null, "nothing played")
	var busy_after := 0
	for p: AudioStreamPlayer in sfx.pool():
		busy_after += 1 if p.playing else 0
	T.eq(busy_after, busy_before, "no player started")
	sfx.music(&"no_such_track")
	T.ok(sfx.current_music() != &"no_such_track", "unknown music ignored")


func test_pool_is_reused() -> void:
	var sfx := _sfx()
	var pool: Array[AudioStreamPlayer] = sfx.pool()
	T.eq(pool.size(), _c("POOL_SIZE"))
	var used := {}
	for i in int(_c("POOL_SIZE")) * 3:
		sfx.set(&"_last_ms", {} as Dictionary[StringName, int])
		var p: AudioStreamPlayer = sfx.play(&"hit")
		T.ok(p != null and p in pool, "a pool player")
		used[p] = true
	T.eq(sfx.pool().size(), _c("POOL_SIZE"), "no player added")
	T.ok(used.size() <= _c("POOL_SIZE"), "players reused")
	var children := 0
	for c in sfx.get_children():
		if c is AudioStreamPlayer:
			children += 1
	T.eq(children, int(_c("POOL_SIZE")) + 2, "pool plus the two music players")


func test_pitch_varies_within_jitter() -> void:
	var sfx := _sfx()
	for i in 10:
		sfx.set(&"_last_ms", {} as Dictionary[StringName, int])
		var p: AudioStreamPlayer = sfx.play(&"coin", 0.05)
		T.ok(p.pitch_scale >= 0.95 and p.pitch_scale <= 1.05, "pitch %f" % p.pitch_scale)


func test_same_id_in_one_frame_plays_once() -> void:
	var sfx := _sfx()
	sfx.set(&"_last_ms", {} as Dictionary[StringName, int])
	T.ok(sfx.play(&"crit") != null)
	T.eq(sfx.play(&"crit"), null, "repeat dropped")


func test_heal_loop_starts_and_stops() -> void:
	var sfx := _sfx()
	sfx.play_loop(&"heal_loop")
	T.ok(sfx.is_looping(&"heal_loop"))
	sfx.play_loop(&"heal_loop")
	sfx.stop_loop(&"heal_loop")
	T.ok(not sfx.is_looping(&"heal_loop"))


func test_music_crossfades() -> void:
	var sfx := _sfx()
	sfx.music(&"tower")
	T.eq(sfx.current_music(), &"tower")
	sfx.music(&"boss")
	T.eq(sfx.current_music(), &"boss")
	await _tree().create_timer(float(_c("CROSSFADE")) + 0.2, true, false, true).timeout
	var playing := 0
	for m: AudioStreamPlayer in sfx.get(&"_music"):
		playing += 1 if m.playing else 0
	T.eq(playing, 1, "only the new track after the crossfade")
	sfx.music(&"")


func test_volume_per_bus() -> void:
	var sfx := _sfx()
	var old: float = sfx.get_volume(_c("MUSIC_BUS"))
	sfx.set_volume(_c("MUSIC_BUS"), 0.25, false)
	T.near(sfx.get_volume(_c("MUSIC_BUS")), 0.25)
	var i := AudioServer.get_bus_index(_c("MUSIC_BUS"))
	T.ok(i >= 0, "Music bus exists")
	T.near(AudioServer.get_bus_volume_db(i), linear_to_db(0.25), 0.01)
	T.ok(AudioServer.get_bus_index(_c("SFX_BUS")) >= 0, "SFX bus exists")
	sfx.set_volume(_c("MUSIC_BUS"), old, false)
