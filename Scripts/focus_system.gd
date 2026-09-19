extends Node2D
class_name FocusSystem
## Decides what the seated seeker is attending to, and counts how long for.
##
## Lives as a child of the Seeker. The rule is deliberately simple: while
## seated, the nearest unfinished Focusable within reach is the target, and
## unbroken attention on it for its focus_time makes it respond. Standing up,
## or being knocked off the ground, cancels it.
##
## The puzzle is therefore never "press the right button" -- it is "work out
## where to sit", since the seeker cannot move while attending to anything.

signal target_changed(target: Focusable)
signal progress_changed(ratio: float)

## How far the seeker's attention reaches, in pixels (three tiles).
@export var focus_radius := 96.0

var target: Focusable = null

var _seeker: Seeker
var _elapsed := 0.0


func _ready() -> void:
	_seeker = get_parent() as Seeker
	if _seeker == null:
		push_error("FocusSystem expects to be a child of a Seeker")
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not _seeker.is_seated or not _seeker.is_still:
		_reset()
		return

	var nearest := _find_nearest()
	if nearest != target:
		_set_target(nearest)
	if target == null:
		return

	_elapsed += delta
	progress_changed.emit(clampf(_elapsed / maxf(target.focus_time, 0.01), 0.0, 1.0))
	if _elapsed >= target.focus_time:
		target.complete()
		_set_target(null)
		_elapsed = 0.0
		progress_changed.emit(0.0)


func _find_nearest() -> Focusable:
	var best: Focusable = null
	var best_distance := focus_radius
	for node in get_tree().get_nodes_in_group("focusable"):
		var candidate := node as Focusable
		if candidate == null or not candidate.can_focus():
			continue
		var distance := _seeker.global_position.distance_to(candidate.focus_point())
		if distance <= best_distance:
			best_distance = distance
			best = candidate
	return best


func _set_target(next: Focusable) -> void:
	if is_instance_valid(target):
		target.set_highlight(false)
	target = next
	_elapsed = 0.0
	if is_instance_valid(target):
		target.set_highlight(true)
	target_changed.emit(target)
	progress_changed.emit(0.0)


func _reset() -> void:
	if target == null and is_zero_approx(_elapsed):
		return
	_set_target(null)
	_elapsed = 0.0
