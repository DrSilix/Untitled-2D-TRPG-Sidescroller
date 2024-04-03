extends BaseCharacter
## Inherits base character and provides more specific mechanisms for Enemies
## that are controlled autonomously by logic instead of with user input
@export var attackWeight := 5
@export var moveWeight := 3
@export var takeAimWeight := 0

@export_group("Attacks")
@export var singleShotWeight := 9
@export var burstShotWeight := 5
@export var grenadeWeight := 0

@onready var game_manager : GameManager = $/root/Node2D/GameManager


var associatedPathNode : PathNode
var rng := RandomNumberGenerator.new()

@onready var attackA : CAction = CAction.new(attackWeight,
											singleShotCost,
											CombatActions.ATTACK)
@onready var moveA : CAction = CAction.new(moveWeight,
											moveCost,
											CombatActions.MOVE)
@onready var aimA : CAction = CAction.new(takeAimWeight,
											takeAimCost,
											CombatActions.TAKEAIM)
@onready var singleSA : CAction = CAction.new(singleShotWeight,
											singleShotCost,
											CombatActions.SHOOTSINGLE)
@onready var burstSA : CAction = CAction.new(burstShotWeight,
											burstShotCost,
											CombatActions.SHOOTBURST)
@onready var grenadeA : CAction = CAction.new(grenadeWeight,
											grenadeCost,
											CombatActions.GRENADE)

func _ready():
	animationPlayer.speed_scale *= RandomNumberGenerator.new().randf_range(0.85, 1.15)
	super._ready()

# TODO: this needs to be broken up into logical parts
## Handles enemy AI logic (WIP state, needs refactoring)
##
## Determines what course of action to take and also uses method
## [method ChooseAttackTarget] to determine the target for the action. The
## different actions are chosen by weighted randomness. The main way that
## enemies react to context is by raising/lowering weights
## Actions are grouped as movement and attack, then attack has sub elements
func ChooseCombatAction():	
	highlight_yellow.visible = true
	# aim modifier can be positive (good) or negative (bad), This increases aim
	# weight proportionally if the enemy has low aim (high recoil)
	aimA.weight = (-aimModifier + 1) if aimModifier < 0 else 1
	# if aiming then next action is heavily weighted attack
	attackA.weight = attackWeight if aimModifier <= 0 else 99
	# grenades are thrown only if 2 or more players in cover, weighted proportionally
	# note: # of players in cover is only ever evaluated at round begin
	if currentCombatArea.currentlyActiveGrenade == null \
		and currentCombatArea.numPlayersInCover > 1:
		grenadeA.weight = currentCombatArea.numPlayersInCover
	else: grenadeA.weight = 0
	grenadeAmmo = currentCombatArea.enemyGrenadeAmmo
	print("Enemy grenade status: W", grenadeA.weight, ", A", grenadeAmmo)
	await get_tree().create_timer(1).timeout
	
	# step one of two, decide move or attack
	var combinedWeightActions := 0
	var possibleActions : Array[CAction] = []
	if attackA.cost <= currentActionPoints and attackA.weight > 0:
		combinedWeightActions += attackA.weight
		possibleActions.append(attackA)
	if moveA.cost <= currentActionPoints and moveA.weight > 0:
		combinedWeightActions += moveA.weight
		possibleActions.append(moveA)
	
	if possibleActions.size() == 0 and combinedWeightActions == 0:
		currentChosenAction = CombatActions.PASS
		print(CombatActions.keys()[currentChosenAction])
		CompleteChosenAction()
		return

	var chosenWeight = rng.randi_range(0, combinedWeightActions-1)
	var chosenPossibleAction : CAction
	
	for act in possibleActions:
		chosenWeight -= act.weight
		if chosenWeight <= 0:
			chosenPossibleAction = act
			break
	
	
	# TODO: this needs to be made a function
	# if attacking decide what attack related action
	if chosenPossibleAction.combatAction == CombatActions.ATTACK:
		combinedWeightActions = 0
		possibleActions.clear()
		if singleSA.cost <= currentActionPoints and currentWeaponAmmo >= 1:
			combinedWeightActions += singleSA.weight
			possibleActions.append(singleSA)
		if burstSA.cost <= currentActionPoints and currentWeaponAmmo >= 3:
			combinedWeightActions += burstSA.weight
			possibleActions.append(burstSA)
		if grenadeA.cost <= currentActionPoints and grenadeA.weight > 0 \
		and grenadeAmmo > 0 and currentWeaponAmmo > 0:
			combinedWeightActions += grenadeA.weight
			possibleActions.append(grenadeA)
		if aimA.cost <= currentActionPoints and aimA.weight > 0 \
		and currentWeaponAmmo > 0 and aimModifier <= 0:
			combinedWeightActions += aimA.weight
			possibleActions.append(aimA)
		# default to reload if an action can't be chosen
		if possibleActions.size() == 0 and combinedWeightActions == 0:
			currentChosenAction = CombatActions.RELOAD
			print(CombatActions.keys()[currentChosenAction])
			CompleteChosenAction()
			return

		chosenWeight = rng.randi_range(0, combinedWeightActions-1)
		chosenPossibleAction = null
		
		for act in possibleActions:
			chosenWeight -= act.weight
			if chosenWeight <= 0:
				chosenPossibleAction = act
				break
	
	currentChosenAction = chosenPossibleAction.combatAction
	var chooseClosestEnemy = true if currentChosenAction != CombatActions.GRENADE else false
	ChooseAttackTarget(chooseClosestEnemy)
	print(CombatActions.keys()[currentChosenAction])
	CompleteChosenAction()

## this is an override. It simply applies a "thinking" 1 second sleep before
## the AI completes the action.
func CompleteChosenAction():
	await get_tree().create_timer(1).timeout
	super.CompleteChosenAction()

## This is used to choose an attack target. The player class has a similar override
## and instead of returning the chosen target, the target is instead assigned to
## a variable
##
## Attack targets are chosen either as the closest player, or the farthest (grenade
## only). TODO this will be made to choose a target randomly but weighted more heavily
## towards the closest target, and also most heavily towards the target closest on
## the Y axis (the target "in front" of them). It would probably be too difficult
## for the player if the enemies targeted the lowest health player.
## [param chooseClosest] do choose the closest player to this enemy (default = true)
func ChooseAttackTarget(chooseClosest : bool = true):
	var players := game_manager.current_players
	var champion = players[0].global_position.distance_squared_to(global_position)
	attackTarget = players[0]
	for player in players:
		var dist = player.global_position.distance_squared_to(global_position)
		if chooseClosest and dist < champion:
			attackTarget = player
			champion = dist
		if not chooseClosest and dist > champion:
			attackTarget = player
			champion = dist

## override to decrement the enemy specific grenade ammo pool
func GrenadeAction():
	currentCombatArea.enemyGrenadeAmmo -= 1
	super.GrenadeAction()

## complete override of the MoveAction. Enemies use a pathnode style movement
## AI with weighted nodes (nodes are generally weighted towards cover and staying
## near the middle of the play field. See [method PathNode.GetMoveToNode] for more
## specifics
##
## enemies avoid occupies pathnodes, otherwise move weighted randomly. They do
## not take into account grenades ATM
func MoveAction():
	print("Moving")
	self.connect("move_completed", _on_action_completed, CONNECT_ONE_SHOT)
	moveA.weight -= 1
	currentActionPoints -= moveCost
	associatedPathNode.occupied = false
	associatedPathNode = associatedPathNode.GetMoveToNode()
	associatedPathNode.occupied = true
	MoveTo(associatedPathNode.global_position)

## override that has enemy prefer being stationary when in cover
func TakeCover():
	super.TakeCover()
	moveA.weight = 1

## override when leaving cover enemy resets their movement weight to normal
## BUG: this is good enough for now but if an enemy moves past cover then this
## takes effect
func LeaveCover():
	super.LeaveCover()
	moveA.weight = 3

## override that has enemy increase their likelyhood of moving if damaged
## while not in cover
func TakeDamage(damage : int):
	super.TakeDamage(damage)
	if hasCover == 0:
		moveA.weight += 2

func Die():
	super.Die()
	queue_free()

## simple data structure class to allow the action choosing mechanism. This
## may not be the best method, it's clunky/doesn't feel right. BUT it works.
class CAction:
	var weight
	var cost
	var combatAction : CombatActions
	
	func _init(w, c, action):
		weight = w
		cost = c
		combatAction = action
