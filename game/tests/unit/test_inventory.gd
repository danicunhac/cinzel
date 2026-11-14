extends RefCounted

const EXPECTS_ERRORS: Array[String] = ["test_unknown_id_not_added"]


func test_materials_stack_to_ten() -> void:
	var inv := Inventory.new(8)
	T.eq(inv.add(&"mat_slime_gel", 7), 0)
	T.eq(inv.add(&"mat_slime_gel", 5), 0)
	T.eq(inv.used(), 2, "10 + 2 in two slots")
	T.eq(inv.qty_at(0), 10)
	T.eq(inv.qty_at(1), 2)
	T.eq(inv.count(&"mat_slime_gel"), 12)


func test_equipment_does_not_stack() -> void:
	var inv := Inventory.new(8)
	inv.add(&"fang")
	inv.add(&"fang")
	T.eq(inv.used(), 2)


func test_add_returns_overflow() -> void:
	var inv := Inventory.new(2)
	T.eq(inv.add(&"mat_stone_shard", 25), 5, "two stacks of 10 fit")
	T.eq(inv.add(&"fang"), 1, "full")
	T.eq(inv.is_full(), true)


func test_remove_all_or_nothing() -> void:
	var inv := Inventory.new(8)
	inv.add(&"mat_slime_gel", 12)
	T.eq(inv.remove(&"mat_slime_gel", 13), false)
	T.eq(inv.count(&"mat_slime_gel"), 12)
	T.eq(inv.remove(&"mat_slime_gel", 11), true)
	T.eq(inv.count(&"mat_slime_gel"), 1)
	T.eq(inv.used(), 1)


func test_remove_at_takes_one_unit() -> void:
	var inv := Inventory.new(8)
	inv.add(&"fang")
	inv.add(&"mat_slime_gel", 3)
	T.eq(inv.remove_at(1), &"mat_slime_gel")
	T.eq(inv.qty_at(1), 2)
	T.eq(inv.remove_at(0), &"fang")
	T.eq(inv.id_at(0), &"")
	T.eq(inv.remove_at(5), &"")


func test_shrink_refused_when_too_full() -> void:
	var inv := Inventory.new(14)
	inv.add(&"fang", 10)
	T.eq(inv.used(), 10)
	T.eq(inv.set_capacity(8), false)
	T.eq(inv.capacity, 14)
	inv.remove(&"fang", 3)
	T.eq(inv.set_capacity(8), true)
	T.eq(inv.capacity, 8)
	T.eq(inv.count(&"fang"), 7, "items kept and packed")


func test_non_positive_qty_is_a_no_op() -> void:
	var inv := Inventory.new(8)
	T.eq(inv.add(&"mat_slime_gel", 0), 0)
	T.eq(inv.add(&"mat_slime_gel", -3), 0)
	T.ok(inv.is_empty(), "nothing added")
	inv.add(&"mat_slime_gel", 2)
	T.eq(inv.remove(&"mat_slime_gel", 0), false)
	T.eq(inv.remove(&"mat_slime_gel", -1), false)
	T.eq(inv.count(&"mat_slime_gel"), 2)


func test_unknown_id_not_added() -> void:
	var inv := Inventory.new(8)
	T.eq(inv.add(&"nope"), 1)
	T.ok(inv.is_empty(), "empty")
