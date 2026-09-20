extends Node2D
class_name Nest
## Where the fledgling belongs. Sits far above anything the body can reach, so
## the only way it gets home is carried.

signal delivered()

## How close the carried chick has to come before it settles in.
@export var catch_radius := 30.0
@export var settle_offset := Vector2(0.0, -8.0)

var is_filled := false


func _physics_process(_delta: float) -> void:
	if is_filled:
		return
	for node in get_tree().get_nodes_in_group("awareness"):
		var wisp := node as Awareness
		if wisp == null or wisp.carrying == null:
			continue
		if global_position.distance_to(wisp.carrying.global_position) > catch_radius:
			continue
		var chick: Node2D = wisp.carrying
		wisp.carrying = null
		if chick.has_method("release"):
			chick.release(global_position + settle_offset)
		is_filled = true
		delivered.emit()
		return
