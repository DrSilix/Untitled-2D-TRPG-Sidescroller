extends StaticBody2D

@export var parentZNode : StaticBody2D

# Called when the node enters the scene tree for the first time.
func _ready():
    if parentZNode == null:
        z_index = round(global_position.y)
    else:
        z_index = round(parentZNode.global_position.y)
    print(name + "-" + str(z_index))

