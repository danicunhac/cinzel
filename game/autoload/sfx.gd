extends Node
## Autoload. Sound effects from a pool of players on the "SFX" bus, music
## with a short crossfade on the "Music" bus, and the volume of both
## (saved in user://settings.cfg once a slider settles). The game must read
## without sound (docs/gdd.md, audio), so a missing or unknown
## id only warns.
## UI sounds are wired here too, without touching the panels: the tree pausing
## (a panel or the pause menu opens) plays ui_open, unpausing ui_close; focus
## moving between buttons plays ui_move; any button press ui_confirm; and gold
## changing while a town panel holds the tree plays buy, sell or forge.

const SFX_DIR := "res://assets/audio/sfx/%s.ogg"
const MUSIC_DIR := "res://assets/audio/music/%s.ogg"
const SETTINGS_PATH := "user://settings.cfg"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const POOL_SIZE := 12
const CROSSFADE := 0.5
## Same id again within this many ms is dropped (multi-hit in one frame).
const REPEAT_MS := 35
const DEFAULT_VOLUME: Dictionary[StringName, float] = {MUSIC_BUS: 0.55, SFX_BUS: 0.8}
const SILENT_DB := -60.0
## settings.cfg is written this long after the last volume change.
const SAVE_DELAY := 0.4

const IDS: Array[StringName] = [
	&"swing_light", &"swing_heavy", &"bow_shot", &"hit", &"crit", &"player_hurt",
	&"enemy_die", &"boss_roar", &"coin", &"item_pickup", &"ui_open", &"ui_close",
	&"ui_move", &"ui_confirm", &"step", &"roll", &"door_open", &"door_locked",
	&"chest_open", &"heal_loop", &"buy", &"sell", &"forge", &"teleport", &"stairs",
	&"special_charge", &"special_release", &"shockwave",
]
const MUSIC_IDS: Array[StringName] = [&"town", &"tower", &"boss"]
## Per-id trim (dB) on top of the -3 dB peak every file is normalised to.
const GAIN_DB: Dictionary[StringName, float] = {
	&"step": -14.0, &"ui_move": -10.0, &"ui_confirm": -6.0, &"ui_open": -6.0,
	&"ui_close": -6.0, &"heal_loop": -10.0, &"swing_light": -4.0, &"swing_heavy": -3.0,
	&"coin": -6.0, &"roll": -5.0, &"hit": -2.0, &"special_charge": -4.0,
	&"door_locked": -4.0, &"stairs": -3.0,
}

var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _streams: Dictionary[StringName, AudioStream] = {}
var _last_ms: Dictionary[StringName, int] = {}
var _loops: Dictionary[StringName, AudioStreamPlayer] = {}
var _music: Array[AudioStreamPlayer] = []
var _music_on: int = 0
var _music_id: StringName = &""
var _music_tween: Tween
var _volume: Dictionary[StringName, float] = {}
## Seconds until the pending settings write (0 = none pending).
var _save_left: float = 0.0
# UI watcher.
var _was_paused: bool = false
var _gold_seen: int = -1
var _quiet_move_until: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_pool.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = MUSIC_BUS
		m.volume_db = SILENT_DB
		add_child(m)
		_music.append(m)
	_load_settings()
	get_tree().node_added.connect(_on_node_added)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _process(_delta: float) -> void:
	_watch_ui()
	if _save_left > 0.0:
		_save_left -= _delta / maxf(Engine.time_scale, 0.0001)
		if _save_left <= 0.0:
			_save_settings()


## At exit: stop every player and drop the cached streams, so nothing is
## still referenced when the engine counts leaks.
func _exit_tree() -> void:
	shutdown()


## Stops all sound, drops the cached streams and writes a pending settings
## change. The audio server lets go of a stopped sound a frame or two later,
## so a quit that wants no leak warning calls this and waits (quit_clean).
func shutdown() -> void:
	if _save_left > 0.0:
		_save_left = 0.0
		_save_settings()
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null
	for p in _pool + _music:
		p.stop()
		p.stream = null
	for id: StringName in _loops.keys():
		stop_loop(id)
	_streams.clear()
	_music_id = &""


## Quits after letting the audio server release every sound (no "leaked at
## exit" warnings). Tools and the "Fechar o jogo" button use it.
func quit_clean(code: int = 0) -> void:
	shutdown()
	# The mixer runs on its own thread in real time (a --fixed-fps run can be
	# far ahead of it): give it a moment, then a few frames to clean up.
	for i in 4:
		OS.delay_msec(30)
		await get_tree().process_frame
	get_tree().quit(code)


# --- effects ---

## Plays `id` once with the pitch varied by +-pitch_jitter. Unknown ids warn
## and do nothing. Returns the player used (null when nothing played).
func play(id: StringName, pitch_jitter: float = 0.05) -> AudioStreamPlayer:
	var stream := _stream(id)
	if stream == null:
		return null
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(id, -1000)) < REPEAT_MS:
		return null
	_last_ms[id] = now
	var p := _free_player()
	p.stream = stream
	p.volume_db = GAIN_DB.get(id, 0.0)
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()
	return p


## Starts a looping effect (heal_loop) once; stop_loop ends it.
func play_loop(id: StringName) -> void:
	if _loops.has(id) and is_instance_valid(_loops[id]):
		return
	var stream := _stream(id)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.bus = SFX_BUS
	p.stream = stream
	p.volume_db = GAIN_DB.get(id, 0.0)
	add_child(p)
	p.play()
	_loops[id] = p


func stop_loop(id: StringName) -> void:
	if not _loops.has(id):
		return
	var p := _loops[id]
	_loops.erase(id)
	if is_instance_valid(p):
		p.queue_free()


func is_looping(id: StringName) -> bool:
	return _loops.has(id) and is_instance_valid(_loops[id])


## The pool (tests read it).
func pool() -> Array[AudioStreamPlayer]:
	return _pool


func _free_player() -> AudioStreamPlayer:
	for i in POOL_SIZE:
		var p := _pool[(_next + i) % POOL_SIZE]
		if not p.playing:
			_next = (_next + i + 1) % POOL_SIZE
			return p
	# All busy: steal the oldest.
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stop()
	return p


func _stream(id: StringName) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var path := SFX_DIR % id
	if not IDS.has(id) or not ResourceLoader.exists(path):
		push_warning("Sfx: unknown sound '%s'" % id)
		return null
	var s := load(path) as AudioStream
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = id == &"heal_loop"
	_streams[id] = s
	return s


# --- music ---

## Crossfades to music `id` (town, tower, boss) in CROSSFADE s; &"" fades
## out. The same id again does nothing.
func music(id: StringName) -> void:
	if id == _music_id:
		return
	var stream: AudioStream = null
	if id != &"":
		var path := MUSIC_DIR % id
		if not MUSIC_IDS.has(id) or not ResourceLoader.exists(path):
			push_warning("Sfx: unknown music '%s'" % id)
			return
		stream = load(path) as AudioStream
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
	_music_id = id
	var old := _music[_music_on]
	_music_on = 1 - _music_on
	var new := _music[_music_on]
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.set_ignore_time_scale(true)
	_music_tween.set_parallel(true)
	if stream != null:
		new.stream = stream
		new.volume_db = SILENT_DB
		new.play()
		_music_tween.tween_property(new, "volume_db", 0.0, CROSSFADE)
	_music_tween.tween_property(old, "volume_db", SILENT_DB, CROSSFADE)
	_music_tween.chain().tween_callback(old.stop)


func current_music() -> StringName:
	return _music_id


# --- volume ---

## Linear volume 0..1 of the Music or SFX bus.
func get_volume(bus: StringName) -> float:
	return _volume.get(bus, DEFAULT_VOLUME.get(bus, 1.0))


func set_volume(bus: StringName, v: float, save: bool = true) -> void:
	v = clampf(v, 0.0, 1.0)
	_volume[bus] = v
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001)
	if save:
		# A slider fires on every step while dragged: write once it settles.
		_save_left = SAVE_DELAY


## A labelled slider row bound to `bus`, for menus (the pause menu uses it).
func volume_row(text: String, bus: StringName) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(52, 0)
	l.add_theme_font_size_override(&"font_size", 8)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.1
	s.value = get_volume(bus)
	s.custom_minimum_size = Vector2(90, 10)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(func(v: float) -> void:
		set_volume(bus, v)
		if bus == SFX_BUS:
			play(&"ui_move"))
	row.add_child(s)
	return row


func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus)
	AudioServer.set_bus_send(i, &"Master")


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var ok := cfg.load(SETTINGS_PATH) == OK
	for bus: StringName in DEFAULT_VOLUME:
		var v: float = DEFAULT_VOLUME[bus]
		if ok:
			v = float(cfg.get_value("audio", String(bus), v))
		set_volume(bus, v, false)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	for bus: StringName in _volume:
		cfg.set_value("audio", String(bus), _volume[bus])
	cfg.save(SETTINGS_PATH)


# --- UI watcher (one place for every menu sound) ---

func _watch_ui() -> void:
	var paused := get_tree().paused
	if paused != _was_paused:
		_was_paused = paused
		play(&"ui_open" if paused else &"ui_close", 0.0)
		_quiet_move_until = Time.get_ticks_msec() + 150
	var game := get_node_or_null(^"/root/Game")
	var run: RefCounted = game.get(&"run") if game != null else null
	if run == null:
		return
	var gold: int = run.get(&"gold")
	if _gold_seen >= 0 and gold != _gold_seen and paused and _town_panel_open():
		if gold > _gold_seen:
			play(&"sell")
		elif _smith_open():
			play(&"forge")
		else:
			play(&"buy")
	_gold_seen = gold


func _town_panel_open() -> bool:
	return UiPanel.open_count > 0


func _smith_open() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	for c in scene.get_children():
		if c is SmithPanel:
			return true
	return false


func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		var b := n as BaseButton
		b.pressed.connect(func() -> void: play(&"ui_confirm", 0.0))


func _on_focus_changed(c: Control) -> void:
	if c is BaseButton and c.is_visible_in_tree() and Time.get_ticks_msec() >= _quiet_move_until:
		play(&"ui_move", 0.0)
