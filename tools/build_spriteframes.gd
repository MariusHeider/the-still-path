extends SceneTree
## Builds the SpriteFrames resource for the seeker from the character sheet.
##
## Written as a script for the same reason as the tileset: a .tres holding fifty
## AtlasTextures is miserable to maintain by hand, and this way re-slicing after
## an art update is one command instead of an afternoon.
##
## SHEET: 56x56 frames, 9 columns x 6 rows.
##   row 0  turnaround reference, not an animation (front / side / side / back)
##   row 1  jump cycle: 2 crouch, 3 launch, 4 rise, 5 fall, 6 reach, 7-8 land
##   row 2  walk cycle, side view
##   row 3  sitting cross-legged, FRONT view -- saved for the summit
##   row 4  kneeling, SIDE view -- the in-level sit, matches the camera
##   row 5  idle, side view
##
## Run:  godot --headless --path . --script res://tools/build_spriteframes.gd

const SHEET := "res://Assets/Character/Character_Spritesheet.png"
const OUT := "res://Assets/Character/seeker_frames.tres"
const FRAME := 56

## The elephant sheet: 108x108, 9 columns x 3 rows. Row 0 is a turnaround
## reference, not an animation. Both cycles face right.
const ELEPHANT_SHEET := "res://Assets/Creatures/Elephant_Spritesheet.png"
const ELEPHANT_OUT := "res://Assets/Creatures/elephant_frames.tres"
const ELEPHANT_FRAME := 108
const ELEPHANT_ANIMATIONS := [
	["idle", 1, 0, 8, 7.0, true],
	["walk", 2, 0, 7, 9.0, true],
]

## name, row, first column, last column (inclusive), fps, loop
const ANIMATIONS := [
	["idle", 5, 0, 4, 3.0, true],
	["walk", 2, 0, 5, 10.0, true],
	["jump", 1, 3, 4, 12.0, false],
	["fall", 1, 5, 5, 6.0, true],
	["land", 1, 7, 8, 14.0, false],
	# Lowering into the kneel, then holding it. The player sees the transition
	# once and then a slow breathing loop.
	["sit_down", 4, 0, 3, 12.0, false],
	# Held poses do not loop: the last frame stays on screen. Looping them makes
	# the seeker visibly restart the settling motion over and over.
	["sit", 4, 4, 8, 3.0, false],
	# Front-facing meditation, for the one moment it is worth breaking camera.
	["meditate_down", 3, 0, 3, 12.0, false],
	["meditate", 3, 4, 8, 3.0, false],
]


func _initialize() -> void:
	var sheet: Texture2D = load(SHEET)
	if sheet == null:
		push_error("could not load %s" % SHEET)
		quit(1)
		return

	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	for entry in ANIMATIONS:
		var name: String = entry[0]
		var row: int = entry[1]
		var first: int = entry[2]
		var last: int = entry[3]
		frames.add_animation(name)
		frames.set_animation_speed(name, entry[4])
		frames.set_animation_loop(name, entry[5])
		for column in range(first, last + 1):
			var region := AtlasTexture.new()
			region.atlas = sheet
			region.region = Rect2(column * FRAME, row * FRAME, FRAME, FRAME)
			frames.add_frame(name, region)
		print("  %-14s row %d, frames %d-%d (%d)"
			% [name, row, first, last, last - first + 1])

	var err := ResourceSaver.save(frames, OUT)
	if err != OK:
		push_error("could not save %s (error %d)" % [OUT, err])
		quit(1)
		return
	print("wrote %s" % OUT)

	if not _build(ELEPHANT_SHEET, ELEPHANT_OUT, ELEPHANT_FRAME, ELEPHANT_ANIMATIONS):
		quit(1)
		return
	quit()


func _build(sheet_path: String, out_path: String, size: int,
		animations: Array) -> bool:
	var sheet: Texture2D = load(sheet_path)
	if sheet == null:
		push_error("could not load %s" % sheet_path)
		return false
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for entry in animations:
		var name: String = entry[0]
		frames.add_animation(name)
		frames.set_animation_speed(name, entry[4])
		frames.set_animation_loop(name, entry[5])
		for column in range(entry[2], entry[3] + 1):
			var region := AtlasTexture.new()
			region.atlas = sheet
			region.region = Rect2(column * size, entry[1] * size, size, size)
			frames.add_frame(name, region)
		print("  %-14s row %d, frames %d-%d" % [name, entry[1], entry[2], entry[3]])
	var save_err := ResourceSaver.save(frames, out_path)
	if save_err != OK:
		push_error("could not save %s (error %d)" % [out_path, save_err])
		return false
	print("wrote %s" % out_path)
	return true
