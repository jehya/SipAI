extends CanvasLayer

@onready var game_over_label = $Panel/GameOverLabel
@onready var winner_label = $Panel/WinnerLabel
@onready var restart_button = $Panel/RestartButton
@onready var quit_button = $Panel/QuitButton


func _ready():
	visible = false
	
	
	restart_button.pressed.connect(restart_game)
	quit_button.pressed.connect(quit_game)  # Connect the quit button

func show_game_over(winner: String):
	game_over_label.text = "GAME OVER"
	winner_label.text = "%s Wins!" % winner
	
	if winner == "Player":
		winner_label.self_modulate = Color(0, 1, 0)  # Green
	else:
		winner_label.self_modulate = Color(1, 0, 0)  # Red
		
	visible = true

func restart_game():
	Global.show_tutorial = false
	get_tree().reload_current_scene()

func quit_game():
	get_tree().quit()  # This exits the game
