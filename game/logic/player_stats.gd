class_name PlayerStats
extends RefCounted

var max_hp: int = 100
var damage: int = 10
var attack_speed_mult: float = 1.0
var move_speed: float = 80.0
var roll_distance: float = 48.0
var lifesteal: float = 0.0
var heal_delay: float = 1.5
var heal_per_sec: float = 8.0
var trail_damage: int = 0
var block_per_room: int = 0


static func from_items(items: Array[StringName]) -> PlayerStats:
	var s: PlayerStats = PlayerStats.new()
	var dmg_mult: float = 1.0
	var move_mult: float = 1.0
	var roll_mult: float = 1.0
	for id: StringName in items:
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
	s.damage = roundi(s.damage * dmg_mult)
	s.move_speed *= move_mult
	s.roll_distance *= roll_mult
	return s
