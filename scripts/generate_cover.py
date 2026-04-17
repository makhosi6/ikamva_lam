#!/usr/bin/env python3
"""Build branding/cover.png: logo (left) + title/tagline (right). Run from repo root on macOS."""

from __future__ import annotations

import sys
import textwrap
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
LOGO = ROOT / "branding" / "logo.png"
OUT_REPO = ROOT / "branding" / "cover.png"
OUT_APP = ROOT / "learner_app" / "assets" / "branding" / "cover.png"

W, H = 1200, 630
LEFT_W = 420
# Left: warmer beige (darker than logo canvas); right: off-white — match reference banner.
LEFT_BG = (239, 230, 213)  # #EFE6D5
RIGHT_BG = (251, 249, 242)  # #FBF9F2
LEFT_OUTER_PAD = 48
BADGE_INNER_PAD = 28
TEXT_INSET_X = 28
TEXT_INSET_RIGHT = 28
TITLE_TAG_GAP = 42
TAG_LINE_GAP = 10
TITLE_FONT_SIZE = 108
TAG_FONT_SIZE = 38
TITLE_COLOR = (32, 31, 30)  # #201F1E warm charcoal
TAG_COLOR = (92, 88, 79)  # #5C584F muted brown-grey

TITLE = "Ikamva Lam"
TAGLINE = "My future — playful English practice"

# Title + tagline: Nunito variable TTF in repo.
FONT_NUNITO = ROOT / "branding" / "fonts" / "Nunito[wght].ttf"
# Flat logo canvas → white so the mark sits cleanly on the white squircle.
LOGO_CANVAS_COLORS = (
    (246, 241, 231),  # #F6F1E7
    (245, 242, 233),  # #F5F2E9
)
LOGO_CANVAS_REPLACE_THRESH = 20


def _load_nunito(size: int, variation_name: str) -> ImageFont.FreeTypeFont:
    font = ImageFont.truetype(str(FONT_NUNITO), size)
    font.set_variation_by_name(variation_name)
    return font


def _rounded_rect_mask(size: tuple[int, int], radius: int) -> Image.Image:
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return m


def _replace_near_solid_colors(
    im: Image.Image,
    targets: tuple[tuple[int, int, int], ...],
    thresh: int,
    replacement: tuple[int, int, int] = (255, 255, 255),
) -> Image.Image:
    rgba = im.convert("RGBA")
    px = rgba.load()
    w, h = rgba.size
    t2 = thresh * thresh
    rr, rg, rb = replacement
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            for tr, tg, tb in targets:
                d = (r - tr) * (r - tr) + (g - tg) * (g - tg) + (b - tb) * (b - tb)
                if d <= t2:
                    px[x, y] = (rr, rg, rb, a)
                    break
    return rgba


def _compose_rounded_badge(
    logo_rgba: Image.Image,
    badge_side: int,
    inner_pad: int,
    corner_radius: int,
    *,
    plate_rgb: tuple[int, int, int] = (255, 255, 255),
) -> Image.Image:
    """Squircle plate + logo; outer edge clipped to rounded rect (app-icon style)."""
    badge = Image.new("RGBA", (badge_side, badge_side), (0, 0, 0, 0))
    draw = ImageDraw.Draw(badge)
    pr, pg, pb = plate_rgb
    draw.rounded_rectangle(
        (0, 0, badge_side - 1, badge_side - 1),
        radius=corner_radius,
        fill=(pr, pg, pb, 255),
    )
    max_logo = badge_side - 2 * inner_pad
    lw, lh = logo_rgba.size
    scale = min(max_logo / lw, max_logo / lh, 1.0)
    nw, nh = int(lw * scale), int(lh * scale)
    lm = logo_rgba.resize((nw, nh), Image.Resampling.LANCZOS)
    ox = (badge_side - nw) // 2
    oy = (badge_side - nh) // 2
    badge.alpha_composite(lm, (ox, oy))
    mask = _rounded_rect_mask((badge_side, badge_side), corner_radius)
    r, g, b, a = badge.split()
    a = ImageChops.multiply(a, mask)
    return Image.merge("RGBA", (r, g, b, a))


def main() -> int:
    if not LOGO.is_file():
        print(f"Missing {LOGO}", file=sys.stderr)
        return 1

    if not FONT_NUNITO.is_file():
        print(f"Missing font {FONT_NUNITO}", file=sys.stderr)
        return 1

    logo = Image.open(LOGO).convert("RGBA")
    logo = _replace_near_solid_colors(logo, LOGO_CANVAS_COLORS, LOGO_CANVAS_REPLACE_THRESH)

    canvas = Image.new("RGB", (W, H), RIGHT_BG)
    draw = ImageDraw.Draw(canvas)

    draw.rectangle((0, 0, LEFT_W, H), fill=LEFT_BG)

    badge_side = min(LEFT_W - 2 * LEFT_OUTER_PAD, H - 2 * LEFT_OUTER_PAD)
    corner_radius = max(32, int(badge_side * 0.26))
    badge = _compose_rounded_badge(logo, badge_side, BADGE_INNER_PAD, corner_radius)
    bx = (LEFT_W - badge_side) // 2
    by = (H - badge_side) // 2
    # Paste RGBA so rounded corners stay anti-aliased (RGB convert would fringe with black).
    layer = canvas.convert("RGBA")
    layer.paste(badge, (bx, by), badge)
    canvas = layer.convert("RGB")
    # Must redraw on the image we save (draw was bound to the pre-badge buffer).
    draw = ImageDraw.Draw(canvas)

    title_font = _load_nunito(TITLE_FONT_SIZE, "Black")
    tag_font = _load_nunito(TAG_FONT_SIZE, "Medium")

    margin_x = LEFT_W + TEXT_INSET_X
    text_max_w = W - margin_x - TEXT_INSET_RIGHT

    approx_chars = max(18, int(text_max_w / 22))
    wrapped = textwrap.fill(TAGLINE, width=approx_chars)
    tag_lines = wrapped.split("\n")

    title_bbox = draw.textbbox((0, 0), TITLE, font=title_font)
    title_h = title_bbox[3] - title_bbox[1]
    tag_h = 0
    line_heights = []
    for line in tag_lines:
        bb = draw.textbbox((0, 0), line, font=tag_font)
        h = bb[3] - bb[1]
        line_heights.append(h)
        tag_h += h + TAG_LINE_GAP
    if tag_lines:
        tag_h -= TAG_LINE_GAP
    block_h = title_h + TITLE_TAG_GAP + tag_h
    y = (H - block_h) // 2

    draw.text((margin_x, y), TITLE, font=title_font, fill=TITLE_COLOR)
    y += title_h + TITLE_TAG_GAP
    for line, lh in zip(tag_lines, line_heights):
        draw.text((margin_x, y), line, font=tag_font, fill=TAG_COLOR)
        y += lh + TAG_LINE_GAP

    OUT_REPO.parent.mkdir(parents=True, exist_ok=True)
    OUT_APP.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(OUT_REPO, "PNG", optimize=True)
    canvas.save(OUT_APP, "PNG", optimize=True)
    print(f"Wrote {OUT_REPO} and {OUT_APP}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
