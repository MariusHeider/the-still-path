extends Node

const MESSAGE := "Perhaps the way forward begins with something left behind."
const WATER_ATTEMPTS_BEFORE_HINT := 3
const SEATED_SECONDS_BEFORE_HINT := 10.0
const RIVER_PROXIMITY_X := 224.0
const RIVER_PROXIMITY_Y := 160.0

var _water_attempts := 0
var _level: Node = null
var _hazard: Area2D = null
var _message: Label = null
var _message_tween: Tween = null
var _sit_timer: Timer = null


func _ready() -> void:
	# The level builds the river and spawns the player in its own _ready(), so
	# bind one frame later.
	call_deferred("_bind_level")


func _bind_level() -> void:
	_level = get_parent()
	if _level == null:
		return

	_hazard = _level.get_node_or_null("Hazard") as Area2D
	_message = _level.get_node_or_null("HUD/Message") as Label
	var player = _level.get("player")

	if _hazard != null and not _hazard.body_entered.is_connected(_on_river_entered):
		_hazard.body_entered.connect(_on_river_entered)

	if player != null and not player.seated_changed.is_connected(_on_seated_changed):
		player.seated_changed.connect(_on_seated_changed)

	_sit_timer = Timer.new()
	_sit_timer.one_shot = true
	_sit_timer.wait_time = SEATED_SECONDS_BEFORE_HINT
	_sit_timer.timeout.connect(_on_sit_timer_timeout)
	add_child(_sit_timer)


func _on_river_entered(body: Node2D) -> void:
	if _level == null or _chick_is_rescued():
		return

	var player = _level.get("player")
	if player == null or body != player:
		return

	_water_attempts += 1
	if _water_attempts == WATER_ATTEMPTS_BEFORE_HINT:
		_water_attempts = 0
		_show_hint()


func _on_seated_changed(seated: bool) -> void:
	if _sit_timer == null:
		return

	# Every new sit is a fresh attempt. Standing up always cancels and resets it.
	_sit_timer.stop()

	if not seated or _level == null or _chick_is_rescued():
		return

	var player = _level.get("player")
	if player != null and _is_near_left_bank(player.global_position):
		_sit_timer.start()


func _on_sit_timer_timeout() -> void:
	if _level == null or _chick_is_rescued():
		return

	var player = _level.get("player")
	if player == null:
		return

	# The timer is one-shot: this can happen only once for the current sit.
	# A later stand + sit starts a new ten-second timer.
	if player.is_seated and _is_near_left_bank(player.global_position):
		_show_hint()


func _chick_is_rescued() -> bool:
	return _level != null and bool(_level.get("_chick_rescued"))


func _is_near_left_bank(position: Vector2) -> bool:
	var checkpoints = _level.get("river_checkpoints")
	if checkpoints == null or checkpoints.size() < 1:
		return false
	var bank: Vector2 = _level.to_global(checkpoints[0])
	return absf(position.x - bank.x) <= RIVER_PROXIMITY_X \
		and absf(position.y - bank.y) <= RIVER_PROXIMITY_Y


func _show_hint() -> void:
	if _message == null or _chick_is_rescued():
		return

	# Restart the visual cleanly if another valid trigger happens while the
	# previous hint is still fading.
	if _message_tween != null and _message_tween.is_valid():
		_message_tween.kill()

	_message.text = MESSAGE
	_message.modulate.a = 0.0
	_message_tween = create_tween()
	_message_tween.tween_property(_message, "modulate:a", 1.0, 0.6)
	_message_tween.tween_interval(3.2)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.7)
