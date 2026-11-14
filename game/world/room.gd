class_name Room
extends Node2D
## One room of the tower. `start` spawns the enemies on the Spawns markers
## (meta `enemy` = crawler | shooter | charger, optional meta `boss`), plus
## `extra` copies on random markers away from the entry. The Exit door stays
## locked until every enemy is dead, or, with heal_to_clear, until the
## player's HP is full.

signal cleared
signal exit_reached

const ENEMY_SCENES: Dictionary[String, PackedScene] = {
	"crawler": preload("res://actors/enemies/crawler.tscn"),
	"shooter": preload("res://actors/enemies/shooter.tscn"),
	"charger": preload("res://actors/enemies/charger.tscn"),
}
const ChestScene := preload("res://world/chest.tscn")
## Enemies fade in and stay still this long, so a room never opens with a hit.
const SPAWN_GRACE := 0.6
const EXTRA_MIN_DIST := 96.0
const BOSS_SCALE := 2.0
const BOSS_HP_MULT := 5

@export var is_boss: bool = false
@export var is_tutorial: bool = false
## Fraction of max HP the player is lowered to on entry (1.0 = untouched).
@export_range(0.0, 1.0) var start_hp_ratio: float = 1.0
@export var heal_to_clear: bool = false

var is_cleared: bool = false
var enemies: Array[EnemyBase] = []
var chest: Chest = null

var _alive: int = 0
var _has_chest: bool = false
var _started: bool = false

@onready var walls: TileMapLayer = $Walls
@onready var entry: Marker2D = $Entry
@onready var exit_door: RoomDoor = get_node_or_null(^"Exit") as RoomDoor
@onready var spawns: Node2D = $Spawns


func _ready() -> void:
	if exit_door != null:
		exit_door.entered.connect(func() -> void: exit_reached.emit())


func start(extra: int, has_chest: bool, rng: RandomNumberGenerator) -> void:
	if _started:
		return
	_started = true
	_has_chest = has_chest and has_node(^"ChestSpot")
	if start_hp_ratio < 1.0:
		_lower_player_hp()
	var markers: Array[Marker2D] = []
	for n in spawns.get_children():
		if n is Marker2D:
			markers.append(n as Marker2D)
	for m in markers:
		_spawn(String(m.get_meta(&"enemy", "crawler")), m.position, bool(m.get_meta(&"boss", false)))
	var far := markers.filter(func(m: Marker2D) -> bool: return m.position.distance_to(entry.position) >= EXTRA_MIN_DIST)
	if not is_tutorial and not is_boss and not far.is_empty():
		for i in extra:
			var m := far[rng.randi_range(0, far.size() - 1)] as Marker2D
			var jitter := Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-4.0, 4.0))
			_spawn(String(m.get_meta(&"enemy", "crawler")), m.position + jitter, false)
	if _alive == 0 and not heal_to_clear:
		_clear()


func _process(_delta: float) -> void:
	if not heal_to_clear or is_cleared or not _started:
		return
	var p := _player()
	if p != null and p.health.hp >= p.health.max_hp:
		_clear()


func _spawn(kind: String, pos: Vector2, boss: bool) -> void:
	if not ENEMY_SCENES.has(kind):
		push_error("Room: unknown enemy '%s'" % kind)
		return
	var e := ENEMY_SCENES[kind].instantiate() as EnemyBase
	e.position = pos
	add_child(e)
	if boss:
		e.scale = Vector2.ONE * BOSS_SCALE
		e.health.max_hp *= BOSS_HP_MULT
		e.health.hp = e.health.max_hp
	e.killed.connect(_on_enemy_killed)
	enemies.append(e)
	_alive += 1
	e.set_physics_process(false)
	e.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(e, "modulate:a", 1.0, SPAWN_GRACE)
	tw.tween_callback(func() -> void:
		if is_instance_valid(e) and not e.dead:
			e.set_physics_process(true))


func _on_enemy_killed() -> void:
	_alive -= 1
	if _alive <= 0:
		_clear()


func _clear() -> void:
	if is_cleared:
		return
	is_cleared = true
	if exit_door != null:
		exit_door.set_open(true)
	if _has_chest:
		chest = ChestScene.instantiate() as Chest
		chest.position = ($ChestSpot as Marker2D).position
		add_child(chest)
	cleared.emit()


func _lower_player_hp() -> void:
	var p := _player()
	if p == null:
		return
	var target := roundi(p.health.max_hp * start_hp_ratio)
	if p.health.hp > target:
		p.health.hp = target
		p.health.hp_changed.emit(target)


func _player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player
