extends Control
## Opening screen. Explains the controls, then names the tool.
##
## The first tool of the crash course is "all the rules are my rules", and the
## one place in a game where that is literally true is the controls screen.
##
## The line appears BENEATH the controls while they are still on screen, rather
## than alone after them. Alone, it reads as a chapter title for whatever comes
## next; underneath, it reads as a remark about the three lines just above it,
## which is what it actually is.

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
	tween.tween_property($Prompt, "modulate:a", 0.0, 0.4)
	tween.tween_property($Tool, "modulate:a", 1.0, 0.9)
	tween.tween_interval(2.6)
	# Everything leaves together, so nothing is left standing alone long enough
	# to look like a heading.
	tween.tween_property($Tool, "modulate:a", 0.0, 0.9)
	tween.parallel().tween_property($Title, "modulate:a", 0.0, 0.9)
	tween.parallel().tween_property($Controls, "modulate:a", 0.0, 0.9)
	tween.tween_callback(_enter_level)


func _enter_level() -> void:
	get_tree().change_scene_to_file(LEVEL)
