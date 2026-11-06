"""Pecking Order's four symbols in the manner of a 1950s safety-manual mascot (reference folder 4):
an even black line, flat fills in a small palette, halftone dots for shade, a pale panel behind.

    python docs/art_redo/4_vaultboy_order/draw.py     # writes the four .svg here
    python docs/art_redo/render.py 4_vaultboy_order   # .svg -> .png
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))

INK = "#16181d"
SKY, GRASS, CLOUD = "#cde4f2", "#d3e7bd", "#eef6fa"
ORANGE, CREAM, WHITE = "#e8872b", "#fbf1d6", "#fdf8ea"
RED, YELLOW, BLUE = "#d9392c", "#f8cc32", "#2b5cab"
PINK, MOUTH = "#f29a8e", "#8f1f1c"
S = 2.9          # the line
S2 = 2.2         # small things: brows, ticks, feather marks
LEG = 2.5        # the line round legs and toes


class Art:
    def __init__(self):
        self.o = []
        self.defs = []
        self.n = 0

    def add(self, s):
        self.o.append(s)

    def stroke(self, w=S):
        return 'stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"' % (INK, w)

    def shape(self, d, fill, shade=True, w=S, dx=-5, dy=-6, tone="ht"):
        """A filled outline. The side away from the light (upper left) carries halftone dots."""
        self.add('<path d="%s" fill="%s"/>' % (d, fill))
        if shade:
            self.n += 1
            cid = "c%d" % self.n
            self.defs.append('<clipPath id="%s"><path d="%s"/></clipPath>' % (cid, d))
            self.add('<g clip-path="url(#%s)"><path d="%s" fill="url(#%s)"/><path d="%s" fill="%s" transform="translate(%s %s)"/></g>'
                     % (cid, d, tone, d, fill, dx, dy))
        if w:
            self.add('<path d="%s" fill="none" %s/>' % (d, self.stroke(w)))

    def flat(self, d, fill, w=S):
        self.shape(d, fill, shade=False, w=w)

    def line(self, d, w=S):
        self.add('<path d="%s" fill="none" %s/>' % (d, self.stroke(w)))

    def tube(self, d, color, width, w=S):
        for c, sw in ((INK, width + 2 * w), (color, width)):
            self.add('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"/>' % (d, c, sw))

    def clipped(self, clip_d, inner):
        self.n += 1
        cid = "c%d" % self.n
        self.defs.append('<clipPath id="%s"><path d="%s"/></clipPath>' % (cid, clip_d))
        self.add('<g clip-path="url(#%s)">%s</g>' % (cid, inner))

    def eye(self, x, y, rx=3.5, ry=5.6, look=1):
        """The mascot's eye: a black oval with a small white cut on the side it looks from."""
        cx, cy = x - look * rx * .15, y - ry * .2
        self.add('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s"/>' % (x, y, rx, ry, INK))
        self.n += 1
        self.defs.append('<clipPath id="c%d"><ellipse cx="%s" cy="%s" rx="%s" ry="%s"/></clipPath>' % (self.n, x, y, rx - .5, ry - .5))
        self.add('<path d="M%.2f %.2f L%.2f %.2f L%.2f %.2f Z" fill="#ffffff" clip-path="url(#c%d)"/>' % (
            cx + look * rx * .25, cy + ry * .15, cx - look * rx * 1.3, cy - ry * .3, cx - look * rx * .5, cy - ry * 1.1, self.n))

    def panel(self, shadow=None, clouds=()):
        """The pale slanted panel of the trophies: sky over a strip of grass, fine print dots."""
        quad = "M-93 -82 L89 -90 L97 97 L-99 101 Z"
        self.add('<path d="%s" fill="%s"/>' % (quad, SKY))
        inner = "".join('<path d="%s" fill="%s"/>' % (c, CLOUD) for c in clouds)
        inner += '<path d="M-110 57 L110 52 L110 110 L-110 110 Z" fill="%s"/>' % GRASS
        inner += '<path d="M-110 -110 H110 V110 H-110 Z" fill="url(#htl)"/>'
        if shadow:
            inner += '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="url(#htg)"/>' % shadow
        self.clipped(quad, inner)

    def svg(self):
        def dots(name, r, color, alpha):
            return ('<pattern id="%s" width="3.3" height="3.3" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">'
                    '<circle cx="1.65" cy="1.65" r="%s" fill="%s" fill-opacity="%s"/></pattern>' % (name, r, color, alpha))
        defs = dots("ht", 1.02, "#1a2440", .42) + dots("htw", .95, BLUE, .42) + dots("htl", .72, BLUE, .13) + dots("htg", 1.15, "#2f6b3a", .55)
        return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="-120 -120 240 240">\n<defs>%s%s</defs>\n%s\n</svg>\n'
                % (defs, "".join(self.defs), "\n".join(self.o)))


def cloud(x, y, k=1.0):
    """A flat cloud, about 44 wide at k = 1, its flat base at y."""
    p = [(-22, 0), (-30, 0, -30, -11, -20, -11), (-20, -20, -6, -22, -2, -14), (4, -20, 16, -18, 15, -10), (24, -11, 26, 0, 18, 0)]
    d = "M%.1f %.1f" % (x + p[0][0] * k, y + p[0][1] * k)
    for c in p[1:]:
        d += " C" + " ".join("%.1f %.1f" % (x + c[i] * k, y + c[i + 1] * k) for i in (0, 2, 4))
    return d + " Z"


def foot(a, x, y, toes, color=YELLOW, width=4.6):
    """Three toes from the ankle, drawn as one outlined tube."""
    a.tube("".join("M%s %s L%s %s" % (x, y, tx, ty) for tx, ty in toes), color, width, LEG)


def rooster():
    """The boss: chest out, a wing on his hip, a wink and a thumbs-up."""
    a = Art()
    a.panel(shadow=(2, 90, 46, 6), clouds=[cloud(-62, 44, .9)])
    # tail: three sickles, behind everything
    a.shape("M26 24 C46 6 64 -18 70 -50 C88 -28 84 6 48 36 Z", BLUE)
    a.shape("M34 30 C58 18 84 -2 98 -24 C104 2 90 28 54 42 Z", YELLOW)
    a.shape("M40 36 C64 34 90 24 106 8 C106 30 88 48 54 50 Z", BLUE)
    # legs
    a.tube("M-17 50 L-20 82", YELLOW, 4.6, LEG)
    a.tube("M19 50 L22 82", YELLOW, 4.6, LEG)
    foot(a, -20, 83, [(-38, 88), (-27, 93), (-9, 90)])
    foot(a, 22, 83, [(40, 88), (29, 93), (11, 90)])
    # thigh feathers
    a.shape("M-30 30 C-36 42 -32 54 -25 58 L-20 51 L-15 59 L-10 51 L-5 57 C-1 48 -2 38 -5 30 Z", ORANGE)
    a.shape("M7 30 C4 38 5 48 8 57 L13 51 L18 59 L23 51 L28 58 C36 52 38 40 32 30 Z", ORANGE)
    # the wing on the hip (his left, our right), behind the body edge
    a.shape("M24 -26 C42 -24 60 -8 58 6 C56 16 46 24 36 30 C30 33 25 27 29 22 C36 15 41 9 40 2 C38 -6 30 -12 20 -14 Z", ORANGE)
    # body and belly
    body = "M-30 -24 C-43 -6 -41 24 -28 38 C-18 48 22 48 32 38 C45 22 44 -8 30 -26 Z"
    belly = '<ellipse cx="1" cy="14" rx="23" ry="30" fill="%s"%%s/>' % CREAM
    a.add('<path d="%s" fill="%s"/>' % (body, ORANGE))
    a.clipped(body, belly % "" + '<path d="%s" fill="url(#ht)"/>' % body
              + '<path d="%s" fill="%s" transform="translate(-6 -6)"/>' % (body, ORANGE) + belly % ' transform="translate(-6 -6)"')
    a.line(body)
    a.line("M33 -12 C44 -6 49 3 46 13", S2)      # a fold in the wing
    # hackle: the yellow cape under the head
    a.shape("M-31 -48 C-41 -38 -43 -24 -39 -12 L-31 -22 L-24 -8 L-15 -20 L-6 -6 L4 -20 L12 -8 L20 -22 L29 -12 C33 -26 31 -40 22 -48 Z", YELLOW)
    # comb, behind the head
    a.shape("M-28 -74 C-40 -92 -28 -108 -14 -98 C-12 -113 9 -116 11 -100 C20 -109 34 -101 29 -88 C27 -81 21 -79 15 -78 L-20 -72 Z", RED)
    # head
    a.shape("M-33 -58 C-33 -78 -20 -90 -5 -90 C11 -90 23 -78 23 -62 C23 -46 13 -33 -4 -32 C-21 -31 -33 -42 -33 -58 Z", ORANGE)
    # wattle
    a.shape("M6 -35 C1 -26 5 -15 12 -18 C19 -21 18 -31 14 -37 Z", RED, dx=-3, dy=-3)
    # beak, open in a laugh; its root curves into the cheek
    mouth = "M4 -48 L42 -49 C37 -39 26 -32 9 -35 C6 -39 4 -43 4 -48 Z"
    a.flat(mouth, MOUTH, w=0)
    a.clipped(mouth, '<ellipse cx="23" cy="-35" rx="10" ry="5.5" fill="%s"/>' % PINK)
    a.line(mouth)
    a.shape("M11 -62 C23 -66 36 -60 46 -50 C36 -47 20 -47 4 -48 C3 -53 6 -59 11 -62 Z", YELLOW, dx=-2, dy=-3)
    a.shape("M8 -37 C18 -34 30 -38 41 -48 C40 -36 28 -26 11 -29 C9 -31 8 -34 8 -37 Z", YELLOW, dx=-2, dy=-3)
    a.line("M-1 -56 C-6 -51 -6 -42 -1 -36", S2)          # cheek crease
    # eyes: his right one winks
    a.line("M-23 -69 C-20 -75 -12 -75 -9 -69")
    a.eye(2, -73, 3.4, 5.6, look=1)
    a.line("M-26 -80 C-21 -85 -13 -85 -8 -81", S2)
    a.line("M-4 -84 C0 -88 6 -87 9 -83", S2)
    # thumbs-up arm (his right, our left): sleeve, thumb, fist
    a.tube("M-27 -19 L-55 5 L-68 -14", ORANGE, 17)
    a.shape("M-73 -24 C-74 -34 -72 -50 -66 -51 C-60 -52 -59 -40 -60 -26 Z", ORANGE, dx=-2, dy=-2)
    a.shape("M-82 -22 C-84 -30 -76 -34 -68 -32 C-58 -30 -54 -24 -56 -14 C-58 -4 -68 -2 -76 -6 C-82 -10 -82 -16 -82 -22 Z", ORANGE, dx=-3, dy=-3)
    a.line("M-78 -24 C-73 -25 -68 -23 -64 -20 M-80 -17 C-74 -18 -69 -16 -65 -13 M-78 -10 C-74 -11 -70 -10 -67 -8", S2)
    # ticks of pride beside the thumb
    a.line("M-82 -56 L-89 -64 M-67 -60 L-67 -71 M-52 -56 L-46 -64", S2)
    return a.svg()


def hen():
    """The lady of the roost: on her nest, an egg beside her, waving hello."""
    a = Art()
    a.panel(shadow=(0, 93, 80, 6), clouds=[cloud(-66, -2, .8)])
    # tail, behind
    a.shape("M46 6 C58 -8 74 -18 90 -20 C88 -4 78 12 58 22 Z", WHITE, tone="htw")
    a.shape("M52 16 C68 8 86 4 100 8 C94 22 80 32 60 34 Z", WHITE, tone="htw")
    a.shape("M54 28 C70 26 86 28 97 35 C88 45 74 48 58 44 Z", WHITE, tone="htw")
    # the inside of the nest
    back = "M-84 46 C-84 34 -50 28 0 28 C50 28 84 34 84 46 C84 58 50 64 0 64 C-50 64 -84 58 -84 46 Z"
    a.flat(back, YELLOW, w=0)
    a.add('<path d="%s" fill="url(#ht)"/>' % back)
    a.line(back)
    a.line("M-78 38 L-88 28 M-66 33 L-70 22 M70 33 L76 22 M80 39 L91 30", S2)       # straws standing up behind
    # body
    a.shape("M-52 34 C-62 4 -54 -26 -42 -44 L-6 -44 C26 -40 54 -12 56 28 C58 52 40 66 0 66 C-40 66 -50 52 -52 34 Z", WHITE, tone="htw", dx=-7, dy=-7)
    a.line("M-38 2 C-36 7 -31 7 -29 2 M-25 13 C-23 18 -18 18 -16 13 M-42 19 C-40 24 -35 24 -33 19", S2)      # breast feathers
    # an egg beside her
    a.shape("M-75 44 C-77 32 -69 23 -61 25 C-53 27 -48 40 -50 50 C-52 61 -73 58 -75 44 Z", CREAM, dx=-3, dy=-3)
    # scarf
    a.shape("M-40 -28 L-54 -8 L-45 -9 L-41 -15 L-36 -6 L-29 -9 Z", BLUE, dx=-2, dy=-2)
    a.shape("M-49 -41 C-38 -29 -10 -28 4 -41 L6 -30 C-8 -17 -38 -18 -52 -30 Z", BLUE, dx=-2, dy=-3)
    # comb, head, wattle
    a.shape("M-38 -80 C-45 -94 -33 -101 -27 -92 C-25 -103 -11 -103 -11 -92 C-4 -98 5 -90 -3 -80 Z", RED, dx=-2, dy=-3)
    a.shape("M-50 -58 C-50 -74 -39 -85 -24 -85 C-9 -85 2 -74 2 -58 C2 -43 -8 -33 -24 -33 C-40 -33 -50 -43 -50 -58 Z", WHITE, tone="htw")
    a.shape("M-41 -40 C-46 -32 -43 -24 -38 -26 C-33 -28 -34 -36 -36 -41 Z", RED, dx=-2, dy=-2)
    # beak with a smile
    a.shape("M-37 -54 C-47 -47 -58 -47 -64 -51 C-60 -44 -50 -41 -42 -44 C-39 -46 -37 -50 -37 -54 Z", YELLOW, shade=False)
    a.shape("M-43 -63 C-52 -64 -61 -59 -66 -52 C-58 -47 -47 -47 -37 -54 C-38 -57 -40 -60 -43 -63 Z", YELLOW, dx=2, dy=-3)
    a.line("M-33 -61 C-29 -57 -29 -51 -33 -47", S2)
    # eyes, lashes, brows
    a.eye(-35, -66, 3.2, 5.4, look=-1)
    a.eye(-20, -66, 3.6, 5.8, look=-1)
    a.line("M-16.5 -70 L-12.5 -73.5 M-16 -66 L-11.5 -67", 1.7)
    a.line("M-43 -74 C-41 -79 -36 -80 -32 -78 M-27 -80 C-23 -84 -16 -83 -12 -78", S2)
    # the near wing, raised in a wave: feathers along the under side, feather fingers
    a.shape("M4 -8 C14 -18 28 -28 37 -34 L37 -58 L55 -58 L57 -26 C57 -18 54 -12 50 -8 C53 -4 50 1 45 -1 C47 4 42 8 37 5 C37 10 31 12 26 7 C16 9 4 2 4 -8 Z", WHITE, tone="htw", dx=-4, dy=-4)
    a.shape("M37 -60 C29 -62 24 -69 27 -74 C30 -78 36 -73 39 -68 Z", WHITE, shade=False)
    a.shape("M35 -62 C29 -72 29 -86 35 -88 C40 -89 41 -82 41 -77 C41 -89 45 -97 50 -95 C55 -93 53 -84 52 -77 C56 -87 62 -89 64 -84 C66 -78 61 -67 57 -60 C52 -52 40 -54 35 -62 Z", WHITE, tone="htw", dx=-3, dy=-3)
    a.line("M16 -84 C12 -78 12 -70 16 -64 M76 -88 C81 -80 81 -70 76 -64", S2)
    # the nest
    a.shape("M-86 44 C-70 54 -40 60 0 60 C40 60 70 54 86 44 C88 72 56 96 0 96 C-56 96 -88 72 -86 44 Z", YELLOW, dx=-6, dy=-7)
    a.line("M-76 60 C-48 75 48 75 76 60", S2)
    a.line("M-64 72 C-54 78 -44 81 -32 83 M-22 87 C-8 90 8 90 20 88 M32 83 C44 81 54 77 64 71", S2)
    a.line("M-58 59 L-63 66 M-34 64 L-30 71 M-8 67 L-11 73 M18 67 L22 73 M42 64 L39 70 M62 58 L66 64", S2)
    a.line("M-84 50 L-98 42 M-83 58 L-98 61 M84 50 L98 42 M83 58 L98 61", S2)
    return a.svg()


def chick():
    """The kid: running flat out, startled, feathers flying."""
    a = Art()
    a.panel(shadow=(6, 92, 34, 5), clouds=[cloud(-52, -42, .9)])
    # speed lines and puffs of dust
    a.line("M-98 -6 L-74 -6 M-104 14 L-66 14 M-97 34 L-72 34", S2)
    a.shape("M-90 90 C-97 90 -97 81 -90 81 C-90 74 -79 74 -77 80 C-70 78 -66 86 -73 90 Z", WHITE, shade=False, w=S2)
    a.shape("M-58 92 C-62 92 -62 87 -58 86 C-57 82 -50 83 -50 87 C-46 87 -46 92 -50 92 Z", WHITE, shade=False, w=S2)
    # the far leg kicked back, the far wing thrown back
    a.tube("M-22 46 L-44 56 L-60 44", ORANGE, 4.4, LEG)
    foot(a, -60, 44, [(-74, 36), (-76, 48), (-66, 57)], ORANGE, 4.4)
    a.shape("M-26 4 C-36 -8 -50 -16 -62 -16 C-68 -15 -68 -9 -63 -8 C-69 -5 -68 2 -62 2 C-64 7 -59 11 -54 9 C-44 14 -34 14 -26 12 Z", YELLOW, dx=-3, dy=-3)
    # tail, body
    a.shape("M-36 20 L-56 14 L-50 25 L-61 32 L-40 38 Z", YELLOW, shade=False)
    a.shape("M-42 30 C-46 12 -30 -4 -10 -6 C8 -8 22 4 20 22 C18 40 0 52 -20 50 C-30 49 -38 42 -42 30 Z", YELLOW)
    # the near leg reaching forward
    a.tube("M0 46 L20 54 L25 79", ORANGE, 4.4, LEG)
    foot(a, 25, 80, [(44, 82), (38, 90), (14, 84)], ORANGE, 4.4)
    # tuft, head
    a.add('<g transform="translate(-5 4)">')
    a.shape("M10 -58 C4 -70 10 -82 17 -73 C17 -86 30 -86 28 -72 C36 -80 42 -68 33 -58 Z", YELLOW, shade=False)
    a.shape("M-11 -30 C-11 -48 3 -61 20 -61 C37 -61 51 -48 51 -30 C51 -13 37 0 20 0 C3 0 -11 -13 -11 -30 Z", YELLOW, dx=-6, dy=-7)
    # the near wing reaching forward
    # beak, open
    mouth = "M42 -20 L64 -21 C60 -12 51 -7 43 -10 C42 -13 41 -17 42 -20 Z"
    a.flat(mouth, MOUTH)
    a.shape("M43 -29 C52 -32 62 -28 68 -21 C60 -19 50 -19 42 -20 C41 -23 41 -26 43 -29 Z", ORANGE, dx=-2, dy=-2)
    a.shape("M43 -12 C50 -10 58 -14 63 -20 C61 -9 52 -3 44 -6 C43 -8 43 -10 43 -12 Z", ORANGE, shade=False)
    # eyes wide, brows up
    a.eye(25, -36, 4, 6.8, look=1)
    a.eye(39, -37, 3.4, 6.2, look=1)
    a.line("M17 -50 C20 -55 26 -55 29 -52 M34 -52 C36 -55 40 -55 42 -51", S2)
    a.add('</g>')
    # the near wing reaching forward
    a.shape("M0 16 C12 8 30 6 44 9 C49 8 53 12 50 15 C55 16 56 22 51 23 C53 27 48 30 44 28 C32 31 14 31 4 28 C-2 24 -4 20 0 16 Z", YELLOW, dx=-3, dy=-4)
    # ticks over the head
    a.line("M39 -64 L44 -76 M52 -55 L63 -64 M57 -41 L70 -45", S2)
    return a.svg()


def whole_egg():
    """The newborn: still half in the shell, the cap for a hat, taking the first step."""
    a = Art()
    a.panel(shadow=(4, 92, 40, 5), clouds=[cloud(-64, -30, .8)])
    # legs: one planted, one taking the first step
    a.tube("M-14 62 L-16 84", ORANGE, 4.4, LEG)
    foot(a, -16, 85, [(1, 88), (-6, 93), (-29, 87)], ORANGE, 4.4)
    a.tube("M14 62 L28 74", ORANGE, 4.4, LEG)
    foot(a, 28, 75, [(43, 72), (41, 82), (30, 87)], ORANGE, 4.4)
    # a wing out of the shell, waving
    a.shape("M34 -12 C38 -26 48 -38 58 -42 C63 -44 66 -39 63 -36 C68 -37 71 -31 67 -28 C70 -25 68 -20 63 -19 C56 -11 44 -6 34 -8 Z", YELLOW, dx=-2, dy=-3)
    a.line("M74 -48 L82 -54 M77 -34 L87 -34", S2)
    # the chick's head, in the shade of the cap
    a.shape("M-36 -30 C-36 -50 -20 -66 0 -66 C20 -66 36 -50 36 -30 C36 -10 20 6 0 6 C-20 6 -36 -10 -36 -30 Z", YELLOW, dx=0, dy=10)
    a.eye(-11, -33, 4, 6.6, look=-1)
    a.eye(11, -33, 4, 6.6, look=-1)
    a.line("M-17 -44 C-14 -47 -8 -47 -5 -44 M5 -45 C8 -48 14 -48 17 -45", S2)
    a.flat("M-6 -20 C-3 -11 3 -11 6 -20 Z", MOUTH)
    a.shape("M-9 -21 C-5 -28 5 -28 9 -21 C5 -17 -5 -17 -9 -21 Z", ORANGE, shade=False)
    # the cap of the shell, worn as a hat
    a.add('<g transform="translate(0 -3) rotate(-10 0 -60)">')
    a.shape("M-40 -58 C-40 -88 -22 -108 0 -108 C22 -108 40 -88 40 -58 L30 -66 L19 -54 L8 -66 L-4 -54 L-16 -66 L-28 -54 Z", CREAM, dx=-6, dy=-7)
    a.add('</g>')
    # the shell
    a.shape("M-46 -4 L-35 -15 L-23 -3 L-11 -15 L3 -1 L17 -15 L30 -5 L45 -15 C54 14 46 54 20 65 C8 70 -8 70 -20 65 C-46 54 -54 14 -46 -4 Z", CREAM, dx=-7, dy=-8)
    a.line("M-23 -3 L-18 8 L-26 17 M30 -5 L26 6 L33 15", S2)
    # bits of shell
    a.shape("M-60 -46 L-51 -52 L-53 -41 Z", CREAM, shade=False, w=S2)
    a.shape("M52 -72 L61 -70 L55 -63 Z", CREAM, shade=False, w=S2)
    return a.svg()


def write(name, text):
    with open(os.path.join(HERE, name + ".svg"), "w", encoding="utf-8") as f:
        f.write(text)


if __name__ == "__main__":
    for f in (rooster, hen, chick, whole_egg):
        write(f.__name__, f())
