"""Generate a 32x32 terrain tileset in a warm, dry, South-Indian palette.

This is a *materials* generator. It draws stone, earth and dry grass, which are
texture-and-lighting problems that code handles well. It deliberately does not
attempt carved pillars with ornament, lamps, lotuses or anything whose appeal
depends on silhouette -- that needs an artist and should come from pixellab.

Layout of the output sheet (8 columns x 3 rows, 256x96 px):
  row 0-1  16 ground tiles, one per combination of which sides have a
           neighbour. Feeds the "match sides" terrain autotiling in Godot, so
           you paint a shape and the edges resolve themselves.
  row 2    cut stone block, pillar top/middle/base, step, and three decorative
           tiles with no collision.

Usage: python tools/make_tileset.py
"""
import random
from PIL import Image

TILE = 32
COLS, ROWS = 8, 3
SEED = 20260919

# --- Palette ---------------------------------------------------------------
# Warm sandstone for earth, dry-season olive for growth, warm grey granite for
# cut stone. Everything shares one hue family so mixed tiles still read as a
# single place.
# The sand ramp is deliberately low-contrast. Wide gaps between neighbouring
# shades make any noise read as gravel static rather than as a surface.
SAND = [(226, 199, 160), (203, 171, 128), (178, 143, 103), (146, 114, 80), (108, 82, 56)]
# Dry season, not a European meadow: pushed toward khaki and desaturated.
GRASS = [(190, 188, 118), (152, 152, 84), (112, 115, 58), (78, 80, 40)]
GRAN = [(194, 180, 160), (155, 140, 120), (116, 105, 90), (79, 70, 60)]
OUTLINE = (46, 33, 24)
CLEAR = (0, 0, 0, 0)

# Side bits. Set = there is a neighbouring tile there, so that edge is interior.
N, E, S, W = 1, 2, 4, 8


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


def ground_tile(bits, rng):
    """One earth tile. `bits` says which sides have neighbours."""
    nz = noise_field(rng)
    px = [[None] * TILE for _ in range(TILE)]

    # Two adjacent shades only, weighted toward the lighter one. No per-tile
    # vertical gradient: that bands visibly every 32px once tiles are stacked,
    # because the gradient restarts at every tile boundary.
    for y in range(TILE):
        for x in range(TILE):
            px[y][x] = SAND[2] if nz[y][x] < 0.72 else SAND[3]

    # Sparse grit. Six pits and four grains per tile, not a field of static.
    for _ in range(6):
        px[rng.randrange(TILE)][rng.randrange(TILE)] = SAND[4]
    for _ in range(4):
        px[rng.randrange(TILE)][rng.randrange(TILE)] = SAND[1]

    if not bits & N:
        # Exposed top: a band of dry grass with an irregular lower boundary,
        # and lighter earth just beneath it where the sun would reach.
        for x in range(TILE):
            h = 6 + rng.randint(-2, 3)
            for y in range(h, min(TILE, h + 3)):
                px[y][x] = SAND[1] if nz[y][x] < 0.6 else SAND[2]
            for y in range(h):
                px[y][x] = GRASS[1 if nz[y][x] < 0.45 else 2]
            px[h - 1][x] = GRASS[3]
            px[0][x] = GRASS[0] if (x + rng.randint(0, 1)) % 3 else GRASS[1]

    # Exposed faces get an outline and a bevel so tiles read as solid volumes.
    if not bits & W:
        for y in range(TILE):
            px[y][0] = OUTLINE
            px[y][1] = shade(px[y][1], 0.72)
    if not bits & E:
        for y in range(TILE):
            px[y][TILE - 1] = OUTLINE
            px[y][TILE - 2] = shade(px[y][TILE - 2], 0.78)
    if not bits & S:
        for x in range(TILE):
            px[TILE - 1][x] = OUTLINE
            px[TILE - 2][x] = shade(px[TILE - 2][x], 0.70)
    return px


def block_tile(rng, palette=GRAN):
    """A cut stone block: flat face, lit top-left, outlined all round."""
    nz = noise_field(rng)
    px = [[palette[1 if nz[y][x] < 0.5 else 2] for x in range(TILE)] for y in range(TILE)]
    for _ in range(10):
        px[rng.randrange(2, TILE - 2)][rng.randrange(2, TILE - 2)] = palette[3]
    for i in range(1, TILE - 1):
        px[1][i] = palette[0]
        px[i][1] = palette[0]
        px[TILE - 2][i] = palette[3]
        px[i][TILE - 2] = palette[3]
    for i in range(TILE):
        px[0][i] = px[TILE - 1][i] = px[i][0] = px[i][TILE - 1] = OUTLINE
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
            px[y][x] = GRAN[lit]
        px[y][inset] = OUTLINE
        px[y][TILE - inset - 1] = OUTLINE

    if part in ("top", "base"):
        # Flared capital or footing: a wider band across one end.
        band = range(0, 7) if part == "top" else range(TILE - 7, TILE)
        for y in band:
            for x in range(2, TILE - 2):
                t = (x - 2) / (TILE - 5)
                lit = 0 if t < 0.22 else (1 if t < 0.55 else (2 if t < 0.82 else 3))
                px[y][x] = GRAN[lit]
            px[y][2] = px[y][TILE - 3] = OUTLINE
        edge = 6 if part == "top" else TILE - 7
        for x in range(2, TILE - 2):
            px[edge][x] = OUTLINE
    return px


def step_tile(rng):
    """Two-level step, for stairs cut into the hillside."""
    px = [[CLEAR] * TILE for _ in range(TILE)]
    nz = noise_field(rng)
    for y in range(TILE):
        for x in range(TILE):
            top = 10 if x >= 14 else 20
            if y >= top:
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
                px[y][x] = OUTLINE
    return px


def scatter_tile(rng, kind):
    """Decoration with no collision: loose rocks, a grass tuft, pebbles."""
    px = [[CLEAR] * TILE for _ in range(TILE)]
    if kind == "grass":
        for _ in range(16):
            bx = rng.randrange(4, TILE - 4)
            h = rng.randint(5, 11)
            lean = rng.choice((-1, 0, 0, 1))
            for i in range(h):
                x = bx + (i * lean) // 3
                y = TILE - 1 - i
                if 0 <= x < TILE:
                    px[y][x] = GRASS[1] if i > h - 3 else GRASS[2]
    elif kind == "rock":
        for _ in range(3):
            cx, cy = rng.randrange(7, TILE - 7), rng.randrange(18, TILE - 5)
            r = rng.randint(3, 5)
            for y in range(max(0, cy - r), min(TILE, cy + r)):
                for x in range(max(0, cx - r), min(TILE, cx + r)):
                    d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                    if d <= r - 0.5:
                        px[y][x] = GRAN[1 if d < r - 2.2 else 2]
                    elif d <= r + 0.2:
                        px[y][x] = OUTLINE
    else:
        for _ in range(12):
            x, y = rng.randrange(1, TILE - 2), rng.randrange(20, TILE - 1)
            px[y][x] = SAND[3]
            if rng.random() < 0.5:
                px[y][x + 1] = SAND[2]
    return px


def main() -> None:
    rng = random.Random(SEED)
    sheet = Image.new("RGBA", (COLS * TILE, ROWS * TILE), CLEAR)

    tiles = [ground_tile(bits, rng) for bits in range(16)]
    tiles.append(block_tile(rng))
    tiles.append(pillar_tile(rng, "top"))
    tiles.append(pillar_tile(rng, "mid"))
    tiles.append(pillar_tile(rng, "base"))
    tiles.append(step_tile(rng))
    tiles.append(scatter_tile(rng, "rock"))
    tiles.append(scatter_tile(rng, "grass"))
    tiles.append(scatter_tile(rng, "pebbles"))

    for i, px in enumerate(tiles):
        ox, oy = (i % COLS) * TILE, (i // COLS) * TILE
        for y in range(TILE):
            for x in range(TILE):
                c = px[y][x]
                sheet.putpixel((ox + x, oy + y), c if len(c) == 4 else c + (255,))

    out = "Assets/Tileset/tileset_generated.png"
    sheet.save(out)
    print(f"wrote {out}  ({COLS * TILE}x{ROWS * TILE}, {len(tiles)} tiles)")
    print("  tiles  0-15 : ground terrain, indexed by neighbour bits N=1 E=2 S=4 W=8")
    print("  tile     16 : cut stone block")
    print("  tiles 17-19 : pillar top / middle / base")
    print("  tile     20 : step")
    print("  tiles 21-23 : decoration, no collision")


if __name__ == "__main__":
    main()
