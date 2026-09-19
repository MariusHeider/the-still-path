extends Node2D
## Test room for the sit-and-focus mechanic. Terrain is painted from a list of
## rectangles at startup rather than placed by hand, so the layout can be
## rearranged by editing numbers while the real level is still being designed.
##
## Two puzzles, both using the same verb:
##   the slab   -- sit beside it and it slides across the gap
##   the seed   -- sit beside it and it grows into a vine you can stand on

const TERRAIN_SET := 0
const EARTH := 0
const METER_WIDTH := 16

## Solid ground in TILE coordinates: Rect2i(x, y, width, height).
## Ground surface is row 10, which is y = 320 in world pixels.
const SOLID: Array[Rect2i] = [
	Rect2i(-10, 10, 32, 5),   # left ground, ends at the gap
	Rect2i(27, 10, 19, 5),    # right ground, resumes after the gap
	Rect2i(6, 8, 4, 1),       # low ledge
	Rect2i(11, 6, 3, 1),      # higher ledge, needs the low one first
	Rect2i(32, 6, 5, 1),      # only reachable from the grown vine
]

@onready var _terrain: TileMapLayer = $Terrain
@onready var _player: Seeker = $Player
@onready var _focus: FocusSystem = $Player/FocusSystem
@onready var _readout: Label = $HUD/Readout


func _ready() -> void:
	_paint_terrain()
	_player.seated_changed.connect(_on_seated_changed)
	_focus.target_changed.connect(_on_target_changed)
	_focus.progress_changed.connect(_on_progress_changed)
	_refresh()


func _paint_terrain() -> void:
	var cells: Array[Vector2i] = []
	for rect in SOLID:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				cells.append(Vector2i(x, y))
	# Picks the right edge tile for every cell from the neighbours it ends up
	# with, so the rectangles above never have to think about edges.
	_terrain.set_cells_terrain_connect(cells, TERRAIN_SET, EARTH)


# --- Readout ----------------------------------------------------------------
# Placeholder HUD. It exists so the mechanic can be felt and demonstrated; the
# real game should say this with animation and sound, not a line of text.

func _on_seated_changed(_seated: bool) -> void:
	_refresh()


func _on_target_changed(_target: Focusable) -> void:
	_refresh()


func _on_progress_changed(ratio: float) -> void:
	if _focus.target == null:
		_refresh()
		return
	var filled := int(ratio * METER_WIDTH)
	_readout.text = "attending  [%s%s]" % [
		"=".repeat(filled), " ".repeat(METER_WIDTH - filled)
	]


func _refresh() -> void:
	if not _player.is_seated:
		_readout.text = "E to sit"
	elif _focus.target == null:
		_readout.text = "still. nothing within reach"
	else:
		_on_progress_changed(0.0)
