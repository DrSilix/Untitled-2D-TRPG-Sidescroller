extends Control

signal action_chosen(action : String, data)

@onready var sub_attack : Control = $SubAttack
@onready var targets : Control = $Targets
@onready var targets_v_box_container = $Targets/Panel/MarginContainer/TargetsVBoxContainer

@onready var attack := $Main/Panel/Attack
@onready var move := $Main/Panel/Move
@onready var passB := $Main/Panel/Pass
@onready var flee := $Main/Panel/Flee
@onready var reload := $SubAttack/Panel/Reload
@onready var single_shot := $SubAttack/Panel/SingleShot
@onready var burst_shot := $SubAttack/Panel/BurstShot
@onready var grenade := $SubAttack/Panel/Grenade

const BUTTON = preload("res://Assets/UI/button.tscn")

var _character : BaseCharacter
var _enemies : Array[BaseCharacter]
var attackType : String

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
	FleeDisabledCheck(false)
	sub_attack.visible = false
	targets.visible = false
	

func ActionChosen(action : String, data):
	action_chosen.emit(action, data)
	visible = false

func FleeDisabledCheck(value : bool):
	if _character.currentHealth > _character.maxHealth / 2:
		flee.disabled = true
	else:
		flee.disabled = value

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
		sub_attack.visible = false
		attack.text = "Attack"
		move.disabled = false
		passB.disabled = false
		#FleeDisabledCheck(false)
	else:
		sub_attack.visible = true
		attack.text = "Cancel"
		move.disabled = true
		passB.disabled = true
		#FleeDisabledCheck(true)
		reload.disabled = false if _character.currentWeaponAmmo <= 3 else true
		single_shot.disabled = false if _character.currentWeaponAmmo >= 1 else true
		burst_shot.disabled = false if _character.currentWeaponAmmo >= 3 else true
		single_shot.text = "Single\nShot"
		burst_shot.text = "Burst\nShot"
		grenade.text = "Grenade"
		grenade.disabled = false


func _on_move_pressed():
	pass # Replace with function body.


func _on_pass_pressed():
	ActionChosen("pass", null)


func _on_flee_pressed():
	ActionChosen("flee", null)

# TODO: functionize this as it's copied 3 times
func _on_single_shot_pressed():
	if targets.visible:
		targets.visible = false
		single_shot.text = "Single\nShot"
		attack.disabled = false
		burst_shot.disabled = false
		grenade.disabled = false
		reload.disabled = false
	else:
		targets.visible = true
		single_shot.text = "Cancel"
		attack.disabled = true
		burst_shot.disabled = true
		grenade.disabled = true
		reload.disabled = true
		attackType = "shootsingle"


func _on_burst_shot_pressed():
	if targets.visible:
		targets.visible = false
		burst_shot.text = "Burst\nShot"
		attack.disabled = false
		single_shot.disabled = false
		grenade.disabled = false
		reload.disabled = false
	else:
		targets.visible = true
		burst_shot.text = "Cancel"
		attack.disabled = true
		single_shot.disabled = true
		grenade.disabled = true
		reload.disabled = true
		attackType = "shootburst"


func _on_grenade_pressed():
	if targets.visible:
		targets.visible = false
		grenade.text = "Grenade"
		attack.disabled = false
		burst_shot.disabled = false
		single_shot.disabled = false
		reload.disabled = false
	else:
		targets.visible = true
		grenade.text = "Cancel"
		attack.disabled = true
		burst_shot.disabled = true
		single_shot.disabled = true
		reload.disabled = true
		attackType = "grenade"


func _on_reload_pressed():
	ActionChosen("reload", null)
	
func _on_enemy_target_pressed_with_info(button : Button):
	ActionChosen(attackType, button.targetId)
