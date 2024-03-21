class_name EnemySpawn
extends Sprite2D

@export var enemyTemplate : Resource

@onready var move_to = $MoveTo


# Called when the node enters the scene tree for the first time.
func _ready():
	visible = false
	move_to.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
