extends Node2D
## Throwaway room for tuning how the seeker moves. Geometry is built in code so
## there is nothing to maintain here -- once the tileset lands, the real level
## uses a TileMapLayer and this scene gets deleted.

## Each entry is (x, y, width, height) with y being the TOP of the block.
const BLOCKS: Array[Rect2] = [
	Rect2(-320, 320, 1600, 80),  # ground
	Rect2(200, 272, 96, 16),     # low ledge
	Rect2(368, 216, 96, 16),     # needs the low ledge first
	Rect2(544, 272, 128, 16),
	Rect2(736, 160, 32, 160),    # pillar to test wall collisions
	Rect2(832, 200, 160, 16),
	Rect2(1040, 272, 120, 16),
]
const BLOCK_COLOR := Color("3a3630")
const METER_WIDTH := 14

@onready var _player: Seeker = $Player
@onready var _readout: Label = $HUD/Readout


func _ready() -> void:
	for block in BLOCKS:
		_add_block(block)
	_player.stillness_changed.connect(_on_stillness_changed)
	_player.became_still.connect(_on_became_still)
	_on_stillness_changed(0.0)


func _add_block(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position

	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = rect.size * 0.5
	body.add_child(collider)

	var visual := ColorRect.new()
	visual.size = rect.size
	visual.color = BLOCK_COLOR
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(visual)

	$Geometry.add_child(body)


func _on_stillness_changed(seconds: float) -> void:
	var fraction := clampf(seconds / maxf(_player.stillness_threshold, 0.001), 0.0, 1.0)
	var filled := int(fraction * METER_WIDTH)
	_readout.text = "be still  [%s%s]" % [
		"=".repeat(filled), " ".repeat(METER_WIDTH - filled)
	]


func _on_became_still() -> void:
	_readout.text = "be still  [ the path answers ]"
