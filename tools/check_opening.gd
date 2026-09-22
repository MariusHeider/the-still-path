extends SceneTree
var _finishing := false
## The controls wait for a second deliberate input; principle then starts level.
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var title = load("res://Scenes/title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await process_frame
	_check(title.get_node("TitleStage").visible and not title.get_node("ControlsStage").visible
		and not title.get_node("Principle").visible, "title stage shows only title and prompt")
	_check(title.menu_music.playing and title.menu_music.volume_db == title.menu_volume_db, "menu music begins quietly on title")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	title._input(key)
	await _frames(70)
	_check(title.get_node("ControlsStage").visible and not title.get_node("TitleStage").visible,
		"first input opens separate controls stage")
	var table: HBoxContainer = title.get_node("ControlsStage/Table")
	_check(table.alignment == BoxContainer.ALIGNMENT_CENTER
		and table.get_node("Actions").get_child_count() == 4
		and table.get_node("Keys").get_child_count() == 4
		and table.get_node("Divider") is VSeparator,
		"controls use centered layout columns with four aligned rows and a separator")
	key.echo = true
	title._input(key)
	await _frames(300)
	_check(current_scene == title and title.stage == title.Stage.CONTROLS
		and not title.get_node("Principle").visible, "controls wait indefinitely; held-key repeat does not advance")
	key.echo = false
	title._input(key)
	await _frames(90)
	_check(title.stage == title.Stage.PREMISE and title.get_node("PremiseStage").visible
		and not title.get_node("ControlsStage").visible, "second input opens premise")
	_check(title.get_node("PremiseStage/Sentence").text == "A young seeker sets out for a shrine in the mountains.\n\nThe path ahead will ask for more than movement.", "premise text matches")
	key.echo = true
	title._input(key)
	await _frames(300)
	_check(title.stage == title.Stage.PREMISE and title.menu_music.playing,
		"premise waits for deliberate input with continuous music")
	key.echo = false
	title._input(key)
	await _frames(90)
	_check(title.stage == title.Stage.INVOLVEMENT and title.get_node("InvolvementStage").visible
		and not title.get_node("ControlsStage").visible, "third input opens separate involvement stage")
	key.echo = true
	title._input(key)
	await _frames(300)
	_check(title.stage == title.Stage.INVOLVEMENT and title.menu_music.playing,
		"involvement waits for deliberate input with uninterrupted music")
	key.echo = false
	title._input(key)
	await _frames(90)
	_check(title.menu_music.volume_db < title.menu_volume_db, "menu music fades as principle appears")
	_check(title.get_node("Principle").visible and not title.get_node("ControlsStage").visible,
		"fourth deliberate input shows only first principle")
	var level = load("res://Scenes/level.tscn").instantiate()
	var reference: Label = level.get_node("HUD/Message")
	var principle: Label = title.get_node("Principle")
	_check(principle.position == reference.position and principle.size == reference.size
		and principle.get_theme_font_size("font_size") == reference.get_theme_font_size("font_size")
		and principle.get_theme_constant("outline_size") == reference.get_theme_constant("outline_size"),
		"opening principle matches level message placement and typography")
	level.free()
	await _frames(240)
	_check(current_scene is LevelMap, "principle fades and automatically starts level")
	print("opening check %s" % ("passed" if _failures == 0 else "FAILED"))
	_finish(0 if _failures == 0 else 1)


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
