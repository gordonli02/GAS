"""Style proposals for the symbols that keep a face (G, M8.6): the same six drawings in three
manners, beside what the game has now. Nothing here is used by the game: once G picks one, its
manner moves into tools/make_ticket_art.py and this file goes.

    python tools/art_proposals.py      # writes docs/m8.6/style_*.png

  A  sticker:      the outline as now, soft cel shading, small dot eyes with a glint, a blush
  B  old cartoon:  a heavy black line, pie-cut eyes, no shading (1930s rubber hose)
  C  print:        a thin brown line, hatched shading, animals drawn as animals; things lose
                   their faces altogether
"""
import json
import math
import os
import shutil
import subprocess

from make_ticket_art import ART, BUILD, GODOT, K_LARGE, K_SMALL, ROOT, n

OUT_DIR = os.path.join(ROOT, "docs", "m8.6")
RED, BEAK, LEG = "#d7342d", "#f2a51d", "#e58a1f"


def darken(hex_color, f):
    h = hex_color.lstrip("#")
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(int(h[i:i + 2], 16) * f))) for i in (0, 2, 4))


STYLES = {
    "a": {"name": "A", "line": "#17202a", "weight": 1.0, "shade": "cel", "eye": "dot", "things": True},
    "b": {"name": "B", "line": "#111111", "weight": 1.4, "shade": "none", "eye": "pie", "things": True},
    "c": {"name": "C", "line": "#3b2a20", "weight": 0.62, "shade": "hatch", "eye": "real", "things": False},
}


class Draw:
    def __init__(self, style, k):
        self.s = STYLES[style]
        self.k = k
        self.defs = []
        self.out = []
        self.ids = 0

    def lw(self, w):
        return w * self.k * self.s["weight"]

    def stroke(self, w, color=None, cap="round"):
        return 'stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="%s"' % (color or self.s["line"], n(self.lw(w)), cap)

    def shape(self, d, fill, w=4, shade=True):
        """A filled outline; the side away from the light (upper left) is shaded in the style's way."""
        self.out.append('<path d="%s" fill="%s"/>' % (d, fill))
        mode = self.s["shade"]
        if shade and mode != "none":
            self.ids += 1
            cid = "c%d" % self.ids
            self.defs.append('<clipPath id="%s"><path d="%s"/></clipPath>' % (cid, d))
            self.out.append('<g clip-path="url(#%s)">' % cid)
            if mode == "cel":
                self.out.append('<path d="%s" fill="%s"/>' % (d, darken(fill, .82)))
                self.out.append('<path d="%s" fill="%s" transform="translate(-7 -8)"/>' % (d, fill))
            else:
                ink = darken(fill, .58)
                for i in range(-34, 35):
                    x = i * 7
                    self.out.append('<path d="M%s -130 L%s 130" stroke="%s" stroke-width="1.7" fill="none"/>' % (x + 130, x - 130, ink))
                self.out.append('<path d="%s" fill="%s" transform="translate(-11 -12)"/>' % (d, fill))
            self.out.append("</g>")
        if w:
            self.out.append('<path d="%s" fill="none" %s/>' % (d, self.stroke(w)))

    def line(self, d, w=3, color=None, cap="round"):
        self.out.append('<path d="%s" fill="none" %s/>' % (d, self.stroke(w, color, cap)))

    def tube(self, d, color, width):
        self.out.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"/>'
                        % (d, self.s["line"], n(width + self.lw(4))))
        self.out.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"/>'
                        % (d, color, n(width)))

    def dot(self, x, y, rx, ry, fill, rot=0):
        t = ' transform="rotate(%s %s %s)"' % (n(rot), n(x), n(y)) if rot else ""
        self.out.append('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s"%s/>' % (n(x), n(y), n(rx), n(ry), fill, t))

    def glow(self, x, y, rx, ry, rot=0, alpha=.5):
        """A soft highlight: only where the style shades softly."""
        if self.s["shade"] == "cel":
            t = ' transform="rotate(%s %s %s)"' % (n(rot), n(x), n(y)) if rot else ""
            self.out.append('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="#ffffff" fill-opacity="%s"%s/>' % (n(x), n(y), n(rx), n(ry), alpha, t))

    def blush(self, x, y, r):
        if self.s["eye"] == "dot":
            self.out.append('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="#ff6f6f" fill-opacity=".45"/>' % (n(x), n(y), n(r), n(r * .62)))

    def eye(self, x, y, r, look=1):
        """One eye of radius r, looking toward `look` (1 right, -1 left)."""
        kind = self.s["eye"]
        line = self.s["line"]
        if kind == "dot":
            self.dot(x, y, r * .62, r * .78, line)
            self.dot(x - r * .2, y - r * .3, r * .22, r * .22, "#ffffff")
        elif kind == "pie":
            self.out.append('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="#ffffff" %s/>' % (n(x), n(y - r * .2), n(r * .82), n(r * 1.25), self.stroke(2.4)))
            px, py = x + look * r * .18, y + r * .12
            self.dot(px, py, r * .46, r * .74, line)
            self.out.append('<path d="M%s %s L%s %s L%s %s Z" fill="#ffffff"/>' % (
                n(px), n(py), n(px - look * r * .6), n(py - r * .75), n(px - look * r * .05), n(py - r * .9)))
        else:
            self.out.append('<circle cx="%s" cy="%s" r="%s" fill="#eba72c" %s/>' % (n(x), n(y), n(r * .62), self.stroke(2.2)))
            self.dot(x + look * r * .06, y, r * .3, r * .3, "#15100c")
            self.dot(x - r * .12, y - r * .16, r * .1, r * .1, "#ffffff")

    def brow(self, x, y, r, look=1):
        if self.s["eye"] == "pie":
            self.line("M%s %s L%s %s" % (n(x - look * r * .9), n(y - r * 1.9), n(x + look * r * .7), n(y - r * 1.55)), 3)

    def smile(self, x, y, w, depth=None):
        depth = w * .42 if depth is None else depth
        self.line("M%s %s C%s %s %s %s %s %s" % (n(x - w), n(y), n(x - w * .5), n(y + depth), n(x + w * .5), n(y + depth), n(x + w), n(y)), 3)

    def grin(self, x, y, w):
        """An open laughing mouth with a tongue (the old cartoons)."""
        d = "M%s %s C%s %s %s %s %s %s C%s %s %s %s %s %s Z" % tuple(n(v) for v in (
            x - w, y, x - w * .5, y + w * .2, x + w * .5, y + w * .2, x + w, y,
            x + w * .8, y + w * 1.1, x - w * .8, y + w * 1.1, x - w, y))
        self.out.append('<path d="%s" fill="#2a0f12" %s/>' % (d, self.stroke(3)))
        self.dot(x, y + w * .62, w * .42, w * .24, "#e8505a")

    def svg(self):
        return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="-120 -120 240 240" width="240" height="240">\n<defs>%s</defs>\n%s\n</svg>\n'
                % ("".join(self.defs), "\n".join(self.out)))


# ---------------------------------------------------------------------------------

def foot(p, x, y, to=1):
    p.tube("M%s %s L%s %s" % (x, y, x - 2, y + 28), LEG, 5)
    for dx, dy in ((16 * to, 6), (6 * to, 12), (-9 * to, 8)):
        p.tube("M%s %s L%s %s" % (x - 2, y + 28, x - 2 + dx, y + 28 + dy), LEG, 4)


def rooster(p):
    for d, col in [("M-34 2 C-44 -48 -70 -84 -96 -92 C-76 -62 -70 -30 -52 8 Z", "#1f6f6b"),
                   ("M-40 8 C-62 -30 -92 -52 -112 -52 C-92 -30 -82 -4 -56 18 Z", "#2f8f5b"),
                   ("M-42 16 C-70 -6 -100 -10 -116 -2 C-94 8 -80 26 -52 32 Z", "#27507a"),
                   ("M-40 26 C-66 22 -92 34 -104 48 C-82 46 -66 52 -44 42 Z", "#1f6f6b")]:
        p.shape(d, col, 3)
    foot(p, -10, 56)
    foot(p, 16, 54)
    p.shape("M-48 14 C-50 -14 -22 -30 6 -24 C30 -20 50 -2 50 22 C50 48 28 64 0 64 C-28 64 -46 44 -48 14 Z", "#b9482a")
    p.shape("M24 -74 C18 -92 30 -98 36 -86 C36 -106 54 -106 54 -88 C62 -100 74 -90 64 -74 C52 -84 36 -82 24 -74 Z", RED, 3)
    p.shape("M4 -18 C2 -44 12 -70 34 -78 C54 -84 68 -70 64 -54 C62 -44 60 -38 60 -30 C60 -12 54 6 42 16 C26 14 10 2 4 -18 Z", "#f0a63a")
    p.shape("M58 -42 C50 -36 50 -18 59 -12 C68 -18 68 -36 62 -42 Z", RED, 3)
    for d in ("M16 -22 C18 -8 24 2 32 8", "M28 -26 C30 -12 36 -2 44 4", "M40 -28 C42 -18 46 -10 52 -6"):
        p.line(d, 2, "#b8741f")
    p.shape("M-36 10 C-18 -6 14 -4 26 14 C16 36 -12 44 -38 30 C-30 24 -32 16 -36 10 Z", "#8f3320", 3)
    for d in ("M-22 14 C-12 22 -2 24 10 22", "M-26 24 C-14 32 -2 34 8 32"):
        p.line(d, 2, "#5e1f12")
    p.shape("M62 -64 L88 -53 L62 -44 Z", BEAK, 3)
    p.line("M64 -54 L80 -53", 2)
    p.eye(47, -60, 11)
    p.brow(47, -60, 11)
    p.blush(40, -44, 7)
    p.glow(26, -62, 8, 5, -30)


def hen(p):
    p.shape("M-46 -4 C-70 -34 -84 -40 -92 -30 C-84 -20 -80 -2 -60 14 Z", "#efe6cf", 3)
    p.shape("M-58 22 C-60 -10 -30 -28 0 -24 C34 -22 58 -4 58 24 C58 50 34 62 0 62 C-34 62 -56 50 -58 22 Z", "#fbf7ea")
    p.shape("M32 -64 C28 -78 38 -80 42 -72 C44 -84 56 -82 54 -70 C60 -76 66 -68 60 -62 C50 -68 40 -68 32 -64 Z", RED, 3)
    p.shape("M10 -18 C8 -40 18 -60 36 -66 C54 -70 64 -58 62 -46 C60 -36 60 -30 58 -22 C58 -8 52 4 42 12 C28 10 14 0 10 -18 Z", "#fbf7ea")
    p.shape("M57 -36 C51 -32 51 -20 58 -15 C65 -20 65 -32 61 -36 Z", RED, 3)
    p.shape("M-34 12 C-16 -2 14 0 24 18 C14 38 -14 42 -36 30 C-30 24 -30 18 -34 12 Z", "#efe6cf", 3)
    for d in ("M-20 16 C-10 24 0 26 10 24", "M-24 26 C-12 33 -2 34 6 33"):
        p.line(d, 2, "#b9ab86")
    p.shape("M60 -54 L82 -45 L60 -38 Z", BEAK, 3)
    p.line("M62 -46 L74 -45", 2)
    p.eye(46, -50, 10)
    p.brow(46, -50, 10)
    p.blush(40, -34, 7)
    # the nest, in front
    p.shape("M-84 46 C-76 80 -42 94 0 94 C42 94 76 80 84 46 C52 60 -52 60 -84 46 Z", "#d9a441")
    for x in (-56, -30, -4, 22, 48):
        p.line("M%s 64 L%s 84" % (x, x + 12), 2, "#8b5a2b")
        p.line("M%s 70 L%s 60" % (x + 6, x + 16), 2, "#f3d27a")


def chick(p):
    foot(p, -12, 60)
    foot(p, 10, 60)
    p.shape("M-4 -18 C22 -18 42 2 42 28 C42 54 22 70 -4 70 C-30 70 -50 54 -50 28 C-50 2 -30 -18 -4 -18 Z", "#f7d13d")
    p.shape("M-30 26 C-16 14 4 18 8 34 C-2 48 -22 48 -36 38 Z", "#f0b424", 3)
    p.shape("M10 -62 C4 -82 18 -86 20 -72 C24 -88 38 -80 30 -64 Z", "#f7d13d", 3)
    p.shape("M16 -66 C38 -66 54 -50 54 -30 C54 -10 38 6 16 6 C-6 6 -22 -10 -22 -30 C-22 -50 -6 -66 16 -66 Z", "#f7d13d")
    p.shape("M50 -34 L72 -25 L50 -17 Z", "#f28a1d", 3)
    p.eye(32, -36, 11)
    p.brow(32, -36, 11)
    p.blush(28, -16, 8)
    p.glow(2, -50, 9, 5, -30)


def whole_egg(p):
    things = p.s["things"]
    if not things:
        # an egg is an egg: it lies in straw
        p.shape("M-90 56 C-80 84 -44 96 0 96 C44 96 80 84 90 56 C56 70 -56 70 -90 56 Z", "#d9a441")
    p.shape("M0 -92 C46 -92 74 -22 74 22 C74 66 42 92 0 92 C-42 92 -74 66 -74 22 C-74 -22 -46 -92 0 -92 Z", "#f3dcb4")
    p.glow(-30, -50, 12, 20, 28, .65)
    if things:
        if p.s["eye"] == "pie":
            p.eye(-22, 6, 15, 1)
            p.eye(22, 6, 15, 1)
            p.grin(0, 34, 20)
        else:
            p.eye(-24, 14, 12)
            p.eye(24, 14, 12)
            p.smile(0, 32, 11)
            p.blush(-44, 34, 10)
            p.blush(44, 34, 10)
    else:
        for x, y in ((-30, 10), (16, -30), (34, 30), (-10, 52), (-44, -24), (4, 6)):
            p.dot(x, y, 4, 3, "#c9a26a", (x + y) % 80)
        for x in (-58, -30, -2, 26, 54):
            p.line("M%s 78 L%s 92" % (x, x + 10), 2, "#8b5a2b")


def walleye(p):
    things = True   # a fish is alive in every style
    p.shape("M52 0 C70 -14 88 -34 100 -44 C96 -20 96 20 102 44 C88 36 70 14 52 0 Z", "#d9a441")
    p.shape("M-34 -34 L-18 -72 L-6 -42 L8 -70 L18 -40 L34 -60 L40 -30 Z", "#b77c2b", 3)
    p.shape("M-92 4 C-80 -28 -40 -44 0 -42 C36 -40 56 -20 60 0 C56 22 36 40 0 42 C-40 44 -80 30 -92 4 Z", "#e8c557")
    p.shape("M-22 12 C-10 10 4 18 6 30 C-8 32 -20 26 -22 12 Z", "#d9a441", 3)
    p.line("M-46 -24 C-38 -8 -38 12 -46 28", 2)
    if p.s["eye"] == "real":
        for x in (-22, -4, 14, 32):
            for y in (-18, -2):
                p.line("M%s %s C%s %s %s %s %s %s" % (x, y, x + 8, y + 3, x + 8, y + 11, x, y + 14), 1.6, "#a8842c")
        p.line("M-92 6 L-72 10", 2.4)
        p.eye(-64, -8, 13, -1)
    elif p.s["eye"] == "pie":
        p.eye(-62, -10, 14, -1)
        p.brow(-62, -10, 14, -1)
        p.grin(-74, 12, 11)
    else:
        p.eye(-62, -8, 13, -1)
        p.smile(-72, 12, 9)
        p.blush(-52, 12, 8)
    p.glow(-10, -28, 26, 6, -4)


def mug(p):
    things = p.s["things"]
    if not things:
        p.shape("M-86 74 C-86 62 -50 56 -4 56 C42 56 78 62 78 74 C78 86 42 92 -4 92 C-50 92 -86 86 -86 74 Z", "#e9e5d8")
    for d in ("M-24 -62 C-36 -76 -12 -86 -24 -104", "M12 -62 C0 -76 24 -86 12 -104"):
        p.line(d, 3, "#ffffff" if p.s["shade"] != "hatch" else "#e9e5d8")
    p.tube("M44 -12 C84 -12 84 46 40 46", "#f4efe2", 12)
    p.shape("M-58 -44 L50 -44 L42 66 C42 74 36 78 28 78 L-36 78 C-44 78 -50 74 -50 66 Z", "#f4efe2")
    p.shape("M-57 -24 L49 -24 L48 -10 L-56 -10 Z", "#c8433b", 0, shade=False)
    p.shape("M-58 -44 C-58 -52 -34 -57 -4 -57 C26 -57 50 -52 50 -44 C50 -36 26 -31 -4 -31 C-34 -31 -58 -36 -58 -44 Z", "#43261a", 3, shade=False)
    p.glow(-38, 20, 6, 30, 4, .7)
    if things:
        if p.s["eye"] == "pie":
            p.eye(-24, 24, 13)
            p.eye(16, 24, 13)
            p.grin(-4, 46, 16)
        else:
            p.eye(-24, 28, 11)
            p.eye(16, 28, 11)
            p.smile(-4, 44, 10)
            p.blush(-42, 44, 9)
            p.blush(34, 44, 9)


SUBJECTS = {"rooster": rooster, "hen": hen, "chick": chick, "whole_egg": whole_egg, "walleye": walleye, "mug": mug}


def main():
    os.makedirs(BUILD, exist_ok=True)
    jobs = []
    for style in STYLES:
        folder = os.path.join(BUILD, "style_" + style, "art")
        os.makedirs(folder, exist_ok=True)
        for key, fn in SUBJECTS.items():
            for suffix, k, px in (("", K_SMALL, 512), ("_large", K_LARGE, 1024)):
                p = Draw(style, k)
                fn(p)
                svg = os.path.join(BUILD, "style_%s_%s%s.svg" % (style, key, suffix))
                with open(svg, "w", encoding="utf-8", newline="\n") as f:
                    f.write(p.svg())
                jobs.append({"svg": svg, "png": os.path.join(folder, key + suffix + ".png"), "scale": px / 240.0})
    manifest = os.path.join(BUILD, "style_jobs.json")
    with open(manifest, "w", encoding="utf-8") as f:
        json.dump(jobs, f)
    subprocess.run([GODOT, "--headless", "--path", ROOT, "-s", "res://tools/raster_svg.gd", "--", manifest], check=True, timeout=300)

    # A pack per style with Pecking Order alone, to see the symbols on a ticket.
    for style in STYLES:
        pack = os.path.join(BUILD, "style_" + style)
        for sub in ("forms", "layouts"):
            os.makedirs(os.path.join(pack, sub), exist_ok=True)
            shutil.copy(os.path.join(ROOT, "packs", "core", sub, "order.json"), os.path.join(pack, sub, "order.json"))
        with open(os.path.join(pack, "pack.json"), "w", encoding="utf-8") as f:
            json.dump({"format": 1, "id": "style_" + style, "version": "0", "name": "style " + style, "forms": ["forms/order.json"]}, f)
    print("wrote %d images" % len(jobs))


if __name__ == "__main__":
    main()
