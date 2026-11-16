extends RefCounted


func test_repeated_activate_keeps_hit_set() -> void:
	var hb := Hitbox.new()
	var hurt := Hurtbox.new()
	hb.set_active(true)
	T.ok(hb.can_hit(hurt), "first")
	hb.set_active(true)
	T.ok(not hb.can_hit(hurt), "still remembered while active")
	hb.set_active(false)
	hb.set_active(true)
	T.ok(hb.can_hit(hurt), "new swing clears")
	hb.free()
	hurt.free()
