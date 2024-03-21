extends Node

@export var combatArea : Area2D
@export var player : BaseCharacter
@export var enemy1 : BaseCharacter

@onready var camera_2d = $"../Biker_Player/Camera2D"

var spawnAreas : Array

func _ready():
	#Handling Enemy Spawn
	combatArea.connect("body_entered", _on_CombatArea_body_entered,)
	var spawns = combatArea.find_children("EnemySpawn*")
	for spawn in spawns:
		spawnAreas.append(SpawnArea.new(spawn, spawn.get_child(0)))

func PlayCutscene():
	await get_tree().create_timer(2).timeout
	enemy1.MoveTo(spawnAreas[0].moveTarget.global_position)
	var tween = get_tree().create_tween()
	tween.tween_property(camera_2d, "global_position", combatArea.global_position, 1)
	await get_tree().create_timer(2).timeout

func BeginCombat():
	pass

#Handle combat area enter
func _on_CombatArea_body_entered(body):
	if body.is_in_group("Player"):
		player.isInputDisabled = true
		player.HaltActions()
		print(spawnAreas[0].moveTarget.name)
		PlayCutscene()


class SpawnArea:
	var spawnArea : Sprite2D
	var moveTarget : Sprite2D

	func _init(spawn, target):
		spawnArea = spawn
		moveTarget = target
