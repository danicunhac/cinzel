class_name SpeechBubble
extends Node2D
## Short NPC line in a bronze frame over the town (no modal, no pause).
## Place it at the speaker's feet; it sits just below them, clamped to the
## screen, so it never hides the building behind the speaker. Pops in when
## shown. At most 25 words in 3 lines (DP 2.1).

const WIDTH := 150.0
const PAD := 5.0

var label: Label
var _frame: NinePatchRect
var _tail: Polygon2D
var _text: String = ""


func _init() -> void:
	z_index = 60
	visible = false
	_frame = UiKit.frame(Vector2(WIDTH, 20))
	add_child(_frame)
	label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.84))
	label.add_theme_constant_override("line_spacing", 0)
	label.size = Vector2(WIDTH - PAD * 2, 10)
	label.position = Vector2(PAD, PAD)
	_frame.add_child(label)
	_tail = Polygon2D.new()
	_tail.polygon = PackedVector2Array([Vector2(-4, 1), Vector2(4, 1), Vector2(0, -4)])
	_tail.color = Color(0.72, 0.45, 0.25)
	add_child(_tail)


func say(text: String) -> void:
	if text == _text and visible:
		return
	_text = text
	label.text = text
	var lh := label.get_line_height()
	label.size = Vector2(WIDTH - PAD * 2, lh)
	var lines := maxi(1, label.get_line_count())
	label.size.y = lines * lh
	var h := lines * lh + PAD * 2
	_frame.size = Vector2(WIDTH, h)
	_layout()
	if not visible:
		visible = true
		scale = Vector2(0.6, 0.6)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_bubble() -> void:
	visible = false
	_text = ""


func line_count() -> int:
	return label.get_line_count()


## Frame below the anchor (this node's position), kept inside the screen.
func _layout() -> void:
	var w := _frame.size.x
	var h := _frame.size.y
	var x := clampf(-w / 2.0, 2.0 - position.x, UiKit.SCREEN.x - 2.0 - w - position.x)
	var y := 6.0
	_frame.position = Vector2(roundf(x), y)
	_tail.position = Vector2(0, y + 1.0)
