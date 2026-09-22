extends AudioStreamPlayer2D
## One continuous local stream, attenuated by distance from the actual river.
@export var river_volume_db := -26.0
func _ready() -> void:
	_start.call_deferred()
func _start() -> void:
	var water: Rect2i = get_parent().get_used_rect()
	position = Vector2((water.position.x + water.size.x * 0.5) * 32, water.position.y * 32 + 8)
	stream = Sound.stream(preload("res://Assets/Audio/SFX/Ambience/Stream.ogg"), true)
	volume_db = river_volume_db
	max_distance = 480.0
	attenuation = 1.4
	play()
