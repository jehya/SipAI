extends Node

signal turn_started(player_name)
signal game_over(winner)

var current_turn = "Player"
var current_juggles = 0
var required_juggles = 3
var player_lives = 3
var ai_lives = 3

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
		else:
			ai_lives -= 1

		print("%s missed! Lives remaining - Player: %d, AI: %d" %
			  [current_turn, player_lives, ai_lives])

		check_game_over()

		# ✅ Stop everything if the game is over
		if player_lives <= 0 or ai_lives <= 0:
			return  # Game over — do NOT continue

		# Player/AI still has lives → retry same turn
		start_turn()
		return

	else:
		# Successful juggling: increase difficulty and switch turn
		required_juggles += 1

		# Reset lives on success (optional)
		if current_turn == "Player":
			player_lives = 3
		else:
			ai_lives = 3

		# Switch turn
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
