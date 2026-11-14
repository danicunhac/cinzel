class_name Shooter
extends EnemyBase

const SPEED := 60.0
const PREFERRED := 120.0
const BAND := 18.0
const FIRE_INTERVAL := 1.5
const AIM_TIME := 0.25
const PROJECTILE_SPEED := 135.0
const ProjectileScene := preload("res://actors/enemies/projectile.tscn")

var _cooldown: float = FIRE_INTERVAL
var _aim: float = -1.0


func _think(delta: float) -> void:
	var p := player()
	if p == null:
		velocity = Vector2.ZERO
		play(ROW_IDLE)
		return
	var to := p.global_position - global_position
	var dist := to.length()
	face(to)
	if _aim >= 0.0:
		velocity = Vector2.ZERO
		_aim += delta
		if _aim >= AIM_TIME:
			_aim = -1.0
			set_telegraph(false)
			_fire(to.normalized())
		return
	if dist > PREFERRED + BAND:
		velocity = to.normalized() * SPEED
		play(ROW_MOVE)
	elif dist < PREFERRED - BAND:
		velocity = -to.normalized() * SPEED
		play(ROW_MOVE)
	else:
		velocity = Vector2.ZERO
		play(ROW_IDLE)
	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = FIRE_INTERVAL
		_aim = 0.0
		velocity = Vector2.ZERO
		set_telegraph(true)
		play(ROW_ATTACK)


func _fire(dir: Vector2) -> void:
	var shot := ProjectileScene.instantiate() as Projectile
	shot.damage = hitbox.damage
	shot.direction = dir
	shot.speed = PROJECTILE_SPEED
	shot.position = position + Vector2(0, -9) + dir * 9.0
	get_parent().add_child(shot)
	play(ROW_IDLE)


func loot_type() -> StringName:
	return &"shooter"
