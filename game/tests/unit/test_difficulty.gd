extends RefCounted


func test_hp_mult() -> void:
	T.near(Difficulty.enemy_hp_mult(0), 1.0)
	T.near(Difficulty.enemy_hp_mult(3), 1.3)


func test_dmg_mult() -> void:
	T.near(Difficulty.enemy_dmg_mult(5), 1.4)


func test_extra_enemies() -> void:
	T.eq(Difficulty.extra_enemies(4), 0)
	T.eq(Difficulty.extra_enemies(5), 1)
	T.eq(Difficulty.extra_enemies(12), 1)


func test_gold_mult() -> void:
	T.near(Difficulty.gold_mult(0), 1.0)
	T.near(Difficulty.gold_mult(4), 1.2)
