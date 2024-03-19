extends BaseCharacter

func _ready():
    get_node("../MovableArea").connect("input_event", _on_input_event, )

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int):
    if event.is_action_pressed("Move"):
        print(get_canvas_transform().affine_inverse() * event.position)
        MoveTo(get_canvas_transform().affine_inverse() * event.position)
