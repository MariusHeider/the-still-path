extends AnimatableBody2D
class_name Elephant
## Carries the seeker across the last gap, once the bird has fetched it.
##
## An AnimatableBody2D rather than a scripted position, so the physics engine
## treats it as moved and the seeker rides properly on its back instead of
## sliding off or being left behind.

## How far it walks, in pixels. Enough to clear the gap and set him down.
@export var carry_distance := 340.0
@export var carry_time := 5.0
## How near the seeker has to be, horizontally, to count as aboard.
@export var board_radius := 52.0
## He must be at least this far above it, so walking past does not trigger it.
@export var board_height := 30.0

var is_ready := false

var _walking := false


## Called once the fledgling is home and the bird has gone to fetch help.
func make_ready() -> void:
	is_ready = true


func _physics_process(_delta: float) -> void:
	if not is_ready or _walking:
		return
	var seeker: Node2D = get_tree().get_first_node_in_group("seeker")
	if seeker == null:
		return
	if absf(seeker.global_position.x - global_position.x) > board_radius:
		return
	if seeker.global_position.y > global_position.y - board_height:
		return
	_walk()


func _walk() -> void:
	_walking = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position:x", position.x + carry_distance, carry_time)
