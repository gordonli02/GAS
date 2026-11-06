"""Hot Plate's four symbols in the manner of reference 5 (bold glossy web cartoon).

    python docs/art_redo/5_adcap_plate/draw.py      # writes egg.svg stack.svg mug.svg pie.svg here
    python docs/art_redo/render.py 5_adcap_plate    # SVG -> PNG

One manner for the set: a heavy dark-brown outer contour (the "ol" filter grows it around the whole
drawing), thinner lines inside, candy fills in two cel tones, white gloss, light from the upper left.
"""
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = "#2b1206"
W_IN = 3.2      # inside line
STEAM_LINE = "#7d93b3"


def f(v):
    return ("%.2f" % v).rstrip("0").rstrip(".")


def pt(p):
    return "%s %s" % (f(p[0]), f(p[1]))


def smooth(pts, closed=True, k=1 / 6.0):
    """A Catmull-Rom curve through pts, as cubic Beziers."""
    n = len(pts)
    d = "M" + pt(pts[0])
    for i in (range(n) if closed else range(n - 1)):
        p0 = pts[(i - 1) % n] if (closed or i > 0) else pts[i]
        p1, p2 = pts[i], pts[(i + 1) % n]
        p3 = pts[(i + 2) % n] if (closed or i + 2 < n) else p2
        c1 = (p1[0] + (p2[0] - p0[0]) * k, p1[1] + (p2[1] - p0[1]) * k)
        c2 = (p2[0] - (p3[0] - p1[0]) * k, p2[1] - (p3[1] - p1[1]) * k)
        d += " C%s %s %s" % (pt(c1), pt(c2), pt(p2))
    return d + (" Z" if closed else "")


def ribbon(center, widths):
    """A closed tapering ribbon around a centre line (steam, streaks)."""
    left, right = [], []
    n = len(center)
    for i, (x, y) in enumerate(center):
        ax, ay = center[max(i - 1, 0)]
        bx, by = center[min(i + 1, n - 1)]
        dx, dy = bx - ax, by - ay
        ln = math.hypot(dx, dy) or 1
        nx, ny = -dy / ln, dx / ln
        w = widths[i]
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    return smooth(left + right[::-1], True)


def st(w=W_IN, color=OUT):
    return 'stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"' % (color, f(w))


def sparkle(x, y, r, rot=0):
    q = r * .16
    d = "M0 %s Q%s %s %s 0 Q%s %s 0 %s Q%s %s %s 0 Q%s %s 0 %s Z" % (
        f(-r), f(q), f(-q), f(r), f(q), f(q), f(r), f(-q), f(q), f(-r), f(-q), f(-q), f(-r))
    return '<path d="%s" transform="translate(%s %s) rotate(%s)" fill="#ffffff" %s/>' % (d, f(x), f(y), f(rot), st(2.2))


def steam(center, widths):
    d = ribbon(center, widths)
    return ('<path d="%s" fill="#ffffff" %s/>' % (d, st(3, STEAM_LINE)))


DEFS = """
<filter id="ol" filterUnits="userSpaceOnUse" x="-150" y="-150" width="300" height="300" color-interpolation-filters="sRGB">
  <feGaussianBlur in="SourceAlpha" stdDeviation="2.7" result="b"/>
  <feComponentTransfer in="b" result="t"><feFuncA type="linear" slope="26" intercept="-3.5"/></feComponentTransfer>
  <feFlood flood-color="%s"/><feComposite in2="t" operator="in" result="o"/>
  <feMerge><feMergeNode in="o"/><feMergeNode in="SourceGraphic"/></feMerge>
</filter>""" % OUT


def page(name, defs, art, over="", under="", dy=0):
    """under: below the outlined drawing (ground shadow); art: gets the heavy contour; over: steam, sparkles.
    dy moves the whole picture so it sits centred in the square."""
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="-120 -120 240 240">\n<defs>%s\n%s</defs>\n<g transform="translate(0 %s)">\n%s\n'
           '<g filter="url(#ol)">\n%s\n</g>\n%s\n</g>\n</svg>\n' % (DEFS, defs, f(dy), under, art, over))
    with open(os.path.join(HERE, name + ".svg"), "w", encoding="utf-8") as fh:
        fh.write(svg)


def ell(cx, cy, rx, ry, fill, stroke="", extra=""):
    return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s" %s %s/>' % (f(cx), f(cy), f(rx), f(ry), fill, stroke, extra)


def path(d, fill, stroke="", extra=""):
    return '<path d="%s" fill="%s" %s %s/>' % (d, fill, stroke, extra)


# ----------------------------------------------------------------------------------------- egg

def egg():
    a, defs, over = [], [], []
    cx, cy = -12, 28
    RX, RY = 88, 60
    defs.append('<linearGradient id="wall" x1="0" x2="1" y1="0" y2="0"><stop offset="0" stop-color="#262b47"/>'
                '<stop offset=".55" stop-color="#3d4670"/><stop offset="1" stop-color="#6673a6"/></linearGradient>')
    defs.append('<linearGradient id="outer" x1="0" x2="1" y1="0" y2="1"><stop offset="0" stop-color="#4a5380"/>'
                '<stop offset="1" stop-color="#252a45"/></linearGradient>')
    defs.append('<radialGradient id="yolk" cx=".38" cy=".32" r=".8"><stop offset="0" stop-color="#ffe04a"/>'
                '<stop offset=".6" stop-color="#ffb81f"/><stop offset="1" stop-color="#ff9412"/></radialGradient>')
    defs.append('<linearGradient id="hand" x1="0" x2="1" y1="0" y2="1"><stop offset="0" stop-color="#5d6896"/>'
                '<stop offset="1" stop-color="#333a5e"/></linearGradient>')
    # handle, behind the pan
    hd = "M48 -14 L96 -68"
    a.append('<path d="%s" fill="none" %s/>' % (hd, st(31)))
    a.append('<path d="%s" fill="none" %s/>' % (hd, st(24.5, "#3a4268")))
    a.append('<path d="M46 -19 L92 -71" fill="none" %s/>' % st(9, "#6b78aa"))
    a.append('<path d="M52 -29 L84 -65" fill="none" %s opacity=".85"/>' % st(2.6, "#c9d4f5"))
    a.append('<ellipse cx="95" cy="-67" rx="6.5" ry="4" transform="rotate(-48 95 -67)" fill="%s"/>' % OUT)
    # the pan: outer wall, rim, inside
    a.append(ell(cx, cy + 15, RX - 5, RY - 2, "url(#outer)", st()))
    a.append(path("M%s %s A%s %s 0 0 0 %s %s" % (f(cx - 70), f(cy + 53), f(RX - 12), f(RY - 8), f(cx + 20), f(cy + 67)), "none",
                  st(3, "#7d8abd"), 'opacity=".7"'))
    a.append(ell(cx, cy, RX, RY, "#8793c4", st()))
    a.append(path("M%s %s A%s %s 0 0 1 %s %s" % (f(cx - 80), f(cy - 14), f(RX - 5), f(RY - 4.5), f(cx - 8), f(cy - 55.2)), "none",
                  st(3.2, "#e6ecff"), 'opacity=".95"'))
    a.append(path("M%s %s A%s %s 0 0 1 %s %s" % (f(cx + 12), f(cy - 54.6), f(RX - 5), f(RY - 4.5), f(cx + 26), f(cy - 52.6)), "none",
                  st(3.2, "#e6ecff"), 'opacity=".95"'))
    defs.append('<clipPath id="in"><ellipse cx="%s" cy="%s" rx="%s" ry="%s"/></clipPath>' % (f(cx), f(cy + 1.5), f(RX - 10), f(RY - 8.5)))
    a.append(ell(cx, cy + 1.5, RX - 10, RY - 8.5, "url(#wall)", st(3)))
    a.append('<g clip-path="url(#in)">')
    a.append(ell(cx, cy + 11, RX - 20, RY - 17, "#454e7c", st(2.2, "#262b47")))
    a.append(ell(cx + 30, cy + 30, 40, 16, "#566192", "", 'opacity=".55" transform="rotate(-18 %s %s)"' % (f(cx + 30), f(cy + 30))))
    a.append("</g>")
    # the white
    ex, ey = cx - 1, cy + 9
    blob = [(-63, -4), (-52, -27), (-30, -31), (-12, -40), (14, -35), (30, -39), (50, -30), (57, -10), (67, 6), (60, 24),
            (38, 31), (20, 30), (2, 39), (-22, 33), (-40, 37), (-58, 24)]
    bd = smooth([(ex + x, ey + y) for x, y in blob])
    defs.append('<clipPath id="white"><path d="%s"/></clipPath>' % bd)
    a.append(path(bd, "#d9cdb6"))
    a.append('<g clip-path="url(#white)">')
    a.append(path(bd, "#fffdf3", "", 'transform="translate(-4 -5)"'))
    a.append(path(bd, "none", st(7, "#f4b24a"), 'opacity=".9"'))
    a.append(path(bd, "none", st(3, "#e58a1f"), 'opacity=".9"'))
    # the yolk's cast shadow on the white
    a.append(ell(ex - 2, ey + 3, 28, 22, "#e9dfc8"))
    a.append("</g>")
    a.append(path(bd, "none", st()))
    # little blisters in the white
    for bx, by, br in ((38, 12, 4.2), (46, 2, 2.4), (-44, 16, 3)):
        a.append('<circle cx="%s" cy="%s" r="%s" fill="#fffdf3" %s/>' % (f(ex + bx), f(ey + by), f(br), st(1.8, "#b89a6a")))
    # the yolk
    yx, yy = ex - 7, ey - 4
    defs.append('<clipPath id="yc"><ellipse cx="%s" cy="%s" rx="26" ry="21"/></clipPath>' % (f(yx), f(yy)))
    a.append(ell(yx, yy, 26, 21, "url(#yolk)"))
    a.append('<g clip-path="url(#yc)">')
    a.append(path("M%s %s a26 21 0 0 0 52 0 a31 27 0 0 1 -52 0 Z" % (f(yx - 26), f(yy + 1)), "#f27a0c", "", 'transform="rotate(-28 %s %s)"' % (f(yx), f(yy))))
    a.append("</g>")
    a.append(ell(yx, yy, 26, 21, "none", st()))
    a.append(ell(yx - 9, yy - 9, 9, 4.6, "#ffffff", "", 'transform="rotate(-32 %s %s)"' % (f(yx - 9), f(yy - 9))))
    a.append('<circle cx="%s" cy="%s" r="2.2" fill="#ffffff"/>' % (f(yx + 4), f(yy - 14)))
    art = '<g transform="rotate(-7)">\n%s\n</g>' % "\n".join(a)
    over.append(steam([(-58, -42), (-70, -58), (-52, -72), (-64, -90), (-54, -104)], [4.5, 7.5, 7, 4.6, 1.2]))
    over.append(steam([(-18, -52), (-8, -68), (-24, -84), (-10, -100), (-18, -112)], [5, 8, 7, 4.6, 1.2]))
    over.append(sparkle(34, -52, 11, 8))
    over.append(sparkle(18, -72, 5, 0))
    under = '<ellipse cx="-6" cy="98" rx="84" ry="10" fill="#2b1206" opacity=".16"/>'
    page("egg", "\n".join(defs), art, "\n".join(over), under, dy=3)


# --------------------------------------------------------------------------------------- stack

def plate(cx, cy, rx, ry, thick=5, stripe=True):
    o = []
    o.append(ell(cx, cy + thick, rx - 3, ry - 1, "#b9cbe3", st()))
    o.append(ell(cx, cy, rx, ry, "#ffffff", st()))
    if stripe:
        o.append(ell(cx, cy, rx - 6.5, ry - 3.6, "none", st(3.2, "#2f8fe6")))
    o.append(ell(cx, cy + 1.5, rx * .68, ry * .62, "#dbe8f7", st(2.2, "#9db4d2")))
    o.append(path("M%s %s A%s %s 0 0 1 %s %s" % (f(cx - (rx - 14) * .93), f(cy - (ry - 8) * .37), f(rx - 14), f(ry - 8), f(cx - (rx - 14) * .5), f(cy - (ry - 8) * .866)),
                  "none", st(2.4, "#c4d6ee")))
    return o


def stack():
    a, defs, over = [], [], []
    defs.append('<linearGradient id="side" x1="0" x2="1" y1="0" y2="0"><stop offset="0" stop-color="#ffe7a3"/>'
                '<stop offset=".5" stop-color="#ffd27a"/><stop offset="1" stop-color="#f2ae4e"/></linearGradient>')
    defs.append('<radialGradient id="top" cx=".4" cy=".35" r=".8"><stop offset="0" stop-color="#f7ae3d"/>'
                '<stop offset="1" stop-color="#e2861f"/></radialGradient>')
    defs.append('<linearGradient id="syr" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#c05a10"/>'
                '<stop offset="1" stop-color="#8f3a08"/></linearGradient>')
    a += plate(0, 84, 103, 23)
    # a little syrup on the plate
    a.append(path(smooth([(48, 92), (62, 88), (80, 91), (86, 96), (70, 100), (52, 98)]), "url(#syr)", st(2.6)))
    a.append('<path d="M56 92 Q64 90 72 92" fill="none" %s/>' % st(2, "#ffb657"))
    T = 17
    cakes = [(4, 50, 76, 22.5, 2), (-8, 27, 73, 22, -3), (7, 4, 72, 21.5, 2.5), (-6, -19, 70, 21, -2), (2, -42, 68, 20.5, 0)]
    for i, (cx, cy, rx, ry, rot) in enumerate(cakes):
        g = []
        body = ("M%s %s A%s %s 0 0 1 %s %s Q%s %s %s %s A%s %s 0 0 1 %s %s Q%s %s %s %s Z" % (
            f(cx - rx), f(cy), f(rx), f(ry), f(cx + rx), f(cy),
            f(cx + rx + 4), f(cy + T * .55), f(cx + rx - 3), f(cy + T), f(rx - 3), f(ry), f(cx - rx + 3), f(cy + T),
            f(cx - rx - 4), f(cy + T * .55), f(cx - rx), f(cy)))
        cid = "pc%d" % i
        defs.append('<clipPath id="%s"><path d="%s"/></clipPath>' % (cid, body))
        g.append(path(body, "url(#side)"))
        g.append('<g clip-path="url(#%s)">' % cid)
        # cel shade on the right and along the bottom of the side
        g.append(ell(cx + rx * .72, cy + T * .7, rx * .42, ry + T * .6, "#e99a3a", "", 'opacity=".85"'))
        g.append(ell(cx, cy + T + 5, rx, ry, "none", st(5, "#e08a2c"), 'opacity=".8"'))
        # shine on the left of the side
        g.append(path("M%s %s q-3 %s 4 %s" % (f(cx - rx + 7), f(cy + 9), f(T * .4), f(T * .75)), "none", st(3.4, "#fff6d6")))
        g.append("</g>")
        g.append(path(body, "none", st()))
        g.append(ell(cx, cy, rx, ry, "#ffd98a", st()))
        g.append(ell(cx + 1, cy + .6, rx - 7, ry - 3.4, "url(#top)"))
        g.append(path("M%s %s A%s %s 0 0 1 %s %s" % (f(cx - rx + 14), f(cy - 4), f(rx - 12), f(ry - 6), f(cx - 14), f(cy - ry + 6.4)),
                      "none", st(2.6, "#ffcf70"), 'opacity=".9"'))
        if i > 0:
            # the shadow this cake drops on the one under it
            px, py, prx, pry, _ = cakes[i - 1]
            defs.append('<clipPath id="sh%d"><ellipse cx="%s" cy="%s" rx="%s" ry="%s"/></clipPath>' % (i, f(px), f(py), f(prx - 1.6), f(pry - 1.6)))
            a.append('<g clip-path="url(#sh%d)" transform="rotate(%s %s %s)">' % (i, f(cakes[i - 1][4]), f(px), f(py)))
            a.append(ell(cx + 2, cy + T + 4, rx + 1, ry, "#b85f12", "", 'opacity=".42"'))
            a.append("</g>")
        a.append('<g transform="rotate(%s %s %s)">\n%s\n</g>' % (f(rot), f(cx), f(cy), "\n".join(g)))
    # syrup: a pool on the top cake running over the front edge in drips
    tx, ty, trx, tryy, _ = cakes[-1]

    def edge(x):
        return ty + tryy * math.sqrt(max(0.0, 1 - ((x - tx) / trx) ** 2))

    drips = [(47, 6.2, 34), (21, 5.4, 15), (-7, 7.6, 72), (-36, 5.8, 46)]
    d = "M%s %s A54 15.5 0 0 1 %s %s" % (f(tx - 54), f(ty + 1), f(tx + 54), f(ty + 1))
    prev = None
    for xd, w, ln in drips:
        xr, xl = xd + w, xd - w
        yr, yl = edge(xr) + 10, edge(xl) + 10
        yb = edge(xd) + ln
        if prev is None:
            d += " C%s %s %s %s %s %s" % (f(tx + 58), f(ty + 12), f(xr), f(yr - 12), f(xr), f(yr))
        else:
            top = min(edge(prev[0]), edge(xr)) + 2
            d += " C%s %s %s %s %s %s" % (f(prev[0]), f(top), f(xr), f(top), f(xr), f(yr))
        d += " L%s %s" % (f(xr), f(yb))
        d += " C%s %s %s %s %s %s" % (f(xr + 2.2), f(yb + w * 1.9), f(xl - 2.2), f(yb + w * 1.9), f(xl), f(yb))
        d += " L%s %s" % (f(xl), f(yl))
        prev = (xl, yl)
    d += " C%s %s %s %s %s %s Z" % (f(prev[0]), f(prev[1] - 12), f(tx - 58), f(ty + 12), f(tx - 54), f(ty + 1))
    defs.append('<clipPath id="sy"><path d="%s"/></clipPath>' % d)
    a.append(path(d, "url(#syr)"))
    a.append('<g clip-path="url(#sy)">')
    a.append(ell(tx + 30, ty + 6, 34, 11, "#7a2e06", "", 'opacity=".75"'))
    a.append(ell(tx - 14, ty - 3, 34, 8, "#d8731a", "", 'opacity=".9"'))
    for xd, w, ln in drips:
        yb = edge(xd) + ln
        a.append('<path d="M%s %s L%s %s" fill="none" %s/>' % (f(xd - w + 2.6), f(edge(xd) + 9), f(xd - w + 2.6), f(yb - 1), st(2.4, "#f08a24")))
        a.append('<path d="M%s %s L%s %s" fill="none" %s opacity=".8"/>' % (f(xd + w - 1.6), f(edge(xd) + 9), f(xd + w - 1.6), f(yb + 2), st(2.6, "#7a2e06")))
    a.append("</g>")
    a.append(path(d, "none", st()))
    for xd, w, ln in drips:
        yb = edge(xd) + ln
        a.append('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="#ffffff"/>' % (f(xd - w * .3), f(yb + w * .25), f(w * .32), f(w * .46)))
    a.append('<path d="M%s %s Q%s %s %s %s" fill="none" %s/>' % (f(tx - 42), f(ty - 3), f(tx - 30), f(ty - 11), f(tx - 4), f(ty - 12.5), st(2.8, "#ffd08a")))
    # a bead that let go of the short drip
    bx, by = 21, edge(21) + 37
    a.append(path("M%s %s C%s %s %s %s %s %s C%s %s %s %s %s %s Z" % (
        f(bx), f(by - 8), f(bx + 6.5), f(by + 1), f(bx + 5), f(by + 8), f(bx), f(by + 8),
        f(bx - 5), f(by + 8), f(bx - 6.5), f(by + 1), f(bx), f(by - 8)), "url(#syr)", st(2.8)))
    a.append('<circle cx="%s" cy="%s" r="1.7" fill="#ffffff"/>' % (f(bx - 1.8), f(by + 2)))
    # butter, half melted
    bx, by = tx - 4, ty - 10
    a.append(path(smooth([(bx - 31, by + 6), (bx - 16, by - 2), (bx + 12, by - 4), (bx + 33, by + 3), (bx + 24, by + 11), (bx - 2, by + 14), (bx - 24, by + 12)]),
                  "#ffe36a", st(2.4, "#c98a12")))
    A_, B_, C_, D_ = (bx - 23, by - 9), (bx + 2, by - 17), (bx + 25, by - 8), (bx - 1, by + 1)
    hgt = 10
    a.append(path("M%s L%s L%s L%s Z" % (pt(A_), pt(D_), pt((D_[0], D_[1] + hgt)), pt((A_[0], A_[1] + hgt))), "#ffd23a", st()))
    a.append(path("M%s L%s L%s L%s Z" % (pt(D_), pt(C_), pt((C_[0], C_[1] + hgt)), pt((D_[0], D_[1] + hgt))), "#f2a91c", st()))
    a.append(path("M%s L%s L%s L%s Z" % (pt(A_), pt(B_), pt(C_), pt(D_)), "#fff39a", st()))
    a.append('<path d="M%s %s L%s %s" fill="none" %s/>' % (f(bx - 12), f(by - 9.5), f(bx + 2), f(by - 13.5), st(2.6, "#ffffff")))
    art = '<g transform="rotate(-3)">\n%s\n</g>' % "\n".join(a)
    over.append(sparkle(62, -70, 12, 10))
    over.append(sparkle(80, -50, 5.5, 0))
    over.append(sparkle(-74, -62, 7, -10))
    under = '<ellipse cx="0" cy="106" rx="92" ry="8" fill="#2b1206" opacity=".16"/>'
    page("stack", "\n".join(defs), art, "\n".join(over), under, dy=-16)


# ----------------------------------------------------------------------------------------- mug

def mug():
    a, defs, over = [], [], []
    mx, my = -10, -34
    defs.append('<linearGradient id="body" x1="0" x2="1" y1="0" y2="0"><stop offset="0" stop-color="#ffffff"/>'
                '<stop offset=".55" stop-color="#fff6e6"/><stop offset="1" stop-color="#f0dfc6"/></linearGradient>')
    defs.append('<radialGradient id="cof" cx=".38" cy=".3" r=".9"><stop offset="0" stop-color="#8a4a1c"/>'
                '<stop offset="1" stop-color="#4a210b"/></radialGradient>')
    # saucer
    a += plate(-2, 72, 98, 23, 5)
    a.append(ell(mx + 6, 73, 58, 13, "#a9bfdc", "", 'opacity=".8"'))
    # handle, behind the body
    hd = "M40 -18 C78 -29 98 -7 93 15 C88 37 64 43 38 35"
    a.append('<path d="%s" fill="none" %s/>' % (hd, st(24)))
    a.append('<path d="%s" fill="none" %s/>' % (hd, st(17.4, "#e3d0b4")))
    a.append('<path d="%s" fill="none" %s transform="translate(-1.6 -2.2)"/>' % (hd, st(11.5, "#fffaf0")))
    a.append('<path d="M60 -21.5 C74 -21.5 85 -14 87 -1" fill="none" %s/>' % st(2.8, "#ffffff"))
    # body
    body = ("M%s %s C%s %s %s %s %s %s A47 15 0 0 0 %s %s C%s %s %s %s %s %s A60 19 0 0 0 %s %s Z" % (
        f(mx - 60), f(my), f(mx - 60), f(my + 40), f(mx - 52), f(my + 80), f(mx - 47), f(my + 94),
        f(mx + 47), f(my + 94), f(mx + 52), f(my + 80), f(mx + 60), f(my + 40), f(mx + 60), f(my),
        f(mx - 60), f(my)))
    defs.append('<clipPath id="mb"><path d="%s"/></clipPath>' % body)
    a.append(path(body, "url(#body)"))
    a.append('<g clip-path="url(#mb)">')
    # diner stripes
    a.append('<path d="M%s %s A62 19 0 0 0 %s %s" fill="none" stroke="#2f8fe6" stroke-width="9.5"/>' % (f(mx - 62), f(my + 20), f(mx + 62), f(my + 20)))
    a.append('<path d="M%s %s A62 19 0 0 0 %s %s" fill="none" stroke="#2f8fe6" stroke-width="3.2"/>' % (f(mx - 62), f(my + 31.5), f(mx + 62), f(my + 31.5)))
    a.append(path("M%s %s C%s %s %s %s %s %s L%s %s L%s %s Z" % (
        f(mx + 30), f(my), f(mx + 34), f(my + 40), f(mx + 28), f(my + 90), f(mx + 18), f(my + 120),
        f(mx + 80), f(my + 120), f(mx + 80), f(my)), "#a9783c", "", 'opacity=".22"'))
    a.append(path("M%s %s C%s %s %s %s %s %s L%s %s L%s %s Z" % (
        f(mx + 48), f(my), f(mx + 50), f(my + 40), f(mx + 44), f(my + 90), f(mx + 38), f(my + 120),
        f(mx + 80), f(my + 120), f(mx + 80), f(my)), "#a9783c", "", 'opacity=".24"'))
    # foot
    a.append('<path d="M%s %s A49 15 0 0 0 %s %s" fill="none" %s/>' % (f(mx - 50), f(my + 84), f(mx + 50), f(my + 84), st(2.6, "#b79d78")))
    # gloss
    a.append(path("M%s %s C%s %s %s %s %s %s" % (f(mx - 47), f(my + 22), f(mx - 47), f(my + 44), f(mx - 44), f(my + 62), f(mx - 40), f(my + 76)),
                  "none", st(6.4, "#ffffff")))
    a.append('<circle cx="%s" cy="%s" r="3.2" fill="#ffffff"/>' % (f(mx - 37), f(my + 88)))
    # light coming back off the saucer on the dark side
    a.append(path("M%s %s C%s %s %s %s %s %s" % (f(mx + 55.5), f(my + 44), f(mx + 54), f(my + 60), f(mx + 51.5), f(my + 74), f(mx + 48.5), f(my + 86)),
                  "none", st(2.6, "#fff4dc"), 'opacity=".8"'))
    a.append("</g>")
    a.append(path(body, "none", st()))
    # rim and coffee
    a.append(ell(mx, my, 60, 19, "#fffaf0", st()))
    defs.append('<clipPath id="mi"><ellipse cx="%s" cy="%s" rx="52.5" ry="14.6"/></clipPath>' % (f(mx), f(my + 1.2)))
    a.append(ell(mx, my + 1.2, 52.5, 14.6, "#cdb58f"))
    a.append('<g clip-path="url(#mi)">')
    a.append(ell(mx, my + 6.5, 51, 13.5, "url(#cof)", st(2.4)))
    a.append(ell(mx, my + 6.5, 46, 10.5, "none", st(2.2, "#b06a2c"), 'opacity=".9"'))
    a.append(path("M%s %s Q%s %s %s %s" % (f(mx - 34), f(my + 4), f(mx - 20), f(my - 3.5), f(mx + 2), f(my - 3.5)), "none", st(3, "#ffe2b8")))
    a.append("</g>")
    a.append(ell(mx, my + 1.2, 52.5, 14.6, "none", st(2.8)))
    # a run of coffee over the rim
    dx = mx - 30
    dy = my + 17
    run = ("M%s %s C%s %s %s %s %s %s L%s %s C%s %s %s %s %s %s L%s %s C%s %s %s %s %s %s Z" % (
        f(dx - 10), f(dy - 9), f(dx - 6), f(dy - 15), f(dx + 8), f(dy - 14), f(dx + 10), f(dy - 7),
        f(dx + 7.2), f(dy + 32), f(dx + 8.6), f(dy + 45), f(dx - 6.6), f(dy + 45), f(dx - 5.2), f(dy + 32),
        f(dx - 7), f(dy + 6), f(dx - 7.4), f(dy), f(dx - 12), f(dy - 3), f(dx - 10), f(dy - 9)))
    a.append(path(run, "#5d2c0e", st(2.8)))
    a.append('<path d="M%s %s L%s %s" fill="none" %s/>' % (f(dx - 2.2), f(dy + 2), f(dx - 1.6), f(dy + 30), st(2.2, "#b06a2c")))
    a.append('<circle cx="%s" cy="%s" r="1.8" fill="#ffffff"/>' % (f(dx - 1), f(dy + 35)))
    art = '<g transform="rotate(-6)">\n%s\n</g>' % "\n".join(a)
    over.append(steam([(-36, -56), (-50, -70), (-30, -84), (-44, -100), (-34, -113)], [5, 8.5, 7.5, 5, 1.2]))
    over.append(steam([(6, -60), (20, -74), (0, -90), (14, -104), (6, -116)], [5.5, 9, 8, 5, 1.2]))
    over.append(steam([(40, -52), (50, -62), (38, -74), (46, -86)], [3.6, 6, 5, 1.2]))
    over.append(sparkle(-94, -34, 10, 8))
    over.append(sparkle(-80, -56, 4.6, 0))
    under = '<ellipse cx="0" cy="103" rx="88" ry="8" fill="#2b1206" opacity=".16"/>'
    page("mug", "\n".join(defs), art, "\n".join(over), under, dy=3)


# ----------------------------------------------------------------------------------------- pie

def pie():
    a, defs, over = [], [], []
    # A wedge lying on a plate, seen from the front and above: T is the point, A..B the crimped rim.
    K = 0.5
    T = (-90.0, 14.0)
    R = 180.0
    A1, A2 = math.radians(-12), math.radians(34)
    H = 34.0

    def rim(ang, r=R):
        return (T[0] + r * math.cos(ang), T[1] - K * r * math.sin(ang))

    B, A = rim(A1), rim(A2)

    def uv(u, v):
        return (T[0] + u * (B[0] - T[0]) + v * (A[0] - T[0]), T[1] + u * (B[1] - T[1]) + v * (A[1] - T[1]))

    def side(s, t):
        return (T[0] + s * (B[0] - T[0]), T[1] + s * (B[1] - T[1]) + t)

    defs.append('<linearGradient id="crust" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#ffc552"/>'
                '<stop offset="1" stop-color="#ee9a2a"/></linearGradient>')
    defs.append('<linearGradient id="fill" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#f52a40"/>'
                '<stop offset="1" stop-color="#c01230"/></linearGradient>')
    PCX, PCY, PRX, PRY = 0, 48, 104, 50
    a += plate(PCX, PCY, PRX, PRY, 6)
    defs.append('<clipPath id="pl"><ellipse cx="%s" cy="%s" rx="%s" ry="%s"/></clipPath>' % (f(PCX), f(PCY), f(PRX - 2), f(PRY - 2)))
    # shadow of the slice on the plate
    a.append('<g clip-path="url(#pl)">')
    a.append(path("M%s L%s L%s L%s Z" % (pt(side(-.02, H - 4)), pt(side(1.02, H - 4)), pt((B[0] + 2, B[1] + H + 7)), pt((T[0] + 7, T[1] + H + 8))),
                  "#a9bfdc", st(4, "#a9bfdc")))
    a.append("</g>")
    # the cut side
    sd = "M%s L%s L%s L%s Z" % (pt(T), pt(B), pt(side(1, H)), pt(side(0, H)))
    a.append(path(sd, "url(#crust)"))
    top_t, bot_t = 6.5, H - 7.5
    # bottom crust line and a few flakes
    a.append(path("M%s L%s" % (pt(side(0.02, bot_t + 4.2)), pt(side(0.9, bot_t + 4.2))), "none", st(2, "#d07d18")))
    # filling between the two crusts, bulging and running
    wav = [(0.9, bot_t), (0.84, bot_t + 1.5), (0.77, bot_t - 1), (0.715, bot_t + 2), (0.69, bot_t + 10), (0.655, bot_t + 10.5), (0.63, bot_t + 1),
           (0.55, bot_t - 1), (0.47, bot_t + 1.5), (0.415, bot_t + 3), (0.395, bot_t + 21), (0.335, bot_t + 21), (0.315, bot_t + 3),
           (0.24, bot_t), (0.15, bot_t + 1), (0.08, bot_t - 3), (0.04, bot_t - 8)]
    fd = "M%s L%s " % (pt(side(0.04, top_t)), pt(side(0.9, top_t))) + smooth([side(s, t) for s, t in wav], False).replace("M", "L", 1) + " Z"
    defs.append('<clipPath id="fl"><path d="%s"/></clipPath>' % fd)
    a.append(path(fd, "url(#fill)"))
    a.append('<g clip-path="url(#fl)">')
    a.append(path("M%s L%s L%s L%s Z" % (pt(side(0, bot_t - 5)), pt(side(1, bot_t - 5)), pt(side(1, H + 30)), pt(side(0, H + 30))), "#9c0b27", "", 'opacity=".5"'))
    a.append(path("M%s L%s" % (pt(side(0.05, top_t + 2.6)), pt(side(0.9, top_t + 2.6))), "none", st(2.2, "#ff7a84"), 'opacity=".9"'))
    for s, t, r in ((0.12, 15, 5.4), (0.245, 16.5, 7), (0.40, 15.5, 7.6), (0.55, 17, 6.6), (0.70, 15.5, 7.4), (0.83, 16.5, 6)):
        c = side(s, t)
        a.append('<circle cx="%s" cy="%s" r="%s" fill="#ff4f5c" %s/>' % (f(c[0]), f(c[1]), f(r), st(2, "#7d0a20")))
        a.append('<path d="M%s %s a%s %s 0 0 0 %s %s" fill="none" %s opacity=".55"/>' % (f(c[0] - r * .5), f(c[1] + r * .45), f(r * .7), f(r * .7), f(r), f(-r * .2), st(2, "#a00c28")))
        a.append('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="#ffffff" transform="rotate(-30 %s %s)"/>' % (
            f(c[0] - r * .32), f(c[1] - r * .36), f(r * .36), f(r * .21), f(c[0] - r * .32), f(c[1] - r * .36)))
    a.append("</g>")
    a.append(path(fd, "none", st(2.8)))
    c = side(0.365, bot_t + 15)
    a.append('<ellipse cx="%s" cy="%s" rx="1.7" ry="2.8" fill="#ffffff"/>' % (f(c[0] - 2.4), f(c[1])))
    # crust end at the rim, flaky
    ce = "M%s L%s L%s L%s Z" % (pt(side(0.9, 0)), pt(B), pt(side(1, H)), pt(side(0.9, H)))
    a.append(path(ce, "#f2a534", st(2.6)))
    for t in (10, 18, 26):
        p1, p2 = side(0.925, t + 1), side(0.98, t - .5)
        a.append('<path d="M%s L%s" fill="none" %s/>' % (pt(p1), pt(p2), st(2, "#c26f14")))
    a.append(path(sd, "none", st()))
    # puddle where the long run lands
    pc = side(0.365, H + 8)
    a.append(path(smooth([(pc[0] - 15, pc[1]), (pc[0] - 4, pc[1] - 4.5), (pc[0] + 13, pc[1] - 2), (pc[0] + 17, pc[1] + 3.5), (pc[0] + 3, pc[1] + 6.5), (pc[0] - 11, pc[1] + 5)]),
                  "#d4182f", st(2.6)))
    a.append('<path d="M%s %s q7 -2.5 14 -.5" fill="none" %s/>' % (f(pc[0] - 7), f(pc[1] - .5), st(1.8, "#ff8a8f")))
    # the top: filling under a woven lattice
    N = 14
    arc = [rim(A2 + (A1 - A2) * i / N) for i in range(N + 1)]
    td = "M%s L%s " % (pt(T), pt(arc[0])) + " ".join("L" + pt(p) for p in arc[1:]) + " Z"
    defs.append('<clipPath id="tp"><path d="%s"/></clipPath>' % td)
    a.append(path(td, "#d4182f"))
    lat = ['<g clip-path="url(#tp)">']
    hw = 0.074
    fam1 = [0.27, 0.535, 0.80]            # u + v = c : along the rim
    fam2 = [-0.60, -0.20, 0.20, 0.60]     # u - v = d : from the point to the rim

    def q(cc, dd):
        return uv((cc + dd) / 2, (cc - dd) / 2)

    def strip1(c, lo=-1.3, hi=1.3, w=hw):
        return [q(c - w, lo), q(c - w, hi), q(c + w, hi), q(c + w, lo)]

    def strip2(d_, lo=-0.2, hi=1.4, w=hw):
        return [q(lo, d_ - w), q(hi, d_ - w), q(hi, d_ + w), q(lo, d_ + w)]

    def mix(p, r, k):
        return (p[0] * (1 - k) + r[0] * k, p[1] * (1 - k) + r[1] * k)

    def draw_strip(P, lit_edge, ends=False):
        o = ['<path d="M%s L%s L%s L%s Z" fill="#ef9a26"/>' % tuple(pt(p) for p in P)]
        if lit_edge == 0:
            Q = [P[0], P[1], mix(P[1], P[2], .6), mix(P[0], P[3], .6)]
        else:
            Q = [P[3], P[2], mix(P[2], P[1], .6), mix(P[3], P[0], .6)]
        o.append('<path d="M%s L%s L%s L%s Z" fill="#ffcf5e"/>' % tuple(pt(p) for p in Q))
        o.append('<path d="M%s L%s M%s L%s" fill="none" %s/>' % (pt(P[0]), pt(P[1]), pt(P[3]), pt(P[2]), st(2.5)))
        return o

    # shadow of the lattice on the filling
    for P in [strip1(c) for c in fam1] + [strip2(d_) for d_ in fam2]:
        lat.append('<path d="M%s L%s L%s L%s Z" fill="#8f0a22" opacity=".65" transform="translate(2.4 3.6)"/>' % tuple(pt(p) for p in P))
    # glints on the filling in the gaps
    for cc, dd in ((0.405, 0.0), (0.67, 0.4), (0.67, -0.4), (0.67, 0.0), (0.92, 0.42), (0.92, -0.4)):
        g = q(cc - 0.03, dd - 0.06)
        lat.append('<ellipse cx="%s" cy="%s" rx="3.4" ry="1.7" fill="#ff8a93" transform="rotate(-20 %s %s)"/>' % (f(g[0]), f(g[1]), f(g[0]), f(g[1])))
    for c in fam1:
        lat += draw_strip(strip1(c), 0)
    for d_ in fam2:
        lat += draw_strip(strip2(d_), 0)
    # weave: at every other crossing the rim-wise strip comes back on top
    for i, c in enumerate(fam1):
        for j, d_ in enumerate(fam2):
            if (i + j) % 2 == 0:
                lat += draw_strip(strip1(c, d_ - hw - 0.035, d_ + hw + 0.035), 0)
    lat.append("</g>")
    a += lat
    a.append(path(td, "none", st()))
    # the crimped rim, far end first
    M = 8
    for i in range(M):
        ang = A2 + (A1 - A2) * (i + .5) / M
        c = rim(ang, R - 4)
        nx = rim(ang - 0.01, R - 4)
        rot = math.degrees(math.atan2(nx[1] - c[1], nx[0] - c[0]))
        cxp, cyp = c[0], c[1] - 6
        a.append('<g transform="rotate(%s %s %s)">' % (f(rot), f(cxp), f(cyp)))
        a.append(ell(cxp, cyp, 8.8, 11.5, "#f6ab36", st()))
        a.append('<path d="M%s %s a8 9 0 0 0 11 -1" fill="none" %s opacity=".8"/>' % (f(cxp - 4), f(cyp + 6.4), st(3, "#d8811c")))
        a.append('<path d="M%s %s a6 8 0 0 1 6.4 -6.6" fill="none" %s/>' % (f(cxp - 5), f(cyp - 1.6), st(2.8, "#ffe59a")))
        a.append("</g>")
    # whipped cream and a cherry
    wx, wy = uv(0.50, 0.33)
    cream = [
        smooth([(wx - 26, wy + 3), (wx - 21, wy - 9), (wx - 4, wy - 14), (wx + 17, wy - 11), (wx + 26, wy), (wx + 19, wy + 9), (wx + 2, wy + 12), (wx - 17, wy + 10)]),
        smooth([(wx - 19, wy - 12), (wx - 13, wy - 22), (wx + 1, wy - 26), (wx + 15, wy - 22), (wx + 19, wy - 13), (wx + 11, wy - 5), (wx - 2, wy - 3), (wx - 13, wy - 5)]),
        smooth([(wx - 12, wy - 24), (wx - 6, wy - 33), (wx + 2, wy - 37), (wx + 10, wy - 32), (wx + 12, wy - 25), (wx + 6, wy - 18), (wx - 3, wy - 17), (wx - 8, wy - 19)]),
    ]
    a.append(ell(wx + 4, wy + 8, 27, 8, "#7d0a20", "", 'opacity=".5"'))
    for i, cd in enumerate(cream):
        cid = "cr%d" % i
        defs.append('<clipPath id="%s"><path d="%s"/></clipPath>' % (cid, cd))
        a.append(path(cd, "#c3d5f0"))
        a.append('<g clip-path="url(#%s)">' % cid)
        a.append(path(cd, "#ffffff", "", 'transform="translate(-4 -4.5)"'))
        a.append("</g>")
        a.append(path(cd, "none", st(2.8)))
    a.append('<path d="M%s %s q6 4 16 2" fill="none" %s/>' % (f(wx - 12), f(wy - 5), st(2, "#9fb6d8")))
    a.append('<path d="M%s %s q5 3 12 1.5" fill="none" %s/>' % (f(wx - 7), f(wy - 18.5), st(2, "#9fb6d8")))
    chx, chy = wx + 2, wy - 40
    defs.append('<radialGradient id="ch" cx=".36" cy=".3" r=".8"><stop offset="0" stop-color="#ff5560"/><stop offset="1" stop-color="#c8102e"/></radialGradient>')
    stem = "M%s %s C%s %s %s %s %s %s" % (f(chx + 1), f(chy - 8), f(chx), f(chy - 22), f(chx - 8), f(chy - 30), f(chx - 19), f(chy - 33))
    a.append('<path d="%s" fill="none" %s/>' % (stem, st(7.6)))
    a.append('<path d="%s" fill="none" %s/>' % (stem, st(2.8, "#63c341")))
    a.append('<circle cx="%s" cy="%s" r="11.5" fill="url(#ch)" %s/>' % (f(chx), f(chy), st()))
    a.append('<path d="M%s %s a9 9 0 0 0 13 -3" fill="none" %s opacity=".6"/>' % (f(chx - 5), f(chy + 6.5), st(2.6, "#8f0a22")))
    a.append('<ellipse cx="%s" cy="%s" rx="4" ry="2.3" fill="#ffffff" transform="rotate(-32 %s %s)"/>' % (f(chx - 4), f(chy - 4.6), f(chx - 4), f(chy - 4.6)))
    art = '<g transform="rotate(-3)">\n%s\n</g>' % "\n".join(a)
    over.append(sparkle(-56, -40, 11, 8))
    over.append(sparkle(-36, -62, 5, 0))
    over.append(sparkle(100, -48, 6, -8))
    under = '<ellipse cx="0" cy="106" rx="88" ry="7" fill="#2b1206" opacity=".16"/>'
    page("pie", "\n".join(defs), art, "\n".join(over), under, dy=-19)


if __name__ == "__main__":
    egg()
    stack()
    mug()
    pie()
    print("wrote egg stack mug pie")
