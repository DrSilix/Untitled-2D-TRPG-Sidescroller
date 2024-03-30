class_name Grenade extends Node2D

@export var throwHeight = 50
@export var deviationDistance = 15
@export var distanceToLandBefore = 30
@export var hangTime = 1500
@export var rollTime = 400
@export var turnsFuse = 1
@export var toHitDC = 3
@export var damage = 6

@onready var point_light_2d = $Sprites/PointLight2D
@onready var animation_player = $Sprites/AnimationPlayer
@onready var GameManager : GameManager = $/root/Node2D/GameManager
@onready var explosion_radius : Area2D = $ExplosionRadius

var _startingPos : Vector2
var _targetPos : Vector2
var _controlPoint1 : Vector2
var _controlPoint2 : Vector2
var _landingPos : Vector2

var _currentTravelDistance : float = 0
var _startTime : float
var _duration : float
var _combatArea : CombatArea
var _currentFuseTime : int

var _toHit : int

enum {IN_AIR, ROLLING, IDLE, EXPLODE}
var currentState = IN_AIR

func _ready():
	print("Grenade Instantiated")

func ThrowAt(toHit : int, pos : Vector2, combatArea : CombatArea):
	print("Throwing Grenade")
	_toHit = toHit
	var toHitDeviation = 1 if _toHit >= toHitDC else 2 + (toHitDC - _toHit)
	if _toHit < toHitDC: print("Missed Grenade")
	var rng = RandomNumberGenerator.new()
	var randomVector = Vector2.from_angle(rng.randf_range(0, PI * 2))
	_combatArea = combatArea
	#combatArea.connect("turn_finished", _on_turn_finished)
	_currentFuseTime = turnsFuse
	_targetPos = pos + (randomVector * deviationDistance * toHitDeviation)
	z_index = (_targetPos.y as int) - 30
	_startingPos = global_position
	_landingPos = _targetPos + (_targetPos.direction_to(_startingPos).normalized() * distanceToLandBefore)
	_controlPoint1 = _startingPos.lerp(_targetPos, 0.33) + (Vector2.UP * throwHeight)
	_controlPoint2 = _startingPos.lerp(_targetPos, 0.66) + (Vector2.UP * throwHeight)
	_startTime = Time.get_ticks_msec()
	_duration = hangTime
	#DrawRawDebugLine()
	#DrawTrajectoryLine()

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

func GetPointOnLine(weight : float) -> Vector2:
	return _startingPos.bezier_interpolate(_controlPoint1, _controlPoint2, _landingPos, weight)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	match currentState:
		IN_AIR:
			global_position = GetPointOnLine( \
				clamp((Time.get_ticks_msec() - _startTime) / _duration, 0, 1))
			if (Time.get_ticks_msec() - _startTime) / _duration > 1:
				currentState = ROLLING
				_startTime = Time.get_ticks_msec()
				_duration = rollTime
		ROLLING:
			if animation_player.current_animation != "Landed": animation_player.play("Landed")
			global_position = _landingPos.lerp(_targetPos, \
				clamp((Time.get_ticks_msec() - _startTime) / _duration, 0, 1))
			if (Time.get_ticks_msec() - _startTime) / _duration > 1:
				currentState = IDLE
		IDLE:
			if animation_player.current_animation != "Idle": animation_player.play("Idle")
		EXPLODE:
			pass

func ChooseCombatAction():
	var st : Panel = GameManager.screen_tinting
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
	_combatArea.DeregisterGrenade()
	_combatArea.CallNextCombatantToTakeTurn()
	queue_free()
	
func CalculateHitAndDamage():
	var bodiesInArea : Array[Node2D] = explosion_radius.get_overlapping_bodies()
	for body : BaseCharacter in bodiesInArea:
		var hitPenalty = 0
		#var toAvoid : int = body.RollToAvoidAttack(hitPenalty)
		#if toAvoid >= _toHit:
			#body.activeState = body.MISSED
			#continue
		var damageToDeal : int = damage + _toHit
		var damagetToResist : int = body.RollToResistDamage()
		if damagetToResist >= damageToDeal:
			body.activeState = body.RESISTED
			continue
		body.TakeDamage(damageToDeal - damagetToResist)
		

func _on_turn_finished(currentCombatant : BaseCharacter, previousCombatant : BaseCharacter):
	_currentFuseTime -= 1
	print("Grenade explodes in ", _currentFuseTime, " turns")
	if _currentFuseTime <= 0:
		var st : Panel = GameManager.screen_tinting
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
		currentState = EXPLODE
		tween = get_tree().create_tween()
		tween.tween_property(st, "self_modulate:a", 1, 0.05)
		tween.tween_property(st, "self_modulate:a", 1, 0.5)
		tween.tween_property(st, "self_modulate:a", 0, 1)
		tween.tween_property(st, "self_modulate:a", 1, 0.05)
		tween.tween_property(st, "self_modulate:a", 1, 1.5)
		tween.tween_property(st, "self_modulate:a", 0, 1)
