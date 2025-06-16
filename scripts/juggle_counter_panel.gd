extends Panel

@onready var current_label: Label = $VBoxContainer/CurrentJuggleLabel
@onready var required_label: Label = $VBoxContainer2/RequiredJuggleLabel
@onready var turn_label: Label = $TurnLabel

var success_color = Color(0, 1, 0)
var normal_color = Color(1, 1, 1)

func update_counters(required: int, current: int, player_name: String):
	current_label.text = "%d" % current
	required_label.text = "%d" % required

	if player_name == "Player":
		current_label.add_theme_color_override("font_color", Color(0, 1, 0))  # Green
		turn_label.text = "Player's Turn"
		turn_label.add_theme_color_override("font_color", Color(0, 1, 0)) 
	else:
		current_label.add_theme_color_override("font_color", Color(1, 0, 0))  # Red
		turn_label.text = "AI's Turn"
		turn_label.add_theme_color_override("font_color", Color(1, 0, 0)) 
		
	# Animate if success
	if current >= required:
		current_label.modulate = Color(0, 1, 0)  # Green effect
		animate_label()
	else:
		current_label.modulate = Color(1, 1, 1)  # Default/White
func animate_label():
	var tween = get_tree().create_tween()
	tween.tween_property(current_label, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(current_label, "scale", Vector2(1, 1), 0.1)
