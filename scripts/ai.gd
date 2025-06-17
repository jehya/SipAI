extends CharacterBody2D

const SPEED = 250
const KICK_DELAY = 0.3
const DRIBBLE_FORCE = 900  # Gentle force for dribbling
const PASS_FORCE = 900     # Strong force for passing

@onready var sipa = get_node("/root/Game/Sipa")
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var turn_manager = get_node("/root/Game/TurnManager")
@onready var player = get_node("/root/Game/Player")
@onready var sfx_kick: AudioStreamPlayer2D = $sfx_kick

var is_kicking = false
var kick_timer = 0.0
var ai_juggles = 0
var initial_position: Vector2
var target_position: Vector2

# Real Q-learning variables
var q_table = {}  # {state_string: { "kick": float, "pass": float }}
var learning_rate = 0.7     # Moderate learning - allows adaptation but not too volatile
var discount_factor = 0.8   # High future reward consideration for long-term strategy
var epsilon = 0.25          # Balanced exploration - enough unpredictability without recklessness
var epsilon_decay = 0.995   # Slower decay to maintain strategic unpredictability longer
var epsilon_min = 0.08      # Higher minimum to keep some tactical surprise element

# Additional strategic parameters
var lives_threshold = 3     # When to switch to more aggressive/unpredictable play
var aggression_bonus = 0.15 # Extra exploration when player has fewer lives

# Experience tracking for Q-learning
var previous_state: String = ""
var previous_action: String = ""
var episode_rewards: Array = []
var total_episodes = 0

# Decision tracking for enhanced logging
var decision_count = 0

func _ready():
	initial_position = position
	target_position = position

func reset_position():
	position = initial_position
	velocity = Vector2.ZERO
	target_position = initial_position

func start_turn():
	kick_timer = KICK_DELAY
	is_kicking = false
	ai_juggles = 0
	previous_state = ""
	previous_action = ""
	decision_count = 0
	print("\n=== AI TURN STARTED ===")
	print("Episode: ", total_episodes, " | Epsilon: %.3f" % epsilon)
	print("Required Juggles: ", turn_manager.required_juggles)
	print("========================\n")

func _physics_process(delta):
	if not sipa or not is_instance_valid(sipa):
		return

	kick_timer -= delta
	
	var sipa_pos = sipa.global_position
	var distance_to_sipa = global_position.distance_to(sipa_pos)
	var sipa_velocity = sipa.linear_velocity
	
	# Movement logic - only move when necessary
	if turn_manager.is_ai_turn():
		# During AI's turn: only move if sipa is drifting away or too far
		var sipa_is_moving_away = is_sipa_moving_away()
		var sipa_too_far = distance_to_sipa > 80
		
		if (sipa_is_moving_away or sipa_too_far) and not is_kicking:
			# Move to intercept the sipa
			var direction_to_sipa = sign(sipa_pos.x - global_position.x)
			velocity.x = direction_to_sipa * SPEED
			sprite.flip_h = direction_to_sipa < 0
			sprite.play("run_ai")
		else:
			# Stay in place for dribbling
			velocity.x = 0
			if not is_kicking:
				sprite.play("idle_ai")
	else:
		# During player's turn: strategic positioning
		calculate_optimal_position()
		var distance_to_target = global_position.distance_to(target_position)
		
		if distance_to_target > 30 and not is_kicking:
			var direction_to_target = sign(target_position.x - global_position.x)
			velocity.x = direction_to_target * SPEED
			sprite.flip_h = direction_to_target < 0
			sprite.play("run_ai")
		else:
			velocity.x = 0
			if not is_kicking:
				sprite.play("idle_ai")

	move_and_slide()

	# Only perform kicks during AI's turn
	if turn_manager.is_ai_turn() and distance_to_sipa <= 60 and not is_kicking and kick_timer <= 0:
		is_kicking = true
		sfx_kick.play()
		sprite.play("kick_ai")
		decision_count += 1

		var current_state = encode_state()
		var action = q_learning_choose_action(current_state)
		
		# Enhanced decision logging
		print("\n--- DECISION #%d ---" % decision_count)
		print("Current State: %s" % current_state)
		print("Current Juggles: %d/%d (%.1f%% complete)" % [ai_juggles, turn_manager.required_juggles, (float(ai_juggles) / turn_manager.required_juggles) * 100])
		print("Sipa Distance: %.1f px" % distance_to_sipa)
		print("Sipa Velocity: %.1f px/s" % sipa_velocity.length())
		print("Decision Method: %s" % ("EXPLORATION" if randf() < epsilon else "EXPLOITATION"))
		print("ACTION CHOSEN: %s" % action.to_upper())
		
		if action == "pass":
			print("→ Executing PASS to player")
			perform_pass()
		else:
			print("→ Executing DRIBBLE (juggle #%d)" % (ai_juggles + 1))
			perform_dribble()
			ai_juggles += 1

		print("Decision completed.\n")

		await get_tree().create_timer(0.3).timeout
		is_kicking = false
		kick_timer = KICK_DELAY

func calculate_optimal_position():
	if not sipa or not player:
		return
		
	var sipa_pos = sipa.global_position
	var player_pos = player.global_position
	var sipa_velocity = sipa.linear_velocity
	
	# Predict where the sipa will be
	var prediction_time = 0.5  # seconds ahead
	var predicted_sipa_pos = sipa_pos + sipa_velocity * prediction_time
	
	if turn_manager.is_ai_turn():
		# During AI turn: stay close to sipa for dribbling
		target_position.x = predicted_sipa_pos.x
		target_position.y = global_position.y  # maintain ground level
	else:
		# During player turn: position strategically between sipa and player
		# Calculate if AI can intercept the sipa before it hits ground
		var time_to_ground = estimate_time_to_ground(sipa_pos, sipa_velocity)
		var distance_ai_can_travel = SPEED * time_to_ground
		var distance_to_predicted_pos = global_position.distance_to(predicted_sipa_pos)
		
		if distance_to_predicted_pos <= distance_ai_can_travel:
			# AI can reach the sipa - position to intercept
			target_position.x = predicted_sipa_pos.x
		else:
			# AI cannot reach - position defensively between player and center
			var center_field = (player_pos.x + initial_position.x) / 2
			target_position.x = center_field
		
		target_position.y = global_position.y

func estimate_time_to_ground(pos: Vector2, vel: Vector2) -> float:
	# Simple physics calculation: time = (v + sqrt(v² + 2gh)) / g
	var gravity = get_gravity().y
	var ground_y = initial_position.y  # assuming ground level
	var height = ground_y - pos.y
	
	if height <= 0:
		return 0.1  # already at ground level
	
	var discriminant = vel.y * vel.y + 2 * gravity * height
	if discriminant < 0:
		return 0.1
	
	return (-vel.y + sqrt(discriminant)) / gravity

func end_turn():
	print("\n=== AI TURN ENDED ===")
	print("Reason: Missed or failed")
	print("Total Decisions Made: %d" % decision_count)
	print("Juggles Achieved: %d/%d" % [ai_juggles, turn_manager.required_juggles])
	print("Success Rate: %.1f%%" % ((float(ai_juggles) / turn_manager.required_juggles) * 100 if turn_manager.required_juggles > 0 else 0))
	
	# Q-learning: learn from failure
	var current_state = encode_state()
	var reward = calculate_reward(false)  # failed turn
	
	print("Learning from failure - Reward: %.2f" % reward)
	
	if previous_state != "" and previous_action != "":
		update_q_value(previous_state, previous_action, reward, current_state)
	
	# End episode
	total_episodes += 1
	decay_epsilon()
	
	print("Episode %d completed.\n" % total_episodes)
	
	is_kicking = false
	kick_timer = 0.0
	sprite.play("idle_ai")

func is_sipa_moving_away() -> bool:
	if not sipa:
		return false
	
	var sipa_pos = sipa.global_position
	var sipa_vel = sipa.linear_velocity
	var current_distance = global_position.distance_to(sipa_pos)
	
	# Predict where sipa will be in 0.5 seconds
	var future_sipa_pos = sipa_pos + sipa_vel * 0.5
	var future_distance = global_position.distance_to(future_sipa_pos)
	
	# If sipa will be significantly farther away and moving with reasonable speed
	return future_distance > current_distance + 30 and sipa_vel.length() > 100

func perform_dribble():
	if sipa:
		velocity.x = 0
		
		# Q-learning: update previous action before taking new one
		var current_state = encode_state()
		var reward = calculate_reward(true)  # successful juggle
		
		print("DRIBBLE EXECUTION:")
		print("  • Reward for this action: %.2f" % reward)
		
		if previous_state != "" and previous_action != "":
			update_q_value(previous_state, previous_action, reward, current_state)
		
		# Update experience tracking
		previous_state = current_state
		previous_action = "kick"
		
		# Very gentle upward kick to keep sipa close
		var small_horizontal = randf_range(-20, 20)
		var impulse = Vector2(small_horizontal, -DRIBBLE_FORCE)
		sipa.apply_central_impulse(impulse)
		turn_manager.successful_juggle()
		
		print("  • Applied impulse: (%.1f, %.1f)" % [impulse.x, impulse.y])
		print("  • Juggle count now: %d/%d" % [ai_juggles + 1, turn_manager.required_juggles])
		
		sfx_kick.play()
		sprite.play("kick_ai")

func perform_pass():
	if sipa:
		velocity.x = 0
		
		# Q-learning: update previous action before passing
		var current_state = encode_state()
		var reward = calculate_reward(true)  # successful pass
		
		print("PASS EXECUTION:")
		print("  • Reward for this action: %.2f" % reward)
		
		if previous_state != "" and previous_action != "":
			update_q_value(previous_state, previous_action, reward, current_state)
		
		# Update experience tracking  
		previous_state = current_state
		previous_action = "pass"
		
		# Strong kick toward player
		var direction = sign(player.global_position.x - global_position.x)
		var horizontal_force = direction * randf_range(400, 600)
		var vertical_force = -randf_range(800, 1000)
		var impulse = Vector2(horizontal_force, vertical_force)
		sipa.apply_central_impulse(impulse)
		turn_manager.successful_juggle()
		
		print("  • Pass direction: %s" % ("RIGHT" if direction > 0 else "LEFT"))
		print("  • Applied impulse: (%.1f, %.1f)" % [impulse.x, impulse.y])
		print("  • Turn will end after this pass")
		
		sprite.play("idle_ai")
		
		# Complete the turn after passing
		complete_turn_with_reward()

# --- ENHANCED STATE ENCODING ---
func encode_state() -> String:
	if not sipa or not player:
		return "default"
	
	var sipa_pos = sipa.global_position
	var player_pos = player.global_position
	var sipa_vel = sipa.linear_velocity
	
	# Discretize values for state representation
	var dist_to_sipa = int(global_position.distance_to(sipa_pos) / 20)  # buckets of 20px
	var dist_to_player = int(global_position.distance_to(player_pos) / 50)  # buckets of 50px
	var sipa_speed = int(sipa_vel.length() / 100)  # velocity buckets
	var sipa_height = int((initial_position.y - sipa_pos.y) / 50)  # height buckets
	var player_relative_pos = 0  # -1 left, 0 center, 1 right
	
	if player_pos.x < global_position.x - 50:
		player_relative_pos = -1
	elif player_pos.x > global_position.x + 50:
		player_relative_pos = 1
	
	var juggle_progress = int(ai_juggles * 10.0 / turn_manager.required_juggles)  # progress as percentage
	
	# Create comprehensive state string
	return "%d|%d|%d|%d|%d|%d|%d" % [
		ai_juggles,
		dist_to_sipa, 
		dist_to_player,
		sipa_speed,
		sipa_height,
		player_relative_pos,
		juggle_progress
	]
		
func get_dynamic_epsilon() -> float:
	var base_epsilon = epsilon
	
	# Get current lives from turn manager
	var player_lives = turn_manager.player_lives
	var ai_lives = turn_manager.ai_lives
	
	# Become more unpredictable when player is losing (AI winning)
	if player_lives < lives_threshold:
		base_epsilon += aggression_bonus
		print("  • Aggression mode: Player has %d lives, epsilon boosted by %.2f" % [player_lives, aggression_bonus])
	
	# Become more conservative when AI is losing
	if ai_lives < lives_threshold:
		base_epsilon *= 0.7
		print("  • Conservative mode: AI has %d lives, epsilon reduced by 30%%" % ai_lives)
	
	return min(base_epsilon, 0.4)  # Cap at 40% to avoid being too random
	
# --- Q-LEARNING IMPLEMENTATION ---
func q_learning_choose_action(state: String) -> String:
	# Initialize state if not exists
	if not q_table.has(state):
		q_table[state] = {"kick": 0.0, "pass": 0.0}
	
	var q_values = q_table[state]
	var chosen_action: String
	var decision_type: String
	var dynamic_epsilon = get_dynamic_epsilon()  # Use dynamic epsilon instead of static
	
	if randf() < dynamic_epsilon:
		# Exploration: choose random action with strategic bias
		var actions = ["kick", "kick", "kick", "pass"]  # 75% dribble, 25% pass
		chosen_action = actions[randi() % actions.size()]
		decision_type = "EXPLORATION"
	else:
		# Exploitation: choose best Q-value action
		chosen_action = "kick" if q_values["kick"] >= q_values["pass"] else "pass"
		decision_type = "EXPLOITATION"
	
	# Enhanced decision logging
	print("Q-LEARNING DECISION:")
	print("  • Method: %s (dynamic epsilon: %.3f vs base: %.3f)" % [decision_type, dynamic_epsilon, epsilon])
	print("  • Game state: Player lives=%d, AI lives=%d" % [turn_manager.player_lives, turn_manager.ai_lives])
	print("  • Q-values: KICK=%.3f, PASS=%.3f" % [q_values["kick"], q_values["pass"]])
	print("  • Best action by Q-values: %s" % ("KICK" if q_values["kick"] >= q_values["pass"] else "PASS"))
	print("  • Action selected: %s" % chosen_action.to_upper())
	
	return chosen_action

func update_q_value(state: String, action: String, reward: float, next_state: String):
	# Initialize Q-table entries if they don't exist
	if not q_table.has(state):
		q_table[state] = {"kick": 0.0, "pass": 0.0}
	if not q_table.has(next_state):
		q_table[next_state] = {"kick": 0.0, "pass": 0.0}
	
	# Get current Q-value
	var current_q = q_table[state][action]
	
	# Find maximum Q-value in next state
	var next_max_q = max(q_table[next_state]["kick"], q_table[next_state]["pass"])
	
	# Q-learning update rule: Q(s,a) = Q(s,a) + α[r + γ*max(Q(s',a')) - Q(s,a)]
	var new_q = current_q + learning_rate * (reward + discount_factor * next_max_q - current_q)
	
	q_table[state][action] = new_q
	
	print("Q-VALUE UPDATE:")
	print("  • State: %s" % state)
	print("  • Action: %s" % action.to_upper())
	print("  • Reward: %.3f" % reward)
	print("  • Old Q-value: %.3f → New Q-value: %.3f" % [current_q, new_q])
	print("  • Learning rate: %.1f | Discount: %.1f" % [learning_rate, discount_factor])

func calculate_reward(success: bool) -> float:
	var base_reward = 1.0 if success else -5.0
	
	# Bonus rewards for strategic play
	if success:
		# Reward progress toward required juggles
		var progress_bonus = (float(ai_juggles) / float(turn_manager.required_juggles)) * 2.0
		
		# Reward efficient play (fewer juggles = higher reward)
		var efficiency_bonus = max(0, (turn_manager.required_juggles - ai_juggles)) * 0.5
		
		# Reward based on sipa positioning
		var position_bonus = 0.0
		if sipa:
			var sipa_height = initial_position.y - sipa.global_position.y
			if sipa_height > 50:  # Good height for juggling
				position_bonus = 1.0
		
		var total_reward = base_reward + progress_bonus + efficiency_bonus + position_bonus
		
		print("REWARD BREAKDOWN:")
		print("  • Base reward: %.2f" % base_reward)
		print("  • Progress bonus: %.2f" % progress_bonus)
		print("  • Efficiency bonus: %.2f" % efficiency_bonus)
		print("  • Position bonus: %.2f" % position_bonus)
		print("  • TOTAL REWARD: %.2f" % total_reward)
		
		return total_reward
	else:
		# Penalty for failure increases with more juggles attempted
		var failure_penalty = -float(ai_juggles) * 0.5
		var total_penalty = base_reward + failure_penalty
		
		print("FAILURE PENALTY:")
		print("  • Base penalty: %.2f" % base_reward)
		print("  • Additional penalty: %.2f" % failure_penalty)
		print("  • TOTAL PENALTY: %.2f" % total_penalty)
		
		return total_penalty

func decay_epsilon():
	var old_epsilon = epsilon
	epsilon = max(epsilon_min, epsilon * epsilon_decay)
	print("EPSILON DECAY: %.4f → %.4f" % [old_epsilon, epsilon])

func complete_turn_with_reward():
	# Final reward for completing the turn successfully
	var final_state = encode_state()
	var completion_reward = calculate_reward(true) + 5.0  # Bonus for completing turn
	
	print("\n=== TURN COMPLETION ===")
	print("Successfully completed turn!")
	print("Total Decisions Made: %d" % decision_count)
	print("Final Juggles: %d/%d" % [ai_juggles, turn_manager.required_juggles])
	print("Completion Bonus: 5.0")
	print("Final Reward: %.2f" % completion_reward)
	
	if previous_state != "" and previous_action != "":
		update_q_value(previous_state, previous_action, completion_reward, final_state)
	
	# End episode
	total_episodes += 1
	decay_epsilon()
	
	print("Episode %d completed successfully!\n" % total_episodes)

# --- MINIMAX LOGIC (for comparison) ---
func minimax_decision(current_juggles, required_juggles, depth):
	var kick_score = minimax(current_juggles + 1, required_juggles, depth - 1, false, "kick->")
	var pass_score = minimax(required_juggles, required_juggles, depth - 1, false, "pass->")

	print("MINIMAX ANALYSIS:")
	print("  • Current situation: %d/%d juggles, depth %d" % [current_juggles, required_juggles, depth])
	print("  • KICK score: %d | PASS score: %d" % [kick_score, pass_score])

	# Add strategic consideration - prefer dribbling early, passing later
	var juggle_ratio = float(current_juggles) / float(required_juggles)
	if juggle_ratio < 0.7:  # Early in sequence, prefer dribbling
		kick_score += 2
		print("  • Early game bonus: KICK +2")
	else:  # Late in sequence, consider passing
		pass_score += 1
		print("  • Late game bonus: PASS +1")

	var decision = "kick" if kick_score > pass_score else "pass"
	print("  • MINIMAX RECOMMENDS: %s" % decision.to_upper())
	
	return decision

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

# --- HYBRID DECISION FUNCTION (Optional) ---
func update_q_with_minimax(state: String, minimax_action: String) -> void:
	if not q_table.has(state):
		q_table[state] = {"kick": 0.0, "pass": 0.0}
	
	var current_q = q_table[state][minimax_action]
	
	# Dynamic reward based on game state
	var reward = 5.0  # base reward
	
	# Bonus for strategic timing
	var juggle_ratio = float(ai_juggles) / float(turn_manager.required_juggles)
	if minimax_action == "kick" and juggle_ratio < 0.7:
		reward += 3.0  # reward early dribbling
	elif minimax_action == "pass" and juggle_ratio >= 0.7:
		reward += 2.0  # reward strategic passing
	
	q_table[state][minimax_action] = current_q + learning_rate * (reward - current_q)
	
	print("MINIMAX→Q-LEARNING UPDATE:")
	print("  • Minimax suggested: %s" % minimax_action.to_upper())
	print("  • Teaching reward: %.2f" % reward)
	print("  • Q-value updated: %.3f → %.3f" % [current_q, q_table[state][minimax_action]])

func decide_action() -> String:
	var state = encode_state()

	print("\n--- HYBRID DECISION PROCESS ---")
	
	# Get Minimax recommended action
	var minimax_action = minimax_decision(ai_juggles, turn_manager.required_juggles, 3)

	# Teach Q-learning with Minimax's suggestion
	update_q_with_minimax(state, minimax_action)

	# Choose action from Q-learning policy
	var final_action = q_learning_choose_action(state)
	
	print("FINAL DECISION: %s" % final_action.to_upper())
	if minimax_action != final_action:
		print("  • Note: Q-learning overrode Minimax recommendation!")
	
	return final_action
