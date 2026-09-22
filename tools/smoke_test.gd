extends SceneTree
var _finishing := false
## Headless smoke test for the sit-and-focus mechanic.
##
## Loads the playground, teleports the seeker next to each puzzle object in
## turn, presses sit, and checks the object actually responded. Catches the
## silent failures -- a focus radius that is too small, a collider that never
## gets enabled, a tween that never runs -- without anyone having to play the
## game to find out.
##
## Run:  godot --headless --path . --script res://tools/smoke_test.gd

const SETTLE := 20

var _scene: Node
var _player: Seeker
var _stone: FocusStone
var _plant: FocusPlant

var _step := 0
var _stone_start := Vector2.ZERO
var _failures: Array[String] = []


func _initialize() -> void:
	_scene = load("res://Scenes/playground.tscn").instantiate()
	root.add_child(_scene)
	_player = _scene.get_node("Player")
	_stone = _scene.get_node("Stone")
	_plant = _scene.get_node("Plant")
	_stone_start = _stone.get_node("Body").global_position


func _physics_process(_delta: float) -> bool:
	if _finishing: return false
	_step += 1

	# --- The slab -----------------------------------------------------------
	if _step == SETTLE:
		_check(_player.is_on_floor(), "seeker should be standing on the ground")
		_player.global_position = Vector2(560, 320)
	elif _step == SETTLE + 4:
		_press("interact")
	elif _step == SETTLE + 6:
		_release("interact")
		_check(_player.is_seated, "pressing interact on level ground should sit")
	elif _step == 120:
		# 1s settling at 60Hz, so attention has only just begun by now.
		_check(_scene.get_node("Player/FocusSystem").target == _stone,
			"the slab should be the focus target when seated beside it")
	elif _step == 520:
		# 1s settle + 5s attention + 1.1s travel, with margin.
		var body: AnimatableBody2D = _stone.get_node("Body")
		var moved: Vector2 = body.global_position - _stone_start
		_check(moved.x > 140.0, "slab should have slid across the gap, moved %s" % moved)
		_check(_stone.is_done, "slab should be marked done")

	# --- The seed -----------------------------------------------------------
	elif _step == 540:
		_press("interact")          # stand back up
	elif _step == 542:
		_release("interact")
		_player.global_position = Vector2(920, 320)
	elif _step == 560:
		_press("interact")
	elif _step == 562:
		_release("interact")
		_check(_player.is_seated, "seeker should be seated beside the sapling")
	elif _step == 1120:
		# 1s settle + 5s attention + 1.85s of growing and flowering, with margin.
		_check(_plant.is_done, "sapling should have grown into a vine")
		var shape: CollisionShape2D = _plant.get_node("Platform/CollisionShape2D")
		_check(not shape.disabled, "vine platform collider should be enabled")
		_check(_plant.get_node("Platform").position.y < -80.0,
			"vine platform should have risen, y = %.1f"
			% _plant.get_node("Platform").position.y)
		_report()
		return false

	return false


func _press(action: String) -> void:
	Input.action_press(action)


func _release(action: String) -> void:
	Input.action_release(action)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok    %s" % message)
	else:
		_failures.append(message)
		print("  FAIL  %s" % message)


func _report() -> void:
	print("")
	if _failures.is_empty():
		print("smoke test passed")
		_finish(0)
	else:
		print("smoke test FAILED (%d)" % _failures.size())
		_finish(1)

func _finish(code := 0) -> void:
	if _finishing: return
	_finishing = true
	preload("res://tools/test_cleanup.gd").finish(self, code)
