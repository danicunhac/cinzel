class_name Difficulty
extends RefCounted


static func enemy_hp_mult(level: int) -> float:
	return 1.0 + 0.1 * level


static func enemy_dmg_mult(level: int) -> float:
	return 1.0 + 0.08 * level


static func extra_enemies(level: int) -> int:
	return 0 if level < 5 else 1


static func gold_mult(level: int) -> float:
	return 1.0 + 0.05 * level
