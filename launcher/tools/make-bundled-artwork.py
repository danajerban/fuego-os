#!/usr/bin/env python3
"""Draws the Launcher's bundled artwork: soft abstract colour fields at TV resolution, saved as WebP.

The pictures are ours (made by this script, MIT like the rest of fuego-os), so they need no notice.
Rerun it to remake them: python3 launcher/tools/make-bundled-artwork.py (needs Pillow).
"""
import pathlib

from PIL import Image, ImageChops, ImageDraw, ImageFilter

WIDTH, HEIGHT = 1920, 1080
OUT = pathlib.Path(__file__).resolve().parent.parent / "app/src/main/res/drawable-nodpi"

# name: (base colour, [(centre x, centre y, radius, colour)]), positions as fractions of the screen.
PICTURES = {
    "artwork_ember": ((18, 6, 10), [
        (0.20, 0.25, 0.55, (255, 87, 34)),
        (0.75, 0.15, 0.45, (255, 171, 64)),
        (0.60, 0.85, 0.50, (183, 28, 28)),
    ]),
    "artwork_dusk": ((8, 8, 24), [
        (0.15, 0.80, 0.55, (94, 53, 177)),
        (0.70, 0.30, 0.50, (236, 64, 122)),
        (0.95, 0.90, 0.40, (255, 112, 67)),
    ]),
    "artwork_tide": ((4, 14, 20), [
        (0.25, 0.20, 0.50, (0, 151, 167)),
        (0.80, 0.70, 0.55, (21, 101, 192)),
        (0.45, 0.95, 0.35, (38, 166, 154)),
    ]),
    "artwork_moss": ((8, 14, 8), [
        (0.80, 0.20, 0.50, (124, 179, 66)),
        (0.20, 0.70, 0.55, (0, 121, 107)),
        (0.55, 0.45, 0.30, (205, 220, 57)),
    ]),
}


def draw(base, blobs):
    picture = Image.new("RGB", (WIDTH, HEIGHT), base)
    for x, y, r, colour in blobs:
        glow = Image.new("RGB", (WIDTH, HEIGHT), (0, 0, 0))
        radius = r * HEIGHT
        ImageDraw.Draw(glow).ellipse(
            (x * WIDTH - radius, y * HEIGHT - radius, x * WIDTH + radius, y * HEIGHT + radius), fill=colour)
        picture = ImageChops.screen(picture, glow.filter(ImageFilter.GaussianBlur(radius * 0.6)))
    picture = picture.filter(ImageFilter.GaussianBlur(24))
    # A faint grain breaks up the banding a smooth gradient shows on an 8-bit panel.
    grain = Image.effect_noise((WIDTH, HEIGHT), 3).convert("RGB")
    picture = ImageChops.add(picture, grain, scale=1, offset=-128)
    return picture


for name, (base, blobs) in PICTURES.items():
    draw(base, blobs).save(OUT / f"{name}.webp", "WEBP", quality=80, method=6)
    print(OUT / f"{name}.webp")
