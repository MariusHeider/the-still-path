extends CharacterBody2D
class_name Seeker
## The seeker. The node's origin sits at the feet, so you can drop it straight
## onto a floor tile and it lines up without fiddling with offsets.
##
## Movement is tuned in units you can actually picture: how many pixels high the
## jump is, how many seconds to reach the top. Gravity is derived from those, so
## you never have to guess at a gravity number to get the feel you want.

## Emitted every frame the player is holding still, with the running total.
signal stillness_changed(seconds_still: float)
## Emitted once when the player has been still long enough for the world to notice.
signal became_still()
## Emitted when the player moves again after having been still.
signal stopped_being_still()

@export_group("Run")
## Top running speed in pixels per second (~4.7 tiles of 32px per second).
@export var max_speed := 150.0
## Seconds to accelerate from standing to full speed on the ground.
@export var ground_accel_time := 0.08
## Seconds to come to a full stop on the ground. Lower = less skating.
@export var ground_stop_time := 0.06
@export var air_accel_time := 0.16
@export var air_stop_time := 0.22

@export_group("Jump")
## Peak height of a full jump, in pixels. 76 clears two 32px tiles comfortably.
@export var jump_height := 76.0
## Seconds to reach the top of the jump.
@export var jump_time_to_peak := 0.38
## Seconds to fall back down. Shorter than the rise = snappier, less floaty.
@export var jump_time_to_fall := 0.30
## Fraction of upward speed kept if you release the jump key early.
@export var jump_cut_factor := 0.45
@export var max_fall_speed := 420.0

@export_group("Assists")
## You can still jump for this long after walking off a ledge.
@export var coyote_time := 0.10
## A jump pressed this long before landing still fires on touchdown.
@export var jump_buffer_time := 0.12

@export_group("Stillness")
## How long the player must hold completely still before the world responds.
@export var stillness_threshold := 1.5

## 1 = facing right, -1 = facing left.
var facing := 1
var seconds_still := 0.0
var is_still := false

var _coyote_left := 0.0
var _buffer_left := 0.0

@onready var _sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_axis("move_left", "move_right")
	var jump_pressed := Input.is_action_just_pressed("jump")
	var jump_released := Input.is_action_just_released("jump")
	var any_input := not is_zero_approx(input_dir) or Input.is_action_pressed("jump")

	_tick_stillness(delta, any_input)
	_tick_timers(delta, jump_pressed)
	_apply_gravity(delta)
	_apply_horizontal(delta, input_dir)
	_try_jump()
	if jump_released and velocity.y < 0.0:
		velocity.y *= jump_cut_factor

	move_and_slide()
	_update_animation(input_dir)


# --- Movement ---------------------------------------------------------------

func _jump_velocity() -> float:
	return -2.0 * jump_height / maxf(jump_time_to_peak, 0.001)


func _rise_gravity() -> float:
	return 2.0 * jump_height / pow(maxf(jump_time_to_peak, 0.001), 2.0)


func _fall_gravity() -> float:
	return 2.0 * jump_height / pow(maxf(jump_time_to_fall, 0.001), 2.0)


func _tick_timers(delta: float, jump_pressed: bool) -> void:
	# Coyote time: refilled while grounded, drains once you leave the floor.
	_coyote_left = coyote_time if is_on_floor() else _coyote_left - delta
	# Jump buffer: remembers a press made slightly too early.
	_buffer_left = jump_buffer_time if jump_pressed else _buffer_left - delta


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var g := _rise_gravity() if velocity.y < 0.0 else _fall_gravity()
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)


func _apply_horizontal(delta: float, dir: float) -> void:
	var grounded := is_on_floor()
	var is_turning := not is_zero_approx(dir)
	var ramp_time: float
	if is_turning:
		ramp_time = ground_accel_time if grounded else air_accel_time
	else:
		ramp_time = ground_stop_time if grounded else air_stop_time
	var step := max_speed / maxf(ramp_time, 0.001) * delta
	velocity.x = move_toward(velocity.x, dir * max_speed, step)


func _try_jump() -> void:
	if _buffer_left <= 0.0 or _coyote_left <= 0.0:
		return
	velocity.y = _jump_velocity()
	# Spend both timers so one press can never produce two jumps.
	_buffer_left = 0.0
	_coyote_left = 0.0


# --- Stillness --------------------------------------------------------------
# The core verb of the game: the world only responds when you stop.

func _tick_stillness(delta: float, any_input: bool) -> void:
	var moving := any_input or not is_on_floor() or absf(velocity.x) > 1.0
	if moving:
		if seconds_still > 0.0:
			seconds_still = 0.0
			stillness_changed.emit(0.0)
		if is_still:
			is_still = false
			stopped_being_still.emit()
		return

	seconds_still += delta
	stillness_changed.emit(seconds_still)
	if not is_still and seconds_still >= stillness_threshold:
		is_still = true
		became_still.emit()


# --- Presentation -----------------------------------------------------------

func _update_animation(dir: float) -> void:
	if not is_zero_approx(dir):
		facing = 1 if dir > 0.0 else -1
	if _sprite == null:
		return
	_sprite.flip_h = facing < 0

	var next := "idle"
	if not is_on_floor():
		next = "jump" if velocity.y < 0.0 else "fall"
	elif absf(velocity.x) > 5.0:
		next = "run"
	elif is_still:
		next = "sit"

	# Fall back to whatever the sheet actually has, so a missing animation
	# never crashes the game mid-demo.
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(next):
		return
	if _sprite.animation != next:
		_sprite.play(next)
