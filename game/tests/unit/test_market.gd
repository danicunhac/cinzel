extends RefCounted
## Replaces test_shop.gd: the old Shop (fixed sell price, 2-for-1 trade) became Market.


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A visit with no wanted items, so prices are only base x rarity x factor.
func _plain_market() -> Market:
	var m := Market.new()
	m.begin_visit(_rng(1))
	m.wanted.clear()
	return m


func test_visit_stock_and_two_wanted() -> void:
	var m := Market.new()
	m.begin_visit(_rng(1))
	T.eq(m.stock.size(), Market.STOCK_SIZE)
	T.eq(m.wanted.size(), Market.WANTED_COUNT)
	T.ok(m.wanted[0] != m.wanted[1], "two different wanted items")
	T.ok(m.stock[0] != m.stock[1] and m.stock[1] != m.stock[2] and m.stock[0] != m.stock[2], "distinct stock")


func test_same_seed_same_visit() -> void:
	var a := Market.new()
	var b := Market.new()
	a.begin_visit(_rng(4))
	b.begin_visit(_rng(4))
	T.eq(a.stock, b.stock)
	T.eq(a.wanted, b.wanted)


func test_price_is_base_times_rarity_times_factor() -> void:
	var m := _plain_market()
	T.eq(m.sell_price(&"fang"), ItemDB.price(&"fang"))
	T.eq(m.sell_price(&"mat_slime_gel"), ItemDB.price(&"mat_slime_gel"))


func test_factor_drops_15_percent_per_sale_down_to_40() -> void:
	var m := _plain_market()
	var run := RunState.new()
	run.inventory.add(&"armor_scale", 6)
	var base := ItemDB.price(&"armor_scale")
	var expected: Array[float] = [1.0, 0.85, 0.7, 0.55, 0.4, 0.4]
	for i in expected.size():
		T.near(m.factor(&"armor_scale"), expected[i])
		T.eq(m.sell(run, i), roundi(base * expected[i]))
	T.eq(run.gold, roundi(base * (1.0 + 0.85 + 0.7 + 0.55 + 0.4 + 0.4)))
	T.eq(run.inventory.count(&"armor_scale"), 0)


func test_decay_is_per_item() -> void:
	var m := _plain_market()
	var run := RunState.new()
	run.inventory.add(&"fang")
	m.sell(run, 0)
	T.near(m.factor(&"fang"), 0.85)
	T.near(m.factor(&"spark"), 1.0)


func test_factor_recovers_half_on_each_return() -> void:
	var m := _plain_market()
	var run := RunState.new()
	run.inventory.add(&"fang", 4)
	for i in 4:
		m.sell(run, i)
	T.near(m.factor(&"fang"), 0.4)
	m.begin_visit(_rng(2))
	T.near(m.factor(&"fang"), 0.7)
	m.begin_visit(_rng(3))
	T.near(m.factor(&"fang"), 0.85)


func test_first_visit_does_not_recover() -> void:
	var m := Market.new()
	m.factors[&"fang"] = 0.4
	m.begin_visit(_rng(1))
	T.near(m.factor(&"fang"), 0.4)


func test_wanted_pays_50_percent_more() -> void:
	var m := _plain_market()
	var normal := m.sell_price(&"mat_beetle_horn")
	m.wanted = [&"mat_beetle_horn", &"fang"] as Array[StringName]
	T.eq(m.sell_price(&"mat_beetle_horn"), roundi(ItemDB.price(&"mat_beetle_horn") * 1.5))
	T.ok(m.sell_price(&"mat_beetle_horn") > normal, "wanted pays more")


func test_sell_one_unit_from_stack() -> void:
	var m := _plain_market()
	var run := RunState.new()
	run.inventory.add(&"mat_slime_gel", 5)
	T.eq(m.sell(run, 0), ItemDB.price(&"mat_slime_gel"))
	T.eq(run.inventory.count(&"mat_slime_gel"), 4)


func test_sell_empty_slot_gives_nothing() -> void:
	var m := _plain_market()
	var run := RunState.new()
	T.eq(m.sell(run, 0), 0)
	T.eq(run.gold, 0)


func test_buy_puts_item_in_backpack() -> void:
	var m := _plain_market()
	var id: StringName = m.stock[0]
	var run := RunState.new()
	run.gold = 5000
	T.eq(m.buy(run, 0), true)
	T.eq(run.gold, 5000 - m.buy_price(id))
	T.eq(run.inventory.count(id), 1)
	T.ok(not m.stock.has(id), "out of stock")


func test_buy_no_gold() -> void:
	var m := _plain_market()
	var run := RunState.new()
	run.gold = 1
	T.eq(m.buy(run, 0), false)
	T.eq(run.gold, 1)
	T.ok(run.inventory.is_empty(), "nothing bought")
	T.eq(m.stock.size(), Market.STOCK_SIZE)


func test_buy_backpack_full() -> void:
	var m := _plain_market()
	var run := RunState.new()
	run.gold = 5000
	run.inventory.add(&"fang", 8)
	T.eq(m.buy(run, 0), false)
	T.eq(run.gold, 5000)
	T.eq(m.stock.size(), Market.STOCK_SIZE)


func test_buy_outfit_unlocks_once() -> void:
	var m := _plain_market()
	var run := RunState.new()
	run.gold = 5000
	T.ok(m.outfits().has(&"outfit_casaco_longo"), "market sells this outfit")
	T.eq(m.buy_outfit(run, &"outfit_casaco_longo"), true)
	T.ok(run.unlocked_outfits.has(&"outfit_casaco_longo"), "unlocked")
	var gold := run.gold
	T.eq(m.buy_outfit(run, &"outfit_casaco_longo"), false, "already owned")
	T.eq(run.gold, gold)
