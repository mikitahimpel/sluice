"""Generate the Sluice menu bar template icon.

Three cascading parallel bars in solid black on transparent — matching the
app icon's mark. Rendered at 4096 and downsampled with LANCZOS to 16, 32, 64
(menu bar uses 18pt = 18x18 at 1x, 36x36 at 2x; Apple's HIG recommends
authoring at 16/32, the system scales).

macOS treats this as a Template Image (per the imageset's
template-rendering-intent) and auto-inverts the alpha for light/dark menu
bars, so the visible color of the mark is irrelevant — only the silhouette.

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

BAR_LENGTH = int(SS * 0.36)
BAR_THICK = int(SS * 0.13)
TILT_DEG = 22.0
CASCADE_STEP = int(SS * 0.22)


def rotated_rect(cx: float, cy: float, length: int, thickness: int, angle_deg: float) -> list[tuple[float, float]]:
    a = math.radians(angle_deg)
    dx, dy = math.cos(a) * length / 2, math.sin(a) * length / 2
    px, py = -math.sin(a) * thickness / 2, math.cos(a) * thickness / 2
    return [
        (cx - dx - px, cy - dy - py),
        (cx + dx - px, cy + dy - py),
        (cx + dx + px, cy + dy + py),
        (cx - dx + px, cy - dy + py),
    ]


def build_mark(draw: ImageDraw.ImageDraw) -> None:
    cx0, cy0 = SS / 2, SS / 2
    step_x = math.cos(math.radians(TILT_DEG + 90)) * CASCADE_STEP
    step_y = math.sin(math.radians(TILT_DEG + 90)) * CASCADE_STEP
    for i in (-1, 0, 1):
        cx, cy = cx0 + step_x * i * 0.6, cy0 + step_y * i
        draw.polygon(rotated_rect(cx, cy, BAR_LENGTH, BAR_THICK, TILT_DEG), fill=(0, 0, 0, 255))


def main() -> None:
    canvas = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
    build_mark(ImageDraw.Draw(canvas))

    os.makedirs(ICONSET, exist_ok=True)
    for size, name in [(16, "menubar.png"), (32, "menubar@2x.png"), (48, "menubar@3x.png")]:
        canvas.resize((size, size), Image.Resampling.LANCZOS).save(os.path.join(ICONSET, name), "PNG")
        print(f"wrote {name} ({size}x{size})")


if __name__ == "__main__":
    main()
