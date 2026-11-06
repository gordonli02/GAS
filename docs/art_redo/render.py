"""Turns the SVG drawings in docs/art_redo/ into PNG with headless Chrome (filters, blend modes
and patterns render as in a browser; the engine's own SVG reader does not do those).

    python docs/art_redo/render.py <folder> [name ...]     # every *.svg in the folder, or the named ones

Each <name>.svg (viewBox -120 -120 240 240, as the game's symbols) becomes <name>.png, 1024 px,
transparent. Nothing here is read by the game.
"""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CHROME = os.environ.get("CHROME", r"C:\Program Files\Google\Chrome\Application\chrome.exe")


def render(svg_path, png_path, width=1024, height=1024):
    with open(svg_path, encoding="utf-8") as f:
        svg = f.read()
    html = ('<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;padding:0;background:transparent;overflow:hidden}'
            'svg{display:block;width:%dpx;height:%dpx}</style></head><body>%s</body></html>' % (width, height, svg))
    # Chrome may still hold its profile for a moment after it exits: leave what cannot be removed.
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
        page = os.path.join(tmp, "page.html")
        with open(page, "w", encoding="utf-8") as f:
            f.write(html)
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                        "--default-background-color=00000000", "--window-size=%d,%d" % (width, height),
                        "--user-data-dir=" + os.path.join(tmp, "profile"),
                        "--screenshot=" + png_path, "file:///" + page.replace("\\", "/")],
                       check=True, timeout=120, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    folder = os.path.join(HERE, sys.argv[1]) if not os.path.isabs(sys.argv[1]) else sys.argv[1]
    names = sys.argv[2:] or sorted(f[:-4] for f in os.listdir(folder) if f.endswith(".svg"))
    for name in names:
        svg = os.path.join(folder, name + ".svg")
        size = (1024, 1024)
        with open(svg, encoding="utf-8") as f:
            head = f.read(400)
        if 'data-size="' in head:  # sheets say their own pixel size: data-size="1600x900"
            w, h = head.split('data-size="')[1].split('"')[0].split("x")
            size = (int(w), int(h))
        render(svg, os.path.join(folder, name + ".png"), *size)
        print("rendered", name)


if __name__ == "__main__":
    main()
