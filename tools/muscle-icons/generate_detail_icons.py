"""Create schematic highlights on the existing iOS muscle silhouettes.

The contours below select portions of the approved reference masks. Deep muscles
are shown by their approximate surface location, using the same icon style.
"""
from PIL import Image, ImageChops, ImageDraw

from generate_reference import ICON_DEST, TORSO, icon, write_asset
from reference_artwork import masks

# Include the complete hands and shoulders in the arm icons.
ARMS = (0, 0, 310, 365)
ARM_GROUPS = {
    "biceps": ("front", "biceps"),
    "triceps": ("back", "triceps"),
    "forearms": ("front", "forearm"),
}

# Each contour describes the left half of the image and is mirrored on the right.
DETAILS = {
    "upperChest": ("front", "chest", TORSO, [(94, 107), (155, 107), (155, 133), (102, 138)]),
    "middleChest": ("front", "chest", TORSO, [(99, 137), (155, 132), (155, 152), (103, 158)]),
    "lowerChest": ("front", "chest", TORSO, [(102, 157), (155, 151), (155, 180), (99, 180)]),
    "anteriorDeltoid": ("front", "deltoids", TORSO, [(120, 104), (124, 125), (96, 152), (77, 163), (95, 125)]),
    "lateralDeltoid": ("front", "deltoids", TORSO, [(70, 107), (119, 104), (95, 126), (79, 163), (66, 157)]),
    "posteriorDeltoid": ("back", "deltoids", TORSO, None),
    "bicepsLongHead": ("front", "biceps", ARMS, [(79, 146), (96, 147), (84, 176), (69, 218), (54, 222)]),
    "bicepsShortHead": ("front", "biceps", ARMS, [(96, 147), (105, 150), (96, 205), (68, 223), (83, 177)]),
    "tricepsLongHead": ("back", "triceps", ARMS, [(96, 147), (106, 150), (95, 189), (79, 203), (72, 201), (85, 173)]),
    "tricepsLateralHead": ("back", "triceps", ARMS, [(71, 148), (96, 146), (86, 173), (73, 200), (59, 205)]),
    "tricepsMedialHead": ("back", "triceps", ARMS, [(64, 202), (80, 199), (94, 187), (84, 215), (62, 224)]),
    "forearmFlexors": ("front", "forearm", ARMS, [(71, 211), (91, 209), (79, 252), (50, 304), (35, 306), (62, 245)]),
    "forearmExtensors": ("back", "forearm", ARMS, None),
    "brachioradialis": ("front", "forearm", ARMS, [(49, 205), (72, 208), (64, 242), (42, 287), (29, 298), (38, 241)]),
    "lats": ("back", "lats", TORSO, None),
    "externalObliques": ("front", "obliques", TORSO, [(100, 170), (137, 180), (132, 220), (120, 247), (101, 244)]),
    "internalObliques": ("front", "obliques", TORSO, [(113, 205), (146, 208), (148, 240), (124, 276), (110, 264)]),
    "transverseAbdominis": ("front", "obliques", TORSO, [(105, 220), (152, 218), (152, 263), (104, 263)]),
}


def detail_mask(source, contour):
    if contour is None:
        return source
    scale = 3
    selection = Image.new("L", (source.width * scale, source.height * scale))
    draw = ImageDraw.Draw(selection)
    draw.polygon([(x * scale, y * scale) for x, y in contour], fill=255)
    draw.polygon([((313 - x) * scale, y * scale) for x, y in contour], fill=255)
    selection = selection.resize(source.size, Image.Resampling.LANCZOS)
    return ImageChops.multiply(source, selection)


def arm_silhouette(base):
    """Fade the torso above the hips while keeping the arms and hands intact."""
    alpha = base.copy()
    for y in range(242, ARMS[3]):
        opacity = max(0, (283 - y) / 41)
        for x in range(87, 227):
            alpha.putpixel((x, y), round(alpha.getpixel((x, y)) * opacity))
    return alpha


def write_icon(name, base, highlight, crop):
    assert highlight.getbbox(), f"Empty highlight: {name}"
    for kind, alpha in (("base", base), ("highlight", highlight)):
        write_asset(ICON_DEST / f"muscle-{name}-{kind}.imageset",
                    {scale: icon(alpha, crop, scale) for scale in (1, 2, 3)})


def generate():
    artwork = {side: masks(side)[0] for side in ("front", "back")}
    arms = {side: arm_silhouette(regions["base"]) for side, regions in artwork.items()}
    for name, (side, region) in ARM_GROUPS.items():
        write_icon(name, arms[side], artwork[side][region], ARMS)
    for name, (side, region, crop, contour) in DETAILS.items():
        regions = artwork[side]
        base = arms[side] if crop == ARMS else regions["base"]
        highlight = ImageChops.darker(detail_mask(regions[region], contour), base)
        write_icon(name, base, highlight, crop)


if __name__ == "__main__":
    generate()
