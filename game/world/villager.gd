class_name Villager
extends Node2D
## Town villager that walks a loop of waypoints, pausing at each one. The
## origin is the feet, so the town's Y-sort puts it in front of or behind
## props correctly; a ground shadow sits under the feet.
## Two kinds of sheet (32x32 cells, feet on row 30):
## - a look sheet (assets/characters/villagers, 4x6 cells): idle down, up,
##   side (2 frames) then walk down, up, side (4 frames); side faces right
##   and is flipped for left.
## - a one-row NPC sheet (shopkeeper, blacksmith): idle frames only, with a
##   1 px hop while walking.

const CELL := 32
const PAUSE := Vector2(0.8, 2.2)
const DIRS: Array[StringName] = [&"down", &"up", &"side"]
const IDLE_FRAMES := 2
const WALK_FRAMES := 4

var path: Array[Vector2] = []
var speed: float = 16.0
## Line said in a bubble when the player comes close ("" = none).
var line: String = ""
## Set by the town while the player is close: stop and face `look_at_pos`.
var talking: bool = false
var look_at_pos: Vector2 = Vector2.ZERO

var _i: int = 0
var _wait: float = 0.0
var _sprite: AnimatedSprite2D
var _directional: bool = false
var _dir: StringName = &"down"
var _rng := RandomNumberGenerator.new()


func setup(tex: Texture2D, tint: Color, waypoints: Array[Vector2]) -> void:
	path = waypoints
	position = waypoints[0]
	_sprite = AnimatedSprite2D.new()
	_directional = tex.get_height() == CELL * 6
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	if _directional:
		for r in 3:
			_add_anim(frames, StringName("idle_%s" % DIRS[r]), tex, r, IDLE_FRAMES, 2.0)
			_add_anim(frames, StringName("walk_%s" % DIRS[r]), tex, r + 3, WALK_FRAMES, 7.0)
	else:
		_add_anim(frames, &"idle", tex, 0, tex.get_width() / CELL, 4.0)
	_sprite.sprite_frames = frames
	_sprite.offset = Vector2(0, -CELL / 2.0)
	_sprite.modulate = tint
	add_child(_sprite)
	add_child(GroundShadow.make(Vector2i(16, 6), Vector2(0, 0)))
	_rng.randomize()
	_wait = _rng.randf_range(0.0, 1.5)
	_play(false)


func _add_anim(frames: SpriteFrames, anim: StringName, tex: Texture2D, row: int, count: int, fps: float) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * CELL, row * CELL, CELL, CELL)
		frames.add_frame(anim, at)


## Current animation name (tests and debugging).
func animation() -> StringName:
	return _sprite.animation


func _play(walking: bool) -> void:
	if not _directional:
		if _sprite.animation != &"idle":
			_sprite.play(&"idle")
		_sprite.offset.y = -CELL / 2.0 - (1.0 if walking and fmod(Time.get_ticks_msec() / 160.0, 2.0) < 1.0 else 0.0)
		return
	var anim := StringName("%s_%s" % [&"walk" if walking else &"idle", _dir])
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)


func _face(v: Vector2) -> void:
	if v.length() < 0.01:
		return
	if absf(v.x) > absf(v.y):
		_dir = &"side"
		_sprite.flip_h = v.x < 0.0
	else:
		_dir = &"down" if v.y > 0.0 else &"up"
		_sprite.flip_h = false


func _process(delta: float) -> void:
	if talking:
		_face(look_at_pos - position)
		_play(false)
		return
	if path.size() < 2:
		_play(false)
		return
	if _wait > 0.0:
		_wait -= delta
		_play(false)
		return
	var target := path[(_i + 1) % path.size()]
	var to := target - position
	if to.length() <= speed * delta:
		position = target
		_i = (_i + 1) % path.size()
		_wait = _rng.randf_range(PAUSE.x, PAUSE.y)
		_play(false)
		return
	position += to.normalized() * speed * delta
	_face(to)
	_play(true)
