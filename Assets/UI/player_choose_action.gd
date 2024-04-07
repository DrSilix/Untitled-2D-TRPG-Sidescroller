extends Control
## Handles player combat input
signal action_chosen(action : String, data)
signal hud_combat_state_changed(attacker : BaseCharacter, defender : BaseCharacter)

@export var ui_positive : AudioStreamWAV
@export var ui_negative : AudioStreamWAV

@onready var game_manager : GameManager = $/root/Node2D/GameManager

@onready var main_menu := $Main
@onready var sub_attack_menu := $SubAttack
@onready var cancel_button = $CancelButton/Cancel

@onready var attack := $Main/Panel/MarginContainer/VBoxContainer/Attack
@onready var move := $Main/Panel/MarginContainer/VBoxContainer/Move
@onready var passB := $Main/Panel/MarginContainer/VBoxContainer/Pass
@onready var take_aim := $SubAttack/Panel/MarginContainer/VBoxContainer/TakeAim
@onready var reload := $SubAttack/Panel/MarginContainer/VBoxContainer/Reload
@onready var single_shot := $SubAttack/Panel/MarginContainer/VBoxContainer/SingleShot
@onready var burst_shot := $SubAttack/Panel/MarginContainer/VBoxContainer/BurstShot
@onready var grenade := $SubAttack/Panel/MarginContainer/VBoxContainer/Grenade

@onready var status_name = $Main/Information/MarginContainer/VBoxContainer/HBoxContainer2/StatusName
@onready var status_health = $Main/Information/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/StatusHealth
@onready var status_aim = $Main/Information/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/StatusAim
@onready var status_cover = $Main/Information/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/StatusCover
@onready var status_ammo = $Main/Information/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/StatusAmmo

@onready var ui_sfx = $UI_SFX

const BUTTON = preload("res://Assets/UI/button.tscn")

var _character : BaseCharacter
var _enemies : Array[BaseCharacter]
var attackType : String
var moveable_area : Area2D

enum State {MAINMENU, ATTACKMENU, TARGETMENU, CONFIRMTARGETMENU, MOVEMENU}
var currentState : State

var _currentTarget : BaseCharacter
var _currentTargetSelectableArea : Area2D
var _currentTargetRedHighlight : NinePatchRect

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

## Associates a player character as the receiver of the resultant input and resets
## all menu states
## must be called each time this action chooser is used
## [param character] BaseCharacter that is requesting user input
func Initialize(character : BaseCharacter):
	_character = character
	moveable_area = _character.find_child("MovableArea")
	_enemies = game_manager.current_enemies
	hud_combat_state_changed.emit(character, null)
	ResetAllMenus()
	BuildStatusInfo(character)
	ChangeMenuState(State.MAINMENU)

## emits action_chosen signal to connected PlayerCharacter finalizing the user input
## as the chosen action. See [method PlayerCharacter._on_action_chosen]
## [param action] string value representing the chosen action
## [param data] generalized additional data needed to complete the chosen action
func ActionChosen(action : String, data):
	PlayPositiveSound()
	ResetAllMenus()
	visible = false
	action_chosen.emit(action, data)

## hides all menus except the main menu and checks each button for whether it should
## be disabled or not
func ResetAllMenus():
	main_menu.visible = true
	sub_attack_menu.visible = false
	cancel_button.visible = false
	moveable_area.visible = false
	IsDisabledCheck()

## Depreciated (for now). Updates an unused status information dump panel
func BuildStatusInfo(character : BaseCharacter):
	status_name.text = character.name
	status_health.text = "Health: " + str(character.currentHealth) + " (" + str(character.getHealthPenalty()) + ")"
	var aimStatus = "Yes (" if character.aimModifier > 0 else "No ("
	status_aim.text = "Aim: " + aimStatus + str(character.aimModifier) + ")"
	var covertStatus = "Yes (3)" if character.hasCover > 0 else "No (0)"
	status_cover.text = "Cover: " + covertStatus
	status_ammo.text = "Ammo: " + str(character.currentWeaponAmmo)

## Aggregate function that calls each individual buttons method to check if it should
## be disabled
func IsDisabledCheck():
	AttackDisabledCheck()
	SingleShotDisabledCheck()
	BurstShotDisabledCheck()
	GrenadeDisabledCheck()
	ReloadDisabledCheck()
	MoveDisabledCheck()
	TakeAimDisabledCheck()
	passB.disabled = false

## On non-finalizing button pressed this method will change the menu configuration
## to what was chosen.
##
## On any configuration but the main menu a cancel button is made visible in the upper
## right
## [param state] enum representing the 5 possible menu configurations
func ChangeMenuState(state : State):
	main_menu.visible = false
	sub_attack_menu.visible = false
	match state:
		State.MAINMENU:
			currentState = State.MAINMENU
			main_menu.visible = true
			moveable_area.visible = false
			cancel_button.visible = false
		State.ATTACKMENU:
			PlayPositiveSound()
			currentState = State.ATTACKMENU
			sub_attack_menu.visible = true
			cancel_button.visible = true
		State.TARGETMENU:
			PlayPositiveSound()
			currentState = State.TARGETMENU
			ConnectToEnemies()
			cancel_button.visible = true
		State.CONFIRMTARGETMENU:
			PlayPositiveSound()
			hud_combat_state_changed.emit(_character, _currentTarget)
			currentState = State.CONFIRMTARGETMENU
			DisconnectFromEnemies()
			cancel_button.visible = true
		State.MOVEMENU:
			PlayPositiveSound()
			moveable_area.visible = true
			currentState = State.MOVEMENU
			cancel_button.visible = true

## Returns to a parent menu state depending on what menu state is active when
## the cancel button is pressed
func _on_cancel_pressed():
	PlayNegativeSound()
	match currentState:
		State.ATTACKMENU:
			ChangeMenuState(State.MAINMENU)
		State.TARGETMENU:
			DisconnectFromEnemies()
			ChangeMenuState(State.ATTACKMENU)
		State.CONFIRMTARGETMENU:
			hud_combat_state_changed.emit(_character, null)
			_currentTargetSelectableArea.disconnect("input_event", _on_confirm_enemy_select_input_event)
			ChangeMenuState(State.TARGETMENU)
		State.MOVEMENU:
			CancelMove()
			ChangeMenuState(State.MAINMENU)

## Connects to each enemies selectable area to allow the user to click directly
## on the enemy to select them. Also activates red pusling highlight
func ConnectToEnemies():
	for enemy in _enemies:
				print(enemy.name, " connected")
				var clickArea := enemy.find_child("SelectableArea")
				var redHighlight := enemy.find_child("HighlightRed")
				redHighlight.visible = true
				redHighlight.get_child(0).play("pulse")
				clickArea.connect("input_event", _on_enemy_select_input_event.bind(enemy))

## Disconnects the enemies from user input and removes red pulsing highlight
func DisconnectFromEnemies():
	for enemy in _enemies:
				print(enemy.name, " connected")
				var clickArea := enemy.find_child("SelectableArea")
				var redHighlight := enemy.find_child("HighlightRed")
				redHighlight.visible = false
				redHighlight.get_child(0).stop()
				clickArea.disconnect("input_event", _on_enemy_select_input_event)

#region button disabled checks
## Checks if the Take Aim button should be disabled or not
func TakeAimDisabledCheck():
	#TODO: implement take aim in character controllers
	if _character.aimModifier > 0 or _character.currentWeaponAmmo <= 0:
		take_aim.disabled = true
	else:
		take_aim.disabled = false

## Checks if the Attack button should be disabled or not
func AttackDisabledCheck():
	if _character.currentActionPoints < _character.singleShotCost:
		attack.disabled = true
	else: attack.disabled = false

## Checks if the Single Shot button should be disabled or not
func SingleShotDisabledCheck():
	if _character.currentActionPoints < _character.singleShotCost or \
	_character.currentWeaponAmmo < 1:
		single_shot.disabled = true
	else: single_shot.disabled = false

## Checks if the Burst Shot button should be disabled or not
func BurstShotDisabledCheck():
	if _character.currentActionPoints < _character.burstShotCost or \
	_character.currentWeaponAmmo < 3:
		burst_shot.disabled = true
	else: burst_shot.disabled = false

## Checks if the Grenade button should be disabled or not
func GrenadeDisabledCheck():
	if _character.currentActionPoints < _character.grenadeCost or \
	_character.currentCombatArea.currentlyActiveGrenade != null or \
	_character.grenadeAmmo < 1:
		grenade.disabled = true
	else: grenade.disabled = false

## Checks if the Reload button should be disabled or not
func ReloadDisabledCheck():
	if _character.currentActionPoints < _character.reloadCost or \
	_character.currentWeaponAmmo >= 3:
		reload.disabled = true
	else: reload.disabled = false

## Checks if the Move button should be disabled or not
func MoveDisabledCheck():
	if _character.currentActionPoints < _character.moveCost:
		move.disabled = true
	else: move.disabled = false

## Simply enables the pass button since it should never be disabled
func PassDisabledCheck():
	passB.disabled = false
#endregion

func _on_attack_pressed():
	ChangeMenuState(State.ATTACKMENU)

## connects to the moveable area that surrounds the character and hides the menu
func _on_move_pressed():
	print("move pressed")
	moveable_area.connect("input_event", _on_move_location_chosen)
	ChangeMenuState(State.MOVEMENU)

## disconnects from the movable area surrounding the character. Disabling user
## input
func CancelMove():
	moveable_area.disconnect("input_event", _on_move_location_chosen)
	ChangeMenuState(State.MAINMENU)

func _on_move_location_chosen(_viewport: Node, event: InputEvent, _shape_idx: int):
	if event.is_action_pressed("Move"):
		var moveTo : Vector2 = _character.get_canvas_transform().affine_inverse() * event.position
		moveable_area.visible = false
		moveable_area.disconnect("input_event", _on_move_location_chosen)
		ActionChosen("move", moveTo)
			
	

func _on_pass_pressed():
	ActionChosen("pass", null)


func _on_take_aim_pressed():
	ActionChosen("takeaim", null)

# TODO: functionize this as it's copied 3 times
func _on_single_shot_pressed():
	ChangeMenuState(State.TARGETMENU)
	attackType = "shootsingle"


func _on_burst_shot_pressed():
	ChangeMenuState(State.TARGETMENU)
	attackType = "shootburst"


func _on_grenade_pressed():
	ChangeMenuState(State.TARGETMENU)
	attackType = "grenade"

func _on_reload_pressed():
	ActionChosen("reload", null)

# first step, activated on chose one enemy of those available
func _on_enemy_select_input_event(_viewport, event : InputEvent, _shape_rid, enemy : BaseCharacter):
	if event.is_action_pressed("Move"):
		_currentTarget = enemy
		_currentTargetSelectableArea = _currentTarget.find_child("SelectableArea")
		_currentTargetRedHighlight = _currentTarget.find_child("HighlightRed")
		ChangeMenuState(State.CONFIRMTARGETMENU)
		_currentTargetRedHighlight.visible = true
		_currentTargetSelectableArea.connect("input_event", _on_confirm_enemy_select_input_event)

# second step, confirm the chosen enemy by selecting them again
func _on_confirm_enemy_select_input_event(_viewport, event : InputEvent, _shape_rid):
	if event.is_action_pressed("Move"):
		_currentTargetRedHighlight.visible = false
		_currentTargetSelectableArea.disconnect("input_event", _on_confirm_enemy_select_input_event)
		ActionChosen(attackType, _currentTarget)
		

func PlayPositiveSound():
	ui_sfx.stream = ui_positive
	ui_sfx.play()
	
func PlayNegativeSound():
	ui_sfx.stream = ui_negative
	ui_sfx.play()
