extends Area2D
class_name ProjectionZone
## The stretch of ground where the seeker can send his attention out of his body.
##
## Not everywhere, deliberately. If attention could leave the body anywhere, it
## would also be a way over the cliff without the sapling and past every other
## puzzle in the game -- the ability would delete the rest of the level. It
## belongs to the canyon, which is the one place the body genuinely cannot go.

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body is Seeker:
		if not body.projection_zones.has(self):
			body.projection_zones.append(self)
		body.can_project = not body.projection_zones.is_empty()


func _on_body_exited(body: Node2D) -> void:
	if body is Seeker:
		body.projection_zones.erase(self)
		body.can_project = not body.projection_zones.is_empty()
