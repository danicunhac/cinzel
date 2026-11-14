class_name Hud
extends CanvasLayer
## Life, clock with difficulty level, gold, 3 item slots, floor, exit bar with
## the boss-room block message, and the boss bar. Reads Game.run and the
## player every frame; process_mode ALWAYS so it stays drawn while paused.
## Finds the player in group "player" and the boss in group "boss" (a boss
## emits boss_hp(hp, max_hp)); the boss bar hides when there is none.

const BLOCKED_TEXT := "Não dá para sair durante o chefe"
const BLOCKED_TIME := 2.5
const HEART_TEX := preload("res://assets/ui/heart.png")
const COIN_TEX := preload("res://assets/ui/coin.png")
const HP_COLOR := Color(0.86, 0.2, 0.2)
const EXIT_COLOR := Color(0.55, 0.8, 1.0)
const BOSS_COLOR := Color(0.75, 0.12, 0.12)
const BAR_BG := Color(0.07, 0.05, 0.06, 0.9)
const DANGER_LEVEL := 5

## In town: floor label reads "Cidade", no exit or boss bar.
@export var in_town: bool = false

var player: Player = null
var boss: Node = null
var boss_hp: int = 0
var boss_max: int = 1

var hp_fill: ColorRect
var hp_label: Label
var gold_label: Label
var clock_label: Label
var floor_label: Label
var slot_icons: Array[TextureRect] = []
var exit_box: Control
var exit_fill: ColorRect
var blocked_label: Label
var boss_box: Control
var boss_fill: ColorRect
var boss_label: Label

var _blocked_left: float = 0.0
var _items_shown: Array[StringName] = []
var _items_dirty: bool = true


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		var p := get_tree().get_first_node_in_group(&"player") as Player
		if p != null:
			bind_player(p)
	if not in_town:
		var b := get_tree().get_first_node_in_group(&"boss")
		var bound: Node = boss if is_instance_valid(boss) else null
		if b != bound or (bound == null and boss_box.visible):
			_bind_boss(b)
	_update_stats()
	if _blocked_left > 0.0:
		_blocked_left -= delta
		blocked_label.visible = _blocked_left > 0.0


func bind_player(p: Player) -> void:
	player = p
	if in_town:
		return
	p.exit_progress.connect(_on_exit_progress)
	p.exit_blocked.connect(_on_exit_blocked)


func current_floor_text() -> String:
	if in_town:
		return "Cidade"
	var d := get_parent() as Dungeon
	return "Andar %d" % (d.current_floor if d != null else Dungeon.requested_floor)


func _update_stats() -> void:
	var run := Game.run
	var hp := run.hp
	var max_hp := run.stats().max_hp
	if player != null and is_instance_valid(player) and player.health != null:
		hp = player.health.hp
		max_hp = player.health.max_hp
	hp_fill.size.x = roundf(58.0 * clampf(float(hp) / maxf(max_hp, 1), 0.0, 1.0))
	hp_label.text = "%d/%d" % [hp, max_hp]
	gold_label.text = "%d" % run.gold
	var level := run.clock.level()
	clock_label.text = "%s  Nível %d" % [UiKit.format_time(run.clock.seconds), level]
	clock_label.add_theme_color_override("font_color", UiKit.COLOR_DANGER if level >= DANGER_LEVEL else Color(0.95, 0.9, 0.82))
	floor_label.text = current_floor_text()
	if run.items != _items_shown:
		_items_shown = run.items.duplicate()
		for i in slot_icons.size():
			slot_icons[i].texture = UiKit.item_icon(run.items[i]) if i < run.items.size() else null
	if boss_box.visible:
		boss_fill.size.x = roundf(158.0 * clampf(float(boss_hp) / maxf(boss_max, 1), 0.0, 1.0))


func _on_exit_progress(p: float) -> void:
	exit_box.visible = p > 0.0 and p < 1.0
	exit_fill.size.x = roundf(98.0 * clampf(p, 0.0, 1.0))


func _on_exit_blocked() -> void:
	blocked_label.visible = true
	_blocked_left = BLOCKED_TIME


func _bind_boss(b: Node) -> void:
	if is_instance_valid(boss) and boss.has_signal(&"boss_hp") \
			and boss.is_connected(&"boss_hp", _on_boss_hp):
		boss.disconnect(&"boss_hp", _on_boss_hp)
	boss = b
	boss_box.visible = b != null
	if b == null:
		return
	boss_hp = 1
	boss_max = 1
	var name_v: Variant = b.get(&"display_name")
	boss_label.text = String(name_v) if name_v is String and String(name_v) != "" else "Chefe"
	var health := b.get_node_or_null(^"Health") as Health
	if health != null:
		boss_hp = health.hp
		boss_max = health.max_hp
	if b.has_signal(&"boss_hp"):
		b.connect(&"boss_hp", _on_boss_hp)


func _on_boss_hp(hp: int, max_hp: int) -> void:
	boss_hp = hp
	boss_max = max_hp


# --- layout (320x180) ---

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Dark backing so the numbers read over bright roofs and floors.
	_backing(root, Rect2(2, 2, 110, 24))
	_backing(root, Rect2(214, 2, 104, 24))
	_icon(root, HEART_TEX, Vector2(4, 4))
	hp_fill = _bar(root, Vector2(15, 4), Vector2(60, 9), HP_COLOR)
	hp_label = _label(root, Vector2(78, 3), Vector2(60, 10))
	_icon(root, COIN_TEX, Vector2(4, 16))
	gold_label = _label(root, Vector2(15, 15), Vector2(60, 10))
	gold_label.add_theme_color_override("font_color", UiKit.COLOR_GOLD)

	clock_label = _label(root, Vector2(196, 3), Vector2(120, 10), HORIZONTAL_ALIGNMENT_RIGHT)
	floor_label = _label(root, Vector2(196, 14), Vector2(120, 10), HORIZONTAL_ALIGNMENT_RIGHT)

	for i in RunState.SLOTS:
		var slot := TextureRect.new()
		slot.texture = UiKit.SLOT_TEX
		slot.position = Vector2(4 + i * 22, 156)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(slot)
		var icon := TextureRect.new()
		icon.position = Vector2(2, 2)
		icon.size = Vector2(16, 16)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		slot_icons.append(icon)

	exit_box = Control.new()
	exit_box.position = Vector2(110, 118)
	exit_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(exit_box)
	_label(exit_box, Vector2(-20, 0), Vector2(140, 10), HORIZONTAL_ALIGNMENT_CENTER).text = "Saindo da torre..."
	exit_fill = _bar(exit_box, Vector2(0, 11), Vector2(100, 6), EXIT_COLOR)
	exit_box.visible = false

	blocked_label = _label(root, Vector2(10, 132), Vector2(300, 10), HORIZONTAL_ALIGNMENT_CENTER)
	blocked_label.text = BLOCKED_TEXT
	blocked_label.add_theme_color_override("font_color", UiKit.COLOR_DANGER)
	blocked_label.visible = false

	boss_box = Control.new()
	boss_box.position = Vector2(80, 158)
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(boss_box)
	boss_label = _label(boss_box, Vector2(0, 0), Vector2(160, 10), HORIZONTAL_ALIGNMENT_CENTER)
	boss_label.add_theme_color_override("font_color", UiKit.COLOR_DANGER)
	boss_fill = _bar(boss_box, Vector2(0, 11), Vector2(160, 7), BOSS_COLOR)
	boss_box.visible = false


func _backing(parent: Control, r: Rect2) -> void:
	var c := ColorRect.new()
	c.color = Color(0.04, 0.03, 0.05, 0.55)
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)


func _icon(parent: Control, tex: Texture2D, pos: Vector2) -> void:
	var t := TextureRect.new()
	t.texture = tex
	t.position = pos
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)


func _label(parent: Control, pos: Vector2, size: Vector2, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Dark frame with a 1px border; returns the fill rect (full width = size - 2).
func _bar(parent: Control, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = BAR_BG
	bg.position = pos
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var fill := ColorRect.new()
	fill.color = color
	fill.position = Vector2(1, 1)
	fill.size = size - Vector2(2, 2)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(fill)
	return fill
