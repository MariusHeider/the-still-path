"""Print a numeric palette report for a spritesheet.

Reads the image locally and prints only numbers and hex codes -- the artwork
itself never leaves this machine. Used to plan a palette remap without
shipping the source asset anywhere.

Usage: python tools/palette_report.py Assets/Tileset/platformer_source.png
"""
import sys
from collections import Counter
from PIL import Image


def main(path: str, tile: int = 32, top: int = 40) -> None:
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    print(f"file      {path}")
    print(f"size      {w} x {h} px")
    print(f"grid      {w / tile:g} x {h / tile:g} tiles at {tile}px"
          f"   {'(clean)' if w % tile == 0 and h % tile == 0 else '(NOT a clean multiple)'}")

    pixels = list(img.getdata())
    opaque = [p for p in pixels if p[3] > 0]
    counts = Counter((r, g, b) for r, g, b, _ in opaque)
    print(f"pixels    {len(pixels)} total, {len(opaque)} opaque "
          f"({100 * len(opaque) / len(pixels):.1f}% coverage)")
    print(f"colours   {len(counts)} unique opaque")

    print(f"\ntop {top} colours by pixel count")
    print(f"{'hex':>9} {'r':>4}{'g':>4}{'b':>4}  {'hue':>4}{'sat':>5}{'val':>5}  {'pixels':>8}  share")
    for (r, g, b), n in counts.most_common(top):
        mx, mn = max(r, g, b), min(r, g, b)
        v = mx / 255
        s = 0.0 if mx == 0 else (mx - mn) / mx
        if mx == mn:
            hue = 0
        elif mx == r:
            hue = (60 * (g - b) / (mx - mn)) % 360
        elif mx == g:
            hue = 60 * (b - r) / (mx - mn) + 120
        else:
            hue = 60 * (r - g) / (mx - mn) + 240
        print(f"  #{r:02x}{g:02x}{b:02x} {r:4}{g:4}{b:4}  {hue:4.0f}{s:5.2f}{v:5.2f}"
              f"  {n:8}  {100 * n / len(opaque):5.2f}%")

    # Which tiles in the grid actually contain art -- tells us the sheet layout.
    print(f"\ntile occupancy map ({w // tile} cols x {h // tile} rows, '#' = has pixels)")
    for ty in range(h // tile):
        row = ""
        for tx in range(w // tile):
            box = img.crop((tx * tile, ty * tile, (tx + 1) * tile, (ty + 1) * tile))
            row += "#" if any(p[3] > 0 for p in box.getdata()) else "."
        print(f"  {ty:2} {row}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "Assets/Tileset/platformer_source.png")
