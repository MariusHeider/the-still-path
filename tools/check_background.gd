extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var level = load("res://Scenes/level.tscn").instantiate()
	root.add_child(level)
	var p: Seeker = level.player
	var bg = level.get_node("Background")
	await frames(20)
	check(bg is CanvasLayer and bg.layer < 0 and not bg.follow_viewport_enabled, "background is fixed behind the gameplay canvas")
	check(bg.has_node("Main") and bg.has_node("Mountain/Wind"), "both skies and mountain wind exist")
	check(bg.main.modulate.a == 1 and bg.mountain.modulate.a == 0 and not bg.wind.visible, "main atmosphere starts active without wind")
	check(bg.find_children("*", "CollisionObject2D", true, false).is_empty()
		and bg.find_children("*", "Control", true, false).is_empty(), "background has no collisions or input controls")
	var terrain: Array[Vector2i] = level.get_node("Terrain").get_used_cells()
	var hazard_count: int = level.get_node("Hazard").get_child_count()
	p.respawn_at(level.mountain_start + Vector2(20,0))
	await frames(150)
	check(bg.mountain_active and bg.mountain.modulate.a > .2 and bg.mountain.modulate.a < .8,
		"existing mountain zone starts gradual visual transition")
	check(bg.wind.visible, "wind fades with mountain atmosphere")
	var at_turn: float = bg.mountain.modulate.a
	p.respawn_at(level.mountain_start - Vector2(40,0))
	await frames(3)
	check(not bg.mountain_active and absf(bg.mountain.modulate.a - at_turn) < .05,
		"mid-fade reversal is continuous")
	await frames(310)
	check(bg.mountain.modulate.a == 0 and not bg.wind.visible, "leaving restores main sky and disables wind")
	p.respawn_at(level.mountain_start + Vector2(20,0))
	await frames(320)
	check(bg.mountain.modulate.a == 1 and bg.wind.visible, "mountain sky reaches full opacity")
	check(bg.WIND_STREAKS.size() == 7, "seven reusable mountain wind streaks configured")
	var active_streaks := 0
	for streak in bg.WIND_STREAKS:
		if streak.w > 0 and streak.w < 7: active_streaks += 1
	check(active_streaks >= 2, "staggered timing produces multiple distinct visible streaks")
	var phase: float = bg._wind_time
	await frames(20)
	check(bg._wind_time != phase, "mountain streaks drift over time")
	check(level.get_node("Terrain").get_used_cells() == terrain
		and level.get_node("Hazard").get_child_count() == hazard_count, "background transitions preserve terrain and hazards")
	check(bg.transform == Transform2D.IDENTITY, "moving the camera leaves background canvas stable")
	print("background check %s" % ("passed" if failures == 0 else "FAILED"))
	preload("res://tools/test_cleanup.gd").finish(self, 0 if failures == 0 else 1)
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok: failures += 1

