extends SceneTree
## Actual hazard entries and contextual E interactions, across repeated trips.
var failures := 0
var level: LevelMap
var player: Seeker
var elephant: Elephant
var entries := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	level = load("res://Scenes/level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(20)
	player = level.player
	elephant = level._elephant
	level.get_node("Hazard").body_entered.connect(func(body: Node2D) -> void:
		if body == player: entries += 1)
	var chick: Fledgling
	for entity in level.get_node("Entities").get_children():
		if entity is Fledgling: chick = entity
	await fall_in(0)
	check(not level._help_requested and not level._adult_bird.visible, "failure before rescue does not call bird")
	var deliveries := [0]
	level._nest.delivered.connect(func() -> void: deliveries[0] += 1)
	chick.interact(player)
	level._nest.interact(player)
	var at_nest := chick.position
	chick.interact(player)
	chick.return_home()
	chick.release(Vector2.ZERO)
	level._nest.interact(player)
	check(deliveries[0] == 1 and chick.delivered and level._nest.is_filled, "delivery is permanent and fires exactly once")
	check(chick.position == at_nest and not chick.can_interact(player), "delivered chick cannot be picked up or removed")
	check(player.carried == null and chick.carrier == null, "both carrier references are clean")
	check(chick.get_node("AnimationPlayer").is_playing(), "nested chick retains animation and chirp timeline")
	await frames(120)
	check(not level._help_requested and not level._adult_bird.visible, "rescue after an earlier failure still waits for a NEW failed attempt")
	var arrivals := [0]
	var departures := [0]
	level._adult_bird.arrived.connect(func() -> void: arrivals[0] += 1)
	level._adult_bird.departed.connect(func() -> void: departures[0] += 1)
	await fall_in(0)
	check(level._help_requested and level._bird_sequence_active, "first failed attempt after rescue starts help")
	await fall_in(0)
	for frame in 1800:
		if elephant.is_waiting() and not level._bird_sequence_active: break
		await physics_frame
	check(elephant.is_waiting() and elephant.bank == 0, "help unlocks one elephant at the left bank")
	check(arrivals[0] == 1 and departures[0] == 1 and level._adult_bird.visible
		and level._adult_bird.global_position.distance_to(level._nest.global_position + Vector2(28,-10)) < 1, "bird sequence runs once and parent remains at nest")
	check(is_equal_approx(elephant.position.y, elephant._home.y + elephant.land_height), "arrival ends at dry land height")
	await fall_in(0)
	await ride_to(1)
	await fall_in(1)
	# Fixture relocation simulates returning to the opposite bank independently.
	await call_from(0)
	await fall_in(0)
	await call_from(1)
	await ride_to(0)
	await fall_in(0)
	for cycle in 2:
		await ride_to(1)
		await fall_in(1)
		await ride_to(0)
		await fall_in(0)
	check(arrivals[0] == 1 and deliveries[0] == 1, "repeated river failures never replay help or delivery")
	check(level.get_node("Entities").get_children().filter(func(n: Node) -> bool: return n is Elephant).size() == 1,
		"all trips use the same elephant")
	print("river state check %s" % ("passed" if failures == 0 else "FAILED"))
	preload("res://tools/test_cleanup.gd").finish(self, 0 if failures == 0 else 1)

func fall_in(side: int) -> void:
	var before := entries
	player._last_safe = Vector2(6110, 520)
	player.position = Vector2(6110, 500)
	player.velocity = Vector2(100, 250)
	await frames(100)
	check(entries == before + 1 and not level.get_node("Hazard").overlaps_body(player), "river entry returns once without a loop")
	check(player.position.distance_to(level.river_checkpoints[side]) < 1 and player.is_on_floor(),
		"safe explicit checkpoint on bank %d" % side)

func call_from(side: int) -> void:
	var water: Rect2i = level.get_node("Water").get_used_rect()
	var edge_x := water.position.x * 32 - 12 if side == 0 else water.end.x * 32 + 12
	player.respawn_at(Vector2(edge_x, level.river_checkpoints[side].y))
	await frames(25)
	var call_point = level._bank_nodes[side]
	check(player.current_interactable() == call_point and call_point.interact_prompt() == "E to call elephant",
		"opposite-bank E offers call on bank %d" % side)
	await tap()
	check(elephant.state == Elephant.State.CROSSING and player.riding == null, "calling sends elephant alone")
	await wait_crossing(side)
	check(level.active_river_bank == side, "empty crossing does not move player's checkpoint")

func ride_to(side: int) -> void:
	check(player.current_interactable() == elephant, "bank-side E offers mounting")
	await tap()
	check(player.riding == elephant and elephant.state == Elephant.State.CROSSING, "mounting starts the opposite-bank trip")
	await wait_crossing(side)
	check(level.active_river_bank == side, "passenger arrival updates active checkpoint")
	await tap()
	await frames(10)
	check(player.riding == null and elephant.is_waiting(), "dismount leaves elephant reusable")
	check(player.position.distance_to(level.river_checkpoints[side]) < 1, "dismount uses safe ground")

func wait_crossing(side: int) -> void:
	var saw_wading := false
	var smooth := true
	var last_y := elephant.position.y
	for frame in 600:
		saw_wading = saw_wading or absf(elephant.position.y - elephant._home.y - elephant.wade_depth) < 0.1
		smooth = smooth and absf(elephant.position.y - last_y) < 2.0
		last_y = elephant.position.y
		if elephant.state != Elephant.State.CROSSING: break
		await physics_frame
	await frames(3)
	check(elephant.bank == side and elephant.state in [Elephant.State.WAITING, Elephant.State.LANDED], "trip completes at bank %d" % side)
	check(elephant.position.distance_to(elephant.bank_position(side)) < 0.1, "elephant reaches the exact bank position")
	check(saw_wading and smooth and absf(elephant.position.y - elephant._home.y - elephant.land_height) < 0.1,
		"smooth land-to-water-to-land heights")

func tap() -> void:
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(2)

func frames(count: int) -> void:
	for i in count: await physics_frame

func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok: failures += 1
