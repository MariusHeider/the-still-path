extends Node2D
class_name LevelMap
signal bird_sequence_finished()
## Builds a level from a plain text map, so the layout lives in a file you can
## edit by typing rather than in binary tile data.
##
## One character is one 32px tile. Terrain characters are painted through the
## autotiler, so edges resolve themselves. Entity characters spawn a scene
## standing on top of the tile below them.
##
##   .  empty            #  earth          R  rock         S  snow
##   P  player start     ~  stone slab     v  sapling      T  summit
##   c  fledgling        n  nest           e  elephant     w  river
##   z  projection zone (where attention may leave the body)
##   r / q  explicit left / right safe river checkpoints and local call points
##   f  perception clearing (visual veil over the existing path to its right)
##   m  mountain ambience crossfade (reversible zone, no physical collision)
##   N  large nesting banyan (decoration)    b  one-way branch
##   B  banyan tree     t  slim tree     g  grass tuft   o  loose stones
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
	"f": preload("res://Scenes/focus_reveal.tscn"),
	"T": preload("res://Scenes/focus_summit.tscn"),
	"c": preload("res://Scenes/fledgling.tscn"),
	"n": preload("res://Scenes/nest.tscn"),
	"e": preload("res://Scenes/elephant.tscn"),
	"z": preload("res://Scenes/projection_zone.tscn"),
	"b": preload("res://Scenes/tree_branch.tscn"),
}

## Water is drawn on its own layer above everything, so the river runs in front
## of the elephant's legs while it wades.
const WATER_CHAR := "w"
const WATER_SURFACE := Vector2i(0, 6)
const WATER_BODY_VARIANTS := 3

## Visuals only, placed explicitly in the map and kept behind the play space.
const DECORATION_SCENES := {
	"B": preload("res://Scenes/tree_banyan.tscn"),
	"N": preload("res://Scenes/nesting_tree.tscn"),
	"t": preload("res://Scenes/tree_slim.tscn"),
	"g": preload("res://Scenes/decoration_grass.tscn"),
	"o": preload("res://Scenes/decoration_stones.tscn"),
}

## What the bird says once its chick is home. Kept short: the rest of the game
## teaches without words, and a talkative bird would undercut that.
## A plain Array, not PackedStringArray: only literal collections count as
## constant expressions, and a PackedStringArray(...) call does not.
const BIRD_LINES := [
	"You brought my little one home.",
	"Wait here. I know someone who can help you.",
]
const ADULT_BIRD := preload("res://Scenes/adult_bird.tscn")

var _bird_sequence_active := false
var _chick_rescued := false
var _help_requested := false
var active_river_bank := 0
var river_checkpoints: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _bank_nodes: Array[Node2D] = []

@export_file("*.txt") var map_path := "res://Levels/level1.txt"

var player: Seeker
var focus: FocusSystem
var river_respawn_position := Vector2.ZERO
var mountain_start := Vector2.ZERO
var mist_message_count := 0
var _mist_message_active := false

var _adult_bird
var _nest: Nest
var _elephant: Elephant
var _awareness: Awareness
var _message_tween: Tween

@onready var _terrain: TileMapLayer = $Terrain
@onready var _water: TileMapLayer = $Water
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
	_build_river(rows)
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
			if symbol == "m":
				mountain_start = Vector2(x * TILE, (y + 1) * TILE)
				var zone := Area2D.new()
				zone.name = "MountainAudioZone"
				zone.collision_layer = 0
				zone.collision_mask = 2
				var shape := CollisionShape2D.new()
				var box := RectangleShape2D.new()
				box.size = Vector2((_width - x) * TILE + 512, _height * TILE + 1024)
				shape.shape = box
				zone.position = Vector2(mountain_start.x + box.size.x * 0.5, _height * TILE * 0.5)
				zone.add_child(shape)
				add_child(zone)
				zone.body_entered.connect($Audio.enter_mountain)
				zone.body_exited.connect($Audio.leave_mountain)
				zone.body_entered.connect($Background.enter_mountain)
				zone.body_exited.connect($Background.leave_mountain)
			if not TERRAIN_BY_CHAR.has(symbol):
				continue
			var terrain: int = TERRAIN_BY_CHAR[symbol]
			if not cells_by_terrain.has(terrain):
				cells_by_terrain[terrain] = [] as Array[Vector2i]
			cells_by_terrain[terrain].append(Vector2i(x, y))
	for terrain in cells_by_terrain:
		_terrain.set_cells_terrain_connect(cells_by_terrain[terrain], TERRAIN_SET, terrain)


## The river: drawn on its own layer, and backed by an area that puts the
## seeker back on the bank. It has no collision -- it does not stop him, it
## refuses him.
func _build_river(rows: PackedStringArray) -> void:
	var hazard: Area2D = $Hazard
	var checkpoint_count := [0, 0]
	for y in rows.size():
		var row := rows[y]
		for x in row.length():
			if row[x] in ["r", "q"]:
				var side := 0 if row[x] == "r" else 1
				river_checkpoints[side] = Vector2(x * TILE + TILE * 0.5, (y + 1) * TILE)
				checkpoint_count[side] += 1
			if row[x] != WATER_CHAR:
				continue
			var above := y > 0 and x < rows[y - 1].length() and rows[y - 1][x] == WATER_CHAR
			var tile := WATER_SURFACE
			if above:
				tile = Vector2i(1 + randi() % WATER_BODY_VARIANTS, 6)
			_water.set_cell(Vector2i(x, y), 0, tile)
			var shape := CollisionShape2D.new()
			var box := RectangleShape2D.new()
			box.size = Vector2(TILE, TILE)
			shape.shape = box
			shape.position = Vector2(x * TILE + TILE * 0.5, y * TILE + TILE * 0.5)
			hazard.add_child(shape)
	assert(hazard.get_child_count() == 0 or checkpoint_count == [1, 1],
		"A river map must contain one r and one q on their safe banks")
	river_respawn_position = river_checkpoints[0]
	hazard.body_entered.connect(_on_river_entered)


func _on_river_entered(body: Node2D) -> void:
	if body is Seeker:
		body.respawn_at(to_global(river_checkpoints[active_river_bank]))
		if _chick_rescued and not _help_requested:
			_help_requested = true
			_run_help_sequence()


func _spawn_entities(rows: PackedStringArray) -> void:
	for y in rows.size():
		var row := rows[y]
		for x in row.length():
			var symbol := row[x]
			if DECORATION_SCENES.has(symbol):
				var decoration: Node2D = DECORATION_SCENES[symbol].instantiate()
				decoration.position = Vector2(x * TILE + TILE * 0.5, (y + 1) * TILE)
				$Decorations.add_child(decoration)
				continue
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
				if node.has_signal("passage_blocked"):
						node.passage_blocked.connect(_on_mist_retreat.bind(node))

	if player == null:
		push_error("level map has no P for the player start")
		return
	if _nest != null:
		_nest.delivered.connect(_on_chick_delivered)
		_adult_bird = ADULT_BIRD.instantiate()
		add_child(_adult_bird)
	if _elephant != null:
		_elephant.checkpoints.assign([to_global(river_checkpoints[0]), to_global(river_checkpoints[1])])
		_elephant.crossing_distance = river_checkpoints[1].x - TILE - _elephant._home.x
		_elephant.bank_reached.connect(func(side: int, passenger: Seeker) -> void:
			if passenger == player: active_river_bank = side)
		for side in 2:
			var call_point := Node2D.new()
			call_point.set_script(preload("res://Scripts/river_bank.gd"))
			call_point.name = "LeftBank" if side == 0 else "RightBank"
			call_point.position = river_checkpoints[side]
			call_point.bank = side
			call_point.elephant = _elephant
			# Cover safe ground all the way to the actual water edge on either bank.
			var water_cells := _water.get_used_rect()
			if side == 0:
				call_point.call_bounds.size.x = water_cells.position.x * TILE - call_point.position.x + 80
			else:
				call_point.call_bounds.position.x = water_cells.end.x * TILE - call_point.position.x
				call_point.call_bounds.size.x = 80 - call_point.call_bounds.position.x
			add_child(call_point)
			_bank_nodes.append(call_point)
	if _awareness != null:
		_awareness.activated.connect(_on_awareness_activated)
	player.seated_changed.connect(func(_seated: bool) -> void: _refresh())

	focus.target_changed.connect(func(_t: Focusable) -> void: _refresh())



func _frame_camera() -> void:
	var camera: Camera2D = player.get_node_or_null("Camera2D")
	if camera == null:
		return
	camera.limit_left = 0
	# Headroom for the shrine roof above the summit, without shifting the map.
	camera.limit_top = -224
	camera.limit_right = _width * TILE
	camera.limit_bottom = _height * TILE
	# One screen below the map is far enough that a fall reads as a fall.
	player.fall_limit = _height * TILE + 200.0


# --- Tool messages ----------------------------------------------------------

func _on_mist_retreat(reveal: Focusable) -> void:
	if reveal.is_done or _mist_message_active or _bird_sequence_active:
		return
	_mist_message_active = true
	mist_message_count += 1
	var tween := _show_lines(["I can't see a way through."], 0.0)
	tween.finished.connect(func() -> void: _mist_message_active = false)

func _on_focusable_completed(source: Focusable) -> void:
	if source.message.is_empty():
		return
	# Late enough that the player has watched the thing happen first. The line
	# names what they just did; it does not instruct them beforehand.
	_show_lines([source.message], source.message_delay)


func _on_awareness_activated() -> void:
	_show_lines(["I am not the body, I am not the mind."], 0.0, 0.35)


func _on_chick_delivered() -> void:
	_chick_rescued = true

func _run_help_sequence() -> void:
	_bird_sequence_active = true
	if _message_tween != null:
		_message_tween.kill()
	_message.modulate.a = 0.0
	await _adult_bird.arrive(to_global(river_checkpoints[active_river_bank]) + Vector2(72, -48)).finished
	await _adult_bird.say(BIRD_LINES[0]).finished
	await get_tree().create_timer(0.4).timeout
	await _adult_bird.say(BIRD_LINES[1]).finished
	await get_tree().create_timer(0.5).timeout
	_adult_bird.leave(_nest.global_position + Vector2(28, -10))
	if _elephant != null:
		_elephant.call_over()
	await _show_lines(["I am a mother to the world."], 1.5, 0.8, true).finished
	bird_sequence_finished.emit()
	if _elephant != null and _elephant.state == Elephant.State.ARRIVING:
		await _elephant.arrived
	_bird_sequence_active = false

func _show_lines(lines: Array, lead_in: float, fade_in := 0.8, bird_principle := false) -> Tween:
	# Keep the bird's complete sequence and arrival callback together. Other
	# incidental messages cannot interrupt it and strand the elephant.
	if _bird_sequence_active and not bird_principle:
		return _message_tween
	if _message_tween != null:
		_message_tween.kill()
	_message.modulate.a = 0.0
	_message_tween = create_tween()
	var tween := _message_tween
	tween.tween_interval(lead_in)
	for line in lines:
		tween.tween_callback(func() -> void: _message.text = line)
		tween.tween_property(_message, "modulate:a", 1.0, fade_in)
		tween.tween_interval(2.4)
		tween.tween_property(_message, "modulate:a", 0.0, 0.7)
	return tween


# Only contextual actions remain; stillness has no meter or persistent prompt.
func _process(_delta: float) -> void:
	if player != null and player.riding == null and player.is_on_floor():
		for call_point in _bank_nodes:
			if call_point.contains(player):
				active_river_bank = call_point.bank
	_refresh()


func _refresh() -> void:
	if player == null:
		return
	_readout.text = ""
	if player.riding != null:
		if player.riding.can_interact(player):
			_readout.text = player.riding.interact_prompt()
	elif player.is_seated:
		if _awareness != null and _awareness.active:
			if _awareness.is_projected():
				_readout.text = "E to go there" if _awareness.find_landing() != null else "nothing to stand on"
			else:
				_readout.text = "WASD moves your attention"
	else:
		var thing := player.current_interactable()
		if thing != null:
			_readout.text = thing.interact_prompt()
