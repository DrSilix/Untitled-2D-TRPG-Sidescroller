class_name CombatArea extends Area2D

signal turn_finished(nextCombatant, prevCombatant)

@export var spawns : Array[EnemySpawn]

@onready var stop_ = $"../CanvasLayer/Stop!"
@onready var game_manager := $/root/Node2D/GameManager

var camera_2d : Camera2D

var enemies : Array[BaseCharacter]
var players : Array[BaseCharacter]
var combatRoundParticipants : Array[Node]

var currentlyActiveGrenade : Grenade
var activeGrenadesParent : BaseCharacter
var activeGrenadesBackupIndex : int
var numPlayersInCover : int = 0
var enemyGrenadeAmmo : int = 1
var playerGrenadeAmmo : int = 0

var _currentCombatant
var _numberOfCombatParticipants : int
var _round : int
var _turn : int

func _ready():
	stop_.visible = false
	connect("body_entered", _on_body_entered,)

func PlayCutscene():
	camera_2d = game_manager.camera_2d
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
	game_manager.punk_player.visible = true
	game_manager.cyborg_player.visible = true
	await get_tree().create_timer(2).timeout
	BeginCombat()

func BeginCombat():
	print("Beginning Combat")
	_round = 1
	game_manager.current_enemies = enemies
	players = game_manager.current_players
	for player in players:
		player.main_status_bar.visible = true
		player.DisconnectFromMovableArea()
	for enemy in enemies:
		enemy.main_status_bar.visible = true
	CombatRound()

func CombatRound():
	if _round > 1: print("Round ",_round ," Complete")
	print("Round ",_round ," Starting")
	if _round % 3 == 0: enemyGrenadeAmmo += 1
	if _round % 2 == 0: playerGrenadeAmmo += 1
	_round += 1
	numPlayersInCover = 0
	for player : BaseCharacter in players:
		player.main_status_bar.visible = true
		player.currentActionPoints = player.maxActionPoints
		if player.hasCover > 0: numPlayersInCover += 1
		player.AssignCombatArea(self)
		combatRoundParticipants.append(player)
	for enemy : BaseCharacter in enemies:
		enemy.main_status_bar.visible = true
		enemy.currentActionPoints = enemy.maxActionPoints
		enemy.AssignCombatArea(self)
		combatRoundParticipants.append(enemy)
	if currentlyActiveGrenade:
		var indexToInsert = activeGrenadesBackupIndex + 1
		if activeGrenadesParent != null:
			indexToInsert = combatRoundParticipants.find(activeGrenadesParent) + 1
		combatRoundParticipants.insert(indexToInsert, currentlyActiveGrenade)
	_turn = 0
	CallNextCombatantToTakeTurn()

func CallNextCombatantToTakeTurn():
	if players.size() == 0 or enemies.size() == 0:
		return
	if combatRoundParticipants.size() == 0:
		CombatRound()
		return
	_numberOfCombatParticipants = players.size() + enemies.size()
	var previousCombatant = _currentCombatant
	_currentCombatant = combatRoundParticipants.pop_front()
	turn_finished.emit(_currentCombatant, previousCombatant)
	_turn += 1
	TakeTurn(_currentCombatant)

func TakeTurn(actor):
	print("---",actor.name, "'s turn---")
	actor.ChooseCombatAction()

func RemoveCombatantFromRound(actor : BaseCharacter):
	combatRoundParticipants.erase(actor)
	#only one has an effect. max array size is like 5, usually 3
	game_manager.current_players.erase(actor)
	game_manager.current_enemies.erase(actor)
	
func RegisterGrenade(grenade : Grenade, combatant : BaseCharacter):
	currentlyActiveGrenade = grenade
	activeGrenadesParent = combatant
	activeGrenadesBackupIndex = _turn - 1

func DeregisterGrenade():
	currentlyActiveGrenade = null
	activeGrenadesParent = null
	

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
		body.velocity = Vector2.ZERO
		body.activeState = body.IDLE
		#print(spawnAreas[0].moveTarget.name)
		PlayCutscene()
