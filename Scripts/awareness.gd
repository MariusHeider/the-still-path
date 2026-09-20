extends Node2D
class_name Awareness
## The seeker's attention, as a thing in the world.
##
## While he is seated and settled, this appears at his chest and can be steered
## away from him. Everything the game calls "focus" is measured from here, not
## from the body -- so sitting still and reaching out are the same act.
##
## Its two uses are the same mechanic seen twice. First you send it across a
## canyon and bring your own body to it, which is hard to read as anything
## other than "the body is not what I am". Then you send it to a fallen chick
## and carry that instead, which is the same power spent on something that is
## not you at all.

## Pixels per second while being steered.
@export var move_speed := 190.0
## How far it can get from the body. Ten tiles: enough to cross the canyon,
## not enough to make sitting position irrelevant.
@export var max_range := 360.0
## How far down it looks for ground when deciding if the body could stand there.
@export var probe_length := 160.0
## Distance from the body past which it counts as projected rather than resting.
@export var projected_at := 20.0

var active := false
var anchor := Vector2.ZERO
var carrying: Node2D = null

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group("awareness")
	top_level = true
	visible = false


func activate(origin: Vector2) -> void:
	if active:
		return
	active = true
	anchor = origin
	global_position = origin
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.4, 0.4)
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, 0.35)
	tween.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)


func deactivate() -> void:
	active = false
	visible = false
	if carrying != null and carrying.has_method("return_home"):
		carrying.return_home()
	carrying = null


func steer(direction: Vector2, delta: float, from: Vector2) -> void:
	anchor = from
	if direction != Vector2.ZERO:
		global_position += direction.normalized() * move_speed * delta
	var offset := global_position - anchor
	if offset.length() > max_range:
		global_position = anchor + offset.normalized() * max_range
	# Brighten when the body could actually arrive here, so the player can read
	# a valid landing without a separate marker cluttering the screen.
	_sprite.modulate = Color(1.3, 1.3, 1.3) if find_landing() != null else Color.WHITE
	if carrying != null:
		carrying.global_position = global_position + Vector2(0, 6)


func is_projected() -> bool:
	return active and global_position.distance_to(anchor) > projected_at


## Where the body would land if it came here, or null if it could not.
func find_landing():
	if not active:
		return null
	var space := get_world_2d().direct_space_state

	# Inside solid rock is not somewhere a body can appear.
	var point := PhysicsPointQueryParameters2D.new()
	point.position = global_position
	point.collision_mask = 1
	if not space.intersect_point(point, 1).is_empty():
		return null

	var ray := PhysicsRayQueryParameters2D.create(
		global_position, global_position + Vector2(0.0, probe_length))
	ray.collision_mask = 1
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return null
	return hit["position"]


# --- Carrying ---------------------------------------------------------------

func carry(node: Node2D) -> void:
	carrying = node


