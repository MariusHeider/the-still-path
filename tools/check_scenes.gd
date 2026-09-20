extends SceneTree
func _initialize() -> void:
	for path in ["res://Scenes/title.tscn", "res://Scenes/ending.tscn",
			"res://Scenes/focus_summit.tscn", "res://Scenes/playground.tscn"]:
		var packed: PackedScene = load(path)
		var node := packed.instantiate()
		root.add_child(node)
		print("  ok  %s -> %s" % [path, node.name])
		node.queue_free()
	quit()
