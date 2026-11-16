extends RefCounted


func _boxes(hb_team: StringName, hit_team: StringName) -> Array:
	var hurt := Hurtbox.new()
	hurt.team = hb_team
	var hit := Hitbox.new()
	hit.team = hit_team
	hit.damage = 7
	return [hurt, hit]


func test_ignores_own_team() -> void:
	var b := _boxes(&"player", &"player")
	var count: Array[int] = [0]
	(b[0] as Hurtbox).hit.connect(func(_h: Hitbox) -> void: count[0] += 1)
	T.ok(not (b[0] as Hurtbox).receive(b[1]), "own team ignored")
	T.eq(count[0], 0)
	(b[0] as Node).free()
	(b[1] as Node).free()


func test_other_team_emits_once_per_swing() -> void:
	var b := _boxes(&"enemy", &"player")
	var hurt := b[0] as Hurtbox
	var hit := b[1] as Hitbox
	var got: Array[int] = []
	hurt.hit.connect(func(h: Hitbox) -> void: got.append(h.damage))
	T.ok(hurt.receive(hit), "first hit counts")
	T.ok(not hurt.receive(hit), "second hit same swing ignored")
	hit.set_active(true)
	hit.set_active(false)
	hit.set_active(true)
	T.ok(hurt.receive(hit), "new swing counts")
	T.eq(got, [7, 7] as Array[int])
	hurt.free()
	hit.free()


func test_landed_signal() -> void:
	var b := _boxes(&"enemy", &"player")
	var landed: Array[int] = [0]
	(b[1] as Hitbox).landed.connect(func(_t: Hurtbox) -> void: landed[0] += 1)
	(b[0] as Hurtbox).receive(b[1])
	T.eq(landed[0], 1)
	(b[0] as Node).free()
	(b[1] as Node).free()


func test_invulnerable_rejects_without_consuming_hitbox() -> void:
	var b := _boxes(&"enemy", &"player")
	var hurt := b[0] as Hurtbox
	var hit := b[1] as Hitbox
	var hits: Array[int] = [0]
	var landed: Array[int] = [0]
	hurt.hit.connect(func(_h: Hitbox) -> void: hits[0] += 1)
	hit.landed.connect(func(_t: Hurtbox) -> void: landed[0] += 1)
	hurt.invulnerable = true
	T.ok(not hurt.receive(hit), "rejected while invulnerable")
	T.eq(hits[0], 0)
	T.eq(landed[0], 0)
	T.eq(hit._already_hit.size(), 0)
	hurt.invulnerable = false
	T.ok(hurt.receive(hit), "hits once invulnerability ends")
	T.eq(hits[0], 1)
	T.eq(landed[0], 1)
	hurt.free()
	hit.free()
