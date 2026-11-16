class_name PlayerStats
extends RefCounted

## Each point of armor weight makes the roll this much slower (the roll keeps
## its duration, so it also covers less ground).
const WEIGHT_ROLL_PENALTY := 0.08
const MIN_ROLL_SPEED_MULT := 0.6

var max_hp: int = 100
var damage: int = 10
var attack_speed_mult: float = 1.0
var attack_range: float = 22.0
var crit_chance: float = 0.0
## Damage multiplier of a crit (the weapon type's, see WeaponDef).
var crit_mult: float = WeaponDef.DEFAULT_CRIT_MULT
var weapon_type: StringName = &"sword"
var defense: int = 0
var weight: int = 0
var roll_speed_mult: float = 1.0
## Base walk (px/s) and roll length (px); armor, helms and relics raise them.
var move_speed: float = 90.0
var roll_distance: float = 54.0
var lifesteal: float = 0.0
var heal_delay: float = 1.5
var heal_per_sec: float = 6.0
var trail_damage: int = 0
var block_per_room: int = 0
## Lâminas Gêmeas: damage the off-hand sword adds to its hits (60% of its
## catalog damage, with the same dmg_mult mods). 0 without two swords.
var offhand_damage: int = 0


## Weapon: damage, attack speed, range, crit. Armor: defense, max hp, weight.
## Helm: crit, defense. Then every "mods" entry (relics and epic extras).
static func from_equipment(eq: Equipment) -> PlayerStats:
	var s: PlayerStats = PlayerStats.new()
	if eq.weapon != &"":
		var w: Dictionary = ItemDB.get_def(eq.weapon)["stats"]
		s.weapon_type = ItemDB.weapon_type(eq.weapon)
		s.damage = int(w["damage"])
		s.attack_speed_mult = float(w["attack_speed"])
		s.attack_range = float(w["range"])
		s.crit_chance += float(w["crit"])
		s.crit_mult = WeaponDef.for_type(s.weapon_type).crit_mult
	if eq.armor != &"":
		var a: Dictionary = ItemDB.get_def(eq.armor)["stats"]
		s.defense += int(a["defense"])
		s.max_hp += int(a["max_hp"])
		s.weight += int(a["weight"])
	if eq.helm != &"":
		var h: Dictionary = ItemDB.get_def(eq.helm)["stats"]
		s.crit_chance += float(h["crit"])
		s.defense += int(h["defense"])
	var dmg_mult: float = 1.0
	var move_mult: float = 1.0
	var roll_mult: float = 1.0
	for id: StringName in eq.stat_items():
		var mods: Dictionary = ItemDB.get_def(id)["mods"]
		dmg_mult *= float(mods.get("dmg_mult", 1.0))
		s.attack_speed_mult *= float(mods.get("attack_speed_mult", 1.0))
		move_mult *= float(mods.get("move_speed_mult", 1.0))
		roll_mult *= float(mods.get("roll_distance_mult", 1.0))
		s.max_hp += int(mods.get("max_hp_add", 0))
		s.lifesteal += float(mods.get("lifesteal", 0.0))
		s.trail_damage += int(mods.get("trail_damage", 0))
		s.block_per_room += int(mods.get("block_per_room", 0))
		if mods.has("heal_delay"):
			s.heal_delay = minf(s.heal_delay, float(mods["heal_delay"]))
	s.roll_speed_mult = maxf(MIN_ROLL_SPEED_MULT, 1.0 - WEIGHT_ROLL_PENALTY * s.weight)
	s.damage = roundi(s.damage * dmg_mult)
	if eq.dual_active():
		var o: Dictionary = ItemDB.get_def(eq.offhand)["stats"]
		s.offhand_damage = roundi(int(o["damage"]) * WeaponDef.DUAL_OFFHAND_SHARE * dmg_mult)
	s.move_speed *= move_mult
	s.roll_distance *= roll_mult * s.roll_speed_mult
	return s
