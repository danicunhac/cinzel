class_name FloorPlan
extends RefCounted

const TUTORIAL_ROOMS: Array[String] = [
	"res://world/rooms/tutorial/t1_move_attack.tscn",
	"res://world/rooms/tutorial/t2_dodge.tscn",
	"res://world/rooms/tutorial/t3_heal.tscn",
]


static func build(floor: int, templates: Array[String], rng: RandomNumberGenerator, include_tutorial: bool) -> Array[String]:
	var plan: Array[String] = []
	if include_tutorial:
		plan.append_array(TUTORIAL_ROOMS)
	if templates.size() < 4:
		push_error("FloorPlan: need at least 4 room templates, got %d" % templates.size())
	var pool: Array[String] = templates.duplicate()
	var count: int = mini(rng.randi_range(4, 5), pool.size())
	for i in count:
		var idx: int = rng.randi_range(0, pool.size() - 1)
		plan.append(pool[idx])
		pool.remove_at(idx)
	plan.append("res://world/rooms/boss_f%d.tscn" % floor)
	return plan


static func chest_rooms(count_rooms: int, rng: RandomNumberGenerator) -> Array[int]:
	var out: Array[int] = []
	if count_rooms <= 0:
		return out
	var first: int = rng.randi_range(0, count_rooms - 1)
	out.append(first)
	if count_rooms >= 2 and rng.randi_range(0, 1) == 1:
		var second: int = rng.randi_range(0, count_rooms - 2)
		if second >= first:
			second += 1
		out.append(second)
	return out
