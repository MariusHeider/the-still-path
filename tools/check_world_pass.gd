extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var level = load("res://Scenes/level.tscn").instantiate()
	root.add_child(level)
	var p: Seeker = level.player
	await frames(20)
	Input.action_press("move_left")
	for i in 4:
		Input.action_press("jump")
		await frames(40)
		Input.action_release("jump")
		await frames(30)
	Input.action_release("move_left")
	check(p.position.x >= 100 and p.position.y < 610, "visible rock rise prevents leaving the map to the left, even jumping")
	Input.action_press("move_right")
	await frames(90)
	Input.action_release("move_right")
	await frames(20)
	check(p.position.x > 300, "opening still permits easy rightward movement")
	var chick: Fledgling
	var reveal: Focusable
	for entity in level.get_node("Entities").get_children():
		if entity is Fledgling: chick = entity
		if entity.get_script().resource_path.ends_with("focus_reveal.gd"): reveal = entity
	chick.interact(p)
	await frames(3)
	check((chick.position-p.position).y >= -37.01 and (chick.position-p.position).y <= -34.99, "standing attachment follows the idle head range")
	p._set_seated(true)
	await frames(10)
	var lowering := (chick.position-p.position).y
	check(lowering > chick.carry_offset.y+1 and lowering < chick.carry_offset.y+1+chick.sitting_head_drop, "chick follows sit_down lowering")
	await frames(90)
	check(absf((chick.position-p.position).y-chick.carry_offset.y-chick.sitting_head_drop-1) < 0.1, "seated chick rests at lowered head offset")
	p._set_seated(false)
	await frames(40)
	check((chick.position-p.position).y >= -37.01 and (chick.position-p.position).y <= -34.99, "standing restores idle attachment")
	chick.return_home()
	var boundary: RectangleShape2D = reveal.get_node("Boundary/CollisionShape2D").shape
	check(boundary.size == Vector2(320,512), "fog visual expansion preserves perception area dimensions")
	check(reveal.get_node("Veil").get_child_count() == 8, "whole eight-mass fog bank shares the existing reveal fade")
	var water: TileMapLayer = level.get_node("Water")
	var current = water.get_node("Current")
	var phase: float = current.phase
	var cells := water.get_used_cells()
	var hazards: int = level.get_node("Hazard").get_child_count()
	await frames(20)
	check(current.cells.size() == cells.size() and current.phase != phase, "current animates over existing water cells")
	check(water.get_used_cells() == cells and level.get_node("Hazard").get_child_count() == hazards and water.position.y == 0,
		"water animation preserves cells, hazard shapes and surface height")
	p.respawn_at(Vector2(5130,480))
	await frames(20)
	Input.action_press("move_right")
	await frames(105)
	Input.action_release("move_right")
	check(p.position.x > 5350 and p.is_on_floor() and absf(p.position.y-480)<1,
		"player walks underneath both elevated nest branches without jumping")
	print("world pass check %s" % ("passed" if failures == 0 else "FAILED"))
	preload("res://tools/test_cleanup.gd").finish(self, 0 if failures == 0 else 1)
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok: failures += 1
