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
signal teleported()
signal movement_relocated()
signal final_meditation_succeeded()
var final_success := false

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

@export_group("Interaction")
## How near he has to be for E to act on something rather than sit down.
@export var interact_radius := 44.0

@export_group("Recovery")
## Below this y the seeker has left the world and is put back. The level sets it
## from the map height; the default only matters if he is used outside one.
@export var fall_limit := 100000.0

@export_group("Awareness")
## Where the attention appears, relative to the seated body.
@export var awareness_offset := Vector2(0.0, -22.0)

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
## Set by a ProjectionZone. Attention can only leave the body where the level
## says it can, or the ability would be a way past every other puzzle.
var can_project := false
var projection_zones: Array[Area2D] = []
## What he is holding, if anything.
var carried: Node2D = null
## What he is riding, if anything.
var riding: Node2D = null
## Set only by the final shrine's meditation area.
var meditation_site: Node2D = null
var _final_meditation := false
## Only the unrevealed mist adjusts these; all other movement keeps its tuning.
var mist_speed_scale := 1.0
var mist_retreat := false
var is_seated := false
var seconds_still := 0.0
var is_still := false

var _coyote_left := 0.0
var _buffer_left := 0.0
## Name of a one-shot animation currently blocking the state animations.
var _transition := ""

var _teleporting := false
## The last place he stood safely, used to put him back after a fall.
var _last_safe := Vector2.ZERO

@onready var _sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var _awareness: Awareness = get_node_or_null("Awareness")


func _ready() -> void:
	add_to_group("seeker")
	if _sprite != null:
		_sprite.animation_finished.connect(_on_sprite_animation_finished)


## Everything the focus system measures is measured from here: the attention if
## it has been sent out, the body otherwise.
func focus_origin() -> Vector2:
	if _awareness != null and _awareness.active:
		return _awareness.global_position
	return global_position


func _physics_process(delta: float) -> void:
	if final_success:
		velocity = Vector2.ZERO
		_play("meditate")
		return
	if _teleporting:
		move_and_slide()
		return
	if riding != null:
		_process_riding()
		return
	if global_position.y > fall_limit:
		respawn()
		return
	# Remember solid ground, but only while standing still enough that the spot
	# is somewhere he could be put back down without immediately falling again.
	if is_on_floor() and absf(velocity.x) < 40.0:
		_last_safe = global_position
	var input_dir := Input.get_axis("move_left", "move_right")
	var jump_pressed := Input.is_action_just_pressed("jump")
	var sit_pressed := Input.is_action_just_pressed("interact")
	if mist_retreat:
		input_dir = -0.45
		jump_pressed = false
		sit_pressed = false

	if is_seated:
		_process_seated(delta, input_dir, jump_pressed, sit_pressed)
	else:
		_process_walking(delta, input_dir, jump_pressed, sit_pressed)

	move_and_slide()
	_update_animation(input_dir)


# --- States -----------------------------------------------------------------

func _process_walking(delta: float, dir: float, jump_pressed: bool,
		sit_pressed: bool) -> void:
	if sit_pressed:
		# One key, and context decides. Something within reach takes priority
		# over sitting, because if there is a chick at your feet you are not
		# there to meditate.
		var thing := current_interactable()
		if thing != null:
			thing.interact(self)
			return
		if is_on_floor() and absf(velocity.x) < sit_max_speed:
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
	# If the ground goes out from under him he should not stay kneeling in mid-air.
	if not is_on_floor():
		_set_seated(false)
		return

	if not is_still:
		# Still settling. Any deliberate move abandons it, which is what lets a
		# player who sat down by accident get straight back up.
		if sit_pressed or jump_pressed or not is_zero_approx(dir):
			_set_seated(false)
			return
	else:
		_steer_awareness(delta)
		# E means "go to where your attention is". If the attention is still at
		# the body, that is just standing up.
		if sit_pressed:
			_commit()
			return

	velocity.x = 0.0
	_apply_gravity(delta)

	seconds_still += delta
	stillness_changed.emit(seconds_still)
	if not is_still and seconds_still >= stillness_threshold:
		is_still = true
		if _awareness != null and can_project:
			_awareness.activate(global_position + awareness_offset)
		became_still.emit()


func _set_seated(seated: bool) -> void:
	if final_success:
		return
	if is_seated == seated:
		return
	is_seated = seated
	_final_meditation = seated and meditation_site != null
	if seated:
		_play_transition("meditate_down" if _final_meditation else "sit_down")
	else:
		_transition = ""
		if _awareness != null:
			_awareness.deactivate()
	if not seated:
		seconds_still = 0.0
		stillness_changed.emit(0.0)
		if is_still:
			is_still = false
			stopped_being_still.emit()
	seated_changed.emit(seated)


## The nearest thing E would act on, or null if E should just sit him down.
func current_interactable() -> Node:
	var best: Node = null
	var best_distance := interact_radius
	for node in get_tree().get_nodes_in_group("interactable"):
		if not node.has_method("can_interact") or not node.can_interact(self):
			continue
		var distance: float = global_position.distance_to(node.global_position)
		if node.has_method("interaction_distance"):
			distance = node.interaction_distance(self)
		if distance <= best_distance:
			best_distance = distance
			best = node
	return best


# --- Riding -----------------------------------------------------------------

func mount(what: Node2D) -> void:
	movement_relocated.emit()
	riding = what
	velocity = Vector2.ZERO
	facing = 1
	_set_seated(false)


func dismount(at: Vector2) -> void:
	movement_relocated.emit()
	riding = null
	global_position = at
	velocity = Vector2.ZERO


func _process_riding() -> void:
	velocity = Vector2.ZERO
	global_position = riding.rider_position()
	if Input.is_action_just_pressed("interact") and riding.can_interact(self):
		riding.interact(self)
		return
	_update_animation(0.0)


## Puts him back on the last ground he stood on. Used for falling out of the
## world and for anything he should not be able to walk into.
func respawn() -> void:
	respawn_at(_last_safe)


## A level hazard can supply a fixed safe point without changing pit recovery.
func respawn_at(at: Vector2) -> void:
	movement_relocated.emit()
	_set_seated(false)
	velocity = Vector2.ZERO
	global_position = at


# --- Awareness --------------------------------------------------------------

func _steer_awareness(delta: float) -> void:
	if _awareness == null:
		return
	var direction := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down"))
	_awareness.steer(direction, delta, global_position + awareness_offset)


func _commit() -> void:
	if _awareness != null and _awareness.is_projected():
		var landing = _awareness.find_landing()
		if landing != null:
			_teleport_to(landing)
			return
	_set_seated(false)


func _teleport_to(landing: Vector2) -> void:
	_teleporting = true
	velocity = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func() -> void:
		global_position = landing
		movement_relocated.emit()
		teleported.emit())
	tween.tween_interval(0.15)
	tween.tween_property(_sprite, "modulate:a", 1.0, 0.4)
	tween.tween_callback(_finish_teleport)


func _finish_teleport() -> void:
	_teleporting = false
	_set_seated(false)


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
	var speed_scale := mist_speed_scale if dir > 0.0 else 1.0
	velocity.x = move_toward(velocity.x, dir * max_speed * speed_scale, step)


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
	_sprite.flip_h = facing < 0 and not _final_meditation

	# A one-shot transition (lowering into the kneel) plays to the end before
	# anything else takes over.
	if _transition != "":
		return

	var next := "idle"
	if riding != null:
		_play("idle")
		return
	if is_seated:
		next = "meditate" if _final_meditation else "sit"
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

func lock_final_meditation() -> void:
	if final_success:
		return
	final_success = true
	is_seated = true
	_final_meditation = true
	_transition = ""
	velocity = Vector2.ZERO
	_play("meditate")
	final_meditation_succeeded.emit()
