class_name BaseCharacter
extends CharacterBody2D
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
@export var fleeCost := 0
@export var singleShotCost := 3
@export var burstShotCost := 6
@export var grenadeCost := 6
@export var reloadCost := 3

@onready var spriteRootNode : Node2D = $SpriteRoot
@onready var animationPlayer : AnimationPlayer = $SpriteRoot/AnimationPlayer
@onready var cover_collision : Area2D = $CoverArea
@onready var cover_icon : Sprite2D = $CoverIcon
@onready var highlight_yellow : NinePatchRect = $HighlightYellow
@onready var highlight_red : NinePatchRect = $HighlightRed

enum {IDLE, WALKING, RUNNING, ATTACKING, ATTACKING_TWO, RELOADING, HURT, MISSED, RESISTED, DEATH}
var activeState := IDLE

enum CombatActions {ATTACK, SHOOTSINGLE, SHOOTBURST, GRENADE, MOVE, RELOAD, FLEE, PASS}
var currentChosenAction : CombatActions

var hasCover = false
var currentHealth : int = maxHealth
var currentActionPoints : int = maxActionPoints
var currentWeaponAmmo : int = maxWeaponAmmo
var moveTarget : Vector2
var attackTarget : BaseCharacter

var currentCombatArea : CombatArea
#endregion
func _ready():
	animationPlayer.connect("animation_finished", _on_AnimationPlayer_animation_finished,)
	cover_collision.connect("body_entered", _on_cover_area_body_entered)
	cover_collision.connect("body_exited", _on_cover_area_body_exited)

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
	
	#this await is here to ensure that the consequences of this action for potential
	#targets is finished before possibly continuing into their turn
	await get_tree().create_timer(1).timeout
	print("Actions points: ", currentActionPoints)
	highlight_yellow.visible = false
	if currentActionPoints > 0: ChooseCombatAction(currentCombatArea)
	else:
		currentActionPoints = maxActionPoints
		currentCombatArea.CallNextCombatantToTakeTurn()
		
#region Action Processing	
func ShootSingleAction():
	print("Shooting Single")
	currentActionPoints -= singleShotCost
	currentWeaponAmmo -= 1
	activeState = ATTACKING
	var dmgDealt = AttackTarget(attackTarget)
	if dmgDealt >= 0: print("Deals ", dmgDealt, " damage")
	elif dmgDealt == -1: print("Attack missed")
	elif dmgDealt == -2: print("Damage resisted")

func ShootBurstAction():
	print("Shooting Burst")
	currentActionPoints -= burstShotCost
	currentWeaponAmmo -= 3 if currentWeaponAmmo >= 3 else currentWeaponAmmo
	activeState = ATTACKING_TWO
	var dmgDealt = AttackTarget(attackTarget)
	if dmgDealt >= 0: print("Deals ", dmgDealt, " damage")
	elif dmgDealt == -1: print("Attack missed")
	elif dmgDealt == -2: print("Damage resisted")

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
	print("Taking cover")
	cover_icon.visible = true
	cover_icon.self_modulate.a = 0
	var tween = get_tree().create_tween()
	tween.tween_property(cover_icon, "self_modulate:a", 1, 0.5)
	tween.tween_property(cover_icon, "self_modulate:a", 1, 0.5)
	tween.tween_property(cover_icon, "self_modulate:a", 0.5, 3)
	tween.tween_property(cover_icon, "self_modulate:a", 0.5, 5)
	tween.tween_property(cover_icon, "self_modulate:a", 0.2, 1)
	hasCover = true
	chanceToHitModifier = -3

func LeaveCover():
	print("Leaving cover")
	cover_icon.visible = false
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


func AttackTarget(target : BaseCharacter) -> int:
	print(self.name, " attacks ", target.name)
	SetFacingTowardsTarget(target)
	var toHit : int = RollToHit() + CalculateDistancePenalty(target)
	var hitPenalty = 0
	if currentChosenAction == CombatActions.SHOOTBURST: hitPenalty = -2
	var toAvoid : int = target.RollToAvoidAttack(hitPenalty)
	if toAvoid >= toHit:
		target.activeState = MISSED
		return -1
	var damageToDeal : int = CalculateDamageToDeal(toHit - toAvoid)
	var damagetToResist : int = target.RollToResistDamage()
	if damagetToResist >= damageToDeal:
		target.activeState = RESISTED
		return -2
	target.TakeDamage(damageToDeal - damagetToResist)
	return damageToDeal - damagetToResist

func CalculateDistancePenalty(target : BaseCharacter) -> int:
	var distanceSquared = global_position.distance_squared_to(target.global_position)
	print(-floor(distanceSquared/15000), " - ", distanceSquared/15000)
	return -floor(distanceSquared/15000)

# ??Factor in distance to shoot??
func RollToHit():
	return RollUtil.GetRoll(weaponSkill + (maxHealth/2) + getHealthBonus())

func CalculateDamageToDeal(netHits : int):
	return weaponDamage + netHits

func RollToAvoidAttack(penaltyFromAttacker : int):
	return RollUtil.GetRoll(moveSpeed + maxHealth + getHealthBonus()) \
	+ penaltyFromAttacker - chanceToHitModifier

func RollToResistDamage():
	return RollUtil.GetRoll(armor + (maxHealth/2) + getHealthBonus())

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
		MISSED:
			animationPlayer.play("Missed")
			velocity = Vector2.ZERO
		RESISTED:
			animationPlayer.play("Resisted")
			velocity = Vector2.ZERO
		DEATH:
			Die()
			animationPlayer.play("Death")
		_:
			pass

func SetFacingTowardsTarget(target : BaseCharacter):
	if target.position.x >= position.x:
		spriteRootNode.scale.x = 1
	else:
		spriteRootNode.scale.x = -1

func Die():
	print(self.name, " died")

func _on_AnimationPlayer_animation_finished(anim_name):
	activeState = IDLE
	
func _on_cover_area_body_entered(body):
	TakeCover()
	
func _on_cover_area_body_exited(body):
	LeaveCover()
