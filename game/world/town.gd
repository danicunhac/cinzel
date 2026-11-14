extends Node2D
## Walkable town (one 480x270 screen). A painted ground with large Y-sorted
## sprites on it (game/assets/town, docs/assets.md). Three spots: the shop
## (shopkeeper), the forge (blacksmith) and the teleport crystal; E near one
## opens its panel. Near a spot with an action, a gold ring pings on the ground
## and the building glows; the NPC speaks a short line in a bubble.
## The run clock stays stopped here. Every town load starts a market visit
## (Market.begin_visit: prices recover, new stock and wanted items).
## Debug: `--gold=N`, `--items=fang,spark` and `--floors=N` change the run,
## `--panel=shop|smith|teleport` opens a panel, `--player=x,y` moves the player.

const SHOPKEEPER_TEX := preload("res://assets/characters/npc_shopkeeper.png")
const SMITH_TEX := preload("res://assets/characters/npc_blacksmith.png")
const ShopPanelScene := preload("res://ui/shop_panel.tscn")
const SmithPanelScene := preload("res://ui/smith_panel.tscn")
const TeleportPanelScene := preload("res://ui/teleport_panel.tscn")
const ART := "res://assets/town/%s.png"
## Every town sprite has PAD px of shadow below its base line (build_town.py).
const PAD := 4

const SPAWN := Vector2(240, 222)
const REACH := 30.0
const CRYSTAL_POS := Vector2(240, 160)
## Where the player stands to use each spot (in front of the counter, the
## anvil and the crystal).
const SPOTS: Dictionary[StringName, Vector2] = {
	&"shop": Vector2(62, 128),
	&"smith": Vector2(426, 146),
	&"teleport": Vector2(240, 172),
}
const SPOT_NAMES: Dictionary[StringName, String] = {
	&"shop": "Loja",
	&"smith": "Ferreiro",
	&"teleport": "Teleporte",
}
const SCREEN := Vector2(480, 270)
const TINT := Color(0.94, 0.9, 0.84)
const LAMP_COLOR := Color(1.0, 0.72, 0.38)

## Speech lines (DP 2.1: at most 25 words, 3 lines).
const LINES: Dictionary[String, String] = {
	"shop": "Poções frescas, lâminas afiadas. Ouro na mão, item na bolsa!",
	"shop_sell": "Achou algo na torre? Eu compro, e pago bem.",
	"smith": "Você tem o material certo! Escolha a receita e eu forjo na hora.",
	"smith_wait": "Traga materiais da torre e ouro. Eu forjo armas e armaduras.",
}

## Large pieces: [name, base position (origin), footprint size or ZERO for
## no collision, optional flip_h]. The footprint is a rect that ends on the
## base line. The forge is mirrored so its chimney smoke clears the HUD.
const PIECES: Array = [
	["shop", Vector2(62, 114), Vector2(96, 26)],
	["forge", Vector2(418, 130), Vector2(98, 24), true],
	["house_a", Vector2(166, 86), Vector2(54, 16)],
	["house_b", Vector2(316, 84), Vector2(70, 16)],
	["house_c", Vector2(440, 268), Vector2(58, 16)],
	["tree_b", Vector2(118, 66), Vector2.ZERO],
	["tree_c", Vector2(206, 40), Vector2.ZERO],
	["tree_b", Vector2(282, 30), Vector2.ZERO],
	["tree_a", Vector2(26, 266), Vector2.ZERO],
	["tree_c", Vector2(80, 270), Vector2.ZERO],
	["tree_b", Vector2(472, 190), Vector2.ZERO],
	["well", Vector2(128, 206), Vector2(28, 10)],
	["lamp", Vector2(206, 96), Vector2(6, 4)],
	["lamp", Vector2(274, 96), Vector2(6, 4)],
	["lamp", Vector2(150, 236), Vector2(6, 4)],
	["lamp", Vector2(330, 236), Vector2(6, 4)],
	["planter", Vector2(152, 122), Vector2(28, 10)],
	["planter", Vector2(328, 122), Vector2(28, 10)],
	["flowerbed", Vector2(186, 198), Vector2(26, 8)],
	["flowerbed", Vector2(294, 198), Vector2(26, 8)],
	["barrel", Vector2(122, 110), Vector2(12, 6)],
	["crates", Vector2(128, 120), Vector2(16, 8)],
	["barrel", Vector2(358, 126), Vector2(12, 6)],
	["sack", Vector2(354, 138), Vector2(12, 6)],
	["crates", Vector2(392, 256), Vector2(16, 8)],
	["fence_post", Vector2(104, 254), Vector2.ZERO],
	["fence", Vector2(126, 254), Vector2.ZERO],
	["fence", Vector2(166, 254), Vector2.ZERO],
	["fence", Vector2(198, 254), Vector2.ZERO],
	["fence_post", Vector2(218, 254), Vector2.ZERO],
	["fence_post", Vector2(262, 254), Vector2.ZERO],
	["fence", Vector2(282, 254), Vector2.ZERO],
	["fence", Vector2(314, 254), Vector2.ZERO],
	["fence", Vector2(354, 254), Vector2.ZERO],
	["fence_post", Vector2(376, 254), Vector2.ZERO],
]
## Unreachable areas: from the top of the screen down to the back rows'
## footprints (shop, house A, house B, forge), behind house C, and the fence
## line with the grass under it. The north path (x 200-280), the plaza and
## the south path (x 222-258) stay open.
const BLOCKED: Array[Rect2] = [
	Rect2(0, 0, 136, 106),
	Rect2(136, 0, 64, 86),
	Rect2(280, 0, 86, 84),
	Rect2(366, 0, 114, 108),
	Rect2(466, 108, 14, 22),
	Rect2(408, 196, 72, 74),
	Rect2(0, 244, 222, 26),
	Rect2(258, 244, 150, 26),
]
## Points of light: [position, radius in px, energy].
const LIGHTS: Array = [
	[Vector2(209, 70), 44.0, 0.8],
	[Vector2(277, 70), 44.0, 0.8],
	[Vector2(153, 210), 44.0, 0.8],
	[Vector2(333, 210), 44.0, 0.8],
	[Vector2(62, 84), 50.0, 0.7],
	[Vector2(424, 100), 56.0, 1.0],
]
## Forge chimney top and anvil (smoke and sparks).
const CHIMNEY := Vector2(399, 32)
const ANVIL := Vector2(426, 112)
const FORGE_BASE := 130.0
## Villager loops (feet positions).
const WALKS: Array = [
	[Vector2(96, 150), Vector2(170, 150), Vector2(162, 226), Vector2(96, 226)],
	[Vector2(240, 30), Vector2(240, 104), Vector2(300, 136), Vector2(240, 104)],
	[Vector2(372, 222), Vector2(316, 222), Vector2(316, 160), Vector2(372, 160)],
]

var shop: Market
var near: StringName = &""
var _rng := RandomNumberGenerator.new()
var _panel: UiPanel = null
var _ctas: Dictionary[StringName, TownCta] = {}
var _glow_targets: Dictionary[StringName, CanvasItem] = {}
var _speakers: Dictionary[StringName, Vector2] = {}
var _bubble: SpeechBubble
var _hint: Label
var _crystal_glow: Sprite2D
var _t: float = 0.0

@onready var player: Player = $Player


func _ready() -> void:
	Game.run.clock.running = false
	Game.in_boss_room = false
	_rng.randomize()
	shop = Game.run.market
	shop.begin_visit(_rng)
	_build_ground()
	_build_bounds()
	_build_pieces()
	_build_spots()
	_build_life()
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
		Game.run.beat_floor(int(args["floors"]) - 1)
	if args.has("player"):
		var xy := String(args["player"]).split(",")
		player.global_position = Vector2(float(xy[0]), float(xy[1]))
	if args.has("panel"):
		open_panel.call_deferred(StringName(String(args["panel"])))


func _process(delta: float) -> void:
	_t += delta
	near = _nearest_spot()
	var items := Game.run.inventory.used()
	var can_forge := Forge.any_craftable(Game.run)
	for id: StringName in _ctas:
		var on := TownLogic.cta_visible(id, near, items, can_forge)
		_ctas[id].active = on
		var glow := 1.0 + (0.1 + 0.06 * sin(_t * 4.0) if on else 0.0)
		_glow_targets[id].modulate = Color(glow, glow, glow * 0.96)
	_update_hint(items)
	_update_bubble(items)
	if _crystal_glow != null:
		_crystal_glow.modulate.a = 0.7 + 0.3 * sin(_t * 2.2)
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
			_panel = SmithPanelScene.instantiate() as SmithPanel
		&"teleport":
			_panel = TeleportPanelScene.instantiate() as TeleportPanel
		_:
			return null
	_panel.closed.connect(func() -> void: _panel = null)
	add_child(_panel)
	_panel.open()
	return _panel


## Line the NPC at `id` says now ("" for the crystal, which has no speaker).
## `item_count` is the backpack's used slots.
func line_for(id: StringName, item_count: int) -> String:
	match id:
		&"shop":
			return LINES["shop_sell"] if item_count > 0 else LINES["shop"]
		&"smith":
			return LINES["smith"] if Forge.any_craftable(Game.run) else LINES["smith_wait"]
	return ""


func _nearest_spot() -> StringName:
	if player == null or player.state == Player.State.DEAD:
		return &""
	return TownLogic.nearest_spot(player.global_position, SPOTS, REACH)


func _update_hint(items: int) -> void:
	if near == &"" or _panel != null:
		_hint.visible = false
		return
	_hint.visible = true
	_hint.text = "E  %s" % SPOT_NAMES[near]
	var ok := TownLogic.can_act(near, items, Forge.any_craftable(Game.run))
	_hint.add_theme_color_override("font_color", UiKit.COLOR_ITEM if ok else UiKit.COLOR_MUTED)
	# Over the player's head, except at the crystal, where that would cover
	# the crystal itself: there it goes under the feet.
	var p := SPOTS[near] + (Vector2(-40, 12) if near == &"teleport" else Vector2(-40, -36))
	_hint.position = Vector2(clampf(p.x, 2, SCREEN.x - 82), p.y)


func _update_bubble(items: int) -> void:
	var text := line_for(near, items) if _panel == null else ""
	if text == "":
		_bubble.hide_bubble()
		return
	_bubble.position = _speakers[near]
	_bubble.say(text)


# --- building the scene -----------------------------------------------------

func _tex(name: String) -> Texture2D:
	return load(ART % name) as Texture2D


func _build_ground() -> void:
	var g := Sprite2D.new()
	g.name = "Ground"
	g.texture = _tex("ground")
	g.centered = false
	g.z_index = -20
	add_child(g)
	var cm := CanvasModulate.new()
	cm.color = TINT
	add_child(cm)


## Screen edges, the areas behind the buildings (the player would vanish
## there) and the fence line; buildings add their own footprints in _piece().
func _build_bounds() -> void:
	var body := StaticBody2D.new()
	body.name = "Bounds"
	add_child(body)
	_rect(body, Rect2(-16, 0, 16, SCREEN.y))
	_rect(body, Rect2(SCREEN.x, 0, 16, SCREEN.y))
	_rect(body, Rect2(0, -16, SCREEN.x, 16 + 18))
	_rect(body, Rect2(0, SCREEN.y - 6, SCREEN.x, 16))
	for r: Rect2 in BLOCKED:
		_rect(body, r)


func _rect(body: StaticBody2D, r: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	body.add_child(shape)


## Sprite with its origin on the base line (Y-sort key), plus its footprint.
func _piece(name: String, base: Vector2, footprint: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = name.capitalize().replace(" ", "")
	s.texture = _tex(name)
	s.centered = false
	var size := s.texture.get_size()
	s.offset = Vector2(-floorf(size.x / 2.0), -size.y + PAD)
	s.position = base
	add_child(s)
	if footprint != Vector2.ZERO:
		var body := StaticBody2D.new()
		body.position = base
		add_child(body)
		_rect(body, Rect2(-footprint.x / 2.0, -footprint.y, footprint.x, footprint.y))
	return s


func _build_pieces() -> void:
	for p: Array in PIECES:
		var s := _piece(p[0], p[1], p[2])
		s.flip_h = p.size() > 3 and p[3]
		if p[0] == "shop":
			_glow_targets[&"shop"] = s
		elif p[0] == "forge":
			_glow_targets[&"smith"] = s
	var crystal := _piece("crystal", CRYSTAL_POS, Vector2(40, 12))
	_glow_targets[&"teleport"] = crystal
	_crystal_glow = Sprite2D.new()
	_crystal_glow.texture = _tex("crystal_glow")
	_crystal_glow.position = Vector2(0, -42)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_crystal_glow.material = add
	crystal.add_child(_crystal_glow)


func _build_spots() -> void:
	_speakers[&"shop"] = _add_npc(SHOPKEEPER_TEX, Vector2(30, 128))
	_speakers[&"smith"] = _add_npc(SMITH_TEX, Vector2(454, 148))
	for id: StringName in SPOTS:
		var cta := TownCta.new()
		cta.position = SPOTS[id]
		cta.radius = 18.0
		if id == &"teleport":
			cta.color = Color(0.55, 0.9, 1.0)
			cta.position = CRYSTAL_POS + Vector2(0, 2)
			cta.radius = 24.0
		add_child(cta)
		_ctas[id] = cta
	# Hint and bubble live on a screen layer (no camera here, so screen and
	# world coordinates match): no CanvasModulate tint, above props and the
	# HUD (layer 5), below the panels (layer 30).
	var overlay := CanvasLayer.new()
	overlay.name = "Talk"
	overlay.layer = 8
	add_child(overlay)
	_hint = UiKit.label("", UiKit.COLOR_ITEM, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.size = Vector2(80, 10)
	_hint.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.06))
	_hint.add_theme_constant_override("outline_size", 2)
	_hint.visible = false
	overlay.add_child(_hint)
	_bubble = SpeechBubble.new()
	overlay.add_child(_bubble)


## NPC standing with its feet at `feet`; returns where its bubble hangs.
func _add_npc(tex: Texture2D, feet: Vector2) -> Vector2:
	var v := Villager.new()
	var still: Array[Vector2] = [feet]
	v.setup(tex, Color.WHITE, still)
	add_child(v)
	var body := StaticBody2D.new()
	body.position = feet
	add_child(body)
	_rect(body, Rect2(-6, -6, 12, 6))
	return feet + Vector2(0, 2)


func _build_life() -> void:
	for l: Array in LIGHTS:
		_add_light(l[0], l[1], l[2])
	_add_smoke()
	_add_sparks()
	_add_crystal_motes()
	_add_leaves()
	var tints: Array[Color] = [Color(0.75, 0.9, 1.0), Color(1.0, 0.85, 0.75), Color(0.85, 1.0, 0.8)]
	var texes: Array[Texture2D] = [SHOPKEEPER_TEX, SMITH_TEX, SHOPKEEPER_TEX]
	for i in WALKS.size():
		var v := Villager.new()
		var pts: Array[Vector2] = []
		pts.assign(WALKS[i])
		v.setup(texes[i], tints[i], pts)
		add_child(v)


static var _light_tex: GradientTexture2D


func _add_light(pos: Vector2, radius: float, energy: float) -> void:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_light_tex = GradientTexture2D.new()
		_light_tex.gradient = g
		_light_tex.fill = GradientTexture2D.FILL_RADIAL
		_light_tex.fill_from = Vector2(0.5, 0.5)
		_light_tex.fill_to = Vector2(1.0, 0.5)
		_light_tex.width = 64
		_light_tex.height = 64
	var light := PointLight2D.new()
	light.texture = _light_tex
	light.texture_scale = radius * 2.0 / 64.0
	light.color = LAMP_COLOR
	light.energy = energy * 0.5
	light.position = pos
	add_child(light)


## Particles at `pos`, Y-sorted as if they stood at `sort_y`: a holder node
## sits at sort_y so the effect draws over the building it belongs to
## (z_index does not lift a child out of the town's Y-sort).
func _particles(pos: Vector2, sort_y: float) -> CPUParticles2D:
	var holder := Node2D.new()
	holder.position = Vector2(pos.x, sort_y)
	add_child(holder)
	var p := CPUParticles2D.new()
	p.position = Vector2(0, pos.y - sort_y)
	p.texture = _dot()
	holder.add_child(p)
	return p


static var _dot_tex: ImageTexture


## 1x1 white pixel; particles scale it (2x2 leaves, 3x3 smoke puffs).
static func _dot() -> ImageTexture:
	if _dot_tex == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_dot_tex = ImageTexture.create_from_image(img)
	return _dot_tex


func _fade_ramp(c: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, c)
	g.set_color(1, Color(c, 0.0))
	return g


func _add_smoke() -> void:
	var p := _particles(CHIMNEY, FORGE_BASE + 1.0)
	# A light wind blows the smoke left over the roof.
	p.amount = 18
	p.lifetime = 3.5
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 2.0
	p.direction = Vector2(-0.7, -1)
	p.spread = 18.0
	p.gravity = Vector2(-5, -2)
	p.initial_velocity_min = 7.0
	p.initial_velocity_max = 11.0
	p.scale_amount_min = 5.0
	p.scale_amount_max = 8.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1))
	p.scale_amount_curve = grow
	p.color_ramp = _fade_ramp(Color(0.93, 0.92, 0.9, 0.95))
	p.preprocess = 3.0


func _add_sparks() -> void:
	var p := _particles(ANVIL, FORGE_BASE + 1.0)
	# Hammer rhythm: most sparks leave together, one burst per lifetime.
	p.amount = 10
	p.lifetime = 0.7
	p.explosiveness = 0.8
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.gravity = Vector2(0, 140)
	p.initial_velocity_min = 35.0
	p.initial_velocity_max = 60.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	var hot := Gradient.new()
	hot.set_color(0, Color(1.0, 1.0, 0.9))
	hot.set_color(1, Color(1.0, 0.4, 0.1, 0.0))
	hot.add_point(0.6, Color(1.0, 0.75, 0.25))
	p.color_ramp = hot
	p.preprocess = 0.5


func _add_crystal_motes() -> void:
	var p := _particles(CRYSTAL_POS + Vector2(0, -8), CRYSTAL_POS.y + 1.0)
	p.amount = 12
	p.lifetime = 1.8
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(12, 4)
	p.direction = Vector2(0, -1)
	p.spread = 10.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 14.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var mote := Gradient.new()
	mote.set_color(0, Color(0.85, 0.97, 1.0))
	mote.set_color(1, Color(0.45, 0.8, 1.0, 0.0))
	mote.add_point(0.6, Color(0.6, 0.9, 1.0))
	p.color_ramp = mote
	p.preprocess = 2.0


func _add_leaves() -> void:
	var p := _particles(Vector2(SCREEN.x / 2.0, -6), SCREEN.y + 100.0)
	p.amount = 6
	p.lifetime = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(SCREEN.x / 2.0, 2)
	p.direction = Vector2(0.4, 1)
	p.spread = 20.0
	p.gravity = Vector2(4, 6)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 14.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 2.0
	var g := Gradient.new()
	g.set_color(0, Color(0.95, 0.55, 0.2))
	g.set_color(1, Color(0.85, 0.4, 0.15, 0.0))
	g.add_point(0.8, Color(0.9, 0.5, 0.2))
	p.color_ramp = g
	p.color_initial_ramp = _leaf_colors()
	p.preprocess = 9.0


func _leaf_colors() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1))
	g.set_color(1, Color(0.7, 1.0, 0.6))
	return g
