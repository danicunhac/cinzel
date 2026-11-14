class_name WeaponFx
extends Node2D
## Light drawn by the weapon, in world space (top_level), additive:
##   the charge glow around the hand while the attack is held (it fills up,
##   then pulses white when the special is ready to fire), and
##   fading light trails of swings and specials (arcs, lines, rings).

const CHARGE_COLOR := Color(0.55, 0.9, 1.0)
const STAGE_ONE_COLOR := Color(1.0, 0.85, 0.45)
const SKILL_COLOR := Color(0.6, 0.95, 1.0)
const SWING_COLOR := Color(1.0, 0.95, 0.85)
## Normal swings: warm amber band with a white edge.
const SLASH_COLOR := Color(1.0, 0.86, 0.6)
const SLASH_LIFE := 0.15

## 0..1 fill of the charge (SpecialCharge.glow), drawn at `hand`.
var glow: float = 0.0
var charged: bool = false
var stage_one: bool = false
var hand: Vector2 = Vector2.ZERO

var _trails: Array[Trail] = []
var _t: float = 0.0


class Trail:
	var kind: StringName
	var a: Vector2
	var b: Vector2
	var radius: float
	var from_angle: float
	var to_angle: float
	var width: float
	var color: Color
	var life: float
	var age: float = 0.0


func _ready() -> void:
	top_level = true
	z_index = 10
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func arc(center: Vector2, radius: float, from_angle: float, to_angle: float, color: Color, life: float, width: float = 3.0) -> void:
	var t := _new(&"arc", color, life, width)
	t.a = center
	t.radius = radius
	t.from_angle = from_angle
	t.to_angle = to_angle


## A filled crescent from `from_angle` to `to_angle` (radians, swept in that
## order), `thickness` px deep at its middle, that sweeps in then fades.
func slash(center: Vector2, radius: float, from_angle: float, to_angle: float, thickness: float,
		color: Color = SLASH_COLOR, life: float = SLASH_LIFE) -> void:
	var t := _new(&"slash", color, life, thickness)
	t.a = center
	t.radius = radius
	t.from_angle = from_angle
	t.to_angle = to_angle


## A straight jab of light (spear) from `a` to `b`.
func jab(a: Vector2, b: Vector2, width: float, color: Color = SLASH_COLOR, life: float = SLASH_LIFE) -> void:
	var t := _new(&"jab", color, life, width)
	t.a = a
	t.b = b


func line(a: Vector2, b: Vector2, color: Color, life: float, width: float = 4.0) -> void:
	var t := _new(&"line", color, life, width)
	t.a = a
	t.b = b


func ring(center: Vector2, radius: float, color: Color, life: float, width: float = 3.0) -> void:
	arc(center, radius, 0.0, TAU, color, life, width)


func _new(kind: StringName, color: Color, life: float, width: float) -> Trail:
	var t := Trail.new()
	t.kind = kind
	t.color = color
	t.life = life
	t.width = width
	_trails.append(t)
	return t


func _process(delta: float) -> void:
	_t += delta
	for t in _trails:
		t.age += delta
	_trails = _trails.filter(func(t: Trail) -> bool: return t.age < t.life)
	queue_redraw()


func _draw() -> void:
	for t in _trails:
		var k := 1.0 - t.age / t.life
		var c := Color(t.color, t.color.a * k)
		match t.kind:
			&"arc":
				draw_arc(t.a, t.radius, t.from_angle, t.to_angle, 24, c, t.width * (0.5 + 0.5 * k))
				draw_arc(t.a, t.radius - t.width, t.from_angle, t.to_angle, 24, Color(c, c.a * 0.4), t.width * 0.6)
			&"line":
				draw_line(t.a, t.b, c, t.width * (0.4 + 0.6 * k))
				draw_line(t.a, t.b, Color(1, 1, 1, c.a), maxf(1.0, t.width * 0.3))
			&"slash":
				_draw_slash(t, k)
			&"jab":
				var grow := minf(t.age / (t.life * 0.35), 1.0)
				var tip := t.a.lerp(t.b, grow)
				var n := (t.b - t.a).normalized().orthogonal() * t.width * 0.5 * k
				var mid := t.a.lerp(tip, 0.5)
				var jc := Color(c, c.a * 0.7)
				draw_primitive(PackedVector2Array([t.a + n * 0.3, mid + n, tip, mid - n]), PackedColorArray([jc, jc, jc, jc]), PackedVector2Array())
				draw_line(t.a.lerp(tip, 0.25), tip, Color(1, 1, 1, c.a), 1.0)
	if glow <= 0.0:
		return
	var col := STAGE_ONE_COLOR if stage_one else CHARGE_COLOR
	if charged:
		var p := 0.5 + 0.5 * sin(_t * 22.0)
		draw_circle(hand, 3.0 + p, Color(1, 1, 1, 0.9))
		draw_circle(hand, 6.0 + p, Color(col, 0.45), false, 2.0)
		draw_arc(hand, 13.0 + 2.0 * p, 0.0, TAU, 24, Color(col, 0.8), 1.0)
		for i in 4:
			var a := _t * 5.0 + i * TAU / 4.0
			draw_circle(hand + Vector2.from_angle(a) * (12.0 + 2.0 * p), 1.0, Color.WHITE)
	else:
		draw_circle(hand, 1.0 + 2.0 * glow, Color(col, 0.5 + 0.5 * glow))
		draw_arc(hand, 12.0, -PI / 2.0, -PI / 2.0 + TAU * glow, 24, Color(col, 0.7), 1.5)


## Crescent: outer edge at radius, inner edge pulled in by thickness at the
## middle and meeting the outer edge at both ends; the leading part shows
## first (sweep over the first 40% of the life).
func _draw_slash(t: Trail, k: float) -> void:
	var sweep := minf(t.age / (t.life * 0.4), 1.0)
	var steps := 14
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in steps + 1:
		var u := float(i) / steps * sweep
		var a := lerpf(t.from_angle, t.to_angle, u)
		var depth := t.width * sin(PI * u) * (0.6 + 0.4 * k)
		outer.append(t.a + Vector2.from_angle(a) * t.radius)
		inner.append(t.a + Vector2.from_angle(a) * (t.radius - depth))
	var fill := Color(t.color, 0.8 * k)
	var cols := PackedColorArray([fill, fill, fill, fill])
	for i in steps:
		# Quads, not one polygon: the ends are thin enough to fail triangulation.
		draw_primitive(PackedVector2Array([outer[i], outer[i + 1], inner[i + 1], inner[i]]), cols, PackedVector2Array())
	draw_polyline(outer, Color(1, 1, 1, 0.95 * k), 2.0)
