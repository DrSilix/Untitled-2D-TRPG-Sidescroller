extends CharacterBody2D


@export var speed : float = 60
@export var moveClickableAreaNodePath : NodePath

@onready var collisionShape2d : CollisionShape2D = $CollisionShape2D
@onready var spriteRootNode : Node2D = $Biker_Sprites
@onready var animationPlayer : AnimationPlayer = $Biker_Sprites/BikerAnimationPlayer

var moveClickableArea : Area2D
var isAttacking : bool = false
var moveTarget : Vector2
var previousPosition : Vector2
var isMoving : bool = false

func _ready():
	moveClickableArea = get_node(moveClickableAreaNodePath)
	moveClickableArea.connect("input_event", _on_input_event)


func _physics_process(delta):
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var xDirection = Input.get_axis("ui_left", "ui_right")
	var yDirection = Input.get_axis("ui_up", "ui_down")

	if !isAttacking:
		if isMoving:
			velocity = position.direction_to(moveTarget) * speed
			if velocity.x < 0:
				spriteRootNode.scale.x = -1
			else:
				spriteRootNode.scale.x = 1
			animationPlayer.play("Walk")
			var temp = position.direction_to(moveTarget) * speed
			var temp2 = moveTarget.x - position.x
			print(str(temp.x) + "," + str(temp.y) + " - " + str(position.distance_squared_to(moveTarget)) + " - " + str(temp2))
			if position.distance_squared_to(moveTarget) < 80 && (abs(moveTarget.x - position.x) < 1 || abs(moveTarget.y - position.y) < 1):
			#var distanceToTarget = position.distance_squared_to(moveTarget)
			#if distanceToTarget < 1 || previousPosition.distance_squared_to(moveTarget) < distanceToTarget:
				isMoving = false
		elif xDirection || yDirection:
			velocity = Vector2(xDirection, yDirection).normalized() * speed
			if xDirection < 0:
				spriteRootNode.scale.x = -1
			elif xDirection > 0:
				spriteRootNode.scale.x = 1
			animationPlayer.play("Walk")
		else:
			velocity = Vector2.ZERO
			animationPlayer.play("Idle")

	if !isAttacking && Input.is_action_just_pressed("Attack"):
		animationPlayer.play("FireGun")
		velocity = Vector2.ZERO
		isAttacking = true
		isMoving = false

	#if move_and_slide() && isMoving:
		#isMoving = false;
	previousPosition = position
	move_and_slide()
	z_index = (position.y as int) - 30


func _on_animation_player_animation_finished(anim_name):
	if anim_name == "FireGun":
		isAttacking = false;
		print("finished_anim")

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int):
	if event.is_action_pressed("Move"):
		print(get_canvas_transform().affine_inverse() * event.position)
		moveTarget = get_canvas_transform().affine_inverse() * event.position
		isMoving = true
		previousPosition = Vector2.ZERO
