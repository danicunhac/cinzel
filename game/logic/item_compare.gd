class_name ItemCompare
extends RefCounted
## Stat rows for the item tooltips. compare() says what changes if `id` is
## worn instead of the current gear; own() lists what an item gives.
## Each row: {"label": String, "old": String, "new": String, "delta": int}
## with delta 1 = better, -1 = worse, 0 = no arrow.

## [PlayerStats property, label, 1 when more is better / -1 when less is, format]
const STATS: Array = [
	[&"damage", "Dano", 1, &"int"],
	[&"attack_speed_mult", "Vel. ataque", 1, &"pct"],
	[&"attack_range", "Alcance", 1, &"int"],
	[&"crit_chance", "Crítico", 1, &"pct"],
	[&"defense", "Defesa", 1, &"int"],
	[&"max_hp", "Vida", 1, &"int"],
	[&"weight", "Peso", -1, &"int"],
	[&"move_speed", "Velocidade", 1, &"int"],
	[&"roll_distance", "Rolamento", 1, &"int"],
	[&"lifesteal", "Roubo de vida", 1, &"pct"],
	[&"heal_delay", "Espera da cura", -1, &"sec"],
	[&"trail_damage", "Rastro", 1, &"int"],
	[&"block_per_room", "Bloqueio", 1, &"int"],
]
const GEAR_KINDS: Array[StringName] = [&"weapon", &"armor", &"helm", &"relic"]


## What changes if `id` is equipped over `eq` (a relic is added as an extra
## one, so the rows show what it gives). Only stats that change are listed.
## Backpacks compare their slots. Materials and outfits have no rows.
static func compare(eq: Equipment, id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var kind := ItemDB.kind(id)
	if kind == &"backpack":
		var old := eq.capacity()
		var new := ItemDB.backpack_slots(id)
		out.append(_row("Espaços", str(old), str(new), signi(new - old)))
		return out
	if not GEAR_KINDS.has(kind):
		return out
	var after := eq.copy()
	match kind:
		&"weapon":
			after.weapon = id
		&"armor":
			after.armor = id
		&"helm":
			after.helm = id
		&"relic":
			after.relics.append(id)
	var a := PlayerStats.from_equipment(eq)
	var b := PlayerStats.from_equipment(after)
	for s: Array in STATS:
		var va: float = float(a.get(s[0]))
		var vb: float = float(b.get(s[0]))
		if is_equal_approx(va, vb):
			continue
		var better: int = signi(int(signf(vb - va))) * int(s[2])
		out.append(_row(s[1], _fmt(va, s[3]), _fmt(vb, s[3]), better))
	return out


## What `id` gives on its own (equipped items): its stats, no arrows.
static func own(id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var kind := ItemDB.kind(id)
	if kind == &"backpack":
		out.append(_row("Espaços", "", str(ItemDB.backpack_slots(id)), 0))
		return out
	if not GEAR_KINDS.has(kind):
		return out
	var bare := Equipment.new()
	if kind != &"weapon":
		# Weapons set the base numbers; everything else adds to the starter sword.
		bare.weapon = Equipment.STARTER_WEAPON
	var a := PlayerStats.from_equipment(bare)
	var with := bare.copy()
	match kind:
		&"weapon":
			with.weapon = id
		&"armor":
			with.armor = id
		&"helm":
			with.helm = id
		&"relic":
			with.relics.append(id)
	var b := PlayerStats.from_equipment(with)
	for s: Array in STATS:
		var va: float = float(a.get(s[0]))
		var vb: float = float(b.get(s[0]))
		if kind == &"weapon":
			if s[0] in [&"damage", &"attack_speed_mult", &"attack_range", &"crit_chance"] or not is_equal_approx(va, vb):
				out.append(_row(s[1], "", _fmt(vb, s[3]), 0))
		elif not is_equal_approx(va, vb):
			out.append(_row(s[1], "", _signed(vb - va, s[3]), 0))
	return out


static func _row(label: String, old: String, new: String, delta: int) -> Dictionary:
	return {"label": label, "old": old, "new": new, "delta": delta}


static func _fmt(v: float, f: StringName) -> String:
	match f:
		&"pct":
			return "%d%%" % roundi(v * 100.0)
		&"sec":
			return ("%.2f s" % v).replace(".", ",").replace(",00 s", " s").replace("0 s", " s")
	return str(roundi(v))


static func _signed(d: float, f: StringName) -> String:
	var t := _fmt(absf(d), f)
	return ("+" if d > 0.0 else "-") + t
