class_name ItemCatalog
extends RefCounted
## Every item in the game, as typed GDScript data. Read it through ItemDB.
##
## Schema of one entry (all keys present unless noted):
##   kind: StringName       weapon, armor, helm, backpack, relic, material, outfit
##   rarity: StringName     common, rare, epic
##   name, desc: String     Portuguese
##   base_price: int        market price before rarity and supply/demand
##   mods: Dictionary       passive effects, same keys as the old relics
##                          (dmg_mult, attack_speed_mult, move_speed_mult,
##                          roll_distance_mult, max_hp_add, lifesteal,
##                          heal_delay, trail_damage, block_per_room). Epic
##                          gear carries its extra effect here.
##   weapon_type            weapon only: sword, longsword, axe, spear, dagger, bow
##   stats: Dictionary      weapon: damage, attack_speed, range (px), crit
##                          armor: defense, max_hp, weight (0..4)
##                          helm: crit, defense
##   slots: int             backpack only
##   floor: int             material only: tower floor, 0 = boss material
##   unlock: StringName     outfit only: start, market, chest, boss
## The icon path is not stored: it is always res://assets/items/<id>.png.

const ITEMS: Dictionary[StringName, Dictionary] = {
	# Weapons: 2 per type.
	&"sword_iron": {
		"kind": &"weapon", "rarity": &"common", "weapon_type": &"sword",
		"name": "Espada de Ferro", "desc": "Equilibrada. Combo de 3 golpes.",
		"base_price": 20, "stats": {"damage": 10, "attack_speed": 1.0, "range": 22.0, "crit": 0.05}, "mods": {},
	},
	&"sword_knight": {
		"kind": &"weapon", "rarity": &"rare", "weapon_type": &"sword",
		"name": "Espada do Cavaleiro", "desc": "Uma espada bem forjada, mais forte e precisa.",
		"base_price": 60, "stats": {"damage": 13, "attack_speed": 1.05, "range": 22.0, "crit": 0.08}, "mods": {},
	},
	&"longsword_steel": {
		"kind": &"weapon", "rarity": &"common", "weapon_type": &"longsword",
		"name": "Espada Longa de Aço", "desc": "Lenta, com arco grande e muito dano.",
		"base_price": 35, "stats": {"damage": 16, "attack_speed": 0.7, "range": 30.0, "crit": 0.05}, "mods": {},
	},
	&"longsword_ember": {
		"kind": &"weapon", "rarity": &"epic", "weapon_type": &"longsword",
		"name": "Espada Longa de Brasa", "desc": "Lâmina em brasa. Deixa um rastro que queima.",
		"base_price": 90, "stats": {"damage": 22, "attack_speed": 0.75, "range": 32.0, "crit": 0.05}, "mods": {"trail_damage": 3},
	},
	&"axe_woodcutter": {
		"kind": &"weapon", "rarity": &"common", "weapon_type": &"axe",
		"name": "Machado de Lenhador", "desc": "Pesado e lento. Atordoa por um instante.",
		"base_price": 30, "stats": {"damage": 18, "attack_speed": 0.6, "range": 22.0, "crit": 0.05}, "mods": {},
	},
	&"axe_war": {
		"kind": &"weapon", "rarity": &"rare", "weapon_type": &"axe",
		"name": "Machado de Guerra", "desc": "Machado de batalha, ainda mais pesado.",
		"base_price": 70, "stats": {"damage": 23, "attack_speed": 0.62, "range": 24.0, "crit": 0.06}, "mods": {},
	},
	&"spear_hunter": {
		"kind": &"weapon", "rarity": &"common", "weapon_type": &"spear",
		"name": "Lança de Caçador", "desc": "Alcance longo e estocada.",
		"base_price": 30, "stats": {"damage": 12, "attack_speed": 0.85, "range": 48.0, "crit": 0.05}, "mods": {},
	},
	&"spear_dragoon": {
		"kind": &"weapon", "rarity": &"rare", "weapon_type": &"spear",
		"name": "Lança do Dragoneiro", "desc": "Lança de cavaleiro, alcança ainda mais longe.",
		"base_price": 65, "stats": {"damage": 15, "attack_speed": 0.9, "range": 52.0, "crit": 0.07}, "mods": {},
	},
	&"dagger_rogue": {
		"kind": &"weapon", "rarity": &"common", "weapon_type": &"dagger",
		"name": "Adaga de Ladino", "desc": "Muito rápida, pouco alcance, crítico alto.",
		"base_price": 25, "stats": {"damage": 6, "attack_speed": 1.6, "range": 14.0, "crit": 0.2}, "mods": {},
	},
	&"dagger_twin_fang": {
		"kind": &"weapon", "rarity": &"epic", "weapon_type": &"dagger",
		"name": "Presas Gêmeas", "desc": "Duas lâminas famintas. Cada corte devolve um pouco de vida.",
		"base_price": 85, "stats": {"damage": 9, "attack_speed": 1.8, "range": 14.0, "crit": 0.3}, "mods": {"lifesteal": 0.05},
	},
	&"bow_short": {
		"kind": &"weapon", "rarity": &"common", "weapon_type": &"bow",
		"name": "Arco Curto", "desc": "Ataca à distância. Carregada, a flecha atravessa um inimigo.",
		"base_price": 30, "stats": {"damage": 8, "attack_speed": 0.9, "range": 160.0, "crit": 0.1}, "mods": {},
	},
	&"bow_elven": {
		"kind": &"weapon", "rarity": &"epic", "weapon_type": &"bow",
		"name": "Arco Élfico", "desc": "Leve como uma folha. Quem o usa anda mais rápido.",
		"base_price": 90, "stats": {"damage": 12, "attack_speed": 1.0, "range": 180.0, "crit": 0.15}, "mods": {"move_speed_mult": 1.1},
	},
	# Armors: defense, max hp and weight (weight makes the roll slower).
	&"armor_cloth": {
		"kind": &"armor", "rarity": &"common",
		"name": "Roupa Acolchoada", "desc": "Pano grosso. Protege pouco e deixa o passo leve.",
		"base_price": 15, "stats": {"defense": 1, "max_hp": 0, "weight": 0}, "mods": {"move_speed_mult": 1.08},
	},
	&"armor_leather": {
		"kind": &"armor", "rarity": &"common",
		"name": "Armadura de Couro", "desc": "Leve e flexível. Rolagem um pouco mais longa.",
		"base_price": 25, "stats": {"defense": 2, "max_hp": 10, "weight": 1}, "mods": {"roll_distance_mult": 1.1},
	},
	&"armor_chain": {
		"kind": &"armor", "rarity": &"rare",
		"name": "Cota de Malha", "desc": "Boa defesa, um pouco pesada.",
		"base_price": 55, "stats": {"defense": 4, "max_hp": 20, "weight": 2}, "mods": {},
	},
	&"armor_scale": {
		"kind": &"armor", "rarity": &"rare",
		"name": "Armadura de Escamas", "desc": "Escamas sobrepostas. Pesada.",
		"base_price": 65, "stats": {"defense": 5, "max_hp": 25, "weight": 3}, "mods": {},
	},
	&"armor_plate": {
		"kind": &"armor", "rarity": &"epic",
		"name": "Armadura de Placas", "desc": "Quase impenetrável e muito pesada. Bloqueia 1 golpe por sala.",
		"base_price": 100, "stats": {"defense": 8, "max_hp": 40, "weight": 4}, "mods": {"block_per_room": 1},
	},
	&"armor_shadow": {
		"kind": &"armor", "rarity": &"epic",
		"name": "Armadura das Sombras", "desc": "Tecido de sombra. Não pesa, acelera o passo e alonga a rolagem.",
		"base_price": 100, "stats": {"defense": 4, "max_hp": 20, "weight": 0}, "mods": {"roll_distance_mult": 1.2, "move_speed_mult": 1.12},
	},
	# Helms: small crit/defense bonus.
	&"helm_hood": {
		"kind": &"helm", "rarity": &"common",
		"name": "Capuz de Viajante", "desc": "Um capuz simples. Um pouco mais de crítico e de velocidade.",
		"base_price": 15, "stats": {"crit": 0.03, "defense": 0}, "mods": {"move_speed_mult": 1.05},
	},
	&"helm_iron": {
		"kind": &"helm", "rarity": &"common",
		"name": "Elmo de Ferro", "desc": "Protege a cabeça.",
		"base_price": 25, "stats": {"crit": 0.0, "defense": 2}, "mods": {},
	},
	&"helm_horned": {
		"kind": &"helm", "rarity": &"rare",
		"name": "Elmo de Chifres", "desc": "Assusta e protege. Crítico e defesa.",
		"base_price": 50, "stats": {"crit": 0.05, "defense": 2}, "mods": {},
	},
	&"helm_circlet": {
		"kind": &"helm", "rarity": &"epic",
		"name": "Diadema Arcano", "desc": "Crítico alto. A cura começa mais cedo.",
		"base_price": 90, "stats": {"crit": 0.1, "defense": 1}, "mods": {"heal_delay": 1.0},
	},
	# Backpacks: inventory slots.
	&"backpack_small": {
		"kind": &"backpack", "rarity": &"common", "slots": 8,
		"name": "Mochila Pequena", "desc": "8 espaços.", "base_price": 10, "mods": {},
	},
	&"backpack_medium": {
		"kind": &"backpack", "rarity": &"rare", "slots": 14,
		"name": "Mochila Média", "desc": "14 espaços.", "base_price": 50, "mods": {},
	},
	&"backpack_large": {
		"kind": &"backpack", "rarity": &"epic", "slots": 20,
		"name": "Mochila Grande", "desc": "20 espaços.", "base_price": 90, "mods": {},
	},
	# Relics: the 8 items of the MVP. base_price is the old sell price.
	&"heavy_blade": {
		"kind": &"relic", "rarity": &"rare",
		"name": "Lâmina Pesada", "desc": "+50% de dano, -25% de velocidade de ataque.",
		"base_price": 30, "mods": {"dmg_mult": 1.5, "attack_speed_mult": 0.75},
	},
	&"light_boots": {
		"kind": &"relic", "rarity": &"common",
		"name": "Botas Leves", "desc": "+25% de velocidade de movimento.",
		"base_price": 25, "mods": {"move_speed_mult": 1.25},
	},
	&"stone_heart": {
		"kind": &"relic", "rarity": &"common",
		"name": "Coração de Pedra", "desc": "+40 de vida máxima.",
		"base_price": 25, "mods": {"max_hp_add": 40},
	},
	&"fang": {
		"kind": &"relic", "rarity": &"rare",
		"name": "Presa", "desc": "Recupera 10% do dano causado como vida.",
		"base_price": 35, "mods": {"lifesteal": 0.1},
	},
	&"wind_cape": {
		"kind": &"relic", "rarity": &"common",
		"name": "Capa do Vento", "desc": "+50% de distância da rolagem.",
		"base_price": 25, "mods": {"roll_distance_mult": 1.5},
	},
	&"cracked_hourglass": {
		"kind": &"relic", "rarity": &"rare",
		"name": "Ampulheta Rachada", "desc": "A cura começa mais cedo.",
		"base_price": 30, "mods": {"heal_delay": 0.75},
	},
	&"spark": {
		"kind": &"relic", "rarity": &"rare",
		"name": "Faísca", "desc": "Deixa um rastro que causa dano.",
		"base_price": 35, "mods": {"trail_damage": 4},
	},
	&"glass_shield": {
		"kind": &"relic", "rarity": &"epic",
		"name": "Escudo de Vidro", "desc": "Bloqueia 1 golpe por sala.",
		"base_price": 40, "mods": {"block_per_room": 1},
	},
	# Materials: 3 per floor, plus 1 rare boss material (floor 0).
	&"mat_slime_gel": {
		"kind": &"material", "rarity": &"common", "floor": 1,
		"name": "Gosma de Slime", "desc": "Pegajosa. Material do andar 1.", "base_price": 3, "mods": {},
	},
	&"mat_slime_core": {
		"kind": &"material", "rarity": &"common", "floor": 1,
		"name": "Núcleo de Slime", "desc": "O coração firme de um slime. Material do andar 1.", "base_price": 5, "mods": {},
	},
	&"mat_stone_shard": {
		"kind": &"material", "rarity": &"common", "floor": 1,
		"name": "Lasca de Pedra", "desc": "Pedra viva da torre. Material do andar 1.", "base_price": 4, "mods": {},
	},
	&"mat_sentinel_eye": {
		"kind": &"material", "rarity": &"common", "floor": 2,
		"name": "Olho de Sentinela", "desc": "Ainda brilha. Material do andar 2.", "base_price": 9, "mods": {},
	},
	&"mat_beetle_shell": {
		"kind": &"material", "rarity": &"common", "floor": 2,
		"name": "Carapaça de Besouro", "desc": "Dura e leve. Material do andar 2.", "base_price": 7, "mods": {},
	},
	&"mat_beetle_horn": {
		"kind": &"material", "rarity": &"common", "floor": 2,
		"name": "Chifre de Besouro", "desc": "Ponta afiada. Material do andar 2.", "base_price": 8, "mods": {},
	},
	&"mat_obsidian": {
		"kind": &"material", "rarity": &"common", "floor": 3,
		"name": "Obsidiana", "desc": "Vidro negro e cortante. Material do andar 3.", "base_price": 12, "mods": {},
	},
	&"mat_ember_dust": {
		"kind": &"material", "rarity": &"common", "floor": 3,
		"name": "Pó de Brasa", "desc": "Ainda quente. Material do andar 3.", "base_price": 11, "mods": {},
	},
	&"mat_specter_cloth": {
		"kind": &"material", "rarity": &"common", "floor": 3,
		"name": "Essência Espectral", "desc": "Um retalho de fantasma. Material do andar 3.", "base_price": 13, "mods": {},
	},
	&"mat_tower_crystal": {
		"kind": &"material", "rarity": &"epic", "floor": 0,
		"name": "Cristal da Torre", "desc": "Raro. Só os chefes deixam cair.", "base_price": 20, "mods": {},
	},
	# Outfits: visual only, unlocked for good.
	&"outfit_starter": {
		"kind": &"outfit", "rarity": &"common", "unlock": &"start",
		"name": "Roupa de Escalador", "desc": "A roupa de quem começa a subir.", "base_price": 0, "mods": {},
	},
	&"outfit_casaco_longo": {
		"kind": &"outfit", "rarity": &"rare", "unlock": &"market",
		"name": "Casaco Longo Escuro", "desc": "Um casaco preto até os pés.", "base_price": 80, "mods": {},
	},
	&"outfit_cavaleiro_leve": {
		"kind": &"outfit", "rarity": &"rare", "unlock": &"boss",
		"name": "Armadura Leve de Cavaleiro", "desc": "Prata e azul. Prêmio do primeiro chefe.", "base_price": 80, "mods": {},
	},
	&"outfit_tunica_ferreiro": {
		"kind": &"outfit", "rarity": &"common", "unlock": &"market",
		"name": "Túnica de Ferreiro", "desc": "Avental de couro e mangas arregaçadas.", "base_price": 60, "mods": {},
	},
	&"outfit_manto_mago": {
		"kind": &"outfit", "rarity": &"epic", "unlock": &"chest",
		"name": "Manto de Mago", "desc": "Manto com estrelas bordadas. Achado em baús.", "base_price": 50, "mods": {},
	},
}
