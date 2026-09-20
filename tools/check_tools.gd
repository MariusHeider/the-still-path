extends SceneTree
## Drives the mechanics that are slow and fiddly to test by hand: the attention
## being refused outside its zone and working inside it, carrying the fledgling
## home, and the elephant arriving and wading across.
##
## Run:  godot --headless --path . --script res://tools/check_tools.gd

const OUTSIDE_ZONE := Vector2(300, 416)
const CANYON_EDGE := Vector2(1800, 288)
const NEAR_CHICK := Vector2(2180, 288)
const AT_NEST := Vector2(2544, 96)
const BESIDE_ELEPHANT := Vector2(2690, 288)

var _level: LevelMap
var _player: Seeker
var _wisp: Awareness
var _chick: Fledgling
var _nest: Nest
var _elephant: Elephant

var _step := 0
var _failures: Array[String] = []


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
			if child is Fledgling:
				_chick = child
			elif child is Nest:
				_nest = child
			elif child is Elephant:
				_elephant = child
		_check(_chick != null and _nest != null and _elephant != null,
			"fledgling, nest and elephant all spawned")
		_player.global_position = OUTSIDE_ZONE

	# --- attention stays in the body away from the canyon -------------------
	elif _step == 20:
		_tap("interact")
	elif _step == 110:
		_check(_player.is_seated, "he sits down away from the canyon")
		_check(not _player.can_project, "no projection zone here")
		_check(not _wisp.active, "attention does NOT leave the body here")
		_tap("interact")
	elif _step == 130:
		_check(not _player.is_seated, "and he stands back up")
		_player.global_position = CANYON_EDGE

	# --- but it does at the canyon -----------------------------------------
	elif _step == 150:
		_check(_player.can_project, "the canyon edge is a projection zone")
		_tap("interact")
	elif _step == 240:
		_check(_wisp.active, "attention leaves the body at the canyon")
		Input.action_press("move_right")
	elif _step == 380:
		Input.action_release("move_right")
		_check(_wisp.global_position.x > 2080.0,
			"attention reached the far bank, x=%.0f" % _wisp.global_position.x)
		_tap("interact")
	elif _step == 470:
		_check(_player.global_position.x > 2060.0,
			"body followed it across, x=%.0f" % _player.global_position.x)
		_player.global_position = NEAR_CHICK

	# --- carrying the fledgling home by hand --------------------------------
	elif _step == 500:
		_check(_player.current_interactable() == _chick,
			"the fledgling is what E would act on")
		_tap("interact")
	elif _step == 520:
		_check(_chick.carrier == _player, "he picked the fledgling up")
		_player.global_position = AT_NEST
	elif _step == 560:
		_check(_player.current_interactable() == _nest,
			"the nest is what E would act on while carrying")
		_tap("interact")
	elif _step == 580:
		_check(_nest.is_filled, "the fledgling is home")
		_check(_player.carried == null, "his hands are empty again")

	# --- the elephant arrives and wades across ------------------------------
	elif _step == 600:
		_check(_elephant.state == Elephant.State.HIDDEN,
			"the elephant was not standing there all along")
	elif _step == 1060:
		_check(_elephant.state == Elephant.State.WAITING,
			"the elephant waded in after the bird called")
		_player.global_position = BESIDE_ELEPHANT
	elif _step == 1090:
		_check(_player.current_interactable() == _elephant, "he can climb up")
		_tap("interact")
	elif _step == 1110:
		_check(_player.riding == _elephant, "he is riding")
		_check(_elephant.state == Elephant.State.CROSSING, "it started across")
	elif _step == 1200:
		_check(not _elephant.can_interact(_player),
			"he cannot get off mid-river")
	elif _step == 1600:
		_check(_elephant.state == Elephant.State.LANDED, "it reached the far bank")
		_tap("interact")
	elif _step == 1640:
		_check(_player.riding == null, "he climbed down")
		_check(_player.global_position.x > 2940.0,
			"and he is across, x=%.0f" % _player.global_position.x)
		_report()
		return true
	return false


## A press and release two frames apart, which is what just_pressed needs.
func _tap(action: String) -> void:
	Input.action_press(action)
	get_tree_tap(action)


func get_tree_tap(action: String) -> void:
	# Released on the next idle frame so the press is seen exactly once.
	Callable(Input, "action_release").bind(action).call_deferred()


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
