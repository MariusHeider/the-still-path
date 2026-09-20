extends Control
## Closing screen.
##
## Deliberately offers no "play again". The whole argument of the game is that
## it is possible to make something that lets go of you, so the last screen
## thanks the player and closes. Anything else would contradict the thing the
## game just spent ten minutes saying.

func _ready() -> void:
	$Lines.modulate.a = 0.0
	$Quit.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property($Lines, "modulate:a", 1.0, 1.6)
	tween.tween_interval(1.4)
	tween.tween_property($Quit, "modulate:a", 1.0, 0.8)
	tween.tween_callback(func() -> void: $Quit.disabled = false)
	$Quit.pressed.connect(_on_quit_pressed)
	$Quit.disabled = true


func _on_quit_pressed() -> void:
	get_tree().quit()
