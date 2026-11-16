extends RefCounted


func _hold(c: ExitChannel, seconds: float, in_boss: bool = false) -> int:
	var status := ExitChannel.IDLE
	for i in roundi(seconds / 0.1):
		status = c.update(0.1, true, in_boss)
	return status


func test_exit_completes() -> void:
	var c := ExitChannel.new()
	T.eq(_hold(c, 2.0), ExitChannel.DONE)


func test_exit_release_resets() -> void:
	var c := ExitChannel.new()
	_hold(c, 1.5)
	T.eq(c.update(0.1, false, false), ExitChannel.IDLE)
	T.near(c.progress, 0.0)
	var status := _hold(c, 1.0)
	T.ok(c.progress < 1.0, "progress below 1")
	T.near(c.progress, 0.5, 0.01)
	T.ok(status != ExitChannel.DONE, "not done")


func test_exit_blocked_in_boss() -> void:
	var c := ExitChannel.new()
	T.eq(c.update(1.0, true, true), ExitChannel.BLOCKED)
	T.near(c.progress, 0.0)


func test_exit_interrupt() -> void:
	var c := ExitChannel.new()
	_hold(c, 1.9)
	c.interrupt()
	T.near(c.progress, 0.0)
	T.ok(_hold(c, 0.2) != ExitChannel.DONE, "not done after interrupt")


func test_exit_interrupt_needs_repress() -> void:
	var c := ExitChannel.new()
	_hold(c, 1.9)
	c.interrupt()
	c.update(0.1, false, false)
	T.eq(_hold(c, 2.0), ExitChannel.DONE)


func test_exit_done_sticks_until_release() -> void:
	var c := ExitChannel.new()
	_hold(c, 2.0)
	T.eq(c.update(0.1, true, false), ExitChannel.DONE)
