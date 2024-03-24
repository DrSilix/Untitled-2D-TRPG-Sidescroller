class_name BaseCharacter
extends CharacterBody2D

@export var moveSpeed : int = 6
@export var maxHealth : int = 9
@export var armor : int = 10
@export var chanceToHitModifier : int = 0
@export var weaponSkill : int = 12
@export var weaponDamage : int = 6
@export var maxWeaponAmmo : int = 6
@export var maxActionPoints : int = 6

@export_group("Action Costs")
@export var moveCost := 3
@export var fleeCost := 0
@export var singleShotCost := 3
@export var burstShotCost := 6
@export var grenadeCost := 6
@export var reloadCost := 3

@onready var spriteRootNode : Node2D = $SpriteRoot
@onready var animationPlayer : AnimationPlayer = $SpriteRoot/AnimationPlayer

enum {IDLE, WALKING, RUNNING, ATTACKING, ATTACKING_TWO, RELOADING, HURT, DEATH}
var activeState := IDLE

enum CombatActions {ATTACK, SHOOTSINGLE, SHOOTBURST, GRENADE, MOVE, RELOAD, FLEE, PASS}
var currentChosenAction : CombatActions

var hasCover = false
var currentHealth : int = maxHealth
var currentActionPoints : int = maxActionPoints
var currentWeaponAmmo : int = maxWeaponAmmo
var moveTarget : Vector2

var currentCombatArea : CombatArea

func _ready():
	animationPlayer.connect("animation_finished", _on_AnimationPlayer_animation_finished,)

func MoveTo(location :Vector2):
	moveTarget = location
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
		CombatActions.MOVE:
			MoveAction()
			# TODO: somehow wait for move to finish. signals??
		CombatActions.FLEE:
			FleeAction()
		CombatActions.PASS:
			PassAction()
			
	print("Actions points: ", currentActionPoints)
	if currentActionPoints > 0: ChooseCombatAction(currentCombatArea)
	else:
		currentActionPoints = maxActionPoints
		currentCombatArea.CallNextCombatantToTakeTurn()
		
#region Action Processing	
func ShootSingleAction():
	currentActionPoints -= singleShotCost
	currentWeaponAmmo -= 1
	activeState = ATTACKING
	print("Shooting Single")

func ShootBurstAction():
	currentActionPoints -= burstShotCost
	currentWeaponAmmo -= 3 if currentWeaponAmmo >= 3 else currentWeaponAmmo
	activeState = ATTACKING_TWO
	print("Shooting Burst")

func GrenadeAction():
	currentActionPoints -= grenadeCost
	print("Throwing Grenade")

func ReloadAction():
	currentActionPoints -= reloadCost if currentActionPoints >= reloadCost else currentActionPoints
	activeState = RELOADING
	currentWeaponAmmo = maxWeaponAmmo

func MoveAction():
	currentActionPoints -= moveCost
	MoveTo(moveTarget)
	print("Moving")

func FleeAction():
	currentActionPoints = 0
	print("Fleeing")

func PassAction():
	currentActionPoints = 0
	print("Passing Turn")
#endregion

func TakeCover():
	hasCover = true
	chanceToHitModifier = -3

func LeaveCover():
	hasCover = false
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


func AttackTarget(target : BaseCharacter):
	var toHit : int = RollToHit()
	var toAvoid : int = target.RollToAvoidAttack()
	if toAvoid >= toHit: return -1
	var damageToDeal : int = CalculateDamageToDeal(toHit - toAvoid)
	var damagetToResist : int = target.RollToResistDamage()
	if damagetToResist >= damageToDeal: return -2
	target.TakeDamage(damageToDeal - damagetToResist)
	return damageToDeal - damagetToResist

# ??Factor in distance to shoot??
func RollToHit():
	return RollUtil.GetRoll(weaponSkill + getHealthBonus())

func CalculateDamageToDeal(netHits : int):
	return weaponDamage + netHits

func RollToAvoidAttack():
	return RollUtil.GetRoll(moveSpeed + getHealthBonus()) + chanceToHitModifier

func RollToResistDamage():
	return RollUtil.GetRoll(armor + getHealthBonus())

func TakeDamage(damage: int):
	currentHealth -= damage
	activeState = HURT if currentHealth > 0 else DEATH
#endregion

func _physics_process(delta):

	match activeState:
		IDLE:
			animationPlayer.play("Idle")
			velocity = Vector2.ZERO
		WALKING:
			animationPlayer.play("Walk")
			velocity = position.direction_to(moveTarget) * moveSpeed * 10
			spriteRootNode.scale.x = 1 if velocity.x > 0 else -1
			move_and_slide()
			z_index = (position.y as int) - 30
			if position.distance_squared_to(moveTarget) < 80:
					activeState = IDLE
		RUNNING:
			animationPlayer.play("Run")
			velocity = position.direction_to(moveTarget) * moveSpeed * 20
			spriteRootNode.scale.x = 1 if velocity.x > 0 else -1
			move_and_slide()
			z_index = (position.y as int) - 30
			if position.distance_squared_to(moveTarget) < 80:
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
		DEATH:
			animationPlayer.play("Death")
		_:
			pass

func _on_AnimationPlayer_animation_finished(anim_name):
	activeState = IDLE
