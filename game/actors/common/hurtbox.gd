class_name Hurtbox
extends Area2D

signal hit(hitbox: Hitbox)

@export var team: StringName = &""


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if area is Hitbox:
		receive(area as Hitbox)


## Returns true when the hit counted (other team, not already hit this swing).
func receive(hitbox: Hitbox) -> bool:
	if hitbox.team == team:
		return false
	if not hitbox.can_hit(self):
		return false
	hit.emit(hitbox)
	hitbox.landed.emit(self)
	return true
