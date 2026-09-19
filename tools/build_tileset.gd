extends SceneTree
## Builds the TileSet resource from the generated sheet, with collision and
## terrain autotiling wired up, and saves it to disk.
##
## Written as a script rather than by hand because the .tres format for terrain
## peering bits is fiddly and easy to get subtly wrong. Letting the engine write
## the file means it is correct by construction.
##
## Run:  godot --headless --path . --script res://tools/build_tileset.gd

const SHEET := "res://Assets/Tileset/tileset_generated.png"
const OUT := "res://Assets/Tileset/terrain.tres"
const TILE := Vector2i(32, 32)
const COLS := 8

# Tile indices in the sheet, matching tools/make_tileset.py.
const TERRAIN_COUNT := 16
const BLOCK := 16
const PILLAR_TOP := 17
const PILLAR_BASE := 19
const STEP := 20
const DECOR_FIRST := 21
const DECOR_LAST := 23

# Neighbour bits, same encoding the generator used.
const BIT_N := 1
const BIT_E := 2
const BIT_S := 4
const BIT_W := 8


func _initialize() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = TILE

	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)

	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)
	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0, 0, "earth")
	tile_set.set_terrain_color(0, 0, Color("b88f63"))

	var source := TileSetAtlasSource.new()
	source.texture = load(SHEET)
	source.texture_region_size = TILE
	# Register the source before creating any tiles. TileData only learns which
	# physics layers exist once its source belongs to a TileSet, so adding tiles
	# first leaves every collision polygon silently dropped.
	tile_set.add_source(source, 0)

	var full_square := PackedVector2Array([
		Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16),
	])
	# Pillars are narrower than their tile, so their collision is inset to match
	# what you can actually see.
	var pillar_column := PackedVector2Array([
		Vector2(-12, -16), Vector2(12, -16), Vector2(12, 16), Vector2(-12, 16),
	])
	# The step is drawn as two levels; its collision follows the same profile.
	var step_profile := PackedVector2Array([
		Vector2(-16, 4), Vector2(-2, 4), Vector2(-2, -6),
		Vector2(16, -6), Vector2(16, 16), Vector2(-16, 16),
	])

	for index in TERRAIN_COUNT:
		var data := _make_tile(source, index, full_square)
		data.terrain_set = 0
		data.terrain = 0
		# A peering bit of 0 means "earth is there", -1 means "nothing is there".
		# That is what lets set_cells_terrain_connect pick the right edge tile.
		data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE,
			0 if index & BIT_N else -1)
		data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
			0 if index & BIT_E else -1)
		data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
			0 if index & BIT_S else -1)
		data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE,
			0 if index & BIT_W else -1)

	_make_tile(source, BLOCK, full_square)
	for index in range(PILLAR_TOP, PILLAR_BASE + 1):
		_make_tile(source, index, pillar_column)
	_make_tile(source, STEP, step_profile)

	# Decoration is scenery only, so it gets no collision at all.
	for index in range(DECOR_FIRST, DECOR_LAST + 1):
		_make_tile(source, index, PackedVector2Array())

	var err := ResourceSaver.save(tile_set, OUT)
	if err != OK:
		push_error("could not save %s (error %d)" % [OUT, err])
		quit(1)
		return
	print("wrote %s" % OUT)
	print("  %d terrain tiles, %d solid props, %d decorations"
		% [TERRAIN_COUNT, 1 + (PILLAR_BASE - PILLAR_TOP + 1) + 1,
		   DECOR_LAST - DECOR_FIRST + 1])
	quit()


func _make_tile(source: TileSetAtlasSource, index: int,
		collision: PackedVector2Array) -> TileData:
	var coord := Vector2i(index % COLS, index / COLS)
	source.create_tile(coord)
	var data := source.get_tile_data(coord, 0)
	if not collision.is_empty():
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, collision)
	return data
