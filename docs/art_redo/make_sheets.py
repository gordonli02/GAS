"""Lays the redrawn symbols out for looking at: one sheet per style (present drawing above, the
redraw below, then the redraw at the size it prints on a ticket) and one page with all six.
This made the comparison G chose from; "present" was the code-drawn art then in the pack. The pack
has the new pictures now (tools/import_symbol_art.py), so a new run compares against those.

    python docs/art_redo/make_sheets.py      # writes docs/art_redo/<folder>/sheet.png and overview.png
"""
import json
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
ART = os.path.join(ROOT, "packs", "core", "art")
FORMS = os.path.join(ROOT, "packs", "core", "forms")
FONT = r"C:\Windows\Fonts\msyh.ttc"
FONT_BOLD = r"C:\Windows\Fonts\msyhbd.ttc"

# folder, form file, heading, what the manner is
STYLES = [
    ("1_cuphead_peckeye", "peckeye", "风格 1  三十年代橡皮管卡通", "参考：Cuphead 设定集"),
    ("2_pulltab_flock", "flock", "风格 2  真票印刷风", "参考：实体 pull-tab 票"),
    ("3_comic_catch", "catch", "风格 3  重阴影美漫", "参考：酒吧里的动物帮派"),
    ("4_vaultboy_order", "order", "风格 4  五十年代吉祥物", "参考：Fallout 奖杯图"),
    ("5_adcap_plate", "plate", "风格 5  粗线亮色卡通", "参考：AdVenture Capitalist"),
    ("6_jsr_spur", "spur", "风格 6  涂鸦赛璐璐", "参考：Jet Set Radio"),
]
BG, BAND, INK, PAPER = "#8fa3ad", "#22303a", "#ffffff", "#f4efe2"


def font(size, bold=False):
    return ImageFont.truetype(FONT_BOLD if bold else FONT, size)


def form(name):
    with open(os.path.join(FORMS, name + ".json"), encoding="utf-8") as f:
        return json.load(f)


def symbol(path, size):
    im = Image.open(path).convert("RGBA")
    return im.resize((size, size), Image.LANCZOS)


def band(draw, y, w, title, note, h=64):
    draw.rectangle([0, y, w, y + h], fill=BAND)
    draw.text((28, y + h / 2), title, font=font(30, True), fill=INK, anchor="lm")
    draw.text((w - 28, y + h / 2), note, font=font(22), fill="#c9d6dd", anchor="rm")
    return y + h


def sheet(folder, form_name, heading, ref):
    f = form(form_name)
    tiers = f["tiers"]
    big, gap, pad = 360, 30, 40
    w = pad * 2 + big * 4 + gap * 3
    h = 64 + (44 + big) * 2 + 44 + 150 + 44 + 190 + pad
    im = Image.new("RGBA", (w, h), BG)
    d = ImageDraw.Draw(im)
    y = band(d, 0, w, "%s  ·  %s" % (heading, f["name"]), ref)
    for label, src in (("现在", lambda t: os.path.join(ART, t["symbol_large"].split("/")[1])),
                       ("重绘", lambda t: os.path.join(HERE, folder, t["key"] + ".png"))):
        d.text((pad, y + 22), label, font=font(24, True), fill=BAND, anchor="lm")
        y += 44
        for i, t in enumerate(tiers):
            x = pad + i * (big + gap)
            im.alpha_composite(symbol(src(t), big), (x, y))
            if label == "重绘":
                d.text((x + big / 2, y + big + 4), "%s  %s" % (t["label"]["zh"], t["label"]["en"]),
                       font=font(20), fill=BAND, anchor="mt")
        y += big
    y += 44
    # As printed: three in a row on white, on the tier's own colour (the Pecking Order row), 48 px.
    d.text((pad, y + 22), "票面大小（48 px，三连）", font=font(24, True), fill=BAND, anchor="lm")
    y += 44
    for i, t in enumerate(tiers):
        x = pad + i * (big + gap)
        d.rounded_rectangle([x, y, x + big, y + 84], 10, fill=f["colors"]["tiles"][i])
        d.rounded_rectangle([x + 10, y + 10, x + 216, y + 74], 8, fill="#ffffff")
        small = symbol(os.path.join(HERE, folder, t["key"] + ".png"), 48)
        for j in range(3):
            im.alpha_composite(small, (x + 26 + j * 64, y + 18))
        d.text((x + 288, y + 42), "$%d" % t["prize"], font=font(30, True), fill="#111111", anchor="mm")
    y += 84 + 44
    # And once on the dark and the pale ground a winner shows it on.
    d.text((pad, y - 22), "中奖页大小（160 px）", font=font(24, True), fill=BAND, anchor="lm")
    for i, t in enumerate(tiers):
        x = pad + i * (big + gap)
        d.rounded_rectangle([x, y, x + big // 2 - 6, y + 172], 10, fill=f["colors"]["tiles"][i])
        d.rounded_rectangle([x + big // 2 + 6, y, x + big, y + 172], 10, fill=PAPER)
        mid = symbol(os.path.join(HERE, folder, t["key"] + ".png"), 160)
        im.alpha_composite(mid, (x + 7, y + 6))
        im.alpha_composite(mid, (x + big // 2 + 13, y + 6))
    im.convert("RGB").save(os.path.join(HERE, folder, "sheet.png"))
    print("wrote", folder + "/sheet.png")


def overview():
    cell, gap, pad, label_w = 250, 18, 36, 430
    w = pad * 2 + label_w + (cell + gap) * 4
    row_h = cell + gap
    h = 70 + row_h * len(STYLES) + pad
    im = Image.new("RGBA", (w, h), BG)
    d = ImageDraw.Draw(im)
    band(d, 0, w, "图案重绘：六种风格各画一张票", "docs/art_redo", h=70)
    y = 70 + gap
    for folder, form_name, heading, ref in STYLES:
        f = form(form_name)
        d.rounded_rectangle([pad, y, w - pad, y + cell], 14, fill="#a9bac2")
        d.text((pad + 24, y + cell / 2 - 44), heading, font=font(27, True), fill=BAND, anchor="lm")
        d.text((pad + 24, y + cell / 2), f["name"], font=font(34, True), fill="#101820", anchor="lm")
        d.text((pad + 24, y + cell / 2 + 44), ref, font=font(21), fill="#3c4c57", anchor="lm")
        for i, t in enumerate(f["tiers"]):
            path = os.path.join(HERE, folder, t["key"] + ".png")
            if os.path.exists(path):
                im.alpha_composite(symbol(path, cell - 16), (pad + label_w + i * (cell + gap), y + 8))
        y += row_h
    im.convert("RGB").save(os.path.join(HERE, "overview.png"))
    print("wrote overview.png")


if __name__ == "__main__":
    for s in STYLES:
        if all(os.path.exists(os.path.join(HERE, s[0], t["key"] + ".png")) for t in form(s[1])["tiers"]):
            sheet(*s)
        else:
            print("skipped", s[0], "(not all four drawn yet)")
    overview()
