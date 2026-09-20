extends Node2D
class_name LevelMap
## Builds a level from a plain text map, so the layout lives in a file you can
## edit by typing rather than in binary tile data.
##
## One character is one 32px tile. Terrain characters are painted through the
## autotiler, so edges resolve themselves. Entity characters spawn a scene
## standing on top of the tile below them.
##
##   .  empty            #  earth          R  rock         S  snow
##   P  player start     ~  stone slab     v  sapling      T  summit
##   c  fledgling        n  nest           e  elephant
##
## A line starting with ; is a comment, and blank lines are ignored, so the map
## file can document itself. The comment marker is NOT # -- that is the earth
## tile, and every solid ground row begins with one.

const TILE := 32
const TERRAIN_SET := 0
## Maps a map character to the terrain index built by tools/build_tileset.gd.
const TERRAIN_BY_CHAR := {"#": 0, "R": 1, "S": 2}

const ENTITY_SCENES := {
	"P": preload("res://Scenes/player.tscn"),
	"~": preload("res://Scenes/focus_stone.tscn"),
	"v": preload("res://Scenes/focus_plant.tscn"),
	"T": preload("res://Scenes/focus_summit.tscn"),
	"c": preload("res://Scenes/fledgling.tscn"),
	"n": preload("res://Scenes/nest.tscn"),
	"e": preload("res://Scenes/elephant.tscn"),
}

## What the bird says once its chick is home. Kept short: the rest of the game
## teaches without words, and a talkative bird would undercut that.
## A plain Array, not PackedStringArray: only literal collections count as
## constant expressions, and a PackedStringArray(...) call does not.
const BIRD_LINES := [
	"You carried what you did not have to carry.",
	"Wait. I will bring someone who can help you.",
	"I am a mother to the world.",
]

const METER_WIDTH := 16

@export_file("*.txt") var map_path := "res://Levels/level1.txt"

var player: Seeker
var focus: FocusSystem

var _nest: Nest
var _elephant: Elephant
var _awareness: Awareness

@onready var _terrain: TileMapLayer = $Terrain
@onready var _entities: Node2D = $Entities
@onready var _readout: Label = $HUD/Readout
@onready var _message: Label = $HUD/Message

var _width := 0
var _height := 0


func _ready() -> void:
	var rows := _read_map()
	if rows.is_empty():
		push_error("level map %s is empty or missing" % map_path)
		return
	_paint_terrain(rows)
	_spawn_entities(rows)
	_frame_camera()
	_message.modulate.a = 0.0
	_refresh()


func _read_map() -> PackedStringArray:
	if not FileAccess.file_exists(map_path):
		return PackedStringArray()
	var text := FileAccess.get_file_as_string(map_path)
	var rows := PackedStringArray()
	for line in text.split("\n", false):
		var stripped := line.replace("\r", "")
		if stripped.begins_with(";") or stripped.strip_edges().is_empty():
			continue
		rows.append(stripped)
	for row in rows:
		_width = maxi(_width, row.length())
	_height = rows.size()
	return rows


func _paint_terrain(rows: PackedStringArray) -> void:
	# Collect every cell per terrain first, then paint each terrain in one call.
	# set_cells_terrain_connect resolves edges against what is already placed,
	# so painting cell by cell would give each tile the wrong neighbours.
	var cells_by_terrain := {}
	for y in rows.size():
		var row := rows[y]
		for x in row.length():
			var symbol := row[x]
			if not TERRAIN_BY_CHAR.has(symbol):
				continue
			var terrain: int = TERRAIN_BY_CHAR[symbol]
			if not cells_by_terrain.has(terrain):
				cells_by_terrain[terrain] = [] as Array[Vector2i]
			cells_by_terrain[terrain].append(Vector2i(x, y))
	for terrain in cells_by_terrain:
		_terrain.set_cells_terrain_connect(cells_by_terrain[terrain], TERRAIN_SET, terrain)


func _spawn_entities(rows: PackedStringArray) -> void:
	for y in rows.size():
		var row := rows[y]
		for x in row.length():
			var symbol := row[x]
			if not ENTITY_SCENES.has(symbol):
				continue
			var node: Node2D = ENTITY_SCENES[symbol].instantiate()
			# An entity marker sits in the empty tile above its footing, so its
			# feet land on the boundary between the two.
			node.position = Vector2(x * TILE + TILE * 0.5, (y + 1) * TILE)
			_entities.add_child(node)

			if node is Seeker:
				player = node
				focus = node.get_node("FocusSystem")
				_awareness = node.get_node_or_null("Awareness")
			elif node is Nest:
				_nest = node
			elif node is Elephant:
				_elephant = node
			elif node is Focusable:
				node.completed.connect(_on_focusable_completed.bind(node))

	if player == null:
		push_error("level map has no P for the player start")
		return
	if _nest != null:
		_nest.delivered.connect(_on_chick_delivered)
	player.seated_changed.connect(func(_seated: bool) -> void: _refresh())
	player.stillness_changed.connect(_on_stillness_changed)
	focus.target_changed.connect(func(_t: Focusable) -> void: _refresh())
	focus.progress_changed.connect(_on_progress_changed)


func _frame_camera() -> void:
	var camera: Camera2D = player.get_node_or_null("Camera2D")
	if camera == null:
		return
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = _width * TILE
	camera.limit_bottom = _height * TILE


# --- Tool messages ----------------------------------------------------------

func _on_focusable_completed(source: Focusable) -> void:
	if source.message.is_empty():
		return
	# Late enough that the player has watched the thing happen first. The line
	# names what they just did; it does not instruct them beforehand.
	_show_lines([source.message], 1.2)


func _on_chick_delivered() -> void:
	_show_lines(BIRD_LINES, 0.8)
	if _elephant != null:
		# It arrives while the bird is still speaking, so the player looks up
		# from the message and finds it already there.
		get_tree().create_timer(5.0).timeout.connect(_elephant.make_ready)


func _show_lines(lines: Array, lead_in: float) -> void:
	var tween := create_tween()
	tween.tween_interval(lead_in)
	for line in lines:
		tween.tween_callback(func() -> void: _message.text = line)
		tween.tween_property(_message, "modulate:a", 1.0, 0.8)
		tween.tween_interval(2.4)
		tween.tween_property(_message, "modulate:a", 0.0, 0.7)


# --- Readout ----------------------------------------------------------------

func _on_stillness_changed(seconds: float) -> void:
	if not player.is_seated:
		return
	if player.is_still:
		if focus.target == null:
			_readout.text = _idle_hint()
		return
	_readout.text = "settling  %s" % _meter(seconds / maxf(player.stillness_threshold, 0.01))


func _on_progress_changed(ratio: float) -> void:
	if focus.target == null:
		_refresh()
		return
	_readout.text = "attending  %s" % _meter(ratio)


## What to say while he is settled but nothing is responding. Once the attention
## has been sent somewhere the body could stand, this is the only prompt the
## player needs to discover the whole mechanic.
func _idle_hint() -> String:
	if _awareness != null and _awareness.is_projected():
		if _awareness.find_landing() != null:
			return "E to go there"
		return "nothing to stand on"
	return "WASD moves your attention"


func _meter(ratio: float) -> String:
	var filled := int(clampf(ratio, 0.0, 1.0) * METER_WIDTH)
	return "[%s%s]" % ["=".repeat(filled), " ".repeat(METER_WIDTH - filled)]


func _refresh() -> void:
	if player == null:
		return
	if not player.is_seated:
		_readout.text = "E to sit"
	elif not player.is_still:
		_readout.text = "settling  %s" % _meter(0.0)
	elif focus.target == null:
		_readout.text = _idle_hint()
	else:
		_on_progress_changed(0.0)
