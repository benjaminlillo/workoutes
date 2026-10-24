#!/usr/bin/env python3
"""Build editable Icon Composer packages from the app's current theme palette."""

import argparse
import json
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "Workoutes/Workoutes"
CANONICAL = APP / "WorkoutesIcon.icon/Assets"


def png_scale(data):
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Icon artwork must be PNG")
    width, height = struct.unpack(">II", data[16:24])
    if width != height:
        raise ValueError("Icon artwork must use a square canvas")
    return 1024 / width


def srgb(hex_value):
    values = [int(hex_value[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return "srgb:" + ",".join(f"{value:.6f}" for value in values) + ",1"


def gradient(first, second):
    return {
        "linear-gradient": [first, second],
        "orientation": {"start": {"x": 0, "y": 0}, "stop": {"x": 1, "y": 1}},
    }


def layer(image, name, scale=1, blend="normal", glass=False):
    return {
        "name": name,
        "image-name": image,
        "fill": "automatic",
        "blend-mode": blend,
        "glass": glass,
        "position": {"scale": scale, "translation-in-points": [0, 0]},
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--foreground", type=Path, default=CANONICAL / "workoutes-w.png")
    parser.add_argument("--texture", type=Path, default=CANONICAL / "grain-atmosphere.png")
    args = parser.parse_args()
    foreground, texture = args.foreground.read_bytes(), args.texture.read_bytes()
    foreground_scale, texture_scale = png_scale(foreground), png_scale(texture)

    source = (APP / "ThemeColor.swift").read_text()

    def values(property_name):
        body = source.split(f"var {property_name}:", 1)[1].split("\n    }", 1)[0]
        return dict(re.findall(r'case \.(\w+): "([^"\n]+)"', body))

    primary, secondary = values("hex"), values("secondaryHex")
    names, alternates = values("name"), values("alternateIconName")
    if set(primary) != set(secondary) or set(primary) != set(names):
        raise ValueError("Theme names and palettes must match")
    if set(primary) != set(alternates) | {"indigo"}:
        raise ValueError("Every non-default theme must declare an alternate icon name")

    for theme, color in primary.items():
        icon_name = alternates.get(theme, "WorkoutesIcon")
        wash = layer("theme-colors.svg", "Colores del tema", blend="multiply")
        wash["fill"] = gradient(srgb(color), srgb(secondary[theme]))
        document = {
            "fill": gradient("srgb:0.008,0.008,0.012,1", "srgb:0.008,0.008,0.012,1"),
            # Icon Composer orders groups and layers from front to back.
            "groups": [
                {
                    "name": "W · logotipo original",
                    "layers": [layer("workoutes-w.png", "W original", foreground_scale, glass=True)],
                    "shadow": {"kind": "neutral", "opacity": 0.25},
                    "translucency": {"enabled": False, "value": 0},
                    "translucency-specializations": [
                        {"appearance": "tinted", "value": {"enabled": True, "value": 0.2}}
                    ],
                },
                {
                    "name": "Fondo · " + names[theme],
                    "layers": [wash, layer("grain-atmosphere.png", "Textura y luz", texture_scale)],
                    "opacity-specializations": [{"appearance": "tinted", "value": 0}],
                    "shadow": {"kind": "neutral", "opacity": 0},
                    "translucency": {"enabled": False, "value": 0},
                },
            ],
            "supported-platforms": {"circles": ["watchOS"], "squares": "shared"},
        }
        destinations = [APP / (icon_name + ".icon")]
        if icon_name == "WorkoutesIcon":
            destinations.append(ROOT / "Workoutes/WorkoutesWatch/WorkoutesIcon.icon")
        for destination in destinations:
            assets = destination / "Assets"
            assets.mkdir(parents=True, exist_ok=True)
            (assets / "workoutes-w.png").write_bytes(foreground)
            (assets / "grain-atmosphere.png").write_bytes(texture)
            (assets / "theme-colors.svg").write_text(
                '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
                'viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="white"/></svg>\n'
            )
            (assets / "09-barra-ez-w-contornos.svg").unlink(missing_ok=True)
            (destination / "icon.json").write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n")
        print(names[theme] + " → " + icon_name + ".icon")


if __name__ == "__main__":
    main()
