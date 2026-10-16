#!/usr/bin/env python3
"""Composes App Store screenshots (T-02) from the AppStoreScreenshotTests captures.

Usage: Scripts/app-store-screenshots.py <shots dir> <out dir> [--style apple|caramel|cocoa|callout ...] [--lang en hu de]

Input files are named <lang>-<n>-<screen>.png (1178 × 2556, iPhone 15). Output is 1320 × 2868 (iPhone 6.9")
PNG per style, language and screen, with a clean status bar (9:41, full battery), a drawn device frame and the
caption in SF Pro.
"""
import argparse
import os
import re

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1320, 2868
SF = "/System/Library/Fonts/SFNS.ttf"

CAPTIONS = {
    "en": {
        "inventory": ("Know what's *at home*", "Photos, amounts and expiry dates in one place"),
        "expiry": ("Use it *before it expires*", "What runs out first is always on top"),
        "shopping": ("Shop with *one list*", "Tick it off and it goes into your inventory"),
        "detail": ("Know what *you paid*", "A price trend for every product"),
        "family": ("Share it with *your family*", "Everyone sees the same, through iCloud"),
    },
    "hu": {
        "inventory": ("Tudd, mi van *otthon*", "Fotó, mennyiség és lejárat egy helyen"),
        "expiry": ("Használd fel, *mielőtt lejár*", "Ami előbb lejár, az mindig felül van"),
        "shopping": ("*Egy lista* a boltba", "Kipipálod, és már a készletben is van"),
        "detail": ("Látod, *mennyit fizettél*", "Ártrend minden termékhez"),
        "family": ("Oszd meg *a családdal*", "Mindenki ugyanazt látja, iCloudon át"),
    },
    "de": {
        "inventory": ("Wissen, was *zu Hause* ist", "Fotos, Mengen und Ablaufdaten an einem Ort"),
        "expiry": ("Verbrauchen, *bevor es abläuft*", "Was zuerst abläuft, steht immer oben"),
        "shopping": ("*Eine Liste* für den Einkauf", "Abhaken, und es ist im Vorrat"),
        "detail": ("Sehen, *was du gezahlt hast*", "Preisverlauf für jedes Produkt"),
        "family": ("Mit der *Familie* teilen", "Alle sehen dasselbe, über iCloud"),
    },
}

# Card to lift out for the "callout" style: the n-th white card down the screen (cards are white on the grouped
# background); "largest" is the tallest card, which on the product detail is the price trend.
CALLOUT = {"inventory": 2, "expiry": 1, "shopping": 0, "detail": "largest", "family": "largest"}


def cards(shot):
    """White card rectangles (x0, y0, x1, y1) found down the column at x = 60, above the tab bar."""
    rgb = shot.convert("RGB")
    found, start = [], None
    for y in range(170, rgb.height - 300):
        white = rgb.getpixel((60, y)) == (255, 255, 255)
        if white and start is None:
            start = y
        elif not white and start is not None:
            if y - start > 80:
                found.append((start, y))
            start = None
    if start is not None and rgb.height - 300 - start > 80:
        found.append((start, rgb.height - 300))
    rects = []
    for y0, y1 in found:
        mid = (y0 + y1) // 2
        x0 = next(x for x in range(rgb.width) if rgb.getpixel((x, mid)) == (255, 255, 255))
        x1 = next(x for x in range(rgb.width - 1, 0, -1) if rgb.getpixel((x, mid)) == (255, 255, 255))
        rects.append((x0, y0 - 4, x1 + 1, y1 + 4))
    return rects


STYLES = {
    "apple": dict(bg=("#f5f5f7", "#ffffff"), title="#1d1d1f", accent="#1d1d1f", sub="#6e6e73", frame="#1d1d1f",
                  edge="#4a4a4f", glow=None),
    "caramel": dict(bg=("#cba87c", "#96714a"), title="#ffffff", accent="#ffffff", sub="#f7ecde", frame="#1b1714",
                    edge="#5c4a39", glow=None),
    "cocoa": dict(bg=("#3a2e25", "#221a14"), title="#ffffff", accent="#e3b98a", sub="#cdbfaf", frame="#0f0d0b",
                  edge="#8f6e47", glow="#b8956a"),
    "callout": dict(bg=("#f3eee8", "#ffffff"), title="#1f1a14", accent="#8f6e47", sub="#6b6258", frame="#1d1d1f",
                    edge="#4a4a4f", glow=None),
}


def font(size, weight="Bold"):
    f = ImageFont.truetype(SF, size)
    f.set_variation_by_name(weight)
    return f


def hex_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def gradient(size, top, bottom):
    w, h = size
    a, b = hex_rgb(top), hex_rgb(bottom)
    column = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(h - 1, 1)
        column.putpixel((0, y), tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)))
    return column.resize((w, h))


def clean_status_bar(shot):
    """Paints over the captured status bar and draws 9:41 with full signal, Wi-Fi and battery."""
    shot = shot.convert("RGB")
    bg = shot.getpixel((30, 150))
    d = ImageDraw.Draw(shot)
    d.rectangle((0, 0, shot.width, 156), fill=bg)
    luminance = sum(bg) / 3
    ink = (0, 0, 0) if luminance > 128 else (255, 255, 255)
    d.text((168, 82), "9:41", font=font(52, "Semibold"), fill=ink, anchor="mm")
    # signal: four bars
    x, base = 868, 100
    for i, h in enumerate((14, 20, 27, 34)):
        d.rounded_rectangle((x + i * 15, base - h, x + i * 15 + 10, base), radius=3, fill=ink)
    # wifi: three arcs and a dot
    cx, cy = 978, 104
    for r in (40, 27, 14):
        d.arc((cx - r, cy - r, cx + r, cy + r), start=225, end=315, fill=ink, width=8)
    d.ellipse((cx - 6, cy - 12, cx + 6, cy), fill=ink)
    # battery
    bx, by = 1030, 66
    d.rounded_rectangle((bx, by, bx + 76, by + 36), radius=11, outline=ink, width=4)
    d.rounded_rectangle((bx + 7, by + 7, bx + 69, by + 29), radius=6, fill=ink)
    d.rounded_rectangle((bx + 80, by + 12, bx + 86, by + 24), radius=3, fill=ink)
    return shot


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def phone(shot, screen_width, style):
    """The screenshot in a drawn iPhone frame with a Dynamic Island. Returns an RGBA image."""
    scale = screen_width / shot.width
    screen = shot.resize((screen_width, round(shot.height * scale)), Image.LANCZOS)
    bezel = round(30 * scale / 0.88)
    radius = round(166 * scale)
    w, h = screen.width + 2 * bezel, screen.height + 2 * bezel
    body = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=radius + bezel, fill=style["frame"])
    d.rounded_rectangle((3, 3, w - 4, h - 4), radius=radius + bezel - 3, outline=style["edge"], width=3)
    body.paste(screen, (bezel, bezel), rounded_mask(screen.size, radius))
    island_w, island_h = round(372 * scale), round(110 * scale)
    ix, iy = (w - island_w) // 2, bezel + round(33 * scale)
    d.rounded_rectangle((ix, iy, ix + island_w, iy + island_h), radius=island_h // 2, fill="#000000")
    return body


def shadow(size, radius, blur, opacity, color="#000000"):
    layer = Image.new("RGBA", (size[0] + blur * 4, size[1] + blur * 4), (0, 0, 0, 0))
    rgb = hex_rgb(color)
    ImageDraw.Draw(layer).rounded_rectangle((blur * 2, blur * 2, blur * 2 + size[0], blur * 2 + size[1]),
                                            radius=radius, fill=rgb + (round(255 * opacity),))
    return layer.filter(ImageFilter.GaussianBlur(blur))


def wrap(draw, text, fnt, width):
    words, lines, line = text.split(), [], ""
    for word in words:
        test = (line + " " + word).strip()
        if draw.textlength(test.replace("*", ""), font=fnt) <= width:
            line = test
        else:
            if line:
                lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def draw_rich_line(draw, center_x, y, line, fnt, color, accent):
    """A centred line where *marked* words use the accent colour."""
    plain = line.replace("*", "")
    x = center_x - draw.textlength(plain, font=fnt) / 2
    accent_on = False
    for part in re.split(r"(\*)", line):
        if part == "*":
            accent_on = not accent_on
            continue
        if not part:
            continue
        draw.text((x, y), part, font=fnt, fill=accent if accent_on else color)
        x += draw.textlength(part, font=fnt)


def caption(canvas, title, subtitle, style, top=190):
    d = ImageDraw.Draw(canvas)
    title_font, sub_font = font(118, "Bold"), font(52, "Medium")
    # carry an open accent mark across wrapped lines
    y = top
    open_mark = False
    for line in wrap(d, title, title_font, 1140):
        if open_mark:
            line = "*" + line
        open_mark = line.count("*") % 2 == 1
        if open_mark:
            line += "*"
        draw_rich_line(d, W / 2, y, line, title_font, style["title"], style["accent"])
        y += 134
    y += 22
    for line in wrap(d, subtitle, sub_font, 1080):
        draw_rich_line(d, W / 2, y, line, sub_font, style["sub"], style["sub"])
        y += 66
    return y


def compose(shot_path, lang, screen, style_name):
    style = STYLES[style_name]
    title, subtitle = CAPTIONS[lang][screen]
    shot = clean_status_bar(Image.open(shot_path))
    canvas = gradient((W, H), *style["bg"]).convert("RGBA")
    if style_name == "cocoa":
        title_subtitle_bottom = caption(canvas, title, subtitle, style)
    else:
        title_subtitle_bottom = caption(canvas, title, subtitle, {**style, "accent": style["accent"]})
    screen_width = 1010 if style_name != "callout" else 900
    device = phone(shot, screen_width, style)
    x = (W - device.width) // 2
    y = max(title_subtitle_bottom + 70, 660)
    if style["glow"]:
        glow = shadow(device.size, 220, 120, 0.55, style["glow"])
        canvas.alpha_composite(glow, (x - 240, y - 200))
    drop = shadow(device.size, 200, 60, 0.28)
    canvas.alpha_composite(drop, (x - 120, y - 80))
    canvas.alpha_composite(device, (x, y))
    if style_name == "callout":
        found = cards(shot)
        pick = CALLOUT[screen]
        x0, y0, x1, y1 = max(found, key=lambda r: r[3] - r[1]) if pick == "largest" else found[pick]
        card = shot.crop((x0, y0, x1, y1))
        zoom = 1200 / card.width
        card = card.resize((round(card.width * zoom), round(card.height * zoom)), Image.LANCZOS)
        radius = 44
        cx = (W - card.width) // 2
        scale = screen_width / shot.width
        bezel = round(30 * scale / 0.88)
        cy = round(y + bezel + y0 * scale - (card.height - (y1 - y0) * scale) / 2)
        canvas.alpha_composite(shadow(card.size, radius, 50, 0.32), (cx - 100, cy - 70))
        framed = Image.new("RGBA", card.size, (0, 0, 0, 0))
        framed.paste(card, (0, 0), rounded_mask(card.size, radius))
        canvas.alpha_composite(framed, (cx, cy))
    return canvas.convert("RGB")


# ---------------------------------------------------------------------------------------------------------------
# Panorama layouts: the five frames are cut from one 6600 px wide canvas, so a tilted phone or a wave can run
# across the boundary between two frames.

PANORAMAS = {
    # background per frame (top, bottom), shared wave colour, caption colours
    "cream": dict(frames=[("#f4ece1", "#ead9c3")] * 5, continuous=("#f6efe5", "#e2cdb0"), wave="#fbf7f1",
                  title="#2b2118", accent="#a9794a", sub="#6b5a48", frame="#1d1d1f", edge="#4a4a4f", glow=None),
    "pastel": dict(frames=[("#f3e7d7", "#ead8c0"), ("#dfe8d6", "#cfdcc3"), ("#f6e0d0", "#eccdb7"),
                           ("#dde8f1", "#cbdbe8"), ("#f5edc9", "#ece0b0"), ("#ece2ef", "#ddd0e3"),
                           ("#d9ebe4", "#c6dfd5")], continuous=None, wave=None,
                   title="#22201c", accent="#a9794a", sub="#5e574e", frame="#1d1d1f", edge="#4a4a4f", glow=None),
    "cocoa": dict(frames=[("#3a2e25", "#221a14")] * 5, continuous=("#3d3027", "#1f1812"), wave="#4a3a2e",
                  title="#ffffff", accent="#e3b98a", sub="#cdbfaf", frame="#0f0d0b", edge="#8f6e47", glow="#b8956a"),
}


PANORAMAS["bold"] = dict(frames=[("#2b211a", "#1e1712"), ("#c8975f", "#b9874f"), ("#fff7ec", "#f6ead9"),
                                  ("#6f8f6a", "#5f7f5a"), ("#f2e3cf", "#e8d4b8")],
                          continuous=None, wave=None, title="#ffffff", accent="#ffffff", sub="#ffffff",
                          frame="#1d1d1f", edge="#4a4a4f", glow=None,
                          ink=["#ffffff", "#ffffff", "#9a6b3c", "#ffffff", "#2b211a"])

# Short headlines for the giant type (lowercase in English and Hungarian; German keeps its capital nouns) and
# the keyword chips under them.
HEADLINES = {
    "en": {"inventory": "know what's at home", "expiry": "use it before it expires",
           "detail": "see what you paid", "shopping": "one list for the shop",
           "family": "share it with your family"},
    "hu": {"inventory": "tudd, mi van otthon", "expiry": "használd fel, mielőtt lejár",
           "detail": "lásd, mennyit fizettél", "shopping": "egy lista a boltba",
           "family": "oszd meg a családdal"},
    "de": {"inventory": "Wissen, was da ist", "expiry": "Verbrauchen, bevor es abläuft",
           "detail": "Sehen, was du zahlst", "shopping": "Eine Liste zum Einkaufen",
           "family": "Mit der Familie teilen"},
}
CHIPS = {
    "en": {"inventory": ["fridge", "pantry", "photos"], "expiry": ["expiry", "reminders", "no waste"],
           "detail": ["price trend", "stores"], "shopping": ["tick off", "shared", "stores"],
           "family": ["iCloud", "members", "together"]},
    "hu": {"inventory": ["hűtő", "kamra", "fotók"], "expiry": ["lejárat", "emlékeztető", "nincs pazarlás"],
           "detail": ["ártrend", "boltok"], "shopping": ["kipipálás", "közös", "boltok"],
           "family": ["iCloud", "tagok", "együtt"]},
    "de": {"inventory": ["Kühlschrank", "Vorrat", "Fotos"], "expiry": ["Ablaufdatum", "Erinnerung", "kein Abfall"],
           "detail": ["Preisverlauf", "Geschäfte"], "shopping": ["Abhaken", "Gemeinsam", "Geschäfte"],
           "family": ["iCloud", "Mitglieder", "zusammen"]},
}


def tracked(draw, xy, text, fnt, fill, tracking):
    """Draws text letter by letter with `tracking` px between letters (negative tightens); returns the width."""
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=fnt, fill=fill, anchor="ls")
        x += draw.textlength(ch, font=fnt) + tracking
    return x - xy[0] - tracking


def tracked_length(draw, text, fnt, tracking):
    return sum(draw.textlength(ch, font=fnt) for ch in text) + tracking * (len(text) - 1)


def giant_caption(canvas, frame_x, top, text, color, max_width=1160, max_lines=3):
    """Huge, tight, centred headline that fills the frame width: the font shrinks until every line fits."""
    d = ImageDraw.Draw(canvas)
    size = 230
    while size > 110:
        fnt = font(size, "Black")
        tracking = -size * 0.035
        words, lines, line = text.split(), [], ""
        for word in words:
            test = (line + " " + word).strip()
            if tracked_length(d, test, fnt, tracking) <= max_width:
                line = test
            else:
                if line:
                    lines.append(line)
                line = word
        lines.append(line)
        if len(lines) <= max_lines and all(tracked_length(d, l, fnt, tracking) <= max_width for l in lines):
            break
        size -= 6
    ascent, _ = fnt.getmetrics()
    baseline = top + ascent * 0.92
    for line in lines:
        width = tracked_length(d, line, fnt, tracking)
        tracked(d, (frame_x + (W - width) / 2, baseline), line, fnt, color, tracking)
        baseline += size * 0.9
    return baseline


def chips(canvas, frame_x, y, words):
    """White pill labels with a solid offset shadow, centred in at most two rows (the font shrinks to fit)."""
    d = ImageDraw.Draw(canvas)
    for size in range(100, 60, -6):
        fnt = font(size, "Heavy")
        pad_x, height, gap = round(size * 0.56), round(size * 1.6), 28
        rows, row, row_w = [], [], 0
        for word in words:
            width = d.textlength(word, font=fnt) + pad_x * 2
            if row and row_w + gap + width > 1200:
                rows.append(row); row, row_w = [], 0
            row.append((word, width)); row_w += (gap if row_w else 0) + width
        rows.append(row)
        if len(rows) <= 2:
            break
    for r in rows:
        total = sum(w for _, w in r) + gap * (len(r) - 1)
        x = frame_x + (W - total) / 2
        for word, width in r:
            d.rounded_rectangle((x + 12, y + 14, x + width + 12, y + height + 14), radius=height / 2, fill="#1b1714")
            d.rounded_rectangle((x, y, x + width, y + height), radius=height / 2, fill="#ffffff",
                                outline="#1b1714", width=6)
            d.text((x + width / 2, y + height / 2 + 4), word, font=fnt, fill="#1b1714", anchor="mm")
            x += width + gap
        y += height + gap + 8


def solve(matrix, vector):
    """Gaussian elimination for the 8 × 8 perspective system (no numpy on the build Mac)."""
    n = len(vector)
    a = [row[:] + [vector[i]] for i, row in enumerate(matrix)]
    for col in range(n):
        pivot = max(range(col, n), key=lambda r: abs(a[r][col]))
        a[col], a[pivot] = a[pivot], a[col]
        for r in range(n):
            if r != col:
                f = a[r][col] / a[col][col]
                a[r] = [x - f * y for x, y in zip(a[r], a[col])]
    return [a[i][n] / a[i][i] for i in range(n)]


def warp(image, quad, size):
    """Maps `image` onto the quadrilateral `quad` (top-left, top-right, bottom-right, bottom-left) in a canvas of
    `size`. PIL's PERSPECTIVE takes the inverse map, from output to input coordinates."""
    w, h = image.size
    src = [(0, 0), (w, 0), (w, h), (0, h)]
    rows, rhs = [], []
    for (x, y), (u, v) in zip(quad, src):
        rows.append([x, y, 1, 0, 0, 0, -u * x, -u * y]); rhs.append(u)
        rows.append([0, 0, 0, x, y, 1, -v * x, -v * y]); rhs.append(v)
    coeffs = solve(rows, rhs)
    return image.transform(size, Image.PERSPECTIVE, coeffs, Image.BICUBIC)


def tilted_quad(cx, cy, w, h, angle, squeeze):
    """A phone of w × h centred at (cx, cy), rotated by `angle` degrees, with its top edge narrowed by
    `squeeze` (0.9 = 10% narrower) for a lying-down perspective."""
    import math
    half_top, half_bottom, half_h = w * squeeze / 2, w / 2, h / 2
    points = [(-half_top, -half_h), (half_top, -half_h), (half_bottom, half_h), (-half_bottom, half_h)]
    a = math.radians(angle)
    return [(cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)) for x, y in points]


def scribble(draw, x0, x1, y, color, width=11):
    """A loose, hand-drawn swoosh under a word, starting at its first letter and running a little past its last.
    `y` is the top of the swoosh; it dips by `sag` in the middle and rises slightly to the right."""
    def stroke(a, b, top, sag, rise, w):
        points = []
        for i in range(41):
            t = i / 40
            points.append((a + (b - a) * t, top + sag * 4 * t * (1 - t) - rise * t))
        draw.line(points, fill=color, width=w, joint="curve")
        for px, py in (points[0], points[-1]):
            draw.ellipse((px - w / 2, py - w / 2, px + w / 2, py + w / 2), fill=color)
    span = x1 - x0
    stroke(x0 + 2, x1 + 6, y, 14, 10, width)
    stroke(x0 + span * 0.22, x1 - span * 0.02, y + 15, 8, 4, width - 4)


def left_caption(canvas, x, top, title, subtitle, style, max_width=1120):
    """Left-aligned caption; the *marked* words get the accent colour and a scribbled underline drawn below the
    descenders, so it never touches the letters."""
    d = ImageDraw.Draw(canvas)
    title_font, sub_font = font(128, "Heavy"), font(54, "Medium")
    ascent, descent = title_font.getmetrics()
    baseline = top + ascent
    open_mark = False
    for line in wrap(d, title, title_font, max_width):
        if open_mark:
            line = "*" + line
        open_mark = line.count("*") % 2 == 1
        if open_mark:
            line += "*"
        cursor = x
        on = False
        underlined = False
        for part in re.split(r"(\*)", line):
            if part == "*":
                on = not on
                continue
            if not part:
                continue
            width = d.textlength(part, font=title_font)
            d.text((cursor, baseline), part, font=title_font, anchor="ls",
                   fill=style["accent"] if on else style["title"])
            if on and part.strip():
                lead = len(part) - len(part.lstrip())
                trail = len(part) - len(part.rstrip())
                start = cursor + d.textlength(part[:lead], font=title_font)
                end = cursor + width - (d.textlength(part[len(part) - trail:], font=title_font) if trail else 0)
                scribble(d, start, end, baseline + descent - 2, style["accent"])
                underlined = True
            cursor += width
        baseline += 176 if underlined else 150
    y = baseline - ascent + 34
    for line in wrap(d, subtitle, sub_font, max_width - 40):
        d.text((x, y), line, font=sub_font, fill=style["sub"])
        y += 68
    return y


def lifted_card(shot, pick, width, angle=0):
    """A card cut from the screenshot, scaled to `width`, with rounded corners and an optional tilt."""
    found = cards(shot)
    x0, y0, x1, y1 = max(found, key=lambda r: r[3] - r[1]) if pick == "largest" else found[pick]
    card = shot.crop((x0, y0, x1, y1))
    zoom = width / card.width
    card = card.resize((round(card.width * zoom), round(card.height * zoom)), Image.LANCZOS).convert("RGBA")
    framed = Image.new("RGBA", card.size, (0, 0, 0, 0))
    framed.paste(card, (0, 0), rounded_mask(card.size, 44))
    if angle:
        framed = framed.rotate(angle, resample=Image.BICUBIC, expand=True)
    return framed


def place_with_shadow(canvas, layer, xy, blur=50, opacity=0.3):
    alpha = layer.split()[3]
    shade = Image.new("RGBA", layer.size, (0, 0, 0, 255))
    shade.putalpha(alpha.point(lambda a: round(a * opacity)))
    pad = blur * 3
    padded = Image.new("RGBA", (layer.width + pad * 2, layer.height + pad * 2), (0, 0, 0, 0))
    padded.alpha_composite(shade, (pad, pad))
    padded = padded.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(padded, (round(xy[0]) - pad + 20, round(xy[1]) - pad + 40))
    canvas.alpha_composite(layer, (round(xy[0]), round(xy[1])))


SCREENS = ["inventory", "expiry", "detail", "shopping", "family"]


def panorama(shots_dir, lang, name, text="giant"):
    """Five frames cut from one canvas. `text` is "scribble" (left caption with a swoosh), "giant" (huge
    centred headline) or "chips" (giant headline plus keyword pills near the bottom)."""
    style = PANORAMAS[name]
    count = len(SCREENS)
    tones = (style["frames"] * count)[:count]
    total = W * count
    dy = 0 if text == "scribble" else 260
    canvas = Image.new("RGBA", (total, H))
    if style["continuous"]:
        canvas.paste(gradient((total, H), *style["continuous"]), (0, 0))
    else:
        for i, (top, bottom) in enumerate(tones):
            canvas.paste(gradient((W, H), top, bottom), (i * W, 0))
    if style["wave"]:
        import math
        d = ImageDraw.Draw(canvas)
        points = [(x, 2380 + math.sin(x / 900) * 120 + math.sin(x / 310) * 30) for x in range(0, total + 20, 20)]
        d.polygon(points + [(total, H), (0, H)], fill=style["wave"])

    shots = {screen: clean_status_bar(Image.open(os.path.join(shots_dir, f"{lang}-{i + 1}-{screen}.png")))
             for i, screen in enumerate(SCREENS)}

    # Frames 1–2: one big tilted phone across the boundary, the expiring card lifted out on frame 2.
    big = phone(shots["inventory"], 1180, style)
    place_with_shadow(canvas, warp(big, tilted_quad(W + 10, 2170 + dy, big.width, big.height, -16, 0.9),
                                   (total, H)), (0, 0), blur=70, opacity=0.32)
    place_with_shadow(canvas, lifted_card(shots["expiry"], 1, 1050, angle=4), (W + 190, 1330 + dy))

    # Frame 3: straight phone, the price trend lifted out.
    mid = phone(shots["detail"], 960, style)
    place_with_shadow(canvas, mid, (2 * W + (W - mid.width) // 2, 860 + dy), blur=60, opacity=0.25)
    place_with_shadow(canvas, lifted_card(shots["detail"], "largest", 1180), (2 * W + 70, 1500 + dy))

    # Frame 4: straight shopping phone, Milk lifted out.
    shop = phone(shots["shopping"], 960, style)
    place_with_shadow(canvas, shop, (3 * W + (W - shop.width) // 2, 860 + dy), blur=60, opacity=0.25)
    place_with_shadow(canvas, lifted_card(shots["shopping"], 0, 1150, angle=-3), (3 * W + 70, 1250 + dy))

    # Frame 5: the household's settings, the members card lifted out.
    fam = phone(shots["family"], 960, style)
    place_with_shadow(canvas, fam, (4 * W + (W - fam.width) // 2, 860 + dy), blur=60, opacity=0.25)
    place_with_shadow(canvas, lifted_card(shots["family"], "largest", 1180, angle=2), (4 * W + 60, 1240 + dy))

    for i, screen in enumerate(SCREENS):
        if text == "scribble":
            title, subtitle = CAPTIONS[lang].get(screen, (HEADLINES[lang][screen], ""))
            left_caption(canvas, i * W + 96, 200, title, subtitle, style)
            continue
        ink = style.get("ink", [style["title"]] * count)[i % len(style.get("ink", [style["title"]]))]
        giant_caption(canvas, i * W, 170, HEADLINES[lang][screen], ink)
        if text == "chips":
            chips(canvas, i * W, 2400, CHIPS[lang][screen])
    return [canvas.crop((i * W, 0, (i + 1) * W, H)).convert("RGB") for i in range(count)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("shots")
    parser.add_argument("out")
    parser.add_argument("--style", nargs="+", default=list(STYLES))
    parser.add_argument("--lang", nargs="+", default=list(CAPTIONS))
    parser.add_argument("--panorama", nargs="*", default=None, help="panorama variants instead of single styles")
    parser.add_argument("--text", nargs="+", default=["giant"], help="scribble, giant or chips")
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)
    if args.panorama is not None:
        orders = [f"{i + 1}-{screen}" for i, screen in enumerate(SCREENS)]
        for variant in args.panorama or list(PANORAMAS):
            for text in args.text:
                for lang in args.lang:
                    for order, frame in zip(orders, panorama(args.shots, lang, variant, text)):
                        suffix = f"-{text}"
                        path = os.path.join(args.out, f"pano-{variant}{suffix}-{lang}-{order}.png")
                        frame.save(path, optimize=True)
                        print(path)
        return
    for name in sorted(os.listdir(args.shots)):
        m = re.match(r"(\w\w)-(\d)-(\w+)\.png$", name)
        if not m or m.group(1) not in args.lang:
            continue
        lang, order, screen = m.groups()
        for style in args.style:
            image = compose(os.path.join(args.shots, name), lang, screen, style)
            path = os.path.join(args.out, f"{style}-{lang}-{order}-{screen}.png")
            image.save(path, optimize=True)
            print(path)


if __name__ == "__main__":
    main()
