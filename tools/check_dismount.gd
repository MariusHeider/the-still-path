extends SceneTree
## Real crossings followed by walking/jumping, without moving the dismount fixture.
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var level = load("res://Scenes/level.tscn").instantiate()
	root.add_child(level)
	var p: Seeker = level.player
	var e: Elephant = level._elephant
	await frames(10)
	e.position = e._home
	e._finish_arrival()
	p.respawn_at(level.river_checkpoints[0])
	await frames(10)
	for side in [1, 0]:
		await tap()
		check(p.riding == e, "contextual E mounts")
		await frames(20)
		var seat := e.rider_position() - e.global_position
		check(is_equal_approx(seat.x, e.rider_offset.x if side == 1 else -e.rider_offset.x)
			and is_equal_approx(seat.y, e.rider_offset.y), "seat mirrors anatomically with direction")
		await frames(420)
		await tap()
		check(p.riding == null and not p.is_seated, "dismount clears riding and permits normal control")
		var start := p.position
		var action := "move_right" if side == 1 else "move_left"
		Input.action_press(action)
		await frames(100)
		Input.action_release(action)
		check(absf(p.position.x - start.x) > 90, "walk away from elephant on dry ground after dismount")
		check(p.current_interactable() != e and p.riding == null, "distant elephant cannot reclaim E")
		# The current hand-edited bank includes a low rock; cross it normally.
		Input.action_press(action)
		Input.action_press("jump")
		await frames(12)
		check(p.position.y < start.y - 35 and not p.is_on_floor(), "jump works after dismount")
		Input.action_release("jump")
		await frames(60)
		Input.action_release(action)
		check(absf(p.position.x - start.x) > 220, "continue several metres away across the bank rock")
		# Walk back to the waiting animal for the return journey.
		Input.action_press("move_left" if side == 1 else "move_right")
		for frame in 240:
			if absf(p.position.x - level.river_checkpoints[side].x) < 4: break
			if p.is_on_wall() and p.is_on_floor():
				Input.action_press("jump")
			elif not p.is_on_floor() and p.velocity.y >= 0:
				Input.action_release("jump")
			await physics_frame
		Input.action_release("move_left" if side == 1 else "move_right")
		Input.action_release("jump")
		await frames(10)
	print("dismount check %s" % ("passed" if failures == 0 else "FAILED"))
	preload("res://tools/test_cleanup.gd").finish(self, 0 if failures == 0 else 1)
func tap() -> void:
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(2)
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok: failures += 1
