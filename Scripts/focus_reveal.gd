extends Focusable
class_name FocusReveal
## Existing ground is obscured by mist; entering its dense core prompts retreat.
signal passage_blocked()

@export var clear_time := 1.6
@export var mist_start := 0.0
@export var dense_core := 80.0
@export var retreat_time := 0.75
@export var reveal_volume_db := -4.0
@onready var reveal_audio := Sound.local(self, Sound.FOG, reveal_volume_db, "RevealSound")
var _cleared := false
var _remaining := 0.0
var _seeker: Seeker


func _ready() -> void:
	super()
	$Boundary.body_entered.connect(_on_entered)
	$Boundary.body_exited.connect(_on_exited)


func _on_entered(body: Node2D) -> void:
	if body is Seeker:
		_seeker = body


func _on_exited(body: Node2D) -> void:
	if body == _seeker:
		_restore_control()
		_seeker = null


func _physics_process(delta: float) -> void:
	if _cleared or not is_instance_valid(_seeker):
		return
	if _remaining > 0.0:
		_remaining = maxf(0.0, _remaining - delta)
		if _remaining == 0.0:
			_seeker.mist_retreat = false
			passage_blocked.emit()
		return
	var depth := _seeker.global_position.x - global_position.x
	var density := smoothstep(mist_start, dense_core, depth)
	_seeker.mist_speed_scale = lerpf(1.0, 0.38, density)
	if depth >= dense_core and not _seeker.is_seated:
		_remaining = retreat_time
		_seeker.mist_retreat = true


func _restore_control() -> void:
	_remaining = 0.0
	if is_instance_valid(_seeker):
		_seeker.mist_speed_scale = 1.0
		_seeker.mist_retreat = false


func _on_complete() -> void:
	reveal_audio.play()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Veil, "modulate:a", 0.0, clear_time)
	tween.tween_callback(_clear_passage)


func _clear_passage() -> void:
	_cleared = true
	_restore_control()
	$Veil.hide()
	$Boundary.set_deferred("monitoring", false)
	$Boundary/CollisionShape2D.set_deferred("disabled", true)
