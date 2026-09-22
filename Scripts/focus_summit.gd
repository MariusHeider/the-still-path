extends Focusable
class_name FocusSummit
## The final meditation inside the open shrine, followed by the ending.

@export_file("*.tscn") var next_scene := "res://Scenes/ending.tscn"
## Seconds between the stillness completing and the scene changing. Long enough
## that the player notices nothing happened.
@export var linger := 2.5
var _candidate: Seeker
var _visitor: Seeker
var _camera_offset := Vector2.ZERO


func _ready() -> void:
	super()
	$MeditationArea.body_entered.connect(_on_entered)
	$MeditationArea.body_exited.connect(_on_exited)


func _on_entered(body: Node2D) -> void:
	if body is Seeker:
		_candidate = body

func _on_exited(body: Node2D) -> void:
	if body == _candidate:
		_candidate = null
		_clear_visitor()

func contains_meditator(body: Seeker) -> bool:
	# Feet must be on the flat foundation, not merely overlapping from stairs.
	return Rect2(-128, -36, 256, 8).has_point(to_local(body.global_position))

func _physics_process(_delta: float) -> void:
	if is_instance_valid(_candidate) and contains_meditator(_candidate):
		if _visitor == _candidate: return
		_visitor = _candidate
		_visitor.meditation_site = self
		var camera: Camera2D = _visitor.get_node("Camera2D")
		_camera_offset = camera.position
		camera.position.y = -80.0
	else:
		_clear_visitor()

func _clear_visitor() -> void:
	if not is_instance_valid(_visitor): return
	_visitor.get_node("Camera2D").position = _camera_offset
	if _visitor.meditation_site == self:
		_visitor.meditation_site = null
	_visitor = null

func focus_point() -> Vector2:
	# The explicit interior zone grants attention across the whole foundation.
	return _visitor.global_position if is_instance_valid(_visitor) else global_position

func can_focus() -> bool:
	return super() and is_instance_valid(_visitor) and contains_meditator(_visitor) and _visitor.is_seated


func _on_complete() -> void:
	_visitor.lock_final_meditation()
	var tween := create_tween()
	tween.tween_interval(linger)
	tween.tween_callback(_leave)


func _leave() -> void:
	get_tree().change_scene_to_file(next_scene)

func set_highlight(_on: bool) -> void:
	# The shrine retains its original colors throughout the final meditation.
	pass
