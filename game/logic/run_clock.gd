class_name RunClock
extends RefCounted

var seconds: float = 0.0
var running: bool = false


func tick(delta: float) -> void:
	if running:
		seconds += delta


func level() -> int:
	return floori(seconds / 60.0)


func reset() -> void:
	seconds = 0.0
