extends Node2D
## Walkable town (one 480x270 screen). Three spots: the shop (shopkeeper),
## the blacksmith and the teleport stone; E near one opens its panel. The run
## clock stays stopped here. The shop restocks every time the town loads,
## which is every return from the tower.
## Debug: `--gold=N`, `--items=fang,spark` and `--floors=N` change the run,
## `--panel=shop|smith|teleport` opens a panel, `--player=x,y` moves the player.

const TILES := preload("res://assets/tiles/town.png")
const FLOOR_TILES := preload("res://assets/tiles/floor1.png")
const SHOPKEEPER_TEX := preload("res://assets/characters/npc_shopkeeper.png")
const SMITH_TEX := preload("res://assets/characters/npc_blacksmith.png")
const ShopPanelScene := preload("res://ui/shop_panel.tscn")
const SmithPanelScene := preload("res://ui/smith_panel.tscn")
const TeleportPanelScene := preload("res://ui/teleport_panel.tscn")
const GlowScript := preload("res://world/teleport_glow.gd")

const T := 16
const SPAWN := Vector2(240, 222)
const REACH := 39.0
const STONE_POS := Vector2(240, 150)
const SPOTS: Dictionary[StringName, Vector2] = {
	&"shop": Vector2(88, 78),
	&"smith": Vector2(392, 78),
	&"teleport": STONE_POS,
}
const SPOT_NAMES: Dictionary[StringName, String] = {
	&"shop": "Loja",
	&"smith": "Ferreiro",
	&"teleport": "Teleporte",
}

## Town tileset atlas coords (docs/assets.md).
const TILE: Dictionary[String, Vector2i] = {
	"R": Vector2i(6, 0), "H": Vector2i(2, 1), "D": Vector2i(3, 1), "N": Vector2i(4, 1),
	"S": Vector2i(7, 0), "A": Vector2i(0, 1), "W": Vector2i(4, 0), "g": Vector2i(2, 0),
	"f": Vector2i(3, 0), "d": Vector2i(5, 0), "~": Vector2i(7, 1),
}
const COBBLE_A := Vector2i(0, 0)
const COBBLE_B := Vector2i(1, 0)
const AWNING_EDGE := Vector2i(1, 1)
const BANNER := Vector2i(5, 1)
const MAP: Array[String] = [
	"RRRRRRRRRRRRRRRRRRRRRRRRRRRRRR",
	"RRRRRRRRRRRRRRRRRRRRRRRRRRRRRR",
	"RRRRRRRRRRRRRRRRRRRRRRRRRRRRRR",
	"HHAAAAAAAHNHDHNHNHDHNSSSSSSSHH",
	"ccWWWWWWWccccccccccccWWWWWWWcc",
	"gcccccccccccccccccccccccccccfg",
	"gccccccccccccccccccccccccccccg",
	"fccccccccccccccccccccccccccccg",
	"gccccccccccccccccccccccccccccg",
	"gccccccccccccccccccccccccccccf",
	"gccccccccccccccccccccccccccccg",
	"gccccccccccccccccccccccccccccg",
	"fccccccccccccccccccccccccccccg",
	"gccccccccccccccccccccccccccccg",
	"gggccccccccccccccccccccccccggg",
	"gfggggggggddddddddddggggggggfg",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
]
const BANNERS: Array[Vector2i] = [Vector2i(9, 3), Vector2i(13, 3), Vector2i(17, 3), Vector2i(20, 3)]
## Shop awning edge, on the counter row under the awning.
const AWNING_ROW := 4
const AWNING_COLS := Vector2i(2, 8)
## Screen size and the y where the houses (top) and the water (bottom) block.
const SCREEN := Vector2(480, 270)
const HOUSES_BOTTOM := 68.0
const WATER_TOP := 252.0

var shop := Shop.new()
var near: StringName = &""
var _rng := RandomNumberGenerator.new()
var _prompts: Dictionary[StringName, Label] = {}
var _panel: UiPanel = null

@onready var ground: TileMapLayer = $Ground
@onready var decor: TileMapLayer = $Decor
@onready var player: Player = $Player


func _ready() -> void:
	Game.run.clock.running = false
	Game.in_boss_room = false
	_rng.randomize()
	shop.restock(_rng)
	_build_tiles()
	_build_bounds()
	_build_spots()
	player.global_position = SPAWN
	player.facing = Vector2.UP
	_apply_debug_args()


func _apply_debug_args() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if args.has("gold"):
		Game.run.add_gold(int(args["gold"]))
	if args.has("items"):
		for id in String(args["items"]).split(",", false):
			Game.run.add_item(StringName(id))
	if args.has("floors"):
		Game.run.unlock_floor(int(args["floors"]))
	if args.has("player"):
		var xy := String(args["player"]).split(",")
		player.global_position = Vector2(float(xy[0]), float(xy[1]))
	if args.has("panel"):
		open_panel.call_deferred(StringName(String(args["panel"])))


func _process(_delta: float) -> void:
	near = _nearest_spot()
	for id: StringName in _prompts:
		var l: Label = _prompts[id]
		l.text = ("E: %s" if id == near else "%s") % SPOT_NAMES[id]
		l.add_theme_color_override("font_color", UiKit.COLOR_ITEM if id == near else UiKit.COLOR_TITLE)
	if near != &"" and _panel == null and Input.is_action_just_pressed(&"interact"):
		open_panel(near)


## Opens the panel of a spot (shop, smith, teleport) and returns it.
func open_panel(id: StringName) -> UiPanel:
	if _panel != null:
		return _panel
	match id:
		&"shop":
			var s := ShopPanelScene.instantiate() as ShopPanel
			s.shop = shop
			_panel = s
		&"smith":
			var m := SmithPanelScene.instantiate() as SmithPanel
			m.shop = shop
			_panel = m
		&"teleport":
			_panel = TeleportPanelScene.instantiate() as TeleportPanel
		_:
			return null
	_panel.closed.connect(func() -> void: _panel = null)
	add_child(_panel)
	_panel.open()
	return _panel


func _nearest_spot() -> StringName:
	if player == null or player.state == Player.State.DEAD:
		return &""
	var best: StringName = &""
	var best_d := REACH
	for id: StringName in SPOTS:
		var d := player.global_position.distance_to(SPOTS[id])
		if d < best_d:
			best_d = d
			best = id
	return best


func _build_tiles() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	var src := TileSetAtlasSource.new()
	src.texture = TILES
	src.texture_region_size = Vector2i(T, T)
	for y in 2:
		for x in 8:
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	ground.tile_set = ts
	decor.tile_set = ts
	for y in MAP.size():
		var row: String = MAP[y]
		for x in row.length():
			var ch := row[x]
			var coords: Vector2i
			if ch == "c":
				coords = COBBLE_B if _rng.randf() < 0.3 else COBBLE_A
			else:
				coords = TILE[ch]
			ground.set_cell(Vector2i(x, y), 0, coords)
	for x in range(AWNING_COLS.x, AWNING_COLS.y + 1):
		decor.set_cell(Vector2i(x, AWNING_ROW), 0, AWNING_EDGE)
	for c in BANNERS:
		decor.set_cell(c, 0, BANNER)


## Walls: houses at the top, water at the bottom, screen sides; plus small
## bodies for the NPCs and the stone.
func _build_bounds() -> void:
	var body := StaticBody2D.new()
	body.name = "Bounds"
	add_child(body)
	_rect(body, Rect2(0, 0, SCREEN.x, HOUSES_BOTTOM))
	_rect(body, Rect2(0, WATER_TOP, SCREEN.x, 20))
	_rect(body, Rect2(-16, 0, 16, SCREEN.y))
	_rect(body, Rect2(SCREEN.x, 0, 16, SCREEN.y))
	_rect(body, Rect2(STONE_POS + Vector2(-7, -5), Vector2(14, 10)))


func _rect(body: StaticBody2D, r: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	body.add_child(shape)


func _build_spots() -> void:
	_add_npc(SHOPKEEPER_TEX, SPOTS[&"shop"] + Vector2(0, -6))
	_add_npc(SMITH_TEX, SPOTS[&"smith"] + Vector2(0, -6))
	var stone := Sprite2D.new()
	stone.texture = FLOOR_TILES
	stone.region_enabled = true
	stone.region_rect = RoomTiles.region(RoomTiles.PILLAR)
	stone.position = STONE_POS + Vector2(0, -6)
	stone.modulate = Color(0.75, 0.9, 1.2)
	add_child(stone)
	var glow := GlowScript.new() as Node2D
	glow.position = STONE_POS + Vector2(0, 4)
	glow.z_index = -1
	add_child(glow)
	for id: StringName in SPOTS:
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(90, 10)
		l.position = SPOTS[id] + Vector2(-45, -38)
		l.z_index = 20
		add_child(l)
		_prompts[id] = l



func _add_npc(tex: Texture2D, feet: Vector2) -> void:
	var s := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 2.0)
	for i in 2:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * 24, 0, 24, 24)
		frames.add_frame(&"default", at)
	s.sprite_frames = frames
	s.position = feet + Vector2(0, -6)
	s.autoplay = "default"
	add_child(s)
	s.play()
	var body := StaticBody2D.new()
	body.position = feet + Vector2(0, 2)
	add_child(body)
	_rect(body, Rect2(-6, -3, 12, 6))
