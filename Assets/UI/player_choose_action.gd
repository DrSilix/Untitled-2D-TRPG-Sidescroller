extends Control

signal action_chosen(action : String, data)

@export var ui_positive : AudioStreamWAV
@export var ui_negative : AudioStreamWAV

@onready var GameManager : GameManager = $/root/Node2D/GameManager

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

enum State {MAINMENU, ATTACKMENU, TARGETMENU, MOVEMENU}
var currentState : State

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

#must be called each time this action chooser is used
func Initialize(character : BaseCharacter):
	_character = character
	moveable_area = _character.find_child("MovableArea")
	_enemies = GameManager.current_enemies
	ResetAllMenus()
	BuildStatusInfo(character)
	ChangeMenuState(State.MAINMENU)

func ActionChosen(action : String, data):
	PlayPositiveSound()
	ResetAllMenus()
	visible = false
	action_chosen.emit(action, data)

func ResetAllMenus():
	main_menu.visible = true
	sub_attack_menu.visible = false
	cancel_button.visible = false
	moveable_area.visible = false
	IsDisabledCheck()

func BuildStatusInfo(char : BaseCharacter):
	status_name.text = char.name
	status_health.text = "Health: " + str(char.currentHealth) + " (" + str(char.getHealthPenalty()) + ")"
	var aimStatus = "Yes (" if char.aimModifier > 0 else "No ("
	status_aim.text = "Aim: " + aimStatus + str(char.aimModifier) + ")"
	var covertStatus = "Yes (3)" if char.hasCover > 0 else "No (0)"
	status_cover.text = "Cover: " + covertStatus
	status_ammo.text = "Ammo: " + str(char.currentWeaponAmmo)

func IsDisabledCheck():
	AttackDisabledCheck()
	SingleShotDisabledCheck()
	BurstShotDisabledCheck()
	GrenadeDisabledCheck()
	ReloadDisabledCheck()
	MoveDisabledCheck()
	TakeAimDisabledCheck()
	passB.disabled = false

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
			for enemy in _enemies:
				print(enemy.name, " connected")
				var clickArea := enemy.find_child("SelectableArea")
				clickArea.connect("input_event", _on_enemy_select_input_event.bind(enemy))
			cancel_button.visible = true
		State.MOVEMENU:
			PlayPositiveSound()
			moveable_area.visible = true
			currentState = State.MOVEMENU
			cancel_button.visible = true

func _on_cancel_pressed():
	PlayNegativeSound()
	match currentState:
		State.ATTACKMENU:
			ChangeMenuState(State.MAINMENU)
		State.TARGETMENU:
			ChangeMenuState(State.ATTACKMENU)
		State.MOVEMENU:
			CancelMove()
			ChangeMenuState(State.MAINMENU)

func ConnectToEnemies():
	for enemy in _enemies:
				print(enemy.name, " connected")
				var clickArea := enemy.find_child("SelectableArea")
				clickArea.connect("input_event", _on_enemy_select_input_event.bind(enemy))

func DisconnectFromEnemies():
	for enemy in _enemies:
				print(enemy.name, " connected")
				var clickArea := enemy.find_child("SelectableArea")
				clickArea.disconnect("input_event", _on_enemy_select_input_event)

#region button disabled checks
func TakeAimDisabledCheck():
	#TODO: implement take aim in character controllers
	if _character.aimModifier > 0 or _character.currentWeaponAmmo <= 0:
		take_aim.disabled = true
	else:
		take_aim.disabled = false

func AttackDisabledCheck():
	if _character.currentActionPoints < _character.singleShotCost:
		attack.disabled = true
	else: attack.disabled = false

func SingleShotDisabledCheck():
	if _character.currentActionPoints < _character.singleShotCost or \
	_character.currentWeaponAmmo < 1:
		single_shot.disabled = true
	else: single_shot.disabled = false

func BurstShotDisabledCheck():
	if _character.currentActionPoints < _character.burstShotCost or \
	_character.currentWeaponAmmo < 3:
		burst_shot.disabled = true
	else: burst_shot.disabled = false
	
func GrenadeDisabledCheck():
	if _character.currentActionPoints < _character.grenadeCost or \
	_character.currentCombatArea.currentlyActiveGrenade != null:
		grenade.disabled = true
	else: grenade.disabled = false

func ReloadDisabledCheck():
	if _character.currentActionPoints < _character.reloadCost or \
	_character.currentWeaponAmmo >= 3:
		reload.disabled = true
	else: reload.disabled = false

func MoveDisabledCheck():
	if _character.currentActionPoints < _character.moveCost:
		move.disabled = true
	else: move.disabled = false

func PassDisabledCheck():
	passB.disabled = false
#endregion


func _on_attack_pressed():
	ChangeMenuState(State.ATTACKMENU)

func _on_move_pressed():
	print("move pressed")
	moveable_area.connect("input_event", _on_move_location_chosen)
	ChangeMenuState(State.MOVEMENU)

func CancelMove():
	moveable_area.disconnect("input_event", _on_move_location_chosen)
	ChangeMenuState(State.MAINMENU)

func _on_move_location_chosen(viewport: Node, event: InputEvent, shape_idx: int):
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
	
func _on_enemy_select_input_event(viewport, event : InputEvent, shape_rid, enemy : BaseCharacter):
	if event.is_action_pressed("Move"):
		DisconnectFromEnemies()
		ActionChosen(attackType, enemy)

func PlayPositiveSound():
	ui_sfx.stream = ui_positive
	ui_sfx.play()
	
func PlayNegativeSound():
	ui_sfx.stream = ui_negative
	ui_sfx.play()
