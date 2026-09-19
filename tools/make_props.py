"""Generate placeholder props: the puzzle vine and seed, and background trees.

Same caveat as the tileset generator -- these are stand-ins so the game can be
built and felt today.

Background trees are the one "form" job here that code has a fair chance at,
because distance does the work an artist would otherwise have to do: a tree on
a far hillside is a soft mass with a trunk, not a botanical study. They are
drawn slightly desaturated and low-contrast so they sit behind the action
instead of competing with it.

The vine is drawn at full height. The game reveals it from the bottom up by
animating the sprite region, so growth costs one static image instead of an
eight-frame animation. See Scripts/focus_plant.gd.

Usage: python tools/make_props.py
"""
import math
import random
from PIL import Image

SEED = 4711

VINE_W, VINE_H = 32, 96
STEM = [(132, 150, 70), (104, 120, 54), (74, 88, 38)]
LEAF = [(158, 176, 88), (118, 138, 62), (84, 100, 44)]
BUD = [(214, 176, 92), (176, 134, 62)]
VINE_OUTLINE = (40, 46, 22)

# Muted for distance. A background tree in full saturation reads as foreground.
CANOPY = [(146, 158, 92), (116, 130, 70), (88, 102, 54), (62, 74, 40)]
BARK = [(142, 120, 94), (110, 90, 70), (78, 64, 50), (50, 41, 32)]

# The one place saturated colour is allowed: the flower is the reward at the top
# of the vine, and it should read instantly as somewhere to land.
PETAL = [(252, 230, 234), (240, 200, 210), (212, 156, 174), (166, 112, 132)]
CORE = [(248, 216, 132), (214, 172, 84), (168, 128, 58)]

CLEAR = (0, 0, 0, 0)


def blank(w, h):
	return [[CLEAR] * w for _ in range(h)]


def save(px, path):
	h, w = len(px), len(px[0])
	img = Image.new("RGBA", (w, h), CLEAR)
	for y in range(h):
		for x in range(w):
			c = px[y][x]
			img.putpixel((x, y), c if len(c) == 4 else c + (255,))
	img.save(path)
	print(f"wrote {path} ({w}x{h})")


def put(px, x, y, c):
	if 0 <= y < len(px) and 0 <= x < len(px[0]):
		px[y][x] = c


# --- The puzzle vine --------------------------------------------------------

def leaf(px, cx, cy, direction, size):
	"""A simple oval leaf leaning away from the stem."""
	for dy in range(-size, size + 1):
		for dx in range(0, size * 2 + 1):
			if (dx / (size * 2.0)) ** 2 + (dy / float(size)) ** 2 > 1.0:
				continue
			x, y = cx + dx * direction, cy + dy - dx // 3
			edge = (dx / (size * 2.0)) ** 2 + (dy / float(size)) ** 2 > 0.62
			put(px, x, y, VINE_OUTLINE if edge else (LEAF[0] if dy < 0 else LEAF[1]))
	for dx in range(1, size * 2):
		put(px, cx + dx * direction, cy - dx // 3, LEAF[2])


def make_vine(rng):
	px = blank(VINE_W, VINE_H)
	centre = {}
	for y in range(VINE_H):
		t = y / float(VINE_H - 1)
		# A gentle serpentine, so the stem does not look like a ruler.
		offset = 3.4 * math.sin(t * 5.2) * (1.0 - t * 0.45)
		cx = int(round(VINE_W / 2 + offset))
		centre[y] = cx
		for dx in (-1, 0, 1):
			put(px, cx + dx, y, STEM[1] if dx == 0 else STEM[2])
		put(px, cx - 1, y, STEM[0] if y % 7 else STEM[1])

	side, y = 1, VINE_H - 12
	while y > 12:
		leaf(px, centre[y] + side * 2, y, side, 4 if y > VINE_H * 0.45 else 3)
		side = -side
		y -= rng.randint(12, 16)

	tip = centre[3]
	for dy in range(0, 6):
		for dx in range(-2, 3):
			if abs(dx) + abs(dy - 3) <= 3:
				put(px, tip + dx, 2 + dy, BUD[0] if dy < 3 else BUD[1])
	return px


def make_seed():
	px = blank(16, 16)
	for y in range(16):
		for x in range(16):
			dx, dy = (x - 7.5) / 4.0, (y - 9.0) / 5.0
			d = dx * dx + dy * dy
			if d <= 1.0:
				px[y][x] = BUD[0] if dy < -0.2 else BUD[1]
			elif d <= 1.35:
				px[y][x] = VINE_OUTLINE
	return px


def petal(px, bx, by, length, width, angle_deg, shades, outline):
	"""One petal, rooted at (bx, by) and radiating outward, widest mid-way."""
	a = math.radians(angle_deg)
	ca, sa = math.cos(a), math.sin(a)
	for t in range(0, length + 1):
		half = width * math.sin(math.pi * (t / float(length)) ** 0.85)
		if half < 0.5:
			continue
		for w in range(-int(half), int(half) + 1):
			x = int(round(bx + t * ca - w * sa))
			y = int(round(by + t * sa + w * ca))
			if abs(w) >= half - 1.0:
				put(px, x, y, outline)
			else:
				# Lighter toward the tip, so the petals read as curling open.
				put(px, x, y, shades[0] if t > length * 0.62 else shades[1])


def make_flower():
	"""The platform at the top of the vine. Wide, flat-topped, hard to miss."""
	w, h = 48, 28
	px = blank(w, h)
	base_x, base_y = w // 2, 20

	# Back row, darker, spread wide to make the silhouette broad.
	for angle in (-172, -146, -120, -92, -64, -38, -12):
		petal(px, base_x, base_y, 19, 4.6, angle, [PETAL[1], PETAL[2]], PETAL[3])
	# Front row, lighter, shorter, filling the middle.
	for angle in (-158, -128, -98, -68, -38):
		petal(px, base_x, base_y - 2, 14, 4.0, angle, [PETAL[0], PETAL[1]], PETAL[3])

	# Seed cup.
	for y in range(h):
		for x in range(w):
			dx, dy = (x - base_x) / 6.0, (y - (base_y - 5)) / 3.6
			d = dx * dx + dy * dy
			if d <= 1.0:
				px[y][x] = CORE[0] if dy < -0.15 else CORE[1]
			elif d <= 1.4:
				px[y][x] = CORE[2]
	return px


def make_sapling():
	"""What you actually sit beside. A seed would be under the soil."""
	w, h = 20, 18
	px = blank(w, h)
	cx = w // 2
	for y in range(6, h):
		put(px, cx, y, STEM[1])
		put(px, cx - 1, y, STEM[2])
	for side, cy, size in ((1, 10, 4), (-1, 13, 3), (1, 15, 2)):
		for t in range(size * 2 + 1):
			half = max(1, int(size * math.sin(math.pi * (t / float(size * 2 + 1)))))
			for k in range(-half, half + 1):
				x = cx + side * t
				y = cy + k // 2 - t // 3
				put(px, x, y, LEAF[0] if k < 0 else LEAF[1])
	# Two seed leaves at the crown so it reads as young growth.
	for dx in (-2, -1, 0, 1, 2):
		put(px, cx + dx, 5, LEAF[0])
		put(px, cx + dx, 6, LEAF[1])
	return px


# --- Background trees -------------------------------------------------------

def canopy_mass(px, blobs, rng):
	"""Overlapping ellipses shaded as one mass, with a ragged leafy edge."""
	mask = set()
	for cx, cy, rx, ry in blobs:
		for y in range(cy - ry - 1, cy + ry + 2):
			for x in range(cx - rx - 1, cx + rx + 2):
				if ((x - cx) / float(rx)) ** 2 + ((y - cy) / float(ry)) ** 2 <= 1.0:
					mask.add((x, y))

	# Chew the outline so it reads as foliage rather than as a balloon.
	border = {p for p in mask
			  if not all((p[0] + dx, p[1] + dy) in mask
						 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))}
	for p in border:
		if rng.random() < 0.38:
			mask.discard(p)

	xs = [p[0] for p in mask]
	ys = [p[1] for p in mask]
	x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)

	for x, y in mask:
		# Light from the upper left, plus clumping so it is not a smooth ramp.
		u = (x - x0) / max(1.0, float(x1 - x0))
		v = (y - y0) / max(1.0, float(y1 - y0))
		lit = u * 0.45 + v * 0.75 + rng.random() * 0.28
		put(px, x, y, CANOPY[0] if lit < 0.42 else
			(CANOPY[1] if lit < 0.78 else CANOPY[2]))

	for x, y in mask:
		if not all((x + dx, y + dy) in mask
				   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
			put(px, x, y, CANOPY[3])
	return mask


def make_tree(rng, width, height, style):
	px = blank(width, height)
	ground = height - 1
	trunk_x = width // 2

	if style == "banyan":
		trunk_top = int(height * 0.46)
		half = 4
	else:
		trunk_top = int(height * 0.40)
		half = 2

	# Trunk, tapering toward the canopy. The width is dithered rather than
	# rounded: rounding puts a hard horizontal step across the trunk wherever it
	# crosses to the next pixel width, and it reads as a joint in the wood.
	for y in range(trunk_top, ground + 1):
		t = (y - trunk_top) / float(max(1, ground - trunk_top))
		exact = half * (0.55 + 0.45 * t)
		w = int(exact)
		if rng.random() < exact - w:
			w += 1
		w = max(1, w)
		for dx in range(-w, w + 1):
			edge = abs(dx) == w
			lit = BARK[0] if dx < -w // 2 else (BARK[1] if dx <= w // 2 else BARK[2])
			put(px, trunk_x + dx, y, BARK[3] if edge else lit)
		# Bark striation, so the trunk is not a flat gradient.
		if rng.random() < 0.3 and w > 1:
			put(px, trunk_x + rng.randint(-w + 1, w - 1), y, BARK[2])

	# A couple of branches lifting into the canopy.
	for direction in (-1, 1):
		bx, by = trunk_x, trunk_top + int(height * 0.06)
		for i in range(int(width * 0.22)):
			bx += direction
			by -= 1 if i % 2 == 0 else 0
			put(px, bx, by, BARK[2])
			put(px, bx, by + 1, BARK[3])

	if style == "banyan":
		blobs = [
			(trunk_x, int(height * 0.28), int(width * 0.42), int(height * 0.16)),
			(trunk_x - int(width * 0.26), int(height * 0.34), int(width * 0.24), int(height * 0.13)),
			(trunk_x + int(width * 0.26), int(height * 0.33), int(width * 0.25), int(height * 0.13)),
			(trunk_x, int(height * 0.17), int(width * 0.28), int(height * 0.12)),
		]
	else:
		blobs = [
			(trunk_x, int(height * 0.22), int(width * 0.40), int(height * 0.17)),
			(trunk_x - int(width * 0.18), int(height * 0.32), int(width * 0.26), int(height * 0.12)),
			(trunk_x + int(width * 0.20), int(height * 0.30), int(width * 0.24), int(height * 0.11)),
		]
	mask = canopy_mass(px, blobs, rng)

	if style == "banyan":
		# Aerial roots hanging from the canopy -- the thing that makes a banyan
		# read as a banyan rather than as a generic blob.
		for _ in range(7):
			rx = rng.randrange(int(width * 0.12), int(width * 0.88))
			under = [y for (x, y) in mask if x == rx]
			if not under:
				continue
			start = max(under) + 1
			length = rng.randint(int(height * 0.12), int(height * 0.34))
			for i in range(length):
				y = start + i
				if y >= ground:
					break
				put(px, rx + (1 if i > length * 0.7 else 0), y,
					BARK[2] if i % 5 else BARK[1])
	return px


def main() -> None:
	rng = random.Random(SEED)
	save(make_vine(rng), "Assets/Props/vine.png")
	save(make_sapling(), "Assets/Props/sapling.png")
	save(make_flower(), "Assets/Props/flower.png")
	save(make_tree(rng, 96, 112, "banyan"), "Assets/Props/tree_banyan.png")
	save(make_tree(rng, 56, 96, "slim"), "Assets/Props/tree_slim.png")
	save(make_tree(rng, 72, 80, "slim"), "Assets/Props/tree_small.png")


if __name__ == "__main__":
	main()
