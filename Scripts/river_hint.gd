extends Node

const MESSAGE := "Perhaps the way forward begins with something left behind."
const WATER_ATTEMPTS_BEFORE_HINT := 3
const SEATED_SECONDS_BEFORE_HINT := 10.0
const RIVER_PROXIMITY_X := 192.0
const RIVER_PROXIMITY_Y := 128.0

var _water_attempts := 0
var _seated_seconds := 0.0
var _hint_shown := false

@onready var _level: LevelMap = get_parent() as LevelMap
@onready var _hazard: Area2D = _level.get_node("Hazard")


func _ready() -> void:
	_hazard.body_entered.connect(_on_river_entered)


func _process(delta: float) -> void:
	if _hint_shown or _level == null or _level.player == null:
		return
	if _level._chick_rescued or _level.active_river_bank != 0:
		_seated_seconds = 0.0
		return

	var player := _level.player
	if not player.is_seated or not _is_near_left_bank(player.global_position):
		_seated_seconds = 0.0
		return

	_seated_seconds += delta
	if _seated_seconds >= SEATED_SECONDS_BEFORE_HINT:
		_show_hint()


func _on_river_entered(body: Node2D) -> void:
	if _hint_shown or not (body is Seeker):
		return
	if _level._chick_rescued or _level.active_river_bank != 0:
		return

	_water_attempts += 1
	if _water_attempts >= WATER_ATTEMPTS_BEFORE_HINT:
		_show_hint()


func _is_near_left_bank(position: Vector2) -> bool:
	var bank := _level.to_global(_level.river_checkpoints[0])
	return absf(position.x - bank.x) <= RIVER_PROXIMITY_X \
		and absf(position.y - bank.y) <= RIVER_PROXIMITY_Y


func _show_hint() -> void:
	if _hint_shown:
		return
	_hint_shown = true
	_level._show_lines([MESSAGE], 0.0)
