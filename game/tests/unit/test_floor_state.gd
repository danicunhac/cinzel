extends RefCounted


func _plan() -> Array[String]:
	var p: Array[String] = ["a", "b", "c"]
	return p


func test_start_floor_keeps_plan_and_fresh_rooms() -> void:
	var s := FloorState.new()
	T.ok(not s.has_floor(1))
	var chests: Array[int] = [1]
	var rec := s.start_floor(1, _plan(), chests)
	T.ok(s.has_floor(1))
	T.eq(rec.plan, _plan())
	T.eq(rec.chest_rooms, chests)
	T.eq(rec.index, 0)
	T.eq(rec.rooms.size(), 3)
	for r in rec.rooms:
		T.eq(r.cleared, false)
		T.ok(r.chests_opened.is_empty() and r.floor_items.is_empty())
	T.ok(s.get_floor(1) == rec)


func test_room_saves_are_kept_per_floor() -> void:
	var s := FloorState.new()
	var none: Array[int] = []
	s.start_floor(1, _plan(), none)
	s.start_floor(2, _plan(), none)
	s.room(1, 1).cleared = true
	s.room(1, 1).chests_opened.append(0)
	s.room(1, 1).floor_items.append({"id": &"ring_vigor", "qty": 1, "pos": Vector2(10, 20)})
	T.eq(s.room(1, 1).cleared, true)
	T.eq(s.room(1, 1).chests_opened, [0])
	T.eq(s.room(1, 1).floor_items[0]["pos"], Vector2(10, 20))
	T.eq(s.room(2, 1).cleared, false, "other floor untouched")
	T.eq(s.room(1, 9), null, "out of range")
	T.eq(s.room(3, 0), null, "unknown floor")
	T.eq(s.floor_count(), 2)


func test_start_floor_again_replaces_it_and_reset_forgets_all() -> void:
	var s := FloorState.new()
	var none: Array[int] = []
	s.start_floor(1, _plan(), none)
	s.room(1, 0).cleared = true
	s.start_floor(1, _plan(), none)
	T.eq(s.room(1, 0).cleared, false, "regenerated")
	s.reset()
	T.eq(s.has_floor(1), false)
	T.eq(s.floor_count(), 0)
