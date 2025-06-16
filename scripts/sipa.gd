extends RigidBody2D

var touching_body: Node = null
var initial_position_player: Vector2
var initial_position_ai: Vector2

@onready var area_2d: Area2D = $Area2D

func _ready():
	await get_tree().process_frame
	area_2d.body_entered.connect(_on_body_entered)
	area_2d.body_exited.connect(_on_body_exited)

	var player_start = get_parent().get_node_or_null("PlayerStart")
	var ai_start = get_parent().get_node_or_null("AIStart")

	if player_start and ai_start:
		var offset = Vector2(0, -60)  # adjust as needed
		initial_position_player = player_start.global_position + offset
		initial_position_ai = ai_start.global_position + offset
	else:
		push_error("PlayerStart or AIStart node not found!")

	start_round("player")
	
#func set_initial_position(pos: Vector2):
	#initial_position = pos


func reset_position(who_starts: String):
	print("Sipa reset called for:", who_starts)

	var target_position = initial_position_player if who_starts == "player" else initial_position_ai
	print("Resetting to:", target_position)

	sleeping = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0
	rotation = 0

	set_deferred("global_position", target_position)
	set_deferred("sleeping", false)

	start_round(who_starts)

func _on_body_entered(body):
	if body.is_in_group("player") or body.is_in_group("enemy"):
		touching_body = body

func _on_body_exited(body):
	if body == touching_body:
		touching_body = null

func _physics_process(delta):
	if touching_body == null:
		return
		

	
	var turn_manager = get_node("/root/Game/TurnManager")
	
	
	# Prevent wrong turn kicks
	if touching_body.is_in_group("player") and not turn_manager.is_player_turn():
		return
	if touching_body.is_in_group("enemy") and not turn_manager.is_ai_turn():
		return

	# Only apply impulse if the body is currently in kick (Layer 3 → bit 4 = 8)
	if (touching_body.collision_layer & 8) != 0:
		var power_ratio = 0.5  # default if no meter

		# Use power_meter if player, otherwise default or AI's version later
		if touching_body.is_in_group("player"):
			if Input.is_action_just_pressed("kick_short"):
				power_ratio = 0.3  # Low force
			elif Input.is_action_just_pressed("kick_medium"):
				power_ratio = 0.6  # Medium force
			elif Input.is_action_just_pressed("kick_high"):
				power_ratio = 0.85  # High force

		var force = lerp(200, 900, power_ratio)

		var horizontal = 0
		if Input.is_action_pressed("move_right"):
			horizontal += 1
		if Input.is_action_pressed("move_left"):
			horizontal -= 1

		var impulse = Vector2(horizontal * 200, -force).normalized() * force
		apply_central_impulse(impulse)
		
		turn_manager.successful_juggle()

		print("Impulse by:", touching_body.name, " → ", impulse)

		# prevent multiple impulses during same kick
		touching_body = null
		
func start_round(who_starts: String):
	# Always collide with floor (Layer 4 = 8) + current kicker
	match who_starts:
		"player":
			collision_mask = 1 | 8  # Player (1) + floor (8)
		"ai":
			collision_mask = 2 | 8  # AI (2) + floor (8)

	print("Sipa collision mask set for:", who_starts)


func _on_ground_area_body_entered(body: Node2D) -> void:
	if body == self:
		print("Sipa hit the ground!")
		
		var turn_manager = get_node("/root/Game/TurnManager")
		var who_starts_next = "player" if turn_manager.is_player_turn() else "ai"
		
		turn_manager.end_turn(false)  # This should handle life deduction

		# Add this after turn ends to restart the round correctly
		reset_position(who_starts_next)
