"""Generate the Sluice menu bar template icon.

Mark: three staggered diagonal bars — the same gesture as the app's brand
icon (a stylized sluice gate). Each bar is a rotated rectangle; together they
cascade from upper-right to lower-left, forming a zigzag silhouette that reads
as the AppIcon at 16pt.

Authored at 4096px and downsampled with LANCZOS to 16/32/48. macOS treats
this as a Template Image (per the imageset's template-rendering-intent) and
auto-inverts the alpha for light/dark menu bars — visible color is irrelevant,
only the silhouette matters.

Run: python3 generate_menu_bar_icon.py
Outputs: writes PNGs into Sluice/App/Assets.xcassets/MenuBarIcon.imageset/
"""

import math
import os
from PIL import Image, ImageDraw

SS = 4096
HERE = os.path.dirname(os.path.abspath(__file__))
ICONSET = os.path.normpath(
    os.path.join(HERE, "..", "..", "Sluice", "App", "Assets.xcassets", "MenuBarIcon.imageset")
)

# Tilt of each bar — matches the brand mark (≈ 30° from horizontal).
TILT_DEG = 30.0
# Each bar's pixel footprint as a fraction of canvas side.
BAR_WIDTH = 0.42
BAR_HEIGHT = 0.155
# Stagger between successive bars. The bars move *along* the tilt axis so the
# row reads as a continuous diagonal zigzag, not three independent strips.
STAGGER_X = 0.22
STAGGER_Y = 0.20


def rotated_rect(cx: float, cy: float, w: float, h: float, angle_deg: float):
    """Return the 4 corners of a rectangle centered at (cx, cy), rotated."""
    a = math.radians(angle_deg)
    cos_a, sin_a = math.cos(a), math.sin(a)
    hw, hh = w / 2, h / 2
    corners = [(-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh)]
    return [
        (cx + x * cos_a - y * sin_a, cy + x * sin_a + y * cos_a)
        for x, y in corners
    ]


def build_mark(draw: ImageDraw.ImageDraw) -> None:
    # Three bars marching from the top-right toward the bottom-left, mirroring
    # the brand icon. Centered on the canvas so they fill it edge-to-edge.
    cx, cy = SS / 2, SS / 2
    w = SS * BAR_WIDTH
    h = SS * BAR_HEIGHT
    dx = SS * STAGGER_X
    dy = SS * STAGGER_Y

    for offset in (-1, 0, 1):
        bar_cx = cx + offset * dx
        bar_cy = cy + offset * dy
        # Top-right bar is `offset = +1` (positive dx, positive dy moves
        # toward bottom-right? — image coords have y down, so positive dy is
        # downward. To get top-right → bottom-left, we negate the y axis.
        bar_cy = cy - offset * dy
        # Re-apply x stagger keyed to the same sign.
        bar_cx = cx + offset * dx
        pts = rotated_rect(bar_cx, bar_cy, w, h, TILT_DEG)
        draw.polygon(pts, fill=(0, 0, 0, 255))


def main() -> None:
    canvas = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
    build_mark(ImageDraw.Draw(canvas))

    os.makedirs(ICONSET, exist_ok=True)
    for size, name in [(16, "menubar.png"), (32, "menubar@2x.png"), (48, "menubar@3x.png")]:
        canvas.resize((size, size), Image.Resampling.LANCZOS).save(os.path.join(ICONSET, name), "PNG")
        print(f"wrote {name} ({size}x{size})")

    # Asset catalog descriptor — declares the three rasters as a template image
    # so macOS does the dark/light inversion automatically.
    with open(os.path.join(ICONSET, "Contents.json"), "w") as f:
        f.write(
            '{\n'
            '  "images" : [\n'
            '    { "filename" : "menubar.png", "idiom" : "universal", "scale" : "1x" },\n'
            '    { "filename" : "menubar@2x.png", "idiom" : "universal", "scale" : "2x" },\n'
            '    { "filename" : "menubar@3x.png", "idiom" : "universal", "scale" : "3x" }\n'
            '  ],\n'
            '  "info" : { "author" : "xcode", "version" : 1 },\n'
            '  "properties" : { "template-rendering-intent" : "template" }\n'
            '}\n'
        )


if __name__ == "__main__":
    main()
