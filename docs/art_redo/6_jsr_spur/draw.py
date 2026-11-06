"""Lucky Spur's four symbols in the manner of reference 6 (cel-shaded street graffiti):
a rough doubled ink line, angular skewed shapes, flat colour with one hard shadow, and a spiky
spray field behind each thing.

    python docs/art_redo/6_jsr_spur/draw.py        # writes shoe.svg star.svg hat.svg cactus.svg
    python docs/art_redo/render.py 6_jsr_spur      # -> the PNGs

Everything is a polygon, on purpose: the reference has no smooth curve in it.
"""
import math
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))

INK = "#0e0b12"
LIME, LIME_EDGE = "#c6ff00", "#0d6b2a"
PURPLE, PURPLE_EDGE = "#7a12cf", "#2a0050"
YELLOW, ORANGE, RUST = "#ffe21a", "#ff8a1e", "#d1410c"
PINK, PINK_DARK = "#ff4fd8", "#b3129a"
GREEN, GREEN_DARK = "#27b84e", "#0b6e3a"
WHITE = "#fff8e6"
STEEL, STEEL_DARK = "#d8e2fa", "#7f6fd8"


def f(v):
    return ("%.1f" % v).rstrip("0").rstrip(".")


def d(pts, close=True):
    return "M" + " L".join("%s %s" % (f(x), f(y)) for x, y in pts) + (" Z" if close else "")


def xf(pts, rot=0, skew=0, sx=1, sy=1, dx=0, dy=0):
    """Scale, lean (skew, degrees), turn (rot, degrees), then move."""
    r, k = math.radians(rot), math.tan(math.radians(skew))
    out = []
    for x, y in pts:
        x, y = x * sx, y * sy
        x += k * y
        out.append((x * math.cos(r) - y * math.sin(r) + dx, x * math.sin(r) + y * math.cos(r) + dy))
    return out


def move(pts, dx, dy):
    return [(x + dx, y + dy) for x, y in pts]


def ngon(cx, cy, r, n, rot=0, ry=None):
    ry = r if ry is None else ry
    return [(cx + r * math.cos(rot + 2 * math.pi * i / n), cy + ry * math.sin(rot + 2 * math.pi * i / n)) for i in range(n)]


def burst(rnd, cx, cy, rx, ry, n, inner=.74, lean=.5, jit=.1, rot=0.0):
    """A saw-toothed spray field: n spikes leaning one way round, none quite like its neighbour."""
    pts = []
    step = 2 * math.pi / n
    for i in range(n):
        a = rot + step * i + rnd.uniform(-.12, .12) * step
        ro = 1 + rnd.uniform(-jit, jit)
        pts.append((cx + rx * ro * math.cos(a + lean * step * .5), cy + ry * ro * math.sin(a + lean * step * .5)))
        ri = inner * (1 + rnd.uniform(-jit * .5, jit * .5))
        pts.append((cx + rx * ri * math.cos(a + step * .62), cy + ry * ri * math.sin(a + step * .62)))
    return pts


def arrow(x0, y0, x1, y1, shaft=13, head=32, head_len=26):
    """A chunky arrow from (x0, y0) to its tip at (x1, y1)."""
    L = math.hypot(x1 - x0, y1 - y0)
    ux, uy = (x1 - x0) / L, (y1 - y0) / L
    nx, ny = -uy, ux
    bx, by = x1 - ux * head_len, y1 - uy * head_len
    h, s = head / 2, shaft / 2
    return [(x0 + nx * s, y0 + ny * s), (bx + nx * s, by + ny * s), (bx + nx * h - ux * 5, by + ny * h - uy * 5), (x1, y1),
            (bx - nx * h + ux * 3, by - ny * h + uy * 3), (bx - nx * s, by - ny * s), (x0 - nx * s, y0 - ny * s)]


def drip(x, y, w, length):
    """A paint run hanging from (x, y): square shoulders, a fat faceted bead at the end."""
    h = w / 2
    return [(x - h, y), (x - h + .6, y + length - h), (x - h - 1.6, y + length + 1), (x - 1, y + length + h + 3.5),
            (x + h + 1.2, y + length + 1.5), (x + h - .4, y + length - h - 1), (x + h, y)]


class Art:
    def __init__(self, seed):
        self.rnd = random.Random(seed)
        self.seed = seed
        self.defs = []
        self.el = []
        self.clips = 0

    # -- plain shapes
    def fill(self, pts, color):
        self.el.append('<path d="%s" fill="%s"/>' % (d(pts), color))

    def stroke(self, pts, color, w, close=True, join="miter", cap="butt", limit=5):
        self.el.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="%s" stroke-linecap="%s" stroke-miterlimit="%s"/>'
                       % (d(pts, close), color, f(w), join, cap, limit))

    def clip_open(self, shapes):
        self.clips += 1
        cid = "c%d" % self.clips
        self.defs.append('<clipPath id="%s"><path d="%s"/></clipPath>' % (cid, " ".join(d(s) for s in shapes)))
        self.el.append('<g clip-path="url(#%s)">' % cid)

    def clip_close(self):
        self.el.append("</g>")

    def jit(self, pts, a):
        return [(x + self.rnd.uniform(-a, a), y + self.rnd.uniform(-a, a)) for x, y in pts]

    # -- the ink line
    def ink(self, pts, w=5.0, close=True, wander=2.1, over=.7, color=INK):
        """A hand-inked outline: the line itself, a second pass a little off it (heavier toward the
        lower right, where the two lie side by side), a thin stray line that wanders in and out, and
        strokes that run on past the corners."""
        self.stroke(pts, color, w, close)
        self.stroke(move(self.jit(pts, .5), w * .26, w * .3), color, w * .72, close)
        if wander:
            stray = self.jit(pts, wander)
            if close:
                k = self.rnd.randrange(len(stray))
                stray = stray[k:] + stray[:k]  # start anywhere and stop one edge short: the gap shows it is a second line
            self.stroke(move(stray, -w * .2, -w * .16), color, w * .3, False, cap="round", join="round")
        if over:
            m = len(pts)
            for i in range(m):
                if not close and i in (0, m - 1):
                    continue
                if self.rnd.random() > over:
                    continue
                (px, py), (x, y), (qx, qy) = pts[i - 1], pts[i], pts[(i + 1) % m]
                for ax, ay in ((px, py), (qx, qy)):
                    L = math.hypot(x - ax, y - ay)
                    if L < 9 or self.rnd.random() < .35:
                        continue
                    e = self.rnd.uniform(3, 8)
                    ux, uy = (x - ax) / L, (y - ay) / L
                    self.stroke([(x - ux * 2, y - uy * 2), (x + ux * e, y + uy * e)], color, w * .3, False, cap="round")

    def line(self, pts, w=2.2, wander=0, color=INK):
        self.stroke(pts, color, w, False, join="round", cap="round")
        if wander:
            self.stroke(move(self.jit(pts, wander), .8, .6), color, w * .55, False, join="round", cap="round")

    # -- a thing with one hard shadow
    def block(self, shapes, depth=7):
        """The thing's side, as sprayed block letters have one: pushed down and right in black."""
        for i in range(1, depth + 1):
            for s in shapes:
                p = move(s, i * .86, i)
                self.fill(p, INK)
                if i == depth:
                    self.stroke(p, INK, 4.5)

    def body(self, shapes, base, shade, dx=5.5, dy=6.5, light=None, lx=2.6, ly=3):
        """Fill the shapes, with a hard-edged rim of shadow along every lower right edge
        (and, for metal, a rim of light along the upper left ones)."""
        self.clip_open(shapes)
        for s in shapes:
            self.fill(s, shade)
        for s in shapes:
            self.fill(move(s, -dx, -dy), base)
        if light:
            self.clips += 1
            mid = "m%d" % self.clips
            every = " ".join(d(s) for s in shapes)
            self.defs.append('<mask id="%s"><rect x="-130" y="-130" width="260" height="260" fill="#000"/>'
                             '<path d="%s" fill="#fff"/><path d="%s" fill="#000" transform="translate(%s %s)"/></mask>'
                             % (mid, every, every, f(lx), f(ly)))
            self.el.append('<rect x="-130" y="-130" width="260" height="260" fill="%s" mask="url(#%s)"/>' % (light, mid))
        self.clip_close()

    # -- the spray field behind
    def field(self, shapes, color, edge, sticker=True):
        if sticker:
            for s in shapes:
                self.stroke(move(s, 2.5, 3), WHITE, 21, limit=3)
            for s in shapes:
                self.fill(move(s, 2.5, 3), WHITE)
        for s in shapes:
            p = move(s, 5, 6)
            self.fill(p, INK)
            self.stroke(p, INK, 7, limit=4)
        for s in shapes:
            self.stroke(s, edge, 7.5, limit=4)
        for s in shapes:
            self.fill(s, color)
        for s in shapes:  # the stray second line, inside the edge
            if len(s) < 10:
                continue
            stray = self.jit(s, 1.4)
            k = self.rnd.randrange(len(stray))
            self.stroke((stray[k:] + stray[:k])[:-1], edge, 1.5, False, join="round", cap="round")

    def spark(self, x, y, r, color=WHITE, rot=0.0):
        """A four-point glint: a black one with a smaller light one inside it."""
        def star4(tip, waist, wide=1.2):
            pts = []
            for i in range(8):
                t = rot + math.pi / 4 * i
                rr = tip if i % 2 == 0 else waist
                pts.append((x + rr * math.cos(t) * (wide if i % 4 == 0 else 1), y + rr * math.sin(t)))
            return pts
        outer = star4(r + 5, r * .3 + 3.2)
        self.fill(move(outer, 1.8, 2.2), INK)
        self.fill(outer, INK)
        self.fill(star4(r, r * .3), color)

    def dashes(self, marks, w=5.5, color=INK):
        """Speed marks: short tapering strokes."""
        for (x0, y0, x1, y1) in marks:
            nx, ny = -(y1 - y0), (x1 - x0)
            L = math.hypot(nx, ny)
            nx, ny = nx / L * w / 2, ny / L * w / 2
            self.fill([(x0 + nx, y0 + ny), (x1, y1), (x0 - nx, y0 - ny)], color)

    def svg(self):
        s = self.seed
        return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="-120 -120 240 240">\n<defs>\n'
                '<filter id="hand" x="-130" y="-130" width="260" height="260" filterUnits="userSpaceOnUse">'
                '<feTurbulence type="fractalNoise" baseFrequency="0.017" numOctaves="1" seed="%d" result="a"/>'
                '<feDisplacementMap in="SourceGraphic" in2="a" scale="5" xChannelSelector="R" yChannelSelector="G" result="b"/>'
                '<feTurbulence type="fractalNoise" baseFrequency="0.16" numOctaves="1" seed="%d" result="c"/>'
                '<feDisplacementMap in="b" in2="c" scale="1.1" xChannelSelector="G" yChannelSelector="R"/>'
                '</filter>\n%s\n</defs>\n<g filter="url(#hand)">\n%s\n</g>\n</svg>\n'
                % (s, s + 7, "\n".join(self.defs), "\n".join(self.el)))

    def save(self, name):
        with open(os.path.join(HERE, name + ".svg"), "w", encoding="utf-8") as fh:
            fh.write(self.svg())


# ---------------------------------------------------------------- horseshoe

def shoe():
    a = Art(11)
    T = dict(rot=-10, skew=-4, sx=.95, sy=.95, dx=-2, dy=-5)
    # the old shape of a shoe: widest across the quarters, the heels drawn in toward each other
    outline = [(-50, 84), (-73, 53), (-85, 10), (-81, -30), (-63, -63), (-32, -83), (4, -89), (38, -79), (66, -57), (83, -24), (85, 14), (73, 55), (51, 86),
               (25, 77), (42, 46), (50, 12), (48, -16), (38, -38), (20, -52), (2, -56), (-18, -51), (-36, -37), (-47, -15), (-50, 12), (-43, 46), (-27, 75)]
    body = xf(outline, **T)
    fld = burst(a.rnd, -2, -4, 96, 98, 10, inner=.8, lean=.7, jit=.07, rot=.2)
    arr = arrow(52, -52, 108, -106, shaft=15, head=38, head_len=27)
    drips = [drip(-58, 78, 9, 17), drip(-36, 84, 7, 9), drip(40, 82, 8, 13)]
    a.field([fld, arr] + drips, LIME, LIME_EDGE)

    a.block([body], 7)
    a.body([body], STEEL, STEEL_DARK, light="#ffffff")
    # the chrome's hard streaks of light, as sprayed chrome letters have
    a.clip_open([body])
    for x, w in ((-92, 13), (-70, 6), (8, 5), (22, 12)):
        a.fill(xf([(x, -100), (x + w, -100), (x + w + 62, 100), (x + 62, 100)], rot=-10), "#ffffff")
    a.clip_close()
    # the crease the nails sit in, and the nail holes
    left = xf([(-41, 66), (-58, 44), (-67, 10), (-64, -24), (-50, -50), (-27, -67)], **T)
    right = xf([(40, 68), (57, 46), (67, 12), (65, -22), (52, -48), (30, -65)], **T)
    a.line(left, 1.8, wander=1.3)
    a.line(right, 1.8, wander=1.3)
    for (x, y, r) in [(-52, 52, 34), (-65, 24, 12), (-66, -8, -6), (-57, -38, -28), (-39, -60, -50),
                      (51, 54, -34), (65, 26, -12), (66, -6, 6), (58, -36, 28), (41, -58, 50)]:
        hole = xf(xf([(-3.6, -6.6), (3.6, -6.6), (3.6, 6.6), (-3.6, 6.6)], rot=r, dx=x, dy=y), **T)
        a.fill(move(hole, 1.6, 1.8), STEEL_DARK)
        a.fill(hole, INK)
    a.ink(body, 5.2)
    # the toe clip: a small tab standing up at the top of the arch
    clip = xf([(-9, -86), (-5, -100), (9, -101), (14, -87)], **T)
    a.fill(move(clip, 2.5, 3), INK)
    a.fill(clip, STEEL)
    a.ink(clip, 3.4, wander=1.2, over=.4)
    # heel caulks: a line across each heel
    a.line(xf([(-59, 68), (-38, 62)], **T), 2.2)
    a.line(xf([(37, 63), (60, 70)], **T), 2.2)

    a.spark(-76, -78, 15, WHITE, rot=.3)
    a.spark(-96, -50, 7, YELLOW, rot=.8)
    a.dashes([(86, 34, 110, 28), (88, 50, 108, 52)])
    a.save("shoe")


# ---------------------------------------------------------------- sheriff's star

def star():
    a = Art(23)
    rot = math.radians(9)
    R = [80, 85, 76, 74, 79]
    tips, dents = [], []
    for i in range(5):
        t = rot - math.pi / 2 + i * 2 * math.pi / 5
        tips.append((R[i] * math.cos(t) * 1.02 - 1, R[i] * math.sin(t) - 2))
        t2 = t + math.pi / 5
        dents.append((38 * math.cos(t2) - 1, 38 * math.sin(t2) - 2))
    body = []
    for i in range(5):
        body += [tips[i], dents[i]]
    c = (-1, -2)

    fld = burst(a.rnd, -1, -2, 98, 98, 9, inner=.7, lean=.75, jit=.06, rot=.5)
    drips = [drip(-30, 78, 8, 15), drip(22, 80, 7, 9)]
    a.field([fld] + drips, PURPLE, PURPLE_EDGE)

    balls = [ngon(x * 1.06, y * 1.06, 9.5, 9, rot=i) for i, (x, y) in enumerate(tips)]
    a.block([body] + balls, 6)
    # each arm: lit half, shaded half, split by a ridge from the middle to the tip
    a.fill(body, YELLOW)
    for i in range(5):
        a.fill([c, tips[i], dents[i]], ORANGE)
    for i in (1, 2):  # the two arms that face away from the light go darker still on their far half
        a.fill([c, tips[i], dents[i]], "#f0650e")
    for i in range(5):
        a.line([c, tips[i]], 1.7)
        a.line([c, dents[i]], 1.2)
    a.ink(body, 5.2)
    for i, b in enumerate(balls):
        a.fill(b, YELLOW)
        bx, by = tips[i][0] * 1.06, tips[i][1] * 1.06
        a.clip_open([b])
        a.fill(ngon(bx + 3.2, by + 3.6, 9.5, 9, rot=i), ORANGE)
        a.fill(ngon(bx - 2, by - 2.4, 9.5, 9, rot=i), YELLOW)
        a.clip_close()
        a.ink(b, 3.6, wander=1.0, over=0)
    # the boss in the middle: a ring and a small star cut in it
    ring = ngon(c[0], c[1], 25, 11, rot=.3)
    a.fill(move(ring, 2.2, 2.6), INK)
    a.fill(ring, YELLOW)
    a.clip_open([ring])
    a.fill(move(ring, 0, 0), ORANGE)
    a.fill(move(ring, -4, -4.6), YELLOW)
    a.clip_close()
    a.ink(ring, 3.8, wander=1.2, over=.3)
    small = []
    for i in range(5):
        t = rot - math.pi / 2 + i * 2 * math.pi / 5
        small += [(c[0] + 15 * math.cos(t), c[1] + 15 * math.sin(t)), (c[0] + 6.2 * math.cos(t + math.pi / 5), c[1] + 6.2 * math.sin(t + math.pi / 5))]
    a.fill(small, PURPLE_EDGE)
    a.stroke(small, INK, 1.6)

    a.spark(-70, -72, 14, WHITE, rot=.2)
    a.spark(80, 66, 9, PINK, rot=.7)
    a.dashes([(-94, 24, -114, 34), (-88, 42, -106, 58)])
    a.save("star")


# ---------------------------------------------------------------- cowboy hat

def hat():
    a = Art(37)
    T = dict(rot=-5, skew=-6, sx=.97, sy=1.0, dx=0, dy=8)
    # the brim ends are cut square, like the end of a fat marker stroke
    brim = [(-111, -34), (-88, -17), (-54, 1), (-30, 9), (34, 7), (58, -3), (87, -20), (109, -41),
            (110, -8), (76, 24), (30, 41), (-18, 44), (-66, 32), (-106, 2)]
    crown = [(-49, 6), (-58, -34), (-52, -68), (-34, -84), (-4, -66), (30, -90), (52, -72), (60, -36), (52, 2), (22, 14), (-18, 15)]
    band = [(-49, 6), (-53, -13), (-18, -3), (24, -4), (56, -17), (52, 2), (22, 14), (-18, 15)]
    brim_t, crown_t, band_t = xf(brim, **T), xf(crown, **T), xf(band, **T)

    fld = burst(a.rnd, 0, -8, 104, 92, 10, inner=.78, lean=.7, jit=.06, rot=.1)
    arr = arrow(-52, -52, -104, -100, shaft=15, head=38, head_len=27)
    drips = [drip(50, 70, 9, 18), drip(70, 62, 7, 9), drip(-44, 72, 8, 12)]
    a.field([fld, arr] + drips, LIME, LIME_EDGE)

    a.block([brim_t], 5)
    a.block([crown_t], 7)
    # brim: top face, with the crown's hard shadow lying across it and the turned-up ends in shade
    a.fill(brim_t, ORANGE)
    a.clip_open([brim_t])
    a.fill(xf([(-44, 10), (60, 0), (86, -12), (96, 0), (62, 22), (14, 28), (-34, 25)], **T), RUST)
    a.fill(xf([(-110, 8), (-66, 37), (-18, 49), (30, 46), (78, 30), (116, -4), (106, -18), (74, 16), (30, 33), (-18, 36), (-62, 24), (-104, -8)], **T), YELLOW)
    a.clip_close()
    a.ink(brim_t, 5.2)
    # crown: lit left, a hard shadow down the right and in the crease
    a.fill(crown_t, ORANGE)
    a.clip_open([crown_t])
    a.fill(xf([(30, -90), (70, -90), (70, 20), (22, 14), (34, -20), (22, -52)], **T), RUST)
    a.fill(xf([(-34, -84), (-4, -66), (30, -90), (22, -52), (2, -34), (-12, -52)], **T), RUST)
    a.fill(xf([(-58, -34), (-52, -68), (-34, -84), (-30, -70), (-46, -56), (-49, -28)], **T), YELLOW)
    a.clip_close()
    # the pinch in the crown front
    a.line(xf([(-4, -66), (-12, -52), (-8, -30)], **T), 2, wander=1.2)
    a.line(xf([(-4, -66), (2, -34)], **T), 1.6)
    a.line(xf([(22, -52), (2, -34), (6, -18)], **T), 2, wander=1.2)
    # the band, with its star
    a.fill(band_t, PURPLE)
    a.clip_open([band_t])
    a.fill(xf([(20, -8), (60, -20), (56, 6), (22, 16)], **T), PURPLE_EDGE)
    a.clip_close()
    a.ink(band_t, 3.4, wander=1.2, over=.3)
    s5 = []
    for i in range(5):
        t = -math.pi / 2 + i * 2 * math.pi / 5 - .2
        s5 += [(-28 + 9.5 * math.cos(t), 2 + 9.5 * math.sin(t)), (-28 + 4 * math.cos(t + math.pi / 5), 2 + 4 * math.sin(t + math.pi / 5))]
    s5 = xf(s5, **T)
    a.fill(s5, LIME)
    a.stroke(s5, INK, 1.8)
    a.ink(crown_t, 5.2)

    a.spark(84, -74, 13, WHITE, rot=.25)
    a.dashes([(-100, 30, -116, 40), (-90, 46, -108, 62)])
    a.save("hat")


# ---------------------------------------------------------------- cactus

def cactus():
    a = Art(53)
    T = dict(rot=5, skew=-5, sx=.98, sy=.98, dx=-2, dy=-3)
    trunk = [(-23, 86), (-27, 22), (-25, -50), (-15, -80), (5, -90), (21, -76), (27, -40), (27, 30), (25, 86)]
    larm = [(-22, 28), (-55, 27), (-73, 10), (-75, -38), (-63, -54), (-50, -47), (-49, -8), (-43, -1), (-22, -1)]
    rarm = [(22, -4), (50, -6), (67, -22), (70, -62), (59, -77), (46, -69), (44, -36), (39, -30), (22, -29)]
    parts = [xf(p, **T) for p in (larm, rarm, trunk)]
    ground = xf([(-52, 90), (-32, 79), (-6, 83), (26, 77), (46, 82), (62, 93), (30, 99), (-28, 100)], rot=2, dy=-2)

    fld = burst(a.rnd, -2, -6, 94, 100, 10, inner=.78, lean=.7, jit=.07, rot=.35)
    drips = [drip(-60, 60, 8, 15), drip(72, 50, 8, 17)]
    a.field([fld] + drips, PURPLE, PURPLE_EDGE)

    a.block(parts, 7)
    a.fill(move(ground, 3, 4), INK)
    a.fill(ground, ORANGE)
    a.clip_open([ground])
    a.fill(move(ground, -3, -5), YELLOW)
    a.clip_close()
    a.ink(ground, 4, wander=1.2)
    a.body(parts, GREEN, GREEN_DARK, dx=9, dy=5)
    # one facet of light down the lit side of each limb
    a.clip_open(parts)
    for strip in ([(-21, 74), (-23, 20), (-21, -46), (-13, -72), (-9, -70), (-15, -44), (-16, 20), (-15, 74)],
                  [(-70, 6), (-71, -34), (-63, -46), (-61, -40), (-65, -32), (-64, 2)],
                  [(49, -30), (50, -62), (57, -70), (59, -65), (55, -60), (54, -32)]):
        a.fill(xf(strip, **T), LIME)
    a.clip_close()
    for p in parts[:2]:
        a.ink(p, 5.2)
    # the trunk goes over the arms: paint out the joins, then ink the trunk
    a.clip_open([parts[2]])
    a.fill(move(parts[2], 0, 0), GREEN_DARK)
    a.fill(move(parts[2], -9, -5), GREEN)
    a.fill(xf([(-21, 74), (-23, 20), (-21, -46), (-13, -72), (-9, -70), (-15, -44), (-16, 20), (-15, 74)], **T), LIME)
    a.clip_close()
    a.ink(parts[2], 5.2)
    # ribs
    a.line(xf([(-3, 80), (-5, 20), (-3, -44), (2, -74)], **T), 1.8, wander=1.2)
    a.line(xf([(11, 80), (12, 22), (13, -40), (9, -70)], **T), 1.6)
    a.line(xf([(-61, 14), (-62, -34)], **T), 1.6)
    a.line(xf([(57, -18), (58, -58)], **T), 1.6)
    # spines: ticks standing off the outline, and little crosses on the ribs
    spines = [(-26, 60, -36, 56), (-27, 44, -36, 46), (-26, -22, -36, -26), (-25, -44, -35, -50), (-18, -74, -26, -84), (4, -90, 3, -101),
              (22, -76, 31, -84), (27, -52, 37, -56), (27, 6, 37, 3), (27, 42, 37, 44), (26, 64, 36, 68),
              (-75, -10, -85, -12), (-75, -30, -85, -34), (-63, -54, -68, -64), (-50, -30, -42, -34),
              (70, -40, 80, -42), (69, -60, 78, -66), (59, -77, 60, -87), (45, -52, 37, -56)]
    for (x0, y0, x1, y1) in spines:
        p = xf([(x0, y0), (x1, y1)], **T)
        a.line(p, 2)
    for (x, y) in [(-4, 52), (-4, 10), (-3, -30), (12, 34), (13, -8), (11, -52), (-62, -12), (58, -40)]:
        cx, cy = xf([(x, y)], **T)[0]
        a.line([(cx - 3, cy - 2.4), (cx + 3, cy + 2.4)], 1.4)
        a.line([(cx - 2.6, cy + 2.8), (cx + 2.6, cy - 2.8)], 1.4)
    # the flower: a small pink burst on the crown, another on the high arm
    for (x, y, r, rr) in [(4, -90, 20, .1), (60, -78, 13, .6)]:
        cx, cy = xf([(x, y)], **T)[0]
        petals = []
        for i in range(5):
            t = rr + i * 2 * math.pi / 5
            petals += [(cx + r * math.cos(t), cy + r * math.sin(t) * .8), (cx + r * .55 * math.cos(t + math.pi / 5), cy + r * .55 * math.sin(t + math.pi / 5) * .8)]
        a.fill(move(petals, 2, 2.4), INK)
        a.stroke(move(petals, 2, 2.4), INK, 3)
        a.fill(petals, PINK)
        a.clip_open([petals])
        a.fill(move(petals, 5, 4), PINK_DARK)
        a.fill(move(petals, -1.5, -2.5), PINK)
        a.clip_close()
        a.stroke(petals, INK, 2.6, limit=3)
        a.fill(ngon(cx, cy, r * .28, 6), YELLOW)
        a.stroke(ngon(cx, cy, r * .28, 6), INK, 1.5)

    a.spark(-78, -80, 13, WHITE, rot=.25)
    a.dashes([(92, 12, 110, 8), (94, 26, 108, 30)])
    a.save("cactus")


if __name__ == "__main__":
    shoe()
    star()
    hat()
    cactus()
