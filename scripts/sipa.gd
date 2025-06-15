extends RigidBody2D

var touching_body: Node = null

@onready var area_2d: Area2D = $Area2D

func _ready():
	area_2d.body_entered.connect(_on_body_entered)
	area_2d.body_exited.connect(_on_body_exited)

	start_round("player")  # or "ai"


func _on_body_entered(body):
	if body.is_in_group("player") or body.is_in_group("enemy"):
		touching_body = body

func _on_body_exited(body):
	if body == touching_body:
		touching_body = null

func _physics_process(delta):
	if touching_body == null:
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
