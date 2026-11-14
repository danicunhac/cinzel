class_name BossBig
extends EnemyBase
## Boss of floors 1 and 2: a common enemy (`base`) at twice the size with
## HP_MULT times its life. A crawler base chases and bites; a charger base
## dashes along a red warning line. Every SHOCK_INTERVAL seconds it stops and
## sends a ring shockwave after a 0.8 s red warning.
## In the group "boss"; boss_hp fires on spawn and on every HP change.

signal boss_hp(hp: int, max_hp: int)

enum State { CHASE, WINDUP, STRIKE, RECOVER, SHOCK }

const HP_MULT := 8
const GOLD_MULT := 6
const SHOCK_INTERVAL := 5.0
# Crawler base: bite.
const CHASE_SPEED := 38.0
const BITE_RANGE := 26.0
const BITE_WINDUP := 0.45
const BITE_TIME := 0.2
# Charger base: dash.
const WALK_SPEED := 28.0
const DASH_TRIGGER := 130.0
const DASH_WARN := 0.7
const DASH_SPEED := 150.0
const DASH_TIME := 0.6
const RECOVER_TIME := 0.8

@export var base: PackedScene

var state: State = State.CHASE
## True when the base enemy is a Charger (dash instead of bite).
var dashes: bool = false

var _t: float = 0.0
var _dir: Vector2 = Vector2.RIGHT
var _shock_cd: float = SHOCK_INTERVAL

@onready var shockwave: Shockwave = $Shockwave
@onready var warning: Line2D = $Warning


func _ready() -> void:
	_copy_base()
	super()
	add_to_group(&"boss")
	warning.visible = false
	shockwave.damage = hitbox.damage
	shockwave.finished.connect(func() -> void:
		set_telegraph(false)
		_enter(State.RECOVER))
	health.hp_changed.connect(func(_hp: int) -> void: _emit_hp())
	_emit_hp.call_deferred()


## Takes stats and the sprite sheet from the base enemy before EnemyBase
## scales them by the difficulty level.
func _copy_base() -> void:
	if base == null:
		push_error("BossBig: no base scene")
		return
	var inst := base.instantiate() as EnemyBase
	base_hp = inst.base_hp * HP_MULT
	base_damage = inst.base_damage
	gold_drop = inst.gold_drop * GOLD_MULT
	dashes = inst is Charger
	sprite.texture = (inst.get_node(^"Sprite") as Sprite2D).texture
	inst.free()


func _emit_hp() -> void:
	boss_hp.emit(health.hp, health.max_hp)


func _think(delta: float) -> void:
	var p := player()
	_t += delta
	if state != State.SHOCK:
		_shock_cd -= delta
	match state:
		State.CHASE:
			if p == null:
				velocity = Vector2.ZERO
				play(ROW_IDLE)
				return
			if _shock_cd <= 0.0:
				_start_shock()
				return
			var to := p.global_position - global_position
			face(to)
			var reach := DASH_TRIGGER if dashes else BITE_RANGE
			if to.length() <= reach:
				_dir = to.normalized()
				_enter(State.WINDUP)
				velocity = Vector2.ZERO
				set_telegraph(true)
				warning.visible = dashes
				play(ROW_ATTACK)
			else:
				velocity = to.normalized() * (WALK_SPEED if dashes else CHASE_SPEED)
				play(ROW_MOVE)
		State.WINDUP:
			velocity = Vector2.ZERO
			if dashes and p != null:
				_dir = (p.global_position - global_position).normalized()
				face(_dir)
				_point_warning()
			if _t >= (DASH_WARN if dashes else BITE_WINDUP):
				_enter(State.STRIKE)
				set_telegraph(false)
				warning.visible = false
				hitbox.position = Vector2(0, -12) if dashes else _dir * 16.0 + Vector2(0, -10)
				hitbox.set_active(true)
		State.STRIKE:
			velocity = _dir * (DASH_SPEED if dashes else CHASE_SPEED * 2.0)
			var length := DASH_TIME if dashes else BITE_TIME
			if _t >= length or (dashes and is_on_wall() and _t > 0.05):
				hitbox.set_active(false)
				velocity = Vector2.ZERO
				_enter(State.RECOVER)
				play(ROW_IDLE)
		State.RECOVER:
			velocity = Vector2.ZERO
			if _t >= RECOVER_TIME:
				_enter(State.CHASE)
		State.SHOCK:
			velocity = Vector2.ZERO


func _start_shock() -> void:
	_shock_cd = SHOCK_INTERVAL
	_enter(State.SHOCK)
	velocity = Vector2.ZERO
	set_telegraph(true)
	play(ROW_ATTACK)
	shockwave.trigger()


func _point_warning() -> void:
	var from := Vector2(0, -12)
	warning.points = PackedVector2Array([from, from + _dir * DASH_SPEED * DASH_TIME])


func _enter(s: State) -> void:
	state = s
	_t = 0.0


func _on_died() -> void:
	shockwave.cancel()
	warning.visible = false
	super()
