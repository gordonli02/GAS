"""Cuts the bundled CJK fonts down to the characters the game's Chinese text uses.

The engine's Latin fonts fall back to these for Chinese (src/ui/lang.gd):
  assets/fonts/cjk-pixel.woff2       from Fusion Pixel Font 12px proportional, zh_hans (OFL)
  assets/fonts/cjk-pixel-lcd.woff2   the same, sized to VT323's capitals ("match" look)
  assets/fonts/cjk-pixel-cond.woff2  the same, sized to Oswald's capitals ("match" look)
  assets/fonts/cjk-hand.woff2        from LXGW WenKai Regular (OFL)

Characters: every non-ASCII character in locale/ui.csv and in src/ui/lang.gd (the language
names on the menu keys), plus common Chinese punctuation.
Run it again whenever locale/ui.csv gains new characters (tests/test_locale.gd checks
the fonts cover the table). The subsets get their own family names, as the OFL asks of
modified versions (LXGW WenKai reserves its name).

  pip install fonttools brotli
  python tools/subset_cjk_fonts.py <fusion-pixel-12px-proportional-zh_hans.otf.woff2> <LXGWWenKai-Regular.ttf>

Sources: https://github.com/TakWolf/fusion-pixel-font/releases (2026.10.25)
         https://github.com/lxgw/LxgwWenKai/releases (v1.530)
"""
import csv
import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PUNCT = "，。、：；！？（）《》「」『』“”‘’…—·～￥％"
## The pixel font's Chinese ink runs from -100 to 1000 units (of 1200): one grid row
## below the baseline to ten above. Lifted by one row it sits on the baseline, and scaled
## by cap height / 1100 its top meets the Latin capitals.
PIXEL_INK = 1100.0
VT323_CAPS = 0.56
OSWALD_CAPS = 0.81
## (file, family, source (0 pixel, 1 hand), scale, lift in source units)
## "cjk-pixel": G's M6 review, a quarter under full size. "-lcd" / "-cond": Chinese as
## tall as the capitals of VT323 / Oswald, sitting on the same baseline.
OUT = [
    ("cjk-pixel.woff2", "Last Sale CJK Pixel", 0, 0.75, 0),
    ("cjk-pixel-lcd.woff2", "Last Sale CJK Pixel LCD", 0, VT323_CAPS * 1200 / PIXEL_INK, 100),
    ("cjk-pixel-cond.woff2", "Last Sale CJK Pixel Cond", 0, OSWALD_CAPS * 1200 / PIXEL_INK, 100),
    ("cjk-hand.woff2", "Last Sale CJK Hand", 1, 1.0, 0),
]


def characters() -> str:
    chars = set(PUNCT)
    with open(os.path.join(ROOT, "locale", "ui.csv"), encoding="utf-8") as f:
        for row in csv.reader(f):
            for cell in row[1:]:
                chars.update(c for c in cell if ord(c) > 127)
    with open(os.path.join(ROOT, "src", "ui", "lang.gd"), encoding="utf-8") as f:
        chars.update(c for c in f.read() if ord(c) > 0x2E7F)
    return "".join(sorted(chars))


def lift(font: TTFont, dy: int) -> None:
    """Moves every CFF outline up by dy units (advances unchanged)."""
    from fontTools.pens.t2CharStringPen import T2CharStringPen
    from fontTools.pens.transformPen import TransformPen
    cff = font["CFF "].cff
    top = cff.topDictIndex[0]
    glyphs = font.getGlyphSet()
    new = {}
    for name in font.getGlyphOrder():
        pen = T2CharStringPen(None, glyphs)
        glyphs[name].draw(TransformPen(pen, (1, 0, 0, 1, 0, dy)))
        new[name] = pen.getCharString(private=top.Private, globalSubrs=cff.GlobalSubrs)
    for name, cs in new.items():
        top.CharStrings[name] = cs


def cut(src: str, dst: str, family: str, scale: float, dy: int, text: str) -> None:
    font = TTFont(src)
    opts = subset.Options()
    opts.flavor = "woff2"
    opts.layout_features = ["*"]
    opts.name_IDs = ["*"]
    opts.notdef_outline = True
    s = subset.Subsetter(opts)
    s.populate(text=text)
    s.subset(font)
    names = font["name"]
    for rec in list(names.names):
        if rec.nameID in (1, 4, 16, 21):
            names.setName(family, rec.nameID, rec.platformID, rec.platEncID, rec.langID)
        elif rec.nameID in (3, 6, 20):
            names.setName(family.replace(" ", "") + "-Regular", rec.nameID, rec.platformID, rec.platEncID, rec.langID)
    if dy:
        lift(font, dy)
    if scale != 1.0:
        # A bigger em with the outlines unchanged draws every glyph smaller.
        font["head"].unitsPerEm = round(font["head"].unitsPerEm / scale)
    font.flavor = "woff2"
    font.save(dst)
    print("%s: %d characters, %d bytes" % (os.path.basename(dst), len(text), os.path.getsize(dst)))


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    text = characters()
    for name, family, source, scale, dy in OUT:
        cut(sys.argv[1 + source], os.path.join(ROOT, "assets", "fonts", name), family, scale, dy, text)


if __name__ == "__main__":
    main()
