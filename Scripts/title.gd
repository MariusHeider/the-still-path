extends Control
## Deliberate opening screens, followed by the timed first principle.
const LEVEL := "res://Scenes/level.tscn"
enum Stage { TITLE, CONTROLS, PREMISE, INVOLVEMENT, PRINCIPLE }
var stage := Stage.TITLE
var _transitioning := false
var _touch_available := false
@export var menu_volume_db := -22.0
@onready var menu_music := AudioStreamPlayer.new()

func _exit_tree() -> void:
	menu_music.stop()

func _ready() -> void:
	_touch_available = DisplayServer.is_touchscreen_available()
	if OS.has_feature("web"):
		var browser_touch = JavaScriptBridge.eval(
			"(('ontouchstart' in window) || (navigator.maxTouchPoints > 0))",
			true
		)
		if browser_touch is bool:
			_touch_available = _touch_available or browser_touch

	_apply_device_text()

	menu_music.name = "MenuMusic"
	menu_music.stream = Sound.stream(Sound.MENU, true)
	menu_music.volume_db = menu_volume_db
	add_child(menu_music)
	menu_music.play()


func _apply_device_text() -> void:
	if not _touch_available:
		return

	$TitleStage/Prompt.text = "Tap to continue"
	$ControlsStage/Table/Keys/Row0.text = "<"
	$ControlsStage/Table/Keys/Row1.text = ">"
	$ControlsStage/Table/Keys/Row2.text = "JUMP"
	$ControlsStage/Table/Keys/Row3.text = "SIT / ACT"
	$ControlsStage/Prompt.text = "Tap to continue"
	$PremiseStage/Prompt.text = "Tap to continue"
	$InvolvementStage/Prompt.text = "Tap to continue"


func _input(event: InputEvent) -> void:
	if _transitioning or stage == Stage.PRINCIPLE:
		return
	var pressed := event is InputEventKey and event.is_pressed() and not event.is_echo()
	pressed = pressed or (event is InputEventMouseButton and event.is_pressed())
	pressed = pressed or (event is InputEventScreenTouch and event.is_pressed())
	pressed = pressed or (event is InputEventJoypadButton and event.is_pressed())
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if stage == Stage.TITLE:
		_show_controls()
	elif stage == Stage.CONTROLS:
		_show_premise()
	elif stage == Stage.PREMISE:
		_show_involvement()
	else:
		_show_principle()


func _show_controls() -> void:
	_transitioning = true
	stage = Stage.CONTROLS
	var tween := create_tween()
	tween.tween_property($TitleStage, "modulate:a", 0.0, 0.4)
	await tween.finished
	$TitleStage.hide()
	$ControlsStage.modulate.a = 0.0
	$ControlsStage.show()
	tween = create_tween()
	tween.tween_property($ControlsStage, "modulate:a", 1.0, 0.5)
	await tween.finished
	_transitioning = false


func _show_premise() -> void:
	_transitioning = true
	stage = Stage.PREMISE
	var tween := create_tween()
	tween.tween_property($ControlsStage, "modulate:a", 0.0, 0.4)
	await tween.finished
	$ControlsStage.hide()
	$PremiseStage.modulate.a = 0.0
	$PremiseStage.show()
	tween = create_tween()
	tween.tween_property($PremiseStage, "modulate:a", 1.0, 0.5)
	await tween.finished
	_transitioning = false


func _show_involvement() -> void:
	_transitioning = true
	stage = Stage.INVOLVEMENT
	var tween := create_tween()
	tween.tween_property($PremiseStage, "modulate:a", 0.0, 0.4)
	await tween.finished
	$PremiseStage.hide()
	$InvolvementStage.modulate.a = 0.0
	$InvolvementStage.show()
	tween = create_tween()
	tween.tween_property($InvolvementStage, "modulate:a", 1.0, 0.5)
	await tween.finished
	_transitioning = false


func _show_principle() -> void:
	_transitioning = true
	stage = Stage.PRINCIPLE
	var tween := create_tween()
	tween.tween_property($InvolvementStage, "modulate:a", 0.0, 0.5)
	await tween.finished
	$InvolvementStage.hide()
	$Principle.modulate.a = 0.0
	$Principle.show()
	create_tween().tween_property(menu_music, "volume_db", -70.0, 3.9)
	tween = create_tween()
	tween.tween_property($Principle, "modulate:a", 1.0, 0.8)
	tween.tween_interval(2.4)
	tween.tween_property($Principle, "modulate:a", 0.0, 0.7)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(LEVEL))
