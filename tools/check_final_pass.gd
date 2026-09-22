extends SceneTree
var _finishing := false
## Bounds, narrative ordering, entrance framing, summit route and final pose.
## Run: godot --headless --path . --script res://tools/check_final_pass.gd

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level = load("res://Scenes/level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await _frames(20)
	var player: Seeker = level.player
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	var camera: Camera2D = player.get_node("Camera2D")
	var wisp: Awareness = player.get_node("Awareness")
	var elephant: Elephant
	var chick: Fledgling
	var nest: Nest
	var summit: FocusSummit
	for entity in level.get_node("Entities").get_children():
		if entity is Elephant: elephant = entity
		elif entity is Fledgling: chick = entity
		elif entity is Nest: nest = entity
		elif entity is FocusSummit: summit = entity
	_check(sprite.sprite_frames.has_animation("meditate_down")
		and sprite.sprite_frames.has_animation("meditate"), "existing meditation animations available")
	await _tap()
	await _frames(90)
	_check(sprite.animation == &"sit", "ordinary sitting still uses sit")
	_check(level.get_node("HUD/Readout").text.is_empty(), "no stillness meter or persistent sit prompt")
	await _tap()

	player.global_position = Vector2(3976, 480)
	camera.reset_smoothing()
	camera.force_update_scroll()
	await _frames(30)
	await _tap()
	await _frames(90)
	_check(wisp.active, "canyon activates Awareness normally")
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN,
			Vector2(-1, -1), Vector2(1, 1)]:
		wisp.steer(direction, 10.0, player.global_position + player.awareness_offset)
		_check(wisp.visible_world_rect().grow(0.01).has_point(wisp.global_position),
			"Awareness stays inside visible camera margin: " + str(direction))
		_check(wisp.global_position.distance_to(wisp.anchor) <= wisp.max_range + 0.01,
			"Awareness also retains maximum range")
	player._set_seated(false)
	player.global_position = Vector2(5904, 480)
	camera.reset_smoothing()
	camera.force_update_scroll()
	await _frames(30)

	var finished := [false]
	var leaving := [false]
	var departed_early := [false]
	var bird_events: Array[String] = []
	var bird = level._adult_bird
	_check(not bird.visible, "adult bird is not a static object before delivery")
	bird.departure_started.connect(func() -> void:
		leaving[0] = true
		_check(not bird._speaking, "bird finishes speech before departure"))
	bird.departed.connect(func() -> void:
		departed_early[0] = elephant.state == Elephant.State.ARRIVING)
	bird.arrived.connect(func() -> void:
		bird_events.append("arrived")
		_check(bird.position.distance_to(player.position) > 70 and bird.position.y < player.position.y - 35,
			"river bird keeps a comfortable raised conversation position"))
	bird.speech_started.connect(func(line: String) -> void:
		bird_events.append(line)
		_check(level.get_node("HUD/Message").modulate.a == 0.0, "bird dialogue is separate from the principle HUD"))
	bird.speech_finished.connect(func(_line: String) -> void: bird_events.append("bubble finished"))
	level.bird_sequence_finished.connect(func() -> void:
		finished[0] = true
		_check(elephant.state == Elephant.State.ARRIVING, "elephant arrives while principle plays")
		_check(not bird._speaking and not bird.get_node("Speech/Bubble").visible, "speech bubble is gone before principle finishes")
		_check(level.get_node("HUD/Message").text == "I am a mother to the world."
			and level.get_node("HUD/Message").modulate.a == 0.0, "mother principle has fully faded"))
	_check(chick.get_node("AnimationPlayer").is_playing(), "chick animation runs while on ground")
	chick.interact(player)
	_check(chick.get_node("AnimationPlayer").is_playing(), "same chick animation continues while carried")
	nest.interact(player)
	_check(nest.is_filled and player.carried == null, "animated chick is delivered normally")
	await _frames(20)
	_check(not bird.visible and elephant.state == Elephant.State.HIDDEN, "delivery alone does not start help")
	player.global_position = Vector2(6080, 500)
	player.velocity = Vector2(0, 100)
	var early_entrance := false
	for frame in 1600:
		if elephant.state != Elephant.State.HIDDEN:
			early_entrance = bird._speaking
			break
		await physics_frame
	_check(bird_events == ["arrived", "You brought my little one home.", "bubble finished", "Wait here. I know someone who can help you.", "bubble finished"], "adult arrival and both bubbles have the exact requested order")
	_check(not early_entrance and not finished[0], "entrance begins after speech without waiting for principle")
	_check(elephant.state == Elephant.State.ARRIVING, "elephant begins entering after the pause")
	_check(leaving[0], "bird departure starts with elephant entrance")
	await _frames(2)
	_check(level.get_node("HUD/Message").modulate.a == 0, "principle stays hidden when bird departs")
	var entrance_x := elephant.position.x
	await _frames(30)
	_check(absf((entrance_x - elephant.position.x) * 2.0 - elephant.walking_speed()) < 2,
		"entrance uses normal crossing velocity")
	var view: Rect2 = root.get_canvas_transform().affine_inverse() * root.get_visible_rect()
	_check(entrance_x - 54.0 > view.end.x, "whole elephant starts outside camera view")
	await _frames(48)
	_check(level.get_node("HUD/Message").modulate.a == 0, "principle stays hidden through first 1.3 seconds")
	await _frames(18)
	_check(level.get_node("HUD/Message").text == "I am a mother to the world."
		and level.get_node("HUD/Message").modulate.a > 0, "principle begins fading in after 1.5 seconds")
	for frame in 1000:
		if elephant.state == Elephant.State.WAITING: break
		await physics_frame
	_check(departed_early[0], "bird returns home before elephant finishes arriving")
	_check(bird.visible and bird.global_position.distance_to(nest.global_position + Vector2(28,-10)) < 1,
		"parent remains visibly perched beside the nest")
	_check(elephant.state == Elephant.State.WAITING, "elephant walks in to its dry-bank waiting point")
	_check(elephant._last_splash >= 0, "entrance walk contacts play varied water steps")
	var stopped_splash := elephant._last_splash
	await _frames(40)
	_check(elephant._last_splash == stopped_splash, "stationary elephant emits no further splashes")
	_check(level.get_node("Water").position.y == 0.0, "water surface stays at natural bank height")
	_check(absf(elephant.position.y - elephant._home.y - elephant.land_height) < 0.1,
		"waiting elephant stands at land height")
	player.global_position = elephant.global_position + Vector2(-4, -58)
	player.velocity = Vector2.ZERO
	await _frames(30)
	_check(player.is_on_floor() and player.current_interactable() == elephant, "standing on its back selects the elephant")
	await _tap()
	_check(player.riding == elephant and not player.is_seated, "E on the back mounts rather than sits")
	for frame in 500:
		if elephant.state == Elephant.State.LANDED: break
		await physics_frame
	_check(elephant.state == Elephant.State.LANDED and absf(elephant.position.y - elephant._home.y) < 0.1,
		"elephant rises to original far-bank height")
	await _tap()
	_check(player.riding == null, "dismount still works after deeper wading")

	# Start at the existing river landing and climb normally, then WALK the stairs.
	await _frames(30)
	Input.action_press("move_right")
	for frame in 2400:
		if frame % 60 == 0 and player.position.x < summit.position.x - 244:
			Input.action_press("jump")
		elif frame % 60 == 30:
			Input.action_release("jump")
		if player.position.x >= summit.position.x - 40: break
		await physics_frame
	Input.action_release("jump")
	Input.action_release("move_right")
	await _frames(30)
	_check(player.is_on_floor() and absf(player.position.y - (summit.position.y - 32)) < 2,
		"mountain and walkable shrine foundation reached")
	_check(player.meditation_site == summit, "player is inside final meditation area")
	await _tap()
	_check(sprite.animation == &"meditate_down", "final sitting begins with meditate_down")
	await _frames(90)
	_check(sprite.animation == &"meditate", "final held posture uses meditate")
	_check(level.focus.target == summit, "final meditation attends to the shrine")
	_check(not root.has_node("FinalGong"), "settled pose alone does not play gong")
	_check(summit.modulate == Color.WHITE, "shrine retains its normal colors during focus")
	for frame in 600:
		if player.final_success: break
		await physics_frame
	_check(player.final_success and root.has_node("FinalGong"), "successful summit focus locks meditation and plays gong")
	var held_position := player.position
	Input.action_press("move_left")
	Input.action_press("jump")
	Input.action_press("interact")
	await _frames(20)
	Input.action_release("move_left")
	Input.action_release("jump")
	Input.action_release("interact")
	_check(player.position == held_position and player.is_seated and sprite.animation == &"meditate",
		"movement, jump and interact cannot interrupt final success")
	summit.complete()
	player.lock_final_meditation()
	_check(root.get_children().filter(func(n: Node) -> bool: return n.name == &"FinalGong").size() == 1,
		"repeat success calls cannot duplicate gong")
	await _frames(180)
	_check(is_instance_valid(current_scene) and current_scene is Control,
		"final meditation reaches the ending")
	if current_scene is Control:
		_check(current_scene.get_node("Lines").text == "The path was never about reaching the summit.\n\nIt was about how you moved through the world.",
			"ending has the revised text")
		_check(not current_scene.has_node("Quit"), "ending remains button-free")
	print("final pass check %s" % ("passed" if _failures == 0 else "FAILED"))
	_finish(0 if _failures == 0 else 1)


func _tap() -> void:
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(2)


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	print(("  ok    " if condition else "  FAIL  ") + message)
	if not condition: _failures += 1

func _finish(code := 0) -> void:
	if _finishing: return
	_finishing = true
	preload("res://tools/test_cleanup.gd").finish(self, code)
