"""Big Catch's four symbols in the manner of reference 3 (the back-room bar: gritty comic).

    python docs/art_redo/3_comic_catch/draw.py     # writes walleye.svg bobber.svg boot.svg worm.svg here
    python docs/art_redo/render.py 3_comic_catch    # SVG -> PNG

One lamp, upper left, orange. Every form is built the same way (Sym.form): a flat base, a soft
lamp glow and a soft dusk over it, a cool shadow on the side away from the lamp, a warm light
and a highlight on the side toward it, a spotted black shadow, a rim that runs hot orange to cold
blue round the edge, and an ink line that is heavier on the shadow side. Tone edges are shaken a
little by a noise filter so they look brushed.
"""
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
INK = "#0e0a0d"
WARM = ("#ffb054", .7)      # lamp light laid over a local colour
COOL = ("#170f33", .62)     # shadow laid over a local colour

DEFS = """
<filter id="wob" x="-20%" y="-20%" width="140%" height="140%"><feTurbulence type="fractalNoise" baseFrequency="0.05" numOctaves="2" seed="11" result="n"/><feDisplacementMap in="SourceGraphic" in2="n" scale="4.5" xChannelSelector="R" yChannelSelector="G"/></filter>
<filter id="rough" x="-10%" y="-10%" width="120%" height="120%"><feTurbulence type="fractalNoise" baseFrequency="0.11" numOctaves="2" seed="4" result="n"/><feDisplacementMap in="SourceGraphic" in2="n" scale="1.4" xChannelSelector="R" yChannelSelector="G"/></filter>
<filter id="grain" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency="1.3" numOctaves="2" seed="9" result="n"/><feColorMatrix in="n" type="matrix" values=".33 .33 .33 0 0 .33 .33 .33 0 0 .33 .33 .33 0 0 0 0 0 0 1" result="g"/><feBlend in="g" in2="SourceGraphic" mode="soft-light" result="b"/><feComposite in="b" in2="SourceGraphic" operator="in"/></filter>
<linearGradient id="rimg" gradientUnits="userSpaceOnUse" x1="-80" y1="-90" x2="80" y2="90"><stop offset="0" stop-color="#fff0c0"/><stop offset=".3" stop-color="#ff9a3c"/><stop offset=".52" stop-color="#8a4f5c"/><stop offset=".78" stop-color="#5563d0"/><stop offset="1" stop-color="#8ea2ff"/></linearGradient>
<radialGradient id="lamp" gradientUnits="userSpaceOnUse" cx="-75" cy="-85" r="200"><stop offset="0" stop-color="#ffd27e" stop-opacity=".62"/><stop offset=".5" stop-color="#ffb054" stop-opacity=".16"/><stop offset="1" stop-color="#ffb054" stop-opacity="0"/></radialGradient>
<linearGradient id="dusk" gradientUnits="userSpaceOnUse" x1="-50" y1="-60" x2="90" y2="105"><stop offset="0" stop-color="#120a2c" stop-opacity="0"/><stop offset="1" stop-color="#120a2c" stop-opacity=".66"/></linearGradient>
"""
BOX = '<rect x="-150" y="-150" width="300" height="300" %s/>'


def f(v):
    return ("%.1f" % v).rstrip("0").rstrip(".")


def poly(pts, close=True):
    return "M" + " L".join("%s %s" % (f(x), f(y)) for x, y in pts) + (" Z" if close else "")


def catmull(pts, per=16):
    out = []
    n = len(pts)
    for i in range(n - 1):
        p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, n - 1)]
        for s in range(per):
            t = s / per
            out.append(tuple(.5 * (2 * p1[k] + (p2[k] - p0[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t * t
                                   + (3 * p1[k] - p0[k] - 3 * p2[k] + p3[k]) * t ** 3) for k in (0, 1)))
    out.append(tuple(pts[-1]))
    return out


def ramp(stops):
    """Piecewise-linear width over t in 0..1 from [(t, w), ...]."""
    def w(t):
        for (t0, w0), (t1, w1) in zip(stops, stops[1:]):
            if t <= t1:
                return w0 + (w1 - w0) * (t - t0) / max(t1 - t0, 1e-6)
        return stops[-1][1]
    return w


class Tube:
    """A band of varying width along a smooth line through pts."""

    def __init__(self, pts, width, per=16, caps=(True, True)):
        c = catmull(pts, per)
        ln = [0.0]
        for a, b in zip(c, c[1:]):
            ln.append(ln[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
        self.c, self.ts = c, [v / ln[-1] for v in ln]
        self.t, self.n = [], []
        for i in range(len(c)):
            a, b = c[max(i - 1, 0)], c[min(i + 1, len(c) - 1)]
            d = math.hypot(b[0] - a[0], b[1] - a[1]) or 1
            self.t.append(((b[0] - a[0]) / d, (b[1] - a[1]) / d))
            self.n.append((-(b[1] - a[1]) / d, (b[0] - a[0]) / d))
        wf = width if callable(width) else (lambda t: width)
        self.w = [wf(t) for t in self.ts]
        self.left = [(p[0] + n[0] * w / 2, p[1] + n[1] * w / 2) for p, n, w in zip(c, self.n, self.w)]
        self.right = [(p[0] - n[0] * w / 2, p[1] - n[1] * w / 2) for p, n, w in zip(c, self.n, self.w)]
        self.caps = caps

    def cap(self, i, sign):
        p, n, t, r = self.c[i], self.n[i], self.t[i], self.w[i] / 2
        return [(p[0] + sign * (n[0] * math.cos(a) + t[0] * math.sin(a)) * r, p[1] + sign * (n[1] * math.cos(a) + t[1] * math.sin(a)) * r)
                for a in (k * math.pi / 8 for k in range(1, 8))]

    def d(self):
        pts = list(self.left)
        if self.caps[1]:
            pts += self.cap(-1, 1)
        pts += self.right[::-1]
        if self.caps[0]:
            pts += self.cap(0, -1)
        return poly(pts)

    def at(self, t):
        return min(range(len(self.ts)), key=lambda i: abs(self.ts[i] - t))

    def slice(self, t0, t1):
        a, b = self.at(t0), self.at(t1) + 1
        return poly(self.left[a:b] + self.right[a:b][::-1])

    def ring(self, t, bow):
        i = self.at(t)
        l, r, p, tg = self.left[i], self.right[i], self.c[i], self.t[i]
        return "M%s %s Q%s %s %s %s" % (f(l[0]), f(l[1]), f(p[0] + tg[0] * bow), f(p[1] + tg[1] * bow), f(r[0]), f(r[1]))


def P(d, fill, op=None, extra=""):
    return '<path d="%s" fill="%s"%s%s/>' % (d, fill, "" if op is None else ' fill-opacity="%s"' % op, " " + extra if extra else "")


def S(d, color, w, extra=""):
    return '<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"%s/>' % (d, color, f(w), " " + extra if extra else "")


def ink(pts, w, ends=(0, 0), color=INK):
    """An inked stroke through pts, fattest in the middle; ends = share of w left at each end."""
    def width(t):
        return w * (ends[0] + (1 - ends[0]) * min(1, t * 4)) * (ends[1] + (1 - ends[1]) * min(1, (1 - t) * 3)) ** .8
    return P(Tube(pts, width, per=10, caps=(False, False)).d(), color)


def feather(x, y, step, stroke, n, w=2.4, color=INK):
    """Brush feathering out of a black: n strokes from (x, y) on, fat where they start, pointed where they end."""
    out = []
    for i in range(n):
        k = .65 + .7 * ((i * 37 % 11) / 10)
        px, py = x + step[0] * i, y + step[1] * i
        out.append(ink([(px, py), (px + stroke[0] * k * .5, py + stroke[1] * k * .5), (px + stroke[0] * k, py + stroke[1] * k)], w, (1, 0), color))
    return "".join(out)


def cord(d, w=1.9, color="#efe4c4"):
    """Fishing line, lace: a pale thread with an ink edge so it shows on any ground."""
    return S(d, INK, w + 2.8) + S(d, color, w)


class Sym:
    def __init__(self, name, transform=""):
        self.name, self.transform = name, transform
        self.defs, self.out, self.k = [], [], 0

    def raw(self, *s):
        self.out.extend(s)

    def form(self, d, base, light=WARM, shade=COOL, deep=INK, ink_w=3.6, la=7.0, sa=8.0, da=3.2, rim=1.5, glow=True,
             local=(), under=(), over=()):
        """One inked, lit form. local: local colours; under: hand-placed shadows; over: details, shine."""
        self.k += 1
        i = "%s%d" % (self.name[:2], self.k)
        self.defs.append('<path id="%s" d="%s"/><clipPath id="%sc"><use href="#%s"/></clipPath>' % (i, d, i, i))

        def crescent(tag, tone, dx, dy):
            self.defs.append('<mask id="%s%s" maskUnits="userSpaceOnUse" x="-150" y="-150" width="300" height="300"><use href="#%s" fill="#fff"/>'
                             '<use href="#%s" fill="#000" transform="translate(%s %s)"/></mask>' % (i, tag, i, i, f(dx), f(dy)))
            color, op = tone if isinstance(tone, tuple) else (tone, 1)
            return BOX % ('fill="%s" fill-opacity="%s" mask="url(#%s%s)"' % (color, op, i, tag))

        def put(items):
            for it in items:
                o.append(it if isinstance(it, str) else P(*it))

        o = self.out
        o.append('<use href="#%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round" transform="translate(%s %s)"/>'
                 % (i, INK, INK, f(ink_w), f(ink_w * .5), f(ink_w * .62)))
        o.append('<use href="#%s" fill="%s"/>' % (i, base))
        o.append('<g clip-path="url(#%sc)"><g filter="url(#wob)">' % i)
        put(local)
        if glow:
            o.append(BOX % 'fill="url(#dusk)"')
            o.append(BOX % 'fill="url(#lamp)"')
        if shade:
            o.append(crescent("s", shade, -sa * .85, -sa))
        put(under)
        if light:
            o.append(crescent("l", light, la * .85, la))
            o.append(crescent("h", ("#ffe9bc", .6), la * .36, la * .42))
        if deep:
            o.append(crescent("d", deep, -da * .85, -da))
        o.append("</g>")
        put(over)
        if rim:
            o.append('<use href="#%s" fill="none" stroke="url(#rimg)" stroke-width="%s"/>' % (i, f(ink_w + rim * 2)))
        o.append("</g>")
        o.append('<use href="#%s" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="round" filter="url(#rough)"/>' % (i, INK, f(ink_w)))

    def save(self):
        body = "\n".join(self.out)
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="-120 -120 240 240">\n<defs>%s%s</defs>\n'
               '<g filter="url(#grain)"><g transform="%s">\n%s\n</g></g>\n</svg>\n' % (DEFS, "\n".join(self.defs), self.transform, body))
        with open(os.path.join(HERE, self.name + ".svg"), "w", encoding="utf-8") as fh:
            fh.write(svg)


def drop(s, x, y, r, tilt=0):
    """A falling water drop, point up."""
    d = "M0 %s C%s %s %s %s 0 %s C%s %s %s %s 0 %s Z" % (f(-r * 1.9), f(r * .5), f(-r * .7), f(r), f(r * .9), f(r), f(-r), f(r * .9), f(-r * .5), f(-r * .7), f(-r * 1.9))
    s.raw('<g transform="translate(%s %s) rotate(%s)">' % (f(x), f(y), f(tilt)))
    s.form(d, "#3f9cc0", light=("#d6f8ff", .9), shade=("#0c2a4a", .7), deep=None, ink_w=2, la=1.6, sa=2.2, rim=.6, glow=False,
           over=[P("M%s %s l%s %s l%s %s Z" % (f(-r * .45), f(-r * .1), f(r * .28), f(-r * .7), f(r * .1), f(r * .75)), "#ffffff")])
    s.raw("</g>")


# ---------------------------------------------------------------------------------------------
def walleye():
    s = Sym("walleye", "translate(1 4) rotate(-7) scale(.95)")
    fin = dict(light=("#ffc267", .85), shade=("#1a1030", .62), ink_w=2.9, la=4, sa=5, da=2, rim=1.1)
    # tail, torn at the fork
    s.form("M70 -16 C84 -30 98 -46 115 -57 C113 -40 107 -27 99 -13 L105 -9 L96 -4 C102 9 108 23 113 39 C97 35 82 25 72 12 Z", "#8a702a",
           under=[("M70 -18 L88 -12 L92 8 L70 14 Z", INK, .7), feather(88, -12, (.6, 5), (9, -1.5), 5, 2)],
           over=[ink([(76, -9), (92, -28), (108, -50)], 2, (.9, 0)), ink([(78, -4), (90, -14), (100, -24)], 1.6, (.9, 0)),
                 ink([(78, 4), (90, 12), (101, 22)], 1.6, (.9, 0)), ink([(76, 8), (92, 22), (108, 34)], 2, (.9, 0))], **fin)
    # second dorsal, anal and pelvic fins
    s.form("M30 -40 L37 -66 C48 -63 58 -50 66 -26 Z", "#96602a",
           over=[ink([(36, -42), (40, -52), (41, -62)], 1.6, (.8, 0)), ink([(46, -38), (50, -46), (52, -54)], 1.6, (.8, 0)),
                 ink([(56, -32), (58, -38), (59, -44)], 1.4, (.8, 0))], **fin)
    s.form("M26 40 L41 66 C51 59 59 44 62 22 Z", "#8a4c2c",
           over=[ink([(36, 40), (40, 50), (42, 60)], 1.6, (.8, 0)), ink([(48, 34), (51, 42), (52, 50)], 1.5, (.8, 0))], **fin)
    s.form("M-32 46 L-23 78 C-10 73 0 62 4 44 Z", "#8a4c2c",
           over=[ink([(-22, 50), (-20, 62), (-21, 72)], 1.6, (.8, 0)), ink([(-10, 50), (-9, 58), (-10, 66)], 1.5, (.8, 0))], **fin)
    # spiny dorsal: five spines leaning back, one web torn
    spines = [((-40, -44), (-37, -83)), ((-28, -48), (-22, -95)), ((-14, -50), (-6, -93)), ((2, -49), (10, -83)), ((14, -46), (22, -69))]
    s.form("M-48 -40 L-37 -84 L-31 -66 L-22 -96 L-15 -73 L-6 -94 L-1 -72 L3 -56 L6 -70 L10 -84 L15 -61 L22 -70 L27 -40 Z", "#a8682a",
           local=[("M8 -44 L12 -66 L20 -62 L24 -44 Z", "#2a1c1c"), ("M-48 -40 L27 -40 L26 -50 L-46 -52 Z", "#5a3420")],
           over=[ink([a, ((a[0] + b[0]) / 2 + 1, (a[1] + b[1]) / 2), b], 2.4, (1, 0)) for a, b in spines], **fin)
    # body: heavy head, the lower jaw pushed out past the snout
    body = "M-100 -3 C-93 -19 -82 -32 -60 -41 C-38 -52 -8 -54 22 -45 C44 -38 62 -27 76 -17 L79 11 C60 22 38 40 6 46 C-28 52 -60 51 -82 44 C-98 39 -113 30 -118 9 L-108 7 Z"
    scales = []
    for row in range(5):
        for col in range(9):
            x, y = -22 + col * 10.5 + (row % 2) * 5, -24 + row * 9
            if y < -30 + (x + 22) * .12 or y > 20 - max(0, x - 10) * .55:
                continue
            scales.append(S("M%s %s q4.5 3.6 0 7.4" % (f(x), f(y)), INK, 1, 'stroke-opacity=".5"'))
    teeth = [[(-115, 9.6), (-108.5, 10.6), (-110, -5)], [(-105, 11), (-99, 12), (-101, -1)], [(-95, 12.6), (-89.5, 13.8), (-91.5, 3.5)],
             [(-85.5, 15), (-80.5, 16.4), (-82, 8.5)], [(-76, 17.4), (-71.5, 18.8), (-73, 12.5)],
             [(-96, 1.4), (-91, 3.4), (-94, 9)], [(-79.5, 9), (-74.5, 11.6), (-78, 16)]]
    s.form(body, "#989238", la=10, sa=13, da=5, ink_w=3.8,
           local=[("M-118 9 C-94 26 -52 26 -12 20 C28 14 58 4 79 -6 L79 40 L0 62 L-104 56 Z", "#d6caa2"),      # belly
                  ("M-118 9 L-92 12 L-62 21 C-64 34 -78 43 -92 40 C-106 35 -115 24 -118 9 Z", "#eadbac"),       # jaw
                  ("M-80 -42 L-58 -48 L-57 -33 L-74 -26 Z", "#4b4a20"), ("M-36 -58 L-10 -58 L-14 -27 L-26 -12 L-37 -30 Z", "#4b4a20"),
                  ("M2 -56 L24 -52 L24 -22 L10 -7 L0 -28 Z", "#4b4a20"), ("M40 -44 L57 -36 L56 -12 L45 -1 L36 -20 Z", "#4b4a20"),
                  ("M66 -26 L80 -20 L80 -6 L68 -4 Z", "#4b4a20")],
           under=[("M-46 -36 C-30 -20 -27 6 -40 38 C-37 10 -39 -14 -53 -32 Z", INK),                              # behind the gill plate
                  feather(-33, -14, (-.4, 7), (12, 1), 6, 2.6),
                  ("M-78 48 C-40 53 0 50 30 41 C50 34 66 24 80 11 L80 30 L20 62 L-78 62 Z", "#120d1c", .92),
                  feather(-60, 49, (11, .2), (2, -9), 9, 2.8, "#120d1c"),
                  ("M54 -24 L80 -18 L80 12 L58 22 C63 6 61 -10 54 -24 Z", INK, .78),
                  feather(57, -14, (.6, 6), (-10, 1), 5, 2.4)],
           over=scales + [
               P("M-86 -29 C-76 -37 -63 -42 -50 -45 L-51 -40 C-63 -38 -74 -34 -84 -26 Z", "#fff3cc"),             # wet shine
               P("M-22 -51 L8 -49 L7 -46.4 L-20 -48 Z", "#ffe6ac"), P("M30 -42 L46 -36 L45 -34 L30 -39.6 Z", "#ffd590"),
               P("M-112 16 C-108 26 -100 33 -90 36 L-91 33 C-99 30 -105 24 -109 16 Z", "#fff6dc"),
               S("M-26 -4 C0 -8 30 -8 72 -3", INK, 1.2, 'stroke-dasharray="5 4" stroke-opacity=".7"'),
               ink([(-50, -37), (-37, -19), (-34, 6), (-42, 30), (-53, 45)], 3.4),                                  # gill cover
               ink([(-60, -30), (-52, -6), (-58, 22)], 1.8),
               P("M-100 -3 L-84 4 L-61 18 L-60 24 L-86 15 L-118 9 L-108 7 Z", INK),                                 # mouth
           ] + [P(poly(t), "#f8eed2", extra='stroke="%s" stroke-width=".9" stroke-linejoin="round"' % INK) for t in teeth] + [
               ink([(-118, 9.4), (-92, 12.6), (-62, 22)], 2.2, (.6, .2)),
               ink([(-64, 20), (-58, 27), (-60, 36)], 2.4, (.3, 0)),
               '<circle cx="-72" cy="-13" r="11.5" fill="#f6f0b6" stroke="%s" stroke-width="2.4"/>' % INK,          # the glass eye
               P("M-83 -13 A11 11 0 0 0 -61 -13 A11 7 0 0 1 -83 -13 Z", "#a4ae62"),
               '<ellipse cx="-76" cy="-11" rx="3.4" ry="4.8" fill="%s"/>' % INK,
               '<circle cx="-68.5" cy="-15.5" r="2.4" fill="#ffffff"/>',
               P("M-96 -14 L-71 -27 L-53 -34 L-49 -25 L-66 -18 L-92 -6 Z", INK),                                    # brow
               ink([(-86, -4), (-75, 2), (-62, -3)], 2),
               '<circle cx="-93" cy="-6.5" r="1.4" fill="%s"/>' % INK,
               S("M-60 2 L-45 19", "#f6b39a", 2.2), S("M-59 8 L-53 4 M-54 14 L-48 10 M-50 19 L-44 15", INK, 1.2),   # the scar
               S("M-18 -44 L-8 -32 M-12 -44 L-6 -37", "#f0cf8a", 1.3),
           ])
    # pectoral fin, over the flank
    s.form("M-37 13 C-22 15 -8 26 -1 43 C-14 46 -29 41 -41 30 Z", "#b06a2c",
           over=[ink([(-34, 18), (-22, 26), (-10, 38)], 1.7, (.8, 0)), ink([(-36, 23), (-28, 31), (-20, 39)], 1.5, (.8, 0))], **fin)
    # an old hook left in the lip, its line snapped
    hook = "M-102 24 C-110 33 -109 46 -100 48 C-94 49 -92 44 -94 40"
    s.raw(cord("M-101 32 C-112 46 -102 60 -113 74", 1.5), S(hook, INK, 5.4), S(hook, "#8a90a0", 2.6), S("M-107 33 C-108 39 -106 44 -101 46", "#fff3d0", 1))
    s.save()


def bobber():
    s = Sym("bobber", "translate(0 28)")
    tilt = 'transform="rotate(16 0 -14)"'
    # the water it sits in
    s.form("M-78 34 A78 18 0 1 0 78 34 A78 18 0 1 0 -78 34 Z", "#1f6a90", light=("#9aeaf2", .75), shade=("#081a3a", .7), la=3, sa=5, da=1.6, ink_w=3,
           over=[P("M8 37 C36 28 72 32 76 38 C58 50 22 49 8 37 Z", INK, .9), feather(22, 44, (9, .4), (2.5, 6), 5, 2.4),
                 S("M-64 30 C-50 24 -32 21 -14 20", "#ffb054", 2), S("M-52 41 C-42 45 -28 47 -16 48", "#bff2ff", 1.6)])
    # the peg and the line
    s.raw("<g %s>" % tilt)
    s.raw(cord("M0 -96 C1 -106 -1 -116 1 -127", 1.6), cord("M0 -99 C6 -103 9 -100 7 -95", 1.3))
    peg = dict(light=("#ffe6ae", .9), shade=("#2a1030", .7), ink_w=2.8, la=2.6, sa=3.4, da=1.4, rim=1)
    s.form("M-6.5 -92 L6.5 -92 L8 -62 L-8 -62 Z", "#d08a2a", **peg)
    s.form("M-10 -101 L10 -101 L11.5 -91 L-11.5 -91 Z", "#eaa23a", **peg)
    s.raw("</g>")
    # the float
    eq = "M-58 -14 C-30 1 30 1 58 -14"
    s.form("M-56 -14 A56 56 0 1 0 56 -14 A56 56 0 1 0 -56 -14 Z", "#f8efda", light=("#fff1cf", .55), la=10, sa=17, da=7, ink_w=3.8,
           local=['<g %s>' % tilt + P(eq + " L70 -90 L-70 -90 Z", "#cf261d") + "</g>"],
           under=['<g %s>' % tilt + P("M-58 -14 C-30 1 30 1 58 -14 L58 -8.6 C30 7 -30 7 -58 -8.6 Z", INK, .86) + "</g>",
                  '<g %s>' % tilt + P("M-57 -6 C-36 6 -8 7 10 5 C6 22 -6 34 -22 41 C-42 35 -56 16 -57 -6 Z", "#fffaea", .8) + "</g>",
                  P("M22 -66 C54 -48 64 -14 52 22 C42 40 26 46 10 44 C40 28 48 -20 22 -66 Z", INK, .55),
                  feather(34, -44, (2.6, 9), (-10, 3), 7, 2.6)],
           over=[P("M-34.6 30 A34.6 7 0 0 0 34.6 30 L60 60 L-60 60 Z", "#0d2f4c", .85),
                 P("M-40 -46 C-30 -59 -14 -66 2 -65 C-11 -59 -23 -50 -30 -36 Z", "#fff8e2"),
                 '<circle cx="-42" cy="-27" r="3.6" fill="#fff8e2"/>',
                 P("M-45 4 C-41 12 -35 18 -28 22 L-30 24.4 C-38 20 -44 13 -48 5 Z", "#ffffff", .9),
                 P("M14 -44 L24 -48 L27 -40 L20 -34 L15 -38 Z", "#e9dcc0", extra='stroke="%s" stroke-width="1.2"' % INK),   # chipped paint
                 S("M-8 -40 L4 -30 M-2 -44 L3 -39", "#ff9c7a", 1.3), S("M-20 8 L-8 16 M24 6 L34 0 M28 12 L33 9", INK, 1.2, 'stroke-opacity=".7"')])
    s.raw(S("M-37 31 A37 8 0 0 0 37 31", INK, 5), S("M-37 31 A37 8 0 0 0 37 31", "#c9f6ff", 2.2))
    # the ring spreading out
    for d in ("M-100 34 A100 25 0 0 0 -34 57", "M-14 59.6 A100 25 0 0 0 56 54.7", "M76 50 A100 25 0 0 0 100 36", "M-92 24 A100 25 0 0 1 -60 14", "M70 16 A100 25 0 0 1 94 25"):
        s.raw(S(d, INK, 5.8), S(d, "#58c4dc", 3), S(d, "#e2fcff", 1, 'stroke-dasharray="7 9"'))
    drop(s, -78, -6, 7, -24)
    drop(s, -96, 12, 4.6, -40)
    drop(s, 82, -2, 6, 26)
    s.save()


def boot():
    s = Sym("boot", "translate(0 -2) scale(.93)")
    # the puddle it stands in
    s.form("M-98 101 A92 9 0 1 0 86 101 A92 9 0 1 0 -98 101 Z", "#1f6a90", light=("#9aeaf2", .75), shade=("#081a3a", .7), la=2, sa=3, da=1.2, ink_w=2.6,
           over=[S("M-76 99 C-56 96 -36 95 -16 95", "#ffb054", 1.6)])
    s.raw('<g transform="rotate(-5)">')
    weed = dict(light=("#dcf060", .85), shade=("#0a2030", .65), ink_w=2.6, la=2.2, sa=2.8, da=1.2, rim=1)
    leather = dict(light=("#ffb25a", .8), shade=("#1b1030", .62))
    # weed over the back of the cuff
    w1 = Tube([(56, -72), (78, -93), (96, -75), (92, -43), (101, -13), (93, 18)], ramp([(0, 9), (.6, 8), (1, 3)]))
    s.form(w1.d(), "#4a882c", **weed)
    s.form("M93 -45 C107 -51 115 -41 111 -29 C103 -31 97 -37 93 -45 Z", "#4a882c", **weed)
    s.form("M99 -9 C86 -7 80 3 84 13 C92 9 97 1 99 -9 Z", "#4a882c", **weed)
    # the pull tab at the back
    s.raw(S("M80 -77 L93 -92 L99 -85 L88 -71", INK, 6.4), S("M80 -77 L93 -92 L99 -85 L88 -71", "#b06a2c", 2.8))
    # sole and heel
    s.form("M85 70 L-50 72 L-112 76 C-119 78 -119 89 -112 92 L-44 89 L34 89 L37 100 L87 100 Z", "#51433e",
           light=("#e8a868", .8), shade=("#0e0a1c", .7), la=3.4, sa=4.6, da=2.2, ink_w=3.6,
           over=[S("M85 79 L-46 80 L-114 84", "#d0a674", 1.3, 'stroke-opacity=".85"'),
                 S("M-96 91 l1 -6 M-80 90.4 l1 -6 M-64 89.8 l1 -6 M-20 89 l0 -6 M-4 89 l0 -6 M12 89 l0 -6 M28 89 l0 -6 M50 100 l0 -7 M62 100 l0 -7 M74 100 l0 -7", INK, 1.8),
                 P("M34 80 L87 80 L87 100 L37 100 Z", INK, .35)])
    s.raw(P("M-46 72 C-66 70 -84 66 -100 62 L-112 76 L-50 72.6 Z", INK),
          S("M-60 70.4 l-1 4 M-74 67.6 l-2 7 M-88 64.6 l-3 9.6 M-99 62 l-5 11", "#e3d2a6", 1.4))
    # the upper: slumped shaft, toe curling up off the sole
    upper = ("M12 -74 C2 -50 8 -30 -4 -8 C-12 6 -36 12 -58 16 C-84 20 -106 32 -108 50 C-108 56 -104 60 -100 62 C-84 66 -66 70 -46 72 L82 71 "
             "C88 52 80 30 84 8 C86 -4 78 -12 80 -24 C84 -44 82 -60 84 -78 C62 -90 34 -88 12 -74 Z")
    eyelets = [(21, -54), (18, -35), (10, -14), (-9, 2), (-31, 9)]
    edge = [(9, -58), (5, -38), (-2, -16), (-20, 6), (-42, 13)]         # where each lace turns over the front edge
    laces = []
    for i, (e, g) in enumerate(zip(eyelets, edge)):
        bar = "M%s %s L%s %s" % (f(e[0]), f(e[1]), f(g[0]), f(g[1]))
        laces.append(S(bar, INK, 5.6) + S(bar, "#e6d8b2", 2.6))
        if i:
            cross = "M%s %s L%s %s" % (f(e[0]), f(e[1]), f(edge[i - 1][0] + 2), f(edge[i - 1][1] + 5))
            laces.append(S(cross, INK, 5) + S(cross, "#cdbc92", 2.2))
    s.form(upper, "#935629", la=8, sa=11, da=4.6, ink_w=3.8, **leather,
           local=[("M-58 16 C-84 20 -106 32 -108 50 L-104 64 L-46 73 C-42 54 -46 30 -58 16 Z", "#6c3a22"),           # toe cap
                  ("M86 72 L42 72 C40 50 52 30 84 22 Z", "#6c3a22"),                                                # heel counter
                  ("M38 -42 L65 -46 L68 -19 L42 -14 Z", "#bd7b3a")],                                                # patch
           under=[("M-6 -9 C10 -2 28 -5 46 -15 C32 3 10 9 -10 2 Z", INK), feather(2, 1, (8, -1), (1.5, 9), 5, 2.4),
                  ("M2 -31 C16 -25 32 -27 48 -35 C34 -18 14 -15 2 -22 Z", "#1c1220", .92),
                  ("M-30 14 C-18 20 -6 20 6 14 C-4 26 -20 26 -30 14 Z", "#1c1220", .85),
                  ("M60 -86 C53 -40 56 20 64 72 L92 72 L92 -86 Z", "#130b22", .62), feather(58, -66, (.5, 13), (-11, 2), 10, 2.8, "#130b22"),
                  ("M-106 54 C-84 62 -62 66 -46 66 L-46 74 L-106 66 Z", INK, .8)],
           over=[P("M12 -74 C30 -60 66 -62 84 -78 C62 -90 34 -88 12 -74 Z", "#120b12"),                             # the opening
                 P("M26 -80 C42 -86 64 -86 78 -80 C62 -84 42 -84 26 -80 Z", "#4a2a24"),
                 S("M13 -73 C31 -60 66 -62 83 -77", "#e6ac6e", 1.8),
                 S("M-56 18 C-45 32 -42 52 -45 71", INK, 2.2), S("M-51 17 C-40 32 -37 52 -40 71", "#e8c98e", 1.1, 'stroke-dasharray="3.4 3"'),
                 S("M84 24 C56 32 44 50 45 71", INK, 2), S("M38 -42 L65 -46 L68 -19 L42 -14 Z", INK, 1.6),
                 S("M41 -38 L62 -41 M64 -40 L66 -22 M65 -19 L45 -16 M43 -17 L40 -37", "#f4dda8", 1.2, 'stroke-dasharray="3 2.6"'),
                 ink([(-2, -10), (16, -4), (42, -14)], 2.6), ink([(4, -31), (20, -26), (46, -34)], 2.2), ink([(-30, 13), (-12, 19), (6, 13)], 2),
                 ink([(12, -50), (26, -46), (42, -50)], 1.6), ink([(84, 8), (74, 2), (66, 4)], 2), ink([(80, -24), (72, -22), (66, -26)], 1.8),
                 P("M-97 36 C-89 26 -75 21 -62 20 L-63 25 C-75 26 -86 31 -94 41 Z", "#ffe9b8"),                    # wet shine
                 P("M8 -58 C4 -44 6 -30 0 -17 L4.6 -17 C10 -30 9 -44 12 -56 Z", "#ffd590"),
                 '<circle cx="-90" cy="46" r="2.6" fill="#ffe9b8"/>',
                 S("M-82 32 L-72 40 M-76 30 L-70 35 M-94 52 L-86 57 M14 34 L28 44 M20 32 L28 38 M60 44 L68 56", "#e2a262", 1.3),
                 S("M-72 48 l5 -6 l4 7 l5 -7 l4 6", INK, 1.5), S("M4 50 l7 -5 l3 7 l8 -6 l4 7", INK, 1.6)] + laces +
                ['<circle cx="%s" cy="%s" r="3.8" fill="#dca63c" stroke="%s" stroke-width="1.7"/><circle cx="%s" cy="%s" r="1.4" fill="%s"/>'
                 % (f(x), f(y), INK, f(x), f(y), INK) for x, y in eyelets])
    # the tongue, standing up inside the opening behind the front edge
    s.form("M17 -70 C11 -84 13 -100 26 -105 C40 -108 52 -100 54 -87 C55 -78 53 -70 50 -63 C40 -62 26 -64 17 -70 Z", "#7a4426", ink_w=3.2, la=4, sa=5, **leather,
           over=[ink([(30, -98), (33, -84), (32, -68)], 1.5), ink([(42, -98), (44, -84), (42, -66)], 1.5),
                 P("M18 -90 C19 -98 24 -102 31 -103 L31 -100 C26 -99 22 -96 21 -89 Z", "#ffdca0")])
    s.raw(S("M15 -71.6 C24 -65 38 -62.4 52 -63", INK, 3.4), S("M15 -72.6 C24 -66 38 -63.4 52 -64", "#e6ac6e", 1.4))
    # a lace hanging loose, weed across the toe
    s.raw(cord("M21 -54 C-8 -64 -32 -42 -26 -18 C-22 -4 -36 2 -43 -6", 2.8), S("M-43 -6 l-5 -5 M-43 -6 l-7 0", INK, 2))
    w2 = Tube([(-103, 36), (-88, 21), (-70, 22), (-56, 38), (-60, 58)], ramp([(0, 3), (.3, 7.5), (.8, 6), (1, 2.5)]))
    s.form(w2.d(), "#4a882c", **weed)
    s.form("M-72 22 C-68 8 -56 4 -48 10 C-52 18 -62 22 -72 22 Z", "#4a882c", **weed)
    s.raw("</g>")
    drop(s, -104, 86, 5, 8)
    drop(s, 96, 62, 5, 0)
    s.save()


def worm():
    s = Sym("worm", "translate(15 13)")
    steel = dict(light=("#ffe8b8", .95), shade=("#141632", .72), ink_w=3, la=2.6, sa=3.2, da=1.4, rim=1)
    ht = Tube([(40, -74), (40, -40), (40, 0), (40, 40), (31, 68), (2, 82), (-27, 68), (-37, 42), (-36, 20)], 10, caps=(True, False))
    k = len(ht.left) - 7
    hook = poly(ht.left[:k] + [(ht.left[k][0] + 13, ht.left[k][1] + 9)] + ht.left[k + 2:] + [(-34, -6)] + ht.right[::-1] + ht.cap(0, -1))
    # line, knot, the eye of the hook
    s.raw(cord("M40 -92 C42 -104 52 -108 56 -118", 1.7), cord("M40 -92 C32 -98 28 -104 32 -110", 1.4),
          '<circle cx="40" cy="-83" r="8" fill="none" stroke="%s" stroke-width="8.6"/><circle cx="40" cy="-83" r="8" fill="none" stroke="#8a90a0" stroke-width="4.2"/>' % INK,
          S("M33 -87 A8 8 0 0 1 42 -91", "#ffe8b8", 1.6), S("M38 -93 l5 3", INK, 3.2), S("M38 -93 l5 3", "#efe4c4", 1.4))
    s.form(hook, "#8a90a0", **steel)
    # the worm
    body = Tube([(-86, -56), (-62, -62), (-36, -62), (-6, -50), (24, -29), (54, -10), (70, 12), (60, 33), (37, 41), (14, 36), (3, 47), (2, 62)],
                ramp([(0, 42), (.07, 46), (.19, 33), (.25, 38), (.36, 38), (.41, 31), (.7, 28), (.9, 18), (1, 9)]), per=18)
    rings = [S(body.ring(t, 5), INK, 1.2, 'stroke-opacity=".6"') for t in
             [.125, .16, .195, .225, .385, .405, .44, .475, .51, .545, .58, .615, .65, .685, .72, .755, .79, .825, .86, .895, .93, .965]]
    s.form(body.d(), "#bd544e", light=("#ffbc78", .85), shade=("#220c36", .66), la=8, sa=11, da=4.2, ink_w=3.8,
           local=[(body.slice(.26, .35), "#e8987a")],
           under=[(body.slice(.51, .57), INK, .5), feather(-52, -41, (9, 1.2), (1, -8), 5, 2.4), feather(46, 22, (-7, 4), (-3, -9), 4, 2.4)],
           over=rings + [S(body.ring(.255, 4), INK, 2), S(body.ring(.355, 4), INK, 2),
                         P("M-66 -78 C-52 -82 -38 -80 -26 -74 L-28 -70 C-40 -75 -52 -77 -64 -74 Z", "#fff0d0"),       # wet shine
                         P("M-2 -58 C10 -52 20 -44 28 -36 L25 -34 C17 -42 8 -49 -4 -55 Z", "#ffdfb0"),
                         P("M52 -20 C60 -14 66 -6 69 2 L66 3 C63 -5 58 -12 50 -17 Z", "#ffdfb0"),
                         # the face: one brow across both eyes, gritted teeth, a toothpick
                         P("M-87 -58 C-83 -65 -72 -66 -65 -60 C-69 -53 -81 -51 -87 -58 Z", "#fff1cc", extra='stroke="%s" stroke-width="1.6"' % INK),
                         P("M-104 -54 C-102 -59 -96 -60 -92 -57 C-94 -51 -100 -50 -104 -54 Z", "#fff1cc", extra='stroke="%s" stroke-width="1.4"' % INK),
                         '<circle cx="-80" cy="-59" r="2.9" fill="%s"/><circle cx="-99.6" cy="-55" r="2.1" fill="%s"/>' % (INK, INK),
                         '<circle cx="-79" cy="-60.2" r=".9" fill="#ffffff"/>',
                         P("M-110 -57 L-88 -66 L-62 -77 L-58 -68 L-84 -58 L-109 -49 Z", INK),
                         ink([(-89, -51), (-78, -47.6), (-66, -53)], 1.8), ink([(-105, -48), (-99, -46.4), (-93, -48.6)], 1.4),
                         P("M-104 -43.4 L-84 -42 L-82.6 -35 L-102 -35.4 Z", "#f8eed2", extra='stroke="%s" stroke-width="1.5" stroke-linejoin="round"' % INK),
                         S("M-98 -43 L-97.6 -35.6 M-92 -42.6 L-91.6 -35.4 M-87 -42.2 L-86.6 -35.2", INK, 1.1),
                         ink([(-83, -40), (-78, -37), (-76, -31)], 2.2, (.4, 0)),
                         S("M-70 -80 L-76 -50", "#f6b39a", 2), S("M-77 -73 L-70 -72 M-78 -67 L-71 -66", INK, 1.1),
                         # a plaster
                         '<g transform="translate(57 7) rotate(28)">' + P("M-10 -3 L10 -3 L10 3 L-10 3 Z", "#ecdcb4", extra='stroke="%s" stroke-width="1.3"' % INK)
                         + P("M-3 -10 L3 -10 L3 10 L-3 10 Z", "#ecdcb4", extra='stroke="%s" stroke-width="1.3"' % INK) + "</g>"])
    s.raw(S("M-97 -39 L-117 -29", INK, 4.2), S("M-97 -39 L-117 -29", "#eed9a0", 1.8))
    # the shank passes in front of the lower coil
    s.defs.append('<clipPath id="shank"><rect x="28" y="22" width="26" height="36"/></clipPath>')
    s.raw('<g clip-path="url(#shank)">')
    s.form(hook, "#8a90a0", **steel)
    s.raw("</g>")
    s.save()


if __name__ == "__main__":
    walleye()
    bobber()
    boot()
    worm()
    print("wrote 4 svg")
