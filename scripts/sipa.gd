extends RigidBody2D

var player_touching = false

@onready var area_2d: Area2D = $Area2D
@onready var power_meter: Control = $"../CanvasLayer/PowerMeter"
@onready var player: CharacterBody2D = $"../Player"

func _ready():
	$Area2D.body_entered.connect(_on_body_entered)
	$Area2D.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):  # Recommended over name checks
		player_touching = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_touching = false

func _physics_process(delta):
	if player_touching and Input.is_action_just_pressed("dribble"):
		var power_ratio = power_meter.get_power_ratio()
		var force = lerp(300, 800, power_ratio)

		var horizontal = 0
		if Input.is_action_pressed("move_right"):
			horizontal += 1
		if Input.is_action_pressed("move_left"):
			horizontal -= 1

		# Compute the impulse based on direction
		var impulse = Vector2(horizontal * 200, -force).normalized() * force
		apply_central_impulse(impulse)

		print("Impulse: ", impulse)
