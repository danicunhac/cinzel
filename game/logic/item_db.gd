class_name ItemDB
extends RefCounted

const _ITEMS: Dictionary = {
	&"heavy_blade": {
		"name": "Lâmina Pesada",
		"desc": "+50% de dano, -25% de velocidade de ataque.",
		"buy": 60,
		"sell": 30,
		"icon": "res://assets/items/heavy_blade.png",
		"mods": {"dmg_mult": 1.5, "attack_speed_mult": 0.75},
	},
	&"light_boots": {
		"name": "Botas Leves",
		"desc": "+25% de velocidade de movimento.",
		"buy": 50,
		"sell": 25,
		"icon": "res://assets/items/light_boots.png",
		"mods": {"move_speed_mult": 1.25},
	},
	&"stone_heart": {
		"name": "Coração de Pedra",
		"desc": "+40 de vida máxima.",
		"buy": 50,
		"sell": 25,
		"icon": "res://assets/items/stone_heart.png",
		"mods": {"max_hp_add": 40},
	},
	&"fang": {
		"name": "Presa",
		"desc": "Recupera 10% do dano causado como vida.",
		"buy": 70,
		"sell": 35,
		"icon": "res://assets/items/fang.png",
		"mods": {"lifesteal": 0.1},
	},
	&"wind_cape": {
		"name": "Capa do Vento",
		"desc": "+50% de distância da rolagem.",
		"buy": 50,
		"sell": 25,
		"icon": "res://assets/items/wind_cape.png",
		"mods": {"roll_distance_mult": 1.5},
	},
	&"cracked_hourglass": {
		"name": "Ampulheta Rachada",
		"desc": "A cura começa mais cedo.",
		"buy": 60,
		"sell": 30,
		"icon": "res://assets/items/cracked_hourglass.png",
		"mods": {"heal_delay": 0.75},
	},
	&"spark": {
		"name": "Faísca",
		"desc": "Deixa um rastro que causa dano.",
		"buy": 70,
		"sell": 35,
		"icon": "res://assets/items/spark.png",
		"mods": {"trail_damage": 4},
	},
	&"glass_shield": {
		"name": "Escudo de Vidro",
		"desc": "Bloqueia 1 golpe por sala.",
		"buy": 80,
		"sell": 40,
		"icon": "res://assets/items/glass_shield.png",
		"mods": {"block_per_room": 1},
	},
}


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in _ITEMS.keys():
		out.append(k)
	return out


static func has(id: StringName) -> bool:
	return _ITEMS.has(id)


static func get_def(id: StringName) -> Dictionary:
	return (_ITEMS[id] as Dictionary).duplicate(true)
