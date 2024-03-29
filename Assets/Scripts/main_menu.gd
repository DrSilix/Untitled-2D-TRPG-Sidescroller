extends Control



func _on_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")


func _on_button_4_pressed():
	get_tree().quit()
