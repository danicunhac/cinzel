extends Node2D
## Walkable town (one 480x270 screen). The layout lives in town.tscn and is
## edited in the Godot editor: the painted Ground and Decals, Y-sorted
## Buildings, Trees, Lamps, Props and Fence (each sprite's origin is its base
## line; a Footprint body blocks it), the Crystal, the Tower, the Npcs, the
## Collision bounds, Lights and Effects. This script reads the markers:
## Spots (shop, forge smith, wardrobe at the door of the hero's house A; each
## with its Ring), Gate (walking into its rectangle enters floor 1, or opens
## the floor list once more floors are unlocked), Arrivals (Spawn, Gate,
## Crystal: where the player appears) and Walks (one Path2D loop per
## villager). E near a spot opens its panel. No weapons in town: the attack
## button only shows a note. Near a spot with an action, its ring pings on the
## ground and the building glows; the NPC speaks a short line in a bubble.
## The run clock stays stopped here. Every town load starts a market visit
## (Market.begin_visit: prices recover, new stock and wanted items).
## Debug: `--gold=N`, `--items=fang,spark` and `--floors=N` change the run,
## `--outfits` unlocks every outfit, `--wanted=a,b` sets the wanted items,
## `--sold=id:n` marks n units of id as sold already (lower price), `--panel=shop|smith|teleport|wardrobe`
## opens a panel (`--tab=buy` picks the shop tab, `--pick=N` the cell, `--qty=N` how many to sell),
## `--player=x,y` moves the player. `--give`/`--equip`: see Game.

const ShopPanelScene := preload("res://ui/shop_panel.tscn")
const SmithPanelScene := preload("res://ui/smith_panel.tscn")
const TeleportPanelScene := preload("res://ui/teleport_panel.tscn")
const WardrobePanelScript := preload("res://ui/wardrobe_panel.gd")

const REACH := 30.0
const SPOT_NAMES: Dictionary[StringName, String] = {
	&"shop": "Loja",
	&"smith": "Ferreiro",
	&"wardrobe": "Guarda-roupa",
}
## Building that glows while its spot is active, and the NPC who speaks there.
const GLOW_TARGETS: Dictionary[StringName, NodePath] = {
	&"shop": ^"Buildings/Shop",
	&"smith": ^"Buildings/Forge",
	&"wardrobe": ^"Buildings/HouseA",
}
const SPEAKERS: Dictionary[StringName, NodePath] = {
	&"shop": ^"Npcs/Shopkeeper",
	&"smith": ^"Npcs/Smith",
}
const SCREEN := Vector2(480, 270)

## Speech lines (DP 2.1: at most 25 words, 3 lines).
const LINES: Dictionary[String, String] = {
	"shop": "Poções frescas, lâminas afiadas. Ouro na mão, item na bolsa!",
	"shop_sell": "Achou algo na torre? Eu compro, e pago bem.",
	"smith": "Você tem o material certo! Escolha a receita e eu forjo na hora.",
	"smith_wait": "Traga materiais da torre e ouro. Eu forjo armas e armaduras.",
	"villager_oldwoman": "Meu marido subiu a torre três vezes. Na quarta, voltou sem botas.",
	"villager_child": "Quando eu crescer vou subir a torre inteira! Hoje só até a fonte.",
	"villager_guard": "Nada desce da torre sem eu ver. Quase nada. Olho nas sombras.",
	"villager_farmer": "A sombra da torre cobre minha horta. Os nabos nem reclamam mais.",
	"villager_archer": "Dizem que a torre toca as nuvens. Minhas flechas ainda não.",
	"villager_merchant": "Vendo mapas da torre! Nenhum certo: ela muda toda noite.",
}

## Looks: sheet in assets/characters/villagers, walk speed (px/s), bubble
## key in LINES.
const VILLAGER_LOOKS: Dictionary[String, float] = {
	"oldwoman": 10.0,
	"child": 24.0,
	"guard": 15.0,
	"farmer": 14.0,
	"archer": 17.0,
	"merchant": 12.0,
}
const VILLAGER_ART := "res://assets/characters/villagers/%s.png"
## A villager talks when the player's feet are this close (and no spot is).
const VILLAGER_REACH := 24.0
const NOTE_TIME := 1.4

var shop: Market
var near: StringName = &""
## Where the player stands to use each spot (Spots/<Name> markers).
var spots: Dictionary[StringName, Vector2] = {}
## Tower entrance (the Gate area's rectangle).
var gate: Rect2
var _rng := RandomNumberGenerator.new()
var _panel: UiPanel = null
var _ctas: Dictionary[StringName, TownCta] = {}
var _glow_targets: Dictionary[StringName, CanvasItem] = {}
var _speakers: Dictionary[StringName, Vector2] = {}
var _villagers: Array[Villager] = []
var _bubble: SpeechBubble
var _hint: Label
var _note: Label
var _note_time: float = 0.0
## True while the player stands in the gate; entering needs a fresh step in.
var _in_gate: bool = false
var _t: float = 0.0

@onready var player: Player = $Player
@onready var _crystal_glow: Sprite2D = $Crystal/Glow


func _ready() -> void:
	Game.run.clock.running = false
	Game.in_boss_room = false
	Sfx.music(&"town")
	_rng.randomize()
	shop = Game.run.market
	shop.begin_visit(_rng, Game.run.unlocked_floors)
	_read_markers()
	_build_talk()
	_spawn_villagers()
	# No attacks in town, and the weapons are put away (hip or back).
	player.armed = false
	player.global_position = arrival_point(Game.town_arrival)
	player.facing = Vector2.DOWN if Game.town_arrival in [&"gate", &"crystal"] else Vector2.UP
	Game.town_arrival = &""
	_in_gate = gate.has_point(player.global_position)
	# Feet are 6 px below the player's origin (layered_sprite FEET_ROW).
	player.add_child(GroundShadow.make(Vector2i(16, 6), Vector2(0, 7)))
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
		shop.begin_visit(_rng, Game.run.unlocked_floors)
	if args.has("wanted"):
		shop.wanted.clear()
		for id in String(args["wanted"]).split(",", false):
			shop.wanted.append(StringName(id))
	if args.has("sold"):
		for part in String(args["sold"]).split(",", false):
			var kv := part.split(":")
			shop.factors[StringName(kv[0])] = maxf(Market.MIN_FACTOR, 1.0 - Market.DECAY_PER_SALE * int(kv[1]))
	if args.has("outfits"):
		for id in ItemDB.ids(&"outfit"):
			Game.run.unlock_outfit(id)
	if args.has("player"):
		var xy := String(args["player"]).split(",")
		player.global_position = Vector2(float(xy[0]), float(xy[1]))
	if args.has("panel"):
		_debug_panel.call_deferred(StringName(String(args["panel"])), String(args.get("tab", "")),
				int(args.get("pick", "-1")), int(args.get("qty", "1")))


func _debug_panel(id: StringName, tab: String, pick: int, qty: int) -> void:
	var p := open_panel(id)
	if p is ShopPanel and tab != "":
		(p as ShopPanel).select_tab(StringName(tab))
	if pick < 0:
		return
	if p is ShopPanel:
		var s := p as ShopPanel
		if s.tab == &"sell":
			s.select_sell(pick)
			s.set_qty(qty)
		else:
			s.select_buy(pick)
	elif p is SmithPanel:
		(p as SmithPanel).select(pick)
	elif p is WardrobePanel:
		var w := p as WardrobePanel
		w._grab.call_deferred(w.outfit_cells[pick])


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
	_crystal_glow.modulate.a = 0.7 + 0.3 * sin(_t * 2.2)
	if near != &"" and _panel == null and not get_tree().paused and Input.is_action_just_pressed(&"interact"):
		open_panel(near)
	_update_gate()
	_update_note(delta, Input.is_action_just_pressed(&"attack"))


## Walking into the tower entrance: floor 1 straight away, or the floor list.
func _update_gate() -> void:
	var inside := player.state != Player.State.DEAD and gate.has_point(player.global_position)
	var stepped_in := inside and not _in_gate
	_in_gate = inside
	if not stepped_in or _panel != null or get_tree().paused:
		return
	enter_tower()


## Enters floor 1, or opens the floor list when more floors are unlocked.
func enter_tower() -> void:
	if Game.run.unlocked_floors > 1:
		open_panel(&"teleport")
		return
	Dungeon.requested_floor = 1
	Game.goto(Dungeon.SCENE)


## Attack in town (`pressed`): no swing, a short note over the player instead.
func _update_note(delta: float, pressed: bool) -> void:
	if pressed and _panel == null and not get_tree().paused and not UiKit.gameplay_input_blocked():
		_note_time = NOTE_TIME
	_note_time = maxf(_note_time - delta, 0.0)
	_note.visible = _note_time > 0.0
	if _note.visible:
		var p := player.global_position + Vector2(-50, -30)
		_note.position = Vector2(clampf(p.x, 2, SCREEN.x - 102), maxf(p.y, 14))
		_note.modulate.a = minf(_note_time / 0.3, 1.0)


## Opens the panel of a spot (shop, smith, wardrobe, or teleport: the floor
## list at the tower entrance) and returns it.
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
			_panel.panel_title = "Entrada da torre"
		&"wardrobe":
			_panel = WardrobePanelScript.new() as WardrobePanel
		_:
			return null
	_panel.closed.connect(func() -> void: _panel = null)
	add_child(_panel)
	_panel.open()
	return _panel


## Line the NPC at `id` says now ("" for a spot with no speaker).
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
	return TownLogic.nearest_spot(player.global_position, spots, REACH)


func _update_hint(items: int) -> void:
	if near == &"" or _panel != null:
		_hint.visible = false
		return
	_hint.visible = true
	_hint.text = "E  %s" % SPOT_NAMES[near]
	var ok := TownLogic.can_act(near, items, Forge.any_craftable(Game.run))
	_hint.add_theme_color_override("font_color", UiKit.COLOR_ITEM if ok else UiKit.COLOR_MUTED)
	var p := spots[near] + Vector2(-50, -36)
	_hint.position = Vector2(clampf(p.x, 2, SCREEN.x - 102), p.y)


func _update_bubble(items: int) -> void:
	var text := line_for(near, items) if _panel == null else ""
	var at := _speakers.get(near, Vector2.ZERO) as Vector2
	var talker := _nearest_villager() if near == &"" and _panel == null else null
	for v in _villagers:
		v.talking = v == talker
		v.look_at_pos = player.global_position
	if talker != null:
		text = talker.line
		at = talker.position + Vector2(0, 2)
	if text == "":
		_bubble.hide_bubble()
		return
	_bubble.position = at
	_bubble.say(text)


## Villager whose feet are within VILLAGER_REACH of the player's, or null.
func _nearest_villager() -> Villager:
	if player == null or player.state == Player.State.DEAD:
		return null
	var feet := player.global_position + Vector2(0, 6)
	var best: Villager = null
	var best_d := VILLAGER_REACH
	for v in _villagers:
		var d := v.position.distance_to(feet)
		if d < best_d:
			best = v
			best_d = d
	return best


# --- reading the scene ------------------------------------------------------

## Where the player appears: Arrivals/Gate after walking back down the tower,
## Arrivals/Crystal after a teleport, else Arrivals/Spawn.
func arrival_point(arrival: StringName) -> Vector2:
	var marker := get_node_or_null(NodePath("Arrivals/" + String(arrival).capitalize())) as Node2D
	if arrival == &"" or marker == null:
		marker = $Arrivals/Spawn as Node2D
	return marker.position


func _read_markers() -> void:
	for m: Node2D in $Spots.get_children():
		var id := StringName(String(m.name).to_snake_case())
		spots[id] = m.position
		_ctas[id] = m.get_node(^"Ring") as TownCta
		_glow_targets[id] = get_node(GLOW_TARGETS[id]) as CanvasItem
	for id: StringName in SPEAKERS:
		_speakers[id] = (get_node(SPEAKERS[id]) as Node2D).position + Vector2(0, 2)
	var area := $Gate as Area2D
	var shape := area.get_node(^"Shape") as CollisionShape2D
	var size := (shape.shape as RectangleShape2D).size
	gate = Rect2(area.position + shape.position - size / 2.0, size)
	# The foot of the tower steps always pings: it is where the run starts.
	(area.get_node(^"Ring") as TownCta).active = true


## Hint, bubble and note: a screen layer (no camera here, so screen and world
## coordinates match), no CanvasModulate tint, above props and the HUD
## (layer 5), below the panels (layer 30).
func _build_talk() -> void:
	var overlay := CanvasLayer.new()
	overlay.name = "Talk"
	overlay.layer = 8
	add_child(overlay)
	_hint = UiKit.label("", UiKit.COLOR_ITEM, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.size = Vector2(100, 10)
	_hint.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.06))
	_hint.add_theme_constant_override("outline_size", 2)
	_hint.visible = false
	overlay.add_child(_hint)
	_bubble = SpeechBubble.new()
	overlay.add_child(_bubble)
	_note = UiKit.label("Sem armas na cidade", UiKit.COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_note.size = Vector2(100, 10)
	_note.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.06))
	_note.add_theme_constant_override("outline_size", 2)
	_note.visible = false
	overlay.add_child(_note)


## One villager per Walks/<Path2D> loop, each with a different look.
func _spawn_villagers() -> void:
	var looks: Array = VILLAGER_LOOKS.keys()
	looks.shuffle()
	var walks := $Walks.get_children()
	for i in mini(walks.size(), looks.size()):
		var walk := walks[i] as Path2D
		var look: String = looks[i]
		var pts: Array[Vector2] = []
		for k in walk.curve.point_count:
			pts.append(walk.position + walk.curve.get_point_position(k))
		var v := Villager.new()
		v.setup(load(VILLAGER_ART % look) as Texture2D, Color.WHITE, pts)
		v.speed = VILLAGER_LOOKS[look]
		v.line = LINES["villager_" + look]
		v.name = "Villager_" + look
		add_child(v)
		_villagers.append(v)
