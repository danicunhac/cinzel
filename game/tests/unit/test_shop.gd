extends RefCounted


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_restock_three_distinct() -> void:
	var shop: Shop = Shop.new()
	shop.restock(_rng(1))
	T.eq(shop.stock.size(), 3)
	T.ok(shop.stock[0] != shop.stock[1], "0 != 1")
	T.ok(shop.stock[0] != shop.stock[2], "0 != 2")
	T.ok(shop.stock[1] != shop.stock[2], "1 != 2")


func test_buy_ok() -> void:
	var shop: Shop = Shop.new()
	shop.restock(_rng(1))
	var id: StringName = shop.stock[0]
	var price: int = ItemDB.get_def(id)["buy"]
	var run: RunState = RunState.new()
	run.gold = 200
	T.eq(shop.buy(run, 0), true)
	T.eq(run.gold, 200 - price)
	T.ok(run.items.has(id), "item in run")
	T.ok(not shop.stock.has(id), "item out of stock")


func test_buy_no_gold() -> void:
	var shop: Shop = Shop.new()
	shop.restock(_rng(1))
	var run: RunState = RunState.new()
	run.gold = 1
	T.eq(shop.buy(run, 0), false)
	T.eq(run.gold, 1)
	T.eq(run.items.size(), 0)
	T.eq(shop.stock.size(), 3)


func test_buy_slots_full() -> void:
	var shop: Shop = Shop.new()
	shop.restock(_rng(1))
	var run: RunState = RunState.new()
	run.gold = 500
	run.items = [&"fang", &"spark", &"wind_cape"]
	T.eq(shop.buy(run, 0), false)
	T.eq(run.gold, 500)
	T.eq(shop.stock.size(), 3)


func test_sell_updates_stats() -> void:
	var shop: Shop = Shop.new()
	var run: RunState = RunState.new()
	run.add_item(&"stone_heart")
	var sell_price: int = ItemDB.get_def(&"stone_heart")["sell"]
	T.eq(shop.sell(run, 0), true)
	T.eq(run.gold, sell_price)
	T.eq(run.stats().max_hp, 100)
	T.eq(run.items.size(), 0)


func test_trade_requires_two() -> void:
	var shop: Shop = Shop.new()
	var run: RunState = RunState.new()
	run.add_item(&"fang")
	T.eq(shop.can_trade(run), false)


func test_trade_result() -> void:
	var shop: Shop = Shop.new()
	var run: RunState = RunState.new()
	run.add_item(&"fang")
	run.add_item(&"spark")
	var new_id: StringName = shop.trade(run, 0, 1, _rng(7))
	T.ok(new_id != &"", "returned id")
	T.eq(run.items.size(), 1)
	T.ok(new_id != &"fang" and new_id != &"spark", "new item differs")
	T.eq(run.items[0], new_id)
