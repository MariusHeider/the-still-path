extends SceneTree
## Drives the two hardest mechanics headlessly: sending awareness across the
## canyon and bringing the body to it, and carrying the fledgling to its nest.
##
## These are the things that are tedious to test by hand -- each attempt costs a
## settle, three seconds of attention and a slow steer -- so they are exactly
## the things worth automating.
##
## Run:  godot --headless --path . --script res://tools/check_tools.gd

const CANYON_EDGE := Vector2(1800, 288)
const NEAR_CHICK := Vector2(2256, 288)

var _level: LevelMap
var _player: Seeker
var _wisp: Awareness
var _chick: Carryable
var _nest: Nest
var _elephant: Elephant

var _step := 0
var _failures: Array[String] = []
var _crossed_to := 0.0


func _initialize() -> void:
	var packed: PackedScene = load("res://Scenes/level.tscn")
	var node: Node = packed.instantiate()
	root.add_child(node)
	_level = node as LevelMap


func _physics_process(_delta: float) -> bool:
	if _level == null:
		print("  FAIL  level failed to compile")
		quit(1)
		return true
	_step += 1

	if _step == 10:
		_player = _level.player
		_wisp = _player.get_node("Awareness")
		for child in _level.get_node("Entities").get_children():
			if child is Carryable:
				_chick = child
			elif child is Nest:
				_nest = child
			elif child is Elephant:
				_elephant = child
		_check(_chick != null, "fledgling spawned")
		_check(_nest != null, "nest spawned")
		_check(_elephant != null, "elephant spawned")
		_player.global_position = CANYON_EDGE

	# --- crossing the canyon as awareness ----------------------------------
	elif _step == 30:
		_check(_player.is_on_floor(), "seeker stands at the canyon edge")
		Input.action_press("interact")
	elif _step == 32:
		Input.action_release("interact")
	elif _step == 100:
		_check(_wisp.active, "awareness appears once he has settled")
		Input.action_press("move_right")
	elif _step == 240:
		Input.action_release("move_right")
		_check(_wisp.global_position.x > 2080.0,
			"awareness reached the far side, x=%.0f" % _wisp.global_position.x)
		_check(_wisp.find_landing() != null, "far side is a valid landing")
	elif _step == 250:
		Input.action_press("interact")
	elif _step == 252:
		Input.action_release("interact")
	elif _step == 330:
		_crossed_to = _player.global_position.x
		_check(_crossed_to > 2060.0,
			"body followed the awareness across, x=%.0f" % _crossed_to)
		_check(not _player.is_seated, "he is standing again after arriving")
		_player.global_position = NEAR_CHICK

	# --- carrying the fledgling home ---------------------------------------
	elif _step == 350:
		Input.action_press("interact")
	elif _step == 352:
		Input.action_release("interact")
	elif _step == 420:
		_check(_wisp.active, "awareness appears beside the fledgling")
		Input.action_press("move_right")
	elif _step == 445:
		Input.action_release("move_right")
	elif _step == 700:
		_check(_chick.is_carried, "fledgling was picked up")
		Input.action_press("move_right")
		Input.action_press("move_up")
	elif _step == 790:
		Input.action_release("move_right")
		Input.action_release("move_up")
	elif _step == 860:
		_check(_nest.is_filled, "fledgling reached the nest")
		_check(_chick.global_position.distance_to(_nest.global_position) < 40.0,
			"fledgling is sitting in the nest")
	elif _step == 1200:
		_check(_elephant.is_ready, "elephant arrives after the bird speaks")
		_report()
		return true
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok    %s" % message)
	else:
		_failures.append(message)
		print("  FAIL  %s" % message)


func _report() -> void:
	print("")
	if _failures.is_empty():
		print("tools check passed")
		quit(0)
	else:
		print("tools check FAILED (%d)" % _failures.size())
		quit(1)
