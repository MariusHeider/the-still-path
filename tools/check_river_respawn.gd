extends SceneTree
var _finishing := false
## Run: godot --headless --path . --script res://tools/check_river_respawn.gd
## Poison the dynamic checkpoint, enter the real Area2D, then wait for loops.

const ENTRIES := [
	[Vector2(6024, 512), Vector2(0, 300)],
	[Vector2(6094, 432), Vector2(150, 542)],
	[Vector2(6224, 432), Vector2(-150, 200)],
]

var _level: LevelMap
var _player: Seeker
var _hazard: Area2D
var _step := 0
var _entries := 0
var _failures := 0
var _safe: Vector2


func _initialize() -> void:
	var node: Node = load("res://Scenes/level.tscn").instantiate()
	root.add_child(node)
	_level = node as LevelMap


func _physics_process(_delta: float) -> bool:
	if _finishing: return false
	if _level == null:
		_finish(1)
		return false
	_step += 1
	if _step == 10:
		_player = _level.player
		_hazard = _level.get_node("Hazard")
		_safe = _level.to_global(_level.river_respawn_position)
		# Connected after the level's handler: inspect the immediate recovery.
		_hazard.body_entered.connect(_on_entered)
		_check(_safe == Vector2(5904, 480), "r resolves to the intended safe bank")

	for i in ENTRIES.size():
		var start := 30 + i * 150
		if _step == start:
			_player.global_position = ENTRIES[i][0]
			_player.velocity = ENTRIES[i][1]
			_player._last_safe = Vector2(6064, 522)
		elif _step == start + 120:
			_check(_entries == i + 1, "entry %d triggered exactly once, with no loop" % (i + 1))
			_check(_player.global_position.distance_to(_safe) < 1.0,
				"player remains at river checkpoint")
			_check(_player.is_on_floor(), "checkpoint is solid ground")
			_check(not _hazard.overlaps_body(_player), "player is clear of river Area2D")

	if _step == 480:
		# An ordinary fall must still use its own dynamic safe point.
		_player._last_safe = Vector2(112, 608)
		_player.global_position = Vector2(112, _player.fall_limit + 100)
		_player.velocity = Vector2(0, 300)
	elif _step == 510:
		_check(_player.global_position.distance_to(Vector2(112, 608)) < 1.0,
			"ordinary fall still uses the dynamic safe position")
		print("river respawn check %s" % ("passed" if _failures == 0 else "FAILED"))
		_finish(0 if _failures == 0 else 1)
		return false
	return false


func _on_entered(body: Node2D) -> void:
	if body != _player:
		return
	_entries += 1
	_check(_player.global_position.is_equal_approx(_safe),
		"river ignores poisoned last-safe position")
	_check(_player.velocity == Vector2.ZERO, "river recovery clears velocity")


func _check(condition: bool, message: String) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition:
		_failures += 1

func _finish(code := 0) -> void:
	if _finishing: return
	_finishing = true
	preload("res://tools/test_cleanup.gd").finish(self, code)
