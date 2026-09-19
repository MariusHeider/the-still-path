extends Focusable
class_name FocusPlant
## A seed that grows into a climbable-height vine when attended to.
##
## The vine is one static image, drawn at full height. Growth is done by
## revealing it from the bottom up with the sprite region while moving the
## sprite down to match, so the plant appears to rise out of the ground. That
## costs a single sprite rather than an eight-frame growth animation, which
## matters when art is the scarce resource.
##
## Expects children: Vine (Sprite2D), Seed (Sprite2D), Platform (StaticBody2D
## with a CollisionShape2D).

## Final height in pixels. Must match the vine texture height.
@export var grow_height := 96.0
@export var grow_time := 1.4

@onready var _vine: Sprite2D = $Vine
@onready var _seed: Sprite2D = $Seed
@onready var _platform: StaticBody2D = $Platform
@onready var _platform_shape: CollisionShape2D = $Platform/CollisionShape2D

var _texture_size := Vector2.ZERO


func _ready() -> void:
	super()
	_texture_size = _vine.texture.get_size()
	_vine.centered = false
	_vine.region_enabled = true
	_set_growth(0.0)
	# The platform only exists once there is something to stand on.
	_platform_shape.disabled = true
	_platform.position.y = 0.0


func focus_point() -> Vector2:
	return global_position


func _on_complete() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_seed, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_method(_set_growth, 0.0, 1.0, grow_time)
	tween.tween_callback(_raise_platform)


func _set_growth(ratio: float) -> void:
	var height := grow_height * ratio
	# Show the bottom `height` pixels of the texture...
	_vine.region_rect = Rect2(0.0, _texture_size.y - height, _texture_size.x, height)
	# ...and place them so the base stays planted on the ground.
	_vine.position = Vector2(-_texture_size.x * 0.5, -height)


func _raise_platform() -> void:
	_platform.position.y = -grow_height + 4.0
	# Deferred because enabling a collider inside a physics callback is not
	# allowed, and the tween finishes during one.
	_platform_shape.set_deferred("disabled", false)
