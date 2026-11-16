extends RefCounted


func test_every_type_has_a_def() -> void:
	for t: StringName in ItemDB.WEAPON_TYPES:
		var d := WeaponDef.for_type(t)
		T.eq(d.type, t)
		T.ok(d.combo >= 1, "%s combo" % t)
		T.eq(d.combo_mult.size(), d.combo, "%s combo mults" % t)
		T.ok(d.special != &"", "%s special" % t)


func test_combo_counts() -> void:
	T.eq(WeaponDef.for_type(&"sword").combo, 3)
	T.eq(WeaponDef.for_type(&"longsword").combo, 2)
	T.eq(WeaponDef.for_type(&"axe").combo, 2)
	T.eq(WeaponDef.for_type(&"dagger").combo, 4)


func test_longsword_arc_and_axe_stun() -> void:
	T.near(WeaponDef.for_type(&"longsword").arc_deg, 160.0)
	T.near(WeaponDef.for_type(&"axe").stun, 0.4)
	T.near(WeaponDef.for_type(&"sword").stun, 0.0)


func test_reach_is_catalog_range_scaled() -> void:
	# Catalog ranges are in the old 320x180 units; the game is x1.5.
	var spear := WeaponDef.for_item(&"spear_hunter")
	T.near(spear.reach, 72.0)
	T.ok(spear.thrust, "spear thrusts")
	T.near(WeaponDef.for_item(&"sword_iron").reach, 33.0)


func test_bow_arrow() -> void:
	var bow := WeaponDef.for_item(&"bow_short")
	T.ok(bow.ranged, "bow is ranged")
	T.near(bow.projectile_speed, 540.0)
	T.near(bow.reach, 240.0)
	T.eq(bow.charged_pierce, 1)
	T.near(bow.charge_hold, 0.5)
	T.near(bow.special_hold, 1.0)


func test_swing_time_scales_with_attack_speed() -> void:
	var axe := WeaponDef.for_item(&"axe_woodcutter")
	T.near(axe.swing_time(0.6), 0.5)
	var dagger := WeaponDef.for_item(&"dagger_rogue")
	T.ok(dagger.swing_time(1.6) < axe.swing_time(0.6), "dagger faster than axe")
