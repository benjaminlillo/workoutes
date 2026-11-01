"""Generate aligned template PDFs for Home's anatomical chart.

Uses the same MIT-licensed paths as generate.py. Requires svglib and reportlab.
All regions share a page and transform so they can be composited without distortion.
"""
import io
import json
import re
from pathlib import Path
from xml.sax.saxutils import quoteattr
from svglib.svglib import svg2rlg
from reportlab.graphics import renderPDF

HERE = Path(__file__).resolve().parent
DATA = json.loads((HERE / 'body-paths.json').read_text())
DEST = HERE.parents[1] / 'Workoutes/Workoutes/BodyMap.xcassets'
NEUTRAL = {'knees', 'hands', 'ankles', 'feet', 'head', 'hair'}

def write(side, name, paths):
    paths = [re.sub(r'(?:\s*z){2,}', 'z', path) for path in paths]
    drawing = ''.join(f'<path d={quoteattr(d)} fill="black" stroke="black" stroke-width="8" stroke-linejoin="round"/>' for d in paths)
    offset = -724 if side == 'back' else 0
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="144.8" height="289.6" viewBox="0 0 724 1448"><g transform="translate({offset} 0)">{drawing}</g></svg>'
    target = DEST / f'body-{side}-{name}.imageset'
    target.mkdir(parents=True, exist_ok=True)
    renderPDF.drawToFile(svg2rlg(io.BytesIO(svg.encode())), str(target / 'body.pdf'))
    (target / 'Contents.json').write_text(json.dumps({
        'images': [{'filename': 'body.pdf', 'idiom': 'universal'}],
        'info': {'author': 'xcode', 'version': 1},
        'properties': {'preserves-vector-representation': True, 'template-rendering-intent': 'template'}
    }, indent=2) + '\n')

DEST.mkdir(parents=True, exist_ok=True)
(DEST / 'Contents.json').write_text('{"info":{"author":"xcode","version":1}}\n')
for side, regions in DATA.items():
    write(side, 'base', [path for paths in regions.values() for path in paths])
    for name, paths in regions.items():
        if name in NEUTRAL:
            continue
        if name == 'gluteal':
            # Match the hip-abductor icon while allowing independent gluteal coloring.
            write(side, 'gluteal-lateral', [paths[i] for i in [0, 2]])
            write(side, 'gluteal-medial', [paths[i] for i in [1, 3]])
        else:
            write(side, name, paths)
print('Generated aligned body-map layers.')
