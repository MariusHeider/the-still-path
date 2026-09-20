extends AnimatableBody2D
class_name Elephant
## Wades the seeker across the river, once the bird has gone to fetch it.
##
## An AnimatableBody2D rather than a scripted sprite, so the physics engine
## treats it as moved and the seeker rides properly rather than sliding off.
##
## It is not standing there from the start. The bird says it will bring someone,
## and then someone arrives -- which only means anything if the place was empty
## before.

signal arrived()

## How far right of its waiting place it starts, out in the river. It wades in
## from there when called.
@export var entrance_offset := Vector2(190.0, 0.0)
@export var entrance_time := 4.0
## How far it carries him. Lands him on the first step of the mountain.
@export var crossing_distance := 276.0
@export var crossing_time := 7.0
## Where the seeker sits on its back.
@export var rider_offset := Vector2(-6.0, -58.0)

enum State { HIDDEN, ARRIVING, WAITING, CROSSING, LANDED }

var state: State = State.HIDDEN

var _home := Vector2.ZERO

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("interactable")
	_home = position
	position += entrance_offset
	visible = false
	_shape.set_deferred("disabled", true)


## Called once the fledgling is home and the bird has gone for help.
func call_over() -> void:
	if state != State.HIDDEN:
		return
	state = State.ARRIVING
	visible = true
	_sprite.flip_h = true          # the sheet faces right; it is walking left
	_sprite.play("walk")
	var tween := create_tween()
	tween.tween_property(self, "position", _home, entrance_time)
	tween.tween_callback(_on_arrived)


func _on_arrived() -> void:
	state = State.WAITING
	_sprite.flip_h = false
	_sprite.play("idle")
	_shape.set_deferred("disabled", false)
	arrived.emit()


func rider_position() -> Vector2:
	return global_position + rider_offset


func interact_prompt() -> String:
	if state == State.LANDED:
		return "E to climb down"
	return "E to climb up"


func can_interact(player: Seeker) -> bool:
	if player.riding == self:
		# Only let him off once it has actually put him down somewhere.
		return state == State.LANDED
	return state == State.WAITING and player.carried == null


func interact(player: Seeker) -> void:
	if player.riding == self:
		player.dismount(global_position + Vector2(24.0, -24.0))
		return
	player.mount(self)
	_cross()


func _cross() -> void:
	state = State.CROSSING
	_sprite.play("walk")
	var tween := create_tween()
	tween.tween_property(self, "position:x", position.x + crossing_distance,
		crossing_time)
	tween.tween_callback(_on_landed)


func _on_landed() -> void:
	state = State.LANDED
	_sprite.play("idle")
