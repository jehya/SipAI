extends CharacterBody2D

const SPEED = 400
const KICK_DELAY = 0.1
const KICK_FORCE = 900

@onready var sipa = get_node("/root/Game/Sipa")
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var turn_manager = get_node("/root/Game/TurnManager")
@onready var player = get_node("/root/Game/Player")

var is_kicking = false
var kick_timer = 0.0
var ai_juggles = 0
var initial_position: Vector2

# Q-learning variables
var q_table = {}  # {state_string: { "kick": float, "pass": float }}
var learning_rate = 0.1
var discount_factor = 0.9
var epsilon = 0.2  # chance to explore random action

func _ready():
	initial_position = position

func reset_position():
	position = initial_position
	velocity = Vector2.ZERO

func start_turn():
	kick_timer = KICK_DELAY
	is_kicking = false
	ai_juggles = 0
	print("AI Turn Started")

func _physics_process(delta):
	if not turn_manager.is_ai_turn():
		return

	if not sipa or not is_instance_valid(sipa):
		return

	kick_timer -= delta

	var sipa_pos = sipa.global_position
	var distance = global_position.distance_to(sipa_pos)
	var direction = sign(sipa_pos.x - global_position.x)

	# Only move if sipa is too far
	if distance > 50 and not is_kicking:
		velocity.x = direction * SPEED
		sprite.flip_h = direction < 0
		sprite.play("run_ai")
	else:
		velocity.x = 0  # stay in place
		if not is_kicking:
			sprite.play("idle_ai")

	move_and_slide()

	# Dribble only if close enough and ready to kick
	if distance <= 50 and not is_kicking and kick_timer <= 0:
		is_kicking = true
		sprite.play("kick_ai")

		var action = decide_action()
		if action == "pass":
			perform_pass()
		else:
			perform_kick()
			ai_juggles += 1

		await get_tree().create_timer(0.3).timeout
		is_kicking = false
		kick_timer = KICK_DELAY


	# Perform action only if close enough and ready to kick
	if distance <= 50 and not is_kicking and kick_timer <= 0:
		is_kicking = true
		sprite.play("kick_ai")

		# Use hybrid Q-learning + Minimax to decide action
		var action = decide_action()
		if action == "pass":
			perform_pass()
		else:
			perform_kick()
			ai_juggles += 1

		await get_tree().create_timer(0.3).timeout
		is_kicking = false
		kick_timer = KICK_DELAY

func end_turn():
	print("AI's turn ended (missed or failed).")
	is_kicking = false
	kick_timer = 0.0
	sprite.play("idle_ai")


func perform_kick():
	if sipa:
		velocity.x = 0
		var direction = sign(sipa.global_position.x - global_position.x)  # +1 right, -1 left
		var impulse = Vector2(direction * 300, -KICK_FORCE)  # Kick diagonally upward towards sipa
		sipa.apply_central_impulse(impulse)
		turn_manager.successful_juggle()
		print("AI juggle", ai_juggles + 1)
		sprite.play("kick_ai")

func perform_pass():
	if sipa:
		velocity.x = 0
		var direction = sign(player.global_position.x - global_position.x)  # direction towards player
		var impulse = Vector2(direction * 200, -KICK_FORCE)  # Pass diagonally upward toward player
		sipa.apply_central_impulse(impulse)
		turn_manager.successful_juggle()
		print("AI passed the Sipa")
		sprite.play("idle_ai")



# --- MINIMAX LOGIC ---

func minimax_decision(current_juggles, required_juggles, depth):
	var kick_score = minimax(current_juggles + 1, required_juggles, depth - 1, false, "kick->")
	var pass_score = minimax(required_juggles, required_juggles, depth - 1, false, "pass->")

	print("Minimax Decision [Juggles: %d/%d, Depth: %d] → kick_score: %d, pass_score: %d"
		% [current_juggles, required_juggles, depth, kick_score, pass_score])

	if kick_score > pass_score:
		print("→ AI chooses: KICK")
		return "kick"
	else:
		print("→ AI chooses: PASS")
		return "pass"

func minimax(current_juggles, required_juggles, depth, is_ai_turn, trace: String = ""):
	if current_juggles >= required_juggles:
		print(trace + " [Juggles Met ✅] → Score: 10")
		return 10

	if depth == 0:
		print(trace + " [Depth Limit 🛑] → Score: 0")
		return 0

	if is_ai_turn:
		var score_kick = minimax(current_juggles + 1, required_juggles, depth - 1, false, trace + "kick->")
		var score_pass = minimax(required_juggles, required_juggles, depth - 1, false, trace + "pass->")
		var max_score = max(score_kick, score_pass)
		print(trace + " [AI Turn 🤖] Max(kick: %d, pass: %d) = %d" % [score_kick, score_pass, max_score])
		return max_score
	else:
		print(trace + " [Player Turn 🧍] Forcing early pass → Score: -10")
		return -10


# --- Q-LEARNING LOGIC ---

func encode_state() -> String:
	# Encode state as a string key for Q-table
	# Using discretized distance and relative player position and current juggles
	var sipa_pos = sipa.global_position
	var dist = int(global_position.distance_to(sipa_pos) / 10)  # distance bucketed by 10 px
	var player_pos = player.global_position
	var rel_player = sign(player_pos.x - global_position.x)  # -1 left, 0 same, 1 right

	return str(ai_juggles) + "|" + str(dist) + "|" + str(rel_player)

func q_learning_choose_action(state: String) -> String:
	if randf() < epsilon:
		# Exploration: choose random action
		return ["kick", "pass"][randi() % 2]
	else:
		# Exploitation: choose best Q-value action
		if not q_table.has(state):
			q_table[state] = {"kick": 0.0, "pass": 0.0}
		var actions = q_table[state]
		if actions["kick"] >= actions["pass"]:
			return "kick"
		else:
			return "pass"

func update_q_with_minimax(state: String, minimax_action: String) -> void:
	if not q_table.has(state):
		q_table[state] = {"kick": 0.0, "pass": 0.0}
	
	var current_q = q_table[state][minimax_action]
	var reward = 10  # reward for good action (tweak as needed)
	
	q_table[state][minimax_action] = current_q + learning_rate * (reward - current_q)


# --- HYBRID DECISION FUNCTION ---

func decide_action() -> String:
	var state = encode_state()

	# Get Minimax recommended action
	var minimax_action = minimax_decision(ai_juggles, turn_manager.required_juggles, 2)

	# Teach Q-learning with Minimax's suggestion
	update_q_with_minimax(state, minimax_action)

	# Choose action from Q-learning policy
	return q_learning_choose_action(state)
