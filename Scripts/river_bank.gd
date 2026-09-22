extends Node2D
## An explicit local call point. It never extends other objects' interaction reach.
var bank := 0
var elephant: Elephant
var call_bounds := Rect2(Vector2(-80, -96), Vector2(160, 112))

func _ready() -> void:
	add_to_group("interactable")

func contains(player: Seeker) -> bool:
	return call_bounds.has_point(to_local(player.global_position))

func can_interact(player: Seeker) -> bool:
	return player.riding == null and player.is_on_floor() and contains(player) \
		and elephant != null and elephant.is_waiting() and elephant.bank != bank

func interaction_distance(_player: Seeker) -> float:
	return 0.0

func interact_prompt() -> String:
	return "E to call elephant"

func interact(player: Seeker) -> void:
	if can_interact(player):
		elephant.travel_to(bank)
