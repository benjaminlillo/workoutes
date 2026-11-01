# iOS muscle artwork

The current iOS artwork is extracted directly from the approved front/back image.
The lossless crops in `reference/` preserve its actual proportions, curves, thin
muscle separators and soft shading. They are source material, not app UI images.

Generate the native template masks offline:

```sh
python3 -m pip install Pillow
python3 tools/muscle-icons/generate_reference.py
```

Optionally add `--preview-dir /tmp/workoutes-muscle-preview` for an icon contact
sheet and the neutral bodies. The app never runs this tool or segments images.

`reference_artwork.py` separates the example colors from shape coverage and
assigns the original regions to anatomical names. The exported alpha masks retain
antialiasing and shading and can be tinted with any saved tag color. PNG resources
are prepared at 1x, 2x and 3x. Icons, chart masks and the already assembled static
skeleton use the same source artwork; no procedural body approximations remain.

The `muscle-<iconName>-base/highlight` resource names and `MuscleIcon` raw values
are unchanged. Existing tags, backups and snapshots automatically use the new
artwork without modifying saved assignments or colors. Chart anchors share the
same normalized 724 x 1448 coordinate system as the front/back resources.

The original `body-paths.json`, `generate.py`, `generate_body_map.py` and MIT
license remain for the legacy artwork and Android generator. They do not generate
the current iOS artwork.
