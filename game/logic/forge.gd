class_name Forge
extends RefCounted
## Blacksmith recipes: materials + gold -> item. A recipe opens once the
## player has beaten `floors` bosses in this run (0 = open from the start).

const RECIPES: Dictionary[StringName, Dictionary] = {
	# Floor 1 materials, open from the start.
	&"spear_hunter": {"result": &"spear_hunter", "floors": 0, "gold": 30,
		"materials": {&"mat_slime_gel": 3, &"mat_stone_shard": 2}},
	&"bow_short": {"result": &"bow_short", "floors": 0, "gold": 30,
		"materials": {&"mat_slime_core": 2, &"mat_stone_shard": 2}},
	&"armor_leather": {"result": &"armor_leather", "floors": 0, "gold": 40,
		"materials": {&"mat_slime_gel": 4, &"mat_slime_core": 1}},
	&"helm_iron": {"result": &"helm_iron", "floors": 0, "gold": 35,
		"materials": {&"mat_stone_shard": 4}},
	# Floor 2 materials, after the first boss.
	&"sword_knight": {"result": &"sword_knight", "floors": 1, "gold": 90,
		"materials": {&"mat_beetle_horn": 3, &"mat_stone_shard": 3}},
	&"axe_war": {"result": &"axe_war", "floors": 1, "gold": 100,
		"materials": {&"mat_beetle_horn": 4, &"mat_sentinel_eye": 1}},
	&"armor_chain": {"result": &"armor_chain", "floors": 1, "gold": 110,
		"materials": {&"mat_beetle_shell": 5, &"mat_slime_core": 2}},
	&"helm_horned": {"result": &"helm_horned", "floors": 1, "gold": 90,
		"materials": {&"mat_beetle_horn": 2, &"mat_beetle_shell": 3}},
	# Floor 3 materials and the boss crystal, after the second boss.
	&"longsword_ember": {"result": &"longsword_ember", "floors": 2, "gold": 220,
		"materials": {&"mat_ember_dust": 4, &"mat_obsidian": 3, &"mat_tower_crystal": 1}},
	&"dagger_twin_fang": {"result": &"dagger_twin_fang", "floors": 2, "gold": 200,
		"materials": {&"mat_obsidian": 3, &"mat_specter_cloth": 2}},
	&"armor_plate": {"result": &"armor_plate", "floors": 2, "gold": 200,
		"materials": {&"mat_obsidian": 5, &"mat_beetle_shell": 4}},
	&"armor_shadow": {"result": &"armor_shadow", "floors": 2, "gold": 240,
		"materials": {&"mat_specter_cloth": 5, &"mat_tower_crystal": 1}},
}


static func is_unlocked(recipe_id: StringName, floors_beaten: int) -> bool:
	return RECIPES.has(recipe_id) and int(RECIPES[recipe_id]["floors"]) <= floors_beaten


static func unlocked(floors_beaten: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in RECIPES:
		if is_unlocked(id, floors_beaten):
			out.append(id)
	return out


## Unlocked, enough gold and every material in the backpack.
static func can_craft(run: RunState, recipe_id: StringName) -> bool:
	if not is_unlocked(recipe_id, run.floors_beaten):
		return false
	var r: Dictionary = RECIPES[recipe_id]
	if run.gold < int(r["gold"]):
		return false
	var mats: Dictionary = r["materials"]
	for m: StringName in mats:
		if run.inventory.count(m) < int(mats[m]):
			return false
	return true


## Why the recipe cannot be forged now, for the disabled button ("" = it can).
## Checked in order: locked, materials, gold, room for the result.
static func block_reason(run: RunState, recipe_id: StringName) -> String:
	if not is_unlocked(recipe_id, run.floors_beaten):
		return "Vença o chefe do andar %d" % int(RECIPES[recipe_id]["floors"]) if RECIPES.has(recipe_id) else "Receita desconhecida"
	var r: Dictionary = RECIPES[recipe_id]
	var mats: Dictionary = r["materials"]
	for m: StringName in mats:
		if run.inventory.count(m) < int(mats[m]):
			return "Faltam materiais"
	if run.gold < int(r["gold"]):
		return "Ouro insuficiente"
	if not _fits_after_paying(run, r):
		return "Mochila cheia"
	return ""


## Whether the result fits once the materials leave the backpack.
static func _fits_after_paying(run: RunState, r: Dictionary) -> bool:
	var inv := Inventory.new(run.inventory.capacity)
	for i in run.inventory.capacity:
		inv.slots[i] = run.inventory.slots[i].duplicate()
	var mats: Dictionary = r["materials"]
	for m: StringName in mats:
		inv.remove(m, int(mats[m]))
	return inv.add(r["result"]) == 0


## Whether any unlocked recipe can be forged right now (smith call to action).
static func any_craftable(run: RunState) -> bool:
	for id: StringName in RECIPES:
		if is_unlocked(id, run.floors_beaten) and block_reason(run, id) == "":
			return true
	return false


## Spends materials and gold and puts the result in the backpack. Refused
## (nothing spent) when the result would not fit after paying.
static func craft(run: RunState, recipe_id: StringName) -> bool:
	if not can_craft(run, recipe_id):
		return false
	var r: Dictionary = RECIPES[recipe_id]
	var mats: Dictionary = r["materials"]
	for m: StringName in mats:
		run.inventory.remove(m, int(mats[m]))
	if run.inventory.add(r["result"]) > 0:
		for m: StringName in mats:
			run.inventory.add(m, int(mats[m]))
		return false
	run.spend_gold(int(r["gold"]))
	return true
