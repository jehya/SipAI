# EnemyAI.gd
extends CharacterBody2D

const SPEED = 300.0
const ACTIONS = ["low", "med_left", "high_left", "med_right", "high_right"]

var is_kicking = false
var kick_timer = 0.0
const KICK_DURATION = 0.3

var q_table = {}
var learning_rate = 0.1
var discount_factor = 0.9
var exploration_rate = 0.2

var current_state = ""
var last_state = ""
var last_action = ""

@onready var sipa = get_node("../Sipa")
@onready var power_meter = get_node("../CanvasLayer/PowerMeter")
@onready var player = get_node("../Player")
@onready var animated_sprite = $AnimatedSprite2D

func _physics_process(delta):
	# AI constantly walks toward the sipa
	var direction = 0
	if position.x < sipa.position.x - 10:
		direction = 1
	elif position.x > sipa.position.x + 10:
		direction = -1
	else:
		direction = 0

	# Update velocity for walking
	velocity.x = direction * SPEED

	# Play animations
	if direction == 0:
		animated_sprite.play("idle")
	else:
		animated_sprite.play("run")
		animated_sprite.flip_h = (direction < 0)

	move_and_slide()

	# If close enough to the sipa, perform kick
	if abs(position.x - sipa.position.x) < 20 and is_on_floor():
		last_state = get_state()
		last_action = choose_action(last_state)
		await perform_action(last_action)


func get_state() -> String:
	var ai_x = int(position.x / 10)
	var player_x = int(player.position.x / 10)
	var sipa_x = int(sipa.position.x / 10)
	return str(ai_x) + "," + str(player_x) + "," + str(sipa_x)

func choose_action(state: String) -> String:
	if not q_table.has(state):
		q_table[state] = {}
		for a in ACTIONS:
			q_table[state][a] = 0.0

	if randf() < exploration_rate:
		return ACTIONS[randi() % ACTIONS.size()]

	var best_action = ""
	var best_score = -INF
	for a in ACTIONS:
		var q = q_table[state].get(a, 0.0)
		var counter = simulate_player_response(state, a)
		var penalty = estimate_counter_reward(counter)
		var net_score = q - penalty
		if net_score > best_score:
			best_score = net_score
			best_action = a

	return best_action

func perform_action(action: String) -> void:
	enable_kick_collision()
	animated_sprite.play("kick")
	
	var power = 0.2
	var horizontal = 0

	match action:
		"low":
			power = 0.2
			horizontal = 0
		"med_left":
			power = 0.5
			horizontal = -1
		"high_left":
			power = 1.0
			horizontal = -1
		"med_right":
			power = 0.5
			horizontal = 1
		"high_right":
			power = 1.0
			horizontal = 1

	var force = lerp(300, 800, power)
	var impulse = Vector2(horizontal * 200, -force).normalized() * force
	sipa.apply_central_impulse(impulse)

	await get_tree().create_timer(0.3).timeout
	disable_kick_collision()

func simulate_player_response(state: String, ai_action: String) -> String:
	# Simulate simplified best counter-action (heuristic)
	# Placeholder: assume player always chooses high_right if AI is left
	var ai_x = int(state.split(",")[0])
	var player_x = int(state.split(",")[1])
	if player_x > ai_x:
		return "high_right"
	else:
		return "high_left"

func estimate_counter_reward(player_action: String) -> float:
	# Simplified: penalize based on predicted strength
	match player_action:
		"low": return 1.0
		"med_left", "med_right": return 3.0
		"high_left", "high_right": return 5.0
		_: return 0.0

func update_q_table(reward: float, new_state: String):
	if not q_table.has(new_state):
		q_table[new_state] = {}
		for a in ACTIONS:
			q_table[new_state][a] = 0.0

	var max_future_q = -INF
	for a in ACTIONS:
		max_future_q = max(max_future_q, q_table[new_state].get(a, 0.0))

	var current_q = q_table[last_state].get(last_action, 0.0)
	q_table[last_state][last_action] = current_q + learning_rate * (reward + discount_factor * max_future_q - current_q)

func reward_event(result: String):
	# Call this based on game outcome
	# result = "win", "miss", "juggle"
	var reward = 0.0
	match result:
		"win": reward = 10.0
		"miss": reward = -10.0
		"juggle": reward = 1.0
	update_q_table(reward, get_state())

func enable_kick_collision():
	collision_layer |= 8  # Add Layer 3 bit (Layer 3 = 8)

func disable_kick_collision():
	collision_layer &= ~8  # Remove Layer 3 bit
