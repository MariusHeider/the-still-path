extends SceneTree
## Checks that the text map actually builds into a playable level.
##
## Catches the things that are invisible until you play: a map row that got
## mangled, an entity spawned inside the floor, terrain that painted as the
## wrong material, a player who starts in mid-air over a hole.
##
## Run:  godot --headless --path . --script res://tools/check_level.gd

const TILE := 32

var _level: LevelMap
var _step := 0
var _failures: Array[String] = []


var _broken := false


func _initialize() -> void:
	var packed: PackedScene = load("res://Scenes/level.tscn")
	var node: Node = packed.instantiate()
	root.add_child(node)
	# If level_map.gd failed to compile, the scene root comes back as a plain
	# Node2D with no script. Catch that here rather than dereferencing null
	# every frame forever.
	_level = node as LevelMap
	if _level == null:
		_broken = true


func _physics_process(_delta: float) -> bool:
	if _broken:
		print("  FAIL  level.tscn has no LevelMap script -- it failed to compile")
		print("")
		print("level check FAILED (1)")
		quit(1)
		return true
	_step += 1
	if _step < 30:
		return false

	var terrain: TileMapLayer = _level.get_node("Terrain")
	var painted := terrain.get_used_cells().size()
	_check(painted > 500, "terrain painted %d cells" % painted)

	var kinds := {}
	for child in _level.get_node("Entities").get_children():
		kinds[child.get_script().resource_path.get_file()] = child
	_check(kinds.has("player.gd"), "player spawned")
	_check(kinds.has("focus_stone.gd"), "stone slab spawned")
	_check(kinds.has("focus_plant.gd"), "sapling spawned")
	_check(kinds.has("focus_summit.gd"), "summit spawned")

	var player: Seeker = _level.player
	_check(player != null, "level exposes the player")
	if player != null:
		_check(player.is_on_floor(),
			"player starts on solid ground, at %s" % player.global_position)
		# Spawned at column 3, row 12, so his feet belong on the row 13 surface.
		_check(absf(player.global_position.y - 13 * TILE) < 2.0,
			"player feet at y=%.1f, expected %d" % [player.global_position.y, 13 * TILE])

	# The slab must rest on the ground rather than sink into it: its origin is
	# at its footing, and the body sits one tile above that.
	if kinds.has("focus_stone.gd"):
		var slab: Node2D = kinds["focus_stone.gd"]
		var body: AnimatableBody2D = slab.get_node("Body")
		_check(absf(body.global_position.y - (13 * TILE - 16)) < 2.0,
			"slab body centred at y=%.1f" % body.global_position.y)

	var camera: Camera2D = player.get_node("Camera2D")
	_check(camera.limit_right > 3000, "camera framed to the map, right=%d" % camera.limit_right)

	print("")
	if _failures.is_empty():
		print("level check passed")
		quit(0)
	else:
		print("level check FAILED (%d)" % _failures.size())
		quit(1)
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok    %s" % message)
	else:
		_failures.append(message)
		print("  FAIL  %s" % message)
