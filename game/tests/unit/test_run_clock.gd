extends RefCounted


func test_clock_stopped_by_default() -> void:
	var c := RunClock.new()
	c.tick(10.0)
	T.near(c.seconds, 0.0)


func test_clock_runs() -> void:
	var c := RunClock.new()
	c.running = true
	c.tick(59.9)
	T.eq(c.level(), 0)
	c.tick(0.2)
	T.eq(c.level(), 1)


func test_clock_pause_keeps_value() -> void:
	var c := RunClock.new()
	c.running = true
	c.tick(90.0)
	c.running = false
	c.tick(30.0)
	T.near(c.seconds, 90.0, 0.01)


func test_clock_reset() -> void:
	var c := RunClock.new()
	c.running = true
	c.tick(130.0)
	c.reset()
	T.near(c.seconds, 0.0)
	T.eq(c.level(), 0)
