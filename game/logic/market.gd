class_name Market
extends RefCounted
## Town market with supply and demand.
##   sell price = ItemDB.price (base x rarity) x factor of the item, +50% when
##   the market wants it this visit (2 items drawn per visit).
##   Each unit sold drops that item's factor by 0.15, down to 0.4.
##   Each return from the tower moves every factor halfway back to 1.0.
## The market also sells a small stock (3 items) and the market outfits.
## Stock and wanted items follow the floors the player has opened: rare gear
## from floor 2, epic from floor 3; materials of opened floors only.

const STOCK_SIZE := 3
const WANTED_COUNT := 2
const DECAY_PER_SALE := 0.15
const MIN_FACTOR := 0.4
const RECOVERY := 0.5
const WANTED_BONUS := 1.5
## Buying costs this much more than the market pays at factor 1.0.
const BUY_MARKUP := 1.6
## Kinds the market trades in (outfits are sold apart, see outfits()).
const TRADE_KINDS: Array[StringName] = [&"weapon", &"armor", &"helm", &"backpack", &"relic", &"material"]
const STOCK_KINDS: Array[StringName] = [&"weapon", &"armor", &"helm", &"backpack", &"relic"]
## First floor on which each rarity shows up in the stock.
const RARITY_FLOOR: Dictionary[StringName, int] = {&"common": 1, &"rare": 2, &"epic": 3}

## Supply/demand factor per item id; missing means 1.0.
var factors: Dictionary[StringName, float] = {}
var wanted: Array[StringName] = []
var stock: Array[StringName] = []
var visits: int = 0


## Called each time the player arrives in town. From the second visit on,
## factors recover; then the wanted items and the stock are drawn again, from
## what the `floors` opened so far can offer.
func begin_visit(rng: RandomNumberGenerator, floors: int = RunState.MAX_FLOOR) -> void:
	if visits > 0:
		recover()
	visits += 1
	wanted = _draw(_pool(TRADE_KINDS, floors), WANTED_COUNT, rng)
	stock = _draw(_pool(STOCK_KINDS, floors), STOCK_SIZE, rng)


func recover() -> void:
	for id: StringName in factors.keys():
		factors[id] = snappedf(factors[id] + (1.0 - factors[id]) * RECOVERY, 0.0001)
		if factors[id] >= 1.0:
			factors.erase(id)


func factor(id: StringName) -> float:
	return factors.get(id, 1.0)


func is_wanted(id: StringName) -> bool:
	return wanted.has(id)


## Today's trend for the shop arrow: 1 wanted (+50%), -1 saturated (sold
## too much, factor under 1), 0 normal. Wanted wins over saturated.
func trend(id: StringName) -> int:
	if is_wanted(id):
		return 1
	return -1 if factor(id) < 1.0 else 0


## Gold for selling `n` units of `id` one after the other: each sale lowers
## the factor before the next one (same rule as sell()).
func sell_total(id: StringName, n: int) -> int:
	var f := factor(id)
	var bonus := WANTED_BONUS if is_wanted(id) else 1.0
	var total := 0
	for i in n:
		total += roundi(ItemDB.price(id) * f * bonus)
		f = snappedf(maxf(MIN_FACTOR, f - DECAY_PER_SALE), 0.0001)
	return total


## Sells up to `n` units from backpack `slot`. Returns the gold received.
func sell_many(run: RunState, slot: int, n: int) -> int:
	var total := 0
	for i in n:
		var got := sell(run, slot)
		if got <= 0:
			break
		total += got
	return total


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


## Ids of `kinds` the opened `floors` can offer, without the starter kit.
func _pool(kinds: Array[StringName], floors: int = RunState.MAX_FLOOR) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ItemDB.ids():
		if kinds.has(ItemDB.kind(id)) and id != Equipment.STARTER_WEAPON and id != Equipment.STARTER_BACKPACK \
				and available(id, floors):
			out.append(id)
	return out


## Whether `id` can be in the stock or wanted list with `floors` opened.
## Materials need their floor open (the boss crystal: floor 2); gear needs
## the floor of its rarity (RARITY_FLOOR).
static func available(id: StringName, floors: int) -> bool:
	if ItemDB.kind(id) == &"material":
		var f := int(ItemCatalog.ITEMS[id]["floor"])
		return (f if f > 0 else 2) <= floors
	return RARITY_FLOOR.get(ItemDB.rarity(id), 1) <= floors


func _draw(pool: Array[StringName], n: int, rng: RandomNumberGenerator) -> Array[StringName]:
	var out: Array[StringName] = []
	while out.size() < n and not pool.is_empty():
		var i := rng.randi_range(0, pool.size() - 1)
		out.append(pool[i])
		pool.remove_at(i)
	return out
