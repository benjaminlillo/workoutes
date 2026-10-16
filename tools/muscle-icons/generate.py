"""Generate native template PDF layers from the MIT-licensed anatomical paths.
Requires svglib and reportlab; not needed to build or run the app.
Source: HichamELBSI/react-native-body-highlighter @ 8ed39ac2ae9cb46fb79d77eedec7e5b029a75174
"""
import io
import json
from pathlib import Path
from xml.sax.saxutils import quoteattr
from svglib.svglib import svg2rlg
from reportlab.graphics import renderPDF

HERE = Path(__file__).resolve().parent
DEST = HERE.parents[1] / 'Workoutes/Workoutes/Assets.xcassets/MuscleIcons'
DATA = json.loads((HERE / 'body-paths.json').read_text())
TRUNK = ['neck', 'trapezius', 'deltoids', 'chest', 'biceps', 'triceps', 'abs', 'obliques', 'upper-back', 'lower-back']
MUSCLES = TRUNK + ['forearm', 'quadriceps', 'adductors', 'calves', 'tibialis', 'hamstring', 'gluteal', 'abductors']
FRONT = (170, 265, 390, 390)
BACK = (894, 265, 390, 390)
# name: side, crop, highlighted anatomical regions, silhouette family
ICONS = {
 'fullBody': ('front', (0, 0, 724, 1448), MUSCLES, 'body'),
 'upperBody': ('front', (45, 265, 635, 550), TRUNK + ['forearm'], 'body'),
 'lowerBody': ('front', (230, 625, 270, 640), ['quadriceps', 'adductors', 'calves', 'tibialis'], 'legs'),
 'arms': ('front', (45, 300, 635, 510), ['biceps', 'triceps', 'forearm'], 'body'),
 'core': ('front', FRONT, ['abs', 'obliques'], 'trunk'),
 'chest': ('front', FRONT, ['chest'], 'trunk'),
 'back': ('back', BACK, ['upper-back', 'lower-back', 'trapezius'], 'trunk'),
 'shoulders': ('front', FRONT, ['deltoids'], 'trunk'),
 'biceps': ('front', FRONT, ['biceps'], 'trunk'),
 'triceps': ('back', BACK, ['triceps'], 'trunk'),
 'forearms': ('front', (45, 300, 225, 515), ['forearm'], 'arm'),
 'trapezius': ('back', BACK, ['trapezius'], 'trunk'),
 'upperBack': ('back', BACK, ['upper-back'], 'trunk'),
 'lowerBack': ('back', BACK, ['lower-back'], 'trunk'),
 'abdominals': ('front', FRONT, ['abs'], 'trunk'),
 'obliques': ('front', FRONT, ['obliques'], 'trunk'),
 'neck': ('front', (180, 230, 370, 300), ['neck'], 'trunk'),
 'glutes': ('back', (954, 605, 270, 300), ['gluteal'], 'legs'),
 'quadriceps': ('front', (230, 625, 270, 430), ['quadriceps'], 'legs'),
 'hamstrings': ('back', (954, 625, 270, 430), ['hamstring'], 'legs'),
 'calves': ('back', (954, 955, 270, 310), ['calves'], 'legs'),
 'adductors': ('front', (230, 625, 270, 430), ['adductors'], 'legs'),
 'abductors': ('back', (954, 605, 270, 300), ['abductors'], 'legs'),
 'tibialis': ('front', (230, 955, 270, 310), ['tibialis'], 'legs'),
}

def paths(side, names, stroke):
 return ''.join(f'<path d={quoteattr(d)} fill="black" stroke="black" stroke-width="{stroke}" stroke-linejoin="round"/>' for name in names for d in DATA[side].get(name, []))


def layer(name, side, box, selected, family, highlight):
 # Two independently tintable vector masks; no source colors baked into the PDFs.
 if highlight:
  if name == 'abductors':
   # Reuse the two upper/lateral gluteal segments for the hip-abductor region.
   abductor_paths = [DATA['back']['gluteal'][i] for i in [0, 2]]
   drawing = ''.join(f'<path d={quoteattr(d)} fill="black" stroke="black" stroke-width="12" stroke-linejoin="round"/>' for d in abductor_paths)
  else:
   drawing = paths(side, selected, 12)
 elif family == 'legs':
  # Join the anatomical muscle islands into one simple silhouette per leg.
  offset = 724 if side == 'back' else 0
  drawing = f'<g transform="translate({offset} 0)"><path fill="black" d="M255 645Q300 630 350 650L340 850Q325 920 320 980L307 1240Q286 1250 267 1238L253 1100Q245 1030 260 970Q246 900 240 800Z M380 650Q425 630 475 645L490 800Q484 900 470 970Q485 1030 477 1100L463 1238Q444 1250 423 1240L410 980Q405 920 390 850Z"/></g>'
 else:
  names = TRUNK if family == 'trunk' else ['deltoids', 'biceps', 'triceps', 'forearm', 'hands'] if family == 'arm' else DATA[side].keys()
  drawing = paths(side, names, 20)
 x, y, width, height = box
 # Explicit square-page clipping and uniform scaling preserve the original anatomy.
 scale = min(28 / width, 28 / height)
 tx, ty = (32 - width * scale) / 2 - x * scale, (32 - height * scale) / 2 - y * scale
 svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><defs><clipPath id="crop"><rect x="{(32-width*scale)/2}" y="{(32-height*scale)/2}" width="{width*scale}" height="{height*scale}"/></clipPath></defs><g clip-path="url(#crop)"><g transform="translate({tx} {ty}) scale({scale})">{drawing}</g></g></svg>'
 target = DEST / f'muscle-{name}-{"highlight" if highlight else "base"}.imageset'
 target.mkdir(parents=True, exist_ok=True)
 renderPDF.drawToFile(svg2rlg(io.BytesIO(svg.encode())), str(target / 'icon.pdf'))
 (target / 'Contents.json').write_text(json.dumps({'images': [{'filename': 'icon.pdf', 'idiom': 'universal'}], 'info': {'author': 'xcode', 'version': 1}, 'properties': {'preserves-vector-representation': True, 'template-rendering-intent': 'template'}}, indent=2)+'\n')

DEST.mkdir(parents=True, exist_ok=True)
(DEST / 'Contents.json').write_text('{"info":{"author":"xcode","version":1}}\n')
for name, config in ICONS.items():
 for highlight in [False, True]:
  layer(name, *config, highlight)
print(f'Generated {len(ICONS)} icons with two vector layers each.')
