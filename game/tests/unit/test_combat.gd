extends RefCounted


func test_defense_formula() -> void:
	# taken = max(1, round(dmg * 20 / (20 + def)))
	T.eq(Combat.reduce(10, 0), 10)
	T.eq(Combat.reduce(10, 4), 8)
	T.eq(Combat.reduce(20, 10), 13)
	T.eq(Combat.reduce(30, 20), 15)
	T.eq(Combat.reduce(1, 50), 1, "never below 1")
	T.eq(Combat.reduce(0, 0), 0, "no hit stays 0")


func test_crit_roll_is_deterministic_with_seed() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 1234
	b.seed = 1234
	var seq_a: Array[bool] = []
	var seq_b: Array[bool] = []
	for i in 50:
		seq_a.append(Combat.roll_crit(0.3, a))
		seq_b.append(Combat.roll_crit(0.3, b))
	T.eq(seq_a, seq_b)
	T.ok(seq_a.has(true) and seq_a.has(false), "mixed results at 30%")


func test_crit_chance_bounds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 20:
		T.ok(not Combat.roll_crit(0.0, rng), "0% never crits")
		T.ok(Combat.roll_crit(1.0, rng), "100% always crits")


func test_hit_damage_applies_crit_mult() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	T.eq(Combat.hit_damage(10, 1.0, 2.0, rng), 20)
	T.eq(Combat.hit_damage(10, 0.0, 2.0, rng), 10)
	T.eq(Combat.hit_damage(7, 1.0, 1.5, rng), 11, "rounded")


func test_stats_crit_from_helm_and_dagger() -> void:
	var eq := Equipment.starter()
	eq.weapon = &"dagger_rogue"
	eq.helm = &"helm_hood"
	var s := PlayerStats.from_equipment(eq)
	T.near(s.crit_chance, 0.23)
	T.near(s.crit_mult, 2.0)
	eq.weapon = &"sword_iron"
	T.near(PlayerStats.from_equipment(eq).crit_mult, 1.5)
