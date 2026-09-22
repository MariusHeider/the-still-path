extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var level = load("res://Scenes/level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var p: Seeker = level.player
	var w: Awareness = p.get_node("Awareness")
	var camera: Camera2D = p.get_node("Camera2D")
	var zones: Array[Node2D] = []
	var summit: FocusSummit
	var chick: Fledgling
	for n in level.get_node("Entities").get_children():
		if n is ProjectionZone: zones.append(n)
		if n is FocusSummit: summit = n
		if n is Fledgling: chick = n
	zones.sort_custom(func(a: Node2D,b: Node2D) -> bool: return a.position.x < b.position.x)
	check(zones.size() == 2, "two explicit canyon projection zones")
	await frames(20)
	for at in [zones[0].position - Vector2(128,0), zones[1].position + Vector2(128,0)]:
		p.respawn_at(at)
		await frames(10)
		await tap()
		await frames(100)
		check(not p.can_project and not w.active, "cannot activate on approach/outside either canyon zone")
		p._set_seated(false)
	p.respawn_at(zones[0].position)
	await frames(15)
	for side in [1,0,1,0]:
		camera.reset_smoothing()
		camera.force_update_scroll()
		await tap()
		await frames(95)
		check(p.can_project and w.active, "Awareness reactivates on bank %d" % (1-side))
		var landing: Vector2 = zones[side].position
		check(w.visible_world_rect().has_point(landing + Vector2(0,-22)), "opposite-bank landing is visible from seated body")
		var action := "move_right" if side == 1 else "move_left"
		Input.action_press(action)
		for i in 160:
			if absf(w.global_position.x - landing.x) < 4: break
			await physics_frame
		Input.action_release(action)
		check(w.find_landing() != null, "opposite bank offers a real landing")
		check(w.visible_world_rect().grow(0.1).has_point(w.global_position)
			and w.global_position.distance_to(w.anchor) <= w.max_range + .1, "screen and distance bounds stay intact")
		await tap()
		await frames(70)
		check(absf(p.position.x - landing.x) < 5 and not p.is_seated and not w.active,
			"normal E teleport crosses to bank %d" % side)
		check(p.can_project and p.projection_zones.size() == 1, "destination zone survives source-zone exit")
	check(get_nodes_in_group("awareness").size() == 1, "all trips reuse one Awareness object")
	var sprites: SpriteFrames = p.get_node("AnimatedSprite2D").sprite_frames
	for name in {"idle":3,"walk":10,"jump":12,"fall":6,"land":14,"sit":3,"sit_down":12,"meditate":3,"meditate_down":12}:
		var speeds := {"idle":3,"walk":10,"jump":12,"fall":6,"land":14,"sit":3,"sit_down":12,"meditate":3,"meditate_down":12}
		check(sprites.get_animation_speed(name) == speeds[name], "animation speed preserved/updated: " + name)
	check(chick.sitting_head_drop == 7.5, "chick sitting head drop is 7.5px")
	var stream: AudioStreamPlayer2D = level.get_node("Water/Stream")
	check(stream.stream.resource_path.ends_with("/Stream.ogg") and stream.stream.loop and stream.playing,
		"actual Stream.ogg loads and loops continuously")
	check(stream.max_distance == 480 and stream.volume_db == -26 and stream.attenuation > 1,
		"quiet positional river stream has finite local reach")
	check(level.get_node("Audio/MainAmbience").playing and stream != level.get_node("Audio/MainAmbience"),
		"local stream coexists with main ambience")
	var playback := stream.get_stream_playback()
	p.respawn_at(Vector2(300,608))
	await frames(20)
	check(stream.get_stream_playback() == playback, "moving away does not restart river stream")
	check(level.get_node("Water/Current").current_speed == 24, "current overlay animates at readable speed")
	# Test the full flat temple floor, including the linga position, without completing yet.
	for x in [-120.0,-70.0,0.0,70.0,120.0]:
		p.respawn_at(summit.position + Vector2(x,-32))
		await frames(15)
		check(p.meditation_site == summit, "interior admits meditation at x=%d" % x)
		await tap()
		await frames(100)
		check(level.focus.target == summit and p.get_node("AnimatedSprite2D").animation == &"meditate",
			"full focus and meditation pose work at x=%d" % x)
		check(not root.has_node("FinalGong"), "entering meditation alone does not play gong")
		p._set_seated(false)
		await frames(5)
	for x in [-160.0,160.0,-210.0,210.0]:
		p.respawn_at(summit.position + Vector2(x,-32))
		await frames(45)
		await tap()
		await frames(100)
		check(p.meditation_site == null and level.focus.target != summit, "stairs/outside excluded at x=%d" % x)
		p._set_seated(false)
	summit.linger = 100
	p.respawn_at(summit.position + Vector2(120,-32))
	await frames(20)
	await tap()
	await frames(600)
	check(p.final_success and root.has_node("FinalGong"), "meditation succeeds at far interior edge")
	check(root.get_node("FinalGong").volume_db == -16, "successful gong is 4dB quieter")
	var held := p.position
	Input.action_press("move_left")
	Input.action_press("jump")
	await tap()
	await frames(20)
	Input.action_release("move_left")
	Input.action_release("jump")
	check(p.position == held and p.get_node("AnimatedSprite2D").animation == &"meditate", "final input lock remains intact")
	print("final polish check %s" % ("passed" if failures == 0 else "FAILED"))
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
