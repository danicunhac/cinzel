class_name Difficulty
extends RefCounted

## Enemy hp and damage per tower floor (index 0 = floor 1), on top of the
## clock level. Tuned with the QA bot, see docs/balance.md.
const FLOOR_HP_MULT: Array[float] = [1.0, 0.85, 0.85]
const FLOOR_DMG_MULT: Array[float] = [1.0, 0.7, 0.7]


static func enemy_hp_mult(level: int) -> float:
	return 1.0 + 0.1 * level


static func enemy_dmg_mult(level: int) -> float:
	return 1.0 + 0.08 * level


static func floor_hp_mult(floor_num: int) -> float:
	return FLOOR_HP_MULT[clampi(floor_num, 1, FLOOR_HP_MULT.size()) - 1]


static func floor_dmg_mult(floor_num: int) -> float:
	return FLOOR_DMG_MULT[clampi(floor_num, 1, FLOOR_DMG_MULT.size()) - 1]


static func extra_enemies(level: int) -> int:
	return 0 if level < 5 else 1


static func gold_mult(level: int) -> float:
	return 1.0 + 0.05 * level
