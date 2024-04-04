class_name Grenade extends Node2D
## Handles the execution of an individually instanced grenade from throw release
## to explosion and damage. chracters have a fake grenade as part of their animation
## which this replaces on the last frame.
@export var throwHeight = 50
@export var deviationDistance = 15
@export var distanceToLandBefore = 30
@export var hangTime = 1500
@export var rollTime = 400
@export var turnsFuse = 5
@export var toHitDC = 3
@export var damage = 8
@export var minDamageFalloffMultiplier : float = 0.2

@onready var point_light_2d = $Sprites/PointLight2D
@onready var animation_player = $Sprites/AnimationPlayer
@onready var game_manager : GameManager = $/root/Node2D/GameManager
@onready var explosion_radius : Area2D = $ExplosionRadius
@onready var navigation_region_2d : NavigationRegion2D = $/root/Node2D/NavigationRegion2D

var _startingPos : Vector2
var _targetPos : Vector2
var _controlPoint1 : Vector2
var _controlPoint2 : Vector2
var _landingPos : Vector2

var _startTime : float
var _duration : float
var _combatArea : CombatArea
var _currentFuseTime : int
var _squaredExplosionRadius : int

var _toHit : int

enum {IN_AIR, ROLLING, IDLE, EXPLODE}
var currentState = IN_AIR

func _ready():
	print("Grenade Instantiated")
	_squaredExplosionRadius = roundi(pow(explosion_radius.get_child(0).get_shape().radius, 2))

## Called first upon grenade instantiation and tells the grenade where
## to target, the throwers accuracy, and the associated combatArea (only one grenade
## allowed per CA)
##
## The targetPos is first deviated either a small distance (visually pleasing) or
## a large distance (character missed) and by a random direction, This is snapped
## to the nearest point on the navmesh to avoid obstacles. Then a landing
## target is determined by further tracing a line back towards the thrower a short
## distance. The grenade is then linearly interpolated along a bezier curve to the
## landing position and rolls to the target position
## [param toHit] character successes on a Nd6 roll to determine accuracty/damage
## [param targetPos] The desired target of the grenade (the grenade will never actually
## land here due to required deviation
## [param combatArea] The combat area the grenade is created into
func ThrowAt(toHit : int, targetPos : Vector2, combatArea : CombatArea):
	print("Throwing Grenade")
	_toHit = toHit
	var toHitDeviation = 1 if _toHit >= toHitDC else 2 + (toHitDC - _toHit)
	if _toHit < toHitDC: print("Missed Grenade")
	var rng = RandomNumberGenerator.new()
	var randomVector = Vector2.from_angle(rng.randf_range(0, PI * 2))
	_combatArea = combatArea
	# Connector for the depreciated turn fuse mechanic
	#combatArea.connect("turn_finished", _on_turn_finished)
	#_currentFuseTime = turnsFuse
	_targetPos = targetPos + (randomVector * deviationDistance * toHitDeviation)
	_targetPos = NavigationServer2D.map_get_closest_point(navigation_region_2d.get_navigation_map(), _targetPos)
	# the grenade is placed on the z-index of its target, from start to end of "throw"
	z_index = (_targetPos.y as int) - 30
	_startingPos = global_position
	# this is the position the thrown grenade lands and then it "rolls" to the target position
	_landingPos = _targetPos + (_targetPos.direction_to(_startingPos).normalized() * distanceToLandBefore)
	_controlPoint1 = _startingPos.lerp(_targetPos, 0.33) + (Vector2.UP * throwHeight)
	_controlPoint2 = _startingPos.lerp(_targetPos, 0.66) + (Vector2.UP * throwHeight)
	_startTime = Time.get_ticks_msec()
	_duration = hangTime
	#DrawRawDebugLine()
	#DrawTrajectoryLine()

## Debug function for drawing a line between the 5 main points, start, control1,
## control2, landing, and target
func DrawRawDebugLine():
	var debugLine : Line2D = Line2D.new()
	get_parent().add_child(debugLine)
	debugLine.add_point(_startingPos)
	debugLine.add_point(_controlPoint1)
	debugLine.add_point(_controlPoint2)
	debugLine.add_point(_landingPos)
	debugLine.add_point(_targetPos)
	debugLine.width = 1
	debugLine.default_color = Color.AQUA
	debugLine.z_index = 999

## Debug function for drawing the bezier line made from the starting to landing pos
## with the 2 control points
func DrawTrajectoryLine():
	var debugLine : Line2D = Line2D.new()
	get_parent().add_child(debugLine)
	debugLine.add_point(GetPointOnLine(0))
	debugLine.add_point(GetPointOnLine(.15))
	debugLine.add_point(GetPointOnLine(.3))
	debugLine.add_point(GetPointOnLine(.45))
	debugLine.add_point(GetPointOnLine(.6))
	debugLine.add_point(GetPointOnLine(.75))
	debugLine.add_point(GetPointOnLine(.9))
	debugLine.add_point(GetPointOnLine(1))
	debugLine.width = 1
	debugLine.default_color = Color.DEEP_PINK
	debugLine.z_index = 999

## utility function to query a point on the bezier throw line using a normalized
## weight.
## [param weight] float representing the normalized distance along the line the
## returned point should be. [0-1] with 0 being starting position and 1 being landing position
## [return Vector2] point on bezier throw line
func GetPointOnLine(weight : float) -> Vector2:
	return _startingPos.bezier_interpolate(_controlPoint1, _controlPoint2, _landingPos, weight)

func _process(_delta):
	match currentState:
		# grenade is interpolated from start position to landing position until it arrives
		IN_AIR:
			global_position = GetPointOnLine( \
				clamp((Time.get_ticks_msec() - _startTime) / _duration, 0, 1))
			if (Time.get_ticks_msec() - _startTime) / _duration > 1:
				currentState = ROLLING
				_startTime = Time.get_ticks_msec()
				_duration = rollTime
		# grenade traces a straight line to target from landing position
		ROLLING:
			if animation_player.current_animation != "Landed": animation_player.play("Landed")
			global_position = _landingPos.lerp(_targetPos, \
				clamp((Time.get_ticks_msec() - _startTime) / _duration, 0, 1))
			if (Time.get_ticks_msec() - _startTime) / _duration > 1:
				currentState = IDLE
		# grenade lays idle waiting to explode. Indication is made on top layer
		# so that even if grenade sprite isn't visible the player knows where it is
		IDLE:
			if animation_player.current_animation != "Idle": animation_player.play("Idle")
		EXPLODE:
			pass

## Triggers the explosion. Thanks to polymorphism and the combat participants
## being Nodes (instead of BaseCharacters) the grenade can exist with them. When
## the grenades "turn" comes this function is called. The grenade can only choose
## to explode...
func ChooseCombatAction():
	Explode()

## Carries out the explosion. Plays what amounts to a cutscene and then calculates
## and applies damage and passes turn
##
## A top level UI panel is used to "blind" the screen 3 times. At the end of the
## first time the grenades explosion animation is played. and after the third
## time the damage is applied, the grenade is deregistered, and the next combatant
## is called.
func Explode():
	var st : Panel = game_manager.screen_tinting
	st.self_modulate = Color.WHITE
	st.self_modulate.a = 0
	st.visible = true
	var tween = get_tree().create_tween()
	tween.tween_property(st, "self_modulate:a", 1, 0.05)
	tween.tween_property(st, "self_modulate:a", 1, 0.5)
	tween.tween_property(st, "self_modulate:a", 0, 1)
	await tween.finished
	animation_player.play("Explode")
	print("BANG!!!")
	# prevents the idle animation from being called due to idle state
	currentState = EXPLODE
	tween = get_tree().create_tween()
	tween.tween_property(st, "self_modulate:a", 1, 0.05)
	tween.tween_property(st, "self_modulate:a", 1, 0.5)
	tween.tween_property(st, "self_modulate:a", 0, 1)
	tween.tween_property(st, "self_modulate:a", 1, 0.05)
	tween.tween_property(st, "self_modulate:a", 1, 1.5)
	tween.tween_property(st, "self_modulate:a", 0, 1)
	await tween.finished
	CalculateHitAndDamage()
	# only one grenade per combat area allowed at a time, this frees that spot
	_combatArea.DeregisterGrenade()
	# needed to allow all affected to finish animations and especially deaths
	await get_tree().create_timer(2).timeout
	_combatArea.CallNextCombatantToTakeTurn()
	queue_free()

## Carries out damaging characters within grenade range
##
## Uses an attached area2D to determine the characters within range and then tests
## distance, they roll to resist, then damage is applied if applicable.
##
## see [method Vector2ScaledDistanceSquared], [method CalculateDamageFalloffMultiplier],
## and [method CharacterBody.RollToResistDamage] for details
func CalculateHitAndDamage():
	var bodiesInArea : Array[Node2D] = explosion_radius.get_overlapping_bodies()
	for body : BaseCharacter in bodiesInArea:
		# vertically squashed distance
		var squaredDistanceTo = Vector2ScaledDistanceSquared(global_position, body.global_position)
		var damageMultiplier = CalculateDamageFalloffMultiplier(squaredDistanceTo, _squaredExplosionRadius)
		var damageToDeal : int = roundi((float(_toHit)/2 + damage) * damageMultiplier)
		var damageToResist : int = body.RollToResistDamage()
		print(body.name, " distance:", squaredDistanceTo, " dmgMult:", damageMultiplier, " damage:", damageToDeal, " toResist:", damageToResist)
		if damageToResist >= damageToDeal:
			body.activeState = body.RESISTED
			continue
		body.TakeDamage(damageToDeal - damageToResist)

## Utility function to calculate vector2 distance with independant x/y scaling
## Due to the nature of the skewed world perspective, distances are optically different
## than they are in physical coordinates.
## TODO: this should be placed in separate class and applied in many other places
## [param v1] Vector2 start position
## [param v2] Vector2 end position
## [param _xScale] float normalized x scale to multiply x distance by (unimplemented) [0-1]
## [param _yScale] float normalized y scale to multiple y distance by [0-1]
func Vector2ScaledDistanceSquared(v1 : Vector2, v2 : Vector2, _xScale : float = 1, yScale : float = 1) -> int:
	return roundi(pow(v2.x - v1.x, 2) + pow((v2.y - v1.y)/yScale, 2))

## Damage falls of exponentially from the grenade origin. this is multiplied by
## the normal damage to get a distance modified damage.
## [param distance] float distance at which to calculate damage
## [param maxDistance] float distance used as reference for maximum full damage distance
## [return float] normalized value representing percentage of damage to deal
func CalculateDamageFalloffMultiplier(distance : float, maxDistance : float) -> float:
	var normalizedDistance = distance/maxDistance
	return pow(minDamageFalloffMultiplier, normalizedDistance)

# depreciated. This is used for the depreciated turn fuse mechanic
func _on_turn_finished(_currentCombatant : BaseCharacter, _previousCombatant : BaseCharacter):
	_currentFuseTime -= 1
	print("Grenade explodes in ", _currentFuseTime, " turns")
	if _currentFuseTime <= 0:
		Explode()
