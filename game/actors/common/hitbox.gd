class_name Hitbox
extends Area2D

## Emitted when this hitbox connects with a hurtbox (used for lifesteal).
signal landed(hurtbox: Hurtbox)

@export var damage: int = 0
@export var team: StringName = &""

var _already_hit: Array[Hurtbox] = []


## One hit per hurtbox per swing. Returns true the first time.
func can_hit(hurtbox: Hurtbox) -> bool:
	if hurtbox in _already_hit:
		return false
	_already_hit.append(hurtbox)
	return true


func set_active(active: bool) -> void:
	if active:
		_already_hit.clear()
	for c in get_children():
		if c is CollisionShape2D:
			(c as CollisionShape2D).set_deferred("disabled", not active)
