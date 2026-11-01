"""Original approved body artwork, extracted as offline tintable alpha masks.

The lossless reference crops retain the exact silhouettes and soft internal edges.
No procedural human shapes or path approximations are used by the application.
"""
from pathlib import Path
from PIL import Image

REFERENCE = Path(__file__).with_name('reference')
SOURCE_SIZE = (310, 620)

def category(pixel):
    r, g, b = pixel
    if min(pixel) >= 252:
        return None
    if max(pixel) - min(pixel) < 8:
        return 'gray'
    if b - r > 5 and g - r > 5:
        return 'cool'
    if b - g > 5 and r - g > 3 and b > r - 3:
        return 'purple'
    if r - b > 5 and g - b > (r - b) * .25:
        return 'orange'
    if r - g > 5:
        return 'red'
    return 'gray'


def region(side, x, y, color):
    """Name existing source shapes; these bounds never define the body outline."""
    if side == 'front':
        if color == 'cool': return 'chest'
        if color == 'purple': return 'biceps'
        if color == 'orange': return 'deltoids' if y < 180 else 'abs'
        if color == 'red': return 'quadriceps' if y < 430 else 'tibialis'
        if y < 88: return 'head'
        if y < 118: return 'neck' if 136 <= x <= 181 else 'trapezius'
        if y >= 297 and (x < 90 or x > 223): return 'hands'
        if 150 <= y <= 215 and (x < 102 or x > 211): return 'triceps'
        if 205 <= y < 297 and (x < 95 or x > 220): return 'forearm'
        if 170 <= y < 204 and 127 <= x <= 188: return 'abs'
        if 170 <= y <= 285 and 105 <= x <= 210: return 'obliques'
        if 286 <= y < 380 and (124 <= x <= 152 or 162 <= x <= 190): return 'adductors'
        if 400 <= y < 450 and 95 <= x <= 220: return 'knees'
        if 449 <= y < 541 and 95 <= x <= 220: return 'calves'
        if y >= 565: return 'feet'
        if y >= 540: return 'ankles'
    else:
        if color == 'cool': return 'lats'
        if color == 'purple': return 'triceps'
        if color == 'orange': return 'deltoids'
        if color == 'red': return 'hamstring' if y < 435 else 'calves'
        if y < 88: return 'head'
        if y < 103 and 135 <= x <= 180: return 'neck'
        if y < 118 or (y < 188 and 146 <= x <= 167): return 'trapezius'
        if 111 <= y < 191 and 96 <= x <= 220: return 'upper-back'
        if y >= 298 and (x < 90 or x > 223): return 'hands'
        if 205 <= y < 298 and (x < 95 or x > 220): return 'forearm'
        if 269 <= y < 336 and 98 <= x <= 213:
            lateral = x < 114 + (y - 300) * .1 or x > 196 - (y - 300) * .1
            return 'gluteal-lateral' if lateral else 'gluteal-medial'
        if 191 <= y < 283 and 100 <= x <= 213: return 'lower-back'
        if 330 <= y < 401 and 126 <= x <= 184: return 'adductors'
        if 400 <= y < 449 and 95 <= x <= 220: return 'knees'
        if y >= 566: return 'feet'
        if y >= 511: return 'ankles'
    return 'neutral'



def masks(side):
    image = Image.open(REFERENCE / f'{side}.png').convert('RGB')
    assert image.size == SOURCE_SIZE
    pixels = image.load()
    samples = {}
    for y in range(image.height):
        for x in range(image.width):
            color = category(pixels[x, y])
            if color is not None:
                samples.setdefault(color, []).append(255 - min(pixels[x, y]))
    # Per-color normalization separates shape coverage from the example tag colors.
    # The remaining alpha retains the reference's antialiasing and soft shading.
    dark = {color: sorted(values)[int((len(values) - 1) * .95)] for color, values in samples.items()}
    result = {'base': Image.new('L', image.size)}
    regions = {}
    for y in range(image.height):
        for x in range(image.width):
            color = category(pixels[x, y])
            if color is None:
                continue
            alpha = round(min(1, (255 - min(pixels[x, y])) / dark[color]) * 255)
            name = region(side, x, y, color)
            if name not in result:
                result[name] = Image.new('L', image.size)
            result['base'].putpixel((x, y), alpha)
            result[name].putpixel((x, y), alpha)
            if alpha >= 128:
                regions.setdefault(name, set()).add((x, y))
    return result, regions
