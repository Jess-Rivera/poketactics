#!/usr/bin/env python3
"""Pack the raw SpriteCollab sheets into one sheet plus one JSON per sprite set, for Godot.

Reads  source/spritecollab/<dex>[/<form>[/<shiny>]]/  (raw, from tools/fetch-spritecollab.js)
Writes assets/pokemon/<dex>[-<form>[-<shiny>]].png and .json, plus assets/pokemon/README.md.

Each sheet holds every fetched animation of one set (Charmander, shiny Charmander, Mega Charizard X, ...), each
animation still laid out as SpriteCollab draws it: one column per frame, 8 rows (one per facing), or a single row
for animations drawn the same for every facing. Sheets are
shelf-packed 4096 wide (8192 when one animation is wider) and never over 8192 tall.

The JSON per set gives, per animation: where it sits in the sheet, frame size, durations (ticks of 1/60 s), hit and
return frames, its row count (8 or 1), the feet point per frame (the white pixel of the Shadow sheet) and four anchor points per frame (the
black, red, green and blue pixels of the Offsets sheet). Points are frame-local pixels, flat [x, y, x, y, ...] in
row-major order (row = facing, then frame), with -1, -1 where a frame has no marker. CopyOf animations are kept as
aliases of the animation they copy.

Sheets are saved as palette PNGs when they have 256 colours or fewer (lossless, checked on every save).
Needs Python 3 with Pillow and numpy. Output is deterministic: packing twice gives identical files.
Decision: docs/discussion-outputs/sprite-pack-plan.md
Usage (repo root): python tools/pack_sprites.py
"""

import io
import json
import sys
import xml.etree.ElementTree as ElementTree
from pathlib import Path

import numpy
from PIL import Image

REPO_ROOT = Path(__file__).resolve().parent.parent
RAW_FOLDER = REPO_ROOT / "source" / "spritecollab"
PACKED_FOLDER = REPO_ROOT / "assets" / "pokemon"
FACING_ROWS = 8
# Some animations (about 1 in 6) are drawn once for all facings: a single row.
ALLOWED_ROW_COUNTS = (1, FACING_ROWS)
NORMAL_SHEET_WIDTH = 4096
LARGEST_SHEET_SIZE = 8192
NO_MARKER = -1
ANCHOR_COLOURS = {
    "black": (0, 0, 0),
    "red": (255, 0, 0),
    "green": (0, 255, 0),
    "blue": (0, 0, 255),
}
FEET_COLOUR = (255, 255, 255)


def read_anim_data(xml_path):
    """Returns {name: {...}} for every <Anim> in an AnimData.xml, plus the set's shadow size."""
    root = ElementTree.parse(xml_path).getroot()
    shadow_size = int(root.findtext("ShadowSize", default="0"))
    animations = {}
    for anim in root.iter("Anim"):
        name = anim.findtext("Name")
        copy_of = anim.findtext("CopyOf")
        if copy_of:
            animations[name] = {"copy_of": copy_of}
            continue
        animations[name] = {
            "frame_size": [int(anim.findtext("FrameWidth")), int(anim.findtext("FrameHeight"))],
            "durations": [int(duration.text) for duration in anim.iter("Duration")],
            "hit_frame": int(anim.findtext("HitFrame", default=str(NO_MARKER))),
            "return_frame": int(anim.findtext("ReturnFrame", default=str(NO_MARKER))),
        }
    return animations, shadow_size


def marker_points(sheet_pixels, colour, frame_width, frame_height, frame_count, row_count):
    """Frame-local position of the one pixel of this colour in each frame, flat row-major, -1 where missing."""
    points = numpy.full((row_count, frame_count, 2), NO_MARKER, dtype=numpy.int64)
    if sheet_pixels is None:
        return points.reshape(-1).tolist()
    red, green, blue, alpha = (sheet_pixels[:, :, channel] for channel in range(4))
    is_marker = (alpha > 0) & (red == colour[0]) & (green == colour[1]) & (blue == colour[2])
    pixel_ys, pixel_xs = numpy.nonzero(is_marker)
    rows, columns = pixel_ys // frame_height, pixel_xs // frame_width
    inside = (rows < row_count) & (columns < frame_count)
    # If a frame ever had two pixels of one colour, the last one in scan order wins; SpriteCollab draws one.
    points[rows[inside], columns[inside], 0] = pixel_xs[inside] % frame_width
    points[rows[inside], columns[inside], 1] = pixel_ys[inside] % frame_height
    return points.reshape(-1).tolist()


def save_sheet(sheet_image, path):
    """Saves losslessly as a palette PNG when the sheet has 256 colours or fewer (SpriteCollab sheets have about 16),
    which is less than half the size of full colour. Reads the bytes back and stops if any pixel differs."""
    pixels = numpy.ascontiguousarray(numpy.asarray(sheet_image))
    height, width, _ = pixels.shape
    colours, colour_index = numpy.unique(pixels.view(numpy.uint32).reshape(-1), return_inverse=True)
    buffer = io.BytesIO()
    if len(colours) <= 256:
        palette = colours.view(numpy.uint8).reshape(-1, 4)
        palette_image = Image.fromarray(colour_index.reshape(height, width).astype(numpy.uint8), "P")
        palette_image.putpalette(palette[:, :3].reshape(-1).tolist())
        palette_image.save(buffer, "PNG", transparency=bytes(palette[:, 3].tolist()), compress_level=9)
    else:
        sheet_image.save(buffer, "PNG", compress_level=9)
    with Image.open(io.BytesIO(buffer.getvalue())) as written:
        if not numpy.array_equal(numpy.asarray(written.convert("RGBA")), pixels):
            raise ValueError(f"{path.name}: saved sheet does not read back identical")
    path.write_bytes(buffer.getvalue())


def load_pixels(path):
    if not path.exists():
        return None
    with Image.open(path) as image:
        return numpy.asarray(image.convert("RGBA"))


def shelf_pack(sheet_sizes):
    """Places sheets (name -> (width, height)) on shelves. Returns positions, sheet width and height."""
    widest = max(width for width, _ in sheet_sizes.values())
    shelf_width = NORMAL_SHEET_WIDTH if widest <= NORMAL_SHEET_WIDTH else LARGEST_SHEET_SIZE
    if widest > shelf_width:
        raise ValueError(f"an animation is {widest} pixels wide, over {LARGEST_SHEET_SIZE}")
    # Tallest first, then widest, then by name, so the layout never depends on file listing order.
    order = sorted(sheet_sizes, key=lambda name: (-sheet_sizes[name][1], -sheet_sizes[name][0], name))
    positions = {}
    cursor_x = cursor_y = shelf_height = used_width = 0
    for name in order:
        width, height = sheet_sizes[name]
        if cursor_x + width > shelf_width:
            cursor_y += shelf_height
            cursor_x = shelf_height = 0
        positions[name] = (cursor_x, cursor_y)
        cursor_x += width
        shelf_height = max(shelf_height, height)
        used_width = max(used_width, cursor_x)
    return positions, used_width, cursor_y + shelf_height


def pack_sprite_set(set_folder, set_id):
    animations, shadow_size = read_anim_data(set_folder / "AnimData.xml")
    sheet_sizes = {}
    for name, animation in animations.items():
        anim_path = set_folder / f"{name}-Anim.png"
        if "copy_of" in animation or not anim_path.exists():
            continue
        with Image.open(anim_path) as image:
            sheet_sizes[name] = image.size
    if not sheet_sizes:
        raise ValueError(f"{set_id}: no animation sheets")

    positions, sheet_width, sheet_height = shelf_pack(sheet_sizes)
    if sheet_height > LARGEST_SHEET_SIZE:
        raise ValueError(f"{set_id}: packed sheet is {sheet_height} tall, over {LARGEST_SHEET_SIZE}")

    packed_sheet = Image.new("RGBA", (sheet_width, sheet_height), (0, 0, 0, 0))
    packed_animations = {}
    for name in sorted(sheet_sizes):
        animation = animations[name]
        frame_width, frame_height = animation["frame_size"]
        width, height = sheet_sizes[name]
        frame_count = len(animation["durations"])
        row_count = height // frame_height
        if row_count not in ALLOWED_ROW_COUNTS or height != row_count * frame_height or width != frame_count * frame_width:
            raise ValueError(f"{set_id} {name}: sheet {width}x{height} does not match its frames")
        with Image.open(set_folder / f"{name}-Anim.png") as image:
            packed_sheet.paste(image.convert("RGBA"), positions[name])
        offsets_pixels = load_pixels(set_folder / f"{name}-Offsets.png")
        shadow_pixels = load_pixels(set_folder / f"{name}-Shadow.png")
        packed_animations[name] = {
            "rect": [positions[name][0], positions[name][1], width, height],
            "frame_size": [frame_width, frame_height],
            "rows": row_count,
            "durations": animation["durations"],
            "hit_frame": animation["hit_frame"],
            "return_frame": animation["return_frame"],
            "feet": marker_points(shadow_pixels, FEET_COLOUR, frame_width, frame_height, frame_count, row_count),
            "anchors": {
                colour_name: marker_points(offsets_pixels, colour, frame_width, frame_height, frame_count, row_count)
                for colour_name, colour in ANCHOR_COLOURS.items()
            },
        }
    for name, animation in animations.items():
        if "copy_of" in animation and animation["copy_of"] in packed_animations:
            packed_animations[name] = {"copy_of": animation["copy_of"]}

    save_sheet(packed_sheet, PACKED_FOLDER / f"{set_id}.png")
    description = {
        "set": set_id,
        "sheet": f"{set_id}.png",
        "sheet_size": [sheet_width, sheet_height],
        "shadow_size": shadow_size,
        "animations": packed_animations,
    }
    (PACKED_FOLDER / f"{set_id}.json").write_text(
        json.dumps(description, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8", newline="\n"
    )
    return sheet_width, sheet_height


def main():
    PACKED_FOLDER.mkdir(parents=True, exist_ok=True)
    set_folders = sorted(path.parent for path in RAW_FOLDER.rglob("AnimData.xml"))
    if not set_folders:
        sys.exit(f"No sprite sets under {RAW_FOLDER}; run tools/fetch-spritecollab.js first")
    written_names = set()
    largest = (0, 0, "")
    for index, set_folder in enumerate(set_folders, start=1):
        set_id = "-".join(set_folder.relative_to(RAW_FOLDER).parts)
        width, height = pack_sprite_set(set_folder, set_id)
        written_names.update({f"{set_id}.png", f"{set_id}.json"})
        largest = max(largest, (height, width, set_id))
        if index % 200 == 0:
            print(f"{index} of {len(set_folders)} sets packed")
    removed = 0
    for path in PACKED_FOLDER.iterdir():
        if path.suffix in (".png", ".json") and path.name not in written_names:
            path.unlink()
            removed += 1
            import_file = path.with_name(path.name + ".import")
            if import_file.exists():
                import_file.unlink()
    (PACKED_FOLDER / "README.md").write_text(
        "\n".join([
            "# assets/pokemon (packed sprites, generated, do not edit by hand)",
            "",
            "One sheet (.png) and one description (.json) per sprite set, packed by `python tools/pack_sprites.py` from",
            "the raw SpriteCollab sheets in source/spritecollab/. Names are the raw folder path joined by dashes:",
            "dex number, then form, then 0001 for shiny (0004 Charmander, 0004-0000-0001 shiny Charmander).",
            "",
            f"Sets: {len(set_folders)}. Largest sheet: {largest[2]} at {largest[1]}x{largest[0]}.",
            "",
            "License CC BY-NC 4.0 and every artist: source/spritecollab/LICENSE-SpriteCollab.md and CREDITS.md.",
            "Format and decisions: docs/discussion-outputs/sprite-pack-plan.md.",
            "",
        ]),
        encoding="utf-8",
        newline="\n",
    )
    print(f"{len(set_folders)} sets packed, {removed} stale files removed, largest {largest[2]} {largest[1]}x{largest[0]}")


if __name__ == "__main__":
    main()
