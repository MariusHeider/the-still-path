"""Generate placeholder puzzle props: a climbing vine and a seed.

Same caveat as the tileset generator -- these are stand-ins so the mechanic can
be built and felt today. Anything whose charm depends on silhouette should be
replaced with real art.

The vine is drawn at full height. The game reveals it from the bottom up by
animating the sprite region, so growth costs one static image instead of an
eight-frame animation. See Scripts/focus_plant.gd.

Usage: python tools/make_props.py
"""
import random
from PIL import Image

SEED = 4711
VINE_W, VINE_H = 32, 96

STEM = [(132, 150, 70), (104, 120, 54), (74, 88, 38)]
LEAF = [(158, 176, 88), (118, 138, 62), (84, 100, 44)]
BUD = [(214, 176, 92), (176, 134, 62)]
OUTLINE = (40, 46, 22)
CLEAR = (0, 0, 0, 0)


def put(px, x, y, c):
    if 0 <= x < VINE_W and 0 <= y < VINE_H:
        px[y][x] = c


def leaf(px, cx, cy, direction, size):
    """A simple oval leaf leaning away from the stem."""
    for dy in range(-size, size + 1):
        for dx in range(0, size * 2 + 1):
            # Squashed ellipse, wider than it is tall.
            if (dx / (size * 2.0)) ** 2 + (dy / float(size)) ** 2 > 1.0:
                continue
            x, y = cx + dx * direction, cy + dy - dx // 3
            edge = (dx / (size * 2.0)) ** 2 + (dy / float(size)) ** 2 > 0.62
            put(px, x, y, OUTLINE if edge else (LEAF[0] if dy < 0 else LEAF[1]))
    # Midrib, so it reads as a leaf and not a blob.
    for dx in range(1, size * 2):
        put(px, cx + dx * direction, cy - dx // 3, LEAF[2])


def main() -> None:
    rng = random.Random(SEED)
    px = [[CLEAR] * VINE_W for _ in range(VINE_H)]

    # Stem: a gentle serpentine so it does not look like a ruler.
    centre = {}
    for y in range(VINE_H):
        t = y / float(VINE_H - 1)
        offset = 3.4 * __import__("math").sin(t * 5.2) * (1.0 - t * 0.45)
        cx = int(round(VINE_W / 2 + offset))
        centre[y] = cx
        for dx in (-1, 0, 1):
            put(px, cx + dx, y, STEM[1] if dx == 0 else STEM[2])
        put(px, cx - 1, y, STEM[0] if y % 7 else STEM[1])

    # Leaves alternate sides going up, getting smaller toward the tip.
    side = 1
    y = VINE_H - 12
    while y > 12:
        size = 4 if y > VINE_H * 0.45 else 3
        leaf(px, centre[y] + side * 2, y, side, size)
        side = -side
        y -= rng.randint(12, 16)

    # A bud at the growing tip.
    tip = centre[3]
    for dy in range(0, 6):
        for dx in range(-2, 3):
            if abs(dx) + abs(dy - 3) <= 3:
                put(px, tip + dx, 2 + dy, BUD[0] if dy < 3 else BUD[1])

    img = Image.new("RGBA", (VINE_W, VINE_H), CLEAR)
    for yy in range(VINE_H):
        for xx in range(VINE_W):
            c = px[yy][xx]
            img.putpixel((xx, yy), c if len(c) == 4 else c + (255,))
    img.save("Assets/Props/vine.png")
    print(f"wrote Assets/Props/vine.png ({VINE_W}x{VINE_H})")

    # Seed: the thing you sit beside before anything has grown.
    s = Image.new("RGBA", (16, 16), CLEAR)
    for yy in range(16):
        for xx in range(16):
            dx, dy = (xx - 7.5) / 4.0, (yy - 9.0) / 5.0
            d = dx * dx + dy * dy
            if d <= 1.0:
                s.putpixel((xx, yy), (BUD[0] if dy < -0.2 else BUD[1]) + (255,))
            elif d <= 1.35:
                s.putpixel((xx, yy), OUTLINE + (255,))
    s.save("Assets/Props/seed.png")
    print("wrote Assets/Props/seed.png (16x16)")


if __name__ == "__main__":
    main()
