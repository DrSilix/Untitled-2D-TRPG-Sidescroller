extends BaseCharacter

@export var attackWeight := 5
@export var moveWeight := 3
@export var moveCost := 3
@export var fleeWeight := 0
@export var fleeCost := 0

@export_group("Attacks")
@export var singleShotWeight := 9
@export var singleShotCost := 3
@export var burstShotWeight := 5
@export var burstShotCost := 6
@export var grenadeWeight := 0
@export var grenadeCost := 6

@export var reloadCost := 3

var associatedPathNode : PathNode
var rng := RandomNumberGenerator.new()

@onready var attackA : CAction = CAction.new(attackWeight,
											singleShotCost,
											CombatActions.ATTACK)
@onready var moveA : CAction = CAction.new(moveWeight,
											moveCost,
											CombatActions.MOVE)
@onready var fleeA : CAction = CAction.new(fleeWeight,
											fleeCost,
											CombatActions.FLEE)
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
	super._ready()

#action weights, when using an action the weight is reduced, when event
#weight can be increased. e.g. movement reduces as used, when hit gets raised
func ChooseCombatAction():
	var combinedWeightActions := 0
	var possibleActions : Array[CAction]
	if attackA.cost <= currentActionPoints and attackA.weight > 0:
		combinedWeightActions += attackA.weight
		possibleActions.append(attackA)
	if moveA.cost <= currentActionPoints and moveA.weight > 0:
		combinedWeightActions += moveA.weight
		possibleActions.append(moveA)
	if fleeA.cost <= currentActionPoints and fleeA.weight > 0:
		combinedWeightActions += fleeA.weight
		possibleActions.append(fleeA)
	
	if possibleActions.size() == 0 and combinedWeightActions == 0:
		currentActionPoints = 0
		currentChosenAction = CombatActions.PASS
		print(CombatActions.keys()[currentChosenAction])
		return

	var chosenWeight = rng.randi_range(0, combinedWeightActions-1)
	var chosenPossibleAction : CAction
	
	for act in possibleActions:
		chosenWeight -= act.weight
		if chosenWeight <= 0:
			chosenPossibleAction = act
			break

	# TODO: this needs to be made a function
	if chosenPossibleAction.combatAction == CombatActions.ATTACK:
		combinedWeightActions = 0
		possibleActions.clear()
		if singleSA.cost <= currentActionPoints:
			combinedWeightActions += singleSA.weight
			possibleActions.append(singleSA)
		if burstSA.cost <= currentActionPoints:
			combinedWeightActions += burstSA.weight
			possibleActions.append(burstSA)
		if grenadeA.cost <= currentActionPoints and grenadeA.weight > 0:
			combinedWeightActions += grenadeA.weight
			possibleActions.append(grenadeA)
		
		if possibleActions.size() == 0 and combinedWeightActions == 0:
			currentActionPoints -= reloadCost if currentActionPoints >= reloadCost else currentActionPoints
			currentChosenAction = CombatActions.RELOAD
			print(CombatActions.keys()[currentChosenAction])
			return

		chosenWeight = rng.randi_range(0, combinedWeightActions-1)
		chosenPossibleAction = null
		
		for act in possibleActions:
			chosenWeight -= act.weight
			if chosenWeight <= 0:
				chosenPossibleAction = act
				break

	currentChosenAction = chosenPossibleAction.combatAction
	currentActionPoints -= chosenPossibleAction.cost
	print(CombatActions.keys()[currentChosenAction])


func CompleteChosenAction():
	#do this if moving
	match currentChosenAction:
		CombatActions.SHOOTSINGLE:
			currentWeaponAmmo -= 1
			print("Shooting Single")
		CombatActions.SHOOTBURST:
			currentWeaponAmmo -= 3 if currentWeaponAmmo >= 3 else currentWeaponAmmo
			print("Shooting Burst")
		CombatActions.GRENADE:
			print("Throwing Grenade")
		CombatActions.RELOAD:
			currentWeaponAmmo = maxWeaponAmmo
		CombatActions.MOVE:
			print("Moving")
			moveA.weight -= 2 if moveA.weight > 1 else 1
			associatedPathNode.occupied = false
			associatedPathNode = associatedPathNode.GetMoveToNode()
			associatedPathNode.occupied = true
			MoveTo(associatedPathNode.global_position)
			# TODO: somehow wait for move to finish. signals??
		CombatActions.FLEE:
			print("Fleeing")
		CombatActions.PASS:
			print("Passing Turn")
	print("Actions points: ", currentActionPoints)

func _process(delta):
	pass

func _physics_process(delta):
	super._physics_process(delta)
	spriteRootNode.scale.x = -1
	
class CAction:
	var weight
	var cost
	var combatAction : CombatActions
	
	func _init(w, c, action):
		weight = w
		cost = c
		combatAction = action
