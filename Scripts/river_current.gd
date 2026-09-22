extends Node2D
## Stronger pixel current overlays; existing water tiles and physics stay untouched.
@export var current_speed := 24.0
var phase := 0.0
var cells: Array[Vector2i] = []
var _bounds := Rect2()
func _ready() -> void:
	_read_cells.call_deferred()
func _read_cells() -> void:
	cells.assign(get_parent().get_used_cells())
	var rect: Rect2i = get_parent().get_used_rect()
	_bounds = Rect2(Vector2(rect.position * 32), Vector2(rect.size * 32))
func _process(delta: float) -> void:
	phase = fmod(phase + delta * current_speed, 64.0)
	queue_redraw()
func _draw() -> void:
	if cells.is_empty(): return
	# Long streaks traverse tile boundaries instead of repeating in every 32px cell.
	for row in range(int(_bounds.size.y / 16)):
		var y := _bounds.position.y + 5 + row * 16
		var offset := fmod(phase + row * 19, 64.0)
		for i in range(-1, int(_bounds.size.x / 64) + 1):
			var x := _bounds.position.x + i * 64 + offset
			var length := 22.0 if row % 2 == 0 else 15.0
			var streak := Rect2(x, y, length, 2).intersection(_bounds)
			if streak.has_area():
				draw_rect(streak, Color(0.68, 0.83, 0.78, 0.42 if row % 2 == 0 else 0.28))
