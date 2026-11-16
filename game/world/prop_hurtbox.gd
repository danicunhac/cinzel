class_name PropHurtbox
extends Hurtbox
## Hurtbox of a breakable prop: only the player's hits count, so enemy shots
## fly past pots and crates (an enemy Hurtbox would eat the projectile).


func _ready() -> void:
	team = &"prop"
	super()


func receive(hitbox: Hitbox) -> bool:
	if hitbox.team != &"player":
		return false
	return super(hitbox)
