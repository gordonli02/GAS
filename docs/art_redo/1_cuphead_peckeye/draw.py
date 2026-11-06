"""Peckeye's four symbols in the manner of a 1930s rubber-hose cartoon (reference folder 1).

    python docs/art_redo/1_cuphead_peckeye/draw.py     # writes the four .svg beside this file
    python docs/art_redo/render.py 1_cuphead_peckeye   # then the .png

A heavy black line, a touch heavier on the side away from the light (upper left), flat muted
fills, one flat shadow tone, a few ink shine marks, a little wobble and paper grain.
"""
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
INK = "#1c1612"
LINE = .82       # scales every outline; raise it for a variant that is printed small
W = 5.6          # outline, before LINE
W_IN = 3.4       # lines inside a form

FEATHER, FEATHER_SH = "#f1e6cc", "#d8c9a6"
WHITE, WHITE_SH = "#fbf5e6", "#d7d2c4"
NAVY, NAVY_SH = "#34507d", "#253c61"
BRICK, BRICK_SH = "#c4472f", "#9c3321"
BEAK, BEAK_SH = "#e7a52f", "#c5801d"
COB, COB_SH = "#e2b64c", "#c08e33"
WOOD, WOOD_SH = "#80502e", "#5e3720"
STEEL, STEEL_SH = "#8499ab", "#61768b"
TIN, TIN_SH = "#a9b4b6", "#808d92"
LEAF, LEAF_SH = "#5c8a3f", "#44692f"
LEAF_LT = "#7ea651"
ROPE, ROPE_SH = "#dcbb7c", "#b99553"
SHINE = "#fdf8ea"


def n(v):
    return ("%.2f" % v).rstrip("0").rstrip(".")


def bez(p, t):
    if len(p) == 3:
        a, b, c = (1 - t) ** 2, 2 * (1 - t) * t, t * t
        return (a * p[0][0] + b * p[1][0] + c * p[2][0], a * p[0][1] + b * p[1][1] + c * p[2][1])
    a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t * t, t ** 3
    return (a * p[0][0] + b * p[1][0] + c * p[2][0] + d * p[3][0], a * p[0][1] + b * p[1][1] + c * p[2][1] + d * p[3][1])


class Draw:
    def __init__(self, seed=3):
        self.defs = []
        self.out = []
        self.ids = 0
        self.seed = seed

    def raw(self, s):
        self.out.append(s)

    def open(self, transform):
        self.out.append('<g transform="%s">' % transform)

    def close(self):
        self.out.append("</g>")

    def clip(self, d, rule=False):
        self.ids += 1
        cid = "c%d" % self.ids
        self.defs.append('<clipPath id="%s"><path d="%s"%s/></clipPath>' % (cid, d, ' clip-rule="evenodd"' if rule else ""))
        return cid

    def shape(self, d, fill, shadow=None, shift=(-5, -6), w=W, heavy=1.7, evenodd=False, extra=None):
        """A filled outline. `shadow`: the form's shadow tone, left as a crescent on the side away
        from the light. `extra`: [(path, fill)] painted inside the form, under its outline."""
        rule = ' fill-rule="evenodd"' if evenodd else ""
        w *= LINE
        if heavy and w:
            self.out.append('<path d="%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round" transform="translate(%s %s)"%s/>'
                            % (d, INK, INK, n(w), n(heavy * .7), n(heavy), rule))
        self.out.append('<path d="%s" fill="%s"%s/>' % (d, shadow or fill, rule))
        if shadow or extra:
            cid = self.clip(d, evenodd)
            self.out.append('<g clip-path="url(#%s)">' % cid)
            if shadow:
                self.out.append('<path d="%s" fill="%s" transform="translate(%s %s)"%s/>' % (d, fill, n(shift[0]), n(shift[1]), rule))
            for ed, ef in extra or []:
                self.out.append('<path d="%s" fill="%s"/>' % (ed, ef))
            self.out.append("</g>")
        if w:
            self.out.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"/>' % (d, INK, n(w)))

    def inside(self, clip_d, items, evenodd=False):
        """Paint raw svg strings clipped to a form (for lines that must stop at its edge)."""
        cid = self.clip(clip_d, evenodd)
        self.out.append('<g clip-path="url(#%s)">%s</g>' % (cid, "".join(items)))

    def line(self, d, w=W_IN, color=INK, cap="round"):
        self.out.append(self.line_s(d, w, color, cap))

    @staticmethod
    def line_s(d, w=W_IN, color=INK, cap="round"):
        return '<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="%s"/>' % (d, color, n(w), cap)

    def tube(self, d, fill, width, w=W):
        """A rubber hose: a round-ended stroke with an outline."""
        w *= LINE
        self.out.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round" transform="translate(1.2 1.7)"/>' % (d, INK, n(width + w)))
        self.out.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"/>' % (d, INK, n(width + w)))
        self.out.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"/>' % (d, fill, n(width - w)))

    def taper_s(self, pts, w=W_IN, mode="both", color=INK, steps=22):
        """An ink stroke that swells and thins: along a quadratic (3 points) or cubic (4)."""
        p = [bez(pts, i / steps) for i in range(steps + 1)]
        left, right = [], []
        for i, (x, y) in enumerate(p):
            t = i / steps
            a, b = p[max(i - 1, 0)], p[min(i + 1, steps)]
            dx, dy = b[0] - a[0], b[1] - a[1]
            ln = math.hypot(dx, dy) or 1
            k = {"both": math.sin(math.pi * t) ** .7, "end": (1 - t) ** .7, "start": t ** .7}[mode]
            h = w / 2 * max(k, .1)
            left.append((x - dy / ln * h, y + dx / ln * h))
            right.append((x + dy / ln * h, y - dx / ln * h))
        d = "M" + " L".join("%s,%s" % (n(x), n(y)) for x, y in left + right[::-1]) + "Z"
        return '<path d="%s" fill="%s" stroke="%s" stroke-width=".5" stroke-linejoin="round"/>' % (d, color, color)

    def taper(self, pts, w=W_IN, mode="both", color=INK):
        self.out.append(self.taper_s(pts, w, mode, color))

    def blob(self, circles, fill, shadow=None, w=W):
        """Overlapping circles outlined as one form (smoke)."""
        w *= LINE
        for dx, dy in ((1.2, 1.7), (0, 0)):
            for x, y, r in circles:
                self.out.append('<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % (n(x + dx), n(y + dy), n(r + w / 2), INK))
        for x, y, r in circles:
            self.out.append('<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % (n(x), n(y), n(r - w / 2), shadow or fill))
        if shadow:
            for x, y, r in circles:
                self.out.append('<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % (n(x - 2.2), n(y - 2.6), n(r - w / 2 - 1.6), fill))

    def svg(self):
        s = self.seed
        return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="-120 -120 240 240">\n<defs>\n'
                '<filter id="ink" filterUnits="userSpaceOnUse" x="-120" y="-120" width="240" height="240">'
                '<feTurbulence type="fractalNoise" baseFrequency=".028" numOctaves="2" seed="%d" result="n"/>'
                '<feDisplacementMap in="SourceGraphic" in2="n" scale="2.6" xChannelSelector="R" yChannelSelector="G" result="d"/>'
                # paper grain and a faint wash mottle, only where there is paint
                '<feTurbulence type="fractalNoise" baseFrequency=".75" numOctaves="2" seed="%d" result="g"/>'
                '<feColorMatrix in="g" type="matrix" values="0 0 0 0 .1  0 0 0 0 .07  0 0 0 0 .04  .42 0 0 0 -.16" result="g2"/>'
                '<feTurbulence type="fractalNoise" baseFrequency=".035" numOctaves="3" seed="%d" result="m"/>'
                '<feColorMatrix in="m" type="matrix" values="0 0 0 0 .12  0 0 0 0 .08  0 0 0 0 .05  .34 0 0 0 -.12" result="m2"/>'
                '<feMerge result="gm"><feMergeNode in="g2"/><feMergeNode in="m2"/></feMerge>'
                '<feComposite in="gm" in2="d" operator="in" result="gg"/>'
                '<feMerge><feMergeNode in="d"/><feMergeNode in="gg"/></feMerge>'
                '</filter>\n%s\n</defs>\n<g filter="url(#ink)">\n%s\n</g>\n</svg>\n'
                % (s, s + 11, s + 23, "\n".join(self.defs), "\n".join(self.out)))


# ---------------------------------------------------------------- anchor

def anchor():
    g = Draw(seed=4)
    g.open("rotate(-11) scale(.97)")
    # rope tail behind everything, hanging from the ring
    ring = "M0,-102 a21,21 0 1,0 .01,0 Z M0,-90 a9,9 0 1,1 -.01,0 Z"
    g.shape(ring, STEEL, STEEL_SH, shift=(-3, -4), evenodd=True)
    body = ("M-10,-64 L10,-64 L13,60 C38,66 54,57 60,38 L45,34 L74,-10 L96,43 L78,41 "
            "C69,79 38,101 0,103 C-38,101 -69,79 -78,41 L-96,43 L-74,-10 L-45,34 L-60,38 C-54,57 -38,66 -13,60 Z")
    g.shape(body, STEEL, STEEL_SH, shift=(-5, -7))
    # the stock, bowed a little, with ball ends
    g.shape("M-46,-56 C-20,-50 20,-50 46,-56 L46,-40 C20,-34 -20,-34 -46,-40 Z", STEEL, STEEL_SH, shift=(-2, -5))
    for x in (-50, 50):
        g.shape("M%s,-48 m-11,0 a11,11 0 1,0 22,0 a11,11 0 1,0 -22,0 Z" % x, STEEL, STEEL_SH, shift=(-3, -4))
    # shine marks
    g.taper([(-17, -86), (-15, -98), (-4, -100)], 3.6, color=SHINE)
    g.taper([(-4, -40), (-5, 0), (-6, 44)], 4.2, color=SHINE)
    g.taper([(-70, 50), (-58, 78), (-30, 90)], 4.6, color=SHINE)
    g.taper([(-74, 2), (-80, 14), (-84, 30)], 3.4, color=SHINE)
    g.taper([(66, 6), (60, 16), (58, 26)], 3, color=SHINE)
    g.taper([(-38, -50), (-20, -47), (-6, -47)], 3, color=SHINE)
    # crown notch
    g.taper([(-13, 62), (0, 70), (13, 62)], 3.2)
    # the rope: two turns round the ring, one over the shank, a frayed end
    rope = "M17,-66 C40,-60 44,-34 24,-20 C8,-9 -22,-18 -32,-4 C-34,0 -34,3 -34,6"
    g.shape("M-41,4 L-45,19 L-38,15 L-34,21 L-30,15 L-23,18 L-28,3 Z", ROPE, ROPE_SH, shift=(-2, -2), w=4.4)
    g.tube(rope, ROPE, 13.5)
    segs = [[(17, -66), (40, -60), (44, -34), (24, -20)], [(24, -20), (8, -9), (-22, -18), (-32, -4)]]
    ticks = []
    for seg, count in zip(segs, (6, 7)):
        for i in range(count):
            t = (i + .5) / count
            x, y = bez(seg, t)
            x2, y2 = bez(seg, min(t + .02, 1))
            a = math.atan2(y2 - y, x2 - x) + math.radians(58)
            ticks.append(g.line_s("M%s,%s L%s,%s" % (n(x - math.cos(a) * 3.4), n(y - math.sin(a) * 3.4), n(x + math.cos(a) * 3.4), n(y + math.sin(a) * 3.4)), 1.7))
    g.raw("".join(ticks))
    g.line("M-40,2 L-28,0", 2.4)
    for deg in (52, 24):
        c, sn = math.cos(math.radians(deg)), math.sin(math.radians(deg))
        g.tube("M%s,%s L%s,%s" % (n(c * 7), n(-81 + sn * 7), n(c * 23), n(-81 + sn * 23)), ROPE, 11.5, w=4.6)
    g.close()
    return g.svg()


# ---------------------------------------------------------------- pipe

def pipe():
    g = Draw(seed=8)
    # smoke first (behind the bowl's rim)
    g.blob([(40, -32, 9), (51, -27, 8)], WHITE, WHITE_SH)
    g.blob([(8, -60, 13), (25, -66, 13), (20, -50, 10)], WHITE, WHITE_SH)
    g.blob([(34, -92, 12), (52, -88, 13), (44, -78, 10)], WHITE, WHITE_SH)
    g.taper([(12, -56), (18, -62), (24, -57)], 2.6)
    g.taper([(40, -86), (46, -91), (52, -85)], 2.6)
    # stem: wide at the bowl, thin at the bit
    stem = "M24,46 C-16,52 -58,44 -97,24 C-103,22 -106,30 -101,34 C-62,56 -20,70 24,70 Z"
    g.shape(stem, WOOD, WOOD_SH, shift=(-1, -5),
            extra=[("M-120,0 L-66,0 L-74,80 L-120,80 Z", "#2e2622")])
    g.inside(stem, [g.line_s("M-66,30 L-72,56", 3)])
    g.taper([(-52, 43), (-28, 50), (-4, 52)], 2.6, color="#b98a5e")
    # the bit's lip
    g.raw('<g transform="rotate(-27 -101 28)">')
    g.shape("M-106,28 a5,10 0 1,0 10,0 a5,10 0 1,0 -10,0 Z", "#2e2622", w=4.4)
    g.raw("</g>")
    g.open("rotate(7 46 40)")
    ly = [-2 + i * 78 / 7 for i in range(8)]
    lx = [(16 - 6.5 * math.sin(math.pi * i / 7.6) + (6 * (i / 7) ** 3), y) for i, y in enumerate(ly)]
    body = "M16,-2"
    for (x0, y0), (x1, y1) in zip(lx, lx[1:]):
        body += " Q%s,%s %s,%s" % (n((x0 + x1) / 2 - 3.6), n((y0 + y1) / 2), n(x1), n(y1))
    body += " C34,90 58,90 70,76"
    rx = [(92 - x, y) for x, y in lx][::-1]
    for (x0, y0), (x1, y1) in zip(rx, rx[1:]):
        body += " Q%s,%s %s,%s" % (n((x0 + x1) / 2 + 3.6), n((y0 + y1) / 2), n(x1), n(y1))
    body += " Z"
    kern = []
    for row in range(8):
        y = 9 + row * 11.2
        for i in range(-1, 9):
            x = 6 + i * 10.4 + (5.2 if row % 2 else 0)
            dy = 7 * (1 - ((x - 46) / 40) ** 2)
            squeeze = max(.55, 1 - abs(x - 46) / 75)
            kern.append('<ellipse cx="%s" cy="%s" rx="%s" ry="4.5" fill="%s"/>' % (n(46 + (x - 46) * .98), n(y + dy), n(4.6 * squeeze), COB))
            kern.append('<ellipse cx="%s" cy="%s" rx="%s" ry="1.3" fill="#f3d47c"/>' % (n(46 + (x - 46) * .98 - 1), n(y + dy - 1.8), n(2 * squeeze)))
    g.shape(body, COB_SH, w=0, heavy=0)
    g.raw('<path d="%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round" transform="translate(1.2 1.7)"/>' % (body, INK, INK, n(W * LINE)))
    g.raw('<path d="%s" fill="#b98a2c"/>' % body)
    g.inside(body, kern + ['<path d="M62,-10 C74,20 72,60 56,96 L100,96 L100,-10 Z" fill="#7a4a10" fill-opacity=".28"/>'])
    g.line(body, W * LINE)
    g.taper([(20, 12), (15, 34), (20, 58)], 4.4, color=SHINE)
    # the mouth of the bowl
    g.shape("M14,-2 a32,11 0 1,0 64,0 a32,11 0 1,0 -64,0 Z", COB, COB_SH, shift=(-2, -3))
    g.shape("M24,-2 a22,6.5 0 1,0 44,0 a22,6.5 0 1,0 -44,0 Z", "#3b2a20", w=3.2, heavy=0,
            extra=[("M30,-1 a16,4 0 1,0 32,0 a16,4 0 1,0 -32,0 Z", BRICK), ("M38,-1.4 a8,2.2 0 1,0 16,0 a8,2.2 0 1,0 -16,0 Z", BEAK)])
    # the band where the stem goes in
    g.close()
    g.shape("M17,45 C13,52 13,64 17,72 L27,72 C24,64 24,52 27,45 Z", TIN, TIN_SH, shift=(-2, -4), w=4.6)
    return g.svg()


# ---------------------------------------------------------------- spinach

def spinach():
    g = Draw(seed=12)
    g.open("rotate(-5)")
    # the lid, bent back on its last tab of tin
    g.shape("M34,-12 L46,-30 L56,-26 L46,-8 Z", TIN, TIN_SH, shift=(-2, -2), w=4.6)
    g.open("translate(60 -50) rotate(-24)")
    pts = []
    for i in range(40):
        a = math.pi * 2 * i / 40
        k = 1 if i % 2 else .93
        pts.append("%s,%s" % (n(math.cos(a) * 37 * k), n(math.sin(a) * 29 * k)))
    g.shape("M" + " L".join(pts) + "Z", TIN, TIN_SH, shift=(-4, -4))
    g.line("M-25,0 a25,19 0 1,0 50,0 a25,19 0 1,0 -50,0 Z", 2.4)
    g.line("M-12,0 a12,9 0 1,0 24,0 a12,9 0 1,0 -24,0 Z", 2)
    g.taper([(-24, -10), (-12, -20), (6, -22)], 3.4, color=SHINE)
    g.close()
    # the can
    body = "M-50,-6 L-50,82 A50,15 0 0 0 50,82 L50,-6 A50,15 0 0 0 -50,-6 Z"
    label = "M-60,12 A50,15 0 0 0 60,12 L60,62 A50,15 0 0 1 -60,62 Z"
    g.shape(body, TIN, TIN_SH, shift=(-9, 0), extra=[(label, BRICK), ("M26,-30 L70,-30 L70,110 L32,110 Z", "#00000030")])
    g.inside(body, [
        g.line_s("M-50,10 A50,15 0 0 0 50,10", 3), g.line_s("M-50,64 A50,15 0 0 0 50,64", 3),
        g.line_s("M-50,0 A50,15 0 0 0 50,0", 2.2), g.line_s("M-50,74 A50,15 0 0 0 50,74", 2.2),
    ])
    g.line(body, W * LINE)
    # label badge with a leaf
    g.shape("M-25,44 a25,21 0 1,0 50,0 a25,21 0 1,0 -50,0 Z", FEATHER, FEATHER_SH, shift=(-2, -3), w=3.6, heavy=1)
    g.shape("M-12,56 C-18,44 -10,30 6,28 C16,28 16,40 10,50 C4,58 -6,60 -12,56 Z", LEAF, LEAF_SH, shift=(-2, -2), w=3, heavy=0)
    g.taper([(-13, 59), (-2, 46), (8, 33)], 2.2)
    g.taper([(-32, 22), (-36, 40), (-34, 58)], 4, color=SHINE)
    # the open top
    g.shape("M-50,-6 a50,15 0 1,0 100,0 a50,15 0 1,0 -100,0 Z", "#39452f", w=W)
    # leaves standing in the can
    back = "M-10,-2 C-34,-18 -52,-52 -38,-76 C-30,-88 -12,-84 -6,-70 C2,-50 2,-22 0,-2 Z"
    mid = "M-4,-2 C-22,-30 -18,-74 6,-96 C18,-104 32,-94 34,-78 C38,-50 26,-20 12,-2 Z"
    g.shape(back, LEAF_SH, "#375727", shift=(-4, -4))
    g.taper([(-6, -8), (-18, -40), (-28, -70)], 2.8)
    g.taper([(-17, -38), (-26, -42), (-34, -50)], 2.2, mode="end")
    g.taper([(-12, -24), (-4, -34), (-2, -44)], 2.2, mode="end")
    g.shape(mid, LEAF, LEAF_SH, shift=(-5, -4))
    g.taper([(4, -6), (8, -50), (16, -90)], 3)
    g.taper([(7, -40), (-2, -52), (-6, -64)], 2.3, mode="end")
    g.taper([(8, -28), (18, -40), (24, -54)], 2.3, mode="end")
    g.taper([(11, -62), (20, -70), (26, -80)], 2.3, mode="end")
    g.taper([(10, -62), (4, -72), (2, -80)], 2.1, mode="end")
    # the near rim, over the stems
    g.line("M-50,-6 A50,15 0 0 0 50,-6", W * LINE)
    # leaves flopping over the rim
    left = "M-12,-4 C-26,-30 -60,-46 -78,-30 C-92,-16 -84,10 -66,12 C-48,14 -26,6 -12,-4 Z"
    right = "M10,-4 C22,-26 50,-34 66,-22 C80,-10 76,12 60,16 C42,20 22,8 10,-4 Z"
    g.shape(left, LEAF_LT, LEAF, shift=(-4, -5))
    g.taper([(-16, -6), (-44, -22), (-72, -12)], 3)
    g.taper([(-38, -20), (-44, -30), (-54, -34)], 2.2, mode="end")
    g.taper([(-48, -19), (-50, -8), (-58, 0)], 2.2, mode="end")
    g.taper([(-30, -14), (-30, -6), (-36, 2)], 2.1, mode="end")
    g.shape(right, LEAF_LT, LEAF, shift=(-4, -5))
    g.taper([(14, -5), (40, -16), (64, -4)], 3)
    g.taper([(34, -14), (40, -22), (50, -24)], 2.2, mode="end")
    g.taper([(42, -13), (44, -2), (52, 6)], 2.2, mode="end")
    g.close()
    return g.svg()


# ---------------------------------------------------------------- sailor

def sailor():
    g = Draw(seed=17)
    # torso
    torso = "M-40,104 C-44,76 -38,50 -20,40 L30,40 C52,48 62,74 60,104 C36,110 -18,110 -40,104 Z"
    g.shape(torso, NAVY, NAVY_SH, shift=(-7, -3))
    g.taper([(46, 64), (52, 84), (50, 104)], 3.2)
    # sailor collar and neckerchief
    left = "M-30,42 L3,42 L3,76 C-12,72 -26,62 -34,50 Z"
    right = "M36,42 L3,42 L3,76 C18,72 32,62 40,50 Z"
    g.shape(left, WHITE, WHITE_SH, shift=(-3, -3), w=4.6)
    g.shape(right, WHITE, WHITE_SH, shift=(-3, -3), w=4.6)
    g.inside(left, [g.line_s("M-27,52 C-19,62 -9,68 3,70", 2.6, NAVY)])
    g.inside(right, [g.line_s("M33,52 C25,62 15,68 3,70", 2.6, NAVY)])
    g.shape("M3,74 C-6,80 -10,94 -6,105 L2,105 C2,96 4,86 6,80 Z", BRICK, BRICK_SH, shift=(-2, -2), w=4.2)
    g.shape("M3,74 C10,82 16,94 14,105 L6,105 C6,96 4,86 2,80 Z", BRICK, BRICK_SH, shift=(-2, -2), w=4.2)
    g.shape("M-4,70 C-4,64 10,64 10,70 C10,80 -4,80 -4,70 Z", BRICK, BRICK_SH, shift=(-2, -2), w=4.2)
    # the arm: a thin hose that swells into the great forearm, a gloved fist
    arm = "M-36,57 L-62,79 C-62,56 -66,10 -76,-31 L-92,-31 C-99,-8 -106,22 -104,48 C-102,70 -98,88 -85,96 C-77,100 -69,97 -61,91 L-32,67 Z"
    g.shape(arm, FEATHER, FEATHER_SH, shift=(-6, -4))
    g.shape("M-22,42 C-36,42 -46,50 -46,62 C-42,70 -32,70 -28,64 Z", NAVY, NAVY_SH, shift=(-3, -3), w=4.8)
    t = NAVY
    g.raw('<g transform="translate(-84 38) rotate(-4)">'
          + g.line_s("M0,-12 L0,14", 3.2, t) + g.line_s("M-7,-5 L7,-5", 3, t)
          + g.line_s("M-11,6 C-9,16 -3,17 0,15 C3,17 9,16 11,6", 3, t)
          + '<circle cx="0" cy="-16" r="3.4" fill="none" stroke="%s" stroke-width="2.6"/>' % t
          + g.line_s("M-13,9 L-11,4 L-7,8", 2.4, t) + g.line_s("M13,9 L11,4 L7,8", 2.4, t) + "</g>")
    g.taper([(-96, 2), (-100, 26), (-98, 52)], 3.6, color=SHINE)
    # fist: two knuckles on top, the thumb folded across, a rolled cuff
    g.open("translate(1 0)")
    fist = "M-101,-52 C-105,-64 -104,-78 -96,-84 C-91,-88 -86,-86 -84,-83 C-79,-88 -70,-85 -68,-78 C-65,-70 -66,-60 -69,-52 C-74,-46 -95,-46 -101,-52 Z"
    g.shape(fist, WHITE, WHITE_SH, shift=(-4, -4))
    g.taper([(-84, -83), (-83, -77), (-85, -72)], 2.8, mode="end")
    g.taper([(-99, -73), (-98, -68), (-96, -64)], 2.2)
    g.taper([(-94, -77), (-93, -72), (-91, -68)], 2.2)
    thumb = "M-58,-66 C-70,-70 -84,-69 -90,-63 C-94,-58 -91,-52 -85,-51 C-76,-49 -66,-50 -58,-53 Z"
    g.inside(fist, ['<path d="%s" fill="%s"/>' % (thumb, WHITE), g.line_s(thumb, 3.6)])
    g.line(fist, W * LINE)
    g.shape("M-102,-40 C-102,-49 -70,-49 -70,-40 C-70,-31 -102,-31 -102,-40 Z", WHITE, WHITE_SH, shift=(-3, -3))
    g.close()
    # head: cheek feathers on the far side, a ruff at the neck
    head = ("M-48,-22 C-50,-52 -26,-68 4,-66 C32,-64 50,-44 49,-16 C49,6 41,22 29,30 C27,41 16,45 10,36 "
            "C6,47 -8,47 -12,37 C-18,45 -30,42 -32,32 C-36,30 -45,28 -51,20 C-47,16 -45,12 -45,8 C-51,8 -57,2 -57,-7 C-51,-9 -48,-15 -48,-22 Z")
    g.shape(head, FEATHER, FEATHER_SH, shift=(-6, -6))
    # cap, pushed back
    g.open("translate(5 -6) rotate(-10 -9 -56)")
    g.shape("M-41,-68 C-45,-104 27,-104 23,-68 C9,-62 -27,-62 -41,-68 Z", WHITE, WHITE_SH, shift=(-6, -4))
    g.shape("M-45,-50 C-29,-41 13,-41 29,-50 L34,-73 C17,-65 -33,-65 -50,-73 Z", WHITE, WHITE_SH, shift=(-5, -4))
    g.taper([(-43, -61), (-9, -49), (27, -61)], 2.4)
    g.taper([(-31, -85), (-27, -95), (-14, -98)], 3, color=SHINE)
    g.close()
    # comb, standing up in front of the cap
    g.shape("M14,-50 C8,-60 12,-78 22,-78 C29,-78 31,-70 30,-64 C32,-78 34,-91 44,-90 C53,-89 54,-76 50,-64 C54,-74 64,-78 69,-70 C74,-60 66,-46 54,-43 C40,-40 24,-42 14,-50 Z", BRICK, BRICK_SH, shift=(-3, -3))
    # wattles
    g.shape("M27,11 C20,23 24,37 33,35 C40,33 39,20 34,11 Z", BRICK, BRICK_SH, shift=(-2, -3), w=4.6)
    g.shape("M36,11 C34,21 39,32 45,29 C50,24 47,14 42,9 Z", BRICK, BRICK_SH, shift=(-2, -3), w=4.6)
    bowl = "M76,-1 C73,14 75,27 82,31 C88,35 97,33 100,27 C103,16 102,8 100,-1 Z"
    kern = []
    for row in range(6):
        for i in range(6):
            x = 73.5 + i * 6.2 + (3.1 if row % 2 else 0)
            kern.append('<ellipse cx="%s" cy="%s" rx="2.6" ry="2.5" fill="%s"/>' % (n(x), n(5 + row * 5.4 + 2.5 * (1 - ((x - 88) / 14) ** 2)), COB))
    g.blob([(91, -21, 6.5), (99, -18, 5)], WHITE, WHITE_SH, w=4.4)
    g.blob([(82, -42, 8), (92, -47, 8.5), (95, -38, 6)], WHITE, WHITE_SH, w=4.4)
    # beak
    g.shape("M35,5 C47,3 57,2 65,1 C61,14 47,18 36,14 Z", BEAK, BEAK_SH, shift=(-2, -3), w=4.8)
    g.tube("M46,6 C58,10 66,23 78,26", WOOD, 11, w=5)
    g.shape(bowl, "#b98a2c", w=5)
    g.inside(bowl, kern + ['<path d="M93,-6 C98,8 97,22 92,36 L106,36 L106,-6 Z" fill="#7a4a10" fill-opacity=".28"/>'])
    g.line(bowl, 5 * LINE)
    g.shape("M75,-1 a13,4.6 0 1,0 26,0 a13,4.6 0 1,0 -26,0 Z", "#3b2a20", w=4.2, heavy=0, extra=[("M81,-1 a7,2 0 1,0 14,0 a7,2 0 1,0 -14,0 Z", BRICK)])
    g.shape("M32,-14 C44,-27 63,-21 74,-5 C62,-1 48,2 34,5 Z", BEAK, BEAK_SH, shift=(-3, -4), w=4.8)
    g.taper([(55, -12), (58, -10), (60, -8)], 2.2)
    # the open eye: a pie-cut pupil, looking down the beak
    g.shape("M1,-18 a12.5,18.5 0 1,0 25,0 a12.5,18.5 0 1,0 -25,0 Z", "#fffdf5", w=3.2, heavy=1)
    g.raw('<ellipse cx="17" cy="-13.5" rx="8.2" ry="13" fill="%s"/>' % INK)
    g.raw('<path d="M17,-13.5 L6,-27 L17,-30 Z" fill="#fffdf5"/>')
    g.taper([(1, -40), (14, -48), (27, -40)], 4.4)
    # the squint: a shut lid hanging from a heavy brow
    lid = "M-30,-24 L-2,-19 C-3,-6 -27,-7 -30,-24 Z"
    g.shape(lid, FEATHER_SH, w=0, heavy=0)
    g.taper([(-29, -21), (-20, -5), (-3, -17)], 4.6)
    g.taper([(-37, -29), (-20, -27), (-1, -19)], 6.4, mode="start")
    g.taper([(-33, -13), (-37, -13), (-40, -17)], 2.2, mode="end")
    g.taper([(-31, -8), (-35, -7), (-39, -9)], 2.2, mode="end")
    # cheek line
    g.taper([(33, 7), (21, 17), (9, 9)], 3)
    g.taper([(8, 4), (5, 8), (7, 13)], 2.4)
    return g.svg()


if __name__ == "__main__":
    for name, fn in (("anchor", anchor), ("pipe", pipe), ("spinach", spinach), ("sailor", sailor)):
        with open(os.path.join(HERE, name + ".svg"), "w", encoding="utf-8") as f:
            f.write(fn())
        print("wrote", name)
