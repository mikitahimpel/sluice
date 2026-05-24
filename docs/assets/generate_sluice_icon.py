"""Generate the Sluice macOS app icon.

Design:
- Squircle (continuous superellipse, n=5) — no outer drop shadow.
- Mesh-gradient background: deep navy base with cyan and magenta soft blobs.
- White asymmetric routing-arrow mark: one trunk enters from the left, splits
  into two arrowed branches — one continues straight, one peels off downward.

Run: python3 generate_sluice_icon.py
Output: /tmp/agy-sluice-icon.png
"""

import os
import numpy as np
from PIL import Image, ImageDraw


SS = 4096
OUT = 1024

BASE = np.array([8, 14, 44])
BLOB_A = np.array([14, 165, 233])
BLOB_B = np.array([168, 85, 247])
BLOB_C = np.array([34, 211, 238])


def make_squircle_alpha(size: int, n: float = 5.0) -> np.ndarray:
    x = np.linspace(-1, 1, size)
    X, Y = np.meshgrid(x, x)
    val = np.abs(X) ** n + np.abs(Y) ** n
    return np.clip((1.0 - val) * size * 0.5, 0, 1)


def radial_blob(size: int, cx: float, cy: float, sigma: float) -> np.ndarray:
    x = np.linspace(0, 1, size)
    X, Y = np.meshgrid(x, x)
    d2 = (X - cx) ** 2 + (Y - cy) ** 2
    return np.exp(-d2 / (2 * sigma ** 2))


def mesh_background(size: int) -> np.ndarray:
    bg = np.tile(BASE.reshape(1, 1, 3), (size, size, 1)).astype(np.float32)
    for color, cx, cy, sigma, weight in [
        (BLOB_A, 0.18, 0.15, 0.45, 0.85),
        (BLOB_B, 0.85, 0.92, 0.55, 0.60),
        (BLOB_C, 0.92, 0.10, 0.30, 0.55),
    ]:
        blob = radial_blob(size, cx, cy, sigma)[..., None] * weight
        bg = bg * (1 - blob) + color.reshape(1, 1, 3) * blob
    return np.clip(bg, 0, 255).astype(np.uint8)


def build_routing_mark(draw: ImageDraw.ImageDraw) -> None:
    # Bold horizontal trunk splitting upward and downward — symmetric for max
    # legibility at 16x16. Stroke is ~14% of icon width so the mark survives
    # aggressive downsampling.
    W = int(SS * 0.14)
    left = SS * 0.18
    mid = SS * 0.50
    right_x = SS * 0.82
    cy = SS * 0.50
    up_y = SS * 0.22
    down_y = SS * 0.78

    white = (255, 255, 255, 255)
    # Trunk (left → split point)
    draw.line([(left, cy), (mid, cy)], fill=white, width=W)
    # Upper branch
    draw.line([(mid, cy), (right_x, up_y)], fill=white, width=W)
    # Lower branch
    draw.line([(mid, cy), (right_x, down_y)], fill=white, width=W)

    # Round caps — the four free endpoints and the junction get hard discs so
    # joins read cleanly at any size.
    r = W // 2
    for x, y in [(left, cy), (mid, cy), (right_x, up_y), (right_x, down_y)]:
        draw.ellipse([x - r, y - r, x + r, y + r], fill=white)


def main(output_path: str) -> None:
    bg = mesh_background(SS)
    bg_img = Image.fromarray(bg).convert("RGBA")

    sheen = np.zeros((SS, SS, 4), dtype=np.uint8)
    sheen_y = np.linspace(1, 0, SS).reshape(SS, 1) ** 3
    sheen[..., :3] = 255
    sheen[..., 3] = (sheen_y * 28).astype(np.uint8)
    bg_img = Image.alpha_composite(bg_img, Image.fromarray(sheen))

    mark = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(mark)
    build_routing_mark(draw)
    composed = Image.alpha_composite(bg_img, mark)

    sq = make_squircle_alpha(SS, n=5.0)
    composed.putalpha(Image.fromarray((sq * 255).astype(np.uint8), mode="L"))

    final = composed.resize((OUT, OUT), Image.Resampling.LANCZOS)

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    final.save(output_path, "PNG")
    print(f"wrote {output_path}")


if __name__ == "__main__":
    main("/tmp/agy-sluice-icon.png")
