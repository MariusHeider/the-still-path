"""Shift a spritesheet's palette from cold/northern to warm/South-Indian.

Runs entirely on this machine: reads the PNG, remaps every colour by hue family,
writes a new PNG. Nothing is uploaded and no model sees the artwork.

The pack splits into four colour families. Only two of them actually need work:
the greens are a cold northern-forest green, and roughly a tenth of the sheet is
snow. The browns and terracottas are already the right colours for laterite and
clay tile, so they get left nearly alone.

All the tuning lives in the constants below -- change a number, re-run, look at
it in Godot. Takes about two seconds per pass.

Usage: python tools/recolour.py [in.png] [out.png]
"""
import sys
import warnings
from colorsys import rgb_to_hsv, hsv_to_rgb
from PIL import Image

warnings.filterwarnings("ignore", category=DeprecationWarning)

# --- Greens: cold forest -> dry sunlit olive --------------------------------
GREEN_RANGE = (60.0, 175.0)    # hues treated as foliage
GREEN_TARGET = (52.0, 95.0)    # compressed into this warmer, narrower band
GREEN_SAT = 0.82               # slightly less lush
GREEN_VAL = 1.14               # dry-season foliage catches more light

# --- Blues: snow and ice -> pale sandstone ----------------------------------
BLUE_RANGE = (175.0, 272.0)   # upper edge catches pale lavender ice highlights
BLUE_HUE = 34.0                # warm stone
BLUE_SAT = 0.35                # mostly drained of colour, so it reads as stone
BLUE_VAL = 0.98

# --- Warm tones: already close, just nudged ---------------------------------
WARM_SAT = 1.06
WARM_HUE_PULL = 0.12           # fraction of the way toward WARM_HUE_CENTRE
WARM_HUE_CENTRE = 28.0

# Near-neutral pixels get a touch of warmth instead of a hue rotation, which
# would otherwise swing unpredictably on greys.
NEUTRAL_SAT = 0.10
NEUTRAL_TINT = 0.05


def _clamp(x: float) -> float:
    return max(0.0, min(1.0, x))


def remap(r: int, g: int, b: int) -> tuple[int, int, int]:
    h, s, v = rgb_to_hsv(r / 255, g / 255, b / 255)
    hue = h * 360.0

    if s < NEUTRAL_SAT:
        hue, s = WARM_HUE_CENTRE, min(1.0, s + NEUTRAL_TINT)
    elif GREEN_RANGE[0] <= hue < GREEN_RANGE[1]:
        t = (hue - GREEN_RANGE[0]) / (GREEN_RANGE[1] - GREEN_RANGE[0])
        hue = GREEN_TARGET[0] + t * (GREEN_TARGET[1] - GREEN_TARGET[0])
        s, v = s * GREEN_SAT, v * GREEN_VAL
    elif BLUE_RANGE[0] <= hue < BLUE_RANGE[1]:
        hue, s, v = BLUE_HUE, s * BLUE_SAT, v * BLUE_VAL
    else:
        # Take the SHORT way round the colour wheel. Without this, a dark red at
        # hue 355 gets dragged backwards through purple instead of forwards
        # through red, and the bricks come out magenta.
        delta = ((WARM_HUE_CENTRE - hue + 180.0) % 360.0) - 180.0
        hue += delta * WARM_HUE_PULL
        s = s * WARM_SAT

    nr, ng, nb = hsv_to_rgb((hue % 360.0) / 360.0, _clamp(s), _clamp(v))
    return round(nr * 255), round(ng * 255), round(nb * 255)


def main(src: str, dst: str) -> None:
    img = Image.open(src).convert("RGBA")
    # Remap the palette, not the pixels: 258 unique colours instead of a
    # million lookups, and it guarantees identical colours stay identical.
    cache: dict[tuple[int, int, int], tuple[int, int, int]] = {}
    out = []
    for r, g, b, a in img.getdata():
        if a == 0:
            out.append((0, 0, 0, 0))     # keep transparency exactly
            continue
        key = (r, g, b)
        if key not in cache:
            cache[key] = remap(r, g, b)
        out.append(cache[key] + (a,))

    result = Image.new("RGBA", img.size)
    result.putdata(out)
    result.save(dst)
    print(f"{src} -> {dst}")
    print(f"{len(cache)} unique colours remapped, {img.size[0]}x{img.size[1]} px")
    print("\nsample of the mapping (before -> after)")
    for before, after in list(cache.items())[:14]:
        print(f"  #{before[0]:02x}{before[1]:02x}{before[2]:02x}"
              f"  ->  #{after[0]:02x}{after[1]:02x}{after[2]:02x}")


if __name__ == "__main__":
    main(
        sys.argv[1] if len(sys.argv) > 1 else "Assets/Tileset/platformer_source.png",
        sys.argv[2] if len(sys.argv) > 2 else "Assets/Tileset/tileset_warm.png",
    )
