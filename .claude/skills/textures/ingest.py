#!/usr/bin/env python3
"""Ingest a downloaded PBR texture/material zip into the mm Godot project.

Usage:
    ingest.py <zip_path> <material_name>

What it does (mechanical part — the judgment is documented in SKILL.md):
  * unzips the archive to a temp dir
  * picks the right map per slot from the filenames:
        color / normal (GL, never DX) / roughness / ao / metallic
  * drops source junk: .blend/.usdc/.mtlx, bundled .tres, bare preview image,
    and DirectX normal maps (Godot wants OpenGL normals)
  * copies the chosen maps to  content/materials/<name>/  with canonical names
  * writes  content/materials/<name>/<name>.tres  (a StandardMaterial3D)

After running this, import the textures:
    godot --headless --path . --import
(see SKILL.md for the GODOT path + the one-time sRGB/normal import note).
"""
import os
import re
import sys
import zipfile
import tempfile
import shutil
import subprocess

# slot -> ordered patterns (first/earlier pattern = higher preference)
SLOT_PATTERNS = {
    "color":     [r"base[_-]?color", r"albedo", r"diffuse", r"color"],
    "normal":    [r"normal[_-]?gl", r"nor[_-]?gl", r"normal", r"\bnor\b"],
    "roughness": [r"rough"],
    "ao":        [r"ambient[_-]?occlusion", r"occlusion", r"\bao\b"],
    "metallic":  [r"metal"],
}
# never use a file matching these for any slot (DirectX normals are wrong for Godot)
EXCLUDE = [r"normal[_-]?dx", r"nor[_-]?dx"]
IMG_EXT = {".png", ".jpg", ".jpeg", ".tga", ".webp", ".exr", ".hdr", ".bmp"}
SLOT_ORDER = ["color", "normal", "roughness", "ao", "metallic"]


def repo_root() -> str:
    return subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()


def image_files(root: str):
    out = []
    for dirpath, _dirs, names in os.walk(root):
        for n in names:
            if os.path.splitext(n)[1].lower() in IMG_EXT:
                out.append(os.path.join(dirpath, n))
    return out


def classify(files):
    """Return {slot: filepath}. Best file per slot by pattern priority."""
    chosen = {}  # slot -> (filepath, priority)
    skipped_excluded = []
    for f in files:
        name = os.path.basename(f).lower()
        if any(re.search(p, name) for p in EXCLUDE):
            skipped_excluded.append(f)
            continue
        for slot, pats in SLOT_PATTERNS.items():
            for i, p in enumerate(pats):
                if re.search(p, name):
                    if slot not in chosen or i < chosen[slot][1]:
                        chosen[slot] = (f, i)
                    break
    return {slot: v[0] for slot, v in chosen.items()}, skipped_excluded


def write_tres(mat_dir: str, name: str, present: dict) -> str:
    """present: slot -> res:// path. Returns the .tres path written."""
    ext_lines, ids = [], {}
    idx = 0
    for slot in SLOT_ORDER:
        if slot in present:
            idx += 1
            rid = f"{idx}_{slot}"
            ids[slot] = rid
            ext_lines.append(
                f'[ext_resource type="Texture2D" path="{present[slot]}" id="{rid}"]'
            )
    body = ["[resource]"]
    if "color" in ids:
        body.append(f'albedo_texture = ExtResource("{ids["color"]}")')
    if "normal" in ids:
        body.append("normal_enabled = true")
        body.append(f'normal_texture = ExtResource("{ids["normal"]}")')
    if "roughness" in ids:
        body.append(f'roughness_texture = ExtResource("{ids["roughness"]}")')
    if "ao" in ids:
        body.append("ao_enabled = true")
        body.append(f'ao_texture = ExtResource("{ids["ao"]}")')
    if "metallic" in ids:
        body.append("metallic = 1.0")
        body.append(f'metallic_texture = ExtResource("{ids["metallic"]}")')
    text = (
        f'[gd_resource type="StandardMaterial3D" load_steps={idx + 1} format=3]\n\n'
        + "\n".join(ext_lines)
        + "\n\n"
        + "\n".join(body)
        + "\n"
    )
    path = os.path.join(mat_dir, f"{name}.tres")
    with open(path, "w") as fh:
        fh.write(text)
    return path


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    zip_path, name = sys.argv[1], sys.argv[2]
    if not re.fullmatch(r"[a-z0-9_]+", name):
        print(f"ERROR: material name must be [a-z0-9_]+ (got {name!r})")
        return 2
    if not os.path.isfile(zip_path):
        print(f"ERROR: zip not found: {zip_path}")
        return 2

    root = repo_root()
    rel_dir = os.path.join("content", "materials", name)
    mat_dir = os.path.join(root, rel_dir)

    with tempfile.TemporaryDirectory() as tmp:
        with zipfile.ZipFile(zip_path) as z:
            z.extractall(tmp)
        files = image_files(tmp)
        if not files:
            print("ERROR: no image files found in the zip")
            return 1
        chosen, excluded = classify(files)
        if "color" not in chosen:
            print("ERROR: no color/albedo/diffuse map found — cannot build a material")
            print("Images seen:", [os.path.basename(f) for f in files])
            return 1

        os.makedirs(mat_dir, exist_ok=True)
        present = {}
        for slot in SLOT_ORDER:
            if slot in chosen:
                ext = os.path.splitext(chosen[slot])[1].lower()
                dest = os.path.join(mat_dir, f"{slot}{ext}")
                shutil.copyfile(chosen[slot], dest)
                present[slot] = f"res://{rel_dir}/{slot}{ext}".replace(os.sep, "/")

        tres = write_tres(mat_dir, name, present)

    chosen_names = {s: os.path.basename(p) for s, p in chosen.items()}
    used = set(chosen.values())
    unused = [os.path.basename(f) for f in files if f not in used and f not in excluded]

    print(f"Material '{name}' → {rel_dir}/")
    for slot in SLOT_ORDER:
        if slot in chosen_names:
            print(f"  {slot:9s} <- {chosen_names[slot]}")
    if excluded:
        print("  dropped (DX normal): " + ", ".join(os.path.basename(f) for f in excluded))
    if unused:
        print("  ignored images: " + ", ".join(unused))
    print(f"  wrote {os.path.relpath(tres, root)}")
    print("\nNext: import the textures, then the material is ready to use:")
    print("  godot --headless --path . --import")
    return 0


if __name__ == "__main__":
    sys.exit(main())
