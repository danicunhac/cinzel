extends Node2D
## Placeholder town (Task 12 replaces it). The clock stays paused here.
## E enters floor 1.

@onready var info: Label = $Info


func _ready() -> void:
	Game.run.clock.running = false
	Game.in_boss_room = false
	var s := int(Game.run.clock.seconds)
	info.text = "Ouro: %d   Andares liberados: %d   Relógio: %02d:%02d\nE: entrar no andar 1" % [
		Game.run.gold, Game.run.unlocked_floors, s / 60, s % 60]


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"interact"):
		Dungeon.requested_floor = 1
		Game.goto(Dungeon.SCENE)
