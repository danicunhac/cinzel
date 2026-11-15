class_name Breakable
extends StaticBody2D
## A pot or small crate along a wall (placed by build_rooms.gd through
## DecorLayout.breakable_spots). One player hit smashes it: cracked frame,
## then the flat debris that stays on the floor, shards, a thud and sometimes
## a few coins or, rarely, a common material of the floor.
## Art: res://assets/rooms/breakables.png, 3 columns (intact, cracked,
## broken) x 2 rows (KINDS order) of 24x24, bottom-centred.

signal broke

const KINDS: Array[StringName] = [&"pot", &"crate"]
const GoldScene := preload("res://world/pickup_gold.tscn")
const PickupScene := preload("res://world/pickup_item.tscn")
## Seconds the cracked frame shows before the debris.
const CRACK_TIME := 0.07
const COINS := Vector2i(1, 3)
const DROP_SPREAD := 10.0
## Debris draws under every actor.
const DEBRIS_Z := -2

@export var kind: StringName = &"pot"
@export_range(0.0, 1.0) var gold_chance: float = 0.35
@export_range(0.0, 1.0) var material_chance: float = 0.06

var broken: bool = false

## Shared by every breakable so drops differ between props (tests seed it).
static var rng: RandomNumberGenerator = null

@onready var sprite: Sprite2D = $Sprite
@onready var shape: CollisionShape2D = $Shape
@onready var hurtbox: PropHurtbox = $Hurtbox


func _ready() -> void:
	sprite.frame = _row() * 3
	var shadow := GroundShadow.make(Vector2i(14 if kind == &"crate" else 12, 4), Vector2(0, -1), GroundShadow.COOL)
	shadow.name = "Shadow"
	add_child(shadow)
	move_child(shadow, 0)
	hurtbox.hit.connect(func(_h: Hitbox) -> void: smash())


func _row() -> int:
	return maxi(KINDS.find(kind), 0)


## Breaks the prop with its feedback; `drop` false for tests of the look.
func smash(drop: bool = true) -> void:
	if broken:
		return
	_set_broken()
	sprite.frame = _row() * 3 + 1
	var tw := create_tween()
	tw.tween_interval(CRACK_TIME)
	tw.tween_callback(func() -> void: sprite.frame = _row() * 3 + 2)
	Fx.flash(sprite, Fx.FLASH_WHITE, Fx.FLASH_TIME)
	Fx.burst(&"pot_shards" if kind == &"pot" else &"crate_splinters", global_position + Vector2(0, -6))
	Sfx.play(&"hit", 0.2)
	if drop:
		_drop.call_deferred()
	broke.emit()


## Debris at once, no feedback (a room visited again).
func show_broken() -> void:
	if broken:
		return
	_set_broken()
	sprite.frame = _row() * 3 + 2


func _set_broken() -> void:
	broken = true
	z_index = DEBRIS_Z
	shape.set_deferred("disabled", true)
	hurtbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	var shadow := get_node_or_null(^"Shadow") as CanvasItem
	if shadow != null:
		shadow.visible = false


## {"gold": coins, "material": item id or &""} for one smashed prop.
static func roll(r: RandomNumberGenerator, floor_num: int, p_gold: float, p_material: float) -> Dictionary:
	var out := {"gold": 0, "material": &""}
	if r.randf() < p_gold:
		out["gold"] = r.randi_range(COINS.x, COINS.y)
	if r.randf() < p_material:
		var mats: Array[StringName] = []
		var table: Dictionary = LootTable.ENEMY_MATERIALS.get(clampi(floor_num, 1, 3), {})
		for k: StringName in table:
			for m: StringName in table[k]:
				if not m in mats:
					mats.append(m)
		if not mats.is_empty():
			out["material"] = mats[r.randi_range(0, mats.size() - 1)]
	return out


func _drop() -> void:
	var parent := _drop_parent()
	if parent == null:
		return
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var loot := roll(rng, _tower_floor(), gold_chance, material_chance)
	var at := parent.to_local(global_position)
	for i in int(loot["gold"]):
		var g := GoldScene.instantiate() as PickupGold
		g.amount = 1
		g.position = at + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(4.0, DROP_SPREAD)
		parent.add_child(g)
	if loot["material"] != &"":
		var p := PickupScene.instantiate() as PickupItem
		p.item_id = loot["material"]
		p.qty = 1
		p.position = at + Vector2(0, 8)
		parent.add_child(p)


## The room (pickups are its children, so Room.snapshot keeps the items).
func _drop_parent() -> Node2D:
	var n := get_parent()
	while n != null and not n is Room:
		n = n.get_parent()
	return (n if n != null else get_parent()) as Node2D


## Floor of the tower (1 outside a Dungeon), like EnemyBase.tower_floor.
func _tower_floor() -> int:
	var n := get_parent()
	while n != null:
		var f: Variant = n.get(&"current_floor")
		if f is int:
			return f
		n = n.get_parent()
	return 1
