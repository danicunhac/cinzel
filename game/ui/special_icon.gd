class_name SpecialIcon
extends Control
## HUD slot of the special (hold attack). The weapon's icon (or a light
## diamond until the icon art lands) on the slot frame; a dark pie covers
## it while the special cools down, the frame lights up blue when it is
## ready, and flares once when it comes back.

const SLOT_TEX := preload("res://assets/ui/hud/slot.png")
const SKILL_COLOR := Color(0.6, 0.95, 1.0)
const SIZE := Vector2(22, 22)

## 1 just used .. 0 ready.
var cooldown_ratio: float = 0.0
## 0..1 charge of the held attack.
var charge: float = 0.0
var weapon_id: StringName = &"":
	set(v):
		if v != weapon_id:
			weapon_id = v
			_icon = UiKit.item_icon(v)
			queue_redraw()

var _icon: Texture2D = null
var _was_ready: bool = true


func _ready() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(ratio: float, charge_fill: float) -> void:
	var ready := ratio <= 0.0
	if ready and not _was_ready:
		modulate = Color(1.8, 1.8, 2.2)
		create_tween().tween_property(self, "modulate", Color.WHITE, 0.35)
	_was_ready = ready
	if not is_equal_approx(ratio, cooldown_ratio) or not is_equal_approx(charge_fill, charge):
		cooldown_ratio = ratio
		charge = charge_fill
		queue_redraw()


func _draw() -> void:
	draw_texture(SLOT_TEX, Vector2.ZERO)
	var c := SIZE / 2.0
	if _icon != null:
		var dim := Color(0.55, 0.55, 0.65) if cooldown_ratio > 0.0 else Color.WHITE
		draw_texture_rect(_icon, Rect2(Vector2(3, 3), Vector2(16, 16)), false, dim)
	else:
		var d := PackedVector2Array([c + Vector2(0, -6), c + Vector2(5, 0), c + Vector2(0, 6), c + Vector2(-5, 0)])
		draw_colored_polygon(d, Color(SKILL_COLOR, 0.85))
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -3), c + Vector2(2, 0), c + Vector2(0, 3), c + Vector2(-2, 0)]), Color.WHITE)
	if cooldown_ratio > 0.0:
		var pts := PackedVector2Array([c])
		var steps := 20
		for i in steps + 1:
			var a := -PI / 2.0 + TAU * cooldown_ratio * (float(i) / steps)
			pts.append(c + Vector2.from_angle(a) * 10.0)
		# A sliver too thin to triangulate is skipped.
		if cooldown_ratio > 0.03:
			draw_colored_polygon(pts, Color(0.02, 0.02, 0.05, 0.72))
		# The part already recharged, as a light arc on the rim.
		var done_from := -PI / 2.0 + TAU * cooldown_ratio
		draw_arc(c, 9.5, done_from, -PI / 2.0 + TAU, 20, Color(SKILL_COLOR, 0.9), 1.0)
	else:
		draw_rect(Rect2(Vector2(1, 1), SIZE - Vector2(2, 2)), Color(SKILL_COLOR, 0.8), false, 1.0)
	if charge > 0.0:
		draw_rect(Rect2(Vector2(3, SIZE.y - 4), Vector2((SIZE.x - 6) * charge, 2)), Color(SKILL_COLOR, 0.95))
