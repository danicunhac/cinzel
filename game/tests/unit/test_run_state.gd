extends RefCounted

var _fired: int = 0


func _on_changed() -> void:
	_fired += 1


func test_add_item_until_full() -> void:
	var r: RunState = RunState.new()
	T.eq(r.add_item(&"fang"), true)
	T.eq(r.add_item(&"spark"), true)
	T.eq(r.add_item(&"wind_cape"), true)
	T.eq(r.add_item(&"heavy_blade"), false)
	T.eq(r.items.size(), 3)


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


func test_die_loses_everything() -> void:
	var r: RunState = RunState.new()
	r.gold = 50
	r.add_item(&"fang")
	r.add_item(&"spark")
	r.unlock_floor(3)
	r.clock.seconds = 200.0
	r.die()
	T.eq(r.gold, 0)
	T.ok(r.items.is_empty(), "items empty")
	T.eq(r.unlocked_floors, 1)
	T.near(r.clock.seconds, 0.0)


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
