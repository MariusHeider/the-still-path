extends SceneTree
## Builds the TileSet resource from the generated sheet, with collision and
## terrain autotiling wired up, and saves it to disk.
##
## Written as a script rather than by hand because the .tres format for terrain
## peering bits is fiddly and easy to get subtly wrong. Letting the engine write
## the file means it is correct by construction.
##
## Must stay in step with the sheet layout in tools/make_tileset.py.
##
## Run:  godot --headless --path . --script res://tools/build_tileset.gd

const SHEET := "res://Assets/Tileset/tileset_generated.png"
const OUT := "res://Assets/Tileset/terrain.tres"
const TILE := Vector2i(32, 32)

# Neighbour bits, same encoding the generator uses.
const N := 1
const E := 2
const S := 4
const W := 8

## Which neighbour combination sits at each slot of a terrain's 4x4 block.
## Reading across: the nine-slice, then the vertical strip; last row is the
## horizontal strip and the lone isolated tile.
const BLOCK_BITS := [
	[E | S,     E | S | W,     S | W,     S],
	[N | E | S, N | E | S | W, N | S | W, N | S],
	[N | E,     N | E | W,     N | W,     N],
	[E,         E | W,         W,         0],
]

## name, column where the 4x4 block starts, colour shown in the terrain picker.
const TERRAINS := [
	["earth", 0, "b88f63"],
	["rock", 4, "8a8078"],
	["snow", 8, "dce4ee"],
]

const PROPS_ROW := 4
## Extra interior tiles, at each terrain's own columns. They carry the same
## peering bits as the centre tile, so the autotiler treats them as
## interchangeable with it and picks among them at random. Without these, a
## large mass shows an obvious 32px grid of one repeated texture.
const FILL_ROW := 5
const FILL_VARIANTS := 3


func _initialize() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = TILE

	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)

	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)
	for i in TERRAINS.size():
		tile_set.add_terrain(0)
		tile_set.set_terrain_name(0, i, TERRAINS[i][0])
		tile_set.set_terrain_color(0, i, Color(TERRAINS[i][2]))

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
	# Big enough to stand on, low enough not to snag you while walking past.
	var boulder := PackedVector2Array([
		Vector2(-12, -4), Vector2(12, -4), Vector2(12, 16), Vector2(-12, 16),
	])

	for terrain_index in TERRAINS.size():
		var origin_column: int = TERRAINS[terrain_index][1]
		for row in 4:
			for column in 4:
				_make_terrain_tile(source, Vector2i(origin_column + column, row),
					BLOCK_BITS[row][column], terrain_index, full_square)
		for variant in FILL_VARIANTS:
			_make_terrain_tile(source, Vector2i(origin_column + variant, FILL_ROW),
				N | E | S | W, terrain_index, full_square)

	# Props row. Everything after the boulder is scenery and gets no collision.
	var prop_shapes := [
		full_square,    # 0 cut stone block
		pillar_column,  # 1 pillar top
		pillar_column,  # 2 pillar middle
		pillar_column,  # 3 pillar base
		step_profile,   # 4 step
		boulder,        # 5 large boulder
	]
	for column in 12:
		var shape: PackedVector2Array = (prop_shapes[column] if column < prop_shapes.size()
			else PackedVector2Array())
		_make_tile(source, Vector2i(column, PROPS_ROW), shape)

	var err := ResourceSaver.save(tile_set, OUT)
	if err != OK:
		push_error("could not save %s (error %d)" % [OUT, err])
		quit(1)
		return
	print("wrote %s" % OUT)
	print("  %d terrains x 16 tiles, 12 props (%d solid)"
		% [TERRAINS.size(), prop_shapes.size()])
	quit()


func _make_terrain_tile(source: TileSetAtlasSource, coord: Vector2i, bits: int,
		terrain_index: int, collision: PackedVector2Array) -> void:
	var data := _make_tile(source, coord, collision)
	data.terrain_set = 0
	data.terrain = terrain_index
	# A peering bit set to this terrain means "more of me is there"; -1 means
	# "nothing of mine is there". That is what lets set_cells_terrain_connect
	# pick the right edge tile.
	data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE,
		terrain_index if bits & N else -1)
	data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
		terrain_index if bits & E else -1)
	data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
		terrain_index if bits & S else -1)
	data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE,
		terrain_index if bits & W else -1)


func _make_tile(source: TileSetAtlasSource, coord: Vector2i,
		collision: PackedVector2Array) -> TileData:
	source.create_tile(coord)
	var data := source.get_tile_data(coord, 0)
	if not collision.is_empty():
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, collision)
	return data
