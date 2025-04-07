extends CharacterBody2D

signal player_moving_signal
signal player_stopped_signal
signal player_entering_door_signal
signal player_entered_door_signal

const LandingDustEffect = preload("res://LandingDustEffect.tscn")

@export var walk_speed: float = 4.0
@export var jump_speed: float = 4.0
const TILE_SIZE: int = 16

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray: RayCast2D = $BlockingRayCast2D
@onready var ledge_ray: RayCast2D = $LedgeRayCast2D
@onready var door_ray: RayCast2D = $DoorRayCast2D
@onready var shadow: Node2D = $Shadow

var jumping_over_ledge := false

enum PlayerState { IDLE, TURNING, WALKING }
enum FacingDirection { LEFT, RIGHT, UP, DOWN }

var player_state := PlayerState.IDLE
var facing_direction := FacingDirection.DOWN

var initial_position: Vector2
var input_direction: Vector2 = Vector2(0, 1)
var is_moving := false
var stop_input := false
var percent_moved_to_next_tile := 0.0

func _ready() -> void:
	sprite.visible = true
	initial_position = position
	shadow.visible = false
	_update_animation("Idle")

func set_spawn(location: Vector2, direction: Vector2) -> void:
	_update_facing_from_direction(direction)
	position = location

func _physics_process(delta: float) -> void:
	if player_state == PlayerState.TURNING or stop_input:
		return
	elif not is_moving:
		process_player_movement_input()
	elif input_direction != Vector2.ZERO:
		_update_animation("Walk")
		move(delta)
	else:
		_update_animation("Idle")
		is_moving = false

func process_player_movement_input() -> void:
	var x = int(Input.is_action_pressed("WalkRight")) - int(Input.is_action_pressed("WalkLeft"))
	var y = int(Input.is_action_pressed("WalkDown")) - int(Input.is_action_pressed("WalkUp"))
	input_direction = Vector2(x, y).normalized()

	if input_direction != Vector2.ZERO:
		var new_facing = _direction_to_enum(input_direction)
		if new_facing != facing_direction:
			facing_direction = new_facing
			player_state = PlayerState.TURNING
			_update_animation("Turn")
		else:
			initial_position = position
			is_moving = true
	else:
		_update_animation("Idle")

func _direction_to_enum(direction: Vector2) -> int:
	if abs(direction.x) > abs(direction.y):
		return FacingDirection.LEFT if direction.x < 0 else FacingDirection.RIGHT
	else:
		return FacingDirection.UP if direction.y < 0 else FacingDirection.DOWN

func finished_turning() -> void:
	player_state = PlayerState.IDLE

func entered_door() -> void:
	emit_signal("player_entered_door_signal")

func move(delta: float) -> void:
	var desired_step: Vector2 = input_direction * TILE_SIZE / 2
	ray.target_position = desired_step
	ray.force_raycast_update()
	ledge_ray.target_position = desired_step
	ledge_ray.force_raycast_update()
	door_ray.target_position = desired_step
	door_ray.force_raycast_update()

	if door_ray.is_colliding():
		if percent_moved_to_next_tile == 0.0:
			emit_signal("player_entering_door_signal")

		percent_moved_to_next_tile += walk_speed * delta
		if percent_moved_to_next_tile >= 1.0:
			position = initial_position + (input_direction * TILE_SIZE)
			percent_moved_to_next_tile = 0.0
			is_moving = false
			stop_input = true
			$AnimationPlayer.play("Disappear")
			$Camera2D.clear_current()
		else:
			position = initial_position + (input_direction * TILE_SIZE * percent_moved_to_next_tile)

	elif (ledge_ray.is_colliding() and input_direction == Vector2(0, 1)) or jumping_over_ledge:
		percent_moved_to_next_tile += jump_speed * delta
		if percent_moved_to_next_tile >= 2.0:
			position = initial_position + (input_direction * TILE_SIZE * 2)
			percent_moved_to_next_tile = 0.0
			is_moving = false
			jumping_over_ledge = false
			shadow.visible = false

			var dust_effect = LandingDustEffect.instantiate()
			dust_effect.position = position
			get_tree().current_scene.add_child(dust_effect)
		else:
			shadow.visible = true
			jumping_over_ledge = true
			var input := input_direction.y * TILE_SIZE * percent_moved_to_next_tile
			position.y = initial_position.y + (-0.96 - 0.53 * input + 0.05 * pow(input, 2))

	elif not ray.is_colliding():
		if percent_moved_to_next_tile == 0.0:
			emit_signal("player_moving_signal")

		percent_moved_to_next_tile += walk_speed * delta
		if percent_moved_to_next_tile >= 1.0:
			position = initial_position + (input_direction * TILE_SIZE)
			percent_moved_to_next_tile = 0.0
			is_moving = false
			emit_signal("player_stopped_signal")
		else:
			position = initial_position + (input_direction * TILE_SIZE * percent_moved_to_next_tile)
	else:
		is_moving = false

func _update_facing_from_direction(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		facing_direction = FacingDirection.LEFT if direction.x < 0 else FacingDirection.RIGHT
	else:
		facing_direction = FacingDirection.UP if direction.y < 0 else FacingDirection.DOWN

func _update_animation(state: String = "Idle") -> void:
	var dir := ""

	match facing_direction:
		FacingDirection.UP:
			dir = "Up"
		FacingDirection.DOWN:
			dir = "Down"
		FacingDirection.LEFT:
			dir = "Left"
		FacingDirection.RIGHT:
			dir = "Right"
		_:
			dir = "Down"

	var anim_name = "%s%s" % [state, dir]

	# Flip for right-facing animations
	sprite.flip_h = facing_direction == FacingDirection.RIGHT and state in ["Walk", "Idle", "Turn"]

	# Set animation speed according to state
	match state:
		"Walk":
			sprite.sprite_frames.set_animation_speed(anim_name, 5) # 0.8s total
		"Turn":
			sprite.sprite_frames.set_animation_speed(anim_name, 20) # 0.1s total with 2 frames = 20 FPS
		_:
			sprite.sprite_frames.set_animation_speed(anim_name, 10) # Default speed

	if sprite.animation != anim_name:
		sprite.play(anim_name)
