extends Node2D

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
const grass_overlay_texture := preload("res://Assests/Grass/stepped_tall_grass.png")
const GrassStepEffect := preload("res://Scenes/tall_grass.tscn")

var grass_overlay: TextureRect = null
var player_inside: bool = false

func _ready():
	var player = get_node("/root/Town/Trees/Player") # Adjust path if needed
	if player:
		player.player_moving_signal.connect(_on_player_exiting_grass)
		player.player_stopped_signal.connect(_on_player_in_grass)

func _on_player_exiting_grass():
	player_inside = false
	if is_instance_valid(grass_overlay):
		grass_overlay.queue_free()

func _on_player_in_grass():
	if player_inside:
		# Play the animation if it's not already playing
		if anim_sprite and anim_sprite.animation != "Stepped":
			anim_sprite.play("Stepped")

		# Create and show step effect
		var grass_step_effect = GrassStepEffect.instantiate()
		grass_step_effect.position = position
		get_tree().current_scene.add_child(grass_step_effect)

		# Add overlay
		grass_overlay = TextureRect.new()
		grass_overlay.texture = grass_overlay_texture
		grass_overlay.position = position
		get_tree().current_scene.add_child(grass_overlay)

func _on_Area2D_body_entered(body):
	if body.name == "Player":
		player_inside = true
		anim_sprite.play("Stepped")  # Optional: animate on entry

func _on_AnimatedSprite2D_animation_finished():
	if anim_sprite.animation == "Stepped":
		anim_sprite.stop()
		anim_sprite.frame = 0
