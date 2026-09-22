extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var level = load("res://Scenes/level.tscn").instantiate()
	root.add_child(level)
	var p: Seeker = level.player
	var chick: Fledgling
	for entity in level.get_node("Entities").get_children():
		if entity is Fledgling: chick = entity
	for i in 20: await physics_frame
	p.set_physics_process(false)
	chick.interact(p)
	chick.get_node("AnimationPlayer").pause()
	var sprite: AnimatedSprite2D = p.get_node("AnimatedSprite2D")
	sprite.play("idle")
	sprite.pause()
	var expected := [-35.0,-36.0,-37.0,-36.0,-35.0]
	for frame in 5:
		sprite.set_frame_and_progress(frame,0)
		chick.get_node("Visual").position.y = -1
		chick._process(0)
		var actual: float = chick.position.y + chick.get_node("Visual").position.y + chick.get_node("Visual/Sprite").position.y + 7 - p.position.y
		check(is_equal_approx(actual,expected[frame]), "idle frame %d follows head exactly, without independent body bob" % frame)
	sprite.play("walk")
	chick._process(0)
	check(chick.position.y-p.position.y == -36 and chick.get_node("Visual/Sprite").position.y == -7,
		"idle to walk restores unchanged walking attachment and bob")
	p.is_seated = true
	sprite.play("sit_down")
	sprite.set_frame_and_progress(2,0)
	chick._process(0)
	check(is_equal_approx(chick.position.y-p.position.y,-31.25), "sit_down keeps interpolation plus exactly one pixel")
	sprite.play("sit")
	chick._process(0)
	check(chick.position.y-p.position.y == -27.5, "seated attachment is exactly one pixel lower")
	p.is_seated = false
	sprite.play("idle")
	sprite.set_frame_and_progress(0,0)
	chick._process(0)
	check(chick.position.y-p.position.y == -35, "sit to stand restores lowered neutral idle position")
	chick.return_home()
	chick._process(0)
	check(chick.get_node("Visual/Sprite").position.y == -7 and p.carried == null, "release restores uncarried visual origin")
	print("chick attachment check %s" % ("passed" if failures == 0 else "FAILED"))
	preload("res://tools/test_cleanup.gd").finish(self,0 if failures == 0 else 1)
func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok: failures += 1
