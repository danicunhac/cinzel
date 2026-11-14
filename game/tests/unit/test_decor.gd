extends RefCounted
## Room decor (DecorLayout via build_rooms.gd): props only along the walls,
## never near doors, the entry, the stairs, spawns or the chest, and the
## solid ones never cut a path.

const CLEAR := 48.0
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


func _room(path: String) -> Room:
	var room := (load(path) as PackedScene).instantiate() as Room
	_tree().root.add_child(room)
	return room


func _keep_clear(room: Room) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for path: NodePath in [^"Exit", ^"Back", ^"Entry", ^"StairsSpot", ^"ChestSpot"]:
		var n := room.get_node_or_null(path) as Node2D
		if n != null:
			out.append(n.position)
	for m in room.get_node(^"Spawns").get_children():
		out.append((m as Node2D).position)
	return out


func _props(room: Room) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	var decor := room.get_node_or_null(^"Decor")
	if decor == null:
		return out
	for c in decor.get_children():
		out.append(c as Sprite2D)
	return out


func _top_rows(walls: TileMapLayer) -> int:
	var top := 0
	while walls.get_cell_source_id(Vector2i(15, top)) != -1 and top < 16:
		top += 1
	return top


func test_every_room_has_decor() -> void:
	for path in _all_rooms():
		var room := _room(path)
		var props := _props(room)
		T.ok(props.size() >= 6, "%s has %d props" % [path, props.size()])
		T.ok(room.get_node(^"Decor").get(&"y_sort_enabled"), "%s decor is Y-sorted" % path)
		room.free()


func test_decor_keeps_clear_of_doors_spawns_stairs_chest() -> void:
	for path in _all_rooms():
		var room := _room(path)
		var keep := _keep_clear(room)
		for p in _props(room):
			for k in keep:
				T.ok(p.position.distance_to(k) >= CLEAR,
						"%s %s at %s is %.0f px from %s" % [path, p.name, p.position, p.position.distance_to(k), k])
		room.free()


func test_floor_decor_only_on_the_wall_band() -> void:
	for path in _all_rooms():
		var room := _room(path)
		var walls := room.walls
		var top := _top_rows(walls)
		for p in _props(room):
			if bool(p.get_meta(&"decor_wall", false)):
				# Wall pieces sit on the top wall, above the floor.
				T.ok(p.position.y <= top * 16 + 18, "%s %s on the wall" % [path, p.name])
				T.ok(not p.has_node(^"Body"), "%s %s has no collision" % [path, p.name])
				continue
			var c := Vector2i(floori(p.position.x / 16.0), floori(p.position.y / 16.0))
			T.ok(DecorLayout.in_band(c, top), "%s %s cell %s is along a wall" % [path, p.name, c])
			T.eq(walls.get_cell_source_id(c), -1, "%s %s not on a wall cell" % [path, p.name])
			var solid := bool(p.get_meta(&"decor_solid", false))
			T.eq(p.has_node(^"Body"), solid, "%s %s collision only when solid" % [path, p.name])
			if solid:
				T.ok(p.get_meta(&"decor_kind") in DecorLayout.SOLID, "%s %s solid kind" % [path, p.name])
		room.free()


func test_solid_decor_never_cuts_a_path() -> void:
	for path in _all_rooms():
		var room := _room(path)
		var walls := room.walls
		var blocked := {}
		for p in _props(room):
			if bool(p.get_meta(&"decor_solid", false)):
				blocked[Vector2i(floori(p.position.x / 16.0), floori(p.position.y / 16.0))] = true
		var start := Vector2i((room.entry.position / 16.0).floor())
		var seen := {start: true}
		var queue: Array[Vector2i] = [start]
		while not queue.is_empty():
			var c: Vector2i = queue.pop_back()
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := c + d
				if n.x < 0 or n.y < 0 or n.x >= 30 or n.y >= 16:
					continue
				if seen.has(n) or blocked.has(n) or walls.get_cell_source_id(n) != -1:
					continue
				seen[n] = true
				queue.append(n)
		var targets: Array[Vector2] = []
		for m in room.get_node(^"Spawns").get_children():
			targets.append((m as Node2D).position)
		for np: NodePath in [^"ChestSpot", ^"StairsSpot"]:
			var n := room.get_node_or_null(np) as Node2D
			if n != null:
				targets.append(n.position)
		if room.exit_door != null:
			targets.append(room.exit_door.arrival())
		for t in targets:
			var c := Vector2i((t / 16.0).floor())
			T.ok(seen.has(c), "%s %s reachable from the entry" % [path, t])
		room.free()
