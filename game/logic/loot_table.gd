class_name LootTable
extends RefCounted
## What drops where. Deterministic for a given RandomNumberGenerator.
##   Enemies: the material of their type on their floor, half of the time.
##   Chests: one piece of gear or a relic (rarely a chest outfit).
##   Bosses: gear of rare or better, 3 floor materials, maybe the tower
##   crystal, and the first boss gives an outfit.
## Rarity is weighted by floor and run clock level.
## Drops are {"id": StringName, "qty": int}.

const ENEMY_DROP_CHANCE := 0.5
const ENEMY_MATERIALS: Dictionary[int, Dictionary] = {
	1: {&"crawler": &"mat_slime_gel", &"charger": &"mat_slime_core", &"shooter": &"mat_stone_shard"},
	2: {&"crawler": &"mat_beetle_shell", &"charger": &"mat_beetle_horn", &"shooter": &"mat_sentinel_eye"},
	3: {&"crawler": &"mat_ember_dust", &"charger": &"mat_obsidian", &"shooter": &"mat_specter_cloth"},
}
const CHEST_KIND_WEIGHTS: Dictionary[StringName, float] = {
	&"weapon": 30.0, &"armor": 20.0, &"helm": 14.0, &"relic": 30.0, &"backpack": 4.0, &"outfit": 2.0,
}
const BOSS_MATERIALS := 3
const BOSS_CRYSTAL := &"mat_tower_crystal"
## Chance of the tower crystal per boss floor.
const BOSS_CRYSTAL_CHANCE: Dictionary[int, float] = {1: 0.35, 2: 0.6, 3: 1.0}
const BOSS_OUTFITS: Dictionary[int, StringName] = {1: &"outfit_cavaleiro_leve"}
const RARITIES: Array[StringName] = [&"common", &"rare", &"epic"]


## Weights for common/rare/epic. Each floor past the first moves 15 from
## common to rare (+8) and epic (+7); each clock level moves 3 (+2, +1).
static func rarity_weights(floor_num: int, clock_level: int) -> Dictionary[StringName, float]:
	var f := clampi(floor_num, 1, 3) - 1
	var lvl := maxi(clock_level, 0)
	var common := maxf(10.0, 70.0 - 15.0 * f - 3.0 * lvl)
	return {
		&"common": common,
		&"rare": 25.0 + 8.0 * f + 2.0 * lvl,
		&"epic": 5.0 + 7.0 * f + 1.0 * lvl,
	}


static func roll_rarity(floor_num: int, clock_level: int, rng: RandomNumberGenerator) -> StringName:
	var w := rarity_weights(floor_num, clock_level)
	return _pick(w, rng)


## Material drop of one enemy (crawler, shooter, charger). [] when nothing drops.
static func roll_enemy(enemy_type: StringName, floor_num: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var table: Dictionary = ENEMY_MATERIALS.get(clampi(floor_num, 1, 3), {})
	if not table.has(enemy_type):
		return out
	if rng.randf() < ENEMY_DROP_CHANCE:
		out.append({"id": table[enemy_type], "qty": 1})
	return out


## One item from a chest. Outfits in `exclude` (already unlocked) are skipped.
static func roll_chest(floor_num: int, clock_level: int, rng: RandomNumberGenerator,
		exclude: Array[StringName] = []) -> StringName:
	var kinds := CHEST_KIND_WEIGHTS.duplicate()
	var chest_outfits: Array[StringName] = []
	for id: StringName in ItemDB.ids(&"outfit"):
		if ItemCatalog.ITEMS[id]["unlock"] == &"chest" and not exclude.has(id):
			chest_outfits.append(id)
	if chest_outfits.is_empty():
		kinds.erase(&"outfit")
	var kind := _pick(kinds, rng)
	if kind == &"outfit":
		return chest_outfits[rng.randi_range(0, chest_outfits.size() - 1)]
	return _gear(kind, roll_rarity(floor_num, clock_level, rng), rng)


## Everything a floor boss drops.
static func roll_boss(floor_num: int, clock_level: int, rng: RandomNumberGenerator,
		exclude: Array[StringName] = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var kinds := CHEST_KIND_WEIGHTS.duplicate()
	kinds.erase(&"outfit")
	var rarity := roll_rarity(floor_num, clock_level, rng)
	if rarity == &"common":
		rarity = &"rare"
	out.append({"id": _gear(_pick(kinds, rng), rarity, rng), "qty": 1})
	var mats := ItemDB.materials_of_floor(clampi(floor_num, 1, 3))
	var counts: Dictionary[StringName, int] = {}
	for i in BOSS_MATERIALS:
		var m := mats[rng.randi_range(0, mats.size() - 1)]
		counts[m] = counts.get(m, 0) + 1
	for m: StringName in counts:
		out.append({"id": m, "qty": counts[m]})
	if rng.randf() < BOSS_CRYSTAL_CHANCE.get(clampi(floor_num, 1, 3), 0.0):
		out.append({"id": BOSS_CRYSTAL, "qty": 1})
	var outfit: StringName = BOSS_OUTFITS.get(floor_num, &"")
	if outfit != &"" and not exclude.has(outfit):
		out.append({"id": outfit, "qty": 1})
	return out


## A random item of `kind` and `rarity`; falls back to a lower rarity when the
## kind has none of that rarity.
static func _gear(kind: StringName, rarity: StringName, rng: RandomNumberGenerator) -> StringName:
	var pool := ItemDB.ids_by(kind, rarity)
	var i := RARITIES.find(rarity)
	while pool.is_empty() and i > 0:
		i -= 1
		pool = ItemDB.ids_by(kind, RARITIES[i])
	if pool.is_empty():
		pool = ItemDB.ids(kind)
	return pool[rng.randi_range(0, pool.size() - 1)]


static func _pick(weights: Dictionary, rng: RandomNumberGenerator) -> StringName:
	var total := 0.0
	for k: StringName in weights:
		total += float(weights[k])
	var r := rng.randf() * total
	var last: StringName = &""
	for k: StringName in weights:
		last = k
		r -= float(weights[k])
		if r < 0.0:
			return k
	return last
