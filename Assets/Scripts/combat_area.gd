class_name CombatArea extends Area2D
## modular all inclusive controller for single instance of player vs enemy combat
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

## Brute force plays a cutscene and initializes and puppets actors
##
## detaches camera from player leaving it above player, then displays dialog.
## after that spawns in enemies and moves them to initial locations while centering
## the camera.
func PlayCutscene():
	camera_2d = game_manager.camera_2d
	camera_2d.position_smoothing_enabled = false
	camera_2d.reparent(get_parent())
	await get_tree().create_timer(0.1).timeout
	camera_2d.position_smoothing_enabled = true
	## UI dialog
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
		# attaches the enemies to the pathnode network
		enemy.associatedPathNode = spawn.startingPathNode
		enemy.associatedPathNode.occupied = true
		enemies.append(enemy)
	var tween = get_tree().create_tween()
	# centers camera
	tween.tween_property(camera_2d, "global_position", global_position, 1)
	# TODO: this pops in the other party members, this should probably be more
	# graceful. Though it doesn't look too wrong with them poping in.
	game_manager.punk_player.visible = true
	game_manager.cyborg_player.visible = true
	await get_tree().create_timer(2).timeout
	BeginCombat()

## One time called initializer to setup and start combat
## the controllable player is also disconnected from world move input and status
## bars are displayed above actors heads
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

## Initializes and kicks off a single combat round which iterates through all
## players and then all enemies. This is run once per round
func CombatRound():
	if _round > 1: print("Round ",_round ," Complete")
	print("Round ",_round ," Starting")
	# for now.. players get grenade every 2 round, enemy every 3
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
	# this adds a grenade to the round participants array.
	if currentlyActiveGrenade:
		# BUG: this may need to be 1 less (because this refers to the situation
		# where the thrower is gone. If the throw exists then this is overwritten
		var indexToInsert = activeGrenadesBackupIndex + 1
		# the grenade creator could have been killed
		if activeGrenadesParent != null:
			indexToInsert = combatRoundParticipants.find(activeGrenadesParent) + 1
		combatRoundParticipants.insert(indexToInsert, currentlyActiveGrenade)
	_turn = 0
	CallNextCombatantToTakeTurn()

## Main Loop. This processes one at a time a queue of combat actors and asks
## them to take their turn. The assumption that must be held is that the actor
## will eventually call this method again. When no more actors are in the queue
## the next round is initiated
func CallNextCombatantToTakeTurn():
	# this is a check that intentionally breaks the loop if someone won/lost.
	if players.size() == 0 or enemies.size() == 0:
		return
	if combatRoundParticipants.size() == 0:
		CombatRound()
		return
	_numberOfCombatParticipants = players.size() + enemies.size()
	var previousCombatant = _currentCombatant
	_currentCombatant = combatRoundParticipants.pop_front()
	# TODO: this WAS used by grenade for a turn timer countdown. Instead
	# opted for a full turn system instead
	turn_finished.emit(_currentCombatant, previousCombatant)
	_turn += 1
	TakeTurn(_currentCombatant)

func TakeTurn(actor):
	print("---",actor.name, "'s turn---")
	actor.ChooseCombatAction()

## This is called when a player/enemy is killed and asks to delete themselves
## from combat before destroying themselves. players/enemies are stored in
## both the current combat instance and in the overall game world GameManager
## [param actor] BaseCharacter to remove from world and combat
func RemoveCombatantFromRound(actor : BaseCharacter):
	combatRoundParticipants.erase(actor)
	#only one has an effect
	game_manager.current_players.erase(actor)
	game_manager.current_enemies.erase(actor)

## Facilitates a system where only one grenade is allowed in play by either
## enemies or players TODO: this may be not ideal, but with the small play area
## it currently makes the most sense
## [param grenade] Grenade object to store as actively on the playfield
## [param combatant] BaseCharacter that threw the grenade
func RegisterGrenade(grenade : Grenade, combatant : BaseCharacter):
	currentlyActiveGrenade = grenade
	activeGrenadesParent = combatant
	activeGrenadesBackupIndex = _turn - 1

## removes references to the Grenade and thrower
func DeregisterGrenade():
	currentlyActiveGrenade = null
	activeGrenadesParent = null
	
## determines if either the players or enemies are all dead.
## [return bool] Whether the game is completed regardless of win/lose
## TODO: this is specific to the demo status, this should instead by isCombatOver
func CheckIfGameOver():
	if players.size() == 0:
		GameOver(false)
		return true
	if enemies.size() == 0:
		GameOver(true)
		return true
	return false

## Switches to the relevant game complete screen for this "demo"
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
	if body.is_in_group("Player"):
		disconnect("body_entered", _on_body_entered,)
		body.isInputDisabled = true
		body.velocity = Vector2.ZERO
		body.activeState = body.IDLE
		PlayCutscene()
