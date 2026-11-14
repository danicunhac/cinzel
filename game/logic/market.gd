class_name Market
extends RefCounted
## Town market with supply and demand.
##   sell price = ItemDB.price (base x rarity) x factor of the item, +50% when
##   the market wants it this visit (2 items drawn per visit).
##   Each unit sold drops that item's factor by 0.15, down to 0.4.
##   Each return from the tower moves every factor halfway back to 1.0.
## The market also sells a small stock (3 items) and the market outfits.

const STOCK_SIZE := 3
const WANTED_COUNT := 2
const DECAY_PER_SALE := 0.15
const MIN_FACTOR := 0.4
const RECOVERY := 0.5
const WANTED_BONUS := 1.5
## Buying costs this much more than the market pays at factor 1.0.
const BUY_MARKUP := 2.0
## Kinds the market trades in (outfits are sold apart, see outfits()).
const TRADE_KINDS: Array[StringName] = [&"weapon", &"armor", &"helm", &"backpack", &"relic", &"material"]
const STOCK_KINDS: Array[StringName] = [&"weapon", &"armor", &"helm", &"backpack", &"relic"]

## Supply/demand factor per item id; missing means 1.0.
var factors: Dictionary[StringName, float] = {}
var wanted: Array[StringName] = []
var stock: Array[StringName] = []
var visits: int = 0


## Called each time the player arrives in town. From the second visit on,
## factors recover; then the wanted items and the stock are drawn again.
func begin_visit(rng: RandomNumberGenerator) -> void:
	if visits > 0:
		recover()
	visits += 1
	wanted = _draw(_pool(TRADE_KINDS), WANTED_COUNT, rng)
	stock = _draw(_pool(STOCK_KINDS), STOCK_SIZE, rng)


func recover() -> void:
	for id: StringName in factors.keys():
		factors[id] = snappedf(factors[id] + (1.0 - factors[id]) * RECOVERY, 0.0001)
		if factors[id] >= 1.0:
			factors.erase(id)


func factor(id: StringName) -> float:
	return factors.get(id, 1.0)


func is_wanted(id: StringName) -> bool:
	return wanted.has(id)


## What the market pays for one unit of `id` now.
func sell_price(id: StringName) -> int:
	var p := ItemDB.price(id) * factor(id) * (WANTED_BONUS if is_wanted(id) else 1.0)
	return roundi(p)


## What the player pays for `id` (not affected by supply and demand).
func buy_price(id: StringName) -> int:
	return roundi(ItemDB.price(id) * BUY_MARKUP)


## Sells one unit from backpack `slot`. Returns the gold received (0 = nothing sold).
func sell(run: RunState, slot: int) -> int:
	var id := run.inventory.id_at(slot)
	if id == &"" or not TRADE_KINDS.has(ItemDB.kind(id)):
		return 0
	var gold := sell_price(id)
	run.inventory.remove_at(slot)
	factors[id] = snappedf(maxf(MIN_FACTOR, factor(id) - DECAY_PER_SALE), 0.0001)
	run.add_gold(gold)
	return gold


## Buys stock item `index` into the backpack. Needs gold and a free slot.
func buy(run: RunState, index: int) -> bool:
	if index < 0 or index >= stock.size():
		return false
	var id := stock[index]
	var price := buy_price(id)
	if price > run.gold or run.inventory.free_slots() <= 0:
		return false
	run.spend_gold(price)
	run.inventory.add(id)
	run.changed.emit()
	stock.remove_at(index)
	return true


## Outfits that can be bought here.
func outfits() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ItemDB.ids(&"outfit"):
		if ItemCatalog.ITEMS[id]["unlock"] == &"market":
			out.append(id)
	return out


func buy_outfit(run: RunState, id: StringName) -> bool:
	if not outfits().has(id) or run.unlocked_outfits.has(id):
		return false
	if not run.spend_gold(buy_price(id)):
		return false
	run.unlock_outfit(id)
	return true


## Ids of `kinds`, without the starter kit.
func _pool(kinds: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ItemDB.ids():
		if kinds.has(ItemDB.kind(id)) and id != Equipment.STARTER_WEAPON and id != Equipment.STARTER_BACKPACK:
			out.append(id)
	return out


func _draw(pool: Array[StringName], n: int, rng: RandomNumberGenerator) -> Array[StringName]:
	var out: Array[StringName] = []
	while out.size() < n and not pool.is_empty():
		var i := rng.randi_range(0, pool.size() - 1)
		out.append(pool[i])
		pool.remove_at(i)
	return out
