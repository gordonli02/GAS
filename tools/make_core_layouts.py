"""Writes packs/core/layouts/{single,windows,plate,jar}.json.

The numbers of single, windows and jar are taken from the web build's canvas drawing code
(reference/last-sale-source.html: drawFront, drawFrontWide, drawInterior, drawInteriorWide,
drawFlap, drawTab, drawJarCover, band). Hot Plate left the web build's tall card for a square
one (G, after M8.6): `plate` is its layout. `windows` stays the built-in tall five-window card
("core:windows" for other packs); the M8.6 forms are built on it (tools/make_new_forms.py).
Run: python tools/make_core_layouts.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INK, STOCK, BLACK, YEL, DIG = "#494642", "#f4f0e5", "#111111", "#ffe600", "#3b3a39"


def T(text, pos, font, size, fill=BLACK, align="center", max_width=None, **kw):
    d = {"type": "text", "text": text, "pos": pos, "font": font, "size": size}
    if fill:
        d["fill"] = fill
    d["align"] = align
    if max_width:
        d["max_width"] = max_width
    d.update(kw)
    return d


def R(rect, fill, **kw):
    return dict({"type": "rect", "rect": rect, "fill": fill}, **kw)


def perf(a, b, color, **kw):
    return dict({"type": "path", "points": [a, b], "stroke": color, "width": 2, "dash": [7, 6]}, **kw)


def title(cx, cy, size, stroke_w, max_w, shift):
    return [
        T("{title}", [cx, cy], "slab", size, fill=None, stroke="#ffffff", stroke_width=stroke_w, max_width=max_w),
        T("{title}", [cx + shift, cy + shift], "slab", size, fill="tile.1", max_width=max_w),
        T("{title}", [cx, cy], "slab", size, fill="ink", max_width=max_w),
    ]


def bubbles(base, sx, sy, rx, ry):
    # x + base + k%3*sx, y + base + (k>>1)*sy, rotated k radians
    return [{"type": "ellipse", "center": [base + (k % 3) * sx, base + (k >> 1) * sy], "radii": [rx, ry],
             "rotation": k, "fill": "#ffffff2e"} for k in range(6)]


def r4(v):
    return round(v, 4)


tall_front = [
    R([0, 0, 420, 600], "edge"), R([20, 20, 380, 122], "head"),
    R([20, 20, 20, 10], "tile.0", repeat={"count": 9, "step": [43, 0]}),
    *title(210, 104, 62, 11, 356, 4),
    {"type": "each_tier", "origin": [20, 152], "columns": 2, "step": [192, 176], "layers": [
        R([0, 0, 188, 170], "tile"),
        {"type": "group", "clip": [0, 0, 188, 120], "layers": bubbles(18, 72, 46, 24, 16)},
        {"type": "symbol", "center": [94, 60], "size": 120},
        R([0, 120, 188, 50], YEL),
        T("{count} WIN", [34, 153], "cond_bold", 16, max_width=54),
        T("${tier_prize}", [126, 159], "slab", 36, max_width=120)]},
    R([20, 508, 380, 74], YEL),
    T("${price}", [32, 568], "slab", 50, align="left"),
    T("INSTANT WINNERS SHOWN ABOVE.", [386, 523], "cond_bold", 14, align="right", max_width=248),
    T("PAYABLE IN EGG MONEY.", [386, 539], "cond_bold", 14, align="right", max_width=248),
    T("©Ben Kraptu apt.   FORM {code}", [386, 555], "cond", 14, align="right", max_width=248),
    T("SERIAL NO. {serial}", [386, 577], "lcd", 24, align="right", max_width=248),
]

single = {
    "format": 1,
    "card": {"size": [1.4, 2.0], "canvas": [420, 600]},
    "front": tall_front,
    "interior": {
        "base": [
            R([0, 0, 420, 600], "#ece7da"), R([16, 16, 388, 568], STOCK),
            perf([16, 16], [404, 16], "#8f8b82"), perf([404, 16], [404, 584], "#8f8b82"),
            perf([16, 584], [404, 584], "#8f8b82"),
            T("PAYABLE IN EGG MONEY", [210, 576], "cond_bold", 12, fill="#5c5850")],
        "slots": [{"anchor": [210, 132]}, {"anchor": [210, 304]}, {"anchor": [210, 476]}],
        "digits": {"direction": "row", "pitch": 84, "color": DIG,
                   "digit": {"font": "slab", "size": 98, "offset": [0, -6]},
                   "caption": {"font": "cond_bold", "size": 15, "offset": [0, 13], "max_width": 68},
                   "mark": {"font": "cond_bold", "size": 15, "offset": [33, -76]}},
        "winner": [
            R([46, 44, 328, 416], "win_tile"),
            {"type": "circle", "center": [210, 236], "radius": 146, "fill": "#ffffff30"},
            {"type": "symbol", "tier": "win", "variant": "large", "center": [210, 236], "size": 268.8},
            R([46, 460, 328, 92], YEL),
            T("${prize}", [210, 534], "slab", 74, max_width=300),
            T("VERIFY {verify}", [210, 66], "lcd", 22, fill="#ffffff", **{"if": "verify"})]},
    "flaps": [{"rect": [16, 16, 388, 568], "hinge": "left", "cover": {"canvas": [400, 572], "layers": [
        R([0, 0, 400, 572], STOCK),
        {"type": "path", "points": [[34, 86], [254, 86], [254, 42], [374, 152], [254, 262], [254, 218], [34, 218]],
         "closed": True, "stroke": INK, "width": 6, "join": "miter"},
        T("OPEN", [164, 144], "slab", 52, fill=INK), T("HERE", [164, 202], "slab", 52, fill=INK),
        {"type": "circle", "center": [200, 392], "radius": 86, "fill": INK},
        {"type": "circle", "center": [200, 392], "radius": 70, "fill": STOCK},
        T("BK", [200, 418], "slab", 74, fill=INK),
        T("©Ben Kraptu apt.", [200, 512], "cond_bold", 24, fill=INK),
        T("PAYABLE IN EGG MONEY", [200, 540], "cond", 16, fill=INK)]}}],
    "pairs": "none",
    "band": None,
    "reveal_slide": [0.36, 0],
}

ROWS = [16 + r * 115.2 for r in range(5)]
windows = {
    "format": 1,
    "card": {"size": [1.4, 2.0], "canvas": [420, 600]},
    "front": tall_front,
    "interior": {
        "base": [
            R([0, 0, 420, 600], "#ece7da"), R([16, 16, 388, 568], STOCK),
            R([16, 123.2, 388, 8], "#ece7da", repeat={"count": 4, "step": [0, 115.2]}),
            perf([16, 16], [404, 16], "#8f8b82", repeat={"count": 5, "step": [0, 115.2]}),
            perf([404, 16], [404, 123.2], "#8f8b82", repeat={"count": 5, "step": [0, 115.2]}),
            perf([16, 123.2], [404, 123.2], "#8f8b82", repeat={"count": 5, "step": [0, 115.2]})],
        "slots": [{"rect": [16, r4(t), 388, 107.2], "anchor": [210, r4(t + 53.6 + 22)]} for t in ROWS],
        # The web build draws these rows at scale 0.66 with a minimum text size of 11.
        "digits": {"direction": "row", "pitch": 55.44, "color": DIG,
                   "digit": {"font": "slab", "size": 64.68, "offset": [0, -3.96]},
                   "caption": {"font": "cond_bold", "size": 11, "offset": [0, 8.58], "max_width": 44.88},
                   "mark": {"font": "cond_bold", "size": 11, "offset": [21.78, -50.16]}},
        "win_slot": [
            R([12, 6, 364, 95.2], "win_tile"),
            {"type": "symbol", "tier": "win", "center": [86, 53.6], "size": 91.2},
            R([160, 6, 216, 95.2], YEL),
            T("${prize}", [268, 73.6], "slab", 54, max_width=196)]},
    "cover_templates": {"tab": {"canvas": [400, 111], "layers": [
        R([0, 0, 400, 111], STOCK),
        {"type": "path", "points": [[140, 38], [296, 38], [296, 18], [366, 55], [296, 92], [296, 72], [140, 72]],
         "closed": True, "stroke": INK, "width": 4, "join": "miter"},
        T("PULL", [216, 66], "slab", 27, fill=INK),
        T("{flap_no}", [72, 76], "slab", 58, fill=INK)]}},
    "flaps": [{"rect": [16, r4(t), 388, 107.2], "hinge": "left", "cover": "tab"} for t in ROWS],
    "pairs": "adjacent",
    "band": None,
    "reveal_slide": [0.36, 0],
}

# Hot Plate's square card: the same five windows, wider and lower, and a front of its own with
# each picture beside its prize.
SQ, SQ_STEP, SQ_ROW = 510, 97.2, 89.2
SQ_ROWS = [16 + r * SQ_STEP for r in range(5)]
square_front = [
    R([0, 0, SQ, SQ], "edge"), R([20, 20, 470, 96], "head"),
    R([20, 20, 20, 10], "tile.0", repeat={"count": 11, "step": [45, 0]}),
    *title(255, 97, 60, 11, 440, 4),
    {"type": "each_tier", "origin": [20, 122], "columns": 2, "step": [237, 142], "layers": [
        R([0, 0, 233, 138], "tile"),
        {"type": "group", "clip": [0, 0, 128, 138], "layers": bubbles(18, 46, 50, 22, 15)},
        {"type": "symbol", "center": [64, 69], "size": 122},
        R([128, 0, 105, 138], YEL),
        T("{count} WIN", [180.5, 50], "cond_bold", 18, max_width=92),
        T("${tier_prize}", [180.5, 100], "slab", 40, max_width=96)]},
    R([20, 408, 470, 82], YEL),
    T("${price}", [32, 476], "slab", 54, align="left"),
    T("INSTANT WINNERS SHOWN ABOVE.", [476, 426], "cond_bold", 14, align="right", max_width=320),
    T("PAYABLE IN EGG MONEY.", [476, 442], "cond_bold", 14, align="right", max_width=320),
    T("©Ben Kraptu apt.   FORM {code}", [476, 458], "cond", 14, align="right", max_width=320),
    T("SERIAL NO. {serial}", [476, 481], "lcd", 24, align="right", max_width=320),
]

plate = {
    "format": 1,
    "card": {"size": [1.7, 1.7], "canvas": [SQ, SQ]},
    "front": square_front,
    "interior": {
        "base": [
            R([0, 0, SQ, SQ], "#ece7da"), R([16, 16, 478, 478], STOCK),
            R([16, 16 + SQ_ROW, 478, 8], "#ece7da", repeat={"count": 4, "step": [0, SQ_STEP]}),
            perf([16, 16], [494, 16], "#8f8b82", repeat={"count": 5, "step": [0, SQ_STEP]}),
            perf([494, 16], [494, 16 + SQ_ROW], "#8f8b82", repeat={"count": 5, "step": [0, SQ_STEP]}),
            perf([16, 16 + SQ_ROW], [494, 16 + SQ_ROW], "#8f8b82", repeat={"count": 5, "step": [0, SQ_STEP]})],
        "slots": [{"rect": [16, r4(t), 478, SQ_ROW], "anchor": [255, r4(t + SQ_ROW / 2 + 19)]} for t in SQ_ROWS],
        "digits": {"direction": "row", "pitch": 58, "color": DIG,
                   "digit": {"font": "slab", "size": 54, "offset": [0, -3.3]},
                   "caption": {"font": "cond_bold", "size": 11, "offset": [0, 8], "max_width": 50},
                   "mark": {"font": "cond_bold", "size": 11, "offset": [20, -42]}},
        "win_slot": [
            R([12, 5, 454, 79.2], "win_tile"),
            {"type": "symbol", "tier": "win", "center": [100, 44.6], "size": 78},
            R([200, 5, 266, 79.2], YEL),
            T("${prize}", [333, 62], "slab", 48, max_width=240)]},
    "cover_templates": {"tab": {"canvas": [480, 90], "layers": [
        R([0, 0, 480, 90], STOCK),
        {"type": "path", "points": [[170, 30], [352, 30], [352, 13], [436, 45], [352, 77], [352, 60], [170, 60]],
         "closed": True, "stroke": INK, "width": 4, "join": "miter"},
        T("PULL", [261, 54], "slab", 24, fill=INK),
        T("{flap_no}", [88, 63], "slab", 50, fill=INK)]}},
    "flaps": [{"rect": [16, r4(t), 478, SQ_ROW], "hinge": "left", "cover": "tab"} for t in SQ_ROWS],
    "pairs": "adjacent",
    "band": None,
    "reveal_slide": [0.36, 0],
}

wide_front = [
    R([0, 0, 640, 400], "edge"), R([16, 14, 608, 74], "head"),
    R([16, 14, 22, 8], "tile.0", repeat={"count": 14, "step": [44, 0]}),
    *title(320, 74, 50, 9, 580, 3),
    {"type": "each_tier", "origin": [16, 96], "columns": 4, "step": [153, 0], "layers": [
        R([0, 0, 149, 196], "tile"),
        {"type": "group", "clip": [0, 0, 149, 150], "layers": bubbles(16, 58, 56, 20, 14)},
        {"type": "symbol", "center": [74.5, 72], "size": 115.2},
        R([0, 150, 149, 46], YEL),
        T("{count} WIN", [27, 180], "cond_bold", 14, max_width=44),
        T("${tier_prize}", [98, 185], "slab", 29, max_width=92)]},
    R([16, 300, 608, 86], YEL),
    T("${price}", [30, 364], "slab", 54, align="left"),
    T("INSTANT WINNERS SHOWN ABOVE.", [608, 320], "cond_bold", 15, align="right", max_width=420),
    T("PAYABLE IN EGG MONEY.", [608, 338], "cond_bold", 15, align="right", max_width=420),
    T("©Ben Kraptu apt.   FORM {code}", [608, 356], "cond", 15, align="right", max_width=420),
    T("SERIAL NO. {serial}", [608, 379], "lcd", 24, align="right", max_width=420),
]

JW, JH, TM = 2.12, 1.325, 1.4 * 16 / 420
PX = 640 / JW
jar = {
    "format": 1,
    "card": {"size": [JW, JH], "canvas": [640, 400]},
    "front": wide_front,
    "interior": {
        "base": [
            R([0, 0, 640, 400], "#ece7da"), R([12, 12, 616, 376], STOCK),
            perf([218, 28], [218, 358], "#b9b2a2", repeat={"count": 2, "step": [204, 0]}),
            T("PAYABLE IN EGG MONEY", [320, 376], "cond_bold", 12, fill="#5c5850")],
        # Each column wins on its own (G, M8.5): a column's rect holds its win.
        "slots": [{"rect": [20 + 204 * i, 28, 192, 330], "anchor": [116 + 204 * i, 200]} for i in range(3)],
        "digits": {"direction": "column", "pitch": 84, "color": DIG,
                   "digit": {"font": "slab", "size": 70, "offset": [-14, 24]},
                   "caption": {"font": "cond_bold", "size": 15, "offset": [46, 14], "max_width": 52},
                   "mark": {"font": "cond_bold", "size": 15, "offset": [46, -10]}},
        "win_slot": [
            R([0, 0, 192, 330], "win_tile"),
            {"type": "circle", "center": [96, 112], "radius": 84, "fill": "#ffffff30"},
            {"type": "symbol", "tier": "win", "variant": "large", "center": [96, 112], "size": 168},
            R([0, 222, 192, 108], YEL),
            T("${prize}", [96, 288], "slab", 60, max_width=176),
            T("VERIFY {verify}", [96, 316], "lcd", 20, **{"if": "verify"})]},
    # side_pull: G's change after M3 review: a sideways swipe also opens it, from the bottom corner
    # the hand moves away from.
    "flaps": [{"rect": [r4(TM * PX), r4(TM * PX), r4((JW - 2 * TM) * PX), r4((JH - 2 * TM) * PX)], "hinge": "top",
               "side_pull": True,
               "cover": {"canvas": [612, 372], "layers": [
                   R([0, 0, 612, 372], STOCK),
                   {"type": "circle", "center": [306, 78], "radius": 62, "fill": INK},
                   {"type": "circle", "center": [306, 78], "radius": 50, "fill": STOCK},
                   T("BK", [306, 98], "slab", 52, fill=INK),
                   {"type": "path", "points": [[254, 356], [254, 288], [216, 288], [306, 236], [396, 288], [358, 288], [358, 356]],
                    "closed": True, "stroke": INK, "width": 6, "join": "miter"},
                   T("OPEN", [136, 316], "slab", 44, fill=INK), T("UP", [476, 316], "slab", 44, fill=INK)]}}],
    "pairs": "none",
    # breaks: G's change after M3 review: drag sideways to slide it off, or up/down to tear it in two.
    "band": {"height": 0.24, "canvas": [640, 70], "breaks": ["slide", "split"], "layers": [
        R([0, 0, 640, 70], "tile.3"),
        {"type": "path", "points": [[-20, 0], [-4, 0], [24, 70], [8, 70]], "closed": True, "fill": "edge",
         "repeat": {"count": 20, "step": [34, 0]}},
        R([206, 14, 228, 42], "#fff6df"),
        T("BREAK BAND", [320, 46], "cond_bold", 30, fill="edge")]},
    "reveal_slide": [0, -0.5],
}

def write_layout(name, d):
    path = os.path.join(ROOT, "packs", "core", "layouts", name + ".json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(d, ensure_ascii=False, indent=1) + "\n")


if __name__ == "__main__":
    for name, d in [("single", single), ("windows", windows), ("plate", plate), ("jar", jar)]:
        write_layout(name, d)
    print("wrote 4 layouts")
