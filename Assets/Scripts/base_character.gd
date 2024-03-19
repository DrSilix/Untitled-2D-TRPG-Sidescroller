extends CharacterBody2D

@export var moveSpeed = 6
@export var maxHealth = 9
@export var armor = 10
@export var chanceToHitModifier = 0
@export var weaponSkill = 12
@export var weaponDamage = 6

@onready var spriteRootNode : Node2D = $SpriteRoot
@onready var animationPlayer : AnimationPlayer = $SpriteRoot/AnimationPlayer

enum {IDLE, WALKING, RUNNING, ATTACKING, HURT, DEATH}
var activeState = IDLE

var hasCover = false
var currentHealth = maxHealth
var moveTarget

func _ready():
	get_node("../MovableArea").connect("input_event", _on_input_event, )

func MoveTo(location :Vector2):
	pass

func MoveVelocity(velocity :Vector2):
	pass

func TakeCover():
	pass

func LeaveCover():
	pass

func ChanceToHit(accuracy: int):
	pass

func CalculateDamageToDeal():
	pass

func AvoidDamage(accuracy: int):
	pass

func ResistDamage(damage: int):
	pass

func TakeDamage(damage: int):
	pass


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
			pass
		ATTACKING:
			animationPlayer.play("FireGun")
			velocity = Vector2.ZERO
		HURT:
			pass
		DEATH:
			pass
		_:
			pass

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int):
	if event.is_action_pressed("Move"):
		print(get_canvas_transform().affine_inverse() * event.position)
		moveTarget = get_canvas_transform().affine_inverse() * event.position
		activeState = WALKING
