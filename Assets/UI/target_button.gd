extends Button

signal pressed_with_info(pressed_button : Button)

var targetId : int = -1

func _on_pressed():
	pressed_with_info.emit(self)
