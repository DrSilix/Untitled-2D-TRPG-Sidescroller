extends Area2D

@export var spawns : Array[EnemySpawn]

@onready var stop_ = $"../CanvasLayer/Stop!"

var camera_2d : Camera2D
var player : BaseCharacter

var enemies : Array[BaseCharacter]

func _ready():
	stop_.visible = false
	#Handling Enemy Spawn
	connect("body_entered", _on_body_entered,)
	#var spawns = find_children("EnemySpawn*")
	#for spawn in spawns:
		#spawnAreas.append(SpawnArea.new(spawn, spawn.get_child(0)))
		#spawn.visible = false
		#spawn.get_child(0).visible = false

func PlayCutscene():
	camera_2d = GameManager.camera_2d
		
	stop_.visible = true
	await get_tree().create_timer(2).timeout
	stop_.visible = false
	for spawn in spawns:
		var enemy : BaseCharacter = spawn.enemyTemplate.instantiate()
		enemy.global_position = spawn.global_position
		get_parent().add_child(enemy)
		enemy.MoveTo(spawn.move_to.global_position)
		enemy.associatedPathNode = spawn.startingPathNode
		enemy.associatedPathNode.occupied = true
		enemies.append(enemy)
	var tween = get_tree().create_tween()
	tween.tween_property(camera_2d, "global_position", global_position, 1)
	await get_tree().create_timer(2).timeout

func BeginCombat():
	pass

func TakeTurn(actor : BaseCharacter):
	while actor.currentActionPoints > 0:
		actor.ChooseCombatAction()
		

#Handle combat area enter
func _on_body_entered(body):
	if body.is_in_group("Player"):
		player = body
		player.isInputDisabled = true
		player.HaltActions()
		#print(spawnAreas[0].moveTarget.name)
		PlayCutscene()
