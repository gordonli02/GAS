"""Draws the tier symbols and front illustrations of the forms added in M8.6.

The first three forms' symbols came from the web build's canvas code (tools/export_web_art.js).
These are drawn here in the same manner: flat fills and a dark round-joined outline. Only
living things have a face (G, M8.6): bombs, nuggets, bells and pipes are things. For the same
reason Lucky Spur's star and cactus are drawn again here, as the web build drew them less the face.
Each drawing is written as SVG to tools/art_build/ (not committed) and turned into PNG by Godot
(tools/raster_svg.gd, which uses the engine's own SVG reader):

    python tools/make_ticket_art.py            # writes packs/core/art/*.png
    python tools/make_ticket_art.py --sheet    # also tools/art_build/sheet.png, every symbol on one page

Since the redraw after M8.6 only the Nugget Rush nuggets and One Flock's flag still come from here
(STILL_DRAWN_HERE); the other symbols are imported pictures, see tools/import_symbol_art.py.

A symbol is drawn for a half-size of 100 in a square of +-120, as the web build did (+-1.2 s).
Like there, each has two files: <key>.png (512 px, outline drawn for a symbol shown small) and
<key>_large.png (1024 px, a thinner outline).
"""
import json
import math
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "tools", "art_build")
ART = os.path.join(ROOT, "packs", "core", "art")
GODOT = os.environ.get("GODOT", r"E:\godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe")
OUT = "#17202a"
# Web build: line width 4 at the size a symbol was drawn for (50 small, 112 large); here s is 100.
K_SMALL, K_LARGE = 2.0, 100 / 112


def n(v):
    return ("%.2f" % v).rstrip("0").rstrip(".")


class Pen:
    """Collects SVG elements. `k` scales every outline (the small and large variants differ)."""

    def __init__(self, k):
        self.k = k
        self.out = []

    def _style(self, fill, w, stroke=OUT, cap="round", extra=""):
        s = 'fill="%s"' % (fill or "none")
        if w:
            s += ' stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="%s"' % (stroke, n(w * self.k), cap)
        return s + (" " + extra if extra else "")

    def path(self, d, fill, w=4, **kw):
        self.out.append('<path d="%s" %s/>' % (d, self._style(fill, w, **kw)))

    def line(self, d, color, width, cap="round"):
        """A stroke whose width is part of the drawing (not an outline): never scaled."""
        self.out.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="%s"/>'
                        % (d, color, n(width), cap))

    def circle(self, x, y, r, fill, w=4, **kw):
        self.out.append('<circle cx="%s" cy="%s" r="%s" %s/>' % (n(x), n(y), n(r), self._style(fill, w, **kw)))

    def ellipse(self, x, y, rx, ry, fill, w=4, rot=0, **kw):
        t = ' transform="rotate(%s %s %s)"' % (n(rot), n(x), n(y)) if rot else ""
        self.out.append('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" %s%s/>' % (n(x), n(y), n(rx), n(ry), self._style(fill, w, **kw), t))

    def rect(self, x, y, w_, h, fill, w=4, r=0, rot=0, **kw):
        t = ' transform="rotate(%s %s %s)"' % (n(rot), n(x + w_ / 2), n(y + h / 2)) if rot else ""
        self.out.append('<rect x="%s" y="%s" width="%s" height="%s" rx="%s" %s%s/>'
                        % (n(x), n(y), n(w_), n(h), n(r), self._style(fill, w, **kw), t))

    def poly(self, pts, fill, w=4, closed=True, **kw):
        d = "M" + " L".join("%s %s" % (n(x), n(y)) for x, y in pts) + (" Z" if closed else "")
        self.path(d, fill, w, **kw)

    def group(self, transform):
        self.out.append('<g transform="%s">' % transform)

    def end(self):
        self.out.append("</g>")

    # --- the house face (web build: face()) ---------------------------------------
    def eyes(self, x, y, s, look=0.0):
        for sx in (-1, 1):
            self.circle(x + sx * s * .42, y, s * .3, "#fff", 2)
            self.circle(x + sx * s * .46 + look * s, y + s * .05, s * .13, OUT, 0)

    def smile(self, x, y, s, ink=OUT):
        a0, a1, r = .15 * math.pi, .85 * math.pi, s * .42
        cy = y + s * .45
        self.path("M%s %s A%s %s 0 0 1 %s %s" % (n(x + r * math.cos(a0)), n(cy + r * math.sin(a0)), n(r), n(r),
                                                n(x + r * math.cos(a1)), n(cy + r * math.sin(a1))), None, 3, stroke=ink, cap="butt")

    def frown(self, x, y, s, ink=OUT):
        a0, a1, r = 1.2 * math.pi, 1.8 * math.pi, s * .34
        cy = y + s * .95
        self.path("M%s %s A%s %s 0 0 1 %s %s" % (n(x + r * math.cos(a0)), n(cy + r * math.sin(a0)), n(r), n(r),
                                                n(x + r * math.cos(a1)), n(cy + r * math.sin(a1))), None, 3, stroke=ink, cap="butt")

    def face(self, x, y, s, mood="happy", ink=OUT):
        self.eyes(x, y, s)
        (self.smile if mood == "happy" else self.frown)(x, y, s, ink)

    def svg(self, box=(-120, -120, 240, 240)):
        return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="%s %s %s %s" width="%s" height="%s">\n%s\n</svg>\n'
                % (n(box[0]), n(box[1]), n(box[2]), n(box[3]), n(box[2]), n(box[3]), "\n".join(self.out)))


def star_pts(cx, cy, r_out, r_in, points=5, turn=-90.0):
    pts = []
    for i in range(points * 2):
        a = math.radians(turn + i * 180.0 / points)
        r = r_in if i % 2 else r_out
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


# ---------------------------------------------------------------------------------
# Chicken parts, shared by every form that shows one (in this world everyone is a chicken).

RED, BEAK, LEG = "#d7342d", "#f2a51d", "#e58a1f"


def comb(p, x, y, s, fill=RED):
    """Three bumps on top of a head centred at (x, y) with radius s."""
    p.path("M%s %s C%s %s %s %s %s %s C%s %s %s %s %s %s C%s %s %s %s %s %s C%s %s %s %s %s %s Z" % tuple(n(v) for v in (
        x - s * .55, y - s * .72,
        x - s * .75, y - s * 1.35, x - s * .2, y - s * 1.4, x - s * .18, y - s * .98,
        x - s * .2, y - s * 1.75, x + s * .42, y - s * 1.62, x + s * .3, y - s * 1.0,
        x + s * .55, y - s * 1.45, x + s * .95, y - s * 1.05, x + s * .62, y - s * .66,
        x + s * .3, y - s * .9, x - s * .3, y - s * .9, x - s * .55, y - s * .72)), fill, 3)


def beak(p, x, y, s, fill=BEAK):
    """A beak seen from the front, a diamond with a mouth line, centred at (x, y)."""
    p.poly([(x - s * .34, y), (x, y - s * .2), (x + s * .34, y), (x, y + s * .36)], fill, 3)
    p.path("M%s %s L%s %s" % (n(x - s * .34), n(y), n(x + s * .34), n(y)), None, 2)


def wattle(p, x, y, s, fill=RED):
    for sx in (-1, 1):
        p.ellipse(x + sx * s * .15, y + s * .2, s * .15, s * .24, fill, 3)


def chicken_head(p, x, y, s, fill="#fbf7ea", comb_fill=RED, with_comb=True, look=0.0):
    if with_comb:
        comb(p, x, y, s, comb_fill)
    p.circle(x, y, s, fill)
    wattle(p, x, y + s * .5, s)
    beak(p, x, y + s * .28, s)
    p.eyes(x, y - s * .2, s * .62, look)


def feet(p, x, y, s):
    for sx in (-1, 1):
        fx = x + sx * s * .3
        p.path("M%s %s L%s %s M%s %s L%s %s L%s %s M%s %s L%s %s" % tuple(n(v) for v in (
            fx, y, fx, y + s * .36, fx - s * .2, y + s * .5, fx, y + s * .36, fx + s * .2, y + s * .5,
            fx, y + s * .36, fx, y + s * .54)), None, 3, stroke=LEG)


# ---------------------------------------------------------------------------------
# Pecking Order: rooster, hen, chick, egg.

def rooster(p):
    # tail feathers behind
    for d, col in [("M-34 30 C-98 30 -112 -24 -84 -62 C-80 -22 -60 -8 -30 -4 Z", "#2f7d6b"),
                   ("M-30 34 C-104 52 -118 6 -104 -28 C-88 4 -60 10 -30 8 Z", "#e0902f"),
                   ("M-28 42 C-92 78 -116 44 -112 12 C-92 36 -62 30 -32 22 Z", "#c7382f")]:
        p.path(d, col, 3)
    feet(p, 4, 70, 60)
    p.ellipse(2, 34, 50, 44, "#c7632b")
    p.path("M-22 30 C-2 62 30 50 34 22", None, 3)
    chicken_head(p, 22, -38, 40, "#d9843a")


def hen(p):
    p.ellipse(0, 78, 84, 22, "#d9a441")
    for x in (-62, -34, -6, 22, 50):
        p.path("M%s 70 L%s 92" % (x, x + 12), None, 2, stroke="#8b5a2b")
    p.path("M-70 60 C-84 -8 -46 -34 0 -34 C46 -34 84 -8 70 60 C50 82 -50 82 -70 60 Z", "#fbf7ea")
    p.path("M-66 34 C-96 30 -104 -2 -88 -22 C-80 0 -66 6 -56 6", "#efe6cf", 3)
    p.path("M36 44 C16 74 -20 62 -24 34", None, 3)
    chicken_head(p, 6, -40, 36)


def chick(p):
    feet(p, 0, 62, 54)
    p.path("M-8 -64 C-22 -92 0 -96 2 -74 C8 -98 30 -90 12 -62", "#f7d13d", 3)
    p.circle(0, 2, 66, "#f7d13d")
    for sx in (-1, 1):
        p.path("M%s 6 C%s -6 %s 30 %s 40 C%s 34 %s 22 %s 6 Z" % (n(sx * 60), n(sx * 92), n(sx * 88), n(sx * 62), n(sx * 56), n(sx * 54), n(sx * 60)),
               "#f2b21e", 3)
    beak(p, 0, 10, 46)
    p.eyes(0, -18, 46)


def egg(p):
    p.path("M0 -92 C46 -92 74 -22 74 22 C74 66 42 92 0 92 C-42 92 -74 66 -74 22 C-74 -22 -46 -92 0 -92 Z", "#f3dcb4")
    p.path("M-70 -6 L-44 -24 L-22 -4 L2 -26 L26 -6 L48 -24 L70 -8", None, 3)
    p.ellipse(-34, -52, 10, 18, "#fff6e0", 0, rot=28)
    p.face(0, 22, 44)


# ---------------------------------------------------------------------------------
# Ka-Bawk!: round bomb, C-4, grenade, shell.

def spark(p, x, y, r):
    p.poly(star_pts(x, y, r, r * .46, 8, -90), "#ffd23a", 3)
    p.poly(star_pts(x, y, r * .5, r * .24, 8, -67), "#ff7a1a", 0)


def bomb(p):
    p.path("M22 -64 C30 -96 58 -100 70 -80", None, 0)
    p.line("M22 -62 C28 -96 58 -102 72 -80", OUT, 13 + 4 * p.k)
    p.line("M22 -62 C28 -96 58 -102 72 -80", "#c9a36a", 9)
    spark(p, 78, -78, 30)
    p.rect(-4, -76, 46, 30, "#7d8794", r=5, rot=14)
    p.circle(-6, 16, 80, "#2b303b")
    p.path("M-62 -6 C-58 -34 -40 -50 -18 -54", None, 0)
    p.line("M-60 -4 C-56 -32 -38 -48 -18 -52", "#5a6274", 12)
    p.circle(-52, 22, 6, "#5a6274", 0)


def c4(p):
    # three sticks strapped together, a timer on top, two wires
    for x in (-78, -28, 22):
        p.rect(x, -34, 56, 108, "#e3b56a", r=10)
    for y in (-32, 52):
        p.rect(-86, y, 172, 18, "#2b303b", 3, r=3)
    p.path("M-50 -52 C-74 -96 -8 -104 -18 -62", None, 0)
    p.line("M-52 -40 C-76 -96 -8 -104 -16 -62", OUT, 9 + 4 * p.k)
    p.line("M-52 -40 C-76 -96 -8 -104 -16 -62", "#d7342d", 6)
    p.line("M48 -40 C82 -90 14 -104 26 -62", OUT, 9 + 4 * p.k)
    p.line("M48 -40 C82 -90 14 -104 26 -62", "#2f7fe0", 6)
    p.rect(-44, -70, 88, 50, "#3a4150", r=6)
    p.rect(-34, -61, 68, 32, "#1a0d0f", 2, r=3)
    for i, x in enumerate((-27, -11, 11, 27)):
        p.rect(x - 5, -55, 10, 20, "#ff3b30", 0, r=2)
    for y in (-49, -41):
        p.circle(0, y, 2.6, "#ff3b30", 0)
    for x in (-50, 0, 50):
        p.path("M%s -2 L%s 40" % (x - 14, x - 14), None, 2, stroke="#f3d9a4")


def grenade(p):
    p.circle(60, -66, 22, None, 5, stroke=OUT)
    p.circle(60, -66, 22, None, 2, stroke="#e7c04b")
    p.path("M-26 -80 L34 -80 L78 -30 L78 12 L62 12 L62 -22 L24 -56 L-26 -56 Z", "#8f99a6", 3)
    p.rect(-24, -66, 48, 30, "#6b7480", r=4)
    p.path("M0 -44 C50 -44 70 -2 70 26 C70 68 40 92 0 92 C-40 92 -70 68 -70 26 C-70 -2 -50 -44 0 -44 Z", "#5f8a3a")
    for d in ("M-66 6 L66 6", "M-66 46 L66 46", "M-24 -40 L-24 88", "M24 -40 L24 88"):
        p.path(d, None, 2, stroke="#3d5f24")
    p.path("M-50 -8 C-40 -26 -22 -34 -6 -36", None, 0)
    p.line("M-48 -6 C-40 -22 -24 -30 -8 -33", "#86b35c", 9)


def shell(p):
    p.group("rotate(28)")
    p.path("M0 -104 C30 -70 38 -36 38 -8 L38 34 L-38 34 L-38 -8 C-38 -36 -30 -70 0 -104 Z", "#5d7a4a")
    p.rect(-38, -6, 76, 15, "#f2c230", 3)
    p.rect(-40, 34, 80, 52, "#d9a441", r=3)
    p.rect(-46, 82, 92, 14, "#b9832c", 3, r=4)
    p.path("M-22 44 L-22 76", None, 2, stroke="#f3d27a")
    p.path("M-20 -70 C-26 -50 -27 -30 -27 -16", None, 2, stroke="#8aa873")
    p.end()


# ---------------------------------------------------------------------------------
# One Flock: Uncle Cluck, Lady Liberty hen, the bell, a rocket.

def uncle(p):
    chicken_head(p, 0, 26, 52, with_comb=False)
    p.path("M-22 66 C-18 96 -6 108 0 110 C6 108 18 96 22 66 C8 76 -8 76 -22 66 Z", "#ffffff", 3)
    p.ellipse(0, -22, 78, 15, "#f6f1e6")
    p.path("M-46 -24 L-40 -102 L40 -102 L46 -24 Z", "#f6f1e6")
    for x in (-27, 0, 27):
        p.path("M%s -100 L%s -52 L%s -52 L%s -100 Z" % (n(x - 7), n(x - 8), n(x + 8), n(x + 7)), "#d7342d", 0)
    p.path("M-44 -52 L44 -52 L46 -24 L-46 -24 Z", "#2a4fb0", 3)
    for x in (-26, 0, 26):
        p.poly(star_pts(x, -38, 9, 4), "#ffffff", 0)
    p.path("M-46 -24 L-40 -102 L40 -102 L46 -24 Z", None)


def liberty(p):
    green, dark = "#8fd0b4", "#5fa98c"
    for a in (-60, -30, 0, 30, 60):
        p.group("rotate(%d 0 0)" % a)
        p.path("M-10 -40 L0 -108 L10 -40 Z", green, 3)
        p.end()
    p.circle(0, 14, 58, green)
    p.path("M-56 -8 C-36 -46 36 -46 56 -8 C30 -22 -30 -22 -56 -8 Z", dark, 3)
    for sx in (-1, 1):
        p.ellipse(sx * 8, 54, 9, 14, dark, 3)
    beak(p, 0, 30, 58, "#c8eedd")
    p.eyes(0, 4, 36)
    # the torch, held up at the right
    p.path("M70 4 L92 4 L86 60 L76 60 Z", "#d9a441", 3)
    p.path("M62 -8 L100 -8 L94 8 L68 8 Z", "#b9832c", 3)
    p.path("M81 -62 C100 -36 100 -20 92 -8 L70 -8 C60 -22 68 -34 72 -40 C74 -32 78 -30 80 -30 C76 -44 76 -52 81 -62 Z", "#ffb21e", 3)


def bell(p):
    p.rect(-12, -98, 24, 22, "#8b5a2b", 3, r=4)
    p.path("M-34 -78 L34 -78 C40 -30 52 12 78 52 L-78 52 C-52 12 -40 -30 -34 -78 Z", "#c98b3a")
    p.rect(-84, 50, 168, 18, "#a86f28", r=6)
    p.circle(0, 82, 14, "#8b5a2b", 3)
    p.path("M10 52 L2 30 L14 14 L4 -6", None, 3)
    p.path("M-28 -62 L28 -62 M-36 -30 L36 -30", None, 2, stroke="#8b5a2b")
    p.path("M-34 -6 C-40 14 -48 28 -56 40", None, 2, stroke="#e8b872")


def rocket(p):
    p.group("rotate(32)")
    p.path("M-4 60 L-4 112", None, 0)
    p.line("M0 56 L0 112", OUT, 7 + 4 * p.k, cap="butt")
    p.line("M0 56 L0 110", "#c9a36a", 7, cap="butt")
    p.path("M-30 -40 L30 -40 L30 60 L-30 60 Z", "#f6f1e6")
    for y in (-22, 12, 46):
        p.path("M-30 %s L30 %s L30 %s L-30 %s Z" % (y - 9, y - 9, y + 5, y + 5), "#d7342d", 0)
    p.path("M-30 -40 L30 -40 L30 60 L-30 60 Z", None)
    p.path("M-36 -40 L0 -104 L36 -40 Z", "#2a4fb0")
    p.poly(star_pts(0, -62, 12, 5.5), "#ffffff", 0)
    p.end()
    for x, y, r in ((-74, -62, 18), (-90, -8, 12), (-40, -96, 12)):
        p.poly(star_pts(x, y, r, r * .42, 4, 0), "#ffd23a", 2)


# ---------------------------------------------------------------------------------
# Nugget Rush: dino, star, boot, ball. One crumb coat for all four.

CRUST, CRUMB = "#d99a3c", "#b87428"


def crumbs(p, spots):
    for x, y in spots:
        p.ellipse(x, y, 4.5, 3, CRUMB, 0, rot=(x * 7 + y * 3) % 90)


def nug_dino(p):
    p.path("M-98 34 C-80 26 -66 6 -40 -6 C-14 -18 10 -18 22 -8 C30 -30 30 -62 44 -80 C56 -96 92 -96 98 -74 "
           "C102 -58 84 -50 70 -52 C66 -34 66 -10 62 12 C60 30 60 52 58 74 L32 74 L30 48 C18 54 2 54 -10 48 "
           "L-12 74 L-40 74 L-40 40 C-58 44 -80 46 -98 34 Z", CRUST)
    crumbs(p, [(-58, 26), (-22, 8), (-4, 34), (22, 14), (44, 40), (48, -22), (-28, 56), (46, 62)])
    crumbs(p, [(74, -74), (58, -62), (-76, 34), (2, 4)])


def nug_star(p):
    pts = star_pts(0, 4, 100, 50)
    d = "M"
    m = len(pts)
    for i in range(m):
        a, b, c = pts[i - 1], pts[i], pts[(i + 1) % m]
        e0 = (b[0] + (a[0] - b[0]) * .22, b[1] + (a[1] - b[1]) * .22)
        e1 = (b[0] + (c[0] - b[0]) * .22, b[1] + (c[1] - b[1]) * .22)
        d += ("%s %s Q%s %s %s %s L" if i else "%s %s Q%s %s %s %s L") % tuple(n(v) for v in (e0 + b + e1))
    p.path(d[:-1] + "Z", CRUST)
    crumbs(p, [(0, -62), (-58, -14), (58, -14), (-40, 60), (40, 60), (0, 46), (-26, -22), (30, -26), (0, 8), (-14, 28), (22, 14)])


def nug_boot(p):
    p.path("M-52 -92 C-24 -100 10 -98 26 -88 C34 -54 30 -22 32 4 C62 4 96 22 98 52 C100 78 84 88 60 88 "
           "L-44 88 C-66 88 -72 70 -68 48 C-62 6 -64 -44 -52 -92 Z", CRUST)
    crumbs(p, [(-34, -70), (4, -74), (-46, 30), (-14, 62), (30, 40), (66, 62), (8, -34), (-40, 70), (-22, -22), (-4, 6), (-30, -44)])


def nug_ball(p):
    p.path("M-6 -84 C36 -90 78 -60 84 -14 C90 34 60 78 12 84 C-36 90 -80 62 -86 12 C-92 -36 -52 -78 -6 -84 Z", CRUST)
    crumbs(p, [(-46, -44), (40, -52), (-60, 16), (58, 18), (-30, 58), (28, 60), (0, -62), (4, 52), (-12, -14), (16, 8), (-22, 22), (24, -22)])


# ---------------------------------------------------------------------------------
# Peckeye: the sailor, his can of spinach, an anchor, the pipe.

def sailor(p, x=0.0, y=0.0):
    comb(p, x + 4, y + 2, 50)
    p.circle(x, y + 16, 56, "#fbf7ea")
    # one eye squeezed shut, the other wide open
    p.path("M%s %s C%s %s %s %s %s %s" % tuple(n(v) for v in (x - 38, y + 2, x - 28, y - 12, x - 12, y - 12, x - 4, y + 2)), None, 4, cap="round")
    p.circle(x + 26, y - 2, 19, "#fff", 2)
    p.circle(x + 30, y + 1, 8.5, OUT, 0)
    wattle(p, x - 4, y + 48, 54)
    # corncob pipe out of the corner of the beak
    p.path("M%s %s L%s %s L%s %s L%s %s Z" % tuple(n(v) for v in (x + 14, y + 36, x + 70, y + 26, x + 72, y + 38, x + 16, y + 48)), "#6b4423", 3)
    p.rect(x + 64, y - 2, 34, 42, "#e7c04b", 3, r=7)
    p.path("M%s %s L%s %s M%s %s L%s %s" % tuple(n(v) for v in (x + 66, y + 12, x + 96, y + 12, x + 66, y + 26, x + 96, y + 26)), None, 2, stroke="#b9832c")
    for cx, cy, r in ((x + 84, y - 22, 11), (x + 98, y - 46, 15), (x + 84, y - 76, 19)):
        p.circle(cx, cy, r, "#f6f1e6", 3)
    beak(p, x - 6, y + 32, 56)
    # the cap
    p.path("M%s %s C%s %s %s %s %s %s L%s %s L%s %s Z" % tuple(n(v) for v in (
        x - 48, y - 30, x - 52, y - 84, x + 44, y - 92, x + 50, y - 38, x + 52, y - 22, x - 50, y - 14)), "#ffffff")
    p.path("M%s %s L%s %s L%s %s L%s %s Z" % tuple(n(v) for v in (x - 54, y - 30, x + 54, y - 40, x + 56, y - 20, x - 52, y - 10)), "#2a4fb0", 3)


def spinach(p):
    for d, col in [("M-34 -44 C-70 -74 -50 -110 -18 -96 C-2 -88 -6 -60 -14 -44 Z", "#3f9b46"),
                   ("M-6 -44 C-18 -92 22 -116 40 -92 C52 -72 30 -54 18 -44 Z", "#56b34f"),
                   ("M22 -44 C40 -70 76 -66 72 -40 C70 -28 50 -30 40 -40 Z", "#3f9b46")]:
        p.path(d, col, 3)
    p.path("M-22 -52 C-28 -70 -30 -80 -30 -88 M14 -52 C18 -74 22 -84 26 -92", None, 2, stroke="#2c6e33")
    p.rect(-56, -44, 112, 132, "#c9d2da", r=8)
    p.rect(-56, -24, 112, 92, "#3f9b46", 3)
    p.ellipse(0, -44, 56, 13, "#e3e9ee", 3)
    p.ellipse(0, -44, 40, 7, "#2c6e33", 2)
    p.ellipse(0, 22, 34, 30, "#fbf7ea", 3)
    p.path("M-2 44 C-26 30 -24 6 0 -2 C24 6 26 30 2 44 Z", "#56b34f", 3)
    p.path("M0 44 L0 6", None, 2, stroke="#2c6e33")


def anchor(p):
    grey = "#8ea3b5"
    p.line("M0 -99 A19 19 0 1 1 -0.1 -99", OUT, 17)
    p.path("M-80 16 C-84 74 -30 96 0 96 C30 96 84 74 80 16 L96 28 L84 -14 L46 12 L62 18 C60 52 30 68 14 70 "
           "L14 -30 L44 -30 L44 -52 L14 -52 L14 -64 L-14 -64 L-14 -52 L-44 -52 L-44 -30 L-14 -30 L-14 70 "
           "C-30 68 -60 52 -62 18 L-46 12 L-84 -14 L-96 28 Z", grey)
    p.line("M0 -99 A19 19 0 1 1 -0.1 -99", grey, 9)


def pipe(p):
    for cx, cy, r in ((34, -40, 12), (52, -66, 17), (30, -94, 21)):
        p.circle(cx, cy, r, "#f6f1e6", 3)
    p.path("M-100 28 C-70 24 -40 40 -6 50 L8 78 C-34 78 -70 50 -100 46 Z", "#6b4423")
    p.rect(-6, -22, 78, 104, "#e7c04b", r=14)
    for y in (4, 30, 56):
        p.path("M-4 %s L70 %s" % (y, y), None, 2, stroke="#b9832c")
    p.ellipse(33, -22, 39, 10, "#3a2a1b", 3)


# ---------------------------------------------------------------------------------
# Lucky Spur's star and cactus, as the web build drew them (SYMBOLS.star, SYMBOLS.cactus
# in reference/last-sale-source.html), without the face.

def spur_star(p):
    p.poly(star_pts(0, 0, 95, 42), "#e7c04b")
    for i in range(5):
        a = math.radians(-90 + i * 72)
        p.circle(math.cos(a) * 95, math.sin(a) * 95, 11, "#f7e08a", 2)
    p.circle(0, 0, 27, "#f7e08a", 3)
    p.poly(star_pts(0, 0, 17, 7.5), "#e7c04b", 2)


def spur_cactus(p):
    g = "#4da25a"
    p.path("M-72 -45 L-72 -5 A20 20 0 0 0 -52 15 L-25 -2 L-52 -2 L-52 -45 Z", g, 3)
    p.path("M72 -65 L72 -25 A20 20 0 0 1 52 -5 L25 -22 L52 -22 L52 -65 Z", g, 3)
    p.rect(-32, -92, 64, 175, g, r=30)
    for y in (-60, -20, 20, 56):
        for x in (-12, 12):
            p.path("M%s %s L%s %s" % (x, y, x, y + 14), None, 2, stroke="#2f6e3b")


SYMBOLS = {
    "rooster": rooster, "hen": hen, "chick": chick, "whole_egg": egg,
    "bomb": bomb, "c4": c4, "grenade": grenade, "shell": shell,
    "uncle": uncle, "liberty": liberty, "bell": bell, "rocket": rocket,
    "nug_dino": nug_dino, "nug_star": nug_star, "nug_boot": nug_boot, "nug_ball": nug_ball,
    "sailor": sailor, "spinach": spinach, "anchor": anchor, "pipe": pipe,
    "star": spur_star, "cactus": spur_cactus,
}
# The game's pictures for every other name now come from tools/import_symbol_art.py (painted
# outside this file). Only these are still written to packs/core/art/ from here; `--all` writes
# the old drawings of the others over the imported ones, to look at them again.
STILL_DRAWN_HERE = ("nug_dino", "nug_star", "nug_boot", "nug_ball", "flock_flag")


# ---------------------------------------------------------------------------------
# Front illustrations.

def flag(p, w=600.0, h=330.0):
    """Old Glory, waving, with a hen for every star."""
    amp, waves, steps = 9.0, 1.5, 48

    def wy(x, y):
        return y + amp * math.sin(2 * math.pi * waves * x / w + .6) * (.35 + .65 * x / w)

    def band(x0, x1, y0, y1):
        top = [(x0 + (x1 - x0) * i / steps, 0) for i in range(steps + 1)]
        pts = [(x, wy(x, y0)) for x, _ in top] + [(x, wy(x, y1)) for x, _ in reversed(top)]
        return "M" + " L".join("%s %s" % (n(x), n(y)) for x, y in pts) + " Z"

    stripe = h / 13.0
    for i in range(13):
        p.path(band(0, w, i * stripe, (i + 1) * stripe + .6), "#c8102e" if i % 2 == 0 else "#ffffff", 0)
    cw, ch = w * .42, stripe * 7
    p.path(band(0, cw, 0, ch), "#1f3a93", 0)
    rows = 5
    for r in range(rows):
        count = 6 if r % 2 == 0 else 5
        for c in range(count):
            x = cw * (c + (.5 if r % 2 == 0 else 1.0)) / 6.0
            y = wy(x, ch * (r + .5) / rows)
            s = 11.0
            # a hen in white: body, head, tail, with a red comb and a gold beak
            p.path("M%s %s L%s %s L%s %s Z" % tuple(n(v) for v in (x - s * .7, y + s * .1, x - s * 1.5, y - s * .9, x - s * .2, y - s * .3)), "#ffffff", 0)
            p.ellipse(x, y + s * .25, s, s * .72, "#ffffff", 0)
            p.circle(x + s * .8, y - s * .55, s * .5, "#ffffff", 0)
            p.path("M%s %s L%s %s L%s %s Z" % tuple(n(v) for v in (x + s * 1.2, y - s * .7, x + s * 1.75, y - s * .5, x + s * 1.2, y - s * .3)), "#ffc93a", 0)
            p.circle(x + s * .8, y - s * 1.05, s * .24, "#ff5a4d", 0)
            p.circle(x + s * .95, y - s * .62, s * .1, "#1f3a93", 0)
    edge = [(w * i / steps, wy(w * i / steps, 0)) for i in range(steps + 1)] + \
           [(w * i / steps, wy(w * i / steps, h)) for i in range(steps, -1, -1)]
    p.poly(edge, None, 5)


def peckeye_hero(p):
    """The sailor from the chest up, one great forearm raised, an anchor inked on it."""
    skin = "#fbf7ea"
    # chest in a sailor's shirt
    p.path("M-150 190 C-150 96 -96 58 -30 58 C36 58 86 96 90 190 Z", "#22324f")
    p.path("M-70 60 L-30 122 L14 60 Z", "#ffffff", 3)
    p.path("M-52 64 L-30 100 L-6 64", None, 3, stroke="#d7342d")
    # the raised arm: a thin upper arm into a forearm like a ham
    p.path("M70 120 C100 110 128 92 138 64 L176 86 C160 130 116 164 82 172 Z", skin)
    p.path("M132 70 C96 30 96 -52 140 -92 C176 -124 236 -112 246 -62 C258 -4 226 58 178 88 Z", skin)
    # fist
    p.path("M150 -94 C140 -130 164 -160 198 -158 C232 -156 254 -128 244 -92 C236 -66 168 -62 150 -94 Z", skin)
    p.path("M170 -150 L176 -118 M194 -156 L198 -122 M218 -150 L218 -118", None, 3)
    # the tattoo
    p.group("translate(186 -18) rotate(14) scale(.46)")
    p.path("M-80 16 C-84 74 -30 96 0 96 C30 96 84 74 80 16 L96 28 L84 -14 L46 12 L62 18 C60 52 30 68 14 70 "
           "L14 -30 L44 -30 L44 -52 L14 -52 L14 -64 L-14 -64 L-14 -52 L-44 -52 L-44 -30 L-14 -30 L-14 70 "
           "C-30 68 -60 52 -62 18 L-46 12 L-84 -14 L-96 28 Z", "#2a4fb0", 0)
    p.circle(0, -80, 17, None, 0)
    p.line("M0 -97 A17 17 0 1 1 -0.1 -97", "#2a4fb0", 9)
    p.end()
    # head on top of it all
    p.group("translate(-34 -22) scale(1.02)")
    sailor(p)
    p.end()


HEROES = {
    # name: (function, viewBox, pixels per unit)
    "flock_flag": (flag, (-6, -16, 612, 362), 2.0),
    "peckeye_hero": (peckeye_hero, (-160, -180, 430, 370), 2.4),
}


def main():
    os.makedirs(BUILD, exist_ok=True)
    with open(os.path.join(BUILD, ".gdignore"), "w") as f:
        f.write("")
    jobs = []
    for key, fn in SYMBOLS.items():
        if key not in STILL_DRAWN_HERE and "--all" not in sys.argv:
            continue
        for suffix, k, px in (("", K_SMALL, 512), ("_large", K_LARGE, 1024)):
            p = Pen(k)
            fn(p)
            svg = os.path.join(BUILD, key + suffix + ".svg")
            with open(svg, "w", encoding="utf-8", newline="\n") as f:
                f.write(p.svg())
            jobs.append({"svg": svg, "png": os.path.join(ART, key + suffix + ".png"), "scale": px / 240.0})
    for key, (fn, box, scale) in HEROES.items():
        if key not in STILL_DRAWN_HERE and "--all" not in sys.argv:
            continue
        p = Pen(1.0)
        fn(p)
        svg = os.path.join(BUILD, key + ".svg")
        with open(svg, "w", encoding="utf-8", newline="\n") as f:
            f.write(p.svg(box))
        jobs.append({"svg": svg, "png": os.path.join(ART, key + ".png"), "scale": scale})
    manifest = os.path.join(BUILD, "jobs.json")
    with open(manifest, "w", encoding="utf-8") as f:
        json.dump(jobs, f)
    subprocess.run([GODOT, "--headless", "--path", ROOT, "-s", "res://tools/raster_svg.gd", "--", manifest], check=True)
    if "--sheet" in sys.argv:
        from PIL import Image
        keys = list(SYMBOLS)
        cell, cols = 256, 8
        rows = (len(keys) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * cell, rows * cell * 2), "#8fa3ad")
        for i, key in enumerate(keys):
            for j, suffix in enumerate(("", "_large")):
                im = Image.open(os.path.join(ART, key + suffix + ".png")).convert("RGBA")
                # the small one at the size it is printed (about 1/4), the large one filling the cell
                size = cell if j else cell // 2
                im = im.resize((size, size), Image.LANCZOS)
                x = (i % cols) * cell + (cell - size) // 2
                y = (i // cols) * cell * 2 + j * cell + (cell - size) // 2
                sheet.paste(im, (x, y), im)
        sheet.save(os.path.join(BUILD, "sheet.png"))
    print("wrote %d images" % len(jobs))


if __name__ == "__main__":
    main()
