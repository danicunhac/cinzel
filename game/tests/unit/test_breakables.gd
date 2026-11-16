extends RefCounted
## Detailed rooms (pilot: f1_arena): breakable pots and crates that a player
## hit smashes (and enemy hits do not), their drops, their place in the room
## (never cutting a path) and the decals and atmosphere around them.

const ARENA := "res://world/rooms/f1/f1_arena.tscn"
const BreakableScene := preload("res://world/breakable.tscn")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _room() -> Room:
	var room := (load(ARENA) as PackedScene).instantiate() as Room
	_tree().root.add_child(room)
	return room


func _prop(kind: StringName = &"pot") -> Array:
	var holder := Node2D.new()
	_tree().root.add_child(holder)
	var b := BreakableScene.instantiate() as Breakable
	b.kind = kind
	b.position = Vector2(100, 100)
	holder.add_child(b)
	return [holder, b]


func _hit(team: StringName) -> Hitbox:
	var h := Hitbox.new()
	h.team = team
	h.damage = 10
	return h


func test_arena_has_breakables_details_and_atmosphere() -> void:
	var room := _room()
	var props := room.breakables()
	T.ok(props.size() >= 3, "arena has %d breakables" % props.size())
	T.ok(room.get_node(^"Breakables").get(&"y_sort_enabled"), "breakables are Y-sorted")
	for b in props:
		T.ok(b.kind in DecorLayout.BREAKABLE_KINDS, "%s kind %s" % [b.name, b.kind])
		T.ok(not b.shape.disabled, "%s blocks while whole" % b.name)
	var details := room.get_node(^"Details")
	T.ok(details.get_child_count() >= 20, "arena has %d decals" % details.get_child_count())
	T.ok((details as Node2D).z_index < 0, "decals under the actors")
	T.ok(room.get_node_or_null(^"Atmosphere") is RoomAtmosphere, "arena has an atmosphere")
	room.free()


func test_other_rooms_stay_plain() -> void:
	var room := (load("res://world/rooms/f1/f1_colunas.tscn") as PackedScene).instantiate() as Room
	T.eq(room.get_node_or_null(^"Breakables"), null, "no breakables outside the pilot")
	T.eq(room.get_node_or_null(^"Atmosphere"), null, "no atmosphere outside the pilot")
	room.free()


func test_breakables_on_the_wall_band_clear_of_doors_and_spawns() -> void:
	var room := _room()
	var keep: Array[Vector2] = []
	for path: NodePath in [^"Exit", ^"Back", ^"Entry", ^"StairsSpot", ^"ChestSpot"]:
		var n := room.get_node_or_null(path) as Node2D
		if n != null:
			keep.append(n.position)
	for m in room.get_node(^"Spawns").get_children():
		keep.append((m as Node2D).position)
	for b in room.breakables():
		var c := Vector2i(floori(b.position.x / 16.0), floori(b.position.y / 16.0))
		T.ok(DecorLayout.in_band(c, 1), "%s cell %s along a wall" % [b.name, c])
		for k in keep:
			T.ok(b.position.distance_to(k) >= DecorLayout.CLEAR, "%s %.0f px from %s" % [b.name, b.position.distance_to(k), k])
	room.free()


func test_breakables_never_cut_a_path() -> void:
	var room := _room()
	var blocked := {}
	for p in room.get_node(^"Decor").get_children():
		if bool(p.get_meta(&"decor_solid", false)):
			blocked[Vector2i(((p as Node2D).position / 16.0).floor())] = true
	for b in room.breakables():
		blocked[Vector2i((b.position / 16.0).floor())] = true
	var walls := room.walls
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
	var free_cells := 0
	for y in range(1, 15):
		for x in range(1, 29):
			var c := Vector2i(x, y)
			if walls.get_cell_source_id(c) == -1 and not blocked.has(c):
				free_cells += 1
				T.ok(seen.has(c), "cell %s reachable from the entry" % c)
	T.ok(free_cells > 300, "%d free cells" % free_cells)
	room.free()


func test_player_hit_smashes_the_prop() -> void:
	var made := _prop(&"pot")
	var holder := made[0] as Node2D
	var b := made[1] as Breakable
	var h := _hit(&"player")
	b.gold_chance = 0.0
	b.material_chance = 0.0
	T.ok(b.hurtbox.receive(h), "the player's hit lands")
	T.ok(b.broken, "smashed")
	T.eq(b.sprite.frame, 1, "cracked frame first")
	T.eq(b.z_index, Breakable.DEBRIS_Z, "debris under the actors")
	await _tree().create_timer(Breakable.CRACK_TIME + 0.05).timeout
	T.eq(b.sprite.frame, 2, "then the debris frame")
	T.ok(b.shape.disabled, "debris does not block")
	T.ok(not b.hurtbox.monitorable, "debris takes no more hits")
	T.ok(not (b.get_node(^"Shadow") as CanvasItem).visible, "no shadow under debris")
	h.free()
	holder.free()


func test_crate_uses_its_own_row() -> void:
	var made := _prop(&"crate")
	var b := made[1] as Breakable
	T.eq(b.sprite.frame, 3, "crate intact frame")
	b.show_broken()
	T.eq(b.sprite.frame, 5, "crate debris frame")
	(made[0] as Node).free()


func test_enemy_hits_pass_through() -> void:
	var made := _prop()
	var b := made[1] as Breakable
	var h := _hit(&"enemy")
	T.ok(not b.hurtbox.receive(h), "an enemy hit is not taken (shots fly on)")
	T.ok(not b.broken, "still whole")
	h.free()
	(made[0] as Node).free()


func test_smash_drops_coins() -> void:
	var made := _prop()
	var holder := made[0] as Node2D
	var b := made[1] as Breakable
	b.gold_chance = 1.0
	b.material_chance = 0.0
	Breakable.rng = RandomNumberGenerator.new()
	Breakable.rng.seed = 7
	b.smash()
	await _tree().process_frame
	var coins := holder.get_children().filter(func(n: Node) -> bool: return n is PickupGold)
	T.ok(coins.size() >= Breakable.COINS.x and coins.size() <= Breakable.COINS.y, "%d coins" % coins.size())
	for c: PickupGold in coins:
		T.eq(c.amount, 1, "a coin each")
		T.ok(c.position.distance_to(b.position) <= Breakable.DROP_SPREAD + 0.5, "coins land by the prop")
	Breakable.rng = null
	holder.free()


func test_drop_roll_odds_and_material() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var none := Breakable.roll(r, 1, 0.0, 0.0)
	T.eq(none["gold"], 0, "no gold at chance 0")
	T.eq(none["material"], &"", "no material at chance 0")
	var mats: Array[StringName] = [&"mat_old_leather", &"mat_iron_ore", &"mat_ash_wood"]
	for i in 20:
		var all := Breakable.roll(r, 1, 1.0, 1.0)
		T.ok(int(all["gold"]) >= 1 and int(all["gold"]) <= 3, "1-3 coins")
		T.ok(all["material"] in mats, "floor 1 material %s" % all["material"])
	var gold := 0
	var mat := 0
	for i in 1000:
		var d := Breakable.roll(r, 1, 0.35, 0.06)
		gold += 1 if int(d["gold"]) > 0 else 0
		mat += 1 if d["material"] != &"" else 0
	T.ok(gold > 280 and gold < 420, "gold about 35%% (%d / 1000)" % gold)
	T.ok(mat > 25 and mat < 100, "material about 6%% (%d / 1000)" % mat)


func test_smashed_props_stay_smashed_on_return() -> void:
	var room := _room()
	var props := room.breakables()
	props[0].show_broken()
	var save := FloorState.RoomSave.new()
	room.snapshot(save)
	T.eq(save.props_broken, [String(props[0].name)] as Array[String], "the smashed prop is saved")
	room.free()
	var again := _room()
	save.cleared = true
	again.start(0, false, RandomNumberGenerator.new(), save)
	for b in again.breakables():
		T.eq(b.broken, String(b.name) in save.props_broken, "%s state comes back" % b.name)
	again.free()
