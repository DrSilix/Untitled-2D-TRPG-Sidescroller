extends BaseCharacter
## Inherits base character and provides more specific mechanisms for Players
## that are controlled by user input
const MOUSE_MOVE_CHECK_FREQ = 30

@export var isOverworldControllable = false;

@onready var player_choose_action_menu := $/root/Node2D/CanvasLayer/PlayerChooseAction
@onready var game_manager : GameManager = $/root/Node2D/GameManager

# TODO: this may be redundant, the connected area has the same effect
var isInputDisabled = false
var _mouseMoveCheckCounter = MOUSE_MOVE_CHECK_FREQ

func _ready():
	ConnectToMovableArea()
	super._ready()

## Connects to the world bounded moveable area and allows click/tap movement
## TODO: this is confusing with the player child movable area (I just confused
## them when writing this comment a moment ago)
func ConnectToMovableArea():
	if isOverworldControllable:
		get_node("../MovableArea").connect("input_event", _on_input_event)

## Disconnects to the world bounded moveable area. This
## disables the ability to click/tap-move
func DisconnectFromMovableArea():
	if isOverworldControllable:
		get_node("../MovableArea").disconnect("input_event", _on_input_event)

## Activates the choose action UI and starts listening for input. It
## also syncronizes with the player grenade pool. See [class player_choose_action]
func ChooseCombatAction():
	grenadeAmmo = currentCombatArea.playerGrenadeAmmo
	highlight_yellow.visible = true
	player_choose_action_menu.visible = true
	player_choose_action_menu.Initialize(self)
	player_choose_action_menu.connect("action_chosen", _on_action_chosen)

## Accepts input from the player choose action class [class player_choose_action]
## in string form and assigns the result to variables in base character
##
## Data is generic in form. attack actions expect a BaseCharacter while the move
## action expects a Vector2 position
## [param action] A string representing the action to take, see method for options
## [param data] generically typed data to be passed along with action
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

## override to decrement the player specific grenade ammo pool
func GrenadeAction():
	currentCombatArea.playerGrenadeAmmo -= 1
	super.GrenadeAction()

func Die():
	super.Die()
	queue_free()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	if !isInputDisabled:
		if event is InputEventMouseMotion:
			var mm = event as InputEventMouseMotion
			if mm.button_mask == 1 && _mouseMoveCheckCounter <= 0:
				_mouseMoveCheckCounter = MOUSE_MOVE_CHECK_FREQ
				print((event as InputEventMouseMotion).position)
				MoveTo(get_canvas_transform().affine_inverse() * event.position)
			elif mm.button_mask == 1:
				_mouseMoveCheckCounter -= 1
		if event.is_action_pressed("Move"):
			print(get_canvas_transform().affine_inverse() * event.position)
			MoveTo(get_canvas_transform().affine_inverse() * event.position)
