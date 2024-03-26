extends Control

signal action_chosen(action : String, data)

@onready var main_menu := $Main
@onready var sub_attack_menu := $SubAttack
@onready var targets_menu := $Targets
@onready var targets_v_box_container := $Targets/Panel/MarginContainer/TargetsVBoxContainer
@onready var cancel_button = $CancelButton/Cancel

@onready var attack := $Main/Panel/MarginContainer/VBoxContainer/Attack
@onready var move := $Main/Panel/MarginContainer/VBoxContainer/Move
@onready var passB := $Main/Panel/MarginContainer/VBoxContainer/Pass
@onready var take_aim := $SubAttack/Panel/MarginContainer/VBoxContainer/TakeAim
@onready var reload := $SubAttack/Panel/MarginContainer/VBoxContainer/Reload
@onready var single_shot := $SubAttack/Panel/MarginContainer/VBoxContainer/SingleShot
@onready var burst_shot := $SubAttack/Panel/MarginContainer/VBoxContainer/BurstShot
@onready var grenade := $SubAttack/Panel/MarginContainer/VBoxContainer/Grenade

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
	ChangeMenuState(State.MAINMENU)

func ActionChosen(action : String, data):
	ResetAllMenus()
	visible = false
	action_chosen.emit(action, data)

func ResetAllMenus():
	main_menu.visible = true
	sub_attack_menu.visible = false
	cancel_button.visible = false
	moveable_area.visible = false
	IsDisabledCheck()

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
			currentState = State.ATTACKMENU
			sub_attack_menu.visible = true
			cancel_button.visible = true
		State.TARGETMENU:
			currentState = State.TARGETMENU
			for enemy in _enemies:
				print(enemy.name, " connected")
				var clickArea := enemy.find_child("SelectableArea")
				clickArea.connect("input_event", _on_enemy_select_input_event.bind(enemy))
			cancel_button.visible = true
		State.MOVEMENU:
			moveable_area.visible = true
			currentState = State.MOVEMENU
			cancel_button.visible = true

func _on_cancel_pressed():
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
	if _character.currentHealth > _character.maxHealth / 2:
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
	if _character.currentActionPoints < _character.grenadeCost:
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
	get_node("../../MovableArea").connect("input_event", _on_move_location_chosen)
	ChangeMenuState(State.MOVEMENU)

func CancelMove():
	get_node("../../MovableArea").disconnect("input_event", _on_move_location_chosen)
	ChangeMenuState(State.MAINMENU)

func _on_move_location_chosen(viewport: Node, event: InputEvent, shape_idx: int):
	if event.is_action_pressed("Move"):
		var moveTo : Vector2 = _character.get_canvas_transform().affine_inverse() * event.position
		var physics = get_world_2d().get_direct_space_state()
		var query = PhysicsPointQueryParameters2D.new()
		query.position = moveTo
		query.collide_with_areas = true
		query.collide_with_bodies = false
		query.collision_mask = 0b00000000_00000000_00000000_00000010
		var points : Array[Dictionary] = physics.intersect_point(query)
		if points.size() > 0:
			#print(points.size(), " - ", points[0]["collider"].name)
			moveable_area.visible = false
			get_node("../../MovableArea").disconnect("input_event", _on_move_location_chosen)
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
