class_name LayeredSprite
extends Node2D

## Sheets are COLS x 13 frames of FRAME_SIZE px; a strip uses the first
## FRAME_COUNT[anim] frames of its row. Feet sit on row FEET_ROW of the frame.
const FRAME_SIZE := 32
const COLS := 8
const VFRAMES := 13
const FEET_ROW := 30
const ROW_ORDER: Array[StringName] = [
	&"idle_down", &"idle_up", &"idle_side",
	&"walk_down", &"walk_up", &"walk_side",
	&"attack_down", &"attack_up", &"attack_side",
	&"roll_down", &"roll_up", &"roll_side",
	&"death",
]
const FRAME_COUNT: Dictionary[StringName, int] = {
	&"idle": 4, &"walk": 8, &"attack": 6, &"roll": 6, &"death": 6,
}
## Attack plays its 6 frames in about one swing (Player.SWING_TIME 0.27 s),
## roll in one roll (Player.ROLL_TIME 0.3 s).
const FPS: Dictionary[StringName, float] = {
	&"idle": 6.0, &"walk": 12.0, &"attack": 22.0, &"roll": 20.0, &"death": 9.0,
}
const LOOPING: Array[StringName] = [&"idle", &"walk"]
const LAYERS: Array[StringName] = [&"body", &"hair", &"outfit", &"weapon"]

var speed_scale: float = 1.0
var anim: StringName = &""
var finished: bool = false

var _sprites: Dictionary = {}
var _row: int = 0
var _frame: int = 0
var _time: float = 0.0


func _ready() -> void:
	for layer in LAYERS:
		var s := Sprite2D.new()
		s.name = String(layer)
		s.hframes = COLS
		s.vframes = VFRAMES
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(s)
		_sprites[layer] = s
		var path := "res://assets/characters/climber/%s.png" % layer
		if ResourceLoader.exists(path):
			s.texture = load(path) as Texture2D
	play(&"idle", Vector2.DOWN)


func set_layer(layer: StringName, texture: Texture2D, tint: Color = Color.WHITE) -> void:
	var s := _sprites.get(layer) as Sprite2D
	if s == null:
		return
	s.texture = texture
	s.modulate = tint


## Facing is a direction vector; the dominant axis picks down/up/side and
## a left-facing vector flips the sprite horizontally.
func play(anim_name: StringName, facing: Vector2, restart: bool = false) -> void:
	var dir := &"side"
	var flip: bool = (_sprites[&"body"] as Sprite2D).flip_h
	if absf(facing.y) > absf(facing.x):
		dir = &"down" if facing.y > 0.0 else &"up"
		flip = false
	elif facing.x != 0.0:
		flip = facing.x < 0.0
	for s: Sprite2D in _sprites.values():
		s.flip_h = flip
	var row_name: StringName = &"death" if anim_name == &"death" else StringName("%s_%s" % [anim_name, dir])
	var row := ROW_ORDER.find(row_name)
	if row < 0:
		push_error("LayeredSprite: unknown anim '%s'" % row_name)
		return
	if anim_name != anim or restart:
		_frame = 0
		_time = 0.0
		finished = false
	anim = anim_name
	_row = row
	_apply()


func _process(delta: float) -> void:
	if finished or anim == &"":
		return
	_time += delta * speed_scale
	var frame_time := 1.0 / FPS[anim]
	while _time >= frame_time:
		_time -= frame_time
		_frame += 1
		var count := FRAME_COUNT[anim]
		if _frame >= count:
			if anim in LOOPING:
				_frame = 0
			else:
				_frame = count - 1
				finished = true
				break
	_apply()


func _apply() -> void:
	for s: Sprite2D in _sprites.values():
		s.frame_coords = Vector2i(_frame, _row)
