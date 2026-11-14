class_name Shop
extends RefCounted

const STOCK_SIZE := 3

var stock: Array[StringName] = []


func restock(rng: RandomNumberGenerator) -> void:
	var pool: Array[StringName] = ItemDB.ids()
	stock.clear()
	while stock.size() < STOCK_SIZE and not pool.is_empty():
		var i: int = rng.randi_range(0, pool.size() - 1)
		stock.append(pool[i])
		pool.remove_at(i)


func buy(run: RunState, stock_index: int) -> bool:
	if stock_index < 0 or stock_index >= stock.size():
		return false
	if not run.can_take_item():
		return false
	var id: StringName = stock[stock_index]
	var price: int = ItemDB.get_def(id)["buy"]
	if not run.spend_gold(price):
		return false
	run.add_item(id)
	stock.remove_at(stock_index)
	return true


func sell(run: RunState, slot: int) -> bool:
	if slot < 0 or slot >= run.items.size():
		return false
	var id: StringName = run.remove_item(slot)
	var price: int = ItemDB.get_def(id)["sell"]
	run.add_gold(price)
	return true


func can_trade(run: RunState) -> bool:
	return run.items.size() >= 2


func trade(run: RunState, slot_a: int, slot_b: int, rng: RandomNumberGenerator) -> StringName:
	if not can_trade(run) or slot_a == slot_b:
		return &""
	if slot_a < 0 or slot_b < 0 or slot_a >= run.items.size() or slot_b >= run.items.size():
		return &""
	var id_a: StringName = run.items[slot_a]
	var id_b: StringName = run.items[slot_b]
	var pool: Array[StringName] = []
	for id: StringName in ItemDB.ids():
		if id != id_a and id != id_b:
			pool.append(id)
	if pool.is_empty():
		return &""
	run.remove_item(maxi(slot_a, slot_b))
	run.remove_item(mini(slot_a, slot_b))
	var new_id: StringName = pool[rng.randi_range(0, pool.size() - 1)]
	run.add_item(new_id)
	return new_id
