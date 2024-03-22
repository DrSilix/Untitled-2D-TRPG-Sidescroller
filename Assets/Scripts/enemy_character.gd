extends BaseCharacter

@export var attackWeight := 5
@export var moveWeight := 3
@export var fleeWeight := 0

@export_group("Attacks")
@export var singleShotWeight := 9
@export var burstShotWeight := 5
@export var grenadeWeight := 0

var associatedPathNode : PathNode
var rng := RandomNumberGenerator.new()

func _ready():
	super._ready()

#action weights, when using an action the weight is reduced, when event
#weight can be increased. e.g. movement reduces as used, when hit gets raised
func ChooseCombatAction():
	if currentActionPoints <= 1:
		currentChosenAction = CombatActions.PASS
		print(CombatActions.keys()[currentChosenAction])
		return
	var combinedWeightOfPossibleActions = attackWeight + moveWeight + fleeWeight
	var chosenWeight = rng.randi_range(0, combinedWeightOfPossibleActions-1)
	
	if chosenWeight < attackWeight:
		combinedWeightOfPossibleActions = singleShotWeight + burstShotWeight + grenadeWeight
		chosenWeight = rng.randi_range(0, combinedWeightOfPossibleActions-1)
		if chosenWeight < singleShotWeight:
			currentChosenAction = CombatActions.SHOOTSINGLE
		elif chosenWeight < singleShotWeight + burstShotWeight:
			currentChosenAction = CombatActions.SHOOTBURST
		else:
			currentChosenAction = CombatActions.GRENADE
			grenadeWeight = 0
	elif chosenWeight < attackWeight + moveWeight:
		currentChosenAction = CombatActions.MOVE
		moveWeight -= 2 if moveWeight > 1 else 1
	else:
		currentChosenAction = CombatActions.FLEE
	print(CombatActions.keys()[currentChosenAction])
	
func CompleteChosenAction():
	#do this if moving
	match currentChosenAction:
		CombatActions.SHOOTSINGLE:
			print("Shooting Single")
			currentActionPoints -= 2
		CombatActions.SHOOTBURST:
			print("Shooting Burst")
			currentActionPoints -= 4
		CombatActions.GRENADE:
			print("Throwing Grenade")
			currentActionPoints -= 6
		CombatActions.MOVE:
			print("Moving")
			currentActionPoints -= 3
			associatedPathNode.occupied = false
			associatedPathNode = associatedPathNode.GetMoveToNode()
			associatedPathNode.occupied = true
			MoveTo(associatedPathNode.global_position)
			# TODO: somehow wait for move to finish. signals??
		CombatActions.FLEE:
			print("Fleeing")
			currentActionPoints -= 6
		CombatActions.PASS:
			print("Passing Turn")
			currentActionPoints = 0
	print("Actions points: ", currentActionPoints)

func _process(delta):
	pass

func _physics_process(delta):
	super._physics_process(delta)
	spriteRootNode.scale.x = -1
	
