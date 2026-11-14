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


func _ready() -> void:
	_autopilot = "--autopilot" in OS.get_cmdline_user_args()
	_make_dummy(Vector2(182, 90))
	_label = Label.new()
	_label.position = Vector2(20, 18)
	_label.add_theme_font_size_override("font_size", 8)
	add_child(_label)
	player.exit_blocked.connect(func() -> void: print("exit_blocked"))
	player.exited.connect(func() -> void: print("exited"))


func _make_dummy(pos: Vector2) -> void:
	var node := Node2D.new()
	node.position = pos
	add_child(node)
	_dummy_rect = ColorRect.new()
	_dummy_rect.size = Vector2(12, 16)
	_dummy_rect.position = Vector2(-6, -8)
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
	rs.size = Vector2(12, 16)
	cs.shape = rs
	hb.add_child(cs)
	node.add_child(hb)
	hb.hit.connect(func(h: Hitbox) -> void:
		_dummy_health.damage(h.damage, h.global_position)
		_dummy_rect.color = Color.WHITE
		get_tree().create_timer(0.08).timeout.connect(func() -> void: _dummy_rect.color = Color(0.7, 0.2, 0.2)))


func _physics_process(delta: float) -> void:
	_time += delta
	if _autopilot:
		_run_autopilot()


func _process(_delta: float) -> void:
	_label.text = "HP %d/%d  dummy %d  state %s  t %.1f p %s" % [
		player.health.hp, player.health.max_hp, _dummy_health.hp,
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
