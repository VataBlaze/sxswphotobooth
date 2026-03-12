#!/usr/bin/env python3
"""
generate-frame.py — Creates vaporwave-btc-frame.png

Generates a transparent-center PNG frame overlay with:
  - Neon grid border lines
  - Palm tree silhouette (bottom-left corner)
  - ₿ logo (bottom-right corner)
  - "STACK SATS" text (top-right corner)
  - Scanline texture at ~10% opacity across the full frame

Output: 1920×1280 px (3:2 aspect, matches Pi Camera Module 3 stills)
        If your camera is 16:9, change to 1920×1080 below.

Usage:
  pip install Pillow --break-system-packages
  python3 scripts/generate-frame.py

Outputs to: ~/photobooth-data/userdata/frames/vaporwave-btc-frame.png
            (also saves a copy in ./userdata/frames/ in the repo)
"""

import math
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# ── Configuration ──────────────────────────────────────────────────
WIDTH  = 1920
HEIGHT = 1280   # Change to 1080 for 16:9 cameras

BORDER = 60     # px thickness of the neon border zone

# Colors (RGBA)
TRANSPARENT = (0, 0, 0, 0)
PINK    = (255, 110, 199)
CYAN    = (0, 240, 255)
BTC     = (247, 147, 26)
MAGENTA = (255, 0, 255)
GREEN   = (0, 255, 65)

# Output paths
REPO_OUT = Path(__file__).resolve().parent.parent / "userdata" / "frames" / "vaporwave-btc-frame.png"
DATA_OUT = Path.home() / "photobooth-data" / "userdata" / "frames" / "vaporwave-btc-frame.png"


def draw_grid_border(draw, w, h, border):
    """Draw neon grid lines around the border of the frame."""
    # Outer border glow lines
    for i in range(3):
        offset = i * 3
        alpha = 200 - i * 60
        color = (*CYAN, alpha)
        draw.rectangle(
            [offset, offset, w - 1 - offset, h - 1 - offset],
            outline=color, width=2,
        )

    # Inner border (thicker, pink)
    draw.rectangle(
        [border - 4, border - 4, w - border + 3, h - border + 3],
        outline=(*PINK, 180), width=2,
    )

    # Grid lines within the border zone (perspective grid effect)
    # Horizontal grid lines in top and bottom borders
    for y in range(0, border, 12):
        draw.line([(0, y), (w, y)], fill=(*MAGENTA, 40), width=1)
        draw.line([(0, h - y), (w, h - y)], fill=(*MAGENTA, 40), width=1)

    # Vertical grid lines in left and right borders
    for x in range(0, border, 12):
        draw.line([(x, 0), (x, h)], fill=(*MAGENTA, 40), width=1)
        draw.line([(w - x, 0), (w - x, h)], fill=(*MAGENTA, 40), width=1)

    # Corner accent brackets
    bracket_len = 80
    bracket_w = 3
    corners = [
        (border, border),                   # top-left
        (w - border, border),               # top-right
        (border, h - border),               # bottom-left
        (w - border, h - border),           # bottom-right
    ]
    for cx, cy in corners:
        # Determine direction of bracket arms
        dx = 1 if cx < w // 2 else -1
        dy = 1 if cy < h // 2 else -1
        draw.line([(cx, cy), (cx + dx * bracket_len, cy)], fill=(*CYAN, 220), width=bracket_w)
        draw.line([(cx, cy), (cx, cy + dy * bracket_len)], fill=(*CYAN, 220), width=bracket_w)


def draw_palm_silhouette(draw, x, y, scale=1.0):
    """Draw a simplified palm tree silhouette at (x, y) base."""
    # Trunk
    trunk_color = (*PINK, 100)
    tw = int(8 * scale)
    th = int(120 * scale)
    draw.polygon([
        (x - tw, y),
        (x + tw, y),
        (x + tw // 2, y - th),
        (x - tw // 2, y - th),
    ], fill=trunk_color)

    # Fronds (radiating lines from top of trunk)
    top = (x, y - th)
    frond_color = (*PINK, 80)
    frond_len = int(90 * scale)
    for angle_deg in [-140, -120, -100, -80, -60, -40]:
        angle = math.radians(angle_deg)
        ex = top[0] + int(frond_len * math.cos(angle))
        ey = top[1] + int(frond_len * math.sin(angle))
        draw.line([top, (ex, ey)], fill=frond_color, width=int(3 * scale))
        # Leaf droop
        droop_x = ex + int(20 * scale * math.cos(angle + 0.5))
        droop_y = ey + int(30 * scale)
        draw.line([(ex, ey), (droop_x, droop_y)], fill=frond_color, width=int(2 * scale))


def draw_bitcoin_logo(draw, cx, cy, size):
    """Draw a simplified ₿ symbol."""
    color = (*BTC, 200)
    glow = (*BTC, 80)

    # Glow circle
    r = size
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=glow, width=3)

    # ₿ character — use a basic font or draw manually
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", size)
    except OSError:
        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf", size)
        except OSError:
            font = ImageFont.load_default()

    # Draw the ₿ centered
    text = "₿"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text((cx - tw // 2, cy - th // 2 - bbox[1]), text, fill=color, font=font)


def draw_text_label(draw, x, y, text, color, size=24, anchor="lt"):
    """Draw pixel-style text. Falls back to default font."""
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", size)
    except OSError:
        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/noto/NotoSansMono-Bold.ttf", size)
        except OSError:
            font = ImageFont.load_default()
    # Glow layer
    for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        draw.text((x + dx, y + dy), text, fill=(*color, 60), font=font)
    draw.text((x, y), text, fill=(*color, 200), font=font)


def apply_scanlines(img, opacity=25):
    """Overlay horizontal scanlines at given opacity (0-255)."""
    scanline = Image.new("RGBA", (img.width, img.height), TRANSPARENT)
    sd = ImageDraw.Draw(scanline)
    for y in range(0, img.height, 4):
        sd.line([(0, y), (img.width, y)], fill=(0, 0, 0, opacity), width=1)
    return Image.alpha_composite(img, scanline)


def main():
    print(f"Generating frame overlay: {WIDTH}×{HEIGHT} px")

    img = Image.new("RGBA", (WIDTH, HEIGHT), TRANSPARENT)
    draw = ImageDraw.Draw(img)

    # 1. Fill the border zone with a semi-transparent dark gradient
    #    (the center stays fully transparent)
    border_layer = Image.new("RGBA", (WIDTH, HEIGHT), TRANSPARENT)
    bd = ImageDraw.Draw(border_layer)

    # Top border
    for y in range(BORDER):
        alpha = int(180 * (1 - y / BORDER))
        bd.line([(0, y), (WIDTH, y)], fill=(10, 5, 30, alpha))
    # Bottom border
    for y in range(HEIGHT - BORDER, HEIGHT):
        alpha = int(180 * ((y - (HEIGHT - BORDER)) / BORDER))
        bd.line([(0, y), (WIDTH, y)], fill=(10, 5, 30, alpha))
    # Left border
    for x in range(BORDER):
        alpha = int(140 * (1 - x / BORDER))
        bd.line([(x, 0), (x, HEIGHT)], fill=(10, 5, 30, alpha))
    # Right border
    for x in range(WIDTH - BORDER, WIDTH):
        alpha = int(140 * ((x - (WIDTH - BORDER)) / BORDER))
        bd.line([(x, 0), (x, HEIGHT)], fill=(10, 5, 30, alpha))

    img = Image.alpha_composite(img, border_layer)
    draw = ImageDraw.Draw(img)

    # 2. Neon grid border
    draw_grid_border(draw, WIDTH, HEIGHT, BORDER)

    # 3. Palm silhouette — bottom-left corner
    draw_palm_silhouette(draw, x=100, y=HEIGHT - 15, scale=1.4)
    draw_palm_silhouette(draw, x=180, y=HEIGHT - 15, scale=1.0)

    # 4. ₿ logo — bottom-right corner
    draw_bitcoin_logo(draw, cx=WIDTH - 100, cy=HEIGHT - 80, size=50)

    # 5. "STACK SATS" — top-right
    draw_text_label(draw, x=WIDTH - 280, y=15, text="STACK SATS", color=BTC, size=20)

    # 6. "21M" — top-left
    draw_text_label(draw, x=18, y=15, text="21M", color=CYAN, size=20)

    # 7. Scanlines across entire frame
    img = apply_scanlines(img, opacity=20)

    # ── Save ──
    for out_path in [REPO_OUT, DATA_OUT]:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        img.save(str(out_path), "PNG")
        print(f"  Saved: {out_path}")

    print("\n  Frame overlay generated successfully.")
    print("  The CSS rule in private.css (#preview-stream::after) already")
    print("  references this file. Refresh the photobooth to see it.\n")


if __name__ == "__main__":
    main()
