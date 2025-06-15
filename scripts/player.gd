extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

var is_kicking = false
var kick_timer = 0.0
const KICK_DURATION = 0.3

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func enable_kick_collision():
	collision_layer |= 8  # Add Layer 4th bit → Layer 3 (Sipa layer)

func disable_kick_collision():
	collision_layer &= ~8  # Remove Layer 3 bit
	
func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("dribble") and not is_kicking:
		is_kicking = true
		kick_timer = KICK_DURATION
		enable_kick_collision()
		animated_sprite_2d.play("kick")
		
	if is_kicking:
		kick_timer -= delta
		if kick_timer <= 0.0:
			is_kicking = false
			disable_kick_collision()
	else:
		var direction := Input.get_axis("move_left", "move_right")
	
		#Flip the sprite
		if direction > 0:
			animated_sprite_2d.flip_h = true
		elif direction < 0:
			animated_sprite_2d.flip_h = false
			
		#Play animations
		if direction == 0:
			animated_sprite_2d.play("idle")
		else:
			animated_sprite_2d.play("run")
		
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
