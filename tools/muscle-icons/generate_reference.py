"""Generate native template assets directly from the approved reference artwork.

Requires Pillow, offline only. Asset IDs and saved MuscleIcon values are unchanged.
"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

from reference_artwork import masks

ROOT = Path(__file__).resolve().parents[2]
ICON_DEST = ROOT / 'Workoutes/Shared/MuscleIcons.xcassets/MuscleIcons'
BODY_DEST = ROOT / 'Workoutes/Workoutes/BodyMap.xcassets'
NEUTRAL = {'base', 'head', 'hands', 'knees', 'ankles', 'feet', 'neutral'}
UPPER = ['neck', 'trapezius', 'deltoids', 'chest', 'biceps', 'triceps', 'forearm', 'abs', 'obliques', 'upper-back', 'lats', 'lower-back']
LOWER = ['quadriceps', 'adductors', 'calves', 'tibialis', 'hamstring', 'gluteal-lateral', 'gluteal-medial']
TORSO = (55, 93, 260, 310)
ICONS = {
    'fullBody': ('front', (0, 0, 310, 620), UPPER + LOWER),
    'upperBody': ('front', (20, 0, 294, 310), UPPER),
    'lowerBody': ('front', (88, 270, 228, 610), LOWER),
    'arms': ('front', (20, 0, 294, 310), ['biceps', 'triceps', 'forearm']),
    'core': ('front', TORSO, ['abs', 'obliques']),
    'chest': ('front', TORSO, ['chest']),
    'back': ('back', TORSO, ['upper-back', 'lats', 'lower-back', 'trapezius']),
    'shoulders': ('front', TORSO, ['deltoids']),
    'biceps': ('front', TORSO, ['biceps']),
    'triceps': ('back', TORSO, ['triceps']),
    'forearms': ('front', (20, 100, 294, 360), ['forearm']),
    'trapezius': ('back', TORSO, ['trapezius']),
    'upperBack': ('back', TORSO, ['upper-back', 'trapezius']),
    'lowerBack': ('back', TORSO, ['lower-back']),
    'abdominals': ('front', TORSO, ['abs']),
    'obliques': ('front', TORSO, ['obliques']),
    'neck': ('front', (105, 0, 211, 127), ['neck']),
    'glutes': ('back', (90, 260, 220, 405), ['gluteal-lateral', 'gluteal-medial']),
    'quadriceps': ('front', (90, 275, 225, 435), ['quadriceps']),
    'hamstrings': ('back', (90, 270, 225, 445), ['hamstring']),
    'calves': ('back', (90, 420, 220, 615), ['calves']),
    'adductors': ('front', (90, 275, 225, 435), ['adductors']),
    'abductors': ('back', (90, 260, 220, 405), ['gluteal-lateral']),
    'tibialis': ('front', (90, 420, 220, 615), ['tibialis']),
}


def combined(regions, selected):
    result = Image.new('L', regions['base'].size)
    for name in selected:
        if name in regions:
            result = ImageChops.lighter(result, regions[name])
    return result


def template(alpha):
    image = Image.new('RGBA', alpha.size, (0, 0, 0, 0))
    image.putalpha(alpha)
    return image


def icon(alpha, box, scale):
    crop = alpha.crop(box)
    factor = min(28 * scale / crop.width, 28 * scale / crop.height)
    crop = crop.resize((round(crop.width * factor), round(crop.height * factor)), Image.Resampling.LANCZOS)
    canvas = Image.new('L', (32 * scale, 32 * scale))
    canvas.paste(crop, ((canvas.width - crop.width) // 2, (canvas.height - crop.height) // 2))
    return canvas


def write_asset(target, images):
    target.mkdir(parents=True, exist_ok=True)
    entries = []
    for scale, image in images.items():
        filename = f'artwork@{scale}x.png'
        template(image).save(target / filename, optimize=True)
        entries.append({'filename': filename, 'idiom': 'universal', 'scale': f'{scale}x'})
    (target / 'Contents.json').write_text(json.dumps({
        'images': entries, 'info': {'author': 'xcode', 'version': 1},
        'properties': {'template-rendering-intent': 'template'},
    }, indent=2) + '\n')
    # Retire the procedural PDF resource after the catalog points to the original artwork.
    for filename in ('icon.pdf', 'body.pdf'):
        previous = target / filename
        if previous.exists(): previous.unlink()


def generate(preview_dir=None):
    all_regions = {side: masks(side)[0] for side in ['front', 'back']}
    for name, (side, box, selected) in ICONS.items():
        regions = all_regions[side]
        for highlight in (False, True):
            alpha = combined(regions, selected) if highlight else regions['base']
            write_asset(ICON_DEST / f'muscle-{name}-{"highlight" if highlight else "base"}.imageset',
                        {scale: ImageChops.darker(icon(alpha, box, scale), icon(regions['base'], box, scale))
                         for scale in (1, 2, 3)})
    for side, regions in all_regions.items():
        for name in ['base'] + [key for key in regions if key not in NEUTRAL]:
            write_asset(BODY_DEST / f'body-{side}-{name}.imageset',
                        {scale: ImageChops.darker(
                             regions[name].resize((144 * scale, 288 * scale), Image.Resampling.LANCZOS),
                             regions['base'].resize((144 * scale, 288 * scale), Image.Resampling.LANCZOS))
                         for scale in (1, 2, 3)})
    if preview_dir:
        preview_dir.mkdir(parents=True, exist_ok=True)
        sheet = Image.new('RGB', (960, 1560), 'white')
        draw = ImageDraw.Draw(sheet)
        for index, (name, (side, box, selected)) in enumerate(ICONS.items()):
            neutral = icon(all_regions[side]['base'], box, 6)
            active = icon(combined(all_regions[side], selected), box, 6)
            drawing = Image.new('RGB', neutral.size, 'white')
            drawing.paste('#C9C9CD', (0, 0, drawing.width, drawing.height), neutral)
            drawing.paste('#4B96F6', (0, 0, drawing.width, drawing.height), active)
            x, y = (index % 4) * 240 + 24, (index // 4) * 260 + 16
            sheet.paste(drawing, (x, y))
            draw.text((x + 96, y + 210), name, anchor='mt', fill='black')
        sheet.save(preview_dir / 'icon-sheet.png')
        for side, regions in all_regions.items():
            preview = Image.new('RGB', regions['base'].size, 'white')
            preview.paste('#C9C9CD', (0, 0, preview.width, preview.height), regions['base'])
            preview.save(preview_dir / f'{side}-neutral.png')
    print('Generated 24 icons and both static bodies from the exact reference crops, at 1x/2x/3x.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--preview-dir', type=Path)
    args = parser.parse_args()
    generate(args.preview_dir)
