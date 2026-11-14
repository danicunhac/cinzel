class_name Dungeon
extends Node2D
## Runs one floor of the tower: builds the plan, chains rooms with a short
## fade, ticks the run clock while active (process_mode pausable, so pause and
## the swap panel stop it) and handles death, Q-exit and the boss portals.
## Debug: `--room=res://...tscn` loads only that room, `--chest` gives it a
## chest, `--cleared` kills its enemies at once, `--floor=N` picks the floor,
## `--player=x,y` moves the player after the room loads, `--boss-hp=N` drops
## the boss to N% of its HP, `--revisit` (with --room) shows the room as on a
## walk back: already cleared, chest opened, back door open.
##
## Walking back: a FloorState keeps each floor's plan and room saves for this
## tower visit (a new Dungeon, from town, starts fresh; death forgets it). The
## entry door leads to the previous room, the first room of each floor has
## stairs down to the previous floor's beaten boss room (to town from floor 1).

const SCENE := "res://world/dungeon.tscn"
const TOWN_SCENE := "res://world/town.tscn"
const GAME_OVER_SCENE := "res://ui/game_over.tscn"
const VICTORY_SCENE := "res://ui/victory.tscn"
const FADE_TIME := 0.2
const DEATH_DELAY := 1.0
const PortalScript := preload("res://world/portal.gd")
const StairsScene := preload("res://world/stairs.tscn")

## Where the player stands in the new room.
enum Arrival { ENTRY, EXIT }

## Floor the next Dungeon instance enters (the town sets it before goto).
static var requested_floor: int = 1

var current_floor: int = 1
## The current floor's plan and chest rooms (shared with its FloorRecord).
var plan: Array[String] = []
var chest_rooms: Array[int] = []
var room_index: int = -1
var room: Room = null
var state := FloorState.new()

## Floor of the loaded room (current_floor changes before the swap).
var _room_floor: int = 1

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
		# Arrival from the town crystal.
		Sfx.play(&"teleport", 0.0)
		enter_floor(int(_args.get("floor", str(requested_floor))))


func _process(delta: float) -> void:
	Game.run.clock.tick(delta)


## Starts `floor_num` at its first room (from town or a boss portal). A floor
## already visited in this tower visit keeps its plan and rooms.
func enter_floor(floor_num: int) -> void:
	current_floor = floor_num
	Game.run.clock.running = true
	var rec := state.get_floor(floor_num)
	if rec == null:
		rec = _build_floor(floor_num)
	_use_floor(rec)
	_go_to_room(0, room != null)


func _build_floor(floor_num: int) -> FloorState.FloorRecord:
	var with_tutorial := floor_num == 1 and not Game.run.tutorial_done
	var p := FloorPlan.build(floor_num, templates_for(floor_num), _rng, with_tutorial)
	var tutorial_count := FloorPlan.TUTORIAL_ROOMS.size() if with_tutorial else 0
	var random_count := p.size() - tutorial_count - 1
	var chests: Array[int] = []
	for i in FloorPlan.chest_rooms(random_count, _rng):
		chests.append(i + tutorial_count)
	return state.start_floor(floor_num, p, chests)


func _use_floor(rec: FloorState.FloorRecord) -> void:
	plan = rec.plan
	chest_rooms = rec.chest_rooms


## Stairs of a floor's first room: to town from floor 1, otherwise to the
## previous floor's boss room (beaten; built fresh if this visit skipped it).
func _on_stairs_used() -> void:
	if _busy or _leaving:
		return
	if current_floor <= 1:
		leave_to_town()
		return
	var below := current_floor - 1
	var rec := state.get_floor(below)
	if rec == null:
		rec = _build_floor(below)
		# Not visited this trip, but beaten earlier in the run: every room
		# starts cleared (nobody spawns next to the arriving player) and its
		# chests already looted, so a walk down is not a free-loot loop.
		for i in rec.rooms.size():
			rec.rooms[i].cleared = true
			if i in rec.chest_rooms:
				rec.rooms[i].chests_opened.append(0)
	# Standing on floor N means floor N-1's boss is beaten.
	rec.rooms[-1].cleared = true
	current_floor = below
	_use_floor(rec)
	_go_to_room(rec.plan.size() - 1, true)


func _on_back_reached() -> void:
	if _busy or _leaving or room_index <= 0:
		return
	_go_to_room(room_index - 1, true, Arrival.EXIT)


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
	current_floor = int(_args.get("floor", "1"))
	var p: Array[String] = [path]
	var chests: Array[int] = []
	if _args.has("chest"):
		chests.append(0)
	var rec := state.start_floor(current_floor, p, chests)
	if _args.has("revisit"):
		rec.rooms[0].cleared = true
		rec.rooms[0].chests_opened.append(0)
	_use_floor(rec)
	_go_to_room(0, false)


func _go_to_room(index: int, with_fade: bool, arrival: Arrival = Arrival.ENTRY) -> void:
	_busy = true
	player.set_physics_process(false)
	if with_fade:
		await _fade_to(1.0)
	if room != null:
		_collect_leftover_gold(room)
		var old := state.room(_room_floor, room_index)
		if old != null:
			room.snapshot(old)
		rooms.remove_child(room)
		room.queue_free()
	room_index = index
	_room_floor = current_floor
	state.get_floor(current_floor).index = index
	room = (load(plan[index]) as PackedScene).instantiate() as Room
	rooms.add_child(room)
	player.global_position = room.entry.global_position
	if arrival == Arrival.EXIT and room.exit_door != null:
		player.global_position = room.exit_door.arrival()
	player.velocity = Vector2.ZERO
	player.reset_room_blocks()
	room.exit_reached.connect(_on_exit_reached)
	room.back_reached.connect(_on_back_reached)
	room.cleared.connect(_on_room_cleared)
	if index == 0:
		_add_stairs()
	var extra := Difficulty.extra_enemies(Game.run.clock.level())
	var has_back := index > 0 or _args.has("revisit")
	room.start(extra, index in chest_rooms, _rng, state.room(current_floor, index), has_back)
	Game.in_boss_room = room.is_boss and not room.is_cleared
	Sfx.music(&"boss" if Game.in_boss_room else &"tower")
	if _args.has("cleared"):
		for e in room.enemies:
			e.health.damage(1 << 20, e.global_position)
	if _args.has("boss-hp"):
		for e in room.enemies:
			if e.is_in_group(&"boss"):
				var target := e.health.max_hp * int(_args["boss-hp"]) / 100
				e.health.damage(e.health.hp - target, e.global_position)
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
		Game.run.tutorial_done = true
	_go_to_room(room_index + 1, true)


## First room of a floor: stairs down on the StairsSpot marker.
func _add_stairs() -> void:
	var spot := room.get_node_or_null(^"StairsSpot") as Marker2D
	if spot == null:
		return
	var st := StairsScene.instantiate() as Stairs
	st.position = spot.position
	st.label = "E: voltar à cidade" if current_floor <= 1 else "E: descer ao andar %d" % (current_floor - 1)
	st.used.connect(_on_stairs_used)
	room.add_child(st)


func _on_room_cleared() -> void:
	var save := state.room(current_floor, room_index)
	if save != null:
		save.cleared = true
	if not room.is_boss:
		return
	Game.in_boss_room = false
	Sfx.music(&"tower")
	# A boss room revisited on a walk back: boss already beaten, portals only.
	if not room.restored:
		Game.run.beat_floor(current_floor)
	if current_floor >= RunState.MAX_FLOOR:
		if not room.restored:
			_win()
		return
	# Low in the room, away from where the boss (and its gold) usually falls.
	var base := Vector2(240, 208)
	_add_portal(base + Vector2(-72, 0), "Cidade", Color(1.0, 0.75, 0.45), leave_to_town)
	_add_portal(base + Vector2(72, 0), "Andar %d" % (current_floor + 1), Color(0.5, 0.85, 1.0), _next_floor)


func _add_portal(pos: Vector2, label: String, color: Color, on_used: Callable) -> void:
	var p := PortalScript.new() as Portal
	p.position = pos
	p.text = label
	p.color = color
	p.used.connect(on_used)
	# Deferred: the boss dies inside a physics callback, where a new area
	# cannot join the space.
	room.add_child.call_deferred(p)


func _next_floor() -> void:
	var next := current_floor + 1
	if not state.has_floor(next) and templates_for(next).is_empty():
		_show_notice("O andar %d ainda não foi construído." % next)
		return
	enter_floor(next)


func _win() -> void:
	_leaving = true
	Game.run.clock.running = false
	_snapshot_run()
	Game.goto(VICTORY_SCENE if ResourceLoader.exists(VICTORY_SCENE) else TOWN_SCENE)


func _on_player_died() -> void:
	if _leaving:
		return
	_leaving = true
	Game.run.clock.running = false
	Sfx.music(&"")
	state.reset()
	await get_tree().create_timer(DEATH_DELAY).timeout
	_snapshot_run()
	Game.run.die()
	Game.in_boss_room = false
	Game.goto(GAME_OVER_SCENE if ResourceLoader.exists(GAME_OVER_SCENE) else TOWN_SCENE)


## Saved before die() zeroes the run, for the game-over and victory screens.
func _snapshot_run() -> void:
	Game.last_run = {"floor": current_floor, "seconds": Game.run.clock.seconds, "gold": Game.run.gold}


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
