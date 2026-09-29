extends Node

const MESSAGE := "Perhaps the way forward begins with something left behind."
const WATER_ATTEMPTS_BEFORE_HINT := 3
const SEATED_SECONDS_BEFORE_HINT := 10.0
const RIVER_PROXIMITY_X := 224.0
const RIVER_PROXIMITY_Y := 160.0

var _water_attempts := 0
var _seated_seconds := 0.0
var _seat_hint_shown_for_current_sit := false
var _level: Node = null
var _hazard: Area2D = null
var _message: Label = null
var _message_tween: Tween = null


func _ready() -> void:
	# Child _ready() runs before the Level's _ready(), so defer setup until the
	# level has built the river and spawned the player.
	call_deferred("_bind_level")


func _bind_level() -> void:
	_level = get_parent()
	if _level == null:
		return
	_hazard = _level.get_node_or_null("Hazard") as Area2D
	_message = _level.get_node_or_null("HUD/Message") as Label
	if _hazard != null and not _hazard.body_entered.is_connected(_on_river_entered):
		_hazard.body_entered.connect(_on_river_entered)


func _process(delta: float) -> void:
	if _level == null:
		return
	var player = _level.get("player")
	if player == null:
		return

	# Once the chick has been returned to the nest, this hint is permanently
	# irrelevant and no further attempts are counted.
	if bool(_level.get("_chick_rescued")):
		_water_attempts = 0
		_seated_seconds = 0.0
		_seat_hint_shown_for_current_sit = false
		return

	if player.is_seated and _is_near_left_bank(player.global_position):
		if not _seat_hint_shown_for_current_sit:
			_seated_seconds += delta
			if _seated_seconds >= SEATED_SECONDS_BEFORE_HINT:
				_seat_hint_shown_for_current_sit = true
				_show_hint()
	else:
		# Standing up resets the sitting hint. A later sit starts a fresh
		# ten-second wait, but the hint never repeats while one sit continues.
		_seated_seconds = 0.0
		_seat_hint_shown_for_current_sit = false


func _on_river_entered(body: Node2D) -> void:
	if _level == null:
		return
	var player = _level.get("player")
	if player == null or body != player:
		return
	if bool(_level.get("_chick_rescued")):
		return

	_water_attempts += 1
	if _water_attempts >= WATER_ATTEMPTS_BEFORE_HINT:
		_water_attempts = 0
		_show_hint()


func _is_near_left_bank(position: Vector2) -> bool:
	var checkpoints = _level.get("river_checkpoints")
	if checkpoints == null or checkpoints.size() < 1:
		return false
	var bank: Vector2 = _level.to_global(checkpoints[0])
	return absf(position.x - bank.x) <= RIVER_PROXIMITY_X \
		and absf(position.y - bank.y) <= RIVER_PROXIMITY_Y


func _show_hint() -> void:
	if _message == null:
		return
	if _message_tween != null and _message_tween.is_valid():
		_message_tween.kill()
	_message.text = MESSAGE
	_message.modulate.a = 0.0
	_message_tween = create_tween()
	_message_tween.tween_property(_message, "modulate:a", 1.0, 0.6)
	_message_tween.tween_interval(3.2)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.7)
