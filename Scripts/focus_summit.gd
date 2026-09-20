extends Focusable
class_name FocusSummit
## The last thing the seeker sits beside, where nothing happens.
##
## Every other Focusable rewards stillness with an effect: a slab moves, a
## sapling flowers. This one does not. The player has been taught to sit in
## order to get something, and here is asked to sit for nothing at all -- which
## is the whole point, and the third tool of the crash course.

@export_file("*.tscn") var next_scene := "res://Scenes/ending.tscn"
## Seconds between the stillness completing and the scene changing. Long enough
## that the player notices nothing happened.
@export var linger := 2.5


func _on_complete() -> void:
	var tween := create_tween()
	tween.tween_interval(linger)
	tween.tween_callback(_leave)


func _leave() -> void:
	get_tree().change_scene_to_file(next_scene)
