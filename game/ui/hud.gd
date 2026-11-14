class_name Hud
extends CanvasLayer
## Life (ornate bar, beating heart), the special's cooldown slot, toasts, gold (counter that counts up, coin that
## spins and bounces on gain), a small clock block with the difficulty
## level, floor, 3 item slots (light ring on a new item), the exit bar with
## the boss-room block message, and the boss bar. Reads Game.run and the
## player every frame; process_mode ALWAYS so it stays drawn while paused.
## Finds the player in group "player" and the boss in group "boss" (a boss
## emits boss_hp(hp, max_hp)); the boss bar hides when there is none.
## Every element enters by sliding (UiKit.slide_in). Nothing moves at rest
## except the heart, whose beat is the life state.

const BLOCKED_TEXT := "Não dá para sair durante o chefe"
const TOAST_TIME := 1.8
const BLOCKED_TIME := 2.5
const DANGER_LEVEL := 5

const HEART_TEX := preload("res://assets/ui/hud/heart.png")
const COIN_TEX := preload("res://assets/ui/hud/coin.png")
const HOURGLASS_TEX := preload("res://assets/ui/hud/hourglass.png")
const SLOT_TEX := preload("res://assets/ui/hud/slot.png")
const RING_TEX := preload("res://assets/ui/hud/ring.png")
const HP_FRAME_TEX := preload("res://assets/ui/hud/hp_frame.png")
const BOSS_FRAME_TEX := preload("res://assets/ui/hud/boss_frame.png")
const FILL_HP_TEX := preload("res://assets/ui/hud/fill_hp.png")
const FILL_BOSS_TEX := preload("res://assets/ui/hud/fill_boss.png")
const FILL_EXIT_TEX := preload("res://assets/ui/hud/fill_exit.png")
const FILL_TIP_TEX := preload("res://assets/ui/hud/fill_tip.png")

## Sprite sheets (frames side by side).
const HEART_FRAME := Vector2i(13, 12)
const HEART_FRAMES := 4
const COIN_FRAME := Vector2i(9, 9)
const COIN_FRAMES := 6

## Heart: one beat (4 frames) every period; faster at low life.
const LOW_HP := 0.3
const BEAT_SLOW := 1.1
const BEAT_FAST := 0.45
const BEAT_TIME := 0.28

## Gold counter: units per second, at least COUNT_MIN, or COUNT_SPEED times
## the gap, so a big gain still lands in well under a second.
const COUNT_MIN := 40.0
const COUNT_SPEED := 8.0
const COIN_SPIN_FRAME := 0.05
const COIN_BOUNCE := 4
const COIN_HOME := Vector2(4, 18)

## Life lost lingers as a pale trail, then drains.
const TRAIL_HOLD := 0.35
const TRAIL_SPEED := 0.9
const TRAIL_COLOR := Color(1.0, 0.92, 0.78)
const RING_TIME := 0.5

## Bar geometry, from the 9-slice art (hp_frame.png 48x12, boss_frame.png
## 64x16). The margins cover the caps, so only uniform middle columns
## stretch; bars are drawn at the art's own height. The fill runs in the
## groove, which starts inside the caps.
const HP_MARGIN := Vector4i(9, 3, 9, 3)
const HP_GROOVE := Vector4i(5, 3, 5, 3)
const HP_SIZE := Vector2(86, 12)
const BOSS_MARGIN := Vector4i(14, 5, 14, 3)
const BOSS_SIZE := Vector2(244, 16)
const BOSS_FILL := Rect2(8, 5, 228, 8)
const EXIT_SIZE := Vector2(120, 12)

## In town: floor label reads "Cidade", no exit or boss bar.
@export var in_town: bool = false

var player: Player = null
var boss: Node = null
var boss_hp: int = 0
var boss_max: int = 1

var hp_fill: TextureRect
var hp_trail: ColorRect
var hp_label: Label
var heart: TextureRect
var gold_label: Label
var coin: TextureRect
var clock_label: Label
var level_label: Label
var floor_label: Label
var slots: Array[TextureRect] = []
var slot_icons: Array[TextureRect] = []
var exit_box: Control
var exit_fill: TextureRect
var exit_tip: TextureRect
var blocked_box: Control
var blocked_label: Label
var boss_box: Control
var boss_fill: TextureRect
var boss_trail: ColorRect
var boss_tip: TextureRect
var boss_label: Label
var boss_plaque: NinePatchRect
## Special (hold attack) cooldown, next to the item slots.
var special_icon: SpecialIcon
var toast_box: NinePatchRect
var toast_label: Label
## "+2 Gosma de Slime" stack under the life and gold (Game.loot_taken).
var loot_toasts: LootToasts

## Gold shown by the counter (counts toward Game.run.gold).
var gold_shown: float = 0.0
## Slots that played the new-item ring, in order (tests read it).
var rings_played: Array[int] = []
## Seconds into the current heart period.
var heart_time: float = 0.0

var _top_left: Control
var _top_right: Control
var _slot_row: Control
var _blocked_left: float = 0.0
var _toast_left: float = 0.0
var _items_shown: Array[StringName] = []
var _gold_target: int = 0
var _coin_spin: float = -1.0
var _coin_tween: Tween
var _last_hp: int = -1
var _hp_ratio: float = 1.0
var _trail_ratio: float = 1.0
var _trail_hold: float = 0.0
var _boss_ratio: float = 1.0
var _boss_trail_ratio: float = 1.0
var _boss_trail_hold: float = 0.0
var _exit_ratio: float = 0.0
var _pulse: float = 0.0


func _ready() -> void:
	_build()
	_items_shown = Game.run.items.duplicate()
	_refresh_slots(false)
	gold_shown = Game.run.gold
	_gold_target = Game.run.gold
	UiKit.slide_in(_top_left, Vector2(0, -28))
	UiKit.slide_in(_top_right, Vector2(0, -32), 0.05)
	UiKit.slide_in(_slot_row, Vector2(0, 32), 0.1)
	Game.toast_requested.connect(show_toast)
	Game.loot_taken.connect(loot_toasts.push)


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
	_update_stats(delta)
	_pulse = fmod(_pulse + delta, 0.6)
	if _toast_left > 0.0:
		_toast_left -= delta
		toast_box.visible = _toast_left > 0.0
	if _blocked_left > 0.0:
		_blocked_left -= delta
		var show := _blocked_left > 0.0
		blocked_label.visible = show
		blocked_box.visible = show


## Short message on a plaque above the exit bar ("Mochila cheia").
func show_toast(text: String) -> void:
	toast_label.text = text
	var w := UiKit.text_width(text) + 16
	toast_box.size = Vector2(w, 14)
	toast_box.position = Vector2(roundf((UiKit.SCREEN.x - w) / 2.0), 154)
	toast_label.size.x = w
	if not toast_box.visible:
		UiKit.slide_in(toast_box, Vector2(0, 10))
	toast_box.visible = true
	_toast_left = TOAST_TIME


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


## Seconds between heart beats; 0 means no beat (dead).
static func heart_period(hp: int, max_hp: int) -> float:
	if hp <= 0:
		return 0.0
	return BEAT_FAST if float(hp) / maxf(max_hp, 1) < LOW_HP else BEAT_SLOW


## Heart frame at `t` seconds into a beat period: a 4-frame beat, then rest.
static func heart_frame(t: float) -> int:
	if t >= BEAT_TIME:
		return 0
	return [1, 2, 3, 0][clampi(int(t / BEAT_TIME * 4.0), 0, 3)]


## One step of the gold counter toward `target`.
static func count_step(shown: float, target: int, delta: float) -> float:
	var gap := absf(target - shown)
	if gap < 0.01:
		return float(target)
	return move_toward(shown, target, maxf(COUNT_MIN, gap * COUNT_SPEED) * delta)


func _update_stats(delta: float) -> void:
	var run := Game.run
	var hp := run.hp
	var max_hp := run.stats().max_hp
	if player != null and is_instance_valid(player) and player.health != null:
		hp = player.health.hp
		max_hp = player.health.max_hp
	_update_life(hp, max_hp, delta)
	_update_gold(run.gold, delta)
	var level := run.clock.level()
	clock_label.text = UiKit.format_time(run.clock.seconds)
	level_label.text = "Nv %d" % level
	level_label.add_theme_color_override("font_color", UiKit.COLOR_DANGER if level >= DANGER_LEVEL else UiKit.COLOR_MUTED)
	floor_label.text = current_floor_text()
	if player != null and is_instance_valid(player) and player.special != null:
		special_icon.weapon_id = player.weapon_id
		special_icon.set_state(player.special.cooldown_ratio(), player.special.glow())
	if run.items != _items_shown:
		_refresh_slots(true)
	if boss_box.visible:
		_update_boss(delta)
	if exit_box.visible:
		_place_tip(exit_tip, exit_fill)


func _update_life(hp: int, max_hp: int, delta: float) -> void:
	_hp_ratio = clampf(float(hp) / maxf(max_hp, 1), 0.0, 1.0)
	if _last_hp >= 0 and hp < _last_hp:
		# Damage: beat now, flash the heart, hold the trail.
		heart_time = 0.0
		heart.modulate = Color(2.2, 2.0, 2.0)
		create_tween().tween_property(heart, "modulate", Color.WHITE, 0.25)
		_trail_hold = TRAIL_HOLD
	_last_hp = hp
	if _hp_ratio >= _trail_ratio:
		_trail_ratio = _hp_ratio
	elif _trail_hold > 0.0:
		_trail_hold -= delta
	else:
		_trail_ratio = move_toward(_trail_ratio, _hp_ratio, TRAIL_SPEED * delta)
	var inner := HP_SIZE.x - HP_GROOVE.x - HP_GROOVE.z
	hp_fill.size.x = roundf(inner * _hp_ratio)
	hp_trail.size.x = roundf(inner * _trail_ratio)
	hp_label.text = "%d/%d" % [hp, max_hp]
	var low := hp > 0 and _hp_ratio < LOW_HP
	hp_label.add_theme_color_override("font_color", UiKit.COLOR_DANGER if low else UiKit.COLOR_TEXT)
	var period := heart_period(hp, max_hp)
	if period > 0.0:
		heart_time += delta
		if heart_time >= period:
			heart_time = fmod(heart_time, period)
	(heart.texture as AtlasTexture).region.position.x = heart_frame(heart_time if period > 0.0 else BEAT_TIME) * HEART_FRAME.x


func _update_gold(gold: int, delta: float) -> void:
	if gold > _gold_target:
		_coin_gain()
	_gold_target = gold
	gold_shown = count_step(gold_shown, gold, delta)
	gold_label.text = "%d" % int(gold_shown)
	gold_label.add_theme_color_override("font_color", UiKit.COLOR_ITEM if gold_shown != gold else UiKit.COLOR_GOLD)
	var f := 0
	if _coin_spin >= 0.0:
		_coin_spin += delta
		f = int(_coin_spin / COIN_SPIN_FRAME)
		if f >= COIN_FRAMES:
			_coin_spin = -1.0
			f = 0
	(coin.texture as AtlasTexture).region.position.x = f * COIN_FRAME.x


## Gold went up: one spin and a bounce.
func _coin_gain() -> void:
	_coin_spin = 0.0
	var home := COIN_HOME
	if _coin_tween != null and _coin_tween.is_valid():
		_coin_tween.kill()
	var t := create_tween()
	_coin_tween = t
	t.tween_property(coin, "position", home - Vector2(0, COIN_BOUNCE), 0.08).set_ease(Tween.EASE_OUT)
	t.tween_property(coin, "position", home, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _refresh_slots(ring_new: bool) -> void:
	var run := Game.run
	for i in slot_icons.size():
		var id: StringName = run.items[i] if i < run.items.size() else &""
		var old: StringName = _items_shown[i] if i < _items_shown.size() else &""
		slot_icons[i].texture = UiKit.item_icon(id) if id != &"" else null
		if ring_new and id != &"" and id != old:
			_ring(i)
	_items_shown = run.items.duplicate()


## New item: a light ring grows out of the slot and fades, the slot flares.
func _ring(i: int) -> void:
	rings_played.append(i)
	var slot := slots[i]
	var ring := TextureRect.new()
	ring.texture = RING_TEX
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.position = Vector2(-1, -1)
	ring.size = Vector2(24, 24)
	ring.pivot_offset = Vector2(12, 12)
	ring.scale = Vector2(0.5, 0.5)
	slot.add_child(ring)
	var t := create_tween().set_parallel()
	t.tween_property(ring, "scale", Vector2(1.75, 1.75), RING_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(ring, "modulate:a", 0.0, RING_TIME).set_ease(Tween.EASE_IN)
	slot.modulate = Color(1.8, 1.5, 1.1)
	t.tween_property(slot, "modulate", Color.WHITE, RING_TIME)
	t.chain().tween_callback(ring.queue_free)


func _update_boss(delta: float) -> void:
	_boss_ratio = clampf(float(boss_hp) / maxf(boss_max, 1), 0.0, 1.0)
	if _boss_ratio > _boss_trail_ratio:
		_boss_trail_ratio = _boss_ratio
	elif _boss_trail_hold > 0.0:
		_boss_trail_hold -= delta
	else:
		_boss_trail_ratio = move_toward(_boss_trail_ratio, _boss_ratio, TRAIL_SPEED * delta)
	boss_fill.size.x = roundf(BOSS_FILL.size.x * _boss_ratio)
	boss_trail.size.x = roundf(BOSS_FILL.size.x * _boss_trail_ratio)
	_place_tip(boss_tip, boss_fill)


## Light pulse riding the end of a fill.
func _place_tip(tip: TextureRect, fill: TextureRect) -> void:
	tip.visible = fill.size.x >= 2.0
	tip.position = Vector2(fill.position.x + fill.size.x - 2, fill.position.y)
	tip.size.y = fill.size.y
	tip.modulate.a = 0.55 + 0.45 * sin(_pulse / 0.6 * TAU)


func _on_exit_progress(p: float) -> void:
	var show := p > 0.0 and p < 1.0
	if show and not exit_box.visible:
		UiKit.slide_in(exit_box, Vector2(0, 10))
	exit_box.visible = show
	_exit_ratio = clampf(p, 0.0, 1.0)
	exit_fill.size.x = roundf((EXIT_SIZE.x - HP_GROOVE.x - HP_GROOVE.z) * _exit_ratio)
	_place_tip(exit_tip, exit_fill)


func _on_exit_blocked() -> void:
	if not blocked_box.visible:
		UiKit.slide_in(blocked_box, Vector2(0, 10))
	blocked_label.visible = true
	blocked_box.visible = true
	_blocked_left = BLOCKED_TIME


func _bind_boss(b: Node) -> void:
	if is_instance_valid(boss) and boss.has_signal(&"boss_hp") \
			and boss.is_connected(&"boss_hp", _on_boss_hp):
		boss.disconnect(&"boss_hp", _on_boss_hp)
	boss = b
	var was_visible := boss_box.visible
	boss_box.visible = b != null
	if b == null:
		return
	boss_hp = 1
	boss_max = 1
	var name_v: Variant = b.get(&"display_name")
	_set_boss_name(String(name_v) if name_v is String and String(name_v) != "" else "Chefe")
	var health := b.get_node_or_null(^"Health") as Health
	if health != null:
		boss_hp = health.hp
		boss_max = health.max_hp
	if b.has_signal(&"boss_hp"):
		b.connect(&"boss_hp", _on_boss_hp)
	_boss_trail_ratio = clampf(float(boss_hp) / maxf(boss_max, 1), 0.0, 1.0)
	if not was_visible:
		UiKit.slide_in(boss_box, Vector2(0, 30))


func _on_boss_hp(hp: int, max_hp: int) -> void:
	if hp < boss_hp:
		_boss_trail_hold = TRAIL_HOLD
	boss_hp = hp
	boss_max = max_hp


func _set_boss_name(text: String) -> void:
	boss_label.text = text
	var w := UiKit.text_width(text) + 16
	boss_plaque.size = Vector2(w, 14)
	boss_plaque.position = Vector2(floorf((BOSS_SIZE.x - w) / 2.0), -10)
	boss_label.size.x = w


# --- layout (480x270; 8 px Silkscreen, art 1:1) ---

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var w := UiKit.SCREEN.x
	var h := UiKit.SCREEN.y

	# Top left: life and gold.
	_top_left = _group(root, Vector2(2, 2))
	heart = _sheet_icon(_top_left, HEART_TEX, HEART_FRAME, Vector2(1, 1))
	var hp_frame := _nine(_top_left, HP_FRAME_TEX, HP_MARGIN, Vector2(15, 1), HP_SIZE)
	var groove := Vector2(HP_GROOVE.x, HP_GROOVE.y)
	var groove_h := HP_SIZE.y - HP_GROOVE.y - HP_GROOVE.w
	hp_trail = ColorRect.new()
	hp_trail.color = TRAIL_COLOR
	hp_trail.position = groove
	hp_trail.size = Vector2(0, groove_h)
	hp_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_frame.add_child(hp_trail)
	hp_fill = _fill(hp_frame, FILL_HP_TEX, Rect2(groove, Vector2(0, groove_h)))
	hp_label = _label(_top_left, Vector2(104, 2), Vector2(48, 10))
	coin = _sheet_icon(_top_left, COIN_TEX, COIN_FRAME, COIN_HOME)
	gold_label = _label(_top_left, Vector2(16, 16), Vector2(80, 10))
	gold_label.add_theme_color_override("font_color", UiKit.COLOR_GOLD)

	loot_toasts = LootToasts.new()
	loot_toasts.position = Vector2(4, 30)
	root.add_child(loot_toasts)

	# Top right: floor, then the small clock block (time and level).
	_top_right = _group(root, Vector2(w - 84, 2))
	floor_label = _label(_top_right, Vector2(0, 1), Vector2(82, 10), HORIZONTAL_ALIGNMENT_RIGHT)
	var clock := UiKit.plaque(Vector2(80, 13))
	clock.position = Vector2(2, 13)
	_top_right.add_child(clock)
	var glass := TextureRect.new()
	glass.texture = HOURGLASS_TEX
	glass.position = Vector2(5, 2)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock.add_child(glass)
	clock_label = _label(clock, Vector2(13, 1), Vector2(30, 10))
	clock_label.add_theme_color_override("font_color", UiKit.COLOR_MUTED)
	level_label = _label(clock, Vector2(46, 1), Vector2(30, 10), HORIZONTAL_ALIGNMENT_RIGHT)

	# Bottom left: item slots.
	_slot_row = _group(root, Vector2(4, h - 26))
	for i in RunState.SLOTS:
		var slot := TextureRect.new()
		slot.texture = SLOT_TEX
		slot.position = Vector2(i * 24, 0)
		slot.size = Vector2(22, 22)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slot_row.add_child(slot)
		var icon := TextureRect.new()
		icon.position = Vector2(3, 3)
		icon.size = Vector2(16, 16)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		slots.append(slot)
		slot_icons.append(icon)
	special_icon = SpecialIcon.new()
	special_icon.position = Vector2(RunState.SLOTS * 24 + 6, 0)
	_slot_row.add_child(special_icon)

	# Centre: exit hold bar.
	exit_box = _group(root, Vector2(roundf((w - EXIT_SIZE.x) / 2.0), 172))
	_label(exit_box, Vector2(-20, 0), Vector2(EXIT_SIZE.x + 40, 10), HORIZONTAL_ALIGNMENT_CENTER).text = "Saindo da torre..."
	var exit_frame := _nine(exit_box, HP_FRAME_TEX, HP_MARGIN, Vector2(0, 11), EXIT_SIZE)
	exit_fill = _fill(exit_frame, FILL_EXIT_TEX, Rect2(groove, Vector2(0, groove_h)))
	exit_tip = _tip(exit_frame)
	exit_box.visible = false

	var bw := UiKit.text_width(BLOCKED_TEXT) + 16
	blocked_box = UiKit.plaque(Vector2(bw, 14))
	blocked_box.position = Vector2(roundf((w - bw) / 2.0), 196)
	root.add_child(blocked_box)
	blocked_label = _label(blocked_box, Vector2(0, 1), Vector2(bw, 10), HORIZONTAL_ALIGNMENT_CENTER)
	blocked_label.text = BLOCKED_TEXT
	blocked_label.add_theme_color_override("font_color", UiKit.COLOR_DANGER)
	blocked_label.visible = false
	blocked_box.visible = false

	toast_box = UiKit.plaque(Vector2(40, 14))
	root.add_child(toast_box)
	toast_label = _label(toast_box, Vector2(0, 1), Vector2(40, 10), HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.add_theme_color_override("font_color", UiKit.COLOR_ITEM)
	toast_box.visible = false

	# Bottom centre: boss bar, name on a plaque across its top edge.
	boss_box = _group(root, Vector2(roundf((w - BOSS_SIZE.x) / 2.0), h - BOSS_SIZE.y - 3))
	var boss_frame := _nine(boss_box, BOSS_FRAME_TEX, BOSS_MARGIN, Vector2.ZERO, BOSS_SIZE)
	boss_trail = ColorRect.new()
	boss_trail.color = TRAIL_COLOR
	boss_trail.position = BOSS_FILL.position
	boss_trail.size = BOSS_FILL.size
	boss_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_frame.add_child(boss_trail)
	boss_fill = _fill(boss_frame, FILL_BOSS_TEX, BOSS_FILL)
	boss_tip = _tip(boss_frame)
	boss_plaque = UiKit.plaque(Vector2(40, 14))
	boss_box.add_child(boss_plaque)
	boss_label = _label(boss_plaque, Vector2(0, 1), Vector2(40, 10), HORIZONTAL_ALIGNMENT_CENTER)
	boss_label.add_theme_color_override("font_color", UiKit.COLOR_DANGER)
	_set_boss_name("Chefe")
	boss_box.visible = false


func _group(parent: Control, pos: Vector2) -> Control:
	var c := Control.new()
	c.position = pos
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


func _sheet_icon(parent: Control, tex: Texture2D, frame: Vector2i, pos: Vector2) -> TextureRect:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(Vector2.ZERO, frame)
	var t := TextureRect.new()
	t.texture = a
	t.position = pos
	t.size = Vector2(frame)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t


func _nine(parent: Control, tex: Texture2D, m: Vector4i, pos: Vector2, size: Vector2) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = tex
	n.patch_margin_left = m.x
	n.patch_margin_top = m.y
	n.patch_margin_right = m.z
	n.patch_margin_bottom = m.w
	n.position = pos
	n.size = size
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	return n


## Fill: a 1 px wide ramp tiled across the groove.
func _fill(parent: Control, tex: Texture2D, r: Rect2) -> TextureRect:
	var f := TextureRect.new()
	f.texture = tex
	f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	f.stretch_mode = TextureRect.STRETCH_SCALE
	f.position = r.position
	f.size = r.size
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(f)
	return f


func _tip(parent: Control) -> TextureRect:
	var t := TextureRect.new()
	t.texture = FILL_TIP_TEX
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size = Vector2(3, 6)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.visible = false
	parent.add_child(t)
	return t


func _label(parent: Control, pos: Vector2, size: Vector2, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
