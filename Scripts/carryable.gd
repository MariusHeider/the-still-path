extends Focusable
class_name Carryable
## Something the awareness can pick up and carry.
##
## The same verb as every other puzzle -- sit, reach, hold still -- except what
## it resolves into is not an effect on the world but a responsibility. You are
## now carrying something, and it goes where you go until you put it somewhere.

var is_carried := false

var _home := Vector2.ZERO


func _ready() -> void:
	super()
	_home = global_position


## Not focusable while already in hand, or the attention would keep re-taking it.
func can_focus() -> bool:
	return not is_carried


func _on_complete() -> void:
	var wisp := _find_awareness()
	if wisp == null:
		return
	wisp.carry(self)
	is_carried = true
	# Picking it up is not the end of anything, so it stays available.
	is_done = false


func release(at: Vector2) -> void:
	is_carried = false
	global_position = at


## Standing up while carrying puts it back where it was, rather than leaving it
## stranded somewhere the player can no longer reach.
func return_home() -> void:
	release(_home)


func _find_awareness() -> Awareness:
	for node in get_tree().get_nodes_in_group("awareness"):
		var wisp := node as Awareness
		if wisp != null and wisp.active:
			return wisp
	return null
