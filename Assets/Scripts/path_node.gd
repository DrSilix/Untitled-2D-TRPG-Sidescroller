class_name PathNode extends Area2D
## Individual node which is part of a network of nodes to allow networked movement between
## The network is generated at first run
@export var weight : int

var connectedPathNodes : Array[PathNode]
var occupied : bool = false
var rng = RandomNumberGenerator.new()
const MAX_NODE_WEIGHT : int = 7

func _ready():
	connect("area_shape_entered", _on_area_shape_entered)
	await get_tree().create_timer(0.4).timeout
	# the below draws debug pathing between nodes to visualize the generated
	# network
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

## Called from occupying character and returns a randomly decided position/node
## for them to move to
##
## Nodes are currently weighted reverse of other game systems. 0 being highest priority
## and 4 being lowest and allowing for a dynamic increase up to a weight of 6
## any movement >16 units in the x direction to the right is considered backwards
## [return PathNode] The path node to move to next
func GetMoveToNode() -> PathNode:
	var connectedNodesCombinedWeight : int = 0
	
	# Generates a sum of inverted weights for possible moves
	# TODO: optimize this so that there isn't two similar loops through the path nodes
	for pnode in connectedPathNodes:
		if pnode.occupied: continue
		var modifiedPnodeWeight = pnode.weight
		# gives backwards moves a +2 (worse) weight
		if pnode.position.x - position.x > 16: modifiedPnodeWeight += 2
		connectedNodesCombinedWeight += MAX_NODE_WEIGHT - modifiedPnodeWeight
	# determines a value which falls within a single nodes weight range in the line
	var counter = rng.randi_range(0, connectedNodesCombinedWeight-1)
	
	# iterates through the nodes subtracting their inverted weight until the
	# chosen weight is reached
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

## This is triggered only by path nodes and triggered once at level load. The
## other path nodes near to this one are gathered and appended as being connected
## unless if there is a world collision (box/barrel) in the way.
func _on_area_shape_entered(_area_rid, area:Area2D, _area_shape_index, _local_shape_index):
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, area.global_position)
	query.collision_mask = 0b00000000_00000000_00000000_00001001
	query.exclude = [self]
	var result := space_state.intersect_ray(query)
	if result.size() == 0 and global_position.distance_squared_to(area.global_position) > 1500:
		connectedPathNodes.append(area)
