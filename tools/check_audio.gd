extends SceneTree
var _finishing := false
## Event timing and valid streams, not subjective mix quality.
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var streams := [Sound.MENU, Sound.AMBIENCE, Sound.MOUNTAIN, Sound.LAND,
		Sound.CHICK, Sound.BIRD, Sound.GROWTH, Sound.FOG, Sound.LEAVING, Sound.TELEPORT, Sound.GONG]
	streams.append_array(Sound.STEPS)
	streams.append_array(Sound.SPLASHES)
	for stream in streams:
		check(stream is AudioStream and stream.get_length() > 0.0, stream.resource_path.get_file() + " loads")
	var last := -1
	for i in 100:
		var next := Sound.choose(Sound.STEPS, last)
		check(next != last, "sample avoids immediate repetition", false)
		last = next
	var level = load("res://Scenes/level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(20)
	var player: Seeker = level.player
	var audio = player.get_node("Audio")
	check(level.get_node("Audio").main.playing and not level.get_node("Audio").wind.playing,
		"only combined ambience plays at level start")
	check(not audio.landing.playing, "spawn has no landing sound")
	var plant: FocusPlant
	var reveal: FocusReveal
	var chick: Fledgling
	var summit: FocusSummit
	var elephant: Elephant
	for entity in level.get_node("Entities").get_children():
		if entity is FocusPlant: plant = entity
		elif entity is FocusReveal: reveal = entity
		elif entity is Fledgling: chick = entity
		elif entity is FocusSummit: summit = entity
		elif entity is Elephant: elephant = entity
	check(not plant.growth_audio.playing and not reveal.reveal_audio.playing, "focus buildup is silent")
	plant.complete()
	reveal.complete()
	check(plant.growth_audio.playing and reveal.reveal_audio.playing, "growth and clearing start their cues")
	player.get_node("Awareness").activate(player.position + player.awareness_offset)
	check(audio.leaving.playing, "Awareness appearance starts leaving-body sound")
	player._teleport_to(player.position + Vector2(40, 0))
	check(not audio.teleport.playing, "teleport cue waits for actual body relocation")
	await frames(23)
	check(audio.teleport.playing, "body relocation plays teleport sound")
	await frames(45)
	# This fixture activated Awareness directly while standing; clear that fixture
	# before testing normal body-based focus at the summit.
	player.get_node("Awareness").deactivate()
	var animation: AnimationPlayer = chick.get_node("AnimationPlayer")
	animation.seek(4.39, true)
	animation.advance(0.03)
	await process_frame
	check(chick.chirp_audio.playing, "chick chirps on the beak-opening animation key")
	var bird = level._adult_bird
	var chirped := [false]
	bird.arrived.connect(func() -> void: chirped[0] = bird.chirp_audio.playing)
	await bird.arrive(level._nest.position + Vector2(24, -6)).finished
	check(chirped[0], "adult chirps at arrival before dialogue")
	# Drive one real jump and detect the single landing playback.
	player.respawn_at(Vector2(300, 608))
	await frames(30)
	Input.action_press("jump")
	await frames(25)
	Input.action_release("jump")
	var landed_sound := false
	for i in 60:
		landed_sound = landed_sound or audio.landing.playing
		await physics_frame
	check(landed_sound, "real jump landing plays the landing cue")
	audio.landing.stop()
	player.respawn_at(Vector2(300, 608))
	await frames(40)
	check(not audio.landing.playing, "respawn does not produce a landing cue")
	Input.action_press("move_right")
	await frames(20)
	check(audio._last_step >= 0, "walk contact frames select footsteps")
	Input.action_release("move_right")
	await frames(20)
	var chosen: int = audio._last_step
	await frames(40)
	check(audio._last_step == chosen, "idle does not generate footsteps")
	check(level.has_node("MountainAudioZone"), "map creates deterministic mountain trigger")
	player.respawn_at(level.mountain_start + Vector2(16, 0))
	await frames(330)
	var bed = level.get_node("Audio")
	check(bed.mountain_started and bed.wind.playing and bed.main.stream_paused,
		"entering mountain crossfades to wind and pauses forest bed")
	var wind_position: float = bed.wind.get_playback_position()
	bed.enter_mountain(player)
	check(bed.wind.get_playback_position() >= wind_position, "mountain transition does not restart")
	player.respawn_at(level.mountain_start - Vector2(64, 0))
	await frames(330)
	check(not bed.mountain_started and bed.wind.stream_paused and not bed.main.stream_paused
		and is_equal_approx(bed.main.volume_db, bed.ambience_db), "leaving mountain restores the accepted forest level")
	player.respawn_at(level.mountain_start + Vector2(16, 0))
	await frames(60)
	var before_reverse: float = bed.wind.volume_db
	player.respawn_at(level.mountain_start - Vector2(64, 0))
	await frames(2)
	check(absf(bed.wind.volume_db - before_reverse) < 1.0, "mid-fade reversal has no volume jump")
	await frames(330)
	check(bed.wind.stream_paused and not bed.main.stream_paused, "reversed fade reaches the correct final state")
	player.respawn_at(summit.position + Vector2(-40, -32))
	await frames(30)
	player._set_seated(true)
	check(not root.has_node("FinalGong"), "gong does not start during lowering posture")
	await frames(32)
	check(not root.has_node("FinalGong"), "settled final meditation has not yet earned the gong")
	for frame in 600:
		if player.final_success: break
		await physics_frame
	check(root.has_node("FinalGong") and root.get_node("FinalGong").playing, "successful final focus starts gong")
	var gong = root.get_node_or_null("FinalGong")
	level.queue_free()
	await process_frame
	check(is_instance_valid(gong) and gong.playing, "gong tail survives removal of gameplay scene")
	if is_instance_valid(gong):
		gong.stop()
		gong.queue_free()
	await frames(3)
	print("audio check %s" % ("passed" if failures == 0 else "FAILED"))
	_finish(0 if failures == 0 else 1)

func frames(count: int) -> void:
	for i in count: await physics_frame

func check(ok: bool, label: String, log_success := true) -> void:
	if not ok: failures += 1
	if not ok or log_success: print(("  ok    " if ok else "  FAIL  ") + label)

func _finish(code := 0) -> void:
	if _finishing: return
	_finishing = true
	preload("res://tools/test_cleanup.gd").finish(self, code)
