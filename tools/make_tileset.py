"""Generate 32x32 terrain tilesets in a warm, dry, South-Indian palette.

This is a *materials* generator. It draws stone, earth, snow and dry grass,
which are texture-and-lighting problems that code handles well.

SHEET LAYOUT (12 columns x 5 rows, 384x160 px)

Each terrain occupies a readable 4x4 block. Columns 0-2 are the usual
nine-slice; column 3 holds the one-tile-wide vertical strip; row 3 holds the
one-tile-tall horizontal strip and the isolated single tile:

      col0        col1       col2        col3
  +-----------+----------+-----------+-----------+
  | top-left  | top-mid  | top-right | vert top  |
  | mid-left  | centre   | mid-right | vert mid  |
  | bot-left  | bot-mid  | bot-right | vert bot  |
  | horiz L   | horiz M  | horiz R   | single    |
  +-----------+----------+-----------+-----------+

  cols 0-3   EARTH  dry soil with a grass crown
  cols 4-7   ROCK   bare mountain granite, for the climb at the end
  cols 8-11  SNOW   paint it over rock for the summit
  row 4      props and decoration
  row 5      three extra interior fill tiles per terrain, at the same columns
             as that terrain's block. A single interior tile stamped across a
             large mass shows an obvious 32px grid; Godot picks at random among
             tiles matching the same pattern, so variants break it up.

Usage: python tools/make_tileset.py
"""
import random
from PIL import Image

TILE = 32
COLS, ROWS = 12, 6
SEED = 20260919

# --- Palettes ---------------------------------------------------------------
# Each ramp is deliberately low-contrast between neighbouring shades. Wide gaps
# make any noise read as gravel static rather than as a surface.
SAND = [(226, 199, 160), (203, 171, 128), (178, 143, 103), (146, 114, 80), (108, 82, 56)]
GRASS = [(190, 188, 118), (152, 152, 84), (112, 115, 58), (78, 80, 40)]
ROCK = [(176, 170, 162), (142, 135, 126), (108, 102, 94), (78, 73, 67), (52, 48, 44)]
SNOW = [(250, 250, 252), (230, 234, 242), (204, 212, 226), (172, 182, 200), (142, 152, 172)]

DARK_OUTLINE = (46, 33, 24)
ROCK_OUTLINE = (34, 31, 29)
# Snow never gets a black outline -- it reads as dirt. Cold blue-grey instead.
SNOW_OUTLINE = (104, 116, 138)
CLEAR = (0, 0, 0, 0)

# Neighbour bits. Set = there is a neighbouring tile there, so that edge is
# interior and gets no outline.
N, E, S, W = 1, 2, 4, 8

# Which neighbour combination belongs at each slot of the 4x4 block above.
BLOCK_BITS = [
	[E | S,     E | S | W,     S | W,     S],          # top row, then vert top
	[N | E | S, N | E | S | W, N | S | W, N | S],      # middle row, vert middle
	[N | E,     N | E | W,     N | W,     N],          # bottom row, vert bottom
	[E,         E | W,         W,         0],          # horizontal strip, single
]

PROPS_ROW = 4
FILL_ROW = 5
FILL_VARIANTS = 3

TERRAINS = {
	"earth": {
		"origin": (0, 0),
		"body": SAND, "lo": 2, "hi": 3, "threshold": 0.72,
		"outline": DARK_OUTLINE,
		"grit_dark": 6, "grit_light": 4,
		"crown": GRASS,          # grass band along any exposed top edge
		"subsoil": 1,            # lighter earth just beneath the grass
		"strata": 0,
	},
	"rock": {
		"origin": (4, 0),
		"body": ROCK, "lo": 1, "hi": 2, "threshold": 0.62,
		"outline": ROCK_OUTLINE,
		"grit_dark": 6, "grit_light": 5,
		"crown": None,
		"rim": 0,                # sun-catching lighter rows along an exposed top
		"strata": 4,             # short dark seams suggesting layered stone
	},
	"snow": {
		"origin": (8, 0),
		"body": SNOW, "lo": 0, "hi": 1, "threshold": 0.70,
		"outline": SNOW_OUTLINE,
		# No dark grit at all: a dark speck on snow reads as dirt, not shading.
		"grit_dark": 0, "grit_light": 0,
		"crown": None,
		"rim": 0,
		"strata": 0,
	},
}


def shade(c, f):
	return tuple(max(0, min(255, int(round(v * f)))) for v in c[:3])


def noise_field(rng, block=2):
	"""Value noise held constant over `block`-pixel squares.

	Per-pixel randomness reads as television static at this scale. Holding it
	over 2x2 blocks gives the clumpy look that hand-drawn pixel art has.
	"""
	cells = -(-TILE // block)
	grid = [[rng.random() for _ in range(cells)] for _ in range(cells)]
	return [[grid[y // block][x // block] for x in range(TILE)] for y in range(TILE)]


def terrain_tile(bits, cfg, rng):
	"""One terrain tile. `bits` says which sides have neighbours."""
	body = cfg["body"]
	outline = cfg["outline"]
	nz = noise_field(rng)

	# Two adjacent shades only. No per-tile vertical gradient: that bands
	# visibly every 32px once tiles are stacked, because the gradient restarts
	# at every tile boundary.
	px = [[body[cfg["lo"]] if nz[y][x] < cfg["threshold"] else body[cfg["hi"]]
		   for x in range(TILE)] for y in range(TILE)]

	for _ in range(cfg["grit_dark"]):
		px[rng.randrange(TILE)][rng.randrange(TILE)] = body[4]
	for _ in range(cfg["grit_light"]):
		px[rng.randrange(TILE)][rng.randrange(TILE)] = body[0]

	# Short dark seams, so bare stone looks bedded rather than poured.
	for _ in range(cfg["strata"]):
		sy = rng.randrange(4, TILE - 4)
		sx = rng.randrange(0, TILE - 8)
		for i in range(rng.randint(5, 13)):
			x = sx + i
			y = sy + (i // 6) * rng.choice((0, 1))
			if 0 <= x < TILE and 0 <= y < TILE:
				px[y][x] = body[3]

	if not bits & N:
		if cfg["crown"] is not None:
			crown = cfg["crown"]
			# Exposed top: a band of dry grass with an irregular lower edge, and
			# lighter earth just beneath it where the sun would reach.
			for x in range(TILE):
				h = 6 + rng.randint(-2, 3)
				for y in range(h, min(TILE, h + 3)):
					px[y][x] = body[cfg["subsoil"]] if nz[y][x] < 0.6 else body[cfg["lo"]]
				for y in range(h):
					px[y][x] = crown[1 if nz[y][x] < 0.45 else 2]
				px[h - 1][x] = crown[3]
				px[0][x] = crown[0] if (x + rng.randint(0, 1)) % 3 else crown[1]
		else:
			# Bare stone and snow just catch more light along the top edge.
			for x in range(TILE):
				depth = 2 + (1 if nz[0][x] < 0.4 else 0)
				for y in range(depth):
					px[y][x] = body[cfg["rim"]]

	# Exposed faces get an outline and a bevel so tiles read as solid volumes.
	if not bits & W:
		for y in range(TILE):
			px[y][0] = outline
			px[y][1] = shade(px[y][1], 0.72)
	if not bits & E:
		for y in range(TILE):
			px[y][TILE - 1] = outline
			px[y][TILE - 2] = shade(px[y][TILE - 2], 0.78)
	if not bits & S:
		for x in range(TILE):
			px[TILE - 1][x] = outline
			px[TILE - 2][x] = shade(px[TILE - 2][x], 0.70)
	return px


# --- Props ------------------------------------------------------------------

def block_tile(rng):
	"""A cut stone block: flat face, lit top-left, outlined all round."""
	nz = noise_field(rng)
	px = [[ROCK[1 if nz[y][x] < 0.5 else 2] for x in range(TILE)] for y in range(TILE)]
	for _ in range(10):
		px[rng.randrange(2, TILE - 2)][rng.randrange(2, TILE - 2)] = ROCK[3]
	for i in range(1, TILE - 1):
		px[1][i] = ROCK[0]
		px[i][1] = ROCK[0]
		px[TILE - 2][i] = ROCK[3]
		px[i][TILE - 2] = ROCK[3]
	for i in range(TILE):
		px[0][i] = px[TILE - 1][i] = px[i][0] = px[i][TILE - 1] = ROCK_OUTLINE
	return px


def pillar_tile(rng, part):
	"""Pillar segment. Plain fluting only -- ornament needs an artist."""
	nz = noise_field(rng)
	px = [[CLEAR] * TILE for _ in range(TILE)]
	inset = 5 if part == "mid" else 3
	for y in range(TILE):
		for x in range(inset, TILE - inset):
			t = (x - inset) / max(1, (TILE - 2 * inset - 1))
			# Cylindrical shading: lit left of centre, falling away to the right.
			lit = 0 if t < 0.22 else (1 if t < 0.55 else (2 if t < 0.82 else 3))
			if nz[y][x] > 0.82 and lit < 3:
				lit += 1
			px[y][x] = ROCK[lit]
		px[y][inset] = ROCK_OUTLINE
		px[y][TILE - inset - 1] = ROCK_OUTLINE

	if part in ("top", "base"):
		band = range(0, 7) if part == "top" else range(TILE - 7, TILE)
		for y in band:
			for x in range(2, TILE - 2):
				t = (x - 2) / (TILE - 5)
				lit = 0 if t < 0.22 else (1 if t < 0.55 else (2 if t < 0.82 else 3))
				px[y][x] = ROCK[lit]
			px[y][2] = px[y][TILE - 3] = ROCK_OUTLINE
		edge = 6 if part == "top" else TILE - 7
		for x in range(2, TILE - 2):
			px[edge][x] = ROCK_OUTLINE
	return px


def step_tile(rng):
	"""Two-level step, for stairs cut into the hillside."""
	px = [[CLEAR] * TILE for _ in range(TILE)]
	nz = noise_field(rng)
	for y in range(TILE):
		for x in range(TILE):
			if y >= (10 if x >= 14 else 20):
				px[y][x] = SAND[1 if nz[y][x] < 0.4 else 2]
	for x in range(14, TILE):
		px[10][x] = SAND[0]
	for x in range(0, 14):
		px[20][x] = SAND[0]
	for y in range(TILE):
		for x in range(TILE):
			if px[y][x] == CLEAR:
				continue
			if (y == TILE - 1 or x == 0 or x == TILE - 1
					or px[y - 1][x] == CLEAR or px[y][x - 1] == CLEAR):
				px[y][x] = DARK_OUTLINE
	return px


def _blob(px, cx, cy, rx, ry, palette, outline):
	"""A shaded lump. Light falls from the upper left."""
	for y in range(max(0, cy - ry - 1), min(TILE, cy + ry + 2)):
		for x in range(max(0, cx - rx - 1), min(TILE, cx + rx + 2)):
			d = ((x - cx) / float(rx)) ** 2 + ((y - cy) / float(ry)) ** 2
			if d > 1.18:
				continue
			if d > 0.86:
				px[y][x] = outline
				continue
			lit = (x - cx) / float(rx) * 0.6 + (y - cy) / float(ry) * 0.8
			px[y][x] = palette[0] if lit < -0.55 else (
				palette[1] if lit < 0.15 else palette[2])


def boulder_tile(rng, size):
	"""Loose mountain stone. `size` picks one big lump or a few small ones."""
	px = [[CLEAR] * TILE for _ in range(TILE)]
	if size == "large":
		_blob(px, 16, 21, 12, 9, ROCK, ROCK_OUTLINE)
		_blob(px, 24, 25, 6, 5, ROCK, ROCK_OUTLINE)
	elif size == "pair":
		_blob(px, 11, 23, 7, 6, ROCK, ROCK_OUTLINE)
		_blob(px, 22, 26, 8, 5, ROCK, ROCK_OUTLINE)
	else:
		for _ in range(4):
			_blob(px, rng.randrange(5, TILE - 5), rng.randrange(22, TILE - 3),
				  rng.randint(2, 4), rng.randint(2, 3), ROCK, ROCK_OUTLINE)
	return px


def pebble_tile(rng):
	px = [[CLEAR] * TILE for _ in range(TILE)]
	for _ in range(12):
		x, y = rng.randrange(1, TILE - 2), rng.randrange(20, TILE - 1)
		px[y][x] = SAND[3]
		if rng.random() < 0.5:
			px[y][x + 1] = SAND[2]
	return px


def grass_tile(rng, height, palette):
	"""A tuft of blades rooted at the bottom of the tile."""
	px = [[CLEAR] * TILE for _ in range(TILE)]
	for _ in range(16 if height < 12 else 13):
		bx = rng.randrange(3, TILE - 3)
		h = rng.randint(height - 3, height + 3)
		lean = rng.choice((-1, 0, 0, 1))
		for i in range(h):
			x = bx + (i * lean) // 3
			y = TILE - 1 - i
			if 0 <= x < TILE and 0 <= y < TILE:
				px[y][x] = palette[1] if i > h - 3 else palette[2]
		# A seed head on the taller blades gives them a silhouette.
		if height >= 12 and rng.random() < 0.5:
			tip = TILE - 1 - h
			for dy in range(-2, 1):
				if 0 <= tip + dy < TILE:
					px[tip + dy][min(TILE - 1, bx + (h * lean) // 3)] = palette[0]
	return px


def main() -> None:
	rng = random.Random(SEED)
	sheet = Image.new("RGBA", (COLS * TILE, ROWS * TILE), CLEAR)

	def paste(px, col, row):
		ox, oy = col * TILE, row * TILE
		for y in range(TILE):
			for x in range(TILE):
				c = px[y][x]
				sheet.putpixel((ox + x, oy + y), c if len(c) == 4 else c + (255,))

	for name, cfg in TERRAINS.items():
		bx, by = cfg["origin"]
		for row in range(4):
			for col in range(4):
				paste(terrain_tile(BLOCK_BITS[row][col], cfg, rng), bx + col, by + row)
		# Extra interior tiles. Same neighbour situation as the centre tile, so
		# the autotiler treats them as interchangeable with it.
		for variant in range(FILL_VARIANTS):
			paste(terrain_tile(N | E | S | W, cfg, rng), bx + variant, FILL_ROW)
		print(f"  {name:6s} 4x4 block at column {bx}, "
			  f"{FILL_VARIANTS} fill variants on row {FILL_ROW}")

	props = [
		("stone block", block_tile(rng)),
		("pillar top", pillar_tile(rng, "top")),
		("pillar mid", pillar_tile(rng, "mid")),
		("pillar base", pillar_tile(rng, "base")),
		("step", step_tile(rng)),
		("boulder large", boulder_tile(rng, "large")),
		("boulder pair", boulder_tile(rng, "pair")),
		("loose stones", boulder_tile(rng, "small")),
		("pebbles", pebble_tile(rng)),
		("grass short", grass_tile(rng, 8, GRASS)),
		("grass tall", grass_tile(rng, 15, GRASS)),
		("dry reeds", grass_tile(rng, 19, [SAND[0], SAND[1], SAND[2], SAND[3]])),
	]
	for i, (label, px) in enumerate(props):
		paste(px, i, PROPS_ROW)

	out = "Assets/Tileset/tileset_generated.png"
	sheet.save(out)
	print(f"\nwrote {out}  ({COLS * TILE}x{ROWS * TILE})")
	print("  row 4 props: " + ", ".join(f"{i}={n}" for i, (n, _) in enumerate(props)))


if __name__ == "__main__":
	main()
