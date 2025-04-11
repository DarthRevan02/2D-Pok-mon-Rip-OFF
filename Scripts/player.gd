extends CharacterBody2D

signal player_moving_signal
signal player_stopped_signal

@export var walk_speed: float = 6.0
const TILE_SIZE: int = 16

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray: RayCast2D = $RayCast2D

enum PlayerState { IDLE, WALKING }
enum FacingDirection { LEFT, RIGHT, UP, DOWN }

var player_state = PlayerState.IDLE
var facing_direction = FacingDirection.DOWN  # No enum typing = no cast warning

var initial_position: Vector2
var input_direction: Vector2 = Vector2(0, 1)
var is_moving := false
var percent_moved_to_next_tile := 0.0

func _ready() -> void:
	initial_position = position
	_update_animation("Idle")

func _physics_process(delta: float) -> void:
	if not is_moving:
		process_player_movement_input()
	elif input_direction != Vector2.ZERO:
		_update_animation("Walk")
		move(delta)
	else:
		_update_animation("Idle")
		is_moving = false
		emit_signal("player_stopped_signal")

func process_player_movement_input() -> void:
	var x = int(Input.is_action_pressed("WalkRight")) - int(Input.is_action_pressed("WalkLeft"))
	var y = int(Input.is_action_pressed("WalkDown")) - int(Input.is_action_pressed("WalkUp"))
	input_direction = Vector2(x, y)

	# Prevent diagonal movement
	if input_direction.x != 0:
		input_direction.y = 0
	elif input_direction.y != 0:
		input_direction.x = 0

	if input_direction != Vector2.ZERO:
		facing_direction = _direction_to_enum(input_direction)
		initial_position = position
		is_moving = true
		emit_signal("player_moving_signal")
	else:
		_update_animation("Idle")

func move(delta: float) -> void:
	var desired_step: Vector2 = input_direction * TILE_SIZE / 2
	ray.target_position = desired_step
	ray.force_raycast_update()

	if not ray.is_colliding():
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
		emit_signal("player_stopped_signal")

func _direction_to_enum(direction: Vector2) -> int:
	if abs(direction.x) > abs(direction.y):
		return FacingDirection.LEFT if direction.x < 0 else FacingDirection.RIGHT
	else:
		return FacingDirection.UP if direction.y < 0 else FacingDirection.DOWN

func _update_animation(state: String = "Idle") -> void:
	var dir := ""

	match facing_direction:
		FacingDirection.UP:
			dir = "Up"
		FacingDirection.DOWN:
			dir = "Down"
		FacingDirection.LEFT, FacingDirection.RIGHT:
			dir = "Left"  # Same anim, flip for Right
		_:
			dir = "Down"

	var anim_name = "%s%s" % [state, dir]
	sprite.flip_h = (facing_direction == FacingDirection.RIGHT and dir == "Left")

	match state:
		"Walk":
			sprite.sprite_frames.set_animation_speed(anim_name, 8)
		_:
			sprite.sprite_frames.set_animation_speed(anim_name, 10)

	if sprite.animation != anim_name:
		sprite.play(anim_name)
