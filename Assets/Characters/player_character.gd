extends BaseCharacter

@export var isOverworldControllable = false;

@onready var player_choose_action_menu := $/root/Node2D/CanvasLayer/PlayerChooseAction
@onready var game_manager : GameManager = $/root/Node2D/GameManager


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

func ChooseCombatAction():
	grenadeAmmo = currentCombatArea.playerGrenadeAmmo
	highlight_yellow.visible = true
	player_choose_action_menu.visible = true
	player_choose_action_menu.Initialize(self)
	player_choose_action_menu.connect("action_chosen", _on_action_chosen)
	
func _on_action_chosen(action : String, data):
	player_choose_action_menu.disconnect("action_chosen", _on_action_chosen)
	match action:
		"shootsingle":
			currentChosenAction = CombatActions.SHOOTSINGLE
			attackTarget = data as BaseCharacter
		"shootburst":
			currentChosenAction = CombatActions.SHOOTBURST
			attackTarget = data as BaseCharacter
		"grenade":
			currentChosenAction = CombatActions.GRENADE
			attackTarget = data as BaseCharacter
		"reload":
			currentChosenAction = CombatActions.RELOAD
		"takeaim":
			currentChosenAction = CombatActions.TAKEAIM
		"move":
			currentChosenAction = CombatActions.MOVE
			moveTarget = data as Vector2
		"pass":
			currentChosenAction = CombatActions.PASS
	CompleteChosenAction()


func CompleteChosenAction():
	super.CompleteChosenAction()
	
func GrenadeAction():
	currentCombatArea.playerGrenadeAmmo -= 1
	super.GrenadeAction()

func Die():
	super.Die()
	queue_free()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	if !isInputDisabled:
		if event.is_action_pressed("Move"):
			print(get_canvas_transform().affine_inverse() * event.position)
			MoveTo(get_canvas_transform().affine_inverse() * event.position)
