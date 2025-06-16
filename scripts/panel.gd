extends Panel

@export var heart_full: Texture
@export var heart_empty: Texture
@export var max_lives := 3

var heart_images := []

@onready var label_node: Label = get_node("HBoxContainer/Label")

func _ready():
	# Get all TextureRects inside HBoxContainer
	heart_images = $HBoxContainer.get_children()
	update_hearts(3)  # Example: start with 3 full lives

func update_hearts(lives: int):
	for i in range(heart_images.size()):
		if i < lives:
			heart_images[i].texture = heart_full
		else:
			heart_images[i].texture = heart_empty
