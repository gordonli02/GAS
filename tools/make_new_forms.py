"""Writes the five forms added in M8.6 and their layouts (packs/core/forms, packs/core/layouts).

New looks on the three ways a ticket opens: the insides, flaps and band rules are those of
single / windows / jar (tools/make_core_layouts.py); each form has a front of its own, after
real pull-tab tickets G collected. Ka-Bawk! and One Flock are long 21:9 cards (G, after M8.6),
the first standing, the second lying, each on a layout of its own (`tower` and `strip` below).
The symbols come from tools/import_symbol_art.py
(tools/make_ticket_art.py for the nuggets and the flag).

Run: python tools/make_new_forms.py   (then add any new form to packs/core/pack.json)
"""
import copy
import json
import math
import os

from make_core_layouts import BLACK, DIG, INK, ROOT, STOCK, YEL, R, T, perf, single, windows, write_layout

CREAM, WHITE = "#fff8e6", "#ffffff"


def RR(rect, fill, radius, **kw):
    return dict({"type": "rect", "rect": rect, "fill": fill, "radius": radius}, **kw)


def C(center, radius, fill, **kw):
    return dict({"type": "circle", "center": center, "radius": radius, "fill": fill}, **kw)


def P(points, fill=None, stroke=None, width=None, closed=True, **kw):
    d = {"type": "path", "points": [[round(x, 2), round(y, 2)] for x, y in points], "closed": closed}
    if fill:
        d["fill"] = fill
    if stroke:
        d.update({"stroke": stroke, "width": width, "join": "round"})
    d.update(kw)
    return d


def S(center, size, tier=None, large=False):
    d = {"type": "symbol", "center": center, "size": size}
    if tier is not None:
        d["tier"] = tier
    if large:
        d["variant"] = "large"
    return d


def star(cx, cy, r_out, r_in, points=5, turn=-90.0):
    out = []
    for i in range(points * 2):
        a = math.radians(turn + i * 180.0 / points)
        r = r_in if i % 2 else r_out
        out.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return out


def rays(cx, cy, radius, count, fill, turn=0.0):
    """Every other wedge of a sunburst (put it inside a clipped group)."""
    out = []
    for i in range(count):
        a0 = math.radians(turn + i * 360.0 / count)
        a1 = math.radians(turn + (i + .5) * 360.0 / count)
        out.append(P([(cx, cy), (cx + math.cos(a0) * radius, cy + math.sin(a0) * radius),
                      (cx + math.cos(a1) * radius, cy + math.sin(a1) * radius)], fill))
    return out


def shadowed(text, pos, font, size, fill, shade, shift=3, **kw):
    return [T(text, [pos[0] + shift, pos[1] + shift], font, size, fill=shade, **kw), T(text, pos, font, size, fill=fill, **kw)]


def legal(x, ys, fill, max_width, sizes=(14, 24), first="INSTANT WINNERS SHOWN ABOVE."):
    return [
        T(first, [x, ys[0]], "cond_bold", sizes[0], fill=fill, align="right", max_width=max_width),
        T("PAYABLE IN EGG MONEY.", [x, ys[1]], "cond_bold", sizes[0], fill=fill, align="right", max_width=max_width),
        T("©Ben Kraptu apt.   FORM {code}", [x, ys[2]], "cond", sizes[0], fill=fill, align="right", max_width=max_width),
        T("SERIAL NO. {serial}", [x, ys[3]], "lcd", sizes[1], fill=fill, align="right", max_width=max_width),
    ]


def with_front(base, front, **changes):
    d = copy.deepcopy(base)
    d["front"] = front
    d.update(changes)
    return d


def tier(key, en, zh, prize, count, role):
    return {"key": key, "label": {"en": en, "zh": zh}, "prize": prize, "printed_count": count, "role": role,
            "symbol": "art/%s.png" % key, "symbol_large": "art/%s_large.png" % key}


def form(fid, name, title, code, colors, tiers, groups, win, layout):
    return {"id": fid, "name": name, "title": title, "code": code, "price": 1, "colors": colors,
            "tiers": [tier(k, en, zh, prize, count, role) for (k, en, zh), (prize, count, role)
                      in zip(tiers, [(500, 6, "top"), (500, 6, "top"), (100, 10, "mid"), (25, 75, "low")])],
            "digit_groups": groups, "win_display": win, "layout": "layouts/%s.json" % layout}


# ---------------------------------------------------------------------------------
# Pecking Order (five windows): a ranking board, three of a kind per row as on a real ticket.

order_front = [
    R([0, 0, 420, 600], "edge"),
    R([14, 14, 392, 150], "head"),
    {"type": "group", "clip": [14, 14, 392, 150], "layers": rays(326, 96, 420, 14, "#ffeb9c", 8)},
    S([326, 96], 146, tier=0, large=True),
    T("PECKING", [26, 82], "slab", 52, fill="ink", align="left", max_width=204, stroke=WHITE, stroke_width=9),
    T("ORDER", [26, 134], "slab", 52, fill="ink", align="left", max_width=204, stroke=WHITE, stroke_width=9),
    T("WHO RULES THE ROOST?", [28, 156], "cond_bold", 15, fill="ink", align="left"),
    {"type": "each_tier", "origin": [14, 170], "columns": 1, "step": [0, 80], "layers": [
        R([0, 0, 392, 76], "tile"),
        RR([8, 7, 216, 62], WHITE, 10),
        S([46, 38], 62), S([116, 38], 62), S([186, 38], 62),
        RR([232, 7, 152, 62], YEL, 10),
        T("{count}", [254, 38], "cond_bold", 20, max_width=34),
        T("WIN", [254, 56], "cond_bold", 14),
        T("${tier_prize}", [326, 53], "slab", 38, max_width=108)]},
    R([14, 494, 392, 92], CREAM),
    C([58, 540], 36, "#d7342d"),
    T("${price}", [58, 556], "slab", 42, fill=WHITE, max_width=60),
    *legal(396, [514, 531, 548, 575], "ink", 270),
]

# ---------------------------------------------------------------------------------
# The long card, 21:9 (G, after M8.6): 2.59 by 1.11, as wide as a card may be. One Flock has it
# lying (`strip`), Ka-Bawk! standing (`tower`).

SW, SH = 840, 360
LONG, SHORT = 2.59, 1.11


def strip(front):
    """Lying: one flap hinged along the top, the three digit groups side by side, each group
    showing its own win."""
    return {
        "format": 1,
        "card": {"size": [LONG, SHORT], "canvas": [SW, SH]},
        "front": front,
        "interior": {
            "base": [
                R([0, 0, SW, SH], "#ece7da"), R([12, 12, 816, 336], STOCK),
                perf([286, 36], [286, 318], "#b9b2a2", repeat={"count": 2, "step": [268, 0]}),
                T("PAYABLE IN EGG MONEY", [420, 339], "cond_bold", 12, fill="#5c5850")],
            "slots": [{"rect": [22 + 268 * i, 26, 260, 296], "anchor": [152 + 268 * i, 204]} for i in range(3)],
            "digits": {"direction": "row", "pitch": 63, "color": DIG,
                       "digit": {"font": "slab", "size": 74, "offset": [0, -4.5]},
                       "caption": {"font": "cond_bold", "size": 11, "offset": [0, 10], "max_width": 52},
                       "mark": {"font": "cond_bold", "size": 11, "offset": [25, -57]}},
            "win_slot": [
                R([0, 0, 260, 296], "win_tile"),
                C([130, 102], 86, "#ffffff30"),
                {"type": "symbol", "tier": "win", "variant": "large", "center": [130, 102], "size": 172},
                R([0, 200, 260, 96], YEL),
                T("${prize}", [130, 260], "slab", 60, max_width=240),
                T("VERIFY {verify}", [130, 287], "lcd", 18, **{"if": "verify"})]},
        # side_pull: a sideways swipe opens it too, as on Lucky Spur.
        "flaps": [{"rect": [16, 16, 808, 328], "hinge": "top", "side_pull": True,
                   "cover": {"canvas": [808, 328], "layers": [
                       R([0, 0, 808, 328], STOCK),
                       C([404, 76], 56, INK), C([404, 76], 45, STOCK),
                       T("BK", [404, 94], "slab", 47, fill=INK),
                       {"type": "path", "points": [[358, 306], [358, 232], [316, 232], [404, 166], [492, 232], [450, 232], [450, 306]],
                        "closed": True, "stroke": INK, "width": 6, "join": "miter"},
                       T("OPEN", [204, 270], "slab", 54, fill=INK), T("UP", [604, 270], "slab", 54, fill=INK)]}}],
        "pairs": "none",
        "band": None,
        "reveal_slide": [0, -0.5],
    }


def tower(front):
    """Standing: one flap hinged on the left as on Big Catch, the three digit groups one above
    the other, a win shown over the whole card."""
    return {
        "format": 1,
        "card": {"size": [SHORT, LONG], "canvas": [SH, SW]},
        "front": front,
        "interior": {
            "base": [
                R([0, 0, SH, SW], "#ece7da"), R([16, 16, 328, 808], STOCK),
                perf([16, 16], [344, 16], "#8f8b82"), perf([344, 16], [344, 824], "#8f8b82"),
                perf([16, 824], [344, 824], "#8f8b82"),
                T("PAYABLE IN EGG MONEY", [180, 815], "cond_bold", 12, fill="#5c5850")],
            "slots": [{"anchor": [180, 196]}, {"anchor": [180, 440]}, {"anchor": [180, 684]}],
            "digits": {"direction": "row", "pitch": 76, "color": DIG,
                       "digit": {"font": "slab", "size": 88, "offset": [0, -5.4]},
                       "caption": {"font": "cond_bold", "size": 14, "offset": [0, 12], "max_width": 62},
                       "mark": {"font": "cond_bold", "size": 14, "offset": [30, -69]}},
            "winner": [
                R([36, 44, 288, 632], "win_tile"),
                C([180, 344], 134, "#ffffff30"),
                {"type": "symbol", "tier": "win", "variant": "large", "center": [180, 344], "size": 252},
                R([36, 676, 288, 116], YEL),
                T("${prize}", [180, 764], "slab", 78, max_width=268),
                T("VERIFY {verify}", [180, 70], "lcd", 20, fill="#ffffff", **{"if": "verify"})]},
        "flaps": [{"rect": [16, 16, 328, 808], "hinge": "left", "cover": {"canvas": [328, 808], "layers": [
            R([0, 0, 328, 808], STOCK),
            {"type": "path", "points": [[26, 176], [206, 176], [206, 138], [304, 232], [206, 326], [206, 288], [26, 288]],
             "closed": True, "stroke": INK, "width": 6, "join": "miter"},
            T("OPEN", [126, 226], "slab", 44, fill=INK), T("HERE", [126, 274], "slab", 44, fill=INK),
            C([164, 500], 74, INK), C([164, 500], 60, STOCK),
            T("BK", [164, 523], "slab", 64, fill=INK),
            T("©Ben Kraptu apt.", [164, 650], "cond_bold", 22, fill=INK),
            T("PAYABLE IN EGG MONEY", [164, 678], "cond", 15, fill=INK)]}}],
        "pairs": "none",
        "band": None,
        "reveal_slide": [0.36, 0],
    }


# ---------------------------------------------------------------------------------
# Ka-Bawk! (standing long card): a bomb going off behind the title, the four prizes in a
# column under it, hazard tape top and bottom.


def hazard(x, y, w, h):
    return {"type": "group", "clip": [x, y, w, h], "layers": [
        R([x, y, w, h], "#ffd23a"),
        P([(x - 20, y), (x - 6, y), (x + h - 6, y + h), (x + h - 20, y + h)], "#17171d",
          repeat={"count": int(w / 28) + 2, "step": [28, 0]})]}


kabawk_front = [
    R([0, 0, SH, SW], "edge"),
    hazard(12, 12, 336, 16),
    R([12, 34, 336, 338], "head"),
    {"type": "group", "clip": [12, 34, 336, 338], "layers": rays(180, 176, 440, 16, "#3a5bf0", 4) + [
        P(star(180, 172, 158, 90, 12, -82), "#ff5a1f"),
        P(star(180, 172, 118, 66, 12, -67), "#ffd23a")]},
    S([176, 166], 204, tier=0, large=True),
    T("KA-BAWK!", [184, 354], "slab", 62, fill="#17171d", max_width=316),
    T("KA-BAWK!", [180, 350], "slab", 62, fill="#ffd23a", max_width=316, stroke="#a3140f", stroke_width=10),
    {"type": "each_tier", "origin": [12, 378], "columns": 1, "step": [0, 83], "layers": [
        R([0, 0, 336, 79], "#26262f"),
        R([0, 0, 8, 79], "tile"),
        S([56, 40], 70),
        T("${tier_prize}", [104, 56], "slab", 46, fill="#ffd23a", align="left", max_width=138),
        T("{count} WIN", [322, 49], "cond_bold", 19, fill=WHITE, align="right", max_width=76)]},
    hazard(12, 712, 336, 12),
    R([12, 724, 336, 104], "#ffd23a"),
    T("${price}", [24, 812], "slab", 64, fill="#17171d", align="left"),
    *legal(338, [748, 765, 782, 808], "#17171d", 226, sizes=(14, 22)),
]

# ---------------------------------------------------------------------------------
# One Flock (lying long card, no band: G keeps the paper band for Lucky Spur alone): the flag
# with a hen for every star, and the prize list beside it.

flock_front = [
    R([0, 0, SW, SH], "edge"),
    *[P(star(x, 40, 12, 5), WHITE) for x in (60, 780)],
    *shadowed("ONE NATION, ONE FLOCK", [420, 56], "slab", 44, WHITE, "#c8102e", 3, max_width=640),
    {"type": "image", "src": "art/flock_flag.png", "rect": [14, 72, 356, 196]},
    RR([380, 72, 446, 196], "head", 8),
    RR([392, 80, 422, 32], "#c8102e", 6),
    T("INSTANT WINNERS", [603, 104], "slab", 22, fill=WHITE, max_width=380),
    {"type": "each_tier", "origin": [390, 118], "columns": 2, "step": [216, 74], "layers": [
        S([36, 36], 66),
        T("{count} WIN", [76, 30], "cond_bold", 18, fill="#c8102e", align="left", max_width=130),
        T("${tier_prize}", [76, 60], "slab", 32, fill="ink", align="left", max_width=130)]},
    R([14, 278, 812, 68], "head"),
    R([14, 278, 812, 5], "#c8102e"),
    R([14, 341, 812, 5], "#c8102e"),
    T("${price}", [28, 334], "slab", 50, fill="ink", align="left"),
    T("E PLURIBUS CLUCKUM", [108, 314], "cond_bold", 17, fill="#c8102e", align="left"),
    T("OUT OF MANY, ONE FLOCK", [108, 332], "cond", 14, fill="ink", align="left"),
    *legal(812, [296, 309, 322, 337], "ink", 320, sizes=(12, 18)),
]

# ---------------------------------------------------------------------------------
# Nugget Rush (five windows): a fry-shop menu board, a row and a price for each shape.

NUG_NAMES = ["DINO", "STAR", "BOOT", "BALL"]
nugget_front = [
    R([0, 0, 420, 600], "edge"),
    RR([14, 14, 392, 122], "head", 14),
    C([30, 27], 4.5, "#ffe98a", repeat={"count": 14, "step": [27.7, 0]}),
    C([30, 123], 4.5, "#ffe98a", repeat={"count": 14, "step": [27.7, 0]}),
    T("NUGGET RUSH", [213, 92], "slab", 50, fill="#5e0d06", max_width=360),
    T("NUGGET RUSH", [210, 89], "slab", 50, fill=WHITE, max_width=360),
    T("FRESH FROM THE FRYER", [210, 112], "cond_bold", 15, fill="#ffe98a"),
    RR([14, 144, 392, 350], "#fff3d1", 12),
    *[{"type": "each_tier", "tiers": [i], "origin": [22, 150 + 85 * i], "columns": 1, "step": [0, 0], "layers": [
        S([46, 42], 80),
        T(NUG_NAMES[i], [96, 40], "slab", 27, fill="ink", align="left"),
        T("{count} WIN", [97, 62], "cond_bold", 15, fill="#a3541c", align="left"),
        {"type": "path", "points": [[190, 38], [262, 38]], "stroke": "#c9a66b", "width": 3, "dash": [3, 6]},
        T("${tier_prize}", [372, 56], "slab", 42, fill="head", align="right", max_width=104),
        *([{"type": "path", "points": [[4, 84], [372, 84]], "stroke": "#e6cf9f", "width": 2}] if i < 3 else [])]}
      for i in range(4)],
    RR([14, 502, 392, 84], "head", 12),
    P(star(60, 544, 40, 31, 14, -90), "#ffd23a"),
    T("${price}", [60, 560], "slab", 40, fill="ink", max_width=56),
    *legal(394, [521, 537, 553, 577], WHITE, 262),
]

# ---------------------------------------------------------------------------------
# Peckeye (one flap): the sailor over the sea, the two top prizes large under him.


def waves(y, amp, length, fill, bottom, phase=0.0):
    pts = [(14 + 392 * i / 56.0, y + amp * math.sin(2 * math.pi * (392 * i / 56.0) / length + phase)) for i in range(57)]
    return P(pts + [(406, bottom), (14, bottom)], fill)


peckeye_front = [
    R([0, 0, 420, 600], "edge"),
    R([14, 14, 392, 332], "head"),
    C([70, 150], 34, "#fff3b0"),
    waves(292, 5, 70, "#58bfe0", 346),
    waves(312, 5, 86, "#2f9fca", 346, 1.4),
    T("PECKEYE", [29, 79], "slab", 60, fill="ink", align="left", max_width=258),
    T("PECKEYE", [26, 76], "slab", 60, fill="#d7342d", align="left", max_width=258, stroke=WHITE, stroke_width=10),
    T("THE SAILOR ROOSTER", [28, 102], "cond_bold", 18, fill="ink", align="left"),
    {"type": "image", "src": "art/peckeye_hero.png", "rect": [68, 60, 338, 291]},
    R([0, 346, 14, 254], "edge"), R([406, 346, 14, 254], "edge"),
    R([14, 346, 392, 150], CREAM),
    {"type": "each_tier", "tiers": [0, 1], "origin": [14, 350], "columns": 2, "step": [196, 0], "layers": [
        S([42, 38], 72),
        *shadowed("${tier_prize}", [138, 52], "slab", 46, "#d7342d", "ink", 3, max_width=104),
        T("{count} WIN", [138, 71], "cond_bold", 14, fill="ink")]},
    R([26, 428, 368, 2], "#d9cfb4"),
    {"type": "each_tier", "tiers": [2, 3], "origin": [14, 432], "columns": 2, "step": [196, 0], "layers": [
        S([42, 31], 56),
        *shadowed("${tier_prize}", [132, 40], "slab", 34, "#d7342d", "ink", 2, max_width=112),
        T("{count} WIN", [132, 57], "cond_bold", 13, fill="ink")]},
    R([14, 496, 392, 90], "ink"),
    C([58, 541], 37, "#d7342d"), C([58, 541], 25, WHITE),
    T("${price}", [58, 553], "slab", 32, fill="ink", max_width=44),
    *legal(396, [517, 533, 549, 574], WHITE, 262),
]

FORMS = [
    (form("order", "Pecking Order", ["PECKING", "ORDER"], "PO-1S",
          {"edge": "#1b7a3a", "head": "#ffd84a", "ink": "#0d3d1c", "tiles": ["#e23d2d", "#f08a1d", "#3aa0e8", "#6cc04a"]},
          [("rooster", "Rooster", "公鸡"), ("hen", "Hen", "母鸡"), ("chick", "Chick", "小鸡"), ("whole_egg", "Egg", "鸡蛋")],
          [4, 3, 4, 3, 4], "each_group", "order"), with_front(windows, order_front)),
    (form("kabawk", "Ka-Bawk!", ["KA-BAWK!"], "KB-1S",
          {"edge": "#17171d", "head": "#2743c9", "ink": "#17171d", "tiles": ["#ff5a1f", "#e23d2d", "#f2c21a", "#3aa0e8"]},
          [("bomb", "Bomb", "圆炸弹"), ("c4", "C-4", "C4"), ("grenade", "Grenade", "手榴弹"), ("shell", "Shell", "炮弹")],
          [4, 4, 3], "whole", "kabawk"), tower(kabawk_front)),
    (form("flock", "One Flock", ["ONE", "FLOCK"], "OF-1S",
          {"edge": "#14245e", "head": "#fff8e6", "ink": "#14245e", "tiles": ["#c8102e", "#1f3a93", "#8fc7f2", "#ffd23a"]},
          [("uncle", "Uncle Cluck", "山姆鸡"), ("liberty", "Lady Liberty", "自由母鸡"), ("bell", "Liberty Bell", "自由钟"), ("rocket", "Rocket", "烟花")],
          [4, 4, 3], "each_group", "flock"), strip(flock_front)),
    (form("nugget", "Nugget Rush", ["NUGGET", "RUSH"], "NR-1S",
          {"edge": "#f5a800", "head": "#d62718", "ink": "#4a1a08", "tiles": ["#d62718", "#2f9e44", "#2f7fe0", "#7a3fc9"]},
          [("nug_dino", "Dino Nugget", "恐龙鸡块"), ("nug_star", "Star Nugget", "星形鸡块"), ("nug_boot", "Boot Nugget", "靴形鸡块"), ("nug_ball", "Ball Nugget", "圆鸡块")],
          [4, 3, 4, 3, 4], "each_group", "nugget"), with_front(windows, nugget_front)),
    (form("peckeye", "Peckeye", ["PECKEYE"], "PE-1S",
          {"edge": "#0e7c86", "head": "#bfeaf5", "ink": "#132a4f", "tiles": ["#2f6fd6", "#d7342d", "#f2c21a", "#2fa89a"]},
          [("sailor", "Peckeye", "水手鸡"), ("spinach", "Spinach", "菠菜罐头"), ("anchor", "Anchor", "船锚"), ("pipe", "Corncob Pipe", "烟斗")],
          [4, 4, 3], "whole", "peckeye"), with_front(single, peckeye_front)),
]

if __name__ == "__main__":
    for f, layout in FORMS:
        write_layout(f["layout"].split("/")[1].split(".")[0], layout)
        path = os.path.join(ROOT, "packs", "core", "forms", f["id"] + ".json")
        with open(path, "w", encoding="utf-8", newline="\n") as out:
            out.write(json.dumps(f, ensure_ascii=False, indent=2) + "\n")
    print("wrote %d forms and layouts" % len(FORMS))
