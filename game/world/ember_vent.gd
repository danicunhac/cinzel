class_name EmberVent
extends Hitbox
## Floor 3 hazard: a grate in the floor that cycles IDLE -> WARN (glows red
## for WARN_TIME) -> BURN (a flame that hurts the player for BURN_TIME).
## Only runs while its room still has enemies; a cleared room goes quiet.
## Damage scales with the run clock like an enemy hit. `phase` (s) shifts the
## cycle so the vents of a room do not all burst together.

enum State { IDLE, WARN, BURN }

const IDLE_TIME := 2.4
const WARN_TIME := 0.8
const BURN_TIME := 0.6
const BASE_DAMAGE := 10
const RADIUS := 9.0
## Cycle offset between the vents of one room (build_rooms.gd).
const STAGGER := 0.9
const GRATE := Color(0.12, 0.09, 0.09)
const GRATE_EDGE := Color(0.35, 0.2, 0.15)
const EMBER := Color(1.0, 0.45, 0.15)
const WARN_RED := Color(1.0, 0.15, 0.1)
const FLAME := Color(1.0, 0.75, 0.3)

@export var phase: float = 0.0

var state: State = State.IDLE
## Seconds spent in the current state.
var t: float = 0.0


func _ready() -> void:
	team = &"enemy"
	z_index = -3
	var level := Game.run.clock.level() if Game.run != null else 0
	damage = roundi(BASE_DAMAGE * Difficulty.enemy_dmg_mult(level) * Difficulty.floor_dmg_mult(3))
	set_active(false)
	# Every vent starts idle, at its own point of the idle wait, so a room
	# never opens with a burst and the vents fire one after another.
	t = fmod(phase, IDLE_TIME)


## False once the room is cleared (or before it starts): the vent rests.
func live() -> bool:
	var room := owner as Room
	if room == null:
		return true
	return not room.is_cleared and not room.enemies.is_empty()


func _physics_process(delta: float) -> void:
	if not live():
		if state != State.IDLE:
			_enter(State.IDLE)
		queue_redraw()
		return
	t += delta
	match state:
		State.IDLE:
			if t >= IDLE_TIME:
				_enter(State.WARN)
		State.WARN:
			if t >= WARN_TIME:
				_enter(State.BURN)
		State.BURN:
			if t >= BURN_TIME:
				_enter(State.IDLE)
	queue_redraw()


func _enter(s: State) -> void:
	state = s
	t = 0.0
	set_active(s == State.BURN)
	if s == State.BURN:
		Sfx.play(&"shockwave", 0.15)


## True while the vent warns or burns (the QA bot keeps away from it).
func dangerous() -> bool:
	return state != State.IDLE


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS - 2.0, GRATE)
	draw_arc(Vector2.ZERO, RADIUS - 2.0, 0.0, TAU, 16, GRATE_EDGE, 1.0)
	for i in 3:
		var y := -3.0 + i * 3.0
		draw_line(Vector2(-4, y), Vector2(4, y), GRATE_EDGE, 1.0)
	match state:
		State.IDLE:
			var k := 0.25 + 0.15 * sin(t * 3.0 + phase)
			draw_circle(Vector2.ZERO, 2.5, Color(EMBER, k))
		State.WARN:
			var k := 0.5 + 0.5 * sin(t * 28.0)
			draw_circle(Vector2.ZERO, RADIUS, Color(WARN_RED, 0.25 + 0.3 * k))
			draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 20, Color(WARN_RED, 0.9), 1.0)
		State.BURN:
			var f := 1.0 - t / BURN_TIME
			draw_circle(Vector2.ZERO, RADIUS, Color(EMBER, 0.75 * f + 0.2))
			draw_circle(Vector2(0, -3), RADIUS * 0.55, Color(FLAME, 0.9 * f + 0.1))
