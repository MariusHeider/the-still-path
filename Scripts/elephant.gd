extends AnimatableBody2D
class_name Elephant
## One reusable animal, with explicit bank and travel state.
## The one-way back platform supports standing above it without pinning a
## dismounting seeker between its underside and the bank.
signal arrived()
signal bank_reached(bank: int, passenger: Seeker)

@export var entrance_offset := Vector2(190.0, 0.0)
var entrance_time := 0.0
@export var crossing_distance := 320.0
@export var crossing_time := 7.0
@export var land_height := 0.0
@export var wade_depth := 12.0
@export var shore_transition_time := 0.65
@export var rider_offset := Vector2(-4.0, -37.0)
@export var splash_volume_db := -19.0

enum State { HIDDEN, ARRIVING, WAITING, CROSSING, LANDED }
enum Bank { LEFT, RIGHT }
var state: State = State.HIDDEN
var bank: Bank = Bank.LEFT
var _home := Vector2.ZERO
var _last_splash := -1
var _passenger: Seeker
var checkpoints: Array[Vector2] = []
@onready var splash_audio := Sound.local(self, Sound.SPLASHES[0], splash_volume_db, "WaterSteps")
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_sprite.frame_changed.connect(_splash_step)
	add_to_group("interactable")
	_home = position
	position += entrance_offset
	hide()
	_shape.set_deferred("disabled", true)

func is_waiting() -> bool:
	return state in [State.WAITING, State.LANDED] and _passenger == null

func bank_position(side: int) -> Vector2:
	return _home + Vector2(crossing_distance * side, land_height)

func call_over() -> void:
	if state != State.HIDDEN: return
	var view: Rect2 = get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	var start: Vector2 = get_parent().to_global(_home + entrance_offset + Vector2(0, wade_depth))
	start.x = maxf(start.x, view.end.x + 80.0)
	sync_to_physics = false
	global_position = start
	state = State.ARRIVING
	show()
	_sprite.flip_h = true
	_sprite.play("walk")
	entrance_time = absf(position.x - bank_position(Bank.LEFT).x) / walking_speed()
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_method(_place_trip.bind(position, bank_position(Bank.LEFT), entrance_time, true),
		0.0, 1.0, entrance_time)
	tween.tween_callback(_finish_arrival)

func _finish_arrival() -> void:
	sync_to_physics = true
	bank = Bank.LEFT
	state = State.WAITING
	_sprite.flip_h = false
	_sprite.play("idle")
	_shape.set_deferred("disabled", false)
	arrived.emit()

func walking_speed() -> float:
	return crossing_distance / crossing_time

func rider_position() -> Vector2:
	return global_position + Vector2(-rider_offset.x if _sprite.flip_h else rider_offset.x, rider_offset.y)

func interact_prompt() -> String:
	return "E to climb down" if _passenger != null else "E to climb up"

func can_interact(player: Seeker) -> bool:
	if player.riding == self:
		return state == State.LANDED
	return is_waiting() and player.carried == null

func interaction_distance(player: Seeker) -> float:
	var body := Rect2(global_position + Vector2(-36, -64), Vector2(72, 64))
	return player.global_position.distance_to(player.global_position.clamp(body.position, body.end))

func interact(player: Seeker) -> void:
	if not can_interact(player): return
	if player.riding == self:
		var safe: Vector2 = checkpoints[bank] if checkpoints.size() == 2 else get_parent().to_global(bank_position(bank) + Vector2(48 if bank == Bank.RIGHT else -48, 0))
		player.dismount(safe)
		_passenger = null
		state = State.WAITING
		return
	_passenger = player
	player.mount(self)
	player.facing = 1 if bank == Bank.LEFT else -1
	travel_to(1 - bank, true)

func travel_to(destination: int, carrying := false) -> void:
	if destination == bank or destination not in [Bank.LEFT, Bank.RIGHT]: return
	if state not in [State.WAITING, State.LANDED]: return
	if _passenger != null and not carrying: return
	state = State.CROSSING
	_sprite.flip_h = destination == Bank.LEFT
	_sprite.play("walk")
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_method(_place_trip.bind(position, bank_position(destination), crossing_time, false),
		0.0, 1.0, crossing_time)
	tween.tween_callback(_finish_crossing.bind(destination))

func _place_trip(ratio: float, from: Vector2, to: Vector2, duration: float, arriving: bool) -> void:
	var elapsed := ratio * duration
	var depth := 1.0 if arriving else smoothstep(0.0, shore_transition_time, elapsed)
	depth *= 1.0 - smoothstep(duration - shore_transition_time, duration, elapsed)
	# One transform assignment: independent axis setters fight physics synchronization.
	position = Vector2(lerpf(from.x, to.x, ratio), _home.y + lerpf(land_height, wade_depth, depth))

func _finish_crossing(destination: int) -> void:
	bank = destination as Bank
	state = State.LANDED if _passenger != null else State.WAITING
	_sprite.play("idle")
	bank_reached.emit(bank, _passenger)

func _splash_step() -> void:
	if state not in [State.ARRIVING, State.CROSSING] or _sprite.animation != &"walk":
		return
	if _sprite.frame not in [0, 4] or position.y < _home.y + 2.0:
		return
	var water := get_parent().get_parent().get_node_or_null("Water") as TileMapLayer
	if water == null or water.get_cell_source_id(water.local_to_map(water.to_local(global_position))) < 0:
		return
	_last_splash = Sound.choose(Sound.SPLASHES, _last_splash)
	splash_audio.stream = Sound.stream(Sound.SPLASHES[_last_splash])
	splash_audio.play()
