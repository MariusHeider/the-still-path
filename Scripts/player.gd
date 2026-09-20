extends CharacterBody2D
class_name Seeker
## The seeker. The origin sits at the feet, so you can drop the node straight
## onto a floor tile and it lines up without fiddling with offsets.
##
## Movement is tuned in units you can picture: how many pixels high the jump is,
## how many seconds to reach the top. Gravity is derived from those, so you
## never have to guess at a gravity number to get the feel you want.
##
## The seeker has two states. Walking, and seated. Sitting is a deliberate press
## rather than an absence of input -- the player should always know they did
## something -- and while seated he cannot move at all. Everything the seeker
## can affect in the world happens from that seated stillness; see
## focus_system.gd.

## Emitted every frame while seated, with the running total held.
signal stillness_changed(seconds_still: float)
## Emitted once the seeker has been still long enough for the world to notice.
signal became_still()
## Emitted when the stillness ends, whether by standing or by falling.
signal stopped_being_still()
signal seated_changed(seated: bool)

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
## How long after sitting down before the count even begins. This is the
## settling-in moment: the seeker is lowering himself and arriving, and nothing
## should be responding to him yet. The focus system starts from zero only once
## this has passed, so the total wait is this plus the object's own focus_time.
@export var stillness_threshold := 1.0
## Below this speed, the seeker is considered steady enough to sit down.
@export var sit_max_speed := 20.0

## 1 = facing right, -1 = facing left.
var facing := 1
var is_seated := false
var seconds_still := 0.0
var is_still := false

var _coyote_left := 0.0
var _buffer_left := 0.0
## Name of a one-shot animation currently blocking the state animations.
var _transition := ""

@onready var _sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")


func _ready() -> void:
	if _sprite != null:
		_sprite.animation_finished.connect(_on_sprite_animation_finished)


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_axis("move_left", "move_right")
	var jump_pressed := Input.is_action_just_pressed("jump")
	var sit_pressed := Input.is_action_just_pressed("interact")

	if is_seated:
		_process_seated(delta, input_dir, jump_pressed, sit_pressed)
	else:
		_process_walking(delta, input_dir, jump_pressed, sit_pressed)

	move_and_slide()
	_update_animation(input_dir)


# --- States -----------------------------------------------------------------

func _process_walking(delta: float, dir: float, jump_pressed: bool,
		sit_pressed: bool) -> void:
	if sit_pressed and is_on_floor() and absf(velocity.x) < sit_max_speed:
		_set_seated(true)
		velocity = Vector2.ZERO
		return

	_tick_timers(delta, jump_pressed)
	_apply_gravity(delta)
	_apply_horizontal(delta, dir)
	_try_jump()
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_factor


func _process_seated(delta: float, dir: float, jump_pressed: bool,
		sit_pressed: bool) -> void:
	# Any intention to move ends the sitting. Falling does too -- if the ground
	# is pulled out from under him he should not stay cross-legged in mid-air.
	if sit_pressed or jump_pressed or not is_zero_approx(dir) or not is_on_floor():
		_set_seated(false)
		return

	velocity.x = 0.0
	_apply_gravity(delta)

	seconds_still += delta
	stillness_changed.emit(seconds_still)
	if not is_still and seconds_still >= stillness_threshold:
		is_still = true
		became_still.emit()


func _set_seated(seated: bool) -> void:
	if is_seated == seated:
		return
	is_seated = seated
	if seated:
		_play_transition("sit_down")
	else:
		_transition = ""
	if not seated:
		seconds_still = 0.0
		stillness_changed.emit(0.0)
		if is_still:
			is_still = false
			stopped_being_still.emit()
	seated_changed.emit(seated)


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
	var ramp_time: float
	if not is_zero_approx(dir):
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


# --- Presentation -----------------------------------------------------------

func _update_animation(dir: float) -> void:
	if not is_zero_approx(dir) and not is_seated:
		facing = 1 if dir > 0.0 else -1
	if _sprite == null:
		return
	_sprite.flip_h = facing < 0

	# A one-shot transition (lowering into the kneel) plays to the end before
	# anything else takes over.
	if _transition != "":
		return

	var next := "idle"
	if is_seated:
		next = "sit"
	elif not is_on_floor():
		next = "jump" if velocity.y < 0.0 else "fall"
	elif absf(velocity.x) > 5.0:
		next = "walk"

	_play(next)


## Plays an animation if the sheet actually has it, so a sheet missing one never
## crashes the game mid-demo.
func _play(name: String) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(name):
		return
	if _sprite.animation != name:
		_sprite.play(name)


## Plays a one-shot animation that blocks the normal state animations until it
## finishes. Used for sitting down, where cutting straight to the held pose
## loses the whole movement.
func _play_transition(name: String) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(name):
		return
	_transition = name
	_sprite.play(name)


func _on_sprite_animation_finished() -> void:
	_transition = ""
