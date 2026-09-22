extends Focusable
class_name FocusPlant
## A sapling that grows into a vine with a flower you can stand on.
##
## The vine is one static image, drawn at full height. Growth is done by
## revealing it from the bottom up with the sprite region while moving the
## sprite down to match, so the plant appears to rise out of the ground. That
## costs a single sprite rather than an eight-frame growth animation, which
## matters when art is the scarce resource.
##
## The flower at the top is the landing platform. It is deliberately wider than
## the vine and the only saturated thing on screen, because a platform the
## player cannot see is a platform they will fall past.
##
## Expects children: Vine (Sprite2D), Sapling (Sprite2D), Flower (Sprite2D),
## Platform (StaticBody2D with a CollisionShape2D).

## Final height of the vine in pixels. Must match the vine texture height.
@export var grow_height := 96.0
@export var grow_time := 1.4
## Where the standing surface ends up, relative to the base of the plant.
## Sits just under the top of the flower petals.
@export var platform_height := -110.0

@onready var _vine: Sprite2D = $Vine
@onready var _sapling: Sprite2D = $Sapling
@onready var _flower: Sprite2D = $Flower
@onready var _platform: StaticBody2D = $Platform
@onready var _platform_shape: CollisionShape2D = $Platform/CollisionShape2D

var _texture_size := Vector2.ZERO
@export var growth_volume_db := -30.0
@onready var growth_audio := Sound.local(self, Sound.GROWTH, growth_volume_db, "GrowthSound")


func _ready() -> void:
	super()
	_texture_size = _vine.texture.get_size()
	_vine.centered = false
	_vine.region_enabled = true
	_set_growth(0.0)

	# The flower opens only once the vine has finished rising.
	_flower.position = Vector2(0.0, -grow_height - 8.0)
	_flower.scale = Vector2.ZERO
	_flower.modulate.a = 0.0

	# The platform only exists once there is something to stand on.
	_platform.position.y = 0.0
	_platform_shape.disabled = true


func focus_point() -> Vector2:
	return global_position


func _on_complete() -> void:
	growth_audio.play()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sapling, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_method(_set_growth, 0.0, 1.0, grow_time)
	# A little overshoot on the flower, so it opens rather than appears.
	tween.tween_property(_flower, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(_flower, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_raise_platform)


func _set_growth(ratio: float) -> void:
	var height := grow_height * ratio
	# Show the bottom `height` pixels of the texture...
	_vine.region_rect = Rect2(0.0, _texture_size.y - height, _texture_size.x, height)
	# ...and place them so the base stays planted in the ground.
	_vine.position = Vector2(-_texture_size.x * 0.5, -height)


func _raise_platform() -> void:
	_platform.position.y = platform_height
	# Deferred because enabling a collider inside a physics callback is not
	# allowed, and the tween finishes during one.
	_platform_shape.set_deferred("disabled", false)
