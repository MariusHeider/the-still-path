extends Node2D

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

	# Parent visibility decides whether controls are shown. Keep each button
	# itself on ALWAYS so Safari cannot hide it through touchscreen-only mode.
	for child in get_children():
		if child is TouchScreenButton:
			child.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
