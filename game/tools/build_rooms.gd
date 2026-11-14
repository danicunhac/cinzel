extends SceneTree
## Generates world/tiles_floor{1,2,3}.tres and the room scenes from the ASCII
## layouts below, after checking each layout (reachability, safe spawns).
## godot --headless --path game -s res://tools/build_rooms.gd
##
## Legend (30 x 16 cells of 16 px, 480 x 256):
##   #  wall (front face when the cell below is open, top otherwise)
##   .  floor        ,  cracked floor    ~  mossy floor
##   o  pillar       x  crate (both block movement and shots)
##   E  entry door (shut; the player starts on the inner neighbour)
##   X  exit door (locked until the room is cleared)
##   c  crawler      s  shooter          h  charger
##   B  big crawler boss (floor 1)       H  big charger boss (floor 2)
##   F  final boss (floor 3)             C  chest spot
## A room's optional "floor" key (default 1) picks the tileset.
##
## Painted rooms: when res://assets/rooms/<room id>.png exists (480 x 270, made
## by art-src/build_rooms_art.py from the layout dumped to LAYOUTS_JSON), the
## room shows it as a Background sprite, the Walls layer stays for collision
## only (hidden), doors get overlay sprites and the torches get lights. Rooms
## without a painting keep the tile visuals, so new templates work at once.

const W := 30
const H := 16
const TILESET_PATH := "res://world/tiles_floor%d.tres"
const TEXTURE_PATH := "res://assets/tiles/floor%d.png"
const FLOORS := 3
const ROOM_SCRIPT := "res://world/room.gd"
const DOOR_SCRIPT := "res://world/room_door.gd"
const PAINT_PATH := "res://assets/rooms/%s.png"
## Door overlays: 3 columns (shut, locked, open) x 2 rows (front, side), 16x24.
const DOORS_PATH := "res://assets/rooms/doors.png"
const DOOR_FRAME := Vector2i(16, 24)
## Layouts for the art pipeline (blockouts, alignment check).
const LAYOUTS_JSON := "res://../art-src/gen/rooms/layouts.json"
## Darkening per floor so the torch lights read.
const AMBIENT: Array[Color] = [
	Color(0.80, 0.76, 0.74), Color(0.72, 0.77, 0.84), Color(0.78, 0.70, 0.70)]
const TORCH_COLOR: Array[Color] = [
	Color(1.0, 0.72, 0.42), Color(1.0, 0.8, 0.6), Color(1.0, 0.55, 0.32)]
## No enemy starts closer than this to the player's entry point.
const MIN_SPAWN_DIST := 144.0
const WALKABLE := ".,~cshBHFC"
const ENEMY_KINDS := {
	"c": "crawler", "s": "shooter", "h": "charger",
	"B": "boss_big", "H": "boss_big", "F": "boss_final",
}
## Look of the big boss (Room meta `base`).
const BOSS_BASE := {"B": "crawler", "H": "charger"}

## Thick top wall of the tutorial rooms; the sign sits on it under the HUD.
const TUTORIAL_TOP := [
	"##############################",
	"##############################",
	"##############################",
	"##############################",
]
## Columns of the torches on the wall face of the top wall.
const TORCH_COLS: Array[int] = [7, 22]
## Torch columns on a thick top wall, clear of the tutorial sign (x 60-420).
const TORCH_COLS_SIGN: Array[int] = [2, 27]
## Tutorial sign rectangle (also a blank plaque in the painting).
const SIGN_RECT := Rect2(60, 26, 360, 36)

var ROOMS: Array[Dictionary] = [
	{
		"path": "res://world/rooms/tutorial/t1_move_attack.tscn",
		"tutorial": true,
		"sign": "MOVER E ATACAR\nMover: WASD ou setas.  Atacar: J ou clique.\n3 golpes seguidos fazem um combo.\nVença o inimigo para destrancar a porta.",
		"rows": TUTORIAL_TOP + [
			"#............................#",
			"#..............,.............#",
			"#............................#",
			"#............................#",
			"#............................#",
			"E.......................c....X",
			"#.....,......................#",
			"#............................#",
			"#...................~........#",
			"#............................#",
			"#............................#",
			"##############################",
		],
	},
	{
		"path": "res://world/rooms/tutorial/t2_dodge.tscn",
		"tutorial": true,
		"sign": "ESQUIVAR\nRolar: Espaço. Ao rolar, nada te acerta.\nRole através dos tiros vermelhos.\nVença o atirador para seguir.",
		"rows": TUTORIAL_TOP + [
			"#x..........................x#",
			"#............................#",
			"#................,...........#",
			"#............................#",
			"#............................#",
			"E.......................s....X",
			"#............................#",
			"#............................#",
			"#.......~....................#",
			"#............................#",
			"#x..........................x#",
			"##############################",
		],
	},
	{
		"path": "res://world/rooms/tutorial/t3_heal.tscn",
		"tutorial": true,
		"heal": true,
		"sign": "CURAR\nFique parado, sem atacar: após 1,5 s a vida volta.\nCurar gasta tempo, e o tempo fortalece a torre.\nCure-se por completo para abrir a porta.",
		"rows": TUTORIAL_TOP + [
			"#~..........................~#",
			"#............................#",
			"#............................#",
			"#.........o........o.........#",
			"#............................#",
			"E............................X",
			"#............................#",
			"#.........o........o.........#",
			"#............................#",
			"#............................#",
			"#~............,.............~#",
			"##############################",
		],
	},
	{
		# Pillar hall: two rows of pillars give cover from the shooter.
		"path": "res://world/rooms/f1/f1_colunas.tscn",
		"rows": [
			"##############################",
			"#............................#",
			"#............................#",
			"#...o.....o.......o.....o....#",
			"#............................#",
			"#..............c.............#",
			"#............................#",
			"E.....................s......X",
			"#......,.....................#",
			"#............................#",
			"#..............c.........C...#",
			"#............................#",
			"#...o.....o.......o.....o....#",
			"#............................#",
			"#............................#",
			"##############################",
		],
	},
	{
		# Gallery: crate lines make three lanes; shooters cover the side lanes.
		"path": "res://world/rooms/f1/f1_galeria.tscn",
		"rows": [
			"##########################X###",
			"#....................s.......#",
			"#............................#",
			"#............................#",
			"#...xxxxxxxx.....xxxxxxxxx...#",
			"#............................#",
			"#............................#",
			"E.................c..........#",
			"#............................#",
			"#............................#",
			"#...xxxxxxxxx.....xxxxxxxx...#",
			"#............................#",
			"#............................#",
			"#....................s......C#",
			"#............................#",
			"##############################",
		],
	},
	{
		# Cross: a central block hides the charger's dash line from the door.
		"path": "res://world/rooms/f1/f1_cruz.tscn",
		"rows": [
			"##############################",
			"#............................#",
			"#............................#",
			"#.............##.............#",
			"#.............##.......c.....#",
			"#.............##.............#",
			"#.........##########.........#",
			"E.........##########.....h...#",
			"#.........##########.........#",
			"#.............##.............#",
			"#....C........##.............#",
			"#.............##.......c.....#",
			"#.............##.............#",
			"#............................#",
			"#............................#",
			"######################X#######",
		],
	},
	{
		# Open arena: room to dodge the charger, pillars only in the corners.
		"path": "res://world/rooms/f1/f1_arena.tscn",
		"rows": [
			"##############################",
			"#............................#",
			"#............................#",
			"#...o.........C..........o...#",
			"#............................#",
			"#............................#",
			"#..................c.........#",
			"E.........,.............h....#",
			"#..................c.........#",
			"#............................#",
			"#............................#",
			"#............................X",
			"#...o....................o...#",
			"#............................#",
			"#............................#",
			"##############################",
		],
	},
	{
		# Antechamber: a wall splits the room; the way in is the low gap.
		"path": "res://world/rooms/f1/f1_antessala.tscn",
		"rows": [
			"##############################",
			"#.........#..................#",
			"#.........#.......s..........#",
			"#.........#..................#",
			"#.........#..................X",
			"#.........#........x.........#",
			"#.........#........x....c....#",
			"E.........#........x.........#",
			"#.........#........x.........#",
			"#.........#..................#",
			"#............................#",
			"#............................#",
			"#.................c.......C..#",
			"#.........#..................#",
			"#.........#..................#",
			"##############################",
		],
	},
	{
		# Ring: enemies circle a central block; four of them, the hardest one.
		"path": "res://world/rooms/f1/f1_anel.tscn",
		"rows": [
			"##############################",
			"#..................s.........#",
			"#............................#",
			"#..............C.............#",
			"#.......o............o.......#",
			"#............................#",
			"#...........######...........#",
			"E...........######.......h...#",
			"#...........######...........#",
			"#............................#",
			"#.......o............o.......#",
			"#............................#",
			"#............................#",
			"#..................c.....c...#",
			"#............................#",
			"#########################X####",
		],
	},
	{
		# Floor 1 boss: the big crawler. Corner pillars only, room to dodge the ring.
		"path": "res://world/rooms/boss_f1.tscn",
		"boss": true,
		"rows": [
			"##############################",
			"#............................#",
			"#............................#",
			"#....o..................o....#",
			"#............................#",
			"#............................#",
			"#............................#",
			"E...................B........#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#....o..................o....#",
			"#............................#",
			"#............................#",
			"##############################",
		],
	},
	{
		# Floor 2 boss: the big charger. Two pillar pairs stop its dashes.
		"path": "res://world/rooms/boss_f2.tscn",
		"boss": true,
		"floor": 2,
		"rows": [
			"##############################",
			"#............................#",
			"#............................#",
			"#............................#",
			"#........o..........o........#",
			"#............................#",
			"#............................#",
			"E.....................H......#",
			"#............................#",
			"#............................#",
			"#........o..........o........#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"##############################",
		],
	},
	{
		# Floor 3 boss: open hall for the dashes, fans and summoned crawlers.
		"path": "res://world/rooms/boss_f3.tscn",
		"boss": true,
		"floor": 3,
		"rows": [
			"##############################",
			"#~..........................~#",
			"#............................#",
			"#...o....................o...#",
			"#............................#",
			"#............................#",
			"#............................#",
			"E...................F........#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"#...o....................o...#",
			"#............................#",
			"#~..........................~#",
			"##############################",
		],
	},

]


func _initialize() -> void:
	var errors: Array[String] = []
	for def in ROOMS:
		errors.append_array(_validate(def))
	if not errors.is_empty():
		for e in errors:
			printerr(e)
		quit(1)
		return
	_dump_layouts()
	var tile_sets: Array[TileSet] = []
	for f in FLOORS:
		tile_sets.append(_build_tileset(f + 1))
	for def in ROOMS:
		var err: Error = await _save_room(def, tile_sets[int(def.get("floor", 1)) - 1])
		if err != OK:
			printerr("save failed %s: %d" % [def["path"], err])
			quit(1)
			return
		print("wrote %s" % def["path"])
	quit(0)


func _rows(def: Dictionary) -> Array[String]:
	var out: Array[String] = []
	out.assign(def["rows"])
	return out


func _ch(rows: Array[String], c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H:
		return "#"
	return rows[c.y][c.x]


func _find(rows: Array[String], ch: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in H:
		for x in W:
			if rows[y][x] == ch:
				out.append(Vector2i(x, y))
	return out


## Direction from a door on the outer wall into the room.
func _inward(c: Vector2i) -> Vector2i:
	if c.x == 0:
		return Vector2i.RIGHT
	if c.x == W - 1:
		return Vector2i.LEFT
	if c.y == 0:
		return Vector2i.DOWN
	return Vector2i.UP


func _center(c: Vector2i) -> Vector2:
	return Vector2(c * RoomTiles.SIZE) + Vector2(8, 8)


func _validate(def: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	var path: String = def["path"]
	var rows := _rows(def)
	if rows.size() != H:
		return ["%s: %d rows, expected %d" % [path, rows.size(), H]]
	for y in H:
		if rows[y].length() != W:
			errs.append("%s: row %d has %d cells" % [path, y, rows[y].length()])
	if not errs.is_empty():
		return errs
	var entries := _find(rows, "E")
	var exits := _find(rows, "X")
	if entries.size() != 1:
		return ["%s: needs exactly one E" % path]
	if exits.size() > 1 or (exits.is_empty() and not def.get("boss", false)):
		errs.append("%s: needs one X (boss rooms none)" % path)
	var start := entries[0] + _inward(entries[0])
	if not WALKABLE.contains(_ch(rows, start)):
		errs.append("%s: cell inside the entry is blocked" % path)
		return errs
	# Flood fill from the entry.
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + d
			if not seen.has(n) and WALKABLE.contains(_ch(rows, n)):
				seen[n] = true
				queue.append(n)
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			if WALKABLE.contains(rows[y][x]) and not seen.has(c):
				errs.append("%s: cell %s unreachable" % [path, c])
	for x in exits:
		if not seen.has(x + _inward(x)):
			errs.append("%s: exit %s unreachable" % [path, x])
	var enemies := 0
	for k: String in ENEMY_KINDS:
		for c in _find(rows, k):
			enemies += 1
			var dist := _center(c).distance_to(_center(start))
			if dist < MIN_SPAWN_DIST:
				errs.append("%s: %s spawn %s only %.0f px from entry" % [path, k, c, dist])
	if enemies == 0 and not def.get("heal", false):
		errs.append("%s: no enemies" % path)
	var chests := _find(rows, "C")
	if not def.get("tutorial", false) and not def.get("boss", false) and chests.size() != 1:
		errs.append("%s: needs one chest spot" % path)
	return errs


func _build_tileset(floor_num: int) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(RoomTiles.SIZE, RoomTiles.SIZE)
	ts.add_physics_layer()
	var src := TileSetAtlasSource.new()
	src.texture = load(TEXTURE_PATH % floor_num) as Texture2D
	src.texture_region_size = Vector2i(RoomTiles.SIZE, RoomTiles.SIZE)
	ts.add_source(src, RoomTiles.SOURCE)
	var full := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	var pillar := PackedVector2Array([
		Vector2(-3, -7), Vector2(3, -7), Vector2(6, -4), Vector2(6, 4),
		Vector2(3, 7), Vector2(-3, 7), Vector2(-6, 4), Vector2(-6, -4)])
	var crate := PackedVector2Array([Vector2(-7, -7), Vector2(6, -7), Vector2(6, 6), Vector2(-7, 6)])
	for coords in RoomTiles.ALL:
		src.create_tile(coords)
		if coords in RoomTiles.SOLID:
			var td := src.get_tile_data(coords, 0)
			td.add_collision_polygon(0)
			var pts := full
			if coords == RoomTiles.PILLAR:
				pts = pillar
			elif coords == RoomTiles.CRATE:
				pts = crate
			td.set_collision_polygon_points(0, 0, pts)
	var path := TILESET_PATH % floor_num
	ResourceSaver.save(ts, path)
	return load(path) as TileSet


## Transform flags so a door drawn for the top wall faces into the room.
func _door_alt(c: Vector2i) -> int:
	if c.x == 0:
		return TileSetAtlasSource.TRANSFORM_TRANSPOSE
	if c.x == W - 1:
		return TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
	if c.y == H - 1:
		return TileSetAtlasSource.TRANSFORM_FLIP_V
	return 0


func _wall_tile(rows: Array[String], c: Vector2i) -> Vector2i:
	var below := c + Vector2i.DOWN
	if c.y + 1 >= H or "#EX".contains(_ch(rows, below)):
		return RoomTiles.WALL_TOP
	if c.y <= 3 and c.x in TORCH_COLS:
		return RoomTiles.WALL_TORCH
	return RoomTiles.WALL_FACE


## Coroutine (awaits a frame for the sign); callers must await it.
func _save_room(def: Dictionary, tile_set: TileSet) -> Error:
	var path: String = def["path"]
	var rows := _rows(def)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(path)

	var room := Node2D.new()
	room.name = path.get_file().get_basename().to_pascal_case()
	room.y_sort_enabled = true
	room.set_script(load(ROOM_SCRIPT))
	room.set("is_boss", def.get("boss", false))
	room.set("is_tutorial", def.get("tutorial", false))
	if def.get("heal", false):
		room.set("start_hp_ratio", 0.5)
		room.set("heal_to_clear", true)

	var floor_num := int(def.get("floor", 1))
	var paint_path := PAINT_PATH % _room_id(def)
	var painted := ResourceLoader.exists(paint_path)
	var floor_layer: TileMapLayer = null
	if painted:
		var bg := Sprite2D.new()
		bg.name = "Background"
		bg.texture = load(paint_path) as Texture2D
		bg.centered = false
		bg.z_index = -5
		_add(room, bg)
		var ambient := CanvasModulate.new()
		ambient.name = "Ambient"
		ambient.color = AMBIENT[floor_num - 1]
		_add(room, ambient)
		var lights := Node2D.new()
		lights.name = "Torches"
		_add(room, lights)
		var light_tex := _light_texture()
		for t in _torches(rows):
			var torch := _make_torch(_center(t), floor_num, light_tex)
			torch.name = "Torch%d" % (lights.get_child_count() + 1)
			lights.add_child(torch)
			torch.owner = room
	else:
		floor_layer = TileMapLayer.new()
		floor_layer.name = "Floor"
		floor_layer.tile_set = tile_set
		floor_layer.z_index = -1
		floor_layer.collision_enabled = false
		_add(room, floor_layer)

	var walls := TileMapLayer.new()
	walls.name = "Walls"
	walls.tile_set = tile_set
	# Painted rooms: collision only.
	walls.visible = not painted
	_add(room, walls)

	var spawns := Node2D.new()
	spawns.name = "Spawns"
	_add(room, spawns)

	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			var ch := rows[y][x]
			if ch == "#":
				walls.set_cell(c, RoomTiles.SOURCE, _wall_tile(rows, c))
				continue
			var ground := RoomTiles.FLOOR_B if rng.randf() < 0.25 else RoomTiles.FLOOR_A
			if ch == ",":
				ground = RoomTiles.FLOOR_CRACK
			elif ch == "~":
				ground = RoomTiles.FLOOR_MOSS
			if floor_layer != null:
				floor_layer.set_cell(c, RoomTiles.SOURCE, ground)
			match ch:
				"o":
					walls.set_cell(c, RoomTiles.SOURCE, RoomTiles.PILLAR)
				"x":
					walls.set_cell(c, RoomTiles.SOURCE, RoomTiles.CRATE)
				"E":
					walls.set_cell(c, RoomTiles.SOURCE, RoomTiles.DOOR_SHUT, _door_alt(c))
					var entry := Marker2D.new()
					entry.name = "Entry"
					entry.position = _center(c + _inward(c))
					_add(room, entry)
					if painted:
						var shut := _make_door_sprite(c, 0)
						shut.name = "EntryDoor"
						shut.position = _center(c)
						_add(room, shut)
				"X":
					walls.set_cell(c, RoomTiles.SOURCE, RoomTiles.DOOR_LOCKED, _door_alt(c))
					var door := Node2D.new()
					door.name = "Exit"
					door.position = _center(c)
					door.set_script(load(DOOR_SCRIPT))
					_add(room, door)
					if painted:
						var overlay := _make_door_sprite(c, 1)
						overlay.name = "Sprite"
						door.add_child(overlay)
						overlay.owner = room
				"C":
					var spot := Marker2D.new()
					spot.name = "ChestSpot"
					spot.position = _center(c)
					_add(room, spot)
				_:
					if ENEMY_KINDS.has(ch):
						var m := Marker2D.new()
						m.name = "%s%d" % [String(ENEMY_KINDS[ch]).capitalize(), spawns.get_child_count() + 1]
						m.position = _center(c)
						m.set_meta(&"enemy", ENEMY_KINDS[ch])
						if BOSS_BASE.has(ch):
							m.set_meta(&"base", BOSS_BASE[ch])
						spawns.add_child(m)
						m.owner = room

	if def.has("sign"):
		# In the tree, so the label measures itself with its 8 px font.
		get_root().add_child(room)
		var sign := _make_sign(def["sign"])
		_add(room, sign)
		await process_frame
		sign.size = SIGN_RECT.size
		get_root().remove_child(room)

	var packed := PackedScene.new()
	var err := packed.pack(room)
	if err != OK:
		return err
	err = ResourceSaver.save(packed, path)
	room.free()
	return err


func _room_id(def: Dictionary) -> String:
	return String(def["path"]).get_file().get_basename()


## Torch cells: on the top wall face and the bottom wall, at TORCH_COLS
## (moved aside if a door is there). Shared with the blockouts.
func _torches(rows: Array[String]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var top := 0
	while top + 1 < H and _ch(rows, Vector2i(1, top + 1)) == "#":
		top += 1
	for y in [top, H - 1]:
		# The tutorial sign covers the middle of the thick top wall.
		var cols: Array[int] = TORCH_COLS_SIGN if y == top and top > 0 else TORCH_COLS
		for col in cols:
			for dx in [0, 2, -2, 4, -4]:
				var c := Vector2i(col + dx, y)
				if _ch(rows, c) == "#" and _ch(rows, c + Vector2i.LEFT) == "#" and _ch(rows, c + Vector2i.RIGHT) == "#":
					out.append(c)
					break
	return out


## Soft round light shared by a room's torches.
func _light_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex


func _make_torch(pos: Vector2, floor_num: int, tex: Texture2D) -> PointLight2D:
	var light := PointLight2D.new()
	light.position = pos
	light.texture = tex
	light.texture_scale = 1.2
	light.color = TORCH_COLOR[floor_num - 1]
	light.energy = 0.4
	return light


## Overlay for a door cell: column 0 shut, 1 locked, 2 open; row 0 for doors
## on the top or bottom wall, row 1 (side view) for the left and right walls.
## The 24 px frame grows into the wall away from the floor.
func _make_door_sprite(c: Vector2i, state: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(DOORS_PATH) as Texture2D
	s.hframes = 3
	s.vframes = 2
	var side := c.x == 0 or c.x == W - 1
	s.frame = state + (3 if side else 0)
	s.flip_h = c.x == W - 1
	s.z_index = -4
	var grow := float(DOOR_FRAME.y - RoomTiles.SIZE) / 2.0
	# Top and side doors grow up; the bottom door grows down off the room.
	s.offset = Vector2(0, grow if c.y == H - 1 else -grow)
	return s


func _dump_layouts() -> void:
	var out := {}
	for def in ROOMS:
		var rows := _rows(def)
		var torches: Array = []
		for t in _torches(rows):
			torches.append([t.x, t.y])
		out[_room_id(def)] = {
			"floor": int(def.get("floor", 1)),
			"tutorial": def.get("tutorial", false),
			"boss": def.get("boss", false),
			"rows": rows,
			"torches": torches,
			"sign": [SIGN_RECT.position.x, SIGN_RECT.position.y, SIGN_RECT.size.x, SIGN_RECT.size.y] if def.has("sign") else [],
		}
	var path := ProjectSettings.globalize_path(LAYOUTS_JSON)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t") + "\n")
	f.close()
	print("wrote %s" % path)


## Plaque on the thick top wall of tutorial rooms.
func _make_sign(text: String) -> Label:
	var label := Label.new()
	label.name = "Sign"
	label.text = text
	label.z_index = 2
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", 8)
	label.add_theme_constant_override(&"line_spacing", -2)
	label.add_theme_color_override(&"font_color", Color(0.96, 0.9, 0.78))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.2, 0.13, 0.09)
	box.border_color = Color(0.45, 0.3, 0.17)
	box.set_border_width_all(1)
	box.set_content_margin_all(2)
	label.add_theme_stylebox_override(&"normal", box)
	label.position = SIGN_RECT.position
	return label


func _add(room: Node, child: Node) -> void:
	room.add_child(child)
	child.owner = room
