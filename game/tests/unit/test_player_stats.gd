extends RefCounted


func test_base_stats() -> void:
	var s: PlayerStats = PlayerStats.from_items([] as Array[StringName])
	T.eq(s.max_hp, 100)
	T.near(s.heal_delay, 1.5)


func test_item_mods_stack() -> void:
	var s: PlayerStats = PlayerStats.from_items([&"stone_heart", &"light_boots"] as Array[StringName])
	T.eq(s.max_hp, 140)
	T.near(s.move_speed, 100.0)


func test_hourglass_heal_delay() -> void:
	var s: PlayerStats = PlayerStats.from_items([&"cracked_hourglass"] as Array[StringName])
	T.near(s.heal_delay, 0.75)
