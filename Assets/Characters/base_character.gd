class_name BaseCharacter
extends CharacterBody2D
## Base class which contains all common character parameters and functionality
signal action_finished
signal move_completed
signal character_stats_changed
#region variables
@export var characterAlias : String = "unassigned"
@export var moveSpeed : int = 6
@export var maxHealth : int = 9
@export var armor : int = 10
@export var chanceToHitModifier : int = 0
@export var weaponSkill : int = 12
@export var weaponDamage : int = 6
@export var weaponAccuracy : int = 5
@export var maxWeaponAmmo : int = 6
@export var maxActionPoints : int = 6

@export_group("Action Costs")
@export var moveCost := 3
@export var takeAimCost := 3
@export var singleShotCost := 3
@export var burstShotCost := 6
@export var grenadeCost := 6
@export var reloadCost := 3

const GRENADE = preload("res://Assets/grenade.tscn")
@onready var grenade_marker = $SpriteRoot/Grenade

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

enum {IDLE, WALKING, ATTACKING, ATTACKING_TWO, THROWING_GRENADE, RELOADING, TAKE_AIM, HURT, MISSED, RESISTED, DEATH}
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
var grenadeAmmo : int = 0

var currentCombatArea : CombatArea
#endregion

func _ready():
	currentHealth = maxHealth
	currentActionPoints = maxActionPoints
	currentWeaponAmmo = maxWeaponAmmo
	animationPlayer.connect("animation_finished", _on_AnimationPlayer_animation_finished,)
	cover_collision.connect("body_entered", _on_cover_area_body_entered)
	cover_collision.connect("body_exited", _on_cover_area_body_exited)

## Initiates a continuous move by character to the location
##
## [param location]: Vector2 global position to move to
func MoveTo(location :Vector2):
	moveTarget = location
	moveTarget = NavigationServer2D.map_get_closest_point(navigation_agent_2d.get_navigation_map(), moveTarget)
	navigation_agent_2d.target_position = moveTarget
	activeState = WALKING

## Updates the current active combat area
## [param combatArea]: current combat area class
func AssignCombatArea(combatArea : CombatArea):
	currentCombatArea = combatArea

## Base method for choosing the action to be taken this turn
## This is extended in the sub classes. players it provides a UI
## Enemies there is pseudo-random conditions that pick
func ChooseCombatAction():
	pass

## Completes the chosen action from the ChooseCombatAction method
## This requires the currentChosenAction parameter to be assigned
##
## Based on the chosen action this will direct the process to the relevant method
## This is step 1 of a 2 part process
func CompleteChosenAction():
	await get_tree().create_timer(0.2).timeout
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
		CombatActions.PASS:
			PassAction()

## Part 2/2 of completing an action
## This must be called to finish the action and pass to the next combatant
##
## Currently this is called by signal events that are connected to either this
## character or the targets end of animation. This facilitates waiting for
## animations to finish which is especially important for the death animation
func _on_action_completed():
	print("Actions points: ", currentActionPoints)
	highlight_yellow.visible = false
	# this breaks the assumption from combatarea.CallNextCombatantToTakeTurn
	# if someone has won. unlike the similar check there, this will check between
	# actions of the same character
	if not await currentCombatArea.CheckIfGameOver():
		if currentActionPoints > 0:
			ChooseCombatAction()
		else: currentCombatArea.CallNextCombatantToTakeTurn()

#region Action Processing	
## the parent method for completing a single shot action vs. the attack target
## See [method AttackTarget]
## This initializes some values and performs cleanup, then will call AttackTarget
## which performs the actual damage rolls and damage dealing
##
## Setting the active state initiates an animation on frame update
##
## Single Shot: 1 ammo, no bonus, recoils aim by 1 unless aiming, then reduces aim to 0
func ShootSingleAction():
	print("Shooting Single - Aim=", aimModifier)
	currentActionPoints -= singleShotCost
	currentWeaponAmmo -= 1
	activeState = ATTACKING
	attackTarget.connect("action_finished", _on_action_completed, CONNECT_ONE_SHOT)
	var dmgDealt = await AttackTarget(attackTarget)
	aimModifier -= 1 if aimModifier <= 0 else aimModifier
	if dmgDealt >= 0: print("Deals ", dmgDealt, " damage")
	elif dmgDealt == -1: print("Attack missed")
	elif dmgDealt == -2: print("Damage resisted")

## The parent method for completing a burst shot action vs. the attack target
## See [method AttackTarget]
## This initializes some values and performs cleanup, then will call AttackTarget
## which performs the actual damage rolls and damage dealing
##
## Setting the active state initiates an animation on frame update
##
## Burst Shot: 3 ammo, target takes -3 to avoid attack, 
## recoils aim by 3 unless aiming, then reduces aim to 0
func ShootBurstAction():
	print("Shooting Burst - Aim=", aimModifier)
	currentActionPoints -= burstShotCost
	currentWeaponAmmo -= 3 if currentWeaponAmmo >= 3 else currentWeaponAmmo
	activeState = ATTACKING_TWO
	attackTarget.connect("action_finished", _on_action_completed, CONNECT_ONE_SHOT)
	var dmgDealt = await AttackTarget(attackTarget)
	aimModifier -= 3 if aimModifier <= 0 else aimModifier
	if dmgDealt >= 0: print("Deals ", dmgDealt, " damage")
	elif dmgDealt == -1: print("Attack missed")
	elif dmgDealt == -2: print("Damage resisted")

## Part 1/2 of throwing a grenade
## This reduces the character AP and is extended by the subclass
## solely to reduce the player/enemy pooled ammo
##
## Setting the active state initiates an animation on frame update
##
## This connects to two methods while watching for the grenade throw
## animation to finish. Those two methods simultaneously instantiate a grenade at
## the end of the grenade throw anim and pass the turn
func GrenadeAction():
	currentActionPoints -= grenadeCost
	SetFacingTowardsTarget(attackTarget)
	self.connect("action_finished", InstantiateAndThrowGrenade, CONNECT_ONE_SHOT)
	self.connect("action_finished", _on_action_completed, CONNECT_ONE_SHOT)
	activeState = THROWING_GRENADE
	print("Throwing Grenade")

## Part 2/2 of throwing a grenade
## This is called after the throw grenade animation is finished and will
## instantiate a grenade scene at last anim frame grenade position
##
## A modified to hit roll by this character is attached to the grenade, with overridden
## attack skill and accuracy and passed to the grenade scene
##
## The grenade is registered with the combat area to allow only one grenade at a time
## and the grenade is given an initiative on the next turn after this character
## goes/would go
##
## grenade: world based AoE, damage specified in grenade scene [8]. exponential falloff
func InstantiateAndThrowGrenade():
	print("Instantiating and Throwing Grenade")
	var toHit : int = RollToHit(CalculateDistancePenalty(attackTarget), 12, 6)
	var grenade : Grenade = GRENADE.instantiate()
	get_parent().add_child(grenade)
	grenade.global_position = grenade_marker.global_position
	currentCombatArea.RegisterGrenade(grenade, self)
	grenade.ThrowAt(toHit, attackTarget.global_position, currentCombatArea)

## Performs a reload filling ammo which resets the aim/recoil modifier
##
## Setting the active state initiates an animation on frame update
func ReloadAction():
	currentActionPoints -= reloadCost if currentActionPoints >= reloadCost else currentActionPoints
	aimModifier = 0
	self.connect("action_finished", _on_action_completed, CONNECT_ONE_SHOT)
	activeState = RELOADING
	currentWeaponAmmo = maxWeaponAmmo

## This sets the aim modifier to 4 and changes the active state starting an
## animation
## Aim can be negative for recoil and positive for the act of aiming
func TakeAimAction():
	print("Taking Aim")
	aimModifier = 4
	currentActionPoints -= takeAimCost
	self.connect("action_finished", _on_action_completed, CONNECT_ONE_SHOT)
	activeState = TAKE_AIM

## Initiates a move to the target location. The enemy subclass overwrites this
##
## movement resets aim/recoil. The MoveTo method will change the active state
## starting the animation
func MoveAction():
	currentActionPoints -= moveCost
	aimModifier = 0
	self.connect("move_completed", _on_action_completed, CONNECT_ONE_SHOT)
	MoveTo(moveTarget)
	print("Moving")

## This passes the remaining action to the next combatant, also resets aim
##
## this directly calls _on_action_completed
func PassAction():
	currentActionPoints = 0
	aimModifier = 0 if aimModifier < 0 else aimModifier
	await get_tree().create_timer(0.5).timeout
	_on_action_completed()
	print("Passing Turn")
#endregion

## Modifies the character to put them "in cover" and displays a large icon overlay
## See [method _on_cover_area_body_entered]
##
## This is called when the character cover collider intersects a cover object
## Cover is counted to facilitate entering/exiting multiple cover objects but
## only counting cover once and totally. If already in cover this has no effect
##
## the cover count has no effect above 1
##
## Cover: reduces attacker to hit dice pool by 3
func TakeCover():
	hasCover += 1
	if hasCover > 1: return
	character_stats_changed.emit()
	print("Taking cover")
	# TODO: make it so cover icon only shows while in combat
	cover_icon.visible = true
	cover_icon.self_modulate.a = 0
	var tween = get_tree().create_tween()
	tween.tween_property(cover_icon, "self_modulate:a", 1, 0.5)
	tween.tween_property(cover_icon, "self_modulate:a", 1, 0.5)
	tween.tween_property(cover_icon, "self_modulate:a", 0, 3)
	chanceToHitModifier = -3

## Decrements cover counter until the character leaves cover
## See [method _on_cover_area_body_exited]
## Has no effect if character is still near a cover object
func LeaveCover():
	hasCover -= 1
	if hasCover > 0: return
	character_stats_changed.emit()
	print("Leaving cover")
	cover_icon.visible = false
	chanceToHitModifier = 0

#region Attack Methods
## Calculates a penalty to apply to dice rolls. -1 for every 3 damage taken
##
## -1 for every 3, e.g:
## 7 8 9 = -0
## 4 5 6 = -1
## 1 2 3 = -2
##
## [b]return[/b] [int]: the health penalty 0 or less
func getHealthPenalty() -> int:
	return floori(float(maxHealth - currentHealth) / 3) * -1

## Calculates the health bonus representing RPG constitution or body
## half max health minus the penalty for being hurt
## [b]return[/b] [int]: health/con/body bonus [0 - maxHealth/2]
func getHealthBonus() -> int:
	return getHealthPenalty() + floori(float(maxHealth)/2)

## Finalizes an attack initiated by [method ShootSingleAction] and [method ShootBurstAction]
##
## Aggregates all combat calculations to determine miss/resist/hit and damage done
## See [method RollToHit], [method CalculateDistancePenalty], [method RollToAvoidAttack]
## [method CalculateDamageToDeal], [method RollToResistDamage], [method TakeDamage]
##
## [param target]: BaseCharacter that is being attacked
## [return int]: damage dealth or -1 if missed, -2 if resisted
func AttackTarget(target : BaseCharacter) -> int:
	print(self.name, " attacks ", target.name)
	var attackResultDelayTime = 0.6
	SetFacingTowardsTarget(target)
	var toHit : int = RollToHit(CalculateDistancePenalty(target))
	var defenderEvadePenalty = 0
	if currentChosenAction == CombatActions.SHOOTBURST:
		defenderEvadePenalty = -2
		attackResultDelayTime = 1.2
	var toAvoid : int = target.RollToAvoidAttack(defenderEvadePenalty)
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

## Performs a attacker/defender distance check and determines a penalty
## Calibrated to between 0 and 3 (times -2). usually combat happens in 2/3 range
##
## [param target]: BaseCharacter that is being attacked
## [return int]: the distance penalty <= 0
func CalculateDistancePenalty(target : BaseCharacter) -> int:
	var distanceSquared = global_position.distance_squared_to(target.global_position)
	#print(floor(distanceSquared/15000) * -2, " - ", distanceSquared/15000)
	return floor(distanceSquared/15000) * -2

## Calculates attack toHit value which the defender must meet or beat to evade
## 
## See [method RollUtil.GetRoll]
## Performs an Nd6 dice roll where 5/6 is successes
##
## ToHit calc: rolls a number of d6 equal to skill + healthbonus + aim/recoil + rangepenalty
## The result number of successes is limited by the weapon accuracy
## [param rangePenalty]: Penalty to dice pool from range, generally [-6, 0]
## [param skillOverride]: overrides weapon skill used in calculation. default: 0(no)
## [param accOverride]: overrides weapon accuracy used in calculation. default: 0(no)
## [return int]: toHit value representing attacks accuracy
func RollToHit(rangePenalty : int, skillOverride : int = 0, accOverride : int = 0) -> int:
	var finalSkill = weaponSkill if skillOverride <= 0 else skillOverride
	var finalAcc = weaponAccuracy if accOverride <= 0 else accOverride
	# TODO: move aimModifier into arguments for consistency
	return min(RollUtil.GetRoll(finalSkill + getHealthBonus() + aimModifier + rangePenalty), finalAcc)

func GetToHitDiceCount(rangePenalty : int, skillOverride : int = 0) -> int:
	var finalSkill = weaponSkill if skillOverride <= 0 else skillOverride
	return finalSkill + getHealthBonus() + aimModifier + rangePenalty

## Calculates the modified damage value which is the attack net hits (toHit - toAvoid)
## plus the weapon damage
##
## [param netHits]: the net result of toHit - toAvoid
## [return int]: modified damage value that needs to be resisted by target
func CalculateDamageToDeal(netHits : int) -> int:
	return weaponDamage + netHits

## Calculates an evasion/avoidance roll for defence from an attack
##
## See [method RollUtil.GetRoll]
## Performs an Nd6 dice roll where 5/6 is successes
##
## ToAvoid calc: rolls a number of d6 equal to movespeed + healthbonus +
## a penalty from the attacker (generally from burst attack) +
## this owns chancetohitmodifier (generally from cover)
## [param penaltyFromAttacker]: the penalty to avoid from the attacker <= 0 (0 or -2)
## [return int]: roll result representing chance to avoid attack
func RollToAvoidAttack(penaltyFromAttacker : int) -> int:
	return RollUtil.GetRoll(moveSpeed + getHealthBonus() \
	+ penaltyFromAttacker - chanceToHitModifier)

func GetToAvoidDiceCount(penaltyFromAttacker : int) -> int:
	return moveSpeed + getHealthBonus() + penaltyFromAttacker - chanceToHitModifier

## Calculates a damage resist roll for absorbing incoming damage
##
## See [method RollUtil.GetRoll]
## Performs an Nd6 dice roll where 5/6 is successes
##
## ToResist calc: armor + healthbonus (which includes a constitution/body analogue)
## [return int]: a number representing this ones ability to resist damage
func RollToResistDamage() -> int:
	return RollUtil.GetRoll(armor + getHealthBonus())

func GetToResistDiceCount() -> int:
	return armor + getHealthBonus()

## Applies incoming damage and activates hurt or death state which plays the animations
## When the hurt animation is finished a [method _on_action_completed] signal will be
## emitted and turn passed. Same with death except the death animation will call [method Die]
## [param damage]: damage to take >0
func TakeDamage(damage: int):
	currentHealth -= damage
	activeState = HURT if currentHealth > 0 else DEATH
	character_stats_changed.emit()
#endregion

## Updates the status panel listed above the characters head with current information
func UpdateStatusPanel():
	health_bar.value = ceil((currentHealth as float / maxHealth as float) * 100)
	ap_bar.value = currentActionPoints
	status_cover_icon.visible = true if hasCover > 0 else false
	var goodColor = Color("#91ff7e")
	var badColor = Color("#d31f41")
	aim_icon.self_modulate = goodColor if aimModifier > 0 else badColor
	aim_icon.visible = false if aimModifier == 0 else true
	ammo_bar.value = ceil((currentWeaponAmmo as float / maxWeaponAmmo as float) * 100)

## game update loop. this contains a state machine for directing animations
## actual movement is handled here.
## generally completion of non-looping animations will trigger the next method call
func _physics_process(_delta):
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
		ATTACKING:
			if animationPlayer.current_animation != "Attack1": animationPlayer.play("Attack1")
			#print(animationPlayer.current_animation)
			velocity = Vector2.ZERO
		ATTACKING_TWO:
			if animationPlayer.current_animation != "Attack2": animationPlayer.play("Attack2")
			velocity = Vector2.ZERO
		THROWING_GRENADE:
			if animationPlayer.current_animation != "Throw_Grenade": animationPlayer.play("Throw_Grenade")
			velocity = Vector2.ZERO
		RELOADING:
			if animationPlayer.current_animation != "Reloading": animationPlayer.play("Reloading")
			velocity = Vector2.ZERO
		TAKE_AIM:
			if animationPlayer.current_animation != "Take_Aim": animationPlayer.play("Take_Aim")
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

## Flips the sprite to face towards a target by scaling it in the -x direction
## [param target]: BaseCharacter to face towards
func SetFacingTowardsTarget(target : BaseCharacter):
	if target.position.x >= position.x:
		spriteRootNode.scale.x = 1
	else:
		spriteRootNode.scale.x = -1

## Calls [method CombatArea.RemoveCombatantFromRound] on the combat area
## Called from game loop update upon death
func RemoveFromCombatList():
	currentCombatArea.RemoveCombatantFromRound(self)

## completes the action and turn of the dead character
## this is exclusively called from within the Death animation player
func Die():
	character_stats_changed.emit()
	action_finished.emit()
	print(self.name, " died")

## This drives the turn loop by emitting action_finished when any non-loop animation
## is finished
func _on_AnimationPlayer_animation_finished(anim_name):
	print(name, " anim finished - ", anim_name, " - active state - ", activeState)
	action_finished.emit()
	activeState = IDLE
	
func _on_cover_area_body_entered(_body):
	TakeCover()
	
func _on_cover_area_body_exited(_body):
	LeaveCover()
