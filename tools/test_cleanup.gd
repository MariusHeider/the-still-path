extends RefCounted
## Allow queued frees and the audio server to release active playback before exit.
static func finish(tree: SceneTree, code: int) -> void:
	for child in tree.root.get_children():
		child.queue_free()
	await tree.create_timer(0.3).timeout
	tree.quit(code)
