# EnemyAI.gd - Fixed version for testing mechanics
extends CharacterBody2D

const SPEED = 300.0
const JUGGLE_FORCE = 400.0
const KICK_FORCE = 600.0

# Timers and state
var juggle_timer = 0.0
var kick_cooldown = 0.0
var juggle_count = 0
var juggle_limit = 3
var is_juggling = false
var is_kicking = false
var is_my_turn = false
var initial_position: Vector2


# AI behavior state
enum AIState { IDLE, MOVING_TO_SIPA, JUGGLING, WAITING }
var current_state = AIState.IDLE

@onready var sipa = get_node("../Sipa")
@onready var power_meter = get_node("../CanvasLayer/PowerMeter")
@onready var player = get_node("../Player")
@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	initial_position = position
	print("AI ready! Testing Sipa mechanics...")
	# Make sure AI is in the enemy group for collision detection
	add_to_group("enemy")

func reset_position():
	position = initial_position
	velocity = Vector2.ZERO


func _physics_process(delta):
	
	if not is_my_turn:
		return  # AI waits until turn starts
			
	# Apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Update timers
	update_timers(delta)
	
	# Handle AI behavior
	handle_ai_logic()
	
	# Apply movement and animations
	move_and_slide()
	update_animations()

func update_timers(delta):
	if juggle_timer > 0:
		juggle_timer -= delta
	
	if kick_cooldown > 0:
		kick_cooldown -= delta
		if kick_cooldown <= 0:
			is_kicking = false
			disable_kick_collision()

func handle_ai_logic():
	var distance_to_sipa = abs(position.x - sipa.position.x)
	var sipa_height = sipa.position.y
	
	match current_state:
		AIState.IDLE:
			
			var turn_manager = get_node("/root/Game/TurnManager")
			if not turn_manager.is_ai_turn():
				return  # Stay idle if it’s not AI’s turn
			# Wait a bit, then start moving toward sipa
	# Countdown before starting movement
			if juggle_timer > 0:
				return

			current_state = AIState.MOVING_TO_SIPA
			print("AI: Starting to move toward sipa")

		
		AIState.MOVING_TO_SIPA:
			move_toward_sipa()
			
			# Start juggling when close enough and sipa is low enough
			if distance_to_sipa < 30 and sipa_height > position.y - 100:
				start_juggling_sequence()
		
		AIState.JUGGLING:
			# Stay close to sipa
			if distance_to_sipa > 25:
				move_toward_sipa()
			else:
				velocity.x = 0
			
			# Perform juggling actions
			if juggle_timer <= 0 and kick_cooldown <= 0:
				if juggle_count < juggle_limit:
					perform_juggle()
				else:
					perform_final_kick()
					finish_juggling()
		
		AIState.WAITING:
			# Just wait and watch
			velocity.x = 0
			if juggle_timer <= 0:
				current_state = AIState.IDLE
				print("AI: Done waiting, going idle")

func move_toward_sipa():
	var direction = 0
	var target_x = sipa.position.x
	
	# Move toward sipa with some tolerance
	if position.x < target_x - 20:
		direction = 1
	elif position.x > target_x + 20:
		direction = -1
	
	velocity.x = direction * SPEED

func start_juggling_sequence():
	if not is_juggling:
		print("AI: Starting juggling sequence!")
		is_juggling = true
		juggle_count = 0
		current_state = AIState.JUGGLING
		juggle_timer = 0.3
		


func perform_juggle():
	var turn_manager = get_node("/root/Game/TurnManager")
	if not turn_manager.is_ai_turn():
		print("AI tried to kick out of turn!")
		return  # Don’t kick if not AI's turn

	
	if is_kicking:
		return
	
	print("AI: Juggle #", juggle_count + 1)
	
	# Start kick
	is_kicking = true
	kick_cooldown = 0.4
	enable_kick_collision()
	animated_sprite.play("kick")
	
	# Light upward kick to keep sipa bouncing
	var horizontal_force = randf_range(-100, 100)  # Small random horizontal movement
	var vertical_force = -JUGGLE_FORCE
	var impulse = Vector2(horizontal_force, vertical_force)
	
	# Apply force to sipa
	sipa.apply_central_impulse(impulse)
	
	juggle_count += 1
	juggle_timer = 0.8  # Wait before next juggle

func perform_final_kick():
	
	var turn_manager = get_node("/root/Game/TurnManager")
	if not turn_manager.is_ai_turn():
		print("AI tried to kick out of turn!")
		return  # Don’t kick if not AI's turn

	if is_kicking:
		return
	
	print("AI: Final kick to player!")
	
	# Start kick
	is_kicking = true
	kick_cooldown = 0.5
	enable_kick_collision()
	animated_sprite.play("kick")
	
	# Stronger kick toward player
	var direction_to_player = 1 if player.position.x > position.x else -1
	var power_ratio = power_meter.get_power_ratio() if power_meter else 0.7
	var force = lerp(JUGGLE_FORCE, KICK_FORCE, power_ratio)
	
	var impulse = Vector2(direction_to_player * force * 0.8, -force)
	sipa.apply_central_impulse(impulse)
	
	await get_tree().create_timer(0.3).timeout  # Let animation/sipa settle
	turn_manager.successful_juggle()  # This ends turn with success

func finish_juggling():
	print("AI: Finished juggling, waiting...")
	is_juggling = false
	juggle_count = 0
	current_state = AIState.WAITING
	juggle_timer = 2.0  # Wait before starting again

func update_animations():
	# Don't change animation while kicking
	if is_kicking:
		return
	
	# Movement animations
	if abs(velocity.x) > 50:
		animated_sprite.play("run")
		animated_sprite.flip_h = (velocity.x < 0)
	else:
		animated_sprite.play("idle")

func enable_kick_collision():
	collision_layer |= 8  # Add bit 4 (Layer 3)
	print("AI: Kick collision enabled")

func disable_kick_collision():
	collision_layer &= ~8  # Remove bit 4 (Layer 3)
	print("AI: Kick collision disabled")

# Debug functions you can call from the main scene
func debug_force_juggle():
	current_state = AIState.MOVING_TO_SIPA
	juggle_timer = 0.1
	print("Debug: Forcing AI to start juggling")

func debug_reset():
	current_state = AIState.IDLE
	is_juggling = false
	is_kicking = false
	juggle_count = 0
	juggle_timer = 1.0
	kick_cooldown = 0
	disable_kick_collision()
	print("Debug: AI reset to idle state")

func debug_info():
	print("AI State: ", AIState.keys()[current_state])
	print("Distance to sipa: ", abs(position.x - sipa.position.x))
	print("Juggle count: ", juggle_count, "/", juggle_limit)
	print("Is kicking: ", is_kicking)
	print("Timers - Juggle: ", juggle_timer, " Kick: ", kick_cooldown)

#func start_ai_turn(juggles_required):
	# Use a timer or yield-based loop to kick the ball n times
	#for i in juggles_required:
		#await get_tree().create_timer(0.6).timeout
		#perform_juggle()

func start_turn():
	print("AI: My turn has started!")
	is_my_turn = true
	await get_tree().create_timer(0.1).timeout 
	current_state = AIState.IDLE
	juggle_timer = 1.0

func end_turn():
	is_my_turn = false
	velocity = Vector2.ZERO
	current_state = AIState.IDLE
	juggle_timer = 999  # Prevent retry
	kick_cooldown = 999
	disable_kick_collision()
	print("AI: My turn is over.")
