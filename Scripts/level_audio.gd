extends Node
## Reversible mountain crossfade; the accepted mix levels are preserved.
@export var ambience_db := -18.0
@export var mountain_db := -14.0
@export var crossfade_seconds := 5.0
var mountain_started := false
var _fade: Tween
var _wind_started := false
@onready var main := AudioStreamPlayer.new()
@onready var wind := AudioStreamPlayer.new()

func _exit_tree() -> void:
	main.stop()
	wind.stop()

func _ready() -> void:
	main.name = "MainAmbience"
	wind.name = "MountainWind"
	main.stream = Sound.stream(Sound.AMBIENCE, true)
	wind.stream = Sound.stream(Sound.MOUNTAIN, true)
	add_child(main)
	add_child(wind)
	main.volume_db = -30.0
	wind.volume_db = -30.0
	main.play()
	_fade = create_tween()
	_fade.tween_property(main, "volume_db", ambience_db, 1.5)

func enter_mountain(body: Node2D) -> void:
	if body is Seeker:
		_crossfade(true)

func leave_mountain(body: Node2D) -> void:
	if body is Seeker:
		_crossfade(false)

func _crossfade(inside: bool) -> void:
	if mountain_started == inside: return
	mountain_started = inside
	if _fade != null: _fade.kill()
	if not _wind_started and inside:
		wind.volume_linear = 0.0
		wind.play()
		_wind_started = true
	main.stream_paused = false
	wind.stream_paused = false
	_fade = create_tween().set_parallel()
	_fade.tween_property(main, "volume_linear", db_to_linear(-40.0 if inside else ambience_db), crossfade_seconds)
	_fade.tween_property(wind, "volume_linear", db_to_linear(mountain_db if inside else -30.0), crossfade_seconds)
	# Keep the accepted fade levels, then ease the quiet bed completely to silence
	# before pausing. Resuming from zero prevents an audible step on re-entry.
	_fade.chain().tween_property(main if inside else wind, "volume_linear", 0.0, 0.3)
	_fade.chain().tween_callback(func() -> void:
		main.stream_paused = inside
		wind.stream_paused = not inside)
