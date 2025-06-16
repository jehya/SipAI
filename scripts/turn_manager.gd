extends Node

signal turn_started(player_name)
signal game_over(winner)

var current_turn = "Player"
var current_juggles = 0
var required_juggles = 3
var player_lives = 5
var ai_lives = 5

func _ready():
	start_turn()
	

func start_turn():
	current_juggles = 0
	emit_signal("turn_started", current_turn)
	print("%s's turn! Juggles required: %d" % [current_turn, required_juggles])

	if current_turn == "AI":
		var ai_node = get_node("/root/Game/AI")  # Adjust if needed
		ai_node.start_turn()  # Let the AI begin kickingaaaaaaasdajskkad

func successful_juggle():
	current_juggles += 1
	if current_juggles >= required_juggles:
		end_turn(true)

func end_turn(success: bool):
	if not success:
		if current_turn == "Player":
			player_lives -= 1
		
			var ui_panel = get_node("/root/Game/CanvasLayer/Panel")
			ui_panel.update_hearts(player_lives)
		else:
			ai_lives -= 1
			var ai_ui_panel = get_node("/root/Game/CanvasLayer/AI_Panel")
			ai_ui_panel.update_hearts(ai_lives)

		print("%s missed! Lives remaining - Player: %d, AI: %d" %
			  [current_turn, player_lives, ai_lives])

		check_game_over()

		if player_lives <= 0 or ai_lives <= 0:
			return  # Game over — do NOT continue

		var sipa = get_node("/root/Game/Sipa")
		var player_node = get_node("/root/Game/Player")
		var ai_node = get_node("/root/Game/AI")

		player_node.reset_position()
		ai_node.reset_position()
		sipa.reset_position(current_turn.to_lower())  # retry same player

		if current_turn == "Player":
			player_node.end_turn()
		else:
			ai_node.end_turn()

		# DO NOT switch turn — retry same player
		start_turn()
		return

	else:
		# Only switch turn if juggling was successful
		required_juggles += 1

		if current_turn == "Player":
			player_lives = 10
		else:
			ai_lives = 10

		current_turn = "AI" if current_turn == "Player" else "Player"

	start_turn()


func check_game_over():
	if player_lives <= 0:
		print("GAME OVER: AI wins!")
		get_tree().paused = true
		emit_signal("game_over", "AI")
	elif ai_lives <= 0:
		print("GAME OVER: Player wins!")
		get_tree().paused = true
		emit_signal("game_over", "Player")

		

func is_player_turn() -> bool:
	return current_turn == "Player"

func is_ai_turn() -> bool:
	return current_turn == "AI"
