class_name PathNode extends Area2D

@export var weight : int

var connectedPathNodes : Array[PathNode]
var occupied : bool = false
var rng = RandomNumberGenerator.new()
const MAX_NODE_WEIGHT : int = 7

# Called when the node enters the scene tree for the first time.
func _ready():
	connect("area_shape_entered", _on_area_shape_entered)
	await get_tree().create_timer(0.4).timeout
	var sprite : Sprite2D = find_child("Sprite2D")
	sprite.self_modulate = Color.from_hsv(weight/8.0, 1, 1, 1)
	sprite.z_index = 0
	for n in get_child(0).get_children():
		n.queue_free()
	for pnode in connectedPathNodes:
		var path := Line2D.new()
		get_child(0).add_child(path)
		path.z_index = 0
		path.width = 2
		path.self_modulate = Color(0, 1, 0, 0.5)
		path.add_point(Vector2.ZERO)
		path.add_point(pnode.global_position - global_position)

# any movement >16 units in the x direction to the right is considered backwards
func GetMoveToNode() -> PathNode:
	var connectedNodesCombinedWeight : int = 0
	# TODO: optimize this so that there isn't two similar loops through the path nodes
	for pnode in connectedPathNodes:
		if pnode.occupied: continue
		var modifiedPnodeWeight = pnode.weight
		if pnode.position.x - position.x > 16: modifiedPnodeWeight += 2
		connectedNodesCombinedWeight += MAX_NODE_WEIGHT - modifiedPnodeWeight
	var counter = rng.randi_range(0, connectedNodesCombinedWeight-1)
	for pnode in connectedPathNodes:
		if pnode.occupied: continue
		var modifiedPnodeWeight = pnode.weight
		if pnode.position.x - position.x > 16: modifiedPnodeWeight += 2
		counter -= MAX_NODE_WEIGHT - modifiedPnodeWeight
		if counter <= 0: return pnode
	return self


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_area_shape_entered(_area_rid, area:Area2D, _area_shape_index, _local_shape_index):
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, area.global_position)
	query.collision_mask = 0b00000000_00000000_00000000_00001001
	query.exclude = [self]
	var result := space_state.intersect_ray(query)
	if result.size() == 0 and global_position.distance_squared_to(area.global_position) > 1500:
		connectedPathNodes.append(area)
