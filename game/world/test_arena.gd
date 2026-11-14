extends Node2D
## Empty test room. `--autopilot` (user arg) drives the player through every
## state so screenshots can capture them. Debug only.

@onready var player: Player = $Player

var _label: Label
var _dummy_health: Health
var _dummy_rect: ColorRect
var _time: float = 0.0
var _autopilot: bool = false
var _fired: Dictionary = {}
var _enemies: Array[EnemyBase] = []

const ENEMY_SCENES := {
	"crawler": preload("res://actors/enemies/crawler.tscn"),
	"shooter": preload("res://actors/enemies/shooter.tscn"),
	"charger": preload("res://actors/enemies/charger.tscn"),
}
const ENEMY_POS := {
	"crawler": Vector2(345, 195),
	"shooter": Vector2(390, 60),
	"charger": Vector2(375, 135),
}


func _ready() -> void:
	_autopilot = "--autopilot" in OS.get_cmdline_user_args()
	var wanted := _enemy_arg()
	if wanted.is_empty():
		_make_dummy(Vector2(273, 135))
	else:
		for kind in wanted:
			_spawn_enemy(kind)
	_label = Label.new()
	_label.position = Vector2(20, 18)
	_label.add_theme_font_size_override("font_size", 8)
	add_child(_label)
	player.exit_blocked.connect(func() -> void: print("exit_blocked"))
	player.exited.connect(func() -> void: print("exited"))


## `--enemies` spawns all three, `--enemies=charger,shooter` a subset.
func _enemy_arg() -> Array[String]:
	var out: Array[String] = []
	for a in OS.get_cmdline_user_args():
		if a == "--enemies":
			out.assign(ENEMY_SCENES.keys())
		elif a.begins_with("--enemies="):
			out.assign(Array(a.substr(10).split(",")))
	return out


func _spawn_enemy(kind: String) -> void:
	var e := (ENEMY_SCENES[kind] as PackedScene).instantiate() as EnemyBase
	e.position = ENEMY_POS[kind]
	add_child(e)
	_enemies.append(e)


func _make_dummy(pos: Vector2) -> void:
	var node := Node2D.new()
	node.position = pos
	add_child(node)
	_dummy_rect = ColorRect.new()
	_dummy_rect.size = Vector2(18, 24)
	_dummy_rect.position = Vector2(-9, -12)
	_dummy_rect.color = Color(0.7, 0.2, 0.2)
	node.add_child(_dummy_rect)
	_dummy_health = Health.new()
	_dummy_health.max_hp = 1000
	_dummy_health.hp = 1000
	node.add_child(_dummy_health)
	var hb := Hurtbox.new()
	hb.team = &"enemy"
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(18, 24)
	cs.shape = rs
	hb.add_child(cs)
	node.add_child(hb)
	hb.hit.connect(func(h: Hitbox) -> void:
		_dummy_health.damage(h.damage, h.global_position)
		_dummy_rect.color = Color.WHITE
		get_tree().create_timer(0.08).timeout.connect(func() -> void: _dummy_rect.color = Color(0.7, 0.2, 0.2)))


func _physics_process(delta: float) -> void:
	_time += delta
	if _autopilot and _enemies.is_empty():
		_run_autopilot()
	elif _autopilot:
		_run_fight()


func _process(_delta: float) -> void:
	var alive := 0
	for e in _enemies:
		if is_instance_valid(e) and not e.dead:
			alive += 1
	_label.text = "HP %d/%d  dummy %d  foes %d  gold %d  state %s  t %.1f p %s" % [
		player.health.hp, player.health.max_hp, _dummy_health.hp if _dummy_health != null else 0, alive, Game.run.gold,
		Player.State.keys()[player.state], _time, player.position.round()]


## Timeline (seconds): idle, walk right, walk down, walk up, damage, walk
## right, combo x3 toward the dummy, roll, idle until healing starts.
const HOLDS := {
	&"move_right": [[0.8, 1.3], [2.2, 2.4]],
	&"move_down": [[1.6, 2.0]],
	&"move_up": [[2.0, 2.2]],
}


func _run_autopilot() -> void:
	for action: StringName in HOLDS:
		var on := false
		for w: Array in HOLDS[action]:
			on = on or (_time >= float(w[0]) and _time < float(w[1]))
		if on and not Input.is_action_pressed(action):
			Input.action_press(action)
		elif not on and Input.is_action_pressed(action):
			Input.action_release(action)
	_once("hurt", 2.2, func() -> void: player.health.damage(40, player.global_position))
	_tap(&"attack", 2.8)
	_tap(&"attack", 3.15)
	_tap(&"attack", 3.5)
	_tap(&"roll", 4.3)


## Fight mode: walk at the nearest living enemy and swing when close.
func _run_fight() -> void:
	var target: EnemyBase = null
	for e in _enemies:
		if is_instance_valid(e) and not e.dead:
			if target == null or e.position.distance_to(player.position) < target.position.distance_to(player.position):
				target = e
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
	if target == null:
		return
	var to := target.position - player.position
	if to.length() > 27.0:
		if absf(to.x) > 6.0:
			Input.action_press(&"move_right" if to.x > 0.0 else &"move_left")
		if absf(to.y) > 6.0:
			Input.action_press(&"move_down" if to.y > 0.0 else &"move_up")
	else:
		_tap(&"attack", snappedf(_time, 0.35))


func _tap(action: StringName, at: float) -> void:
	var key := "%s%.2f" % [action, at]
	if _time >= at and not _fired.has(key):
		_fired[key] = true
		Input.action_press(action)
		get_tree().create_timer(0.05).timeout.connect(func() -> void: Input.action_release(action))


func _once(key: String, at: float, fn: Callable) -> void:
	if _time >= at and not _fired.has(key):
		_fired[key] = true
		fn.call()
