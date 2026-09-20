extends Node2D
class_name Fledgling
## A chick that has come out of its nest. Picked up and carried by hand.
##
## It was briefly carried by the attention instead, which was worse: it made
## the moment abstract, and it needed the awareness mechanic to be available
## here rather than only at the canyon. Picking it up and climbing with it is
## plainer and asks more of the player, which suits what the moment is about.

## Where it sits while being carried, relative to the seeker. Mirrored with him.
@export var carry_offset := Vector2(5.0, -30.0)

var carrier: Seeker = null

var _home := Vector2.ZERO


func _ready() -> void:
	add_to_group("interactable")
	_home = global_position


func _process(_delta: float) -> void:
	if carrier == null:
		return
	global_position = carrier.global_position + Vector2(
		carry_offset.x * carrier.facing, carry_offset.y)


func interact_prompt() -> String:
	return "E to pick up"


func can_interact(player: Seeker) -> bool:
	return carrier == null and player.carried == null


func interact(player: Seeker) -> void:
	carrier = player
	player.carried = self


## Put down somewhere specific, by the nest or by the seeker standing up.
func release(at: Vector2) -> void:
	if carrier != null:
		carrier.carried = null
	carrier = null
	global_position = at


func return_home() -> void:
	release(_home)
