extends BaseCharacter

var isInputDisabled = false

func _ready():
    get_node("../MovableArea").connect("input_event", _on_input_event, )
    super._ready()

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int):
    if !isInputDisabled:
        if event.is_action_pressed("Move"):
            print(get_canvas_transform().affine_inverse() * event.position)
            MoveTo(get_canvas_transform().affine_inverse() * event.position)
        if event.is_action_pressed("Attack"):
            activeState = ATTACKING
