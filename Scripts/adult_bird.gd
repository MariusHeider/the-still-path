extends Node2D
## A small parent bird, with a screen-readable bubble pointing to its perch.
signal arrived()
signal speech_started(line: String)
signal speech_finished(line: String)
signal departed()
signal departure_started()

var _bob := 0.0
var _speaking := false
var _speech_tween: Tween
@export var chirp_volume_db := -24.0
@onready var chirp_audio := Sound.local(self, Sound.BIRD, chirp_volume_db, "ChirpSound")


func _ready() -> void:
	hide()
	$Speech/Bubble.hide()
	$Speech/Tail.hide()


func arrive(at: Vector2) -> Tween:
	var view: Rect2 = get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	global_position = Vector2(at.x + 100, minf(at.y - 100, view.position.y - 32))
	show()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", at + Vector2(30, -40), 0.9)
	tween.tween_property(self, "global_position", at, 0.7)
	tween.tween_callback(func() -> void:
		chirp_audio.play()
		arrived.emit())
	tween.tween_interval(0.35)
	return tween


func say(line: String) -> Tween:
	var label: Label = $Speech/Bubble/Text
	var text_width := label.get_theme_font("font").get_string_size(
		line, HORIZONTAL_ALIGNMENT_LEFT, -1,
		label.get_theme_font_size("font_size")
	).x

	label.autowrap_mode = (
		TextServer.AUTOWRAP_OFF if text_width <= 240
		else TextServer.AUTOWRAP_WORD
	)
	label.text = line
	label.custom_minimum_size.x = minf(240, text_width)
	label.update_minimum_size()
	$Speech/Bubble.update_minimum_size()
	_resize_bubble.call_deferred()
	_speaking = true
	$Speech/Bubble.modulate.a = 0.0
	$Speech/Tail.modulate.a = 0.0
	speech_started.emit(line)
	_speech_tween = create_tween()
	_speech_tween.tween_property($Speech/Bubble, "modulate:a", 1.0, 0.25)
	_speech_tween.parallel().tween_property($Speech/Tail, "modulate:a", 1.0, 0.25)
	_speech_tween.tween_interval(maxf(2.8, line.length() * 0.085))
	_speech_tween.tween_property($Speech/Bubble, "modulate:a", 0.0, 0.35)
	_speech_tween.parallel().tween_property($Speech/Tail, "modulate:a", 0.0, 0.35)
	_speech_tween.tween_callback(func() -> void:
		_speaking = false
		$Speech/Bubble.hide()
		$Speech/Tail.hide()
		speech_finished.emit(line))
	return _speech_tween

func _resize_bubble() -> void:
	var bubble: PanelContainer = $Speech/Bubble
	bubble.reset_size()
	await get_tree().process_frame
	bubble.reset_size()

func leave(destination: Vector2) -> Tween:
	departure_started.emit()
	$Visual.scale.x = -1.0 if destination.x < global_position.x else 1.0
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var lift := global_position + Vector2(-45, -60)
	tween.tween_property(self, "global_position", lift, 0.7)
	tween.tween_property(self, "global_position", destination,
		maxf(1.2, lift.distance_to(destination) / 180.0))
	tween.tween_callback(func() -> void:
		departed.emit())
	return tween


func _process(delta: float) -> void:
	if not visible:
		return
	_bob += delta
	$Visual.position.y = -1.0 if fmod(_bob, 3.0) > 2.3 else 0.0
	if not _speaking:
		return
	var tip := get_global_transform_with_canvas() * Vector2(0, -24)
	var view := get_viewport_rect()
	var on_screen := view.has_point(tip)
	$Speech/Bubble.visible = on_screen
	$Speech/Tail.visible = on_screen
	var bubble: PanelContainer = $Speech/Bubble
	bubble.position = (tip - Vector2(bubble.size.x * 0.5, bubble.size.y + 12)).clamp(
		Vector2(12, 12), view.size - bubble.size - Vector2(12, 12))
	var edge := Vector2(clampf(tip.x, bubble.position.x + 10, bubble.position.x + bubble.size.x - 10),
		bubble.position.y + bubble.size.y)
	if tip.y < bubble.position.y:
		edge.y = bubble.position.y
	$Speech/Tail.polygon = PackedVector2Array([edge + Vector2(-5, -1), edge + Vector2(5, -1), tip])
