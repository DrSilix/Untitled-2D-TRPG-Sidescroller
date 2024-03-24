extends BaseCharacter

@export var isOverworldControllable = false;

@onready var player_choose_action_menu := $/root/Node2D/CanvasLayer/PlayerChooseAction

var isInputDisabled = false

func _ready():
	ConnectToMovableArea()
	super._ready()

func ConnectToMovableArea():
	if isOverworldControllable:
		get_node("../MovableArea").connect("input_event", _on_input_event)

func DisconnectFromMovableArea():
	if isOverworldControllable:
		get_node("../MovableArea").disconnect("input_event", _on_input_event)

func ChooseCombatAction(combatArea : CombatArea):
	currentCombatArea = combatArea
	player_choose_action_menu.visible = true
	player_choose_action_menu.Initialize(self)
	player_choose_action_menu.connect("action_chosen", _on_action_chosen)
	
func _on_action_chosen(action : String, data):
	player_choose_action_menu.disconnect("action_chosen", _on_action_chosen)
	match action:
		"shootsingle":
			currentChosenAction = CombatActions.SHOOTSINGLE
			attackTarget = GameManager.current_enemies[data as int]
		"shootburst":
			currentChosenAction = CombatActions.SHOOTBURST
			attackTarget = GameManager.current_enemies[data as int]
		"grenade":
			currentChosenAction = CombatActions.GRENADE
		"reload":
			currentChosenAction = CombatActions.RELOAD
		"move":
			currentChosenAction = CombatActions.MOVE
			moveTarget = data as Vector2
		"pass":
			currentChosenAction = CombatActions.PASS
		"flee":
			currentChosenAction = CombatActions.FLEE
	CompleteChosenAction()


func CompleteChosenAction():
	super.CompleteChosenAction()

func Die():
	super.Die()
	GameManager.current_players.erase(self)
	queue_free()

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int):
	if !isInputDisabled:
		if event.is_action_pressed("Move"):
			print(get_canvas_transform().affine_inverse() * event.position)
			MoveTo(get_canvas_transform().affine_inverse() * event.position)
		if event.is_action_pressed("Attack"):
			activeState = ATTACKING
