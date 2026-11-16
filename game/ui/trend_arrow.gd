class_name TrendArrow
extends Control
## Small pixel triangle with a dark outline (7x4 inside a 9x6 box): green up
## for a better stat or a wanted item, red down for a worse stat or a
## saturated one. Drawn, so it does not depend on font glyphs.

const OUTLINE := Color(0.06, 0.04, 0.05)

var up: bool = true
var color: Color = UiKit.COLOR_GOOD


static func make(is_up: bool, c: Color = Color(0, 0, 0, 0)) -> TrendArrow:
	var a := TrendArrow.new()
	a.up = is_up
	a.color = c if c.a > 0.0 else (UiKit.COLOR_GOOD if is_up else UiKit.COLOR_DANGER)
	return a


func _init() -> void:
	custom_minimum_size = Vector2(9, 6)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var top := floorf((size.y - 6.0) / 2.0)
	for off: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		_tri(Vector2(1, top + 1) + off, OUTLINE)
	_tri(Vector2(1, top + 1), color)


## Rows of width 1, 3, 5, 7 (point up) or 7, 5, 3, 1 (point down).
func _tri(origin: Vector2, c: Color) -> void:
	for i in 4:
		var k := i if up else 3 - i
		draw_rect(Rect2(origin + Vector2(3 - k, i), Vector2(1 + 2 * k, 1)), c)
