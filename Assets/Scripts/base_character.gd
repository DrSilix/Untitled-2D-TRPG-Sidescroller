class_name BaseCharacter
extends CharacterBody2D

@export var moveSpeed : int = 6
@export var maxHealth : int = 9
@export var armor : int = 10
@export var chanceToHitModifier : int = 0
@export var weaponSkill : int = 12
@export var weaponDamage : int = 6
@export var maxWeaponAmmo : int = 30
@export var maxActionPoints : int = 6

@onready var spriteRootNode : Node2D = $SpriteRoot
@onready var animationPlayer : AnimationPlayer = $SpriteRoot/AnimationPlayer

enum {IDLE, WALKING, RUNNING, ATTACKING, HURT, DEATH}
var activeState := IDLE

enum CombatActions {ATTACK, SHOOTSINGLE, SHOOTBURST, GRENADE, MOVE, RELOAD, FLEE, PASS}
var currentChosenAction : CombatActions

var hasCover = false
var currentHealth : int = maxHealth
var currentActionPoints : int = maxActionPoints
var currentWeaponAmmo : int = maxWeaponAmmo
var moveTarget : Vector2

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


func ChooseCombatAction():
	pass

func CompleteChosenAction():
	pass

func TakeCover():
	hasCover = true
	chanceToHitModifier = -3

func LeaveCover():
	hasCover = false
	chanceToHitModifier = 0


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
		HURT:
			animationPlayer.play("Hurt")
			velocity = Vector2.ZERO
		DEATH:
			animationPlayer.play("Death")
		_:
			pass

func _on_AnimationPlayer_animation_finished(anim_name):
	activeState = IDLE
