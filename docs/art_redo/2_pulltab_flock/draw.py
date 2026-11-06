"""One Flock's four symbols in the manner of printed pull-tab tickets (reference folder 2):
a firm dark outline, gradient modelling, hard white highlights, a white sticker keyline and a
drop shadow. Writes uncle.svg, liberty.svg, bell.svg, rocket.svg beside this file:

    python docs/art_redo/2_pulltab_flock/draw.py
    python docs/art_redo/render.py 2_pulltab_flock

Light comes from the upper left in all four.
"""
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
INK = "#15110f"
O = 'stroke="%s" stroke-width="5" stroke-linejoin="round" stroke-linecap="round"' % INK      # outer contour
I = 'stroke="%s" stroke-width="2.8" stroke-linejoin="round" stroke-linecap="round"' % INK    # inner line
T = 'stroke="%s" stroke-width="1.8" stroke-linejoin="round" stroke-linecap="round"' % INK    # detail line

STICKER = """
<filter id="sticker" x="-20%" y="-20%" width="140%" height="140%" color-interpolation-filters="sRGB">
  <feMorphology in="SourceAlpha" operator="dilate" radius="4.2" result="d"/>
  <feGaussianBlur in="d" stdDeviation="1.3" result="b"/>
  <feComponentTransfer in="b" result="k"><feFuncA type="linear" slope="8" intercept="-3.5"/></feComponentTransfer>
  <feFlood flood-color="#ffffff"/><feComposite in2="k" operator="in" result="white"/>
  <feGaussianBlur in="k" stdDeviation="2.6" result="sb"/>
  <feOffset in="sb" dx="2.5" dy="4.5" result="so"/>
  <feFlood flood-color="#0a0a20" flood-opacity=".55"/><feComposite in2="so" operator="in" result="shadow"/>
  <feMerge><feMergeNode in="shadow"/><feMergeNode in="white"/><feMergeNode in="SourceGraphic"/></feMerge>
</filter>
"""


def n(v):
    return ("%.2f" % v).rstrip("0").rstrip(".")


def star(cx, cy, r, rot=-90, inner=.42, points=5):
    pts = []
    for i in range(points * 2):
        a = math.radians(rot + i * 180 / points)
        rr = r if i % 2 == 0 else r * inner
        pts.append("%s %s" % (n(cx + rr * math.cos(a)), n(cy + rr * math.sin(a))))
    return "M" + " L".join(pts) + "Z"


def burst(cx, cy, r_out, r_in, points, rot=0, sx=1, sy=1):
    pts = []
    for i in range(points * 2):
        a = math.radians(rot + i * 180 / points)
        rr = r_out if i % 2 == 0 else r_in
        pts.append("%s %s" % (n(cx + rr * math.cos(a) * sx), n(cy + rr * math.sin(a) * sy)))
    return "M" + " L".join(pts) + "Z"


def sparkle(cx, cy, r, pinch=.2):
    """A four-point twinkle with curved-in sides."""
    p = r * pinch
    return ("M%s %s Q%s %s %s %s Q%s %s %s %s Q%s %s %s %s Q%s %s %s %sZ" % (
        n(cx), n(cy - r), n(cx + p), n(cy - p), n(cx + r), n(cy), n(cx + p), n(cy + p), n(cx), n(cy + r),
        n(cx - p), n(cy + p), n(cx - r), n(cy), n(cx - p), n(cy - p), n(cx), n(cy - r)))


def svg(defs, body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="-120 -120 240 240">\n<defs>%s%s</defs>\n'
            '<g filter="url(#sticker)">\n%s\n</g>\n</svg>\n' % (STICKER, defs, body))


def write(name, text):
    with open(os.path.join(HERE, name + ".svg"), "w", encoding="utf-8") as f:
        f.write(text)


# --------------------------------------------------------------------------------------- bell
def bell():
    body = ("M-37 -56 C-37 -78 37 -78 37 -56 C39 -30 43 -4 53 18 C61 36 78 46 89 56 "
            "L90 64 Q0 84 -90 64 L-89 56 C-78 46 -61 36 -53 18 C-43 -4 -39 -30 -37 -56Z")
    yoke = ("M-64 -83 C-64 -96 -52 -101 -32 -101 L32 -101 C52 -101 64 -96 64 -83 L64 -78 "
            "C48 -78 40 -72 34 -60 L-34 -60 C-40 -72 -48 -78 -64 -78Z")
    crack = "M3 73 L-2 52 L7 40 L-3 24 L5 9 L1 -6 L8 9 L3 24 L13 40 L6 52 L11 72Z"
    defs = """
<linearGradient id="bz" gradientUnits="userSpaceOnUse" x1="-88" y1="0" x2="88" y2="0">
  <stop offset="0" stop-color="#5e2804"/><stop offset=".1" stop-color="#a5540a"/>
  <stop offset=".27" stop-color="#ffc93c"/><stop offset=".34" stop-color="#fff3b0"/>
  <stop offset=".42" stop-color="#ffc230"/><stop offset=".6" stop-color="#e08a12"/>
  <stop offset=".8" stop-color="#a04e08"/><stop offset=".92" stop-color="#6b2f05"/>
  <stop offset=".97" stop-color="#d98a22"/><stop offset="1" stop-color="#8a4608"/>
</linearGradient>
<linearGradient id="bzv" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#3a1602" stop-opacity=".6"/><stop offset=".22" stop-color="#3a1602" stop-opacity="0"/>
  <stop offset=".8" stop-color="#3a1602" stop-opacity="0"/><stop offset="1" stop-color="#3a1602" stop-opacity=".45"/>
</linearGradient>
<linearGradient id="wood" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#e2783a"/><stop offset=".3" stop-color="#b84a1c"/><stop offset="1" stop-color="#5a1c08"/>
</linearGradient>
<linearGradient id="iron" x1="0" y1="0" x2="1" y2="0">
  <stop offset="0" stop-color="#4b525c"/><stop offset=".35" stop-color="#e9eef4"/><stop offset="1" stop-color="#3a4049"/>
</linearGradient>
<radialGradient id="clap" cx=".35" cy=".3" r=".8">
  <stop offset="0" stop-color="#ffd76a"/><stop offset=".5" stop-color="#b9650e"/><stop offset="1" stop-color="#4a1f03"/>
</radialGradient>
<clipPath id="bellclip"><path d="%(body)s"/></clipPath>
<clipPath id="yokeclip"><path d="%(yoke)s"/></clipPath>
""" % {"body": body, "yoke": yoke}
    out = []
    # clapper
    out.append('<path d="M-5 62 L-5 80 L5 80 L5 62Z" fill="#6b2f05" %s/>' % I)
    out.append('<circle cx="0" cy="88" r="12.5" fill="url(#clap)" %s/>' % O)
    out.append('<ellipse cx="-4" cy="83.5" rx="3.6" ry="2.4" fill="#fff" opacity=".9" transform="rotate(-30 -4 83.5)"/>')
    # yoke
    out.append('<path d="%s" fill="url(#wood)" %s/>' % (yoke, O))
    out.append('<g clip-path="url(#yokeclip)">')
    out.append('<path d="M-60 -95 C-40 -98 40 -98 60 -95" fill="none" stroke="#ffc08a" stroke-width="2.6" stroke-linecap="round" opacity=".9"/>')
    for d in ("M-56 -88 C-30 -91 -8 -86 14 -89", "M-10 -80 C12 -83 36 -79 58 -84", "M-48 -82 C-38 -84 -30 -81 -22 -78"):
        out.append('<path d="%s" fill="none" stroke="#4a1505" stroke-width="1.4" stroke-linecap="round" opacity=".75"/>' % d)
    out.append("</g>")
    for x in (-27, 19):
        out.append('<path d="M%d -103 L%d -103 L%d -60 L%d -60Z" fill="url(#iron)" %s/>' % (x, x + 8, x + 8, x, I))
        out.append('<circle cx="%d" cy="-92" r="1.9" fill="%s"/>' % (x + 4, INK))
        out.append('<circle cx="%d" cy="-72" r="1.9" fill="%s"/>' % (x + 4, INK))
    # body
    out.append('<path d="%s" fill="url(#bz)"/>' % body)
    out.append('<g clip-path="url(#bellclip)">')
    out.append('<rect x="-90" y="-80" width="180" height="170" fill="url(#bzv)"/>')
    # lip: a darker band under a bright bevel line
    out.append('<path d="M-92 50 Q0 72 92 50 L92 90 L-92 90Z" fill="#7a3906" opacity=".38"/>')
    out.append('<path d="M-92 50 Q0 72 92 50" fill="none" stroke="#4a1f03" stroke-width="2.6"/>')
    out.append('<path d="M-92 53.5 Q0 75.5 92 53.5" fill="none" stroke="#ffe59a" stroke-width="1.8" opacity=".9"/>')
    # engraved bands
    for y, sag in ((-40, 5), (-32, 5.5), (22, 12), (30, 13)):
        out.append('<path d="M-92 %s Q0 %s 92 %s" fill="none" stroke="#5a2604" stroke-width="2.2" opacity=".9"/>' % (y, y + 2 * sag, y))
        out.append('<path d="M-92 %s Q0 %s 92 %s" fill="none" stroke="#fff0b0" stroke-width="1.3" opacity=".75"/>' % (y + 2.6, y + 2.6 + 2 * sag, y + 2.6))
    # reflected light low on the right
    out.append('<path d="M40 16 C48 34 64 44 80 54 L70 56 C58 48 46 38 40 16Z" fill="#ffb347" opacity=".5"/>')
    # hard highlights
    out.append('<path d="M-26 -54 C-27 -30 -31 -6 -41 16 C-33 -2 -27 -30 -14 -54Z" fill="#ffffff" opacity=".95"/>')
    out.append('<path d="M-44 28 C-50 38 -60 44 -70 50 C-62 42 -54 36 -40 28Z" fill="#ffffff" opacity=".9"/>')
    out.append('<path d="M-62 66 Q-40 71 -18 72.5 L-18 75.5 Q-42 74 -64 69Z" fill="#fff6c8" opacity=".9"/>')
    out.append("</g>")
    out.append('<path d="%s" fill="none" %s/>' % (body, O))
    # the crack
    out.append('<path d="%s" fill="#241003" stroke="%s" stroke-width="1.6" stroke-linejoin="round"/>' % (crack, INK))
    out.append('<path d="M11 72 L6 52 L13 40 L3 24 L8 9" fill="none" stroke="#ffe9a0" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" transform="translate(2.2 0)"/>')
    write("bell", svg(defs, "\n".join(out)))


# ------------------------------------------------------------------------------------- rocket
def rocket():
    body = "M-29 -40 L29 -40 L29 42 Q0 54 -29 42Z"
    cone = "M-38 -39 C-33 -64 -16 -88 0 -102 C16 -88 33 -64 38 -39 Q0 -28 -38 -39Z"
    defs = """
<linearGradient id="cyl_d" gradientUnits="userSpaceOnUse" x1="-29" y1="0" x2="29" y2="0">
  <stop offset="0" stop-color="#1a0a2a" stop-opacity=".45"/><stop offset=".2" stop-color="#1a0a2a" stop-opacity="0"/>
  <stop offset=".55" stop-color="#1a0a2a" stop-opacity="0"/><stop offset="1" stop-color="#1a0a2a" stop-opacity=".6"/>
</linearGradient>
<linearGradient id="cyl_l" gradientUnits="userSpaceOnUse" x1="-29" y1="0" x2="29" y2="0">
  <stop offset=".18" stop-color="#fff" stop-opacity="0"/><stop offset=".3" stop-color="#fff" stop-opacity=".85"/>
  <stop offset=".4" stop-color="#fff" stop-opacity="0"/>
</linearGradient>
<linearGradient id="cone" gradientUnits="userSpaceOnUse" x1="-38" y1="0" x2="38" y2="0">
  <stop offset="0" stop-color="#0b1a66"/><stop offset=".3" stop-color="#3f7cff"/><stop offset=".4" stop-color="#2a5be0"/>
  <stop offset="1" stop-color="#081250"/>
</linearGradient>
<linearGradient id="gold" gradientUnits="userSpaceOnUse" x1="-33" y1="0" x2="33" y2="0">
  <stop offset="0" stop-color="#8a4a00"/><stop offset=".3" stop-color="#fff3a8"/><stop offset=".5" stop-color="#ffc21a"/>
  <stop offset="1" stop-color="#8a4a00"/>
</linearGradient>
<linearGradient id="stick" gradientUnits="userSpaceOnUse" x1="12" y1="0" x2="23" y2="0">
  <stop offset="0" stop-color="#f6d08a"/><stop offset="1" stop-color="#a86a24"/>
</linearGradient>
<radialGradient id="fire" cx=".5" cy=".5" r=".5">
  <stop offset="0" stop-color="#fff"/><stop offset=".35" stop-color="#fff27a"/><stop offset="1" stop-color="#ffb300"/>
</radialGradient>
<radialGradient id="tw" cx=".4" cy=".35" r=".7">
  <stop offset="0" stop-color="#fffbd0"/><stop offset="1" stop-color="#ffc400"/>
</radialGradient>
<clipPath id="bodyclip"><path d="%(body)s"/></clipPath>
<clipPath id="coneclip"><path d="%(cone)s"/></clipPath>
""" % {"body": body, "cone": cone}
    out = ['<g transform="translate(5 -6) rotate(35)">']
    # exhaust burst, then the stick over it
    out.append('<path d="%s" fill="#ff4a00" %s/>' % (burst(-4, 62, 37, 22, 9, rot=10, sy=1.08), I))
    out.append('<path d="%s" fill="url(#fire)"/>' % burst(-4, 62, 26, 14, 9, rot=30, sy=1.08))
    out.append('<path d="M12 20 L23 20 L22 110 L13 110Z" fill="url(#stick)" %s/>' % O)
    # body
    out.append('<path d="%s" fill="#ffffff"/>' % body)
    out.append('<g clip-path="url(#bodyclip)">')
    for i in range(6):
        y0 = -62 + i * 25
        out.append('<path d="M-31 %s L31 %s L31 %s L-31 %sZ" fill="#e3172b"/>' % (y0 + 18, y0 - 12, y0, y0 + 30))
    out.append('<rect x="-31" y="-44" width="62" height="102" fill="url(#cyl_d)"/>')
    out.append('<rect x="-31" y="-44" width="62" height="102" fill="url(#cyl_l)"/>')
    out.append("</g>")
    out.append('<path d="%s" fill="none" %s/>' % (body, O))
    # gold ring under the cone, and one at the foot
    out.append('<path d="M-32 -42 L32 -42 L32 -31 Q0 -21 -32 -31Z" fill="url(#gold)" %s/>' % I)
    out.append('<path d="M-31 30 Q0 42 31 30 L31 42 Q0 54 -31 42Z" fill="url(#gold)" %s/>' % I)
    # nose cone
    out.append('<path d="%s" fill="url(#cone)"/>' % cone)
    out.append('<g clip-path="url(#coneclip)">')
    out.append('<path d="M-20 -46 C-17 -64 -10 -78 -3 -90 C-11 -78 -24 -62 -29 -46Z" fill="#ffffff" opacity=".85"/>')
    out.append("</g>")
    out.append('<path d="%s" fill="#ffffff" %s/>' % (star(3, -58, 15.5), T))
    out.append('<path d="%s" fill="none" %s/>' % (cone, O))
    out.append("</g>")
    # twinkles
    for x, y, r in ((-66, -50, 20), (-30, -90, 10), (72, 44, 15)):
        out.append('<path d="%s" fill="url(#tw)" %s/>' % (sparkle(x, y, r), I))
    write("rocket", svg(defs, "\n".join(out)))


# -------------------------------------------------------------------------------------- uncle
def uncle():
    k = 1.12                                  # the whole bust is drawn a little larger than its numbers
    o = O.replace('"5"', '"%s"' % n(5 / k))
    i_ = I.replace('"2.8"', '"%s"' % n(2.8 / k))
    t = T.replace('"1.8"', '"%s"' % n(1.8 / k))
    head = ("M-42 -24 C-52 -6 -50 14 -54 28 C-57 40 -63 48 -71 56 L-57 56 L-60 72 L-44 64 L-42 80 L-27 68 "
            "L-21 82 L-8 69 L2 78 L9 66 L17 70 L18 58 C19 50 16 46 19 40 C23 32 30 26 30 20 L37 -4 "
            "C38 -12 37 -18 36 -22 L28 -36Z")
    face = "M5 -27 C-8 -16 -8 6 4 16 C14 23 26 24 32 20 L37 -4 C38 -12 37 -18 36 -22Z"
    comb = ("M3 -28 C-2 -42 3 -58 13 -61 C20 -62 23 -54 23 -47 C25 -57 33 -64 40 -58 C45 -52 41 -43 38 -38 "
            "C44 -45 53 -41 51 -32 C49 -24 42 -17 38 -12Z")
    goatee = ("M25 20 C20 32 20 44 25 54 L19 55 C23 64 29 70 35 74 L32 79 C40 85 50 85 57 79 "
              "C51 77 49 71 50 63 C53 50 52 36 47 21Z")
    row = "M-56 24 L-46 40 L-38 28 L-28 46 L-19 33 L-9 51 L-1 38 L8 54 L14 42 L19 50"
    cx, half_b, half_t = -16, 34, 41
    top = -91
    crown = "M%s -39 Q%s -66 %s %s Q%s %s %s %s Q%s -66 %s -39 Q%s -28 %s -39Z" % (
        cx - half_b, cx - half_b - 1, cx - half_t, top, cx, top - 11, cx + half_t, top, cx + half_b + 1, cx + half_b, cx, cx - half_b)
    defs = """
<linearGradient id="fea" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="#ffffff"/><stop offset=".55" stop-color="#f1f5fc"/><stop offset="1" stop-color="#a9b9d6"/>
</linearGradient>
<linearGradient id="fea2" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="#f4f7fd"/><stop offset=".5" stop-color="#dde5f3"/><stop offset="1" stop-color="#9eb0d0"/>
</linearGradient>
<linearGradient id="red" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="#ff5a4d"/><stop offset=".5" stop-color="#e3172b"/><stop offset="1" stop-color="#8f0717"/>
</linearGradient>
<linearGradient id="beak" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#ffe45c"/><stop offset=".6" stop-color="#ffb400"/><stop offset="1" stop-color="#e06a00"/>
</linearGradient>
<linearGradient id="beak2" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#e88a00"/><stop offset="1" stop-color="#a84a00"/>
</linearGradient>
<linearGradient id="brim" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#ffffff"/><stop offset=".55" stop-color="#eef2fa"/><stop offset="1" stop-color="#93a4c6"/>
</linearGradient>
<linearGradient id="hat_d" gradientUnits="userSpaceOnUse" x1="-58" y1="0" x2="26" y2="0">
  <stop offset="0" stop-color="#0a0a30" stop-opacity=".4"/><stop offset=".16" stop-color="#0a0a30" stop-opacity="0"/>
  <stop offset=".5" stop-color="#0a0a30" stop-opacity="0"/><stop offset="1" stop-color="#0a0a30" stop-opacity=".62"/>
</linearGradient>
<linearGradient id="hat_l" gradientUnits="userSpaceOnUse" x1="-58" y1="0" x2="26" y2="0">
  <stop offset=".14" stop-color="#fff" stop-opacity="0"/><stop offset=".26" stop-color="#fff" stop-opacity=".8"/>
  <stop offset=".36" stop-color="#fff" stop-opacity="0"/>
</linearGradient>
<linearGradient id="band" gradientUnits="userSpaceOnUse" x1="-54" y1="0" x2="22" y2="0">
  <stop offset="0" stop-color="#0b1a66"/><stop offset=".28" stop-color="#3f7cff"/><stop offset=".45" stop-color="#2450d8"/>
  <stop offset="1" stop-color="#081250"/>
</linearGradient>
<radialGradient id="iris" cx=".4" cy=".35" r=".7">
  <stop offset="0" stop-color="#ffe04a"/><stop offset="1" stop-color="#e07a00"/>
</radialGradient>
<clipPath id="headclip"><path d="%(head)s"/></clipPath>
<clipPath id="crownclip"><path d="%(crown)s"/></clipPath>
<clipPath id="combclip"><path d="%(comb)s"/></clipPath>
<clipPath id="goatclip"><path d="%(goatee)s"/></clipPath>
""" % {"head": head, "crown": crown, "comb": comb, "goatee": goatee}
    out = ['<g transform="translate(1 6) scale(%s)">' % k]
    # ---- neck and head
    out.append('<path d="%s" fill="url(#fea)" %s/>' % (head, o))
    out.append('<g clip-path="url(#headclip)">')
    # the lower row of hackles sits in the shade of the upper one
    out.append('<path d="%s L30 90 L-80 90Z" fill="url(#fea2)"/>' % row)
    out.append('<path d="%s" fill="none" stroke="#7f93b8" stroke-width="6" stroke-linejoin="round" opacity=".6" transform="translate(0 4)"/>' % row)
    out.append('<path d="M30 18 C18 28 10 40 11 54 C12 66 9 78 4 90 L30 90Z" fill="#8fa3c8" opacity=".85"/>')
    out.append('<path d="M-60 -40 L40 -40 L40 -22 C10 -14 -30 -14 -60 -10Z" fill="#8fa3c8" opacity=".7"/>')
    for d in ("M-45 2 C-46 12 -48 20 -51 27", "M-34 8 C-34 18 -35 26 -38 32", "M-22 16 C-21 24 -22 30 -24 36",
              "M-50 46 C-52 52 -56 58 -60 62", "M-34 50 C-35 58 -38 64 -42 70", "M-16 54 C-16 62 -18 68 -22 74", "M0 58 C1 64 0 70 -2 74"):
        out.append('<path d="%s" fill="none" stroke="#7f93b8" stroke-width="2.2" stroke-linecap="round"/>' % d)
    out.append('<path d="%s" fill="none" %s/>' % (row, i_))
    out.append("</g>")
    # ---- hat (it sits back, behind the comb)
    out.append('<g transform="rotate(-12 -8 -34)">')
    out.append('<ellipse cx="%s" cy="-34" rx="60" ry="12.5" fill="url(#brim)" %s/>' % (cx, o))
    out.append('<path d="M-73 -31 C-50 -23 16 -23 41 -31" fill="none" stroke="#7f93b8" stroke-width="2" stroke-linecap="round" opacity=".8"/>')
    out.append('<path d="%s" fill="#ffffff"/>' % crown)
    out.append('<g clip-path="url(#crownclip)">')
    edges = [math.sin(math.radians(a)) for a in (-90, -66, -40, -13, 13, 40, 66, 90)]
    for i in range(0, 7, 2):
        b0, b1 = cx + edges[i] * 36, cx + edges[i + 1] * 36
        t0, t1 = cx + edges[i] * 43, cx + edges[i + 1] * 43
        out.append('<path d="M%s -30 L%s -106 L%s -106 L%s -30Z" fill="#e3172b"/>' % (n(b0), n(t0), n(t1), n(b1)))
    out.append('<path d="M-60 -62 Q%s -50 28 -62 L28 -20 L-60 -20Z" fill="url(#band)"/>' % cx)
    out.append('<path d="M-60 -62 Q%s -50 28 -62" fill="none" %s/>' % (cx, i_))
    out.append('<rect x="-62" y="-106" width="92" height="86" fill="url(#hat_d)"/>')
    out.append('<rect x="-62" y="-106" width="92" height="86" fill="url(#hat_l)"/>')
    for sx, sy in ((cx - 22, -47.5), (cx, -44.5), (cx + 22, -47.5)):
        out.append('<path d="%s" fill="#ffffff" stroke="%s" stroke-width="1.1" stroke-linejoin="round"/>' % (star(sx, sy, 7.5), INK))
    out.append("</g>")
    out.append('<path d="%s" fill="none" %s/>' % (crown, o))
    out.append("</g>")
    # ---- wattle, then the goatee over it
    out.append('<path d="M20 18 C8 27 6 46 17 54 C28 50 34 36 32 20Z" fill="url(#red)" %s/>' % o)
    out.append('<path d="M14 27 C11 35 12 43 16 48" fill="none" stroke="#ff9a8a" stroke-width="2.2" stroke-linecap="round"/>')
    out.append('<path d="%s" fill="url(#fea)" %s/>' % (goatee, o))
    out.append('<g clip-path="url(#goatclip)">')
    out.append('<path d="M47 20 C54 38 53 56 50 66 C48 74 52 80 58 82 L64 60 L54 18Z" fill="#8fa3c8" opacity=".85"/>')
    for d in ("M31 28 C29 40 31 50 36 60", "M38 28 C38 40 40 52 43 62", "M40 68 C41 73 44 77 48 79"):
        out.append('<path d="%s" fill="none" stroke="#7f93b8" stroke-width="2.2" stroke-linecap="round"/>' % d)
    out.append("</g>")
    # ---- comb and red face
    out.append('<path d="%s" fill="url(#red)" %s/>' % (comb, o))
    out.append('<g clip-path="url(#combclip)">')
    out.append('<path d="M8 -34 C5 -44 8 -53 13 -56" fill="none" stroke="#ffb0a0" stroke-width="3" stroke-linecap="round"/>')
    out.append('<path d="M28 -44 C30 -51 34 -55 38 -55" fill="none" stroke="#ffb0a0" stroke-width="2.6" stroke-linecap="round"/>')
    out.append("</g>")
    out.append('<path d="%s" fill="url(#red)" %s/>' % (face, i_))
    # ---- beak
    out.append('<path d="M33 12 C42 11 50 13 56 16 C50 23 42 25 32 22Z" fill="url(#beak2)" %s/>' % i_)
    out.append('<path d="M32 -9 C45 -13 58 -5 64 13 C55 9 45 11 34 13Z" fill="url(#beak)" %s/>' % o)
    out.append('<path d="M38 -6 C46 -8 54 -3 58 4 C52 0 45 -2 39 -2Z" fill="#fff" opacity=".85"/>')
    out.append('<ellipse cx="42" cy="4" rx="3" ry="1.6" fill="#7a3a00" transform="rotate(12 42 4)"/>')
    # ---- eye and brow
    out.append('<ellipse cx="16" cy="-4" rx="10.5" ry="9" fill="#fff" %s/>' % i_)
    out.append('<circle cx="18" cy="-4" r="6.6" fill="url(#iris)" %s/>' % t)
    out.append('<circle cx="18.8" cy="-4" r="3.4" fill="%s"/>' % INK)
    out.append('<circle cx="16.2" cy="-6.8" r="1.9" fill="#fff"/>')
    out.append('<path d="M-2 -19 C8 -28 23 -24 33 -9 C24 -15 13 -15 1 -10Z" fill="#fff" %s/>' % i_)
    out.append("</g>")
    write("uncle", svg(defs, "\n".join(out)))


# ------------------------------------------------------------------------------------ liberty
def liberty():
    head = ("M-46 -20 C-52 -10 -53 0 -50 6 L-46 22 C-42 34 -28 42 -12 42 C10 42 26 26 28 6 "
            "C30 -16 18 -34 0 -42 C-18 -46 -36 -38 -46 -20Z")
    hair = "M2 -34 C22 -28 34 -8 30 14 C28 30 18 42 4 50 C10 38 2 30 8 18 C-2 8 8 -8 -4 -18Z"
    robe = "M-68 102 C-66 82 -56 68 -40 60 L18 56 C38 60 54 76 62 102 Q0 110 -68 102Z"
    arm = "M34 104 C38 78 50 58 63 45 C60 36 62 26 69 22 L93 24 C98 33 96 45 89 52 C82 72 76 88 74 104Z"
    head_face = ("M-46 -20 C-52 -10 -53 0 -50 6 L-46 22 C-42 34 -28 42 -12 42 C0 42 8 34 8 18 "
                 "C-2 8 8 -8 -4 -18 L2 -34 C-18 -46 -36 -38 -46 -20Z")
    cxs, cys = -10, -10
    defs = """
<linearGradient id="vg" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="#c9f7e2"/><stop offset=".35" stop-color="#6fd0ad"/><stop offset=".7" stop-color="#2f9c84"/>
  <stop offset="1" stop-color="#145c53"/>
</linearGradient>
<linearGradient id="vg2" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="#8fe0c2"/><stop offset=".5" stop-color="#3aa58a"/><stop offset="1" stop-color="#0f4a44"/>
</linearGradient>
<linearGradient id="vg3" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="#63c5a4"/><stop offset="1" stop-color="#1c6f61"/>
</linearGradient>
<linearGradient id="vlight" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#e6fff3"/><stop offset="1" stop-color="#7fd9b8"/>
</linearGradient>
<linearGradient id="tgold" gradientUnits="userSpaceOnUse" x1="62" y1="0" x2="98" y2="0">
  <stop offset="0" stop-color="#8a4a00"/><stop offset=".3" stop-color="#fff3a8"/><stop offset=".5" stop-color="#ffc21a"/>
  <stop offset="1" stop-color="#8a4a00"/>
</linearGradient>
<linearGradient id="flame" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#ff3d00"/><stop offset="1" stop-color="#ff9a00"/>
</linearGradient>
<linearGradient id="flame2" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#ffd000"/><stop offset="1" stop-color="#fff9c0"/>
</linearGradient>
<clipPath id="lhead"><path d="%(head_face)s"/></clipPath>
<clipPath id="lrobe"><path d="%(robe)s"/></clipPath>
<clipPath id="lhair"><path d="%(hair)s"/></clipPath>
<clipPath id="larm"><path d="%(arm)s"/></clipPath>
""" % {"head": head, "robe": robe, "hair": hair, "arm": arm, "head_face": head_face}
    out = []
    # ---- crown rays (behind the head), each in two facets
    for a in (45, 65, 85, 105, 125, 145, 165):
        ra = math.radians(a)
        ux, uy = math.cos(ra), -math.sin(ra)
        px, py = -uy, ux
        bx, by = cxs + ux * 28, cys + uy * 28
        tx, ty = cxs + ux * 90, cys + uy * 90
        w = 10.5
        l = (bx - px * w, by - py * w)
        r = (bx + px * w, by + py * w)
        # the facet whose outward normal turns to the upper left is the lit one
        l_lit = (-px - py) < 0
        first, second = ("url(#vlight)", "#2a8f79") if not l_lit else ("#2a8f79", "url(#vlight)")
        out.append('<path d="M%s %s L%s %s L%s %sZ" fill="%s"/>' % (n(l[0]), n(l[1]), n(tx), n(ty), n(bx), n(by), first))
        out.append('<path d="M%s %s L%s %s L%s %sZ" fill="%s"/>' % (n(r[0]), n(r[1]), n(tx), n(ty), n(bx), n(by), second))
        out.append('<path d="M%s %s L%s %s L%s %sZ" fill="none" stroke="%s" stroke-width="3.6" stroke-linejoin="round"/>' % (
            n(l[0]), n(l[1]), n(tx), n(ty), n(r[0]), n(r[1]), INK))
    # ---- wing raised to the torch, torch
    out.append('<path d="%s" fill="url(#vg2)" %s/>' % (arm, O))
    out.append('<g clip-path="url(#larm)">')
    out.append('<path d="M44 104 C48 82 58 64 70 52" fill="none" stroke="#c9f7e2" stroke-width="3" stroke-linecap="round" opacity=".85"/>')
    out.append("</g>")
    out.append('<path d="M70 46 L90 46 L94 -30 L66 -30Z" fill="url(#tgold)" %s/>' % O)
    out.append('<path d="M80 -106 C93 -88 102 -72 96 -54 C94 -47 87 -42 80 -42 C71 -42 63 -48 63 -58 C63 -70 72 -73 73 -86 C78 -80 80 -92 80 -106Z" fill="url(#flame)" %s/>' % O)
    out.append('<path d="M80 -84 C87 -74 90 -66 87 -57 C85 -52 83 -50 80 -50 C75 -50 71 -54 72 -60 C73 -66 78 -70 80 -84Z" fill="url(#flame2)"/>')
    out.append('<path d="M58 -30 L102 -30 L97 -45 L63 -45Z" fill="url(#tgold)" %s/>' % O)
    for x in (68, 75, 85, 92):
        out.append('<path d="M%s -43 L%s -32" fill="none" stroke="#7a3f00" stroke-width="1.6" stroke-linecap="round"/>' % (x, x + (x - 80) * -.12))
    out.append('<path d="M56 -22 L104 -22 L100 -31 L60 -31Z" fill="url(#tgold)" %s/>' % I)
    # feather fingers round the handle
    for y in (25, 34, 43):
        out.append('<path d="M63 %s C72 %s 86 %s 96 %s C93 %s 70 %s 63 %sZ" fill="url(#vg)" %s/>' % (y + 3, y - 4, y - 4, y + 2, y + 9, y + 10, y + 3, I))
    # ---- robe
    out.append('<path d="%s" fill="url(#vg2)" %s/>' % (robe, O))
    out.append('<g clip-path="url(#lrobe)">')
    for d in ("M18 58 C-2 74 -28 90 -60 100", "M32 64 C12 82 -10 96 -34 108", "M48 76 C32 90 16 102 0 110"):
        out.append('<path d="%s" fill="none" stroke="#0f4a44" stroke-width="3.2" stroke-linecap="round"/>' % d)
        out.append('<path d="%s" fill="none" stroke="#c9f7e2" stroke-width="2" stroke-linecap="round" opacity=".85" transform="translate(-2.5 -3.2)"/>' % d)
    out.append("</g>")
    # ---- neck, and the fold of the robe across it
    out.append('<path d="M-38 28 C-36 42 -40 54 -48 64 L24 62 C14 52 12 40 14 28Z" fill="url(#vg3)" %s/>' % O)
    out.append('<path d="M-62 78 C-46 56 -2 46 44 60 L44 74 C6 58 -30 64 -53 87Z" fill="url(#vlight)" %s/>' % O)
    # wing feathers hanging from the raised arm over the robe
    for i, (x, y) in enumerate(((40, 98), (46, 84), (53, 71))):
        out.append('<path d="M%s %s C%s %s %s %s %s %s C%s %s %s %s %s %sZ" fill="url(#vg)" %s/>' % (
            x + 14, y - 12, x + 4, y - 12, x - 6, y - 4, x - 12, y + 8, x - 2, y + 6, x + 8, y + 4, x + 16, y - 2, I))
    # ---- wattle
    out.append('<path d="M-44 22 C-53 32 -52 49 -43 54 C-34 50 -33 36 -37 22Z" fill="url(#vg2)" %s/>' % I)
    # ---- hair gathered at the back, behind the head line
    out.append('<path d="%s" fill="url(#vg3)" %s/>' % (hair, O))
    out.append('<g clip-path="url(#lhair)">')
    for d in ("M10 -24 C24 -14 26 4 20 18 C16 28 14 34 12 42", "M4 -12 C14 -4 16 8 12 20"):
        out.append('<path d="%s" fill="none" stroke="#9fe6cb" stroke-width="2.2" stroke-linecap="round" opacity=".9"/>' % d)
    out.append("</g>")
    # ---- head
    out.append('<path d="%s" fill="url(#vg)" %s/>' % (head_face, O))
    out.append('<g clip-path="url(#lhead)">')
    out.append('<path d="M-50 26 C-34 40 -10 40 2 28 L12 50 L-50 50Z" fill="#145c53" opacity=".32"/>')
    out.append('<path d="M-44 -14 C-40 -26 -28 -34 -14 -36 C-26 -30 -36 -22 -40 -12Z" fill="#f2fff9" opacity=".8"/>')
    out.append("</g>")
    # ---- beak
    out.append('<path d="M-47 14 C-55 14 -62 15 -68 18 C-62 24 -54 26 -45 23Z" fill="#2a8f79" %s/>' % I)
    out.append('<path d="M-45 -7 C-58 -10 -71 -1 -77 15 C-68 11 -58 12 -47 14Z" fill="url(#vlight)" %s/>' % O)
    out.append('<ellipse cx="-55" cy="4" rx="3" ry="1.6" fill="#145c53" transform="rotate(-12 -55 4)"/>')
    # ---- eye
    out.append('<path d="M-40 -3 C-35 -12 -21 -12 -16 -2 C-21 5 -35 5 -40 -3Z" fill="#f2fff9" %s/>' % I)
    out.append('<circle cx="-29" cy="-3.5" r="5.4" fill="#0f4a44"/>')
    out.append('<circle cx="-30.8" cy="-5.4" r="1.8" fill="#fff"/>')
    out.append('<path d="M-43 -8 C-35 -17 -21 -16 -13 -8" fill="none" %s/>' % I)
    # ---- diadem
    out.append('<path d="M-52 -18 C-40 -46 6 -52 32 -14 L27 -2 C8 -32 -32 -30 -47 -6Z" fill="url(#vlight)" %s/>' % O)
    for x, y, rot in ((-36, -24, -38), (-22, -31, -18), (-6, -33, 2), (9, -28, 24), (20, -19, 44)):
        out.append('<path d="M-3.4 4 L-3.4 -1 A3.4 3.4 0 0 1 3.4 -1 L3.4 4Z" fill="#145c53" stroke="%s" stroke-width="1.2" transform="translate(%s %s) rotate(%s)"/>' % (INK, x, y, rot))
    write("liberty", svg(defs, "\n".join(out)))


if __name__ == "__main__":
    bell()
    rocket()
    uncle()
    liberty()
    print("wrote 4 svg")
