extends Control

signal action_chosen(action : String, data)

@onready var sub_attack : Control = $SubAttack
@onready var targets : Control = $Targets
@onready var targets_v_box_container = $Targets/Panel/MarginContainer/TargetsVBoxContainer


@onready var attack := $Main/Panel/MarginContainer/VBoxContainer/Attack
@onready var move := $Main/Panel/MarginContainer/VBoxContainer/Move
@onready var passB := $Main/Panel/MarginContainer/VBoxContainer/Pass
@onready var flee := $Main/Panel/MarginContainer/VBoxContainer/Flee
@onready var reload := $SubAttack/Panel/MarginContainer/VBoxContainer/Reload
@onready var single_shot := $SubAttack/Panel/MarginContainer/VBoxContainer/SingleShot
@onready var burst_shot := $SubAttack/Panel/MarginContainer/VBoxContainer/BurstShot
@onready var grenade := $SubAttack/Panel/MarginContainer/VBoxContainer/Grenade

const BUTTON = preload("res://Assets/UI/button.tscn")

var _character : BaseCharacter
var _enemies : Array[BaseCharacter]
var attackType : String
var moveable_area : Area2D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

#must be called each time this action chooser is used
func Initialize(character : BaseCharacter):
	_character = character
	_enemies = GameManager.current_enemies
	ResetAllMenus()
	ConstructTargetMenu()

func ResetAllMenus():
	sub_attack.visible = false
	targets.visible = false
	attack.text = "Attack"
	single_shot.text = "Single\nShot"
	burst_shot.text = "Burst\nShot"
	grenade.text = "Grenade"
	AllDisabledCheck(false)

func ActionChosen(action : String, data):
	DeconstructTargetMenu()
	ResetAllMenus()
	visible = false
	action_chosen.emit(action, data)

func AllDisabledCheck(doDisable : bool):
	AttackDisabledCheck(doDisable)
	SingleShotDisabledCheck(doDisable)
	BurstShotDisabledCheck(doDisable)
	GrenadeDisabledCheck(doDisable)
	ReloadDisabledCheck(doDisable)
	MoveDisabledCheck(doDisable)
	FleeDisabledCheck(doDisable)
	passB.disabled = doDisable

func AllButOneDisabledCheck(doDisable : bool, one):
	pass

#region button disabled checks
func FleeDisabledCheck(doDisable : bool):
	if _character.currentHealth > _character.maxHealth / 2:
		flee.disabled = true
	else:
		flee.disabled = doDisable

func AttackDisabledCheck(doDisable : bool):
	if _character.currentActionPoints < _character.singleShotCost:
		attack.disabled = true
	else: attack.disabled = doDisable

func SingleShotDisabledCheck(doDisable : bool):
	if _character.currentActionPoints < _character.singleShotCost or \
	_character.currentWeaponAmmo < 1:
		single_shot.disabled = true
	else: single_shot.disabled = doDisable

func BurstShotDisabledCheck(doDisable : bool):
	if _character.currentActionPoints < _character.burstShotCost or \
	_character.currentWeaponAmmo < 3:
		burst_shot.disabled = true
	else: burst_shot.disabled = doDisable
	
func GrenadeDisabledCheck(doDisable : bool):
	if _character.currentActionPoints < _character.grenadeCost:
		grenade.disabled = true
	else: grenade.disabled = doDisable

func ReloadDisabledCheck(doDisable : bool):
	if _character.currentActionPoints < _character.reloadCost or \
	_character.currentWeaponAmmo >= 3:
		reload.disabled = true
	else: reload.disabled = doDisable

func MoveDisabledCheck(doDisable : bool):
	if _character.currentActionPoints < _character.moveCost:
		move.disabled = true
	else: move.disabled = doDisable

func PassDisabledCheck(doDisable : bool):
	passB.disabled = doDisable
#endregion

func ConstructTargetMenu():
	for i in range(_enemies.size()):
		var enemy := _enemies[i]
		var newButton = BUTTON.instantiate()
		newButton.text = enemy.name
		newButton.name = enemy.name
		newButton.targetId = i
		targets_v_box_container.add_child(newButton)
		newButton.connect("pressed_with_info", _on_enemy_target_pressed_with_info)
		
func DeconstructTargetMenu():
	for n in targets_v_box_container.get_children():
		n.queue_free()


func _on_attack_pressed():
	if sub_attack.visible:
		AttackMenuOpenState(false)
	else:
		AttackMenuOpenState(true)

func AttackMenuOpenState(isOpen : bool):
	sub_attack.visible = isOpen
	attack.text = "Cancel" if isOpen else "Attack"
	AttackDisabledCheck(false)
	MoveDisabledCheck(isOpen)
	PassDisabledCheck(isOpen)
	FleeDisabledCheck(isOpen)
	ReloadDisabledCheck(false)
	SingleShotDisabledCheck(false)
	BurstShotDisabledCheck(false)
	GrenadeDisabledCheck(false)
	single_shot.text = "Single\nShot"
	burst_shot.text = "Burst\nShot"
	grenade.text = "Grenade"

func _on_move_pressed():
	moveable_area = _character.find_child("MovableArea")
	moveable_area.visible = true
	visible = false
	get_node("../../MovableArea").connect("input_event", _on_move_location_chosen)

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
			print(points[0]["collider"].name)
			moveable_area.visible = false
			get_node("../../MovableArea").disconnect("input_event", _on_move_location_chosen)
			ActionChosen("move", moveTo)
			
	

func _on_pass_pressed():
	ActionChosen("pass", null)


func _on_flee_pressed():
	ActionChosen("flee", null)

# TODO: functionize this as it's copied 3 times
func _on_single_shot_pressed():
	if targets.visible:
		targets.visible = false
		AttackMenuOpenState(true)
	else:
		targets.visible = true
		single_shot.text = "Cancel"
		AllDisabledCheck(true)
		SingleShotDisabledCheck(false)
		attackType = "shootsingle"


func _on_burst_shot_pressed():
	if targets.visible:
		targets.visible = false
		AttackMenuOpenState(true)
	else:
		targets.visible = true
		burst_shot.text = "Cancel"
		AllDisabledCheck(true)
		BurstShotDisabledCheck(false)
		attackType = "shootburst"


func _on_grenade_pressed():
	if targets.visible:
		targets.visible = false
		AttackMenuOpenState(true)
	else:
		targets.visible = true
		grenade.text = "Cancel"
		AllDisabledCheck(true)
		GrenadeDisabledCheck(false)
		attackType = "grenade"


func _on_reload_pressed():
	ActionChosen("reload", null)
	
func _on_enemy_target_pressed_with_info(button : Button):
	ActionChosen(attackType, button.targetId)
