extends RefCounted


func _templates(n: int) -> Array[String]:
	var out: Array[String] = []
	for i in n:
		out.append("res://world/rooms/r%d.tscn" % i)
	return out


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func test_floor1_with_tutorial() -> void:
	var plan: Array[String] = FloorPlan.build(1, _templates(8), _rng(1), true)
	T.eq(plan[0], "res://world/rooms/tutorial/t1_move_attack.tscn")
	T.eq(plan[1], "res://world/rooms/tutorial/t2_dodge.tscn")
	T.eq(plan[2], "res://world/rooms/tutorial/t3_heal.tscn")
	T.eq(plan[plan.size() - 1], "res://world/rooms/boss_f1.tscn")
	T.ok(plan.size() >= 8 and plan.size() <= 9)


func test_no_repeat_templates() -> void:
	for s in 20:
		var plan: Array[String] = FloorPlan.build(2, _templates(8), _rng(s), false)
		var seen := {}
		for p in plan:
			T.ok(not seen.has(p))
			seen[p] = true


func test_floor3_boss_last() -> void:
	var plan: Array[String] = FloorPlan.build(3, _templates(8), _rng(5), false)
	T.eq(plan[plan.size() - 1], "res://world/rooms/boss_f3.tscn")


func test_chest_rooms_range() -> void:
	for s in 20:
		var count: int = FloorPlan.build(1, _templates(8), _rng(s), false).size() - 1
		var chests: Array[int] = FloorPlan.chest_rooms(count, _rng(s))
		T.ok(chests.size() >= 1 and chests.size() <= 2)
		if chests.size() == 2:
			T.ok(chests[0] != chests[1])
		for c in chests:
			T.ok(c >= 0 and c < count)
