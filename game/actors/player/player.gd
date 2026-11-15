class_name Player
extends CharacterBody2D
## The climber. The equipped weapon (WeaponDef from its item) drives the
## attack: combo, arc or thrust, arrows, stun, crit, and the special fired by
## holding attack (SpecialCharge). Stats come from Game.run.stats().
## With Lâminas Gêmeas and two swords (Equipment.dual_active) the def is
## WeaponDef.dual_swords: the combo alternates hands and the off-hand hits
## add the off-hand sword's share (PlayerStats.offhand_damage).
## Debug: `--weapon=<item id>` equips that weapon; `--special-cd=<s>` starts
## the special cooling down.

signal exit_progress(p: float)
signal exit_blocked
signal exited
signal died

enum State { FREE, ATTACK, ROLL, DEAD, SPECIAL }

const COMBO_WINDOW := 0.4
## Hitbox live from HIT_START to HIT_END of a swing (fractions).
const HIT_START := 0.22
const HIT_END := 0.74
## The attack strip (6 frames at 22 fps) lasts this long at speed_scale 1.
const ANIM_SWING := 6.0 / 22.0
const FINISHER_SCALE := 1.25
const ROLL_TIME := 0.4
## Invincible part of the roll (shorter than the roll itself).
const ROLL_IFRAMES := 0.3
const ROLL_COOLDOWN := 0.6
const HURT_IFRAMES := 1.0
## Moving while the attack is held to charge.
const CHARGE_MOVE_MULT := 0.45
const HAND := Vector2(0, -6)
## Run feel: a step every STEP_TIME s of walking (two per walk cycle of 8
## frames at 12 fps), dust at the feet every second step, and the sprite
## leans LEAN px toward the move.
const STEP_TIME := 1.0 / 3.0
const LEAN := 1.0
const SPRITE_HOME := Vector2(0, -8)
const HEAVY_WEAPONS: Array[StringName] = [&"axe", &"longsword"]
## Seconds between heal sparkles while healing.
const HEAL_SPARK_TIME := 0.45

# Specials (px already at the x1.5 scale).
const THRUST_TIME := 0.3
const THRUST_DASH := 0.18
const THRUST_SPEED := 330.0
const THRUST_LEN := 54.0
const SPIN_TIME := 0.45
const SPIN_REACH_MULT := 1.15
const SLAM_TIME := 0.5
const SLAM_IMPACT := 0.15
const SLAM_RADIUS := 30.0
const SLAM_STUN := 0.8
const WAVE_RADIUS := 66.0
const WAVE_MULT := 1.0
const WAVE_STUN := 0.4
const LUNGE_TIME := 0.32
const LUNGE_DASH := 0.25
const LUNGE_SPEED := 384.0
const FLURRY_CUTS := 6
const FLURRY_GAP := 0.11
const FLURRY_ARC := 140.0
const FLURRY_REACH_MULT := 1.4
const RAIN_TIME := 0.3
const RAIN_DIST := 96.0
const RAIN_RADIUS := 36.0

@onready var sprite: LayeredSprite = $Sprite
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox

var state: State = State.FREE
var facing: Vector2 = Vector2.DOWN
var invincible_time: float = 0.0
var blocks_left: int = 0
var weapon: WeaponDef = WeaponDef.for_type(&"sword")
var weapon_id: StringName = &""
## Off-hand sword in use (&"" = none, or no Lâminas Gêmeas).
var offhand_id: StringName = &""
var special: SpecialCharge = SpecialCharge.new()
## False in town: the attack button does nothing (no swing, shot or special).
var armed: bool = true
## Crit rolls. Seed it for deterministic tests.
var rng := RandomNumberGenerator.new()

var _stats: PlayerStats
var _heal := HealRule.new()
## Instance ids of the hazards slowing the walk right now (set_slowed).
var _slowed_by: Dictionary[int, bool] = {}
var _exit := ExitChannel.new()
var _fx: WeaponFx
var _exit_was_blocked: bool = false
var _exit_was_channeling: bool = false
var _state_time: float = 0.0
var _combo_step: int = -1
var _combo_timer: float = 0.0
var _attack_queued: bool = false
var _queued_charged: bool = false
var _shot_charged: bool = false
var _shot_fired: bool = false
var _swing_dur: float = 0.27
var _roll_cooldown: float = 0.0
var _roll_dir: Vector2 = Vector2.DOWN
var _roll_speed: float = 0.0
var _pulse: float = 0.0
var _special_dir: Vector2 = Vector2.DOWN
var _special_step: int = 0
var _step_time: float = 0.0
var _steps: int = 0
var _was_charged: bool = false
var _heal_spark: float = 0.0
## The swing now is the off-hand's (Lâminas Gêmeas).
var _offhand_hit: bool = false


func _ready() -> void:
	add_to_group(&"player")
	rng.randomize()
	if Game.run == null:
		Game.new_run()
	_apply_debug_weapon()
	_fx = WeaponFx.new()
	add_child(_fx)
	Game.run.changed.connect(_refresh_stats)
	_refresh_stats()
	health.hp = clampi(Game.run.hp, 0, health.max_hp)
	blocks_left = _stats.block_per_room
	hitbox.team = &"player"
	hitbox.set_active(false)
	hitbox.landed.connect(_on_hitbox_landed)
	hurtbox.team = &"player"
	hurtbox.hit.connect(_on_hurt)
	health.damaged.connect(_on_damaged)
	health.hp_changed.connect(_on_hp_changed)
	health.died.connect(_on_died)


func _exit_tree() -> void:
	Sfx.stop_loop(&"heal_loop")
	if Game.run != null and Game.run.changed.is_connected(_refresh_stats):
		Game.run.changed.disconnect(_refresh_stats)


func reset_room_blocks() -> void:
	blocks_left = _stats.block_per_room
	_slowed_by.clear()


## A floor hazard (IcePatch) starts or stops slowing the walk; several can
## overlap, the slow does not stack.
func set_slowed(source: Object, on: bool) -> void:
	if on:
		_slowed_by[source.get_instance_id()] = true
	else:
		_slowed_by.erase(source.get_instance_id())


func is_slowed() -> bool:
	return not _slowed_by.is_empty()


func stats() -> PlayerStats:
	return _stats


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_sync_invulnerable()
	var input_dir := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	_update_charge(delta)
	match state:
		State.FREE:
			_process_free(delta, input_dir)
		State.ATTACK:
			_process_attack(delta)
		State.SPECIAL:
			_process_special(delta)
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


func _process_free(delta: float, input_dir: Vector2) -> void:
	var speed := _stats.move_speed
	if is_slowed():
		speed *= IcePatch.SLOW_MULT
	if special.glow() > 0.0:
		speed *= CHARGE_MOVE_MULT
	velocity = input_dir * speed
	if input_dir != Vector2.ZERO:
		facing = input_dir
		sprite.play(&"walk", facing)
		_walk_feel(delta, input_dir)
	else:
		sprite.play(&"idle", facing)
		_step_time = 0.0
		sprite.position = SPRITE_HOME
	if _just_pressed(&"roll") and _roll_cooldown <= 0.0:
		_start_roll(input_dir if input_dir != Vector2.ZERO else facing)
	elif armed and _just_pressed(&"attack") and not weapon.ranged:
		_start_attack()


## Footsteps and dust while walking, and the 1 px lean.
func _walk_feel(delta: float, dir: Vector2) -> void:
	sprite.position = SPRITE_HOME + Vector2(signf(roundf(dir.x)) * LEAN, 0)
	_step_time += delta
	if _step_time < STEP_TIME:
		return
	_step_time -= STEP_TIME
	_steps += 1
	Sfx.play(&"step", 0.1)
	if _steps % 2 == 0:
		Fx.burst(&"step_dust", global_position + Vector2(0, 5))


## Attack press starts the hold; the release fires the special, the bow's
## charged arrow, or (bow) the plain arrow.
func _update_charge(delta: float) -> void:
	if state == State.DEAD or state == State.ROLL or state == State.SPECIAL or not armed:
		special.cancel()
		special.tick(delta, false)
		return
	var held := Input.is_action_pressed(&"attack") and not UiKit.gameplay_input_blocked()
	charge_step(delta, _just_pressed(&"attack"), held)


## One step of the hold with the attack input given (tests drive it).
func charge_step(delta: float, pressed: bool, held: bool) -> void:
	if pressed:
		special.press()
	var was_holding := special.holding
	var result := special.tick(delta, held)
	match result:
		SpecialCharge.SPECIAL:
			_start_special()
		SpecialCharge.CHARGED:
			_shoot_or_queue(true)
		_:
			if was_holding and not special.holding and weapon.ranged:
				_shoot_or_queue(false)


func _shoot_or_queue(charged: bool) -> void:
	if state == State.ATTACK:
		_attack_queued = true
		_queued_charged = charged
	else:
		_start_attack(charged)


func _start_attack(charged: bool = false) -> void:
	_combo_step = (_combo_step + 1) % weapon.combo if _combo_timer > 0.0 else 0
	state = State.ATTACK
	_state_time = 0.0
	_attack_queued = false
	_queued_charged = false
	_shot_charged = charged
	_shot_fired = false
	_swing_dur = weapon.swing_time(_stats.attack_speed_mult)
	_offhand_hit = weapon.is_offhand_step(_combo_step)
	sprite.speed_scale = ANIM_SWING / _swing_dur
	sprite.offhand_swing = _offhand_hit
	sprite.play(&"attack", facing, true)
	if weapon.ranged:
		return
	var finisher := weapon.combo > 1 and _combo_step == weapon.combo - 1
	Sfx.play(&"swing_heavy" if finisher or weapon.type in HEAVY_WEAPONS else &"swing_light", 0.08)
	hitbox.heavy = finisher
	_roll_hit(weapon.combo_mult[_combo_step], _stats.offhand_damage if _offhand_hit else 0)
	hitbox.stun = weapon.stun
	_set_swing_shape(weapon.reach, weapon.arc_deg)
	hitbox.scale = Vector2.ONE * (FINISHER_SCALE if finisher else 1.0)
	hitbox.rotation = facing.angle()


## Slash light of a normal swing (when its hit window opens), sized by the weapon (not by the 32 px cell):
## spear a jab, the rest a crescent as wide as the arc (alternating side per
## combo step), axe deepest, dagger smallest.
func _swing_fx(r: float) -> void:
	var dir := facing.normalized()
	if weapon.thrust:
		_fx.jab(_hand(), _hand() + dir * r, 7.0, _fx.slash_color())
		return
	var half := deg_to_rad(weapon.arc_deg) / 2.0
	var side := 1.0 if _combo_step % 2 == 0 else -1.0
	var depth := r * (0.42 if weapon.type == &"axe" else 0.3)
	var life := 0.12 if weapon.type == &"dagger" else (0.18 if weapon.type == &"axe" or weapon.type == &"longsword" else WeaponFx.SLASH_LIFE)
	_fx.slash(_hand(), r, dir.angle() - half * side, dir.angle() + half * side, depth, _fx.slash_color(_offhand_hit), life)


func _process_attack(delta: float) -> void:
	_state_time += delta
	var t := _state_time / _swing_dur
	velocity = facing.normalized() * weapon.lunge_speed if t < 0.4 else Vector2.ZERO
	if weapon.ranged:
		if not _shot_fired and t >= HIT_START:
			_shot_fired = true
			_fire_arrow(_shot_charged)
	else:
		if not _shot_fired and t >= HIT_START:
			_shot_fired = true
			_swing_fx(weapon.reach * hitbox.scale.x)
		hitbox.set_active(t >= HIT_START and t <= HIT_END)
	if _just_pressed(&"attack") and not weapon.ranged:
		_attack_queued = true
	if _just_pressed(&"roll") and _roll_cooldown <= 0.0:
		_end_swing()
		_start_roll(facing)
		return
	if _state_time >= _swing_dur:
		_end_swing()
		_combo_timer = COMBO_WINDOW
		state = State.FREE
		if _attack_queued:
			_start_attack(_queued_charged)


func _end_swing() -> void:
	hitbox.set_active(false)
	hitbox.stun = 0.0
	hitbox.heavy = false
	hitbox.scale = Vector2.ONE
	sprite.speed_scale = 1.0
	sprite.offhand_swing = false
	_offhand_hit = false


func _fire_arrow(charged: bool) -> void:
	var a := PlayerArrow.new()
	a.direction = facing.normalized()
	a.speed = weapon.projectile_speed
	a.max_dist = weapon.reach
	a.charged = charged
	a.pierce = weapon.charged_pierce if charged else 0
	a.damage = _roll_damage(weapon.charged_mult if charged else 1.0)
	a.crit = _last_crit
	a.heavy = charged
	Sfx.play(&"bow_shot", 0.08 if not charged else 0.02)
	a.global_position = global_position + HAND + a.direction * 8.0
	a.landed.connect(func(_h: Hurtbox) -> void: _lifesteal(a.damage))
	_room().add_child(a)


# --- specials ---

func _start_special() -> void:
	_end_swing()
	hitbox.heavy = true
	state = State.SPECIAL
	_state_time = 0.0
	_special_step = 0
	_special_dir = facing.normalized() if facing != Vector2.ZERO else Vector2.DOWN
	sprite.speed_scale = 1.0
	sprite.play(&"attack", facing, true)
	Sfx.play(&"special_release", 0.02)
	Fx.burst(&"ring", _hand())
	var hand := _hand()
	match weapon.special:
		&"thrust_line":
			invincible_time = maxf(invincible_time, THRUST_TIME)
			_roll_hit(weapon.special_mult)
			_set_thrust_shape(THRUST_LEN, 14.0)
			hitbox.rotation = _special_dir.angle()
			hitbox.set_active(true)
			_fx.line(hand, hand + _special_dir * (THRUST_SPEED * THRUST_DASH + THRUST_LEN), _fx.skill_color(), 0.35, 6.0)
		&"spin":
			_roll_hit(weapon.special_mult)
			_set_circle_shape(weapon.reach * SPIN_REACH_MULT)
			hitbox.set_active(true)
		&"ground_slam":
			pass
		&"lunge":
			invincible_time = maxf(invincible_time, LUNGE_TIME)
			_roll_hit(weapon.special_mult)
			_set_thrust_shape(weapon.reach * 1.1, 16.0)
			hitbox.rotation = _special_dir.angle()
			hitbox.set_active(true)
			_fx.line(hand, hand + _special_dir * (LUNGE_SPEED * LUNGE_DASH + weapon.reach), _fx.skill_color(), 0.4, 5.0)
		&"flurry":
			_flurry_cut()
		&"cross_flurry":
			_cross_cut()
		&"arrow_rain":
			var b := PlayerBlast.new()
			b.kind = PlayerBlast.Kind.RAIN
			b.radius = RAIN_RADIUS
			b.global_position = global_position + _special_dir * RAIN_DIST
			b.damage_roll = _blast_roll.bind(b, weapon.special_mult)
			b.landed.connect(func(_h: Hurtbox) -> void: _lifesteal(b.damage))
			_room().add_child(b)
			_fx.line(hand, b.global_position + Vector2(0, -24), _fx.skill_color(), 0.3, 2.0)


func _process_special(delta: float) -> void:
	_state_time += delta
	var t := _state_time
	var done := 0.3
	velocity = Vector2.ZERO
	match weapon.special:
		&"thrust_line":
			done = THRUST_TIME
			if t < THRUST_DASH:
				velocity = _special_dir * THRUST_SPEED
			hitbox.set_active(t < THRUST_DASH + 0.04)
		&"spin":
			done = SPIN_TIME
			var k := clampf(t / SPIN_TIME, 0.0, 1.0)
			facing = _special_dir.rotated(TAU * k)
			sprite.play(&"attack", facing)
			hitbox.set_active(t < SPIN_TIME * 0.8)
			var a := _special_dir.angle() + TAU * k
			_fx.arc(_hand(), weapon.reach * SPIN_REACH_MULT, a - 0.9, a, _fx.skill_color(), 0.25, 4.0)
		&"ground_slam":
			done = SLAM_TIME
			if _special_step == 0 and t >= SLAM_IMPACT:
				_special_step = 1
				_slam()
			hitbox.set_active(_special_step == 1 and t < SLAM_IMPACT + 0.1)
		&"lunge":
			done = LUNGE_TIME
			if t < LUNGE_DASH:
				velocity = _special_dir * LUNGE_SPEED
			hitbox.set_active(t < LUNGE_DASH + 0.04)
		&"flurry":
			done = FLURRY_GAP * FLURRY_CUTS + 0.05
			var cut := int(t / FLURRY_GAP)
			if cut > _special_step and cut < FLURRY_CUTS:
				_special_step = cut
				_flurry_cut()
			velocity = _special_dir * 40.0
		&"cross_flurry":
			done = WeaponDef.CROSS_GAP * WeaponDef.CROSS_CUTS + 0.05
			var cut := int(t / WeaponDef.CROSS_GAP)
			if cut > _special_step and cut < WeaponDef.CROSS_CUTS:
				_special_step = cut
				_cross_cut()
			velocity = _special_dir * 40.0
		&"arrow_rain":
			done = RAIN_TIME
	if t >= done:
		_end_swing()
		hitbox.rotation = facing.angle()
		_set_swing_shape(weapon.reach, weapon.arc_deg)
		facing = _special_dir
		state = State.FREE


func _slam() -> void:
	var at := global_position + _special_dir * 14.0
	_roll_hit(weapon.special_mult)
	hitbox.stun = SLAM_STUN
	_set_circle_shape(SLAM_RADIUS, _special_dir * 14.0)
	hitbox.set_active(true)
	var w := PlayerBlast.new()
	w.kind = PlayerBlast.Kind.WAVE
	w.radius = WAVE_RADIUS
	w.stun = WAVE_STUN
	w.global_position = at
	w.damage_roll = _blast_roll.bind(w, WAVE_MULT)
	w.landed.connect(func(_h: Hurtbox) -> void: _lifesteal(w.damage))
	_room().add_child(w)
	_fx.ring(at + HAND, SLAM_RADIUS, _fx.skill_color(), 0.35, 5.0)


func _flurry_cut() -> void:
	var side := 1.0 if _special_step % 2 == 0 else -1.0
	var dir := _special_dir.rotated(deg_to_rad(25.0) * side)
	_roll_hit(weapon.special_mult)
	_set_swing_shape(weapon.reach * FLURRY_REACH_MULT, FLURRY_ARC)
	hitbox.rotation = dir.angle()
	hitbox.reset_hits()
	hitbox.set_active(true)
	hitbox.hit_overlapping()
	facing = dir
	sprite.play(&"attack", facing, true)
	var half := deg_to_rad(FLURRY_ARC) / 2.0
	_fx.arc(_hand(), weapon.reach * FLURRY_REACH_MULT, dir.angle() - half * side, dir.angle() + half * side, _fx.skill_color(), 0.22, 3.0)


## One X of the two-sword special: both blades cut across each other (two
## crescents tilted CROSS_TILT to each side, swept in opposite directions),
## one hit with both swords' damage. The hands take turns leading.
func _cross_cut() -> void:
	var reach := weapon.reach * WeaponDef.CROSS_REACH_MULT
	_roll_hit(weapon.special_mult, _stats.offhand_damage)
	_set_swing_shape(reach, WeaponDef.CROSS_ARC)
	hitbox.rotation = _special_dir.angle()
	hitbox.reset_hits()
	hitbox.set_active(true)
	hitbox.hit_overlapping()
	facing = _special_dir
	sprite.offhand_swing = _special_step % 2 == 1
	sprite.play(&"attack", facing, true)
	Sfx.play(&"swing_light", 0.08)
	var half := deg_to_rad(WeaponDef.CROSS_ARC) / 2.0
	var tilt := deg_to_rad(WeaponDef.CROSS_TILT)
	var a := _special_dir.angle()
	_fx.slash(_hand(), reach, a + tilt - half, a + tilt + half, reach * 0.25, _fx.skill_color(), 0.2)
	_fx.slash(_hand(), reach, a - tilt + half, a - tilt - half, reach * 0.25, _fx.skill_color(true), 0.2)


# --- hit shapes and damage ---

var _last_crit: bool = false


## (Base damage + `bonus`) times `mult`, after one crit roll. The bonus is
## the off-hand sword's share on its hits.
func _roll_damage(mult: float, bonus: int = 0) -> int:
	var base := roundi((_stats.damage + bonus) * mult)
	var dmg := Combat.hit_damage(base, _stats.crit_chance, _stats.crit_mult, rng)
	_last_crit = dmg != base
	return dmg


## Damage of one rain volley or the slam wave, with its own crit roll.
func _blast_roll(blast: Hitbox, mult: float) -> int:
	var dmg := _roll_damage(mult)
	blast.crit = _last_crit
	return dmg


func _roll_hit(mult: float, bonus: int = 0) -> void:
	hitbox.damage = _roll_damage(mult, bonus)
	hitbox.crit = _last_crit


func _set_swing_shape(reach: float, arc_deg: float) -> void:
	if weapon.thrust and arc_deg == weapon.arc_deg and reach == weapon.reach:
		_set_thrust_shape(reach, weapon.thrust_width)
		return
	var half := deg_to_rad(arc_deg) / 2.0
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 9:
		pts.append(Vector2.from_angle(lerpf(-half, half, i / 8.0)) * reach)
	_set_shape(pts)


func _set_thrust_shape(length: float, width: float) -> void:
	_set_shape(PackedVector2Array([
		Vector2(0, -width / 2.0), Vector2(length, -width / 2.0),
		Vector2(length, width / 2.0), Vector2(0, width / 2.0)]))


func _set_circle_shape(radius: float, offset: Vector2 = Vector2.ZERO) -> void:
	hitbox.rotation = 0.0
	var pts := PackedVector2Array()
	for i in 16:
		pts.append(offset + Vector2.from_angle(TAU * i / 16.0) * radius)
	_set_shape(pts)


func _set_shape(pts: PackedVector2Array) -> void:
	var shape := ConvexPolygonShape2D.new()
	shape.points = pts
	($Hitbox/Shape as CollisionShape2D).shape = shape


func _hand() -> Vector2:
	return global_position + HAND


func _room() -> Node:
	return get_parent() if get_parent() != null else get_tree().current_scene


# --- roll, heal, exit ---

func _start_roll(dir: Vector2) -> void:
	state = State.ROLL
	_state_time = 0.0
	_roll_dir = dir.normalized()
	facing = dir
	_roll_speed = _stats.roll_distance / ROLL_TIME
	_roll_cooldown = ROLL_COOLDOWN
	_combo_step = -1
	_combo_timer = 0.0
	special.cancel()
	invincible_time = maxf(invincible_time, ROLL_IFRAMES)
	sprite.play(&"roll", facing, true)
	sprite.position = SPRITE_HOME
	Sfx.play(&"roll", 0.08)
	Fx.burst(&"roll_dust", global_position + Vector2(0, 5))


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
	var idle := state == State.FREE and input_dir == Vector2.ZERO and not special.holding
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
	_update_sounds(delta)
	var c := Color.WHITE
	if _heal.healing:
		var k := 0.5 + 0.5 * sin(_pulse * 6.0)
		c = Color.WHITE.lerp(Color(1.0, 0.9, 0.2), 0.35 + 0.4 * k)
	if invincible_time > 0.0 and state != State.ROLL and state != State.SPECIAL:
		c.a = 0.4 if int(_pulse * 16.0) % 2 == 0 else 1.0
	sprite.modulate = c
	_fx.hand = _hand() + facing.normalized() * 6.0
	_fx.glow = special.glow()
	_fx.charged = special.is_charged()
	_fx.stage_one = special.is_stage_one()


## Special ready to release, and the heal loop while healing.
func _update_sounds(delta: float) -> void:
	var charged := special.is_charged()
	if charged and not _was_charged:
		Sfx.play(&"special_charge", 0.0)
	_was_charged = charged
	var healing := _heal.healing and state != State.DEAD and health.hp < health.max_hp
	if healing:
		Sfx.play_loop(&"heal_loop")
		_heal_spark -= delta
		if _heal_spark <= 0.0:
			_heal_spark = HEAL_SPARK_TIME
			Fx.burst(&"heal", global_position + Vector2(0, -8))
	elif Sfx.is_looping(&"heal_loop"):
		Sfx.stop_loop(&"heal_loop")
		_heal_spark = 0.0


## Writes Health.hp back to the run on every change, never once dead.
func _on_hp_changed(hp: int) -> void:
	if state == State.DEAD:
		return
	Game.run.hp = hp


func _refresh_stats() -> void:
	_stats = Game.run.stats()
	health.set_max_hp(_stats.max_hp)
	var e := Game.run.equipment
	var off := e.offhand if e.dual_active() else &""
	if e.weapon != weapon_id or off != offhand_id:
		_set_weapon(e.weapon, off)
	if sprite.outfit_dir != String(e.outfit).trim_prefix("outfit_"):
		sprite.set_outfit(e.outfit)
	sprite.set_gear(e.armor, e.helm, e.show_armor)
	sprite.set_backpack(e.backpack)


## Main weapon `id`, and the off-hand sword `off` when Lâminas Gêmeas is on
## with two swords (&"" otherwise).
func _set_weapon(id: StringName, off: StringName = &"") -> void:
	weapon_id = id
	offhand_id = off
	if off != &"":
		weapon = WeaponDef.dual_swords(id)
	else:
		weapon = WeaponDef.for_item(id) if ItemDB.kind(id) == &"weapon" else WeaponDef.for_type(&"sword")
	var cd := special.cooldown
	special = SpecialCharge.new(weapon.special_hold, weapon.charge_hold)
	special.cooldown = cd
	_combo_step = -1
	_set_swing_shape(weapon.reach, weapon.arc_deg)
	sprite.set_weapon(weapon.type, id if ItemDB.kind(id) == &"weapon" else &"")
	sprite.set_offhand(off)
	if _fx != null:
		_fx.tint = ItemDB.fx_color(id)
		_fx.offhand_tint = ItemDB.fx_color(off)


func _apply_debug_weapon() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--weapon="):
			var id := StringName(a.substr(9))
			if ItemDB.kind(id) == &"weapon" and Game.run.equipment.weapon != id:
				Game.run.equipment.weapon = id
		elif a.begins_with("--special-cd="):
			special.cooldown = float(a.substr(13))


func _on_hurt(from: Hitbox) -> void:
	if state == State.DEAD or invincible_time > 0.0:
		return
	if blocks_left > 0:
		blocks_left -= 1
		invincible_time = HURT_IFRAMES * 0.5
		return
	health.damage(Combat.reduce(from.damage, _stats.defense), from.global_position)


## A hit that deals damage breaks the charge (a blocked hit does not).
func _on_damaged(_n: int) -> void:
	invincible_time = HURT_IFRAMES
	# M on the ladder: red flash, a small shake; the HUD heart pulses.
	Sfx.play(&"player_hurt")
	Fx.flash(sprite, Fx.FLASH_HURT, Fx.HURT_FLASH_TIME)
	Fx.shake(1.5, 0.15)
	Fx.burst(&"hit", global_position + HAND)
	special.cancel()
	_exit.interrupt()
	exit_progress.emit(0.0)
	_exit_was_channeling = false


func _on_hitbox_landed(_target: Hurtbox) -> void:
	_lifesteal(hitbox.damage)


func _lifesteal(dmg: int) -> void:
	if _stats.lifesteal > 0.0:
		health.heal(dmg * _stats.lifesteal)


func _on_died() -> void:
	state = State.DEAD
	remove_from_group(&"player")
	hurtbox.invulnerable = true
	hitbox.set_active(false)
	special.cancel()
	sprite.speed_scale = 1.0
	sprite.play(&"death", Vector2.DOWN, true)
	sprite.position = SPRITE_HOME
	Sfx.stop_loop(&"heal_loop")
	Fx.hit_stop(Fx.STOP_FRAMES[Fx.L])
	Fx.shake(3.0, 0.4)
	died.emit()
