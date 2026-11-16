#!/usr/bin/env python3
"""Pack the raw SpriteCollab portraits into one sheet per emotion and colour, for Godot (#16).

Reads  source/spritecollab-portrait/<dex>[/<form>[/<shiny>]]/<Emotion>.png  (raw, from tools/fetch-spritecollab.js)
       source/spritecollab/tracker.json  (which sets exist upstream and their form names)
Writes assets/portraits/<emotion>_portraits.png and shiny_<emotion>_portraits.png, portraits.json, README.md.

Layout (docs/discussion-outputs/six-a-side-opening.md): every sheet is the same grid of 40x40 cells. Cell 0 is a
generic placeholder; then one cell per non-shiny set (each species and mainline form), ordered by folder (dex
number, then form). A set has the same cell in every sheet, so the emotion and the colour (normal or shiny) only
pick the file: shiny Charmander sits in shiny_normal_portraits.png at the cell Charmander has in
normal_portraits.png. Missing portraits leave their cell transparent. A flipped emotion (SpriteCollab's trailing ^)
gets its own sheet, for example normal_flipped_portraits.png.

portraits.json maps every set id in scope (dash-joined folder, as in assets/pokemon: 0006, 0006-0000-0001,
0037-0001) to its cell, its colour and the emotions it has; a set without its own Normal portrait instead names
the set it falls back to (its form's normal colours, then the species' normal set of the same colour, then the
species' normal set), or "placeholder".

Needs Python 3 with Pillow and numpy. Output is deterministic: packing twice gives identical files.
Usage (repo root): python tools/pack_portraits.py [--check]
  --check packs in memory and fails if assets/portraits/ differs (run by tools/run-tests.cmd).
"""

import io
import json
import math
import sys
from pathlib import Path

import numpy
from PIL import Image

REPO_ROOT = Path(__file__).resolve().parent.parent
RAW_FOLDER = REPO_ROOT / "source" / "spritecollab-portrait"
TRACKER_PATH = REPO_ROOT / "source" / "spritecollab" / "tracker.json"
PACKED_FOLDER = REPO_ROOT / "assets" / "portraits"
CELL_SIZE = 40
PLACEHOLDER_CELL = 0
PLACEHOLDER = "placeholder"
NORMAL_COLOUR = "normal"
SHINY_COLOUR = "shiny"
NORMAL_FORM_FOLDER = "0000"
SHINY_FOLDER = "0001"
FLIPPED_MARK = "^"
# Same scope as tools/fetch-spritecollab.js (2026-11-15-variant-scope): '' is the species' normal form.
MAINLINE_FORM_NAMES = {
    "Alola", "Galar", "Hisui", "Paldea", "Mega", "Mega_X", "Mega_Y", "Mega_Z", "Gigantamax", "Primal",
}
# SpriteCollab's standard emotions in its own order; the Special ones and anything unexpected follow.
STANDARD_EMOTIONS = [
    "Normal", "Happy", "Pain", "Angry", "Worried", "Sad", "Crying", "Shouting", "Teary-Eyed", "Determined",
    "Joyous", "Inspired", "Surprised", "Dizzy", "Sigh", "Stunned",
]
SPECIAL_EMOTIONS = ["Special0", "Special1", "Special2", "Special3"]
PLACEHOLDER_COLOUR = (96, 96, 104, 255)
PLACEHOLDER_OUTLINE = (40, 40, 48, 255)


def sets_in_scope(tracker):
    """Yields (set id, colour, base set id, species set id) for every wanted set, shinies included."""
    for dex_folder, species in tracker.items():
        if dex_folder == "0000":
            continue  # placeholder entry upstream, not a Pokemon
        subgroups = species.get("subgroups", {})
        yield dex_folder, NORMAL_COLOUR, dex_folder, dex_folder
        if SHINY_FOLDER in subgroups.get(NORMAL_FORM_FOLDER, {}).get("subgroups", {}):
            yield f"{dex_folder}-{NORMAL_FORM_FOLDER}-{SHINY_FOLDER}", SHINY_COLOUR, dex_folder, dex_folder
        for form_folder, form in subgroups.items():
            if form_folder == NORMAL_FORM_FOLDER or form.get("name") not in MAINLINE_FORM_NAMES:
                continue
            form_id = f"{dex_folder}-{form_folder}"
            yield form_id, NORMAL_COLOUR, form_id, dex_folder
            if SHINY_FOLDER in form.get("subgroups", {}):
                yield f"{form_id}-{SHINY_FOLDER}", SHINY_COLOUR, form_id, dex_folder


def raw_folder(set_id):
    return RAW_FOLDER.joinpath(*set_id.split("-"))


def emotions_of(set_id):
    """The emotion file names (without .png) directly in a set's raw folder."""
    folder = raw_folder(set_id)
    if not folder.is_dir():
        return []
    return sorted(path.stem for path in folder.glob("*.png"))


def emotion_order(found_emotions):
    base_names = STANDARD_EMOTIONS + SPECIAL_EMOTIONS
    extras = sorted({name.rstrip(FLIPPED_MARK) for name in found_emotions} - set(base_names))
    ordered = []
    for name in base_names + extras:
        for variant in (name, name + FLIPPED_MARK):
            if variant in found_emotions:
                ordered.append(variant)
    return ordered


def sheet_file_name(colour, emotion):
    flipped = emotion.endswith(FLIPPED_MARK)
    stem = emotion.rstrip(FLIPPED_MARK).lower().replace("-", "_") + ("_flipped" if flipped else "")
    prefix = "shiny_" if colour == SHINY_COLOUR else ""
    return f"{prefix}{stem}_portraits.png"


def placeholder_pixels():
    """A grey head-and-shoulders silhouette with a dark outline, drawn from circles (deterministic)."""
    pixels = numpy.zeros((CELL_SIZE, CELL_SIZE, 4), numpy.uint8)
    rows, columns = numpy.mgrid[0:CELL_SIZE, 0:CELL_SIZE]
    head = (columns - 19.5) ** 2 + (rows - 15.5) ** 2 <= 8.5 ** 2
    shoulders = ((columns - 19.5) ** 2 / 15.0 ** 2 + (rows - 40.0) ** 2 / 13.0 ** 2 <= 1.0) & (rows < CELL_SIZE - 2)
    body = head | shoulders
    outline = body & ~(
        numpy.roll(body, 1, 0) & numpy.roll(body, -1, 0) & numpy.roll(body, 1, 1) & numpy.roll(body, -1, 1)
    )
    pixels[body] = PLACEHOLDER_COLOUR
    pixels[outline] = PLACEHOLDER_OUTLINE
    return pixels


def load_portrait(path):
    with Image.open(path) as image:
        pixels = numpy.array(image.convert("RGBA"))
    if pixels.shape[:2] != (CELL_SIZE, CELL_SIZE):
        raise ValueError(f"{path} is {pixels.shape[1]}x{pixels.shape[0]}, not {CELL_SIZE}x{CELL_SIZE}")
    return pixels


def png_bytes(pixels):
    buffer = io.BytesIO()
    Image.fromarray(pixels, "RGBA").save(buffer, "PNG", compress_level=9)
    return buffer.getvalue()


def fallback_target(set_id, colour, base_id, species_id, has_own):
    """Where a set without its own Normal portrait draws from, or PLACEHOLDER."""
    candidates = [base_id]
    if colour == SHINY_COLOUR:
        candidates.append(f"{species_id}-{NORMAL_FORM_FOLDER}-{SHINY_FOLDER}")
    candidates.append(species_id)
    for candidate in candidates:
        if candidate != set_id and has_own.get(candidate):
            return candidate
    return PLACEHOLDER


def build():
    """Returns {file name: bytes} for everything in assets/portraits/."""
    tracker = json.loads(TRACKER_PATH.read_text(encoding="utf-8"))
    scope = list(sets_in_scope(tracker))
    emotions_by_set = {set_id: emotions_of(set_id) for set_id, *_ in scope}
    has_own = {set_id: "Normal" in emotions for set_id, emotions in emotions_by_set.items()}

    # One cell per non-shiny set that it or its shiny draws in, ordered by folder.
    base_ids = sorted({base_id for set_id, _, base_id, _ in scope if has_own[set_id]})
    cell_by_base = {base_id: index + 1 for index, base_id in enumerate(base_ids)}
    cell_count = len(base_ids) + 1
    columns = math.ceil(math.sqrt(cell_count))
    rows = math.ceil(cell_count / columns)

    all_emotions = emotion_order({name for emotions in emotions_by_set.values() for name in emotions})
    sheets = {}
    for set_id, colour, base_id, _ in scope:
        if not has_own[set_id]:
            continue
        cell = cell_by_base[base_id]
        top, left = (cell // columns) * CELL_SIZE, (cell % columns) * CELL_SIZE
        for emotion in emotions_by_set[set_id]:
            key = (colour, emotion)
            if key not in sheets:
                sheets[key] = numpy.zeros((rows * CELL_SIZE, columns * CELL_SIZE, 4), numpy.uint8)
            sheets[key][top:top + CELL_SIZE, left:left + CELL_SIZE] = load_portrait(
                raw_folder(set_id) / f"{emotion}.png"
            )
    for colour in (NORMAL_COLOUR, SHINY_COLOUR):
        if (colour, "Normal") in sheets:
            sheets[(colour, "Normal")][0:CELL_SIZE, 0:CELL_SIZE] = placeholder_pixels()

    set_entries = {}
    for set_id, colour, base_id, species_id in scope:
        if has_own[set_id]:
            set_entries[set_id] = {
                "cell": cell_by_base[base_id],
                "colour": colour,
                "emotions": [name for name in all_emotions if name in emotions_by_set[set_id]],
            }
        else:
            set_entries[set_id] = {"fallback": fallback_target(set_id, colour, base_id, species_id, has_own)}

    sheet_names = {}
    for colour in (NORMAL_COLOUR, SHINY_COLOUR):
        sheet_names[colour] = {
            emotion: sheet_file_name(colour, emotion) for emotion in all_emotions if (colour, emotion) in sheets
        }
    index = {
        "cell_size": CELL_SIZE,
        "columns": columns,
        "rows": rows,
        "placeholder_cell": PLACEHOLDER_CELL,
        "emotions": all_emotions,
        "sheets": sheet_names,
        "sets": dict(sorted(set_entries.items())),
    }

    files = {name: png_bytes(sheets[(colour, emotion)])
             for colour, by_emotion in sheet_names.items() for emotion, name in by_emotion.items()}
    files["portraits.json"] = (json.dumps(index, indent=1, sort_keys=False) + "\n").encode("utf-8")
    own_count = sum(1 for value in has_own.values() if value)
    files["README.md"] = "\n".join([
        "# assets/portraits (generated by tools/pack_portraits.py, do not edit by hand)",
        "",
        "Portraits from SpriteCollab (CC BY-NC 4.0; artists in source/spritecollab-portrait/CREDITS.md), one sheet",
        "per emotion and colour, every sheet the same grid of 40x40 cells. portraits.json gives each sprite set's",
        "cell and emotions, or the set it falls back to. Read through view/portrait_loader.gd.",
        "",
        "| | |",
        "|---|---|",
        f"| Sheets | {len(files) - 1} (grid {columns} x {rows} cells) |",
        f"| Sets in scope | {len(scope)} |",
        f"| Sets with their own portraits | {own_count} |",
        f"| Sets using a fallback | {len(scope) - own_count} |",
        "",
    ]).encode("utf-8")
    return files


def main():
    check_only = "--check" in sys.argv
    files = build()
    if check_only:
        problems = []
        for name, content in files.items():
            path = PACKED_FOLDER / name
            if not path.exists() or path.read_bytes() != content:
                problems.append(f"{name} differs or is missing")
        for path in PACKED_FOLDER.glob("*"):
            if path.suffix in (".png", ".json", ".md") and path.name not in files:
                problems.append(f"{path.name} is not produced by the packer")
        if problems:
            print("Portrait pack is out of date (run python tools/pack_portraits.py):")
            print("\n".join(f"  {problem}" for problem in problems[:20]))
            sys.exit(1)
        print(f"Portrait pack is current ({len(files)} files)")
        return
    PACKED_FOLDER.mkdir(parents=True, exist_ok=True)
    for path in PACKED_FOLDER.glob("*"):
        if path.suffix in (".png", ".json", ".md") and path.name not in files:
            path.unlink()
            import_file = path.with_name(path.name + ".import")
            if import_file.exists():
                import_file.unlink()
    for name, content in files.items():
        path = PACKED_FOLDER / name
        if not path.exists() or path.read_bytes() != content:
            path.write_bytes(content)
    print(f"Wrote {len(files)} files to {PACKED_FOLDER.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
