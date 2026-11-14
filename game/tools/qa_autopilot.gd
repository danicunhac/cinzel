extends Node
## Scripted QA run through real input (Task P1, balance pass). Plays floor 1
## with the keyboard actions the player uses (move, attack, roll, interact),
## pathing with an AStarGrid2D over whatever blocks a point query (walls,
## pillars, decor). It plays like a decent player: rolls on red warnings
## (crawler and boss bites, charger dash lines, shooter shots, the boss ring),
## backs off to idle-heal when low and heals to full between rooms.
##   --mode=win: clear every room, open chests, pick up materials, beat the
##     boss, take the "Cidade" portal back to town.
##   --mode=die: stand in the first fight without attacking until death.
##   --kit=starter (default): sword_iron, no armor. --kit=forged: knight
##     sword, chain mail, iron helm (a returning player's kit).
##   --no-dodge: never rolls (the old bot), for comparison.
##   --skill=0.8: chance to react to each red warning (after a 0.15-0.35 s
##     reaction time); the rest land.
## Prints one "CHECK <name> PASS|FAIL <detail>" line per check, a RESULT line
## (outcome, clock at the boss, cause of death, damage taken by source,
## materials) and a summary.
## godot --headless --fixed-fps 60 --path game -s res://tools/run_node.gd -- --node=res://tools/qa_autopilot.gd --mode=win

const MOVES: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]
## Game-time limits in 60 fps frames (headless runs much faster than real time).
const RUN_FRAMES := 60 * 60 * 20
const ROOM_FRAMES := 60 * 240
const HEAL_FRAMES := 60 * 25
## Start backing off to heal under this fraction of max HP, fight again over
## the second one.
const LOW_HP := 0.35
const OK_HP := 0.75
## Gives up backing off to heal after this long (a crowded room).
const HEAL_TRY_FRAMES := 60 * 6
## Reaction time to a red warning (s), drawn per attack.
const REACT_MIN := 0.15
const REACT_MAX := 0.35

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
var kit := "starter"
var dodge := true
## Chance to react to a warning at all (a decent player misses some).
var skill := 0.8
var _rng := RandomNumberGenerator.new()
var _warnings: Dictionary[int, Array] = {}
var _counter := ErrorCounter.new()
var _checks: Array[String] = []
var _fails: int = 0
var _attack_toggle: bool = false
var _healing: bool = false
var _heal_from: int = 0
var _heal_retry_at: int = 0
var _rooms_seen: Dictionary = {}
var _music_seen: Array[StringName] = []
var _min_scale: float = 1.0
var _hits_seen: int = 0
var _gold_start: int = 0
var _frame: int = 0
# Balance numbers.
var _last_source: String = ""
var _taken: Dictionary[String, int] = {}
var _rolls: int = 0
var _boss_at: float = -1.0
var _boss_level: int = -1
var _boss_kill_at: float = -1.0
var _death_room: int = -1
var _outcome: String = "timeout"
var _mats_at_death: String = ""
var _pending: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.substr(7)
		elif a.begins_with("--kit="):
			kit = a.substr(6)
		elif a == "--no-dodge":
			dodge = false
		elif a.begins_with("--skill="):
			skill = float(a.substr(8))
	_rng.randomize()
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
	if kit == "forged":
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
	d.player.hurtbox.hit.connect(_on_player_hit)
	d.player.health.damaged.connect(_on_player_damaged.bind(d))
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
	if mode == "win":
		_print_result()
	print("SUMMARY mode=%s checks=%d fails=%d" % [mode, _checks.size(), _fails])
	Sfx.quit_clean(1 if _fails > 0 else 0)


func _print_result() -> void:
	var mats := _mats_text() if _outcome != "death" else _mats_at_death
	print("RESULT outcome=%s kit=%s dodge=%s skill=%.2f boss_at=%.0f boss_level=%d boss_kill_at=%.0f end_clock=%.0f death_room=%d cause=%s rolls=%d taken=%s %s gold=%d" % [
		_outcome, kit, dodge, skill, _boss_at, _boss_level, _boss_kill_at, Game.last_run.get("seconds", Game.run.clock.seconds) if _outcome == "death" else Game.run.clock.seconds,
		_death_room, _last_source if _outcome == "death" else "-", _rolls, _taken, mats, Game.run.gold])


## Materials in the backpack and the forge recipes they already pay for.
func _mats_text() -> String:
	var mats: Dictionary[String, int] = {}
	for s: Dictionary in Game.run.inventory.slots:
		if not s.is_empty() and ItemDB.kind(s["id"]) == &"material":
			mats[String(s["id"]).trim_prefix("mat_")] = mats.get(String(s["id"]).trim_prefix("mat_"), 0) + int(s["qty"])
	var craftable: Array[String] = []
	for r: StringName in Forge.unlocked(0):
		var need: Dictionary = Forge.RECIPES[r]["materials"]
		var ok := true
		for m: StringName in need:
			if Game.run.inventory.count(m) < int(need[m]):
				ok = false
		if ok:
			craftable.append(String(r))
	return "mats=%s recipes=%s" % [mats, craftable]


## The player's own hurt handler runs first (it connected first), so the
## damage it deals lands in _pending before this names the source.
func _on_player_hit(from: Hitbox) -> void:
	_last_source = _source_name(from)
	if _pending > 0:
		_taken[_last_source] = _taken.get(_last_source, 0) + _pending
		_pending = 0


func _on_player_damaged(n: int, d: Dungeon) -> void:
	_pending += n
	if d.player.health.hp <= 0:
		_outcome = "death"
		_death_room = d.room_index
		_mats_at_death = _mats_text()


func _source_name(from: Hitbox) -> String:
	if from is Shockwave:
		return "boss_ring"
	if from is Projectile:
		return "shooter"
	var owner_node := from.get_parent()
	if owner_node is BossBig:
		return "boss_dash" if (owner_node as BossBig).dashes else "boss_bite"
	if owner_node is Charger:
		return "charger"
	if owner_node is Crawler:
		return "crawler"
	return String(owner_node.name) if owner_node != null else "?"


# --- win ---

func _win(d: Dungeon) -> void:
	var boss_beaten := false
	while _frame < RUN_FRAMES:
		await _wait_room_ready(d)
		if not is_instance_valid(d) or d.player.state == Player.State.DEAD:
			break
		var room := d.room
		_rooms_seen[d.room_index] = room.scene_file_path.get_file()
		_note_music()
		if room.is_boss:
			_boss_at = Game.run.clock.seconds
			_boss_level = Game.run.clock.level()
			check("boss_music", Sfx.current_music() == &"boss", str(Sfx.current_music()))
		var ok := await _clear_room(d)
		if not ok:
			break
		if room.is_boss:
			_boss_kill_at = Game.run.clock.seconds
			boss_beaten = true
			_outcome = "win"
		await _pick_materials(d)
		# Stand still until healed, as a careful player would.
		_release_all()
		for i in HEAL_FRAMES:
			if _gone(d) or d.player.health.hp >= d.player.health.max_hp:
				break
			await _frames(1)
		if _gone(d):
			break
		# Walked through the open door (or a portal) while picking up loot.
		if d.room != room:
			continue
		if room.chest != null and is_instance_valid(room.chest) and not room.chest.is_open:
			await _go_to(d, room.chest.global_position + Vector2(0, 16), 10.0)
			await _press(&"interact")
			await _frames(20)
			check("chest_opens_%d" % d.room_index, room.chest.is_open)
		if room.is_boss:
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
	if not boss_beaten:
		return
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
	var f0 := _frame
	while _frame - f0 < ROOM_FRAMES:
		if _gone(d):
			check("player_survives_room_%d" % (d.room_index if is_instance_valid(d) else -1), false, "killed by %s" % _last_source)
			return false
		var alive := _alive(d)
		if alive.is_empty():
			break
		var p := d.player
		var target: EnemyBase = alive[0]
		for e: EnemyBase in alive:
			if e.global_position.distance_to(p.global_position) < target.global_position.distance_to(p.global_position):
				target = e
		var to := target.global_position - p.global_position
		if dodge and await _dodge(d, alive):
			continue
		var reach := p.weapon.reach * (0.75 if not target.is_in_group(&"boss") else 1.2)
		# Low on life: keep away and stand still to heal (1.5 s idle). When
		# the room never lets it stand still, it fights on for a while.
		if p.health.hp < p.health.max_hp * LOW_HP and not _healing and _frame >= _heal_retry_at:
			_healing = true
			_heal_from = _frame
		elif p.health.hp > p.health.max_hp * OK_HP:
			_healing = false
		elif _healing and _frame - _heal_from > HEAL_TRY_FRAMES and p.health.hp < p.health.max_hp * LOW_HP:
			_healing = false
			_heal_retry_at = _frame + HEAL_TRY_FRAMES
		if _healing and dodge:
			Input.action_release(&"attack")
			var near := _nearest_threat(d, alive)
			if near < 80.0:
				_set_move(_flee_dir(d, alive))
				await _frames(6)
			else:
				_release_moves()
				await _frames(6)
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
	if _gone(d):
		return false
	var cleared := d.room.is_cleared
	if not cleared and d.player.state != Player.State.DEAD:
		for e in d.room.enemies:
			if is_instance_valid(e) and not e.dead:
				var boss_state := ""
				if e is BossBig:
					var b := e as BossBig
					boss_state = " boss state %s t %.2f shock_cd %.2f ring %s" % [BossBig.State.keys()[b.state], b._t, b._shock_cd, b.shockwave.is_running()]
				print("STUCK enemy %s at %s hp %d/%d%s; player at %s hp %d state %d" % [e.name, e.global_position, e.health.hp, e.health.max_hp, boss_state, d.player.global_position, d.player.health.hp, d.player.state])
	check("room_cleared_%d" % d.room_index, cleared)
	return cleared


## The player died (the dungeon may already be gone).
func _gone(d: Variant) -> bool:
	return not is_instance_valid(d) or d.player.state == Player.State.DEAD


func _alive(d: Dungeon) -> Array:
	return d.room.enemies.filter(func(e: Variant) -> bool: return is_instance_valid(e) and not (e as EnemyBase).dead)


## Distance to the closest living enemy.
func _nearest_threat(d: Dungeon, alive: Array) -> float:
	var best := INF
	for e: EnemyBase in alive:
		best = minf(best, e.global_position.distance_to(d.player.global_position))
	return best


## Away from the enemies (weighted by closeness), bent along a wall when the
## straight way is blocked.
func _flee_dir(d: Dungeon, alive: Array) -> Vector2:
	var p := d.player.global_position
	var away := Vector2.ZERO
	for e: EnemyBase in alive:
		var v := p - e.global_position
		away += v.normalized() / maxf(v.length(), 8.0)
	away = away.normalized()
	if away == Vector2.ZERO:
		away = Vector2.DOWN
	for a: float in [0.0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8]:
		var dir := away.rotated(a)
		if _clear_line(d, p, p + dir * 24.0):
			return dir
	return away


func _clear_line(d: Dungeon, from: Vector2, to: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(from + Vector2(0, 6), to + Vector2(0, 6))
	q.collide_with_areas = false
	q.exclude = [d.player.get_rid()]
	var hit := d.get_world_2d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit["collider"] is CharacterBody2D


## Rolls through a telegraphed attack about to land: a crawler or boss bite,
## a charger or boss dash line, a shot on its way, the boss ring. True when
## it rolled. Like a person, it reacts to each warning only after a reaction
## time (REACT_MIN..REACT_MAX s) and misses some of them (1 - skill).
func _dodge(d: Dungeon, alive: Array) -> bool:
	var p := d.player
	if p._roll_cooldown > 0.0 or (p.state != Player.State.FREE and p.state != Player.State.ATTACK):
		return false
	var pp := p.global_position
	# Shots heading at the player.
	for n in d.room.get_children():
		var shot := n as Projectile
		if shot == null:
			continue
		var rel := pp + Vector2(0, -6) - shot.global_position
		var along := rel.dot(shot.direction)
		var side := absf(rel.cross(shot.direction))
		if along > 0.0 and along < 42.0 and side < 11.0 and _reacts(shot, 0, shot._age):
			await _roll(_perp(shot.direction, rel))
			return true
	for e: EnemyBase in alive:
		var to := e.global_position - pp
		if e is Charger:
			var c := e as Charger
			if c.state == Charger.State.WARN and c._t >= Charger.WARN_TIME - 0.15 and _reacts(c, c.state, c._t):
				var rel := pp - c.global_position
				if rel.dot(c._dir) > -8.0 and rel.dot(c._dir) < Charger.DASH_SPEED * Charger.DASH_TIME + 12.0 \
						and absf(rel.cross(c._dir)) < 16.0:
					await _roll(_perp(c._dir, rel))
					return true
		elif e is BossBig:
			var b := e as BossBig
			if b.state == BossBig.State.WINDUP:
				if b.dashes and b._t >= BossBig.DASH_WARN - 0.15 and _reacts(b, b.state, b._t):
					var rel := pp - b.global_position
					if absf(rel.cross(b._dir)) < 26.0 and rel.dot(b._dir) > -12.0:
						await _roll(_perp(b._dir, rel))
						return true
				elif not b.dashes and b._t >= BossBig.BITE_WINDUP - 0.15 and to.length() < 64.0 and _reacts(b, b.state, b._t):
					await _roll((-to).normalized().rotated(0.5))
					return true
			if await _dodge_ring(d, b):
				return true
		elif e is Crawler:
			var cr := e as Crawler
			if cr.state == Crawler.State.WINDUP and cr._t >= Crawler.WINDUP_TIME - 0.12 and to.length() < 40.0 \
					and _reacts(cr, cr.state, cr._t):
				await _roll((-to).normalized().rotated(0.6))
				return true
	return false


## Whether the bot has noticed this warning yet: one reaction time and one
## miss roll per attack (a new `state` entry of `who` is a new attack), and
## `t` seconds of it seen so far.
func _reacts(who: Object, state: int, t: float) -> bool:
	var id := who.get_instance_id()
	var seen: Array = _warnings.get(id, [])
	if seen.is_empty() or int(seen[0]) != state or t < float(seen[3]):
		seen = [state, _rng.randf_range(REACT_MIN, REACT_MAX), _rng.randf() > skill, t]
		_warnings[id] = seen
	seen[3] = t
	return not bool(seen[2]) and t >= float(seen[1])


## The boss ring: walk out of it during the warning; when that fails, roll
## inward through the band just before it reaches the player.
func _dodge_ring(d: Dungeon, b: BossBig) -> bool:
	var sw := b.shockwave
	if sw == null or not sw.is_running():
		return false
	if not _reacts(sw, 0, sw._t):
		return false
	var hb := d.player.hurtbox.global_position
	var dist := hb.distance_to(sw.global_position)
	if sw.warning:
		if dist < sw.max_radius + Shockwave.BAND + 6.0:
			var out := (hb - sw.global_position).normalized()
			var dir := out
			for a: float in [0.0, 0.5, -0.5, 1.0, -1.0]:
				if _clear_line(d, d.player.global_position, d.player.global_position + out.rotated(a) * 24.0):
					dir = out.rotated(a)
					break
			_set_move(dir)
			await _frames(3)
			return true
		return false
	var gap := dist - sw.radius
	# The ring moves ~5 px a frame and the roll starts 2-3 frames after the
	# decision: leave room for that.
	if gap > -Shockwave.BAND and gap < 55.0:
		await _roll((sw.global_position - hb).normalized())
		return true
	return false


## Perpendicular to `dir`, on the side the player already is (`rel` is the
## player relative to the attack).
func _perp(dir: Vector2, rel: Vector2) -> Vector2:
	var n := dir.orthogonal()
	return n if rel.dot(n) >= 0.0 else -n


func _roll(dir: Vector2) -> void:
	_rolls += 1
	Input.action_release(&"attack")
	_set_move(dir)
	await _frames(1)
	await _press(&"roll")
	await _frames(14)
	_release_moves()


## Walks over the material drops of the room (they are taken on touch).
func _pick_materials(d: Dungeon) -> void:
	await _frames(20)
	for i in 12:
		if _gone(d):
			return
		var best: PickupItem = null
		for n in d.room.get_children():
			var it := n as PickupItem
			if it == null or it.is_queued_for_deletion() or not it.is_material() or it.qty <= 0:
				continue
			if best == null or it.global_position.distance_to(d.player.global_position) < best.global_position.distance_to(d.player.global_position):
				best = it
		if best == null:
			return
		await _go_to(d, best.global_position, 6.0)
		await _frames(10)
		if is_instance_valid(best) and not best.is_queued_for_deletion() and best.qty > 0:
			# Backpack full of it: leave it.
			return


# --- die ---

func _die(d: Dungeon) -> void:
	await _wait_room_ready(d)
	_note_music()
	var f0 := _frame
	# Walk into the nearest enemy and never attack.
	while d.player.state != Player.State.DEAD and _frame - f0 < 60 * 180:
		var alive := _alive(d)
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
	var f0 := _frame
	while _frame - f0 < seconds * 60.0:
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
		_frame += 1
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
