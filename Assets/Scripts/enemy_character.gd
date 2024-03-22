extends BaseCharacter

var associatedPathNode : PathNode

func _ready():
	ChooseCombatAction()
	super._ready()

#action weights, when using an action the weight is reduced, when event
#weight can be increased. e.g. movement reduces as used, when hit gets raised
func ChooseCombatAction():
	await get_tree().create_timer(5).timeout
	associatedPathNode.occupied = false
	associatedPathNode = associatedPathNode.GetMoveToNode()
	associatedPathNode.occupied = true
	MoveTo(associatedPathNode.global_position)
	ChooseCombatAction()

func _process(delta):
	pass

func _physics_process(delta):
	super._physics_process(delta)
	spriteRootNode.scale.x = -1
