extends SceneTree
var _finishing := false
func _initialize() -> void:
	for path in ["res://Scenes/title.tscn", "res://Scenes/ending.tscn",
			"res://Scenes/focus_summit.tscn", "res://Scenes/playground.tscn",
			"res://Scenes/nesting_tree.tscn", "res://Scenes/tree_branch.tscn"]:
		var packed: PackedScene = load(path)
		var node := packed.instantiate()
		root.add_child(node)
		print("  ok  %s -> %s" % [path, node.name])
		node.queue_free()
	_finish()

func _finish(code := 0) -> void:
	if _finishing: return
	_finishing = true
	preload("res://tools/test_cleanup.gd").finish(self, code)
