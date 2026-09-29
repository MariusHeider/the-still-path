extends Node2D

var _interact_label: Label = null
var _level: Node = null


func _ready() -> void:
	var touch_available := DisplayServer.is_touchscreen_available()

	# Safari/iOS can fail Godot's automatic touchscreen visibility check in a
	# web export. Use the browser's own touch capability as a fallback.
	if OS.has_feature("web"):
		var browser_touch = JavaScriptBridge.eval(
			"(('ontouchstart' in window) || (navigator.maxTouchPoints > 0))",
			true
		)
		if browser_touch is bool:
			touch_available = touch_available or browser_touch

	visible = touch_available
	_level = get_parent().get_parent()
	_interact_label = get_node_or_null("Interact/Label") as Label

	# Parent visibility decides whether controls are shown. Keep each button
	# itself on ALWAYS so Safari cannot hide it through touchscreen-only mode.
	for child in get_children():
		if child is TouchScreenButton:
			child.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS

	_update_interact_label()


func _process(_delta: float) -> void:
	if not visible:
		return
	_update_interact_label()


func _update_interact_label() -> void:
	if _interact_label == null or _level == null:
		return

	var player = _level.get("player")
	if player == null:
		_interact_label.text = "SIT"
		return

	var should_act := false

	# While seated, the same button either stands up or commits the awareness
	# interaction/teleport, so SIT would be misleading.
	if player.is_seated:
		should_act = true
	elif player.riding != null:
		should_act = player.riding.can_interact(player)
	else:
		should_act = player.current_interactable() != null

	_interact_label.text = "ACT" if should_act else "SIT"
