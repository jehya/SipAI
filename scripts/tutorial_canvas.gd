extends CanvasLayer

signal tutorial_finished

@onready var texture_rect = $Panel/TextureRect
@onready var skip_button = $Panel/Skip
@onready var next_button = $Panel/Next
@onready var prev_button = $Panel/Previous

# Exported array of tutorial images
@export var tutorial_images: Array[Texture]

var current_index := 0

func _ready():
	visible = false
	skip_button.pressed.connect(hide_tutorial)
	next_button.pressed.connect(show_next)
	prev_button.pressed.connect(show_previous)

func start_tutorial():
	current_index = 0
	visible = true
	update_image()

func update_image():
	texture_rect.texture = tutorial_images[current_index]
	prev_button.disabled = current_index == 0
	next_button.disabled = current_index == tutorial_images.size() - 1

func show_next():
	if current_index < tutorial_images.size() - 1:
		current_index += 1
		update_image()

func show_previous():
	if current_index > 0:
		current_index -= 1
		update_image()

func hide_tutorial():
	visible = false
	emit_signal("tutorial_finished")
