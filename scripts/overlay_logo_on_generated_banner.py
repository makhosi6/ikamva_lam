#!/usr/bin/env python3
"""Replace the left squircle artwork on branding/Generated_image.png with branding/logo.png."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
BANNER = ROOT / "branding" / "Generated_image.png"
LOGO = ROOT / "branding" / "logo.png"

# 1376×768 reference: squircle position from raster (warm plate interior ~247,243,231).
BADGE_SIDE = 326
BADGE_CX = 241
BADGE_CY = 383
# Plate fill matches the original banner’s off-white tile (not pure #fff).
PLATE_RGB = (247, 243, 231)
BADGE_INNER_PAD = 26
CORNER_FRAC = 0.26


def _load_generate_cover():
    path = ROOT / "scripts" / "generate_cover.py"
    spec = importlib.util.spec_from_file_location("generate_cover", path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader
    spec.loader.exec_module(mod)
    return mod


def main() -> int:
    if not BANNER.is_file():
        print(f"Missing {BANNER}", file=sys.stderr)
        return 1
    if not LOGO.is_file():
        print(f"Missing {LOGO}", file=sys.stderr)
        return 1

    gc = _load_generate_cover()
    base = Image.open(BANNER).convert("RGBA")

    logo = Image.open(LOGO).convert("RGBA")
    logo = gc._replace_near_solid_colors(
        logo,
        gc.LOGO_CANVAS_COLORS,
        gc.LOGO_CANVAS_REPLACE_THRESH,
        replacement=PLATE_RGB,
    )

    corner_r = max(32, int(BADGE_SIDE * CORNER_FRAC))
    badge = gc._compose_rounded_badge(
        logo,
        BADGE_SIDE,
        BADGE_INNER_PAD,
        corner_r,
        plate_rgb=PLATE_RGB,
    )

    bx = BADGE_CX - BADGE_SIDE // 2
    by = BADGE_CY - BADGE_SIDE // 2
    base.alpha_composite(badge, (bx, by))
    base.convert("RGB").save(BANNER, "PNG", optimize=True)
    print(f"Updated {BANNER}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
