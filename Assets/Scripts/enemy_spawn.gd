class_name EnemySpawn
extends Sprite2D

@export var enemyTemplate : Resource
@export var startingPathNode : PathNode

@onready var move_to = $MoveTo


# Called when the node enters the scene tree for the first time.
func _ready():
	visible = false
	move_to.visible = false
