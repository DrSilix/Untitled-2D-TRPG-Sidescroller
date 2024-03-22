class_name PathNode extends Area2D

@export var weight : int

var connectedPathNodes : Array[PathNode]
var occupied : bool = false
var rng = RandomNumberGenerator.new()
const MAX_NODE_WEIGHT : int = 7

# Called when the node enters the scene tree for the first time.
func _ready():
	print(rng.randi_range(0,1))
	connect("area_shape_entered", _on_area_shape_entered)
	await get_tree().create_timer(0.4).timeout
	find_child("Sprite2D").self_modulate = Color().from_hsv(weight/8.0, 1, 1, 1)
	for n in get_child(0).get_children():
		n.queue_free()
	for pnode in connectedPathNodes:
		var path := Line2D.new()
		get_child(0).add_child(path)
		path.z_index = 999
		path.width = 2
		path.self_modulate = Color(0, 1, 0, 0.5)
		path.add_point(Vector2.ZERO)
		path.add_point(pnode.global_position - global_position)

# >16 backwards
func GetMoveToNode() -> PathNode:
	var connectedNodesCombinedWeight : int = 0
	for pnode in connectedPathNodes:
		if pnode.occupied: continue
		var modifiedPnodeWeight = pnode.weight
		if pnode.position.x - position.x > 16: modifiedPnodeWeight += 2
		connectedNodesCombinedWeight += MAX_NODE_WEIGHT - modifiedPnodeWeight
	print(connectedPathNodes)
	var counter = rng.randi_range(0, connectedNodesCombinedWeight-1)
	for pnode in connectedPathNodes:
		if pnode.occupied: continue
		var modifiedPnodeWeight = pnode.weight
		if pnode.position.x - position.x > 16: modifiedPnodeWeight += 2
		counter -= MAX_NODE_WEIGHT - modifiedPnodeWeight
		if counter <= 0: return pnode
	print("crap")
	return self


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_area_shape_entered(area_rid, area:Area2D, area_shape_index, local_shape_index):
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, area.global_position)
	query.collision_mask = 0b00000000_00000000_00000000_00001001
	query.exclude = [self]
	var result := space_state.intersect_ray(query)
	if result.size() == 0:
		connectedPathNodes.append(area)
