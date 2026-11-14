extends Node
## Scripted QA run through real input (Task P1). Plays floor 1 with the
## keyboard actions the player uses (move, attack, interact), pathing with an
## AStarGrid2D over whatever blocks a point query (walls, pillars, decor).
##   --mode=win: clear every room, open chests, beat the boss, take the
##     "Cidade" portal back to town.
##   --mode=die: stand in the first fight without attacking until death.
## Prints one "CHECK <name> PASS|FAIL <detail>" line per check and a summary.
## godot --headless --fixed-fps 60 --path game -s res://tools/run_node.gd -- --node=res://tools/qa_autopilot.gd --mode=win

const MOVES: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]
const TIME_LIMIT := 600.0

class ErrorCounter extends Logger:
	var errors: Array[String] = []
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_lock.lock()
		errors.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])
		_lock.unlock()


var mode := "win"
var _counter := ErrorCounter.new()
var _checks: Array[String] = []
var _fails: int = 0
var _attack_toggle: bool = false
var _healing: bool = false
var _rooms_seen: Dictionary = {}
var _music_seen: Array[StringName] = []
var _min_scale: float = 1.0
var _hits_seen: int = 0
var _gold_start: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.substr(7)
	OS.add_logger(_counter)
	_run.call_deferred()


func check(name: String, ok: bool, detail: String = "") -> void:
	var line := "CHECK %s %s %s" % [name, "PASS" if ok else "FAIL", detail]
	_checks.append(line)
	if not ok:
		_fails += 1
	print(line)


func _run() -> void:
	Game.new_run()
	Game.run.tutorial_done = true
	if mode == "win":
		# A returning player's kit (forged in town): a bot that cannot dodge
		# well loses the starter kit to the floor 1 boss too often.
		for id: StringName in [&"sword_knight", &"armor_chain", &"helm_iron"]:
			Game.run.inventory.add(id, 1)
			Game.run.equip(id)
		Game.run.hp = Game.run.stats().max_hp
	Dungeon.requested_floor = 1
	Game.goto(Dungeon.SCENE)
	await _frames(30)
	var d := get_tree().current_scene as Dungeon
	check("dungeon_loads", d != null)
	if d == null:
		_finish()
		return
	_gold_start = Game.run.gold
	if mode == "die":
		await _die(d)
	else:
		await _win(d)
	_finish()


func _finish() -> void:
	_release_all()
	check("time_scale_back_to_1", is_equal_approx(Engine.time_scale, 1.0), "time_scale %.2f" % Engine.time_scale)
	OS.remove_logger(_counter)
	check("no_engine_errors", _counter.errors.is_empty(), "; ".join(_counter.errors.slice(0, 5)))
	print("MUSIC ", _music_seen)
	print("SUMMARY mode=%s checks=%d fails=%d" % [mode, _checks.size(), _fails])
	get_tree().quit(1 if _fails > 0 else 0)


# --- win ---

func _win(d: Dungeon) -> void:
	var t0 := Time.get_ticks_msec()
	var boss_beaten := false
	while (Time.get_ticks_msec() - t0) / 1000.0 < TIME_LIMIT:
		await _wait_room_ready(d)
		if not is_instance_valid(d) or d.player.state == Player.State.DEAD:
			break
		var room := d.room
		_rooms_seen[d.room_index] = room.scene_file_path.get_file()
		_note_music()
		if room.is_boss:
			check("boss_music", Sfx.current_music() == &"boss", str(Sfx.current_music()))
		var ok := await _clear_room(d)
		if not ok:
			break
		# Stand still until healed, as a careful player would.
		_release_all()
		for i in 900:
			if d.player.health.hp >= d.player.health.max_hp:
				break
			await _frames(1)
		if room.chest != null and is_instance_valid(room.chest) and not room.chest.is_open:
			await _go_to(d, room.chest.global_position + Vector2(0, 16), 10.0)
			await _press(&"interact")
			await _frames(20)
			check("chest_opens_%d" % d.room_index, room.chest.is_open)
		if room.is_boss:
			boss_beaten = true
			await _frames(30)
			_note_music()
			check("tower_music_after_boss", Sfx.current_music() == &"tower", str(Sfx.current_music()))
			check("floor1_marked_beaten", Game.run.floors_beaten >= 1, "floors_beaten %d" % Game.run.floors_beaten)
			var portal: Node2D = null
			for n in room.get_children():
				if n is Portal and (n as Portal).text == "Cidade":
					portal = n
			check("portals_after_boss", portal != null)
			if portal == null:
				return
			await _go_to(d, portal.global_position, 15.0)
			await _frames(60)
			break
		var index := d.room_index
		var door := room.exit_door
		check("exit_opens_%d" % index, door != null and door.is_open)
		await _go_to(d, door.global_position, 20.0)
		for i in 120:
			if d.room_index != index:
				break
			await _frames(1)
		check("next_room_%d" % index, d.room_index == index + 1)
		if d.room_index == index:
			return
	check("boss_beaten", boss_beaten, "rooms %s" % _rooms_seen)
	var town := get_tree().current_scene
	check("back_in_town", town != null and town.scene_file_path == Dungeon.TOWN_SCENE, str(town))
	await _frames(40)
	_note_music()
	check("town_music", Sfx.current_music() == &"town", str(Sfx.current_music()))
	check("gold_earned", Game.run.gold > _gold_start, "gold %d" % Game.run.gold)
	check("hit_stop_seen", _min_scale < 1.0, "min time_scale %.2f" % _min_scale)
	check("damage_numbers_seen", _hits_seen > 0, "%d numbers" % _hits_seen)


## Fights until every enemy of the room is dead. False when the player died
## or time ran out.
func _clear_room(d: Dungeon) -> bool:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) < 120000:
		if d.player.state == Player.State.DEAD:
			check("player_survives_room_%d" % d.room_index, false)
			return false
		var alive := d.room.enemies.filter(func(e: Variant) -> bool: return is_instance_valid(e) and not (e as EnemyBase).dead)
		if alive.is_empty():
			break
		var p := d.player
		var target: EnemyBase = alive[0]
		for e: EnemyBase in alive:
			if e.global_position.distance_to(p.global_position) < target.global_position.distance_to(p.global_position):
				target = e
		var to := target.global_position - p.global_position
		if await _dodge(d, target, to):
			continue
		var reach := p.weapon.reach * (0.75 if not target.is_in_group(&"boss") else 1.2)
		# Low on life: keep away and stand still to heal (1.5 s idle).
		if p.health.hp < p.health.max_hp * 0.35:
			_healing = true
		elif p.health.hp > p.health.max_hp * 0.8:
			_healing = false
		if _healing:
			Input.action_release(&"attack")
			if to.length() < 70.0:
				_set_move(-to.normalized())
				await _frames(6)
			else:
				_release_moves()
				await _frames(10)
			continue
		if to.length() <= reach:
			_set_move(to.normalized())
			await _frames(1)
			_attack_toggle = not _attack_toggle
			if _attack_toggle:
				Input.action_press(&"attack")
			else:
				Input.action_release(&"attack")
			await _frames(1)
			_release_moves()
		else:
			_attack_toggle = false
			Input.action_release(&"attack")
			_set_move(_next_step(d, target.global_position))
			await _frames(2)
	_release_all()
	await _frames(10)
	var cleared := d.room.is_cleared
	if not cleared:
		for e in d.room.enemies:
			if is_instance_valid(e) and not e.dead:
				print("STUCK enemy %s at %s hp %d/%d; player at %s hp %d" % [e.name, e.global_position, e.health.hp, e.health.max_hp, d.player.global_position, d.player.health.hp])
	check("room_cleared_%d" % d.room_index, cleared)
	return cleared


## Rolls through a telegraphed attack or the boss ring. True when it rolled.
func _dodge(d: Dungeon, target: EnemyBase, to: Vector2) -> bool:
	var p := d.player
	if p._roll_cooldown > 0.0 or p.state != Player.State.FREE:
		return false
	var away := -to.normalized()
	if bool(target.get(&"_telegraph")) and to.length() < 56.0:
		await _roll(away.rotated(0.6))
		return true
	for n in target.get_children():
		var sw := n as Shockwave
		if sw == null or not sw.is_running():
			continue
		var dist := (p.global_position + Vector2(0, 6)).distance_to(sw.global_position)
		if not sw.warning and dist > sw.radius and dist - sw.radius < 26.0:
			await _roll(away)
			return true
	return false


func _roll(dir: Vector2) -> void:
	_set_move(dir)
	await _frames(1)
	await _press(&"roll")
	await _frames(14)
	_release_moves()


# --- die ---

func _die(d: Dungeon) -> void:
	await _wait_room_ready(d)
	_note_music()
	var t0 := Time.get_ticks_msec()
	# Walk into the nearest enemy and never attack.
	while d.player.state != Player.State.DEAD and (Time.get_ticks_msec() - t0) < 180000:
		var alive := d.room.enemies.filter(func(e: Variant) -> bool: return is_instance_valid(e) and not (e as EnemyBase).dead)
		if alive.is_empty():
			break
		_set_move(_next_step(d, (alive[0] as EnemyBase).global_position))
		await _frames(3)
	_release_all()
	check("player_died", d.player.state == Player.State.DEAD)
	for i in 300:
		await _frames(1)
		var s := get_tree().current_scene
		if s != null and s.scene_file_path == Dungeon.GAME_OVER_SCENE:
			break
	var scene := get_tree().current_scene
	check("game_over_screen", scene != null and scene.scene_file_path == Dungeon.GAME_OVER_SCENE, str(scene))
	check("music_stops_on_death", Sfx.current_music() == &"", str(Sfx.current_music()))
	check("run_reset_after_death", Game.run.gold == 0 and not Game.run.tutorial_done)
	check("hurt_flash_and_shake_ran", _min_scale <= 1.0)


# --- movement ---

func _go_to(d: Dungeon, target: Vector2, seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		if not is_instance_valid(d) or not d.is_inside_tree() or d.room == null or d._busy:
			break
		if d.player.global_position.distance_to(target) < 6.0:
			break
		_set_move(_next_step(d, target))
		await _frames(2)
	_release_moves()


## Direction toward the next cell of an A* path to `target` (blocked cells
## from point queries: walls, pillars, crates, solid decor).
func _next_step(d: Dungeon, target: Vector2) -> Vector2:
	# The body circle sits 6 px below the player's origin.
	var p := d.player.global_position + Vector2(0, 6)
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, 30, 17)
	grid.cell_size = Vector2(16, 16)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var space := d.get_world_2d().direct_space_state
	for y in 17:
		for x in 30:
			var q := PhysicsPointQueryParameters2D.new()
			q.position = Vector2(x * 16 + 8, y * 16 + 8)
			for hit in space.intersect_point(q, 8):
				if not (hit["collider"] is CharacterBody2D):
					grid.set_point_solid(Vector2i(x, y))
					break
	var from := Vector2i((p / 16.0).floor())
	var to := Vector2i((target / 16.0).floor())
	grid.set_point_solid(from, false)
	grid.set_point_solid(to, false)
	var path := grid.get_id_path(from, to, true)
	if path.size() < 2:
		return (target - p).normalized()
	var next := Vector2(path[1] * 16) + Vector2(8, 8)
	if path.size() == 2:
		next = target
	return (next - p).normalized()


func _set_move(dir: Vector2) -> void:
	_release_moves()
	if dir.x < -0.2:
		Input.action_press(&"move_left", minf(-dir.x * 1.5, 1.0))
	elif dir.x > 0.2:
		Input.action_press(&"move_right", minf(dir.x * 1.5, 1.0))
	if dir.y < -0.2:
		Input.action_press(&"move_up", minf(-dir.y * 1.5, 1.0))
	elif dir.y > 0.2:
		Input.action_press(&"move_down", minf(dir.y * 1.5, 1.0))


func _release_moves() -> void:
	for m in MOVES:
		Input.action_release(m)


func _release_all() -> void:
	_release_moves()
	for a: StringName in [&"attack", &"interact", &"roll"]:
		Input.action_release(a)


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _wait_room_ready(d: Dungeon) -> void:
	for i in 600:
		if not is_instance_valid(d) or (not d._busy and d.room != null):
			break
		await _frames(1)
	await _frames(40)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		_min_scale = minf(_min_scale, Engine.time_scale)
		var world := Fx.get_node_or_null(^"World")
		if world != null:
			for c in world.get_children():
				if c is Label and not c.has_meta(&"qa_seen"):
					c.set_meta(&"qa_seen", true)
					_hits_seen += 1


func _note_music() -> void:
	var m := Sfx.current_music()
	if _music_seen.is_empty() or _music_seen[-1] != m:
		_music_seen.append(m)
