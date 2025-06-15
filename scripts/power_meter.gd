extends Control

@onready var gradient_bar = $Panel/GradientBar
@onready var marker_line = $MarkerLine

var speed = 100
var direction = 1

func _process(delta):
	var new_x = marker_line.position.x + speed * direction * delta

	if new_x < 0:
		new_x = 0
		direction *= -1
	elif new_x > gradient_bar.size.x:
		new_x = gradient_bar.size.x
		direction *= -1

	marker_line.position.x = new_x

	var ratio = marker_line.position.x / gradient_bar.size.x
	var power_color = gradient_color(ratio)

func gradient_color(ratio: float) -> Color:
	if ratio < 0.5:
		return Color(0, 1, 0).lerp(Color(1, 1, 0), ratio / 0.5)  # Green to Yellow
	else:
		return Color(1, 1, 0).lerp(Color(1, 0, 0), (ratio - 0.5) / 0.5)  # Yellow to Red
		
func get_power_ratio() -> float:
	return marker_line.position.x / gradient_bar.size.x
