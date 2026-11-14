class_name Hurtbox
extends Area2D

signal hit(hitbox: Hitbox)

@export var team: StringName = &""
## While true, hits are rejected before can_hit/landed, so hitboxes are not
## consumed. Overlaps are re-checked when it turns off.
var invulnerable: bool = false

var _was_invulnerable: bool = false


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _physics_process(_delta: float) -> void:
	if _was_invulnerable and not invulnerable:
		for area in get_overlapping_areas():
			if area is Hitbox:
				receive(area as Hitbox)
	_was_invulnerable = invulnerable


func _on_area_entered(area: Area2D) -> void:
	if area is Hitbox:
		receive(area as Hitbox)


## Returns true when the hit counted (other team, not already hit this swing).
func receive(hitbox: Hitbox) -> bool:
	if invulnerable or hitbox.team == team:
		return false
	if not hitbox.can_hit(self):
		return false
	hit.emit(hitbox)
	hitbox.landed.emit(self)
	return true
