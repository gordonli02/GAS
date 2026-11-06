"""Puts the redrawn tier symbols into the core pack (G, after M8.6: the code-drawn symbols were
too crude).

Seven forms have pictures made outside the code. Six were painted by GPT image from the prompts
G ran (kept untouched in docs/art_redo/gpt/<form>/<key>.png); Lucky Spur is the redraw in
docs/art_redo/6_jsr_spur/ (SVG written by draw.py there, turned into PNG by docs/art_redo/render.py).
Nugget Rush still has the code-drawn nuggets of tools/make_ticket_art.py.

    python tools/import_symbol_art.py            # writes packs/core/art/<key>.png and <key>_large.png
    python tools/import_symbol_art.py --sheet    # also docs/art_redo/symbols.png, every symbol on one page

Each source picture is trimmed to what is drawn, fitted into a square with the same margin for
every symbol and saved twice, as the game expects: <key>_large.png (1024 px) and <key>.png (512 px).
To change a symbol, replace its source picture (square or not, transparent background) and run this
again. Needs Pillow.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "packs", "core", "art")
REDO = os.path.join(ROOT, "docs", "art_redo")
FILL = 0.90  # the longer side of the drawing, as a share of the square

# form id: (source folder under docs/art_redo, its tier keys)
SOURCES = {
    "catch": ("gpt/catch", ["walleye", "bobber", "boot", "worm"]),
    "plate": ("gpt/plate", ["egg", "stack", "mug", "pie"]),
    "spur": ("6_jsr_spur", ["shoe", "star", "hat", "cactus"]),
    "order": ("gpt/order", ["rooster", "hen", "chick", "whole_egg"]),
    "kabawk": ("gpt/kabawk", ["bomb", "c4", "grenade", "shell"]),
    "flock": ("gpt/flock", ["uncle", "liberty", "bell", "rocket"]),
    "peckeye": ("gpt/peckeye", ["sailor", "spinach", "anchor", "pipe"]),
}
# Front pictures built from a symbol's source: name: (source, pixel size, height as a share of the
# box, where its middle sits across the box). The picture stands on the bottom edge of its box, as
# the code-drawn one did. Peckeye's box reaches up behind the title, so the sailor stays below it.
HEROES = {"peckeye_hero": ("gpt/peckeye/sailor.png", (1032, 888), 0.82, 0.57)}


def trimmed(path):
    """The picture cut down to what is drawn, with nearly solid pixels made solid (GPT image
    leaves its solid areas at alpha 253 or 254)."""
    im = Image.open(path).convert("RGBA")
    alpha = im.getchannel("A").point(lambda v: 255 if v >= 250 else v)
    im.putalpha(alpha)
    return im.crop(alpha.point(lambda v: 255 if v > 16 else 0).getbbox())


def fitted(im, size, fill=FILL):
    scale = fill * size / max(im.size)
    w, h = max(1, round(im.size[0] * scale)), max(1, round(im.size[1] * scale))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(im.resize((w, h), Image.LANCZOS), ((size - w) // 2, (size - h) // 2))
    return out


def main():
    count = 0
    for form, (folder, keys) in SOURCES.items():
        for key in keys:
            im = trimmed(os.path.join(REDO, folder, key + ".png"))
            fitted(im, 1024).save(os.path.join(ART, key + "_large.png"))
            fitted(im, 512).save(os.path.join(ART, key + ".png"))
            count += 2
    for name, (src, (w, h), share, middle) in HEROES.items():
        im = trimmed(os.path.join(REDO, src))
        scale = min(w / im.size[0], share * h / im.size[1])
        im = im.resize((round(im.size[0] * scale), round(im.size[1] * scale)), Image.LANCZOS)
        out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        out.alpha_composite(im, (min(w - im.size[0], max(0, round(w * middle - im.size[0] / 2))), h - im.size[1]))
        out.save(os.path.join(ART, name + ".png"))
        count += 1
    if "--sheet" in sys.argv:
        cell, cols = 256, 4
        keys = [k for _, ks in SOURCES.values() for k in ks]
        rows = (len(keys) + cols - 1) // cols
        sheet = Image.new("RGBA", (cols * cell * 2, rows * cell), "#8fa3ad")
        for i, key in enumerate(keys):
            # the large one filling its cell, and beside it the small one at about the printed size
            x, y = (i % cols) * cell * 2, (i // cols) * cell
            sheet.alpha_composite(Image.open(os.path.join(ART, key + "_large.png")).resize((cell, cell), Image.LANCZOS), (x, y))
            small = Image.open(os.path.join(ART, key + ".png")).resize((64, 64), Image.LANCZOS)
            sheet.alpha_composite(small, (x + cell + 32, y + (cell - 64) // 2))
        sheet.convert("RGB").save(os.path.join(REDO, "symbols.png"))
    print("wrote %d images" % count)


if __name__ == "__main__":
    main()
