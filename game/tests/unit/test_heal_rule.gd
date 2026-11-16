extends RefCounted


func _idle(r: HealRule, seconds: float) -> float:
	var total := 0.0
	for i in roundi(seconds / 0.1):
		total += r.update(0.1, true, 1.5, 8.0)
	return total


func test_heal_waits_delay() -> void:
	var r := HealRule.new()
	T.near(_idle(r, 1.4), 0.0)
	T.near(_idle(r, 0.6), 4.0, 0.01)


func test_heal_resets_on_move() -> void:
	var r := HealRule.new()
	var total := _idle(r, 1.0)
	total += r.update(0.1, false, 1.5, 8.0)
	total += _idle(r, 1.0)
	T.near(total, 0.0)


func test_heal_flag() -> void:
	var r := HealRule.new()
	_idle(r, 1.4)
	T.ok(not r.healing, "not healing before delay")
	_idle(r, 0.2)
	T.ok(r.healing, "healing after delay")
	r.update(0.1, false, 1.5, 8.0)
	T.ok(not r.healing, "healing stops on move")
