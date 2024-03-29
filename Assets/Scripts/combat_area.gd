class_name CombatArea extends Area2D

@export var spawns : Array[EnemySpawn]

@onready var stop_ = $"../CanvasLayer/Stop!"
@onready var GameManager := $/root/Node2D/GameManager

var camera_2d : Camera2D

var enemies : Array[BaseCharacter]
var players : Array[BaseCharacter]
var combatRoundParticipants : Array[BaseCharacter]

var _numberOfCombatParticipants : int
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
		player.main_status_bar.visible = true
		player.DisconnectFromMovableArea()
	for enemy in enemies:
		enemy.main_status_bar.visible = true
	CombatRound()

func CombatRound():
	if _round > 1: print("Round ",_round ," Complete")
	print("Round ",_round ," Starting")
	_round += 1
	for player : BaseCharacter in players:
		player.main_status_bar.visible = true
		player.currentActionPoints = player.maxActionPoints
		player.DisconnectFromMovableArea()
		player.InitializeCombatant(self)
		combatRoundParticipants.append(player)
	for enemy : BaseCharacter in enemies:
		enemy.main_status_bar.visible = true
		enemy.currentActionPoints = enemy.maxActionPoints
		enemy.InitializeCombatant(self)
		combatRoundParticipants.append(enemy)
	CallNextCombatantToTakeTurn()

func CallNextCombatantToTakeTurn():
	if players.size() == 0 or enemies.size() == 0:
		return
	if combatRoundParticipants.size() == 0:
		CombatRound()
		return
	_numberOfCombatParticipants = players.size() + enemies.size()
	var currentCombatant = combatRoundParticipants.pop_front()
	TakeTurn(currentCombatant)

func TakeTurn(actor : BaseCharacter):
	print("---",actor.name, "'s turn---")
	actor.ChooseCombatAction()

func RemoveCombatantFromRound(actor : BaseCharacter):
	combatRoundParticipants.erase(actor)
	#only one has an effect. max array size is like 5, usually 3
	GameManager.current_players.erase(actor)
	GameManager.current_enemies.erase(actor)

func CheckIfGameOver():
	if players.size() == 0:
		GameOver(false)
		return true
	if enemies.size() == 0:
		GameOver(true)
		return true
	return false
		
func GameOver(didWin : bool):
	if didWin:
		await get_tree().create_timer(2).timeout
		print("You Win!")
		get_tree().change_scene_to_file("res://Scenes/you_win.tscn")
	else:
		await get_tree().create_timer(2).timeout
		print("You Lose!")
		get_tree().change_scene_to_file("res://Scenes/game_over.tscn")

#Handle combat area enter
func _on_body_entered(body):
	# TODO: disconnect this after it's entered first time
	if body.is_in_group("Player"):
		disconnect("body_entered", _on_body_entered,)
		body.isInputDisabled = true
		body.HaltActions()
		#print(spawnAreas[0].moveTarget.name)
		PlayCutscene()
