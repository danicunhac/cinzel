class_name BossFinal
extends EnemyBase
## Boss of floor 3. Walks toward the player, then alternates a dash (red
## warning line) and a fan of projectiles. Phase 2 starts at half HP: it
## summons SUMMON_COUNT crawlers right away and every SUMMON_INTERVAL seconds,
## and moves PHASE2_SPEED times faster. Its crawlers die with it.
## In the group "boss"; boss_hp fires on spawn and on every HP change.

signal boss_hp(hp: int, max_hp: int)

enum State { WALK, DASH_WARN, DASH, AIM, RECOVER }

const WALK_SPEED := 30.0
const WALK_TIME := 1.4
const DASH_WARN_TIME := 0.6
const DASH_SPEED := 170.0
const DASH_TIME := 0.5
const AIM_TIME := 0.5
const RECOVER_TIME := 0.7
const FAN_SHOTS := 5
const FAN_SPREAD := PI / 3.0
const SHOT_SPEED := 85.0
const SHOT_DAMAGE_MULT := 0.7
const SUMMON_INTERVAL := 8.0
const SUMMON_COUNT := 2
const SUMMON_OFFSET := 28.0
const PHASE2_SPEED := 1.2
const PHASE2_TINT := Color(1.0, 0.72, 0.68)
## Room interior (inside the outer walls), where summons may appear.
const ROOM_INNER := Rect2(24, 24, 272, 128)
const CrawlerScene := preload("res://actors/enemies/crawler.tscn")
const ProjectileScene := preload("res://actors/enemies/projectile.tscn")

## 1 while hp > 50%, then 2 for good.
var phase: int = 1
var state: State = State.WALK
var minions: Array[EnemyBase] = []

var _t: float = 0.0
var _dir: Vector2 = Vector2.RIGHT
var _dash_next: bool = true
var _summon_cd: float = 0.0

@onready var warning: Line2D = $Warning


func _ready() -> void:
	super()
	add_to_group(&"boss")
	warning.visible = false
	health.hp_changed.connect(_on_hp_changed)
	_emit_hp.call_deferred()


func _emit_hp() -> void:
	boss_hp.emit(health.hp, health.max_hp)


func speed_mult() -> float:
	return PHASE2_SPEED if phase == 2 else 1.0


func _on_hp_changed(hp: int) -> void:
	_emit_hp()
	if phase == 1 and hp > 0 and hp * 2 <= health.max_hp:
		phase = 2
		_summon_cd = 0.0
		sprite.self_modulate = PHASE2_TINT


func _think(delta: float) -> void:
	var p := player()
	_t += delta
	if phase == 2:
		_summon_cd -= delta
		if _summon_cd <= 0.0:
			_summon_cd = SUMMON_INTERVAL
			summon()
	match state:
		State.WALK:
			if p == null:
				velocity = Vector2.ZERO
				play(ROW_IDLE)
				return
			var to := p.global_position - global_position
			face(to)
			velocity = to.normalized() * WALK_SPEED * speed_mult()
			play(ROW_MOVE)
			if _t >= WALK_TIME / speed_mult():
				_dir = to.normalized()
				velocity = Vector2.ZERO
				set_telegraph(true)
				play(ROW_ATTACK)
				if _dash_next:
					_enter(State.DASH_WARN)
					warning.visible = true
				else:
					_enter(State.AIM)
				_dash_next = not _dash_next
		State.DASH_WARN:
			velocity = Vector2.ZERO
			if p != null:
				_dir = (p.global_position - global_position).normalized()
				face(_dir)
			_point_warning()
			if _t >= DASH_WARN_TIME:
				_enter(State.DASH)
				set_telegraph(false)
				warning.visible = false
				hitbox.position = Vector2(0, -12)
				hitbox.set_active(true)
		State.DASH:
			velocity = _dir * DASH_SPEED * speed_mult()
			if _t >= DASH_TIME or (is_on_wall() and _t > 0.05):
				hitbox.set_active(false)
				_rest()
		State.AIM:
			velocity = Vector2.ZERO
			if p != null:
				_dir = (p.global_position - global_position).normalized()
				face(_dir)
			if _t >= AIM_TIME:
				set_telegraph(false)
				fire_fan(_dir)
				_rest()
		State.RECOVER:
			velocity = Vector2.ZERO
			if _t >= RECOVER_TIME / speed_mult():
				_enter(State.WALK)


func fire_fan(dir: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	for i in FAN_SHOTS:
		var k := float(i) / float(FAN_SHOTS - 1) - 0.5
		var d := dir.rotated(k * FAN_SPREAD)
		var shot := ProjectileScene.instantiate() as Projectile
		shot.damage = roundi(hitbox.damage * SHOT_DAMAGE_MULT)
		shot.direction = d
		shot.speed = SHOT_SPEED * speed_mult()
		shot.position = position + Vector2(0, -12) + d * 10.0
		parent.add_child(shot)


## Adds SUMMON_COUNT crawlers beside the boss; they fade in like room spawns.
func summon() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for i in SUMMON_COUNT:
		var side := -1.0 if i % 2 == 0 else 1.0
		var pos := position + Vector2(side * SUMMON_OFFSET, 0.0)
		if parent is Room:
			pos = pos.clamp(ROOM_INNER.position, ROOM_INNER.end)
		var c := CrawlerScene.instantiate() as EnemyBase
		c.position = pos
		parent.add_child(c)
		minions.append(c)
		c.set_physics_process(false)
		c.modulate.a = 0.0
		var tw := c.create_tween()
		tw.tween_property(c, "modulate:a", 1.0, Room.SPAWN_GRACE)
		tw.tween_callback(func() -> void:
			if not c.dead:
				c.set_physics_process(true))


func _rest() -> void:
	velocity = Vector2.ZERO
	_enter(State.RECOVER)
	play(ROW_IDLE)


func _point_warning() -> void:
	var from := Vector2(0, -12)
	warning.points = PackedVector2Array([from, from + _dir * DASH_SPEED * speed_mult() * DASH_TIME])


func _enter(s: State) -> void:
	state = s
	_t = 0.0


func _on_died() -> void:
	warning.visible = false
	for m in minions:
		if is_instance_valid(m) and not m.dead:
			m.health.damage(m.health.hp, m.global_position)
	super()
