extends RefCounted
## Stats come from the whole equipment (was from_items over the 3 relics).


func _with_relics(relics: Array[StringName]) -> Equipment:
	var eq := Equipment.starter()
	eq.relics = relics
	return eq


func test_base_stats() -> void:
	var s := PlayerStats.from_equipment(Equipment.starter())
	T.eq(s.max_hp, 100)
	T.eq(s.damage, 10, "iron sword keeps the old base damage")
	T.eq(s.weapon_type, &"sword")
	T.near(s.heal_delay, 1.5)
	T.near(s.roll_distance, 54.0)
	T.near(s.move_speed, 90.0)


func test_item_mods_stack() -> void:
	var s := PlayerStats.from_equipment(_with_relics([&"stone_heart", &"light_boots"] as Array[StringName]))
	T.eq(s.max_hp, 140)
	T.near(s.move_speed, 112.5)


func test_hourglass_heal_delay() -> void:
	var s := PlayerStats.from_equipment(_with_relics([&"cracked_hourglass"] as Array[StringName]))
	T.near(s.heal_delay, 0.75)


func test_weapon_sets_damage_speed_range() -> void:
	var eq := Equipment.starter()
	eq.weapon = &"dagger_rogue"
	var s := PlayerStats.from_equipment(eq)
	var st: Dictionary = ItemDB.get_def(&"dagger_rogue")["stats"]
	T.eq(s.weapon_type, &"dagger")
	T.eq(s.damage, int(st["damage"]))
	T.near(s.attack_speed_mult, float(st["attack_speed"]))
	T.near(s.attack_range, float(st["range"]))
	T.near(s.crit_chance, float(st["crit"]))


func test_relic_mult_applies_to_weapon_damage() -> void:
	var eq := _with_relics([&"heavy_blade"] as Array[StringName])
	eq.weapon = &"axe_war"
	var base: int = ItemDB.get_def(&"axe_war")["stats"]["damage"]
	T.eq(PlayerStats.from_equipment(eq).damage, roundi(base * 1.5))


func test_armor_defense_hp_and_weight_slows_roll() -> void:
	var light := Equipment.starter()
	light.armor = &"armor_cloth"
	var heavy := Equipment.starter()
	heavy.armor = &"armor_plate"
	var sl := PlayerStats.from_equipment(light)
	var sh := PlayerStats.from_equipment(heavy)
	var plate: Dictionary = ItemDB.get_def(&"armor_plate")["stats"]
	T.eq(sh.defense, int(plate["defense"]))
	T.eq(sh.max_hp, 100 + int(plate["max_hp"]))
	T.eq(sh.weight, int(plate["weight"]))
	T.ok(sh.roll_speed_mult < sl.roll_speed_mult, "heavier armor rolls slower")
	T.ok(sh.roll_distance < sl.roll_distance, "and shorter (same roll time)")
	T.near(sl.roll_speed_mult, 1.0)


func test_helm_adds_crit() -> void:
	var eq := Equipment.starter()
	eq.helm = &"helm_horned"
	var base := PlayerStats.from_equipment(Equipment.starter()).crit_chance
	var helm: Dictionary = ItemDB.get_def(&"helm_horned")["stats"]
	T.near(PlayerStats.from_equipment(eq).crit_chance, base + float(helm["crit"]))
