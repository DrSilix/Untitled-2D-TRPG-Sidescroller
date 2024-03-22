extends BaseCharacter

#action weights, when using an action the weight is reduced, when event
#weight can be increased. e.g. movement reduces as used, when hit gets raised
func ChooseCombatAction():
	print("Enemy")

func _ready():
	super._ready()
