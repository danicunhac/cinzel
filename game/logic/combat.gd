class_name Combat
extends RefCounted
## Damage rules shared by the player and the enemies.
##   Defense: taken = max(1, round(dmg * DEFENSE_K / (DEFENSE_K + defense))).
##   With K = 20, defense 4 takes 83%, 10 takes 67%, 20 takes 50%.
##   Crit: one roll per swing (or arrow, or flurry cut); a crit multiplies the
##   damage by the weapon's crit_mult.

const DEFENSE_K := 20.0


static func reduce(dmg: int, defense: int) -> int:
	if dmg <= 0:
		return 0
	return maxi(1, roundi(dmg * DEFENSE_K / (DEFENSE_K + maxi(defense, 0))))


static func roll_crit(chance: float, rng: RandomNumberGenerator) -> bool:
	return rng.randf() < chance


## Base damage after one crit roll.
static func hit_damage(base: int, crit_chance: float, crit_mult: float, rng: RandomNumberGenerator) -> int:
	return roundi(base * crit_mult) if roll_crit(crit_chance, rng) else base
