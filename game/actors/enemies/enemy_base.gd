class_name EnemyBase
extends CharacterBody2D

signal killed

const GoldScene := preload("res://world/pickup_gold.tscn")
const ROW_IDLE := 0
const ROW_MOVE := 1
const ROW_ATTACK := 2
const ROW_DEATH := 3
## Frames per second of the idle, move, attack and death rows.
const FPS: Array[float] = [6.0, 10.0, 12.0, 9.0]
const FLASH_TIME := 0.08
const KNOCKBACK := 135.0
## Below this horizontal speed the sprite keeps its facing.
const FLIP_MIN_SPEED := 1.0
const TELEGRAPH_RED := Color(1.0, 0.25, 0.25)

@export var base_hp: int = 20
@export var base_damage: int = 5
@export var gold_drop: int = 3
## Sheet layout: rows idle, move, attack, death; frames_per_row frames of
## frame_size px each. Art faces right; flip_h turns it left.
@export var frame_size: int = 24
@export var frames_per_row: int = 6

@onready var sprite: Sprite2D = $Sprite
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox

var dead: bool = false
var _row: int = ROW_IDLE
var _anim_time: float = 0.0
var _flash: float = 0.0
var _telegraph: bool = false
var _knock: Vector2 = Vector2.ZERO


func _ready() -> void:
	if Game.run == null:
		Game.new_run()
	var level := Game.run.clock.level()
	var max_hp := roundi(base_hp * Difficulty.enemy_hp_mult(level))
	health.max_hp = max_hp
	health.hp = max_hp
	hitbox.damage = roundi(base_damage * Difficulty.enemy_dmg_mult(level))
	hitbox.team = &"enemy"
	hitbox.set_active(false)
	hurtbox.team = &"enemy"
	hurtbox.hit.connect(_on_hit)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_setup_sheet()
	play(ROW_IDLE)


func player() -> Node2D:
	return get_tree().get_first_node_in_group(&"player") as Node2D


func play(row: int) -> void:
	if row == _row and _anim_time > 0.0:
		return
	_row = row
	_anim_time = 0.0
	_update_frame()


## Red tint until cleared. Used as the attack warning.
func set_telegraph(on: bool) -> void:
	_telegraph = on


func _physics_process(delta: float) -> void:
	_anim_time += delta
	_update_frame()
	_flash = maxf(_flash - delta, 0.0)
	var tint := Color.WHITE
	if _telegraph:
		var k := 0.5 + 0.5 * sin(_anim_time * 30.0)
		tint = Color.WHITE.lerp(TELEGRAPH_RED, 0.6 + 0.4 * k)
	if _flash > 0.0:
		tint = Color(3.0, 3.0, 3.0)
	sprite.modulate = tint
	if dead:
		return
	_knock = _knock.move_toward(Vector2.ZERO, KNOCKBACK * 4.0 * delta)
	_think(delta)
	_face_movement()
	velocity += _knock
	move_and_slide()
	velocity -= _knock


## Subclasses set velocity and drive their state here.
func _think(_delta: float) -> void:
	pass


## Slices the sheet into frames_per_row x 4 frames; the texture must be
## frames_per_row * frame_size wide and 4 * frame_size tall.
func _setup_sheet() -> void:
	sprite.hframes = frames_per_row
	sprite.vframes = 4
	if sprite.texture == null:
		return
	var expected := Vector2i(frames_per_row * frame_size, 4 * frame_size)
	if Vector2i(sprite.texture.get_size()) != expected:
		push_warning("%s: sheet is %s, expected %s" % [name, sprite.texture.get_size(), expected])


func _update_frame() -> void:
	var f := int(_anim_time * FPS[_row])
	if _row == ROW_DEATH:
		f = mini(f, frames_per_row - 1)
	else:
		f %= frames_per_row
	sprite.frame = _row * frames_per_row + f


## Turns toward dir (used while standing still to aim or wind up).
func face(dir: Vector2) -> void:
	if absf(dir.x) > 0.1:
		sprite.flip_h = dir.x < 0.0


## While moving, the sprite faces the way it moves (a retreating shooter
## shows its back); standing still keeps the last face() call.
func _face_movement() -> void:
	if absf(velocity.x) > FLIP_MIN_SPEED:
		sprite.flip_h = velocity.x < 0.0


func _on_hit(from: Hitbox) -> void:
	health.damage(from.damage, from.global_position)


func _on_damaged(_n: int) -> void:
	_flash = FLASH_TIME
	_knock = (global_position - health.last_hit_from).normalized() * KNOCKBACK


func _on_died() -> void:
	dead = true
	velocity = Vector2.ZERO
	_telegraph = false
	hitbox.set_active(false)
	hurtbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	($Body as CollisionShape2D).set_deferred("disabled", true)
	play(ROW_DEATH)
	_drop_gold.call_deferred()
	killed.emit()
	get_tree().create_timer(0.8).timeout.connect(queue_free)


func gold_amount() -> int:
	return roundi(gold_drop * Difficulty.gold_mult(Game.run.clock.level()))


func _drop_gold() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var gold := GoldScene.instantiate() as PickupGold
	gold.amount = gold_amount()
	gold.position = position
	parent.add_child(gold)
