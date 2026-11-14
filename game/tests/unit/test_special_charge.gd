extends RefCounted


func test_tap_is_not_special() -> void:
	var c := SpecialCharge.new()
	c.press()
	c.tick(0.2, true)
	T.eq(c.tick(0.016, false), SpecialCharge.NONE)


func test_hold_past_threshold_fires_special() -> void:
	var c := SpecialCharge.new()
	c.press()
	c.tick(0.49, true)
	T.ok(not c.is_charged(), "not yet at 0.49 s")
	c.tick(0.02, true)
	T.ok(c.is_charged(), "charged at 0.51 s")
	T.eq(c.tick(0.016, false), SpecialCharge.SPECIAL)
	T.near(c.cooldown, SpecialCharge.COOLDOWN, 0.02)


func test_cooldown_blocks_and_recovers() -> void:
	var c := SpecialCharge.new()
	c.press()
	c.tick(0.6, true)
	c.tick(0.0, false)
	c.press()
	c.tick(0.6, true)
	T.ok(not c.is_charged(), "no charge while cooling down")
	T.eq(c.tick(0.0, false), SpecialCharge.NONE)
	c.tick(SpecialCharge.COOLDOWN, false)
	T.near(c.cooldown, 0.0)
	T.near(c.cooldown_ratio(), 0.0)
	c.press()
	c.tick(0.5, true)
	T.eq(c.tick(0.0, false), SpecialCharge.SPECIAL)


func test_bow_two_stages() -> void:
	var c := SpecialCharge.new(1.0, 0.5)
	c.press()
	c.tick(0.6, true)
	T.eq(c.tick(0.0, false), SpecialCharge.CHARGED, "0.6 s: piercing arrow")
	T.near(c.cooldown, 0.0)
	c.press()
	c.tick(1.0, true)
	T.eq(c.tick(0.0, false), SpecialCharge.SPECIAL, "1.0 s: rain")
	c.press()
	c.tick(1.2, true)
	T.eq(c.tick(0.0, false), SpecialCharge.CHARGED, "rain on cooldown: still a piercing arrow")
