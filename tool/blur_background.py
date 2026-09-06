#!/usr/bin/env python3
"""Regenerate bg-vector-blurred.png from bg-vector.png.

The app used to blur this image at runtime through `ImageFiltered` and
composite it at 50% `Opacity`, under every shell screen, with no
`RepaintBoundary` — two `saveLayer`s per frame for a decoration. Both are now
baked into the asset instead. Run this after changing the source art:

    python tool/blur_background.py

Requires Pillow (`python -m pip install pillow`).
"""

from PIL import Image, ImageFilter

SRC = "bg-vector.png"
OUT = "bg-vector-blurred.png"

# Matches the sigma the runtime ImageFilter.blur used. The asset is scaled
# ~1.1x to cover a phone, so blurring at source resolution with the same sigma
# lands within a pixel of the old result.
SIGMA = 3

# Matches the Opacity(0.5) the widget used to wrap the image in. Composited
# over the opaque cream ground, halving the alpha channel is exactly
# equivalent.
ALPHA_SCALE = 0.5


def main() -> None:
    src = Image.open(SRC).convert("RGBA")
    blurred = src.filter(ImageFilter.GaussianBlur(radius=SIGMA))
    r, g, b, a = blurred.split()
    a = a.point(lambda v: int(v * ALPHA_SCALE))
    Image.merge("RGBA", (r, g, b, a)).save(OUT, optimize=True)
    print(f"{OUT} written from {SRC}")


if __name__ == "__main__":
    main()
