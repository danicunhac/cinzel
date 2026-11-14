class_name ExitChannel
extends RefCounted

enum Status { IDLE, CHANNELING, BLOCKED, DONE }

const IDLE := Status.IDLE
const CHANNELING := Status.CHANNELING
const BLOCKED := Status.BLOCKED
const DONE := Status.DONE
const HOLD := 2.0

var progress: float = 0.0
var _elapsed: float = 0.0
var _needs_repress: bool = false


func update(delta: float, holding: bool, in_boss_room: bool) -> int:
	if not holding:
		_reset()
		_needs_repress = false
		return Status.IDLE
	if in_boss_room:
		_reset()
		return Status.BLOCKED
	if _needs_repress:
		return Status.IDLE
	_elapsed += delta
	progress = clampf(_elapsed / HOLD, 0.0, 1.0)
	if progress >= 1.0:
		return Status.DONE
	return Status.CHANNELING


func interrupt() -> void:
	_reset()
	_needs_repress = true


func _reset() -> void:
	_elapsed = 0.0
	progress = 0.0
