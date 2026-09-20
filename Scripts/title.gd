extends Control
## Opening screen. Explains the controls, then names the tool.
##
## The first tool of the crash course is "all the rules are my rules", and the
## one place in a game where that is literally true is the controls screen. So
## the line arrives AFTER the player has read the rules, not before: it lands as
## a recognition rather than as a lesson to be applied.

const LEVEL := "res://Scenes/level.tscn"

var _started := false


func _ready() -> void:
	$Tool.modulate.a = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return
	var pressed_key := event is InputEventKey and event.is_pressed() and not event.is_echo()
	var pressed_mouse := event is InputEventMouseButton and event.is_pressed()
	if pressed_key or pressed_mouse:
		_begin()


func _begin() -> void:
	_started = true
	var tween := create_tween()
	tween.tween_property($Title, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property($Controls, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property($Prompt, "modulate:a", 0.0, 0.4)
	tween.tween_property($Tool, "modulate:a", 1.0, 0.9)
	tween.tween_interval(2.8)
	tween.tween_property($Tool, "modulate:a", 0.0, 0.9)
	tween.tween_callback(_enter_level)


func _enter_level() -> void:
	get_tree().change_scene_to_file(LEVEL)
