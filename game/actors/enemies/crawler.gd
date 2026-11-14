class_name Crawler
extends EnemyBase

enum State { CHASE, WINDUP, BITE, RECOVER }

const SPEED := 50.0
const BITE_RANGE := 14.0
const WINDUP_TIME := 0.3
const BITE_TIME := 0.15
const RECOVER_TIME := 0.7

var state: State = State.CHASE
var _t: float = 0.0
var _bite_dir: Vector2 = Vector2.RIGHT


func _think(delta: float) -> void:
	var p := player()
	_t += delta
	match state:
		State.CHASE:
			if p == null:
				velocity = Vector2.ZERO
				play(ROW_IDLE)
				return
			var to := p.global_position - global_position
			face(to)
			if to.length() <= BITE_RANGE:
				_enter(State.WINDUP)
				_bite_dir = to.normalized()
				velocity = Vector2.ZERO
				set_telegraph(true)
				play(ROW_ATTACK)
			else:
				velocity = to.normalized() * SPEED
				play(ROW_MOVE)
		State.WINDUP:
			velocity = Vector2.ZERO
			if _t >= WINDUP_TIME:
				_enter(State.BITE)
				set_telegraph(false)
				hitbox.position = _bite_dir * 9.0 + Vector2(0, -5)
				hitbox.set_active(true)
		State.BITE:
			velocity = _bite_dir * SPEED * 1.5
			if _t >= BITE_TIME:
				_enter(State.RECOVER)
				hitbox.set_active(false)
				play(ROW_IDLE)
		State.RECOVER:
			velocity = Vector2.ZERO
			if _t >= RECOVER_TIME:
				_enter(State.CHASE)


func _enter(s: State) -> void:
	state = s
	_t = 0.0
