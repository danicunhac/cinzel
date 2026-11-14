class_name Player
extends CharacterBody2D

signal exit_progress(p: float)
signal exit_blocked
signal exited
signal died

enum State { FREE, ATTACK, ROLL, DEAD }

const COMBO_STEPS := 3
const COMBO_WINDOW := 0.4
const SWING_TIME := 0.27
const HIT_START := 0.06
const HIT_END := 0.2
const FINISHER_MULT := 1.5
const ROLL_TIME := 0.3
const ROLL_COOLDOWN := 0.6
const HURT_IFRAMES := 1.0
const LUNGE_SPEED := 30.0
const ARC_RADIUS := 22.0
const ARC_HALF_ANGLE := deg_to_rad(60.0)

@onready var sprite: LayeredSprite = $Sprite
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox

var state: State = State.FREE
var facing: Vector2 = Vector2.DOWN
var invincible_time: float = 0.0
var blocks_left: int = 0

var _stats: PlayerStats
var _heal := HealRule.new()
var _exit := ExitChannel.new()
var _exit_was_blocked: bool = false
var _exit_was_channeling: bool = false
var _state_time: float = 0.0
var _combo_step: int = -1
var _combo_timer: float = 0.0
var _attack_queued: bool = false
var _swing_dur: float = SWING_TIME
var _roll_cooldown: float = 0.0
var _roll_dir: Vector2 = Vector2.DOWN
var _roll_speed: float = 0.0
var _pulse: float = 0.0


func _ready() -> void:
	add_to_group(&"player")
	if Game.run == null:
		Game.new_run()
	Game.run.changed.connect(_refresh_stats)
	_refresh_stats()
	health.hp = clampi(Game.run.hp, 0, health.max_hp)
	blocks_left = _stats.block_per_room
	_build_arc()
	hitbox.team = &"player"
	hitbox.set_active(false)
	hitbox.landed.connect(_on_hitbox_landed)
	hurtbox.team = &"player"
	hurtbox.hit.connect(_on_hurt)
	health.damaged.connect(_on_damaged)
	health.hp_changed.connect(_on_hp_changed)
	health.died.connect(_on_died)


func _exit_tree() -> void:
	if Game.run != null and Game.run.changed.is_connected(_refresh_stats):
		Game.run.changed.disconnect(_refresh_stats)


func reset_room_blocks() -> void:
	blocks_left = _stats.block_per_room


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_sync_invulnerable()
	var input_dir := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	match state:
		State.FREE:
			_process_free(delta, input_dir)
		State.ATTACK:
			_process_attack(delta)
		State.ROLL:
			_process_roll(delta)
		State.DEAD:
			velocity = Vector2.ZERO
	move_and_slide()
	_update_heal(delta, input_dir)
	_update_exit(delta)
	_sync_invulnerable()
	_update_visuals(delta)


func _tick_timers(delta: float) -> void:
	invincible_time = maxf(invincible_time - delta, 0.0)
	_roll_cooldown = maxf(_roll_cooldown - delta, 0.0)
	if state != State.ATTACK:
		_combo_timer = maxf(_combo_timer - delta, 0.0)


func _process_free(_delta: float, input_dir: Vector2) -> void:
	velocity = input_dir * _stats.move_speed
	if input_dir != Vector2.ZERO:
		facing = input_dir
		sprite.play(&"walk", facing)
	else:
		sprite.play(&"idle", facing)
	if _just_pressed(&"roll") and _roll_cooldown <= 0.0:
		_start_roll(input_dir if input_dir != Vector2.ZERO else facing)
	elif _just_pressed(&"attack"):
		_start_attack()


func _start_attack() -> void:
	_combo_step = (_combo_step + 1) % COMBO_STEPS if _combo_timer > 0.0 else 0
	state = State.ATTACK
	_state_time = 0.0
	_attack_queued = false
	var dur := SWING_TIME / _stats.attack_speed_mult
	sprite.speed_scale = _stats.attack_speed_mult
	sprite.play(&"attack", facing, true)
	var finisher := _combo_step == COMBO_STEPS - 1
	hitbox.damage = roundi(_stats.damage * (FINISHER_MULT if finisher else 1.0))
	hitbox.scale = Vector2.ONE * (1.25 if finisher else 1.0)
	hitbox.rotation = facing.angle()
	_swing_dur = dur


func _process_attack(delta: float) -> void:
	_state_time += delta
	var t := _state_time / _swing_dur
	velocity = facing.normalized() * LUNGE_SPEED if t < 0.4 else Vector2.ZERO
	hitbox.set_active(t >= HIT_START / SWING_TIME and t <= HIT_END / SWING_TIME)
	if _just_pressed(&"attack"):
		_attack_queued = true
	if _just_pressed(&"roll") and _roll_cooldown <= 0.0:
		hitbox.set_active(false)
		sprite.speed_scale = 1.0
		_start_roll(facing)
		return
	if _state_time >= _swing_dur:
		hitbox.set_active(false)
		sprite.speed_scale = 1.0
		_combo_timer = COMBO_WINDOW
		state = State.FREE
		if _attack_queued:
			_start_attack()


func _start_roll(dir: Vector2) -> void:
	state = State.ROLL
	_state_time = 0.0
	_roll_dir = dir.normalized()
	facing = dir
	_roll_speed = _stats.roll_distance / ROLL_TIME
	_roll_cooldown = ROLL_COOLDOWN
	_combo_step = -1
	_combo_timer = 0.0
	invincible_time = maxf(invincible_time, ROLL_TIME)
	sprite.play(&"roll", facing, true)


func _process_roll(delta: float) -> void:
	_state_time += delta
	velocity = _roll_dir * _roll_speed
	if _state_time >= ROLL_TIME:
		state = State.FREE
		velocity = Vector2.ZERO


## A key that closed a menu (Space on "Fechar") does not also act in game.
func _just_pressed(action: StringName) -> bool:
	return Input.is_action_just_pressed(action) and not UiKit.gameplay_input_blocked()


func _sync_invulnerable() -> void:
	hurtbox.invulnerable = state == State.DEAD or invincible_time > 0.0


func _update_heal(delta: float, input_dir: Vector2) -> void:
	var idle := state == State.FREE and input_dir == Vector2.ZERO
	health.heal(_heal.update(delta, idle, _stats.heal_delay, _stats.heal_per_sec))


func _update_exit(delta: float) -> void:
	if state == State.DEAD:
		return
	var status := _exit.update(delta, Input.is_action_pressed(&"exit"), Game.in_boss_room)
	match status:
		ExitChannel.CHANNELING:
			_exit_was_channeling = true
			exit_progress.emit(_exit.progress)
		ExitChannel.BLOCKED:
			if not _exit_was_blocked:
				exit_blocked.emit()
		ExitChannel.DONE:
			exit_progress.emit(1.0)
			_exit.interrupt()
			exited.emit()
		_:
			if _exit_was_channeling:
				exit_progress.emit(0.0)
				_exit_was_channeling = false
	_exit_was_blocked = status == ExitChannel.BLOCKED


func _update_visuals(delta: float) -> void:
	_pulse += delta
	var c := Color.WHITE
	if _heal.healing:
		var k := 0.5 + 0.5 * sin(_pulse * 6.0)
		c = Color.WHITE.lerp(Color(1.0, 0.9, 0.2), 0.35 + 0.4 * k)
	if invincible_time > 0.0 and state != State.ROLL:
		c.a = 0.4 if int(_pulse * 16.0) % 2 == 0 else 1.0
	sprite.modulate = c


## Writes Health.hp back to the run on every change, never once dead.
func _on_hp_changed(hp: int) -> void:
	if state == State.DEAD:
		return
	Game.run.hp = hp


func _refresh_stats() -> void:
	_stats = Game.run.stats()
	health.set_max_hp(_stats.max_hp)


func _build_arc() -> void:
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 7:
		var a := lerpf(-ARC_HALF_ANGLE, ARC_HALF_ANGLE, i / 6.0)
		pts.append(Vector2.from_angle(a) * ARC_RADIUS)
	var shape := ConvexPolygonShape2D.new()
	shape.points = pts
	($Hitbox/Shape as CollisionShape2D).shape = shape


func _on_hurt(from: Hitbox) -> void:
	if state == State.DEAD or invincible_time > 0.0:
		return
	if blocks_left > 0:
		blocks_left -= 1
		invincible_time = HURT_IFRAMES * 0.5
		return
	health.damage(from.damage, from.global_position)


func _on_damaged(_n: int) -> void:
	invincible_time = HURT_IFRAMES
	_exit.interrupt()
	exit_progress.emit(0.0)
	_exit_was_channeling = false


func _on_hitbox_landed(_target: Hurtbox) -> void:
	if _stats.lifesteal > 0.0:
		health.heal(hitbox.damage * _stats.lifesteal)


func _on_died() -> void:
	state = State.DEAD
	remove_from_group(&"player")
	hurtbox.invulnerable = true
	hitbox.set_active(false)
	sprite.speed_scale = 1.0
	sprite.play(&"death", Vector2.DOWN, true)
	died.emit()
