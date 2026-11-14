class_name Dungeon
extends Node2D
## Runs one floor of the tower: builds the plan, chains rooms with a short
## fade, ticks the run clock while active (process_mode pausable, so pause and
## the swap panel stop it) and handles death, Q-exit and the boss portals.
## Debug: `--room=res://...tscn` loads only that room, `--chest` gives it a
## chest, `--cleared` kills its enemies at once, `--floor=N` picks the floor,
## `--player=x,y` moves the player after the room loads.

const SCENE := "res://world/dungeon.tscn"
const TOWN_SCENE := "res://world/town.tscn"
const GAME_OVER_SCENE := "res://ui/game_over.tscn"
const VICTORY_SCENE := "res://ui/victory.tscn"
const FADE_TIME := 0.2
const DEATH_DELAY := 1.0
const PortalScript := preload("res://world/portal.gd")

## Floor the next Dungeon instance enters (the town sets it before goto).
static var requested_floor: int = 1
## The tutorial plays on floor 1 until it is finished once in this session.
static var tutorial_done: bool = false

var current_floor: int = 1
var plan: Array[String] = []
var chest_rooms: Array[int] = []
var room_index: int = -1
var room: Room = null

var _rng := RandomNumberGenerator.new()
var _busy: bool = false
var _leaving: bool = false
var _args: Dictionary = {}

@onready var rooms: Node2D = $Rooms
@onready var player: Player = $Player
@onready var fade: ColorRect = $Overlay/Fade
@onready var notice: Label = $Overlay/Notice


func _ready() -> void:
	Game.run.clock.running = true
	_rng.randomize()
	_args = _parse_args()
	player.died.connect(_on_player_died)
	player.exited.connect(leave_to_town)
	notice.visible = false
	if _args.has("room"):
		_enter_single(String(_args["room"]))
	else:
		enter_floor(int(_args.get("floor", str(requested_floor))))


func _process(delta: float) -> void:
	Game.run.clock.tick(delta)


func enter_floor(floor_num: int) -> void:
	current_floor = floor_num
	Game.run.clock.running = true
	var with_tutorial := floor_num == 1 and not tutorial_done
	plan = FloorPlan.build(floor_num, templates_for(floor_num), _rng, with_tutorial)
	var tutorial_count := FloorPlan.TUTORIAL_ROOMS.size() if with_tutorial else 0
	var random_count := plan.size() - tutorial_count - 1
	chest_rooms.clear()
	for i in FloorPlan.chest_rooms(random_count, _rng):
		chest_rooms.append(i + tutorial_count)
	_go_to_room(0, room != null)


func leave_to_town() -> void:
	if _leaving:
		return
	_leaving = true
	Game.run.clock.running = false
	Game.in_boss_room = false
	Game.goto(TOWN_SCENE)


static func templates_for(floor_num: int) -> Array[String]:
	var dir := "res://world/rooms/f%d" % floor_num
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in ResourceLoader.list_directory(dir):
		if f.ends_with(".tscn"):
			out.append("%s/%s" % [dir, f])
	out.sort()
	return out


func _enter_single(path: String) -> void:
	plan.assign([path])
	chest_rooms.clear()
	if _args.has("chest"):
		chest_rooms.append(0)
	_go_to_room(0, false)


func _go_to_room(index: int, with_fade: bool) -> void:
	_busy = true
	player.set_physics_process(false)
	if with_fade:
		await _fade_to(1.0)
	if room != null:
		_collect_leftover_gold(room)
		rooms.remove_child(room)
		room.queue_free()
	room_index = index
	room = (load(plan[index]) as PackedScene).instantiate() as Room
	rooms.add_child(room)
	player.global_position = room.entry.global_position
	player.velocity = Vector2.ZERO
	player.reset_room_blocks()
	Game.in_boss_room = room.is_boss
	room.exit_reached.connect(_on_exit_reached)
	room.cleared.connect(_on_room_cleared)
	var extra := Difficulty.extra_enemies(Game.run.clock.level())
	room.start(extra, index in chest_rooms, _rng)
	if _args.has("cleared"):
		for e in room.enemies:
			e.health.damage(1 << 20, e.global_position)
	if _args.has("player"):
		var xy := String(_args["player"]).split(",")
		player.global_position = Vector2(float(xy[0]), float(xy[1]))
	fade.color.a = 1.0 if with_fade else 0.0
	await _fade_to(0.0)
	if player.state != Player.State.DEAD:
		player.set_physics_process(true)
	_busy = false


func _fade_to(alpha: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", alpha, FADE_TIME)
	await tw.finished


func _collect_leftover_gold(r: Room) -> void:
	for n in r.get_children():
		if n is PickupGold:
			(n as PickupGold).collect()


func _on_exit_reached() -> void:
	if _busy or _leaving or room_index + 1 >= plan.size():
		return
	if plan[room_index] == FloorPlan.TUTORIAL_ROOMS[-1]:
		tutorial_done = true
	_go_to_room(room_index + 1, true)


func _on_room_cleared() -> void:
	if not room.is_boss:
		return
	Game.in_boss_room = false
	Game.run.unlock_floor(current_floor + 1)
	if current_floor >= RunState.MAX_FLOOR:
		_win()
		return
	# Low in the room, away from where the boss (and its gold) usually falls.
	var base := Vector2(160, 136)
	_add_portal(base + Vector2(-48, 0), "Cidade", Color(1.0, 0.75, 0.45), leave_to_town)
	_add_portal(base + Vector2(48, 0), "Andar %d" % (current_floor + 1), Color(0.5, 0.85, 1.0), _next_floor)


func _add_portal(pos: Vector2, label: String, color: Color, on_used: Callable) -> void:
	var p := PortalScript.new() as Portal
	p.position = pos
	p.text = label
	p.color = color
	p.used.connect(on_used)
	room.add_child(p)


func _next_floor() -> void:
	var next := current_floor + 1
	if templates_for(next).is_empty():
		_show_notice("O andar %d ainda não foi construído." % next)
		return
	enter_floor(next)


func _win() -> void:
	_leaving = true
	Game.run.clock.running = false
	Game.goto(VICTORY_SCENE if ResourceLoader.exists(VICTORY_SCENE) else TOWN_SCENE)


func _on_player_died() -> void:
	if _leaving:
		return
	_leaving = true
	Game.run.clock.running = false
	await get_tree().create_timer(DEATH_DELAY).timeout
	Game.run.die()
	Game.in_boss_room = false
	Game.goto(GAME_OVER_SCENE if ResourceLoader.exists(GAME_OVER_SCENE) else TOWN_SCENE)


func _show_notice(text: String) -> void:
	notice.text = text
	notice.visible = true
	get_tree().create_timer(2.5).timeout.connect(func() -> void: notice.visible = false)


func _parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1] if kv.size() > 1 else ""
	return out
