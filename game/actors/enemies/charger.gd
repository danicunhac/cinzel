class_name Charger
extends EnemyBase

enum State { WALK, WARN, DASH, RECOVER }

const WALK_SPEED := 35.0
const TRIGGER_RANGE := 100.0
const WARN_TIME := 0.6
const DASH_SPEED := 160.0
const DASH_TIME := 0.55
const RECOVER_TIME := 0.9

var state: State = State.WALK
var _t: float = 0.0
var _dir: Vector2 = Vector2.RIGHT

@onready var warning: Line2D = $Warning


func _ready() -> void:
	super()
	warning.visible = false


func _think(delta: float) -> void:
	var p := player()
	_t += delta
	match state:
		State.WALK:
			if p == null:
				velocity = Vector2.ZERO
				play(ROW_IDLE)
				return
			var to := p.global_position - global_position
			face(to)
			if to.length() <= TRIGGER_RANGE:
				_enter(State.WARN)
				_dir = to.normalized()
				velocity = Vector2.ZERO
				set_telegraph(true)
				warning.visible = true
				play(ROW_ATTACK)
			else:
				velocity = to.normalized() * WALK_SPEED
				play(ROW_MOVE)
		State.WARN:
			velocity = Vector2.ZERO
			if p != null:
				_dir = (p.global_position - global_position).normalized()
			face(_dir)
			_point_warning()
			if _t >= WARN_TIME:
				_enter(State.DASH)
				set_telegraph(false)
				warning.visible = false
				hitbox.position = Vector2(0, -6)
				hitbox.set_active(true)
		State.DASH:
			velocity = _dir * DASH_SPEED
			if _t >= DASH_TIME or (is_on_wall() and _t > 0.05):
				_enter(State.RECOVER)
				hitbox.set_active(false)
				velocity = Vector2.ZERO
				play(ROW_IDLE)
		State.RECOVER:
			velocity = Vector2.ZERO
			if _t >= RECOVER_TIME:
				_enter(State.WALK)


func _point_warning() -> void:
	var reach := DASH_SPEED * DASH_TIME
	warning.points = PackedVector2Array([Vector2(0, -6), Vector2(0, -6) + _dir * reach])


func _enter(s: State) -> void:
	state = s
	_t = 0.0
