class_name Hitbox
extends Area2D

## Emitted when this hitbox connects with a hurtbox (used for lifesteal).
signal landed(hurtbox: Hurtbox)

@export var damage: int = 0
@export var team: StringName = &""
## Seconds a hit enemy stops acting (axe); bosses ignore it.
var stun: float = 0.0
## The current damage came from a crit roll (enemies flash gold).
var crit: bool = false

var _active: bool = false
var _already_hit: Array[Hurtbox] = []


## One hit per hurtbox per swing. Returns true the first time.
func can_hit(hurtbox: Hurtbox) -> bool:
	if hurtbox in _already_hit:
		return false
	_already_hit.append(hurtbox)
	return true


func set_active(active: bool) -> void:
	if active and not _active:
		_already_hit.clear()
	_active = active
	for c in get_children():
		if c is CollisionShape2D:
			(c as CollisionShape2D).set_deferred("disabled", not active)


## Lets every hurtbox be hit again (a new cut of a multi-hit attack).
func reset_hits() -> void:
	_already_hit.clear()


## Hits every hurtbox overlapping now (a new cut on enemies already inside).
func hit_overlapping() -> void:
	for area in get_overlapping_areas():
		if area is Hurtbox:
			(area as Hurtbox).receive(self)
