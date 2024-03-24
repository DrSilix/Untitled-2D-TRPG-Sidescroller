class_name CombatArea extends Area2D

@export var spawns : Array[EnemySpawn]

@onready var stop_ = $"../CanvasLayer/Stop!"

var camera_2d : Camera2D
var player : BaseCharacter

var enemies : Array[BaseCharacter]
var players : Array[BaseCharacter]

var _numberOfCombatParticipants : int
var _currentActiveCombatantIndex : int
var _round : int

func _ready():
	stop_.visible = false
	connect("body_entered", _on_body_entered,)

func PlayCutscene():
	camera_2d = GameManager.camera_2d
	camera_2d.position_smoothing_enabled = false
	camera_2d.reparent(get_parent())
	await get_tree().create_timer(0.1).timeout
	camera_2d.position_smoothing_enabled = true
	stop_.visible = true
	await get_tree().create_timer(2).timeout
	stop_.visible = false
	for i in range(spawns.size()):
		var spawn = spawns[i]
		var enemy : BaseCharacter = spawn.enemyTemplate.instantiate()
		enemy.name = "Enemy-" + str(i+1)
		enemy.global_position = spawn.global_position
		get_parent().add_child(enemy)
		enemy.MoveTo(spawn.move_to.global_position)
		enemy.associatedPathNode = spawn.startingPathNode
		enemy.associatedPathNode.occupied = true
		enemies.append(enemy)
	var tween = get_tree().create_tween()
	tween.tween_property(camera_2d, "global_position", global_position, 1)
	GameManager.punk_player.visible = true
	GameManager.cyborg_player.visible = true
	await get_tree().create_timer(2).timeout
	BeginCombat()

func BeginCombat():
	print("Beginning Combat")
	_round = 1
	GameManager.current_enemies = enemies
	players = GameManager.current_players
	for player in players:
		player.DisconnectFromMovableArea()
	CombatRound()

func CombatRound():
	if _round > 1: print("Round ",_round ," Complete")
	print("Round ",_round ," Starting")
	_currentActiveCombatantIndex = -1
	_round += 1
	CallNextCombatantToTakeTurn()

func CallNextCombatantToTakeTurn():
	_currentActiveCombatantIndex += 1
	_numberOfCombatParticipants = players.size() + enemies.size()
	if _currentActiveCombatantIndex >= _numberOfCombatParticipants:
		CombatRound()
		return
	if _currentActiveCombatantIndex < players.size():
		TakeTurn(players[_currentActiveCombatantIndex])
	else:
		TakeTurn(enemies[_currentActiveCombatantIndex - players.size()])

func TakeTurn(actor : BaseCharacter):
	actor.ChooseCombatAction(self)

#Handle combat area enter
func _on_body_entered(body):
	# TODO: disconnect this after it's entered first time
	if body.is_in_group("Player"):
		player = body
		player.isInputDisabled = true
		player.HaltActions()
		#print(spawnAreas[0].moveTarget.name)
		PlayCutscene()
