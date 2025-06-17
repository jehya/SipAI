extends Control


func _on_start_pressed() -> void:
	Global.show_tutorial = true
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()
