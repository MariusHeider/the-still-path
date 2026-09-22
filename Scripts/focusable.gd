extends Node2D
class_name Focusable
## Base class for anything the seeker can act on by sitting near it.
##
## The seeker never pushes or grabs. He sits, and holds still, and what he is
## attending to responds. So a Focusable has no interaction of its own: it only
## knows how long it needs to be attended to, and what to do when that is met.
## The focus system (focus_system.gd) does the choosing and the counting.
##
## Subclass and override _on_complete(). Put the node in the "focusable" group
## or the focus system will not see it.

signal completed()

## Seconds of unbroken attention this object needs before it responds, counted
## only after the seeker has finished settling. Long on purpose: the point of
## the mechanic is that stillness is held, not tapped. Tune per object in the
## Inspector if one puzzle wants to be quicker than another.
@export var focus_time := 3.0
## Most puzzle objects should only resolve once.
@export var one_shot := true
## Shown by the level after this resolves, once the player has watched it
## happen. Empty means nothing is shown.
@export_multiline var message := ""
## Wait for this object's response animation before showing its message.
@export var message_delay := 1.2
## Tint applied while this is the object being attended to.
@export var highlight_tint := Color(1.35, 1.28, 0.95)

var is_done := false


func _ready() -> void:
	add_to_group("focusable")


func can_focus() -> bool:
	return not (one_shot and is_done)


## Where the seeker has to be near. Override if the visual centre is not the
## node origin -- a tall plant, for instance, is reached at its base.
func focus_point() -> Vector2:
	return global_position


func complete() -> void:
	if not can_focus():
		return
	is_done = true
	set_highlight(false)
	_on_complete()
	completed.emit()


## What this object actually does. Override in subclasses.
func _on_complete() -> void:
	pass


func set_highlight(on: bool) -> void:
	modulate = highlight_tint if on else Color.WHITE
