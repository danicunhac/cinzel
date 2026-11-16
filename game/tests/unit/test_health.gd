extends RefCounted


func _make(max_hp: int = 100) -> Health:
	var h := Health.new()
	h.max_hp = max_hp
	h.hp = max_hp
	return h


func test_damage_reduces_hp_and_emits() -> void:
	var h := _make()
	var seen: Array[int] = []
	h.damaged.connect(func(n: int) -> void: seen.append(n))
	h.damage(30, Vector2.ZERO)
	T.eq(h.hp, 70)
	T.eq(seen, [30] as Array[int])
	h.free()


func test_damage_clamps_and_dies_once() -> void:
	var h := _make()
	var deaths: Array[int] = [0]
	h.died.connect(func() -> void: deaths[0] += 1)
	h.damage(250, Vector2.ZERO)
	T.eq(h.hp, 0)
	h.damage(10, Vector2.ZERO)
	T.eq(deaths[0], 1)
	h.free()


func test_heal_clamps_to_max() -> void:
	var h := _make()
	h.damage(10, Vector2.ZERO)
	h.heal(50.0)
	T.eq(h.hp, 100)
	h.free()


func test_heal_accumulates_fractions() -> void:
	var h := _make()
	h.damage(10, Vector2.ZERO)
	h.heal(0.4)
	T.eq(h.hp, 90)
	h.heal(0.4)
	T.eq(h.hp, 90)
	h.heal(0.4)
	T.eq(h.hp, 91)
	h.free()


func test_no_heal_when_dead() -> void:
	var h := _make()
	h.damage(100, Vector2.ZERO)
	h.heal(20.0)
	T.eq(h.hp, 0)
	h.free()


func test_hp_changed_emitted_on_every_change() -> void:
	var h := _make()
	var seen: Array[int] = []
	h.hp_changed.connect(func(v: int) -> void: seen.append(v))
	h.damage(10, Vector2.ZERO)
	h.heal(5.0)
	h.heal(100.0)
	h.heal(1.0)
	h.set_max_hp(50)
	h.set_max_hp(60)
	T.eq(seen, [90, 95, 100, 50] as Array[int])
	h.free()
