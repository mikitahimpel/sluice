"""Generate the Sluice menu bar template icon by extracting the mark directly
from the AppIcon master. This guarantees the menu bar silhouette is 1:1 with
the brand logo — no proportions to re-tune.

Source: docs/assets/sluice-icon-master.png (white mark on a black rounded tile).
We isolate the white pixels, invert to a black-on-transparent template, square
the canvas with breathing-room padding, and downsample to 16/32/48.

macOS treats `template-rendering-intent: "template"` images as silhouettes —
the alpha is auto-inverted for light/dark menu bars, only the shape matters.

Run: python3 generate_menu_bar_icon.py
Outputs: writes PNGs into Sluice/App/Assets.xcassets/MenuBarIcon.imageset/
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(HERE, "sluice-icon-master.png")
ICONSET = os.path.normpath(
    os.path.join(HERE, "..", "..", "Sluice", "App", "Assets.xcassets", "MenuBarIcon.imageset")
)

# Working canvas for high-quality downsample. Larger = sharper terminal sizes.
WORK = 4096
# How much of the working canvas the mark occupies. The AppIcon itself leaves
# generous tile padding around the mark; for the menu bar (no tile) we can run
# the mark closer to the edge so it reads at 18pt.
MARK_FILL = 0.92


def isolate_mark(source: Image.Image) -> Image.Image:
    """Return a black-on-transparent RGBA image containing just the mark,
    cropped tight to the union of the white parallelograms."""
    src = source.convert("RGBA")
    w, h = src.size
    pixels = src.load()

    # The AppIcon master is white-on-black. White → opaque-black template;
    # everything else → transparent. Threshold tolerates anti-aliasing.
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out_pixels = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            brightness = (r + g + b) // 3
            if a > 0 and brightness > 200:
                # Map source brightness to template alpha so anti-aliased edges
                # carry through cleanly.
                alpha = min(255, int((brightness - 200) * (255 / 55)))
                out_pixels[x, y] = (0, 0, 0, alpha)
    return out.crop(out.getbbox())


def main() -> None:
    src = Image.open(SOURCE)
    mark = isolate_mark(src)

    mw, mh = mark.size
    target_side = int(WORK * MARK_FILL)
    scale = target_side / max(mw, mh)
    resized = mark.resize((int(mw * scale), int(mh * scale)), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (WORK, WORK), (0, 0, 0, 0))
    rw, rh = resized.size
    canvas.alpha_composite(resized, ((WORK - rw) // 2, (WORK - rh) // 2))

    os.makedirs(ICONSET, exist_ok=True)
    for size, name in [(16, "menubar.png"), (32, "menubar@2x.png"), (48, "menubar@3x.png")]:
        canvas.resize((size, size), Image.Resampling.LANCZOS).save(os.path.join(ICONSET, name), "PNG")
        print(f"wrote {name} ({size}x{size})")

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
