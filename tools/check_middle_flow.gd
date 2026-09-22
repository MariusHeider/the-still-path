extends SceneTree
var _finishing := false
## Walk the newly spaced canyon-to-chick-to-river journey, including nest ledges.
var _player: Seeker
var _failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var level = load("res://Scenes/level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await _frames(20)
	_player = level.player
	var chick: Fledgling
	for entity in level.get_node("Entities").get_children():
		if entity is Fledgling: chick = entity
	_player.respawn_at(Vector2(4284, 480))
	await _frames(20)
	if not await _travel(5290, 480): return
	_check(_player.current_interactable() == chick, "quiet canyon exit leads to chick")
	await _tap("interact")
	_check(absf(chick._home.x - level._nest.position.x) < 1 and chick._home.y > level._nest.position.y,
		"fallen chick is directly below its nest")
	# Backtrack to the rooted rock, then ascend two broad wooden branches.
	if not await _travel(5150, 480): return
	if not await _travel(5080, 416, true): return
	if not await _travel(5100, 416): return
	if not await _travel(5168, 352, true): return
	if not await _travel(5206, 352): return
	if not await _travel(5296, 288, true): return
	_check(_player.current_interactable() == level._nest, "nest reached by climbing with chick")
	_check(level._elephant.state == Elephant.State.HIDDEN, "walking to nest never calls elephant early")
	await _tap("interact")
	_check(level._nest.is_filled, "normal E delivery still works")
	# Continue on foot through the added bank clearing; river itself stays unmodified.
	if not await _travel(5904, 480): return
	_check(_player.position.distance_to(level.river_respawn_position) < 5,
		"quiet nest-to-river stretch reaches safe bank")
	_check(not level.get_node("Audio").mountain_started, "mountain sound does not start before crossing")
	_check(not level._help_requested and not level._adult_bird.visible, "help waits for an actual river failure")
	# No failed river attempt has happened in this route.
	for frame in 1200:
		if not level._bird_sequence_active: break
		await physics_frame
	_check(not level._bird_sequence_active, "waiting on the bank alone does not start a bird sequence")
	print("middle flow check %s" % ("passed" if _failures == 0 else "FAILED"))
	_finish(0 if _failures == 0 else 1)

func _travel(x: float, y: float, jump := false) -> bool:
	if jump:
		Input.action_press("jump")
	var last_x := _player.position.x
	var stuck := 0
	for frame in 1600:
		var dx := x - _player.global_position.x
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(dx) > 3.0:
			Input.action_press("move_right" if dx > 0 else "move_left")
		if absf(_player.position.x - last_x) < 0.2 and absf(dx) > 6.0:
			stuck += 1
		else:
			stuck = 0
		last_x = _player.position.x
		if stuck == 15 and _player.is_on_floor():
			Input.action_press("jump")
		if stuck == 16:
			stuck = 0
		if frame % 40 == 30:
			Input.action_release("jump")
		if frame > 10 and absf(dx) <= 4.0 and _player.is_on_floor() and absf(_player.position.y - y) < 2.0:
			Input.action_release("jump")
			Input.action_release("move_left")
			Input.action_release("move_right")
			await _frames(6)
			_check(true, "travelled to (%d, %d) using movement%s" % [x, y, " and jump" if jump else ""])
			return true
		await physics_frame
	_check(false, "could not reach (%d, %d); at %s" % [x, y, _player.position])
	_finish(1)
	return false


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(2)


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition:
		_failures += 1

func _finish(code := 0) -> void:
	if _finishing: return
	_finishing = true
	preload("res://tools/test_cleanup.gd").finish(self, code)
