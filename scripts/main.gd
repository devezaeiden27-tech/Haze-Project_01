extends Node3D

@onready var player: HazePlayer = $Player
@onready var hud: Control = $HUD/Overlay


func _ready() -> void:
	for enemy: HazeEnemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_target(player)
	hud.setup(player)
	hud.restart_requested.connect(_restart)
	player.restart_requested.connect(_restart)


func _restart() -> void:
	get_tree().reload_current_scene()