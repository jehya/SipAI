extends RigidBody2D

var player_touching = false

@onready var area_2d: Area2D = $Area2D

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
		apply_central_impulse(Vector2(0, -400))  # Jump upward
