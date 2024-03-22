extends Node

@onready var rootNode : Node2D = $/root/Node2D
@onready var player_spawn : Sprite2D = $/root/Node2D/PlayerSpawn
@onready var camera_2d : Camera2D = $/root/Node2D/Camera2D

var player1PackedScene : PackedScene = preload("res://Assets/Characters/Biker/biker_player.tscn")
var biker_player

func _ready():
	player_spawn.visible = false
	biker_player = player1PackedScene.instantiate()
	rootNode.add_child(biker_player)
	biker_player.global_position = player_spawn.global_position
	camera_2d.position_smoothing_enabled = false
	camera_2d.reparent(biker_player)
	camera_2d.position = Vector2.ZERO
	await get_tree().create_timer(0.1).timeout
	camera_2d.position_smoothing_enabled = true
