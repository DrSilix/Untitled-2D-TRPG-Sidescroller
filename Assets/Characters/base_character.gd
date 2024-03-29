class_name BaseCharacter
extends CharacterBody2D

signal action_finished
signal move_completed

#region variables
@export var moveSpeed : int = 6
@export var maxHealth : int = 9
@export var armor : int = 8
@export var chanceToHitModifier : int = 0
@export var weaponSkill : int = 12
@export var weaponDamage : int = 6
@export var maxWeaponAmmo : int = 6
@export var maxActionPoints : int = 6

@export_group("Action Costs")
@export var moveCost := 3
@export var takeAimCost := 3
@export var singleShotCost := 3
@export var burstShotCost := 6
@export var grenadeCost := 6
@export var reloadCost := 3

@onready var spriteRootNode : Node2D = $SpriteRoot
@onready var navigation_agent_2d : NavigationAgent2D = $NavigationAgent2D
@onready var animationPlayer : AnimationPlayer = $SpriteRoot/AnimationPlayer
@onready var cover_collision : Area2D = $CoverArea
@onready var cover_icon : Sprite2D = $CoverIcon
@onready var highlight_yellow : NinePatchRect = $HighlightYellow
@onready var highlight_red : NinePatchRect = $HighlightRed

@onready var main_status_bar = $StatusBar
@onready var health_bar : ProgressBar = $StatusBar/HealthBar
@onready var ap_bar : ProgressBar = $StatusBar/APBar
@onready var status_cover_icon : TextureRect = $StatusBar/CoverIcon
@onready var aim_icon : TextureRect = $StatusBar/AimIcon
@onready var ammo_bar : ProgressBar = $StatusBar/AmmoIcon/AmmoBar

enum {IDLE, WALKING, RUNNING, ATTACKING, ATTACKING_TWO, RELOADING, HURT, MISSED, RESISTED, DEATH}
var activeState := IDLE

enum CombatActions {ATTACK, SHOOTSINGLE, SHOOTBURST, GRENADE, MOVE, RELOAD, TAKEAIM, PASS}
var currentChosenAction : CombatActions

var hasCover : int = 0
var aimModifier = 0
var currentHealth : int
var currentActionPoints : int
var currentWeaponAmmo : int
var moveTarget : Vector2
var attackTarget : BaseCharacter

var currentCombatArea : CombatArea
#endregion
func _ready():
	currentHealth = maxHealth
	currentActionPoints = maxActionPoints
	currentWeaponAmmo = maxWeaponAmmo
	animationPlayer.connect("animation_finished", _on_AnimationPlayer_animation_finished,)
	cover_collision.connect("body_entered", _on_cover_area_body_entered)
	cover_collision.connect("body_exited", _on_cover_area_body_exited)

func MoveTo(location :Vector2):
	moveTarget = location
	moveTarget = NavigationServer2D.map_get_closest_point(navigation_agent_2d.get_navigation_map(), moveTarget)
	navigation_agent_2d.target_position = moveTarget
	activeState = WALKING

func HaltActions():
	velocity = Vector2.ZERO
	activeState = IDLE

func MoveVelocity(velocity :Vector2):
	pass

func ChooseCombatAction(combatArea : CombatArea):
	currentCombatArea = combatArea
	pass

func CompleteChosenAction():
	await get_tree().create_timer(0.2).timeout
	#do this if moving
	match currentChosenAction:
		CombatActions.SHOOTSINGLE:
			ShootSingleAction()
		CombatActions.SHOOTBURST:
			ShootBurstAction()
		CombatActions.GRENADE:
			GrenadeAction()
		CombatActions.RELOAD:
			ReloadAction()
		CombatActions.TAKEAIM:
			TakeAimAction()
		CombatActions.MOVE:
			MoveAction()
			# TODO: somehow wait for move to finish. signals??
		CombatActions.PASS:
			PassAction()
	
	#this await is here to ensure that the consequences of this action for potential
	#targets is finished before possibly continuing into their turn
	"""await get_tree().create_timer(1).timeout
	print("Actions points: ", currentActionPoints)
	highlight_yellow.visible = false
	if currentActionPoints > 0: ChooseCombatAction(currentCombatArea)
	else: currentCombatArea.CallNextCombatantToTakeTurn()"""
		
func _on_action_completed():
	print("Actions points: ", currentActionPoints)
	highlight_yellow.visible = false
	if currentActionPoints > 0: ChooseCombatAction(currentCombatArea)
	else: currentCombatArea.CallNextCombatantToTakeTurn()

#region Action Processing	
func ShootSingleAction():
	print("Shooting Single - Aim=", aimModifier)
	currentActionPoints -= singleShotCost
	currentWeaponAmmo -= 1
	activeState = ATTACKING
	attackTarget.connect("action_finished", _on_action_completed, CONNECT_ONE_SHOT)
	var dmgDealt = await AttackTarget(attackTarget)
	aimModifier -= 1 if aimModifier <= 0 else 2
	if dmgDealt >= 0: print("Deals ", dmgDealt, " damage")
	elif dmgDealt == -1: print("Attack missed")
	elif dmgDealt == -2: print("Damage resisted")

func ShootBurstAction():
	print("Shooting Burst - Aim=", aimModifier)
	currentActionPoints -= burstShotCost
	currentWeaponAmmo -= 3 if currentWeaponAmmo >= 3 else currentWeaponAmmo
	activeState = ATTACKING_TWO
	attackTarget.connect("action_finished", _on_action_completed, CONNECT_ONE_SHOT)
	var dmgDealt = await AttackTarget(attackTarget)
	aimModifier -= 3
	if dmgDealt >= 0: print("Deals ", dmgDealt, " damage")
	elif dmgDealt == -1: print("Attack missed")
	elif dmgDealt == -2: print("Damage resisted")

func GrenadeAction():
	currentActionPoints -= grenadeCost
	print("Throwing Grenade")

func ReloadAction():
	currentActionPoints -= reloadCost if currentActionPoints >= reloadCost else currentActionPoints
	aimModifier = 0
	self.connect("action_finished", _on_action_completed, CONNECT_ONE_SHOT)
	activeState = RELOADING
	currentWeaponAmmo = maxWeaponAmmo
	
func TakeAimAction():
	aimModifier = 2
	currentActionPoints -= takeAimCost
	await get_tree().create_timer(0.5).timeout
	_on_action_completed()
	print("Taking Aim")

func MoveAction():
	currentActionPoints -= moveCost
	aimModifier = 0
	self.connect("move_completed", _on_action_completed, CONNECT_ONE_SHOT)
	MoveTo(moveTarget)
	print("Moving")

func PassAction():
	currentActionPoints = 0
	aimModifier = 0 if aimModifier < 0 else aimModifier
	await get_tree().create_timer(0.5).timeout
	_on_action_completed()
	print("Passing Turn")
#endregion

func TakeCover():
	hasCover += 1
	if hasCover > 1: return
	print("Taking cover")
	cover_icon.visible = true
	cover_icon.self_modulate.a = 0
	var tween = get_tree().create_tween()
	tween.tween_property(cover_icon, "self_modulate:a", 1, 0.5)
	tween.tween_property(cover_icon, "self_modulate:a", 1, 0.5)
	tween.tween_property(cover_icon, "self_modulate:a", 0, 3)
	chanceToHitModifier = -3

func LeaveCover():
	hasCover -= 1
	if hasCover > 0: return
	print("Leaving cover")
	cover_icon.visible = false
	chanceToHitModifier = 0

#region Attack Methods
# -2 for every 3, e.g:
# 7 8 9 = -0
# 4 5 6 = -2
# 1 2 3 = -4
func getHealthPenalty():
	return ((maxHealth - currentHealth) / 3) * -2

func getHealthBonus():
	return getHealthPenalty() + maxHealth


func AttackTarget(target : BaseCharacter) -> int:
	print(self.name, " attacks ", target.name)
	var attackResultDelayTime = 0.6
	SetFacingTowardsTarget(target)
	var toHit : int = RollToHit() + CalculateDistancePenalty(target)
	var hitPenalty = 0
	if currentChosenAction == CombatActions.SHOOTBURST:
		hitPenalty = -2
		attackResultDelayTime = 1.2
	var toAvoid : int = target.RollToAvoidAttack(hitPenalty)
	if toAvoid >= toHit:
		await get_tree().create_timer(attackResultDelayTime).timeout
		target.activeState = MISSED
		return -1
	var damageToDeal : int = CalculateDamageToDeal(toHit - toAvoid)
	var damagetToResist : int = target.RollToResistDamage()
	if damagetToResist >= damageToDeal:
		await get_tree().create_timer(attackResultDelayTime).timeout
		target.activeState = RESISTED
		return -2
	
	await get_tree().create_timer(attackResultDelayTime).timeout
	target.TakeDamage(damageToDeal - damagetToResist)
	return damageToDeal - damagetToResist

func CalculateDistancePenalty(target : BaseCharacter) -> int:
	var distanceSquared = global_position.distance_squared_to(target.global_position)
	print(-floor(distanceSquared/15000), " - ", distanceSquared/15000)
	return -floor(distanceSquared/15000)

# ??Factor in distance to shoot??
func RollToHit():
	return RollUtil.GetRoll(weaponSkill + getHealthBonus() + aimModifier)

func CalculateDamageToDeal(netHits : int):
	return weaponDamage + netHits

func RollToAvoidAttack(penaltyFromAttacker : int):
	return RollUtil.GetRoll(moveSpeed + getHealthBonus()) \
	+ penaltyFromAttacker - chanceToHitModifier

func RollToResistDamage():
	return RollUtil.GetRoll(armor + getHealthBonus())

func TakeDamage(damage: int):
	currentHealth -= damage
	activeState = HURT if currentHealth > 0 else DEATH
#endregion

func UpdateStatusPanel():
	health_bar.value = ceil((currentHealth as float / maxHealth as float) * 100)
	ap_bar.value = currentActionPoints
	status_cover_icon.visible = true if hasCover > 0 else false
	var goodColor = Color("#91ff7e")
	var badColor = Color("#d31f41")
	aim_icon.self_modulate = goodColor if aimModifier > 0 else badColor
	aim_icon.visible = false if aimModifier == 0 else true
	ammo_bar.value = ceil((currentWeaponAmmo as float / maxWeaponAmmo as float) * 100)

func _physics_process(delta):
	UpdateStatusPanel()
	match activeState:
		IDLE:
			animationPlayer.play("Idle")
			velocity = Vector2.ZERO
		WALKING:
			animationPlayer.play("Walk")
			#velocity = position.direction_to(moveTarget) * moveSpeed * 10
			var nextPathPos = navigation_agent_2d.get_next_path_position()
			velocity = position.direction_to(nextPathPos) * moveSpeed * 10
			spriteRootNode.scale.x = 1 if velocity.x > 0 else -1
			move_and_slide()
			z_index = (position.y as int) - 30
			if position.distance_squared_to(moveTarget) < 1:
				print("move complete")
				move_completed.emit()
				activeState = IDLE
		RUNNING:
			animationPlayer.play("Run")
			velocity = position.direction_to(moveTarget) * moveSpeed * 20
			spriteRootNode.scale.x = 1 if velocity.x > 0 else -1
			move_and_slide()
			z_index = (position.y as int) - 30
			if position.distance_squared_to(moveTarget) < 1:
				activeState = IDLE
		ATTACKING:
			if animationPlayer.current_animation != "Attack1": animationPlayer.play("Attack1")
			#print(animationPlayer.current_animation)
			velocity = Vector2.ZERO
		ATTACKING_TWO:
			if animationPlayer.current_animation != "Attack2": animationPlayer.play("Attack2")
			velocity = Vector2.ZERO
		RELOADING:
			if animationPlayer.current_animation != "Reloading": animationPlayer.play("Reloading")
			velocity = Vector2.ZERO
		HURT:
			animationPlayer.play("Hurt")
			velocity = Vector2.ZERO
		MISSED:
			animationPlayer.play("Missed")
			velocity = Vector2.ZERO
		RESISTED:
			animationPlayer.play("Resisted")
			velocity = Vector2.ZERO
		DEATH:
			RemoveFromCombatList()
			animationPlayer.play("Death")
		_:
			pass

func SetFacingTowardsTarget(target : BaseCharacter):
	if target.position.x >= position.x:
		spriteRootNode.scale.x = 1
	else:
		spriteRootNode.scale.x = -1

func RemoveFromCombatList():
	pass

func Die():
	action_finished.emit()
	print(self.name, " died")

func _on_AnimationPlayer_animation_finished(anim_name):
	print(name, " anim finished - ", anim_name, " - active state - ", activeState)
	action_finished.emit()
	activeState = IDLE
	
func _on_cover_area_body_entered(body):
	TakeCover()
	
func _on_cover_area_body_exited(body):
	LeaveCover()
