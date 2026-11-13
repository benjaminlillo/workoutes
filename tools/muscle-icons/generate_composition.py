"""Export aligned alpha masks for the four composable iOS anatomy panels."""

import json

from PIL import Image, ImageChops, ImageDraw

from generate_detail_icons import DETAILS, detail_mask
from generate_reference import ICON_DEST, ICONS, LOWER, UPPER, combined, template
from reference_artwork import masks

DEST = ICON_DEST.parent / "MuscleComposition"
UPPER_BOX = (0, 0, 310, 365)
LOWER_BOXES = {"front": (88, 282, 228, 620), "back": (88, 269, 228, 620)}

# Broad icons span both faces where their anatomy calls for it.
BOTH_FACES = {
    "fullBody": UPPER + LOWER,
    "upperBody": UPPER,
    "lowerBody": LOWER,
    "arms": ["biceps", "triceps", "forearm"],
    "shoulders": ["deltoids"],
    "forearms": ["forearm"],
    "trapezius": ["trapezius"],
    "adductors": ["adductors"],
    "calves": ["calves"],
}



def write_mask(name, alpha, box):
    folder = DEST / f"{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    crop = alpha.crop(box)
    crop = crop.resize((crop.width // 2, (crop.height + 1) // 2), Image.Resampling.LANCZOS)
    template(crop).save(folder / "mask.png", optimize=True)
    (folder / "Contents.json").write_text(json.dumps({
        "images": [{"filename": "mask.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"template-rendering-intent": "template"},
    }, indent=2) + "\n")


def generate():
    membership = {}
    for side in ("front", "back"):
        regions = masks(side)[0]
        lower_area = Image.new("L", regions["base"].size)
        lower_box = LOWER_BOXES[side]
        draw = ImageDraw.Draw(lower_area)
        if side == "front":
            draw.polygon([(88, 282), (124, 282), (150, 307), (167, 307),
                          (195, 282), (227, 282), (227, 619), (88, 619)], fill=255)
        else:
            draw.rectangle((88, 269, 227, 619), fill=255)
        upper_area = ImageChops.invert(lower_area)
        highlights = {}
        for name, (face, _, pieces) in ICONS.items():
            if face == side or name in BOTH_FACES:
                highlights[name] = combined(regions, BOTH_FACES.get(name, pieces))
        for name, (face, piece, _, contour) in DETAILS.items():
            if face == side:
                highlights[name] = detail_mask(regions[piece], contour)

        for half, area, box in (("upper", upper_area, UPPER_BOX), ("lower", lower_area, lower_box)):
            panel = f"{half}{side.title()}"
            write_mask(f"anatomy-{panel}-base", ImageChops.multiply(regions["base"], area), box)
            for name, alpha in highlights.items():
                # Pick the anatomical half from the muscle, not stray source pixels.
                upper = name not in {"lowerBody", "glutes", "quadriceps", "hamstrings", "calves",
                                     "adductors", "abductors", "tibialis"}
                if name != "fullBody" and upper != (half == "upper"):
                    continue
                part = ImageChops.multiply(alpha, area)
                assert part.getbbox(), (panel, name)
                write_mask(f"anatomy-{panel}-{name}", part, box)
                membership.setdefault(name, []).append(panel)

    print("\n".join(f"{name}: {', '.join(panels)}" for name, panels in membership.items()))


if __name__ == "__main__":
    generate()
