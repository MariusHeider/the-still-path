extends Node2D
class_name Nest
## Where the fledgling belongs. High enough that getting here with a chick in
## your hands is the whole of the puzzle.

signal delivered()

@export var settle_offset := Vector2(0.0, -8.0)

var is_filled := false


func _ready() -> void:
	add_to_group("interactable")


func interact_prompt() -> String:
	return "E to put it back"


func can_interact(player: Seeker) -> bool:
	return not is_filled and player.carried is Fledgling and not player.carried.delivered


func interact(player: Seeker) -> void:
	if not can_interact(player):
		return
	var chick: Fledgling = player.carried
	if chick.carrier != player or not chick.deliver_to(global_position + settle_offset):
		return
	is_filled = true
	remove_from_group("interactable")
	delivered.emit()
