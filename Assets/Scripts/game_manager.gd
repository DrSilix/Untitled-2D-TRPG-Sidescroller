class_name GameManager extends Node
## stores common elements for global access and handles initializing the game
@onready var rootNode := $".."

@onready var player_spawn : Sprite2D = $"../PlayerSpawn"
@onready var player_spawn_2 : Sprite2D = $"../PlayerSpawn2"
@onready var player_spawn_3 : Sprite2D = $"../PlayerSpawn3"
@onready var camera_2d : Camera2D = $"../Camera2D"
@onready var screen_tinting : Panel = $"../ScreenTinting"

var player1PackedScene : PackedScene = preload("res://Assets/Characters/Biker/biker_player.tscn")
var player2PackedScene : PackedScene = preload("res://Assets/Characters/Punk/punk_player.tscn")
var player3PackedScene : PackedScene = preload("res://Assets/Characters/Cyborg/cyborg_player.tscn")
var biker_player
var punk_player
var cyborg_player

var current_players : Array[BaseCharacter]
var current_enemies : Array[BaseCharacter]

func _ready():
	await get_tree().create_timer(0.1).timeout
	SpawnPlayers()

## Spawns the 3 players, two of which are immobile and hidden at the start of
## the combat area
func SpawnPlayers():
	player_spawn_2.visible = false
	player_spawn_3.visible = false
	player_spawn.visible = false
	
	biker_player = player1PackedScene.instantiate()
	rootNode.add_child(biker_player)
	biker_player.global_position = player_spawn.global_position
	camera_2d.position_smoothing_enabled = false
	camera_2d.reparent.call_deferred(biker_player)
	camera_2d.position = player_spawn.global_position
	# This is necessary to snap the camera before the first frame render. Despite position
	# smoothing being disabled without this the camera will smoothly pan to the character
	await get_tree().create_timer(0.1).timeout
	camera_2d.position_smoothing_enabled = true
	current_players.append(biker_player)
	
	punk_player = player2PackedScene.instantiate()
	cyborg_player = player3PackedScene.instantiate()
	rootNode.add_child(punk_player)
	rootNode.add_child(cyborg_player)
	punk_player.global_position = player_spawn_2.global_position
	cyborg_player.global_position = player_spawn_3.global_position
	
	current_players.append(punk_player)
	current_players.append(cyborg_player)
	punk_player.visible = false
	cyborg_player.visible = false
