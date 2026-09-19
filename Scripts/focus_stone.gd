extends Focusable
class_name FocusStone
## A stone slab that slides into place when attended to.
##
## The slab is an AnimatableBody2D so that it carries the seeker properly if he
## happens to be standing on it, and so the physics engine treats it as moved
## rather than teleported.

## Where the slab ends up, relative to where it starts.
@export var move_by := Vector2(160.0, 0.0)
## Seconds the slab takes to travel. Slow enough to watch, short enough that it
## does not stall the puzzle.
@export var travel_time := 1.1

@onready var _body: AnimatableBody2D = $Body


func focus_point() -> Vector2:
	return _body.global_position


func _on_complete() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_body, "position", _body.position + move_by, travel_time)
