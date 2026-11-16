class_name HealRule
extends RefCounted

var healing: bool = false
var _idle_time: float = 0.0


func update(delta: float, is_idle: bool, delay: float, per_sec: float) -> float:
	if not is_idle:
		_idle_time = 0.0
		healing = false
		return 0.0
	var before := _idle_time
	_idle_time += delta
	healing = _idle_time >= delay
	if not healing:
		return 0.0
	var healed_time := _idle_time - maxf(before, delay)
	return per_sec * healed_time
