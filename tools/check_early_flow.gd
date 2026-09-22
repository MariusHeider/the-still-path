extends SceneTree
var _finishing := false
## Input-driven journey from the start through plant and perception to canyon.
## Run: godot --headless --path . --script res://tools/check_early_flow.gd

var _level: LevelMap
var _player: Seeker
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var node: Node = load("res://Scenes/level.tscn").instantiate()
	root.add_child(node)
	_level = node as LevelMap
	if _level == null:
		_finish(1)
		return
	await _frames(20)
	_player = _level.player
	var plant: FocusPlant
	var reveal: Focusable
	for entity in _level.get_node("Entities").get_children():
		if entity is FocusPlant:
			plant = entity
		elif entity.get_script().resource_path.ends_with("focus_reveal.gd"):
			reveal = entity
	_check(plant != null and reveal != null, "plant and reveal spawned from the map")
	if plant == null or reveal == null:
		_finish(1)
		return
	var terrain: TileMapLayer = _level.get_node("Terrain")
	var before := _terrain_snapshot(terrain)
	_check(reveal.message == "What is there right now is all there is.", "reveal principle configured")
	_check(reveal.get_node("Veil").visible and reveal.get_node("Veil").modulate.a == 1.0,
		"veil begins uncleared")
	_check(_route_has_ground(), "hidden route has physical ground before attention")
	_check(plant.get_node("Platform/CollisionShape2D").disabled, "flower platform starts unavailable")

	if not await _travel(432, 608): return
	if not await _travel(1178, 544, true): return
	# A full jump from the approach ledge cannot bypass the ungrown plant.
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(45)
	Input.action_release("jump")
	Input.action_release("move_right")
	await _frames(20)
	_check(_player.global_position.x < 1312 and _player.global_position.y > 542,
		"upper shelf cannot be reached with a direct jump before plant growth")
	if not await _travel(1250, 608): return
	await _tap("interact")
	await _frames(100)
	_check(_level.focus.target == plant, "first environmental puzzle uses normal focus")
	await _frames(290)
	_check(plant.is_done and not plant.get_node("Platform/CollisionShape2D").disabled,
		"plant completes and enables its flower platform")
	await _tap("interact")
	if not await _travel(1232, 608): return
	if not await _travel(1178, 544, true): return
	if not await _travel(1264, 498, true): return
	if not await _travel(1344, 480, true): return
	if not await _travel(2208, 480): return
	_check(not _player.can_project, "perception section is outside the projection zone")
	var warnings := [0]
	reveal.passage_blocked.connect(func() -> void: warnings[0] += 1)
	Input.action_press("move_right")
	await _frames(30)
	_check(_player.position.x > 2240 and _player.mist_speed_scale < 1.0,
		"player enters outer mist with progressive slowdown instead of a wall")
	_check(warnings[0] == 0, "no message before reaching dense mist")
	for frame in 240:
		if _player.mist_retreat: break
		await physics_frame
	_check(_player.mist_retreat, "dense core starts the short retreat")
	var entered_at := _player.position.x
	_check(entered_at >= reveal.position.x + reveal.dense_core, "retreat begins inside the visible dense core")
	Input.action_release("move_right")
	await _frames(50)
	_check(not _player.mist_retreat and _player.facing == -1 and _player.position.x < entered_at - 30,
		"seeker turns and walks back, then immediately returns control")
	_check(warnings[0] == 1 and _level.get_node("HUD/Message").text == "I can't see a way through.",
		"one narrative hint appears after the attempted passage")
	Input.action_press("move_right")
	Input.action_press("jump")
	for frame in 240:
		if _player.mist_retreat: break
		await physics_frame
	_check(_player.mist_retreat, "jumping through the mist also invokes the soft retreat")
	Input.action_release("move_right")
	Input.action_release("jump")
	await _frames(60)
	_check(warnings[0] == 2 and _level.mist_message_count == 1, "retreat repeats but visible message does not restart")
	await _frames(260)
	Input.action_press("move_right")
	for frame in 240:
		if _player.mist_retreat: break
		await physics_frame
	Input.action_release("move_right")
	await _frames(60)
	_check(_level.mist_message_count == 2, "later completed retreat can show the fully faded message again")
	if not await _travel(2264, 512): return
	await _tap("interact")
	await _frames(100)
	_check(_level.focus.target == reveal, "perception receives attention through FocusSystem")
	await _frames(225)
	_check(reveal.is_done, "perception completes through seated attention")
	_check(_level.get_node("HUD/Message").text != reveal.message,
		"principle is not shown before mist has cleared")
	await _frames(40)
	_check(not reveal.get_node("Veil").visible and reveal.get_node("Veil").modulate.a == 0.0,
		"veil fades fully and hides")
	_check(not reveal.get_node("Boundary").monitoring
		and reveal.get_node("Boundary/CollisionShape2D").disabled,
		"perception boundary is disabled after the reveal")
	_check(_player.mist_speed_scale == 1.0 and not _player.mist_retreat, "reveal restores normal movement permanently")
	_check(_level.get_node("HUD/Message").text == reveal.message,
		"principle appears after reveal")
	_check(before == _terrain_snapshot(terrain) and _route_has_ground(),
		"route tiles and collision are unchanged by reveal")
	await _tap("interact")
	if not await _travel(2400, 544): return
	if not await _travel(2506, 512, true): return
	if not await _travel(2576, 480, true): return
	if not await _travel(2696, 512): return
	if not await _travel(3536, 480, true): return
	if not await _travel(3976, 480): return
	_check(_player.can_project, "existing Awareness canyon is reachable after revealed route")
	print("early flow check %s" % ("passed" if _failures == 0 else "FAILED"))
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


func _terrain_snapshot(terrain: TileMapLayer) -> Dictionary:
	var result := {}
	for cell in terrain.get_used_cells():
		result[cell] = [terrain.get_cell_source_id(cell), terrain.get_cell_atlas_coords(cell),
			terrain.get_cell_tile_data(cell).get_collision_polygons_count(0)]
	return result


func _route_has_ground() -> bool:
	for x in range(70, 85):
		var ray := PhysicsRayQueryParameters2D.create(Vector2(x * 32 + 16, 392),
			Vector2(x * 32 + 16, 592), 1)
		if _player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			return false
	return true


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
