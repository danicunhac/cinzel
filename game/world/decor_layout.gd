class_name DecorLayout
extends RefCounted
## Where build_rooms.gd puts the decor props of a room (art from
## res://assets/rooms/decor.png, 12 frames of 32x32 in FRAMES order).
## Same layout, same props: the rng is seeded by the caller.
## Rules:
##   - Floor props only on the edge band (the first floor cell along the side
##     and bottom walls, and the row under the top wall face), never on a
##     lane through the room.
##   - Nothing within CLEAR px of a door, the entry, the stairs spot, a spawn
##     or the chest spot.
##   - Solid props (barrel, crate, rack) only in corners and next to them,
##     and only if every walkable cell stays reachable from the entry.
##   - Wall pieces (banner, chains, cobwebs) sit on the wall, never on floor.

const FRAMES: Array[StringName] = [
	&"barrel", &"crate", &"bones", &"skulls", &"pot", &"candles",
	&"chains", &"rubble", &"moss", &"banner", &"rack", &"cobweb",
]
const SOLID: Array[StringName] = [&"barrel", &"crate", &"rack"]
const DECALS: Array[StringName] = [&"bones", &"skulls", &"pot", &"candles", &"rubble", &"moss", &"bones", &"rubble", &"moss"]
const WALL: Array[StringName] = [&"banner", &"chains"]
## Props that cast a ground shadow (flat decals do not).
const SHADOWED: Array[StringName] = [&"barrel", &"crate", &"rack", &"pot", &"candles", &"skulls"]
const CELL := 16
const W := 30
const H := 16
const CLEAR := 48.0
## Floor props keep this far apart.
const SPACING := 34.0
const MAX_FLOOR := 14
## Top-wall columns free of the torches (7, 22) and of the banners most
## paintings already have (about 10 and 20).
const WALL_COLS: Array[int] = [3, 4, 14, 15, 16, 25, 26]
const WALKABLE := ".,~cshBHFC"


## Spots for `rows` (the 30x16 layout). `keep_clear`: world points (door
## centres, entry, stairs, spawns, chest) no prop may come within CLEAR of.
## Each spot: {"kind": StringName, "pos": Vector2 (feet), "cell": Vector2i,
## "solid": bool, "wall": bool, "flip": bool}.
static func spots(rows: Array[String], keep_clear: Array[Vector2], rng: RandomNumberGenerator,
		tutorial: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var top := top_rows(rows)
	var band := edge_band(rows)
	var free: Array[Vector2i] = []
	for c in band:
		if _clear_of(feet(c), keep_clear):
			free.append(c)
	_shuffle(free, rng)
	var solid_cells: Array[Vector2i] = []
	# Corners first: a solid prop, sometimes a second one along the wall.
	for c in free.duplicate():
		if not is_corner(rows, c) or not _spaced(feet(c), out, 24.0):
			continue
		var kind: StringName = SOLID[rng.randi_range(0, 1)]
		if (c.y == H - 2 or c.y == top + (1 if top == 1 else 0)) and rng.randf() < 0.3:
			kind = &"rack"
		if not _keeps_paths(rows, _with(solid_cells, c)):
			continue
		solid_cells.append(c)
		out.append(_spot(kind, c, true))
		free.erase(c)
		var along := _along_wall(rows, c, band)
		if along != Vector2i(-1, -1) and along in free and rng.randf() < 0.6 \
				and _keeps_paths(rows, _with(solid_cells, along)):
			solid_cells.append(along)
			out.append(_spot(SOLID[rng.randi_range(0, 1)], along, true))
			free.erase(along)
	# Then flat decals along the walls, spaced out.
	var floor_count := out.size()
	for c in free:
		if floor_count >= MAX_FLOOR:
			break
		if not _spaced(feet(c), out, SPACING):
			continue
		var kind := DECALS[rng.randi_range(0, DECALS.size() - 1)]
		var s := _spot(kind, c, false)
		s["flip"] = rng.randf() < 0.5
		out.append(s)
		floor_count += 1
	# Cobwebs in the two top corners, on the wall.
	var web_y := float(top * CELL) + (17.0 if top == 1 else 9.0)
	for side in [0, 1]:
		var pos := Vector2(28.0 if side == 0 else W * CELL - 28.0, web_y)
		if _clear_of(pos, keep_clear):
			out.append({"kind": &"cobweb", "pos": pos, "cell": Vector2i(-1, -1), "solid": false, "wall": true, "flip": side == 0})
	# One or two wall pieces on the top wall face (not over the tutorial sign).
	if not tutorial and top == 1:
		var cols := WALL_COLS.duplicate()
		_shuffle(cols, rng)
		var placed := 0
		for col: int in cols:
			if placed >= 2:
				break
			if _ch(rows, Vector2i(col, 0)) != "#" or _ch(rows, Vector2i(col, 1)) == "#":
				continue
			var pos := Vector2(col * CELL + 8, 30.0)
			if not _clear_of(pos, keep_clear) or not _spaced(pos, out, 48.0):
				continue
			out.append({"kind": WALL[rng.randi_range(0, WALL.size() - 1)], "pos": pos, "cell": Vector2i(-1, -1), "solid": false, "wall": true, "flip": false})
			placed += 1
	return out


## Wall rows at the top (1 normally, 4 for the tutorial's thick wall).
static func top_rows(rows: Array[String]) -> int:
	var top := 0
	while top < H and _ch(rows, Vector2i(1, top)) == "#":
		top += 1
	return top


## Plain floor cells along the outer walls: column 1 and W-2, the bottom row
## and the first row clear of the top wall face.
static func edge_band(rows: Array[String]) -> Array[Vector2i]:
	var top := top_rows(rows)
	var first := top + (1 if top == 1 else 0)
	var out: Array[Vector2i] = []
	for y in range(first, H - 1):
		for x in range(1, W - 1):
			var c := Vector2i(x, y)
			if not in_band(c, top):
				continue
			if ".,~".contains(_ch(rows, c)):
				out.append(c)
	return out


static func in_band(c: Vector2i, top: int) -> bool:
	var first := top + (1 if top == 1 else 0)
	return c.x == 1 or c.x == W - 2 or c.y == H - 2 or c.y == first


## A cell with walls (outer or inner) on two orthogonal sides.
static func is_corner(rows: Array[String], c: Vector2i) -> bool:
	var top := top_rows(rows)
	var first := top + (1 if top == 1 else 0)
	var up := _ch(rows, c + Vector2i.UP) == "#" or c.y == first
	var down := _ch(rows, c + Vector2i.DOWN) == "#"
	var left := _ch(rows, c + Vector2i.LEFT) == "#"
	var right := _ch(rows, c + Vector2i.RIGHT) == "#"
	return (up or down) and (left or right)


## Where a prop on `c` stands: the cell centre, 6 px down (feet for Y-sort).
static func feet(c: Vector2i) -> Vector2:
	return Vector2(c * CELL) + Vector2(8, 14)


static func _spot(kind: StringName, c: Vector2i, solid: bool) -> Dictionary:
	return {"kind": kind, "pos": feet(c), "cell": c, "solid": solid, "wall": false, "flip": false}


static func _along_wall(rows: Array[String], c: Vector2i, band: Array[Vector2i]) -> Vector2i:
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var n := c + d
		if n in band and _ch(rows, n) != "#":
			return n
	return Vector2i(-1, -1)


static func _with(cells: Array[Vector2i], c: Vector2i) -> Array[Vector2i]:
	var out := cells.duplicate()
	out.append(c)
	return out


static func _clear_of(p: Vector2, keep_clear: Array[Vector2]) -> bool:
	for k in keep_clear:
		if p.distance_to(k) < CLEAR:
			return false
	return true


static func _spaced(p: Vector2, placed: Array[Dictionary], gap: float) -> bool:
	for s in placed:
		if not bool(s["wall"]) and p.distance_to(s["pos"]) < gap:
			return false
	return true


## True when every walkable cell is still reachable from every other with
## `blocked` cells taken out (solid props never cut the room).
static func _keeps_paths(rows: Array[String], blocked: Array[Vector2i]) -> bool:
	var cells: Array[Vector2i] = []
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			if WALKABLE.contains(_ch(rows, c)) and not c in blocked:
				cells.append(c)
	if cells.is_empty():
		return true
	var seen := {cells[0]: true}
	var queue: Array[Vector2i] = [cells[0]]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + d
			if not seen.has(n) and WALKABLE.contains(_ch(rows, n)) and not n in blocked:
				seen[n] = true
				queue.append(n)
	return seen.size() == cells.size()


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t


static func _ch(rows: Array[String], c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H:
		return "#"
	return rows[c.y][c.x]
