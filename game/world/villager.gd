class_name Villager
extends Node2D
## Town villager that walks a loop of waypoints, pausing at each one. Reuses
## an NPC sheet (square frames in one row) with a tint; the origin is the feet
## so the town's Y-sort puts it in front of or behind props correctly.

const SPEED := 16.0
const PAUSE := Vector2(0.8, 2.2)

var path: Array[Vector2] = []
var _i: int = 0
var _wait: float = 0.0
var _sprite: AnimatedSprite2D
var _rng := RandomNumberGenerator.new()


func setup(tex: Texture2D, tint: Color, waypoints: Array[Vector2]) -> void:
	path = waypoints
	position = waypoints[0]
	_sprite = AnimatedSprite2D.new()
	var n := tex.get_height()
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 4.0)
	for i in tex.get_width() / n:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * n, 0, n, n)
		frames.add_frame(&"default", at)
	_sprite.sprite_frames = frames
	_sprite.offset = Vector2(0, -n / 2.0)
	_sprite.modulate = tint
	add_child(_sprite)
	_sprite.play()
	var shadow := Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 12:
		var a := TAU * k / 12.0
		pts.append(Vector2(cos(a) * 6.0, sin(a) * 2.0))
	shadow.polygon = pts
	shadow.color = Color(0.08, 0.05, 0.1, 0.35)
	shadow.show_behind_parent = true
	add_child(shadow)
	_rng.randomize()
	_wait = _rng.randf_range(0.0, 1.5)


func _process(delta: float) -> void:
	if path.is_empty():
		return
	if _wait > 0.0:
		_wait -= delta
		_sprite.offset.y = -_sprite.sprite_frames.get_frame_texture(&"default", 0).get_height() / 2.0
		return
	var target := path[(_i + 1) % path.size()]
	var to := target - position
	if to.length() <= SPEED * delta:
		position = target
		_i = (_i + 1) % path.size()
		_wait = _rng.randf_range(PAUSE.x, PAUSE.y)
		return
	position += to.normalized() * SPEED * delta
	if absf(to.x) > 0.5:
		_sprite.flip_h = to.x < 0.0
	# Walking bob: 1 px hop, the sheet only has idle frames.
	var h := _sprite.sprite_frames.get_frame_texture(&"default", 0).get_height()
	_sprite.offset.y = -h / 2.0 - (1.0 if fmod(Time.get_ticks_msec() / 160.0, 2.0) < 1.0 else 0.0)
