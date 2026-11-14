class_name TownLogic
extends RefCounted
## Pure rules of the town (no nodes), so tests can check them directly.

## DP 2.1: a speech bubble holds at most 25 words in at most 3 lines.
const BUBBLE_MAX_WORDS := 25
const BUBBLE_MAX_LINES := 3


## Spot id closest to `pos` within `reach`, or &"" when none is in reach.
static func nearest_spot(pos: Vector2, spots: Dictionary[StringName, Vector2], reach: float) -> StringName:
	var best: StringName = &""
	var best_d := reach
	for id: StringName in spots:
		var d := pos.distance_to(spots[id])
		if d < best_d:
			best_d = d
			best = id
	return best


## Whether the spot has something to do right now. The shop always can (buy
## or sell), the smith needs two items to trade, the crystal always works.
static func can_act(id: StringName, item_count: int) -> bool:
	match id:
		&"shop", &"teleport":
			return true
		&"smith":
			return item_count >= 2
	return false


## The ring and glow show only on the spot the player is at, and only when
## there is an action to take there.
static func cta_visible(id: StringName, near: StringName, item_count: int) -> bool:
	return id != &"" and id == near and can_act(id, item_count)


static func word_count(text: String) -> int:
	return text.split(" ", false).size()


static func bubble_fits(text: String) -> bool:
	return word_count(text) <= BUBBLE_MAX_WORDS
