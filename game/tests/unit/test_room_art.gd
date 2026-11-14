extends RefCounted
## Painted rooms: every room scene shows a 480x270 painting and still blocks
## movement on its wall cells (the hidden Walls layer).

const ROOMS: Array[String] = [
	"res://world/rooms/tutorial/t1_move_attack.tscn",
	"res://world/rooms/tutorial/t2_dodge.tscn",
	"res://world/rooms/tutorial/t3_heal.tscn",
	"res://world/rooms/boss_f1.tscn",
	"res://world/rooms/boss_f2.tscn",
	"res://world/rooms/boss_f3.tscn",
]


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _all_rooms() -> Array[String]:
	var out: Array[String] = []
	out.assign(ROOMS)
	out.append_array(Dungeon.templates_for(1))
	return out


func test_every_room_has_a_480x270_background() -> void:
	for path in _all_rooms():
		var room := (load(path) as PackedScene).instantiate() as Room
		var bg := room.get_node_or_null(^"Background") as Sprite2D
		T.ok(bg != null, "%s has Background" % path)
		if bg != null:
			T.ok(bg.texture != null, "%s texture" % path)
			T.eq(bg.texture.get_size(), Vector2(480, 270), "%s size" % path)
			T.eq(bg.centered, false, "%s top-left anchored" % path)
		T.eq(room.get_node(^"Walls").visible, false, "%s walls are collision only" % path)
		T.ok(room.has_node(^"Torches") and room.get_node(^"Torches").get_child_count() > 0, "%s torches" % path)
		room.free()


func test_wall_cells_still_block() -> void:
	for path in _all_rooms():
		var room := (load(path) as PackedScene).instantiate() as Room
		_tree().root.add_child(room)
		await _tree().physics_frame
		await _tree().physics_frame
		var space := room.get_world_2d().direct_space_state
		var walls := room.walls
		var checked := 0
		for c in walls.get_used_cells():
			var pos := room.to_global(walls.map_to_local(c))
			var q := PhysicsPointQueryParameters2D.new()
			q.position = pos
			var hits := space.intersect_point(q, 1)
			T.ok(not hits.is_empty(), "%s cell %s blocks" % [path, c])
			checked += 1
			if not T.failures.is_empty():
				break
		T.ok(checked > 80, "%s checked %d wall cells" % [path, checked])
		# An open floor cell (the entry) does not block.
		var q2 := PhysicsPointQueryParameters2D.new()
		q2.position = room.to_global(room.entry.position)
		T.ok(space.intersect_point(q2, 1).is_empty(), "%s entry cell is open" % path)
		room.free()


func test_exit_door_overlay_follows_state() -> void:
	var room := (load("res://world/rooms/f1/f1_colunas.tscn") as PackedScene).instantiate() as Room
	_tree().root.add_child(room)
	await _tree().process_frame
	var sprite := room.exit_door.get_node(^"Sprite") as Sprite2D
	T.eq(sprite.frame % sprite.hframes, RoomDoor.FRAME_LOCKED, "locked")
	room.exit_door.set_open(true)
	T.eq(sprite.frame % sprite.hframes, RoomDoor.FRAME_OPEN, "open")
	room.free()
