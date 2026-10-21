import argparse
import hashlib
import math
from pathlib import Path
import unicodedata

from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont


UPSTREAM_URL = "https://github.com/tywr/Nordwand-Mono/releases/download/1.3.1/NordwandMono-TTF.zip"
UPSTREAM_ARCHIVE_SHA256 = "9725cfd15e21dede25c64c80aab54dcc3f27c4a127d20f13478c121aee5ae6c5"
UPSTREAM_SHA256 = "e6a0635eb33c27a73b7d84f85233e04e6942422ccd325930175ff79343647b50"
VERSION_SUFFIX = "; terminal glyphs added by Multiprompt"


def polygon(pen, points):
    pen.moveTo(points[0])
    for point in points[1:]:
        pen.lineTo(point)
    pen.closePath()


def rectangles(pen, filled, cutouts=()):
    xs = sorted({r[i] for r in [*filled, *cutouts] for i in (0, 2)})
    ys = sorted({r[i] for r in [*filled, *cutouts] for i in (1, 3)})
    edges = set()
    for x0, x1 in zip(xs, xs[1:]):
        for y0, y1 in zip(ys, ys[1:]):
            x, y = (x0 + x1) / 2, (y0 + y1) / 2
            if not any(a < x < c and b < y < d for a, b, c, d in filled):
                continue
            if any(a < x < c and b < y < d for a, b, c, d in cutouts):
                continue
            points = [(x0, y0), (x0, y1), (x1, y1), (x1, y0)]
            for a, b in zip(points, points[1:] + points[:1]):
                if (b, a) in edges:
                    edges.remove((b, a))
                else:
                    edges.add((a, b))
    while edges:
        start, current = min(edges)
        points = [start]
        edges.remove((start, current))
        previous = start
        while current != start:
            points.append(current)
            candidates = [b for a, b in edges if a == current]
            dx, dy = current[0] - previous[0], current[1] - previous[1]
            following = min(candidates, key=lambda b: math.atan2(
                dx * (b[1] - current[1]) - dy * (b[0] - current[0]),
                dx * (b[0] - current[0]) + dy * (b[1] - current[1])))
            edges.remove((current, following))
            previous, current = current, following
        polygon(pen, points)


def directions(name):
    weights = {"LIGHT": 1, "SINGLE": 1, "HEAVY": 2, "DOUBLE": 3}
    axes = {"LEFT": "L", "RIGHT": "R", "UP": "U", "DOWN": "D", "HORIZONTAL": "LR", "VERTICAL": "UD"}
    words = name.removeprefix("BOX DRAWINGS ").replace("ARC ", "").split()
    default = weights[words[0]] if words[0] in weights else None
    result = {}
    for part in " ".join(words).split(" AND "):
        tokens = part.split()
        weight = next((weights[t] for t in tokens if t in weights), default)
        for token in tokens:
            for direction in axes.get(token, ""):
                result[direction] = weight
    return result


def box(pen, codepoint, width, bottom, top, light):
    name = unicodedata.name(chr(codepoint))
    cx, cy = width / 2, (top + bottom) / 2
    if "DIAGONAL" in name:
        offset = round(light * math.hypot(width, top - bottom) / (2 * (top - bottom)))
        if codepoint in (0x2571, 0x2573):
            polygon(pen, [(0, bottom), (0, bottom + offset * (top - bottom) / width),
                          (width - offset, top), (width, top), (width, top - offset * (top - bottom) / width), (offset, bottom)])
        if codepoint in (0x2572, 0x2573):
            polygon(pen, [(0, top), (offset, top), (width, bottom + offset * (top - bottom) / width),
                          (width, bottom), (width - offset, bottom), (0, top - offset * (top - bottom) / width)])
        return
    if "DASH" in name:
        count = 2 if "DOUBLE" in name else 3 if "TRIPLE" in name else 4
        thickness = light * (2 if "HEAVY" in name else 1)
        horizontal = "HORIZONTAL" in name
        length = width if horizontal else top - bottom
        filled = []
        for i in range(count):
            start = round((i + 0.15) * length / count)
            end = round((i + 0.85) * length / count)
            filled.append((start, cy - thickness / 2, end, cy + thickness / 2) if horizontal else
                          (cx - thickness / 2, bottom + start, cx + thickness / 2, bottom + end))
        rectangles(pen, filled)
        return
    arms = directions(name)
    filled, cutouts = [], []
    opposite = {"L": "R", "R": "L", "U": "D", "D": "U"}
    for direction, weight in arms.items():
        horizontal = direction in "LR"
        perpendicular = [arms[d] for d in ("UD" if horizontal else "LR") if d in arms]
        reach = max(perpendicular, default=0) * light / 2
        if weight == 1 and perpendicular == [3, 3] and opposite[direction] not in arms:
            reach = -light / 2
        half = weight * light / 2
        if direction == "L":
            filled.append((0, cy - half, cx + reach, cy + half))
        elif direction == "R":
            filled.append((cx - reach, cy - half, width, cy + half))
        elif direction == "U":
            filled.append((cx - half, cy - reach, cx + half, top))
        else:
            filled.append((cx - half, bottom, cx + half, cy + reach))
        if weight != 3:
            continue
        through_gap = perpendicular == [1] and arms.get(opposite[direction]) == 3
        reach = light / 2 if 3 in perpendicular or through_gap else -light / 2 if perpendicular else 0
        if direction == "L":
            cutouts.append((0, cy - light / 2, cx + reach, cy + light / 2))
        elif direction == "R":
            cutouts.append((cx - reach, cy - light / 2, width, cy + light / 2))
        elif direction == "U":
            cutouts.append((cx - light / 2, cy - reach, cx + light / 2, top))
        else:
            cutouts.append((cx - light / 2, bottom, cx + light / 2, cy + reach))
    rectangles(pen, filled, cutouts)


def block(pen, codepoint, width, bottom, top):
    height = top - bottom
    if codepoint == 0x2580:
        filled = [(0, round(bottom + height / 2), width, top)]
    elif 0x2581 <= codepoint <= 0x2588:
        filled = [(0, bottom, width, round(bottom + height * (codepoint - 0x2580) / 8))]
    elif 0x2589 <= codepoint <= 0x258F:
        filled = [(0, bottom, round(width * (0x2590 - codepoint) / 8), top)]
    elif codepoint == 0x2590:
        filled = [(round(width / 2), bottom, width, top)]
    elif 0x2591 <= codepoint <= 0x2593:
        level = codepoint - 0x2590
        filled = []
        for y in range(16):
            for x in range(8):
                if ((0, 2), (3, 1))[y % 2][x % 2] < level:
                    filled.append((round(x * width / 8), round(bottom + y * height / 16),
                                   round((x + 1) * width / 8), round(bottom + (y + 1) * height / 16)))
    elif codepoint == 0x2594:
        filled = [(0, round(top - height / 8), width, top)]
    elif codepoint == 0x2595:
        filled = [(round(width * 7 / 8), bottom, width, top)]
    else:
        name = unicodedata.name(chr(codepoint)).removeprefix("QUADRANT ")
        filled = []
        for quadrant in name.split(" AND "):
            x0, x1 = (0, round(width / 2)) if "LEFT" in quadrant else (round(width / 2), width)
            y0, y1 = (bottom, round(bottom + height / 2)) if "LOWER" in quadrant else (round(bottom + height / 2), top)
            filled.append((x0, y0, x1, y1))
    rectangles(pen, filled)


def powerline(pen, codepoint, width, bottom, top, light):
    middle = (top + bottom) / 2
    if codepoint % 2 == 0:
        points = [(0, top), (width, middle), (0, bottom)]
    else:
        inset = round(light * math.hypot(width, (top - bottom) / 2) / ((top - bottom) / 2))
        points = [(0, top), (width, middle), (0, bottom), (0, bottom + light),
                  (width - inset, middle), (0, top - light)]
    if codepoint >= 0xE0B2:
        points = [(width - x, y) for x, y in reversed(points)]
    polygon(pen, points)


def main():
    parser = argparse.ArgumentParser(description="Add Multiprompt terminal glyphs to the official Nordwand Mono 1.3.1 SemiBold TTF; requires fonttools==4.67.0.")
    parser.add_argument("input", type=Path, help=f"SemiBold TTF from {UPSTREAM_URL} (archive SHA-256 {UPSTREAM_ARCHIVE_SHA256})")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if hashlib.sha256(args.input.read_bytes()).hexdigest() != UPSTREAM_SHA256:
        parser.error(f"input is not the official 1.3.1 SemiBold TTF (expected SHA-256 {UPSTREAM_SHA256})")
    font = TTFont(args.input, recalcTimestamp=False)
    width = font["hmtx"][font.getBestCmap()[ord(" ")]][0]
    stem = font["glyf"][font.getBestCmap()[ord("|")]]
    light = stem.xMax - stem.xMin
    bottom, top = -font["OS/2"].usWinDescent, font["OS/2"].usWinAscent
    order = list(font.getGlyphOrder())
    for codepoint in [*range(0x2500, 0x25A0), *range(0xE0B0, 0xE0B4)]:
        name = f"uni{codepoint:04X}"
        pen = TTGlyphPen(None)
        if codepoint < 0x2580:
            box(pen, codepoint, width, bottom, top, light)
        elif codepoint < 0x25A0:
            block(pen, codepoint, width, bottom, top)
        else:
            powerline(pen, codepoint, width, bottom, top, light)
        glyph = pen.glyph()
        glyph.recalcBounds(font["glyf"])
        font["glyf"][name] = glyph
        font["hmtx"][name] = (width, glyph.xMin)
        order.append(name)
        for table in font["cmap"].tables:
            if table.isUnicode():
                table.cmap[codepoint] = name
    font.setGlyphOrder(order)
    font["maxp"].recalc(font)
    font["post"].formatType = 2.0
    font["OS/2"].recalcUnicodeRanges(font)
    names = {
        1: "Nordwand Mono MP SemiBold",
        2: "Regular",
        3: "NordwandMonoMP-SemiBold; Multiprompt terminal glyphs",
        4: "Nordwand Mono MP SemiBold",
        6: "NordwandMonoMP-SemiBold",
        16: "Nordwand Mono MP",
        17: "SemiBold",
    }
    for record in font["name"].names:
        if record.nameID in names:
            record.string = names[record.nameID].encode(record.getEncoding())
        if record.nameID == 5:
            record.string = (record.toUnicode() + VERSION_SUFFIX).encode(record.getEncoding())
    font["head"].created = 3873555003
    font["head"].modified = 3873555003
    font.save(args.output, reorderTables=True)
    print(f"SHA-256 {hashlib.sha256(args.output.read_bytes()).hexdigest()}")
    print(f"unitsPerEm={font['head'].unitsPerEm} advance={width} winAscent={top} winDescent={-bottom} light={light} heavy={light * 2}")


if __name__ == "__main__":
    main()
