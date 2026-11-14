class_name Health
extends Node

signal died
signal damaged(n: int)

var max_hp: int = 100
var hp: int = 100
var last_hit_from: Vector2 = Vector2.ZERO
var _frac: float = 0.0


func damage(n: int, from: Vector2) -> void:
	if hp <= 0 or n <= 0:
		return
	last_hit_from = from
	hp = maxi(hp - n, 0)
	_frac = 0.0
	damaged.emit(n)
	if hp == 0:
		died.emit()


func heal(n: float) -> void:
	if hp <= 0 or n <= 0.0:
		return
	_frac += n
	var whole := int(_frac)
	_frac -= whole
	hp = mini(hp + whole, max_hp)
	if hp == max_hp:
		_frac = 0.0
