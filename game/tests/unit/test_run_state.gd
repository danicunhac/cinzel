extends RefCounted

## Tests whose push_error is the behaviour under test (see run_tests.gd).
const EXPECTS_ERRORS: Array[String] = ["test_add_unknown_item_rejected", "test_items_is_read_only"]

var _fired: int = 0


func _on_changed() -> void:
	_fired += 1


## `items` / add_item now mean the 3 relic slots of Equipment.
func test_add_item_until_full() -> void:
	var r: RunState = RunState.new()
	T.eq(r.add_item(&"fang"), true)
	T.eq(r.add_item(&"spark"), true)
	T.eq(r.add_item(&"wind_cape"), true)
	T.eq(r.add_item(&"heavy_blade"), false)
	T.eq(r.items.size(), 3)
	T.eq(r.items, r.equipment.relics)


func test_replace_returns_old() -> void:
	var r: RunState = RunState.new()
	r.add_item(&"fang")
	r.add_item(&"spark")
	var old: StringName = r.replace_item(1, &"wind_cape")
	T.eq(old, &"spark")
	T.eq(r.items[1], &"wind_cape")


func test_spend_gold_insufficient() -> void:
	var r: RunState = RunState.new()
	r.gold = 10
	T.eq(r.spend_gold(11), false)
	T.eq(r.gold, 10)
	T.eq(r.spend_gold(10), true)
	T.eq(r.gold, 0)


func test_unlock_keeps_max() -> void:
	var r: RunState = RunState.new()
	r.unlock_floor(3)
	r.unlock_floor(2)
	T.eq(r.unlocked_floors, 3)
	r.unlock_floor(5)
	T.eq(r.unlocked_floors, 3)


func test_beat_floor_unlocks_next() -> void:
	var r := RunState.new()
	r.beat_floor(1)
	T.eq(r.floors_beaten, 1)
	T.eq(r.unlocked_floors, 2)
	r.beat_floor(3)
	T.eq(r.floors_beaten, 3)
	T.eq(r.unlocked_floors, 3)


func test_die_loses_everything() -> void:
	var r: RunState = RunState.new()
	r.gold = 50
	r.add_item(&"fang")
	r.add_item(&"spark")
	r.unlock_floor(3)
	r.beat_floor(2)
	r.clock.seconds = 200.0
	r.tutorial_done = true
	r.die()
	T.eq(r.gold, 0)
	T.eq(r.tutorial_done, false, "tutorial comes back")
	T.ok(r.items.is_empty(), "items empty")
	T.eq(r.unlocked_floors, 1)
	T.eq(r.floors_beaten, 0)
	T.near(r.clock.seconds, 0.0)


func test_die_restores_starter_kit_and_keeps_outfits() -> void:
	var r := RunState.new()
	r.inventory.add(&"backpack_large")
	r.equip(&"backpack_large")
	r.inventory.add(&"axe_war")
	r.equip(&"axe_war")
	r.inventory.add(&"armor_plate")
	r.equip(&"armor_plate")
	r.inventory.add(&"mat_slime_gel", 15)
	r.unlock_outfit(&"outfit_manto_mago")
	T.eq(r.set_outfit(&"outfit_manto_mago"), true)
	r.die()
	T.eq(r.equipment.weapon, &"sword_iron")
	T.eq(r.equipment.backpack, &"backpack_small")
	T.eq(r.equipment.armor, &"")
	T.ok(r.inventory.is_empty(), "backpack emptied")
	T.eq(r.inventory.capacity, 8)
	T.ok(r.unlocked_outfits.has(&"outfit_manto_mago"), "outfits are visual and stay")
	T.eq(r.equipment.outfit, &"outfit_manto_mago", "chosen outfit stays")


func test_set_outfit_needs_unlock() -> void:
	var r := RunState.new()
	T.eq(r.set_outfit(&"outfit_casaco_longo"), false)
	T.eq(r.equipment.outfit, &"outfit_starter")
	r.unlock_outfit(&"outfit_casaco_longo")
	T.eq(r.set_outfit(&"outfit_casaco_longo"), true)


func test_take_loot_equips_into_free_slot_else_backpack() -> void:
	var r := RunState.new()
	T.eq(r.take_loot(&"fang"), 0)
	T.eq(r.items, [&"fang"] as Array[StringName], "free relic slot: equipped")
	T.eq(r.take_loot(&"armor_leather"), 0)
	T.eq(r.equipment.armor, &"armor_leather", "empty armor slot: equipped")
	T.eq(r.take_loot(&"axe_war"), 0)
	T.eq(r.equipment.weapon, &"sword_iron", "weapon slot taken: backpack")
	T.eq(r.inventory.count(&"axe_war"), 1)
	T.eq(r.take_loot(&"mat_stone_shard", 3), 0)
	T.eq(r.inventory.count(&"mat_stone_shard"), 3)
	T.eq(r.take_loot(&"outfit_cavaleiro_leve"), 0)
	T.ok(r.unlocked_outfits.has(&"outfit_cavaleiro_leve"), "outfit unlocks")


func test_take_loot_returns_overflow_when_backpack_full() -> void:
	var r := RunState.new()
	r.inventory.add(&"axe_war", 8)
	T.eq(r.take_loot(&"bow_short"), 1)
	T.eq(r.take_loot(&"mat_slime_gel", 4), 4)


func test_equip_through_run_updates_capacity_and_stats() -> void:
	var r := RunState.new()
	r.inventory.add(&"backpack_medium")
	T.eq(r.equip(&"backpack_medium"), true)
	T.eq(r.inventory.capacity, 14)
	r.inventory.add(&"armor_plate")
	r.equip(&"armor_plate")
	T.ok(r.stats().max_hp > 100, "armor hp")
	T.eq(r.unequip(&"armor"), true)
	T.eq(r.stats().max_hp, 100)


func test_changed_signal() -> void:
	var r: RunState = RunState.new()
	_fired = 0
	r.changed.connect(_on_changed)
	r.add_gold(5)
	T.eq(_fired, 1)


func test_add_unknown_item_rejected() -> void:
	var r: RunState = RunState.new()
	T.eq(r.add_item(&"nope"), false)
	T.ok(r.items.is_empty(), "items empty")
	r.add_item(&"fang")
	T.eq(r.replace_item(0, &"nope"), &"")
	T.eq(r.items[0], &"fang")


func test_replace_bad_slot_noop() -> void:
	var r: RunState = RunState.new()
	r.add_item(&"fang")
	T.eq(r.replace_item(5, &"spark"), &"")
	T.eq(r.replace_item(-1, &"spark"), &"")
	T.eq(r.remove_item(3), &"")
	T.eq(r.items.size(), 1)
	T.eq(r.items[0], &"fang")


func test_die_restores_hp() -> void:
	var r := RunState.new()
	r.add_item(&"stone_heart")
	r.hp = 5
	r.die()
	T.eq(r.hp, 100)


func test_hp_defaults_to_base_max() -> void:
	T.eq(RunState.new().hp, 100)


func test_die_resets_market() -> void:
	var r := RunState.new()
	r.market.begin_visit(RandomNumberGenerator.new())
	r.market.factors[&"fang"] = 0.4
	r.die()
	T.near(r.market.factor(&"fang"), 1.0)
	T.eq(r.market.visits, 0, "new run, fresh market")


func test_items_is_read_only() -> void:
	var r := RunState.new()
	r.items = [&"fang"] as Array[StringName]
	T.ok(r.items.is_empty(), "assignment ignored: use add_item or equip")
