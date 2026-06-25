---
name: textures
description: Use when the user has a downloaded PBR texture/material zip (ambientCG, Poly Haven, Kenney PBR, etc.) to bring into this Godot project — e.g. "put this texture zip in", "ingest these bricks", a .zip of Color/Normal/Roughness/AO maps. Handles placing the right maps and producing a usable material.
---

# textures — ingest a PBR texture zip into the mm project

## Overview

Turns a downloaded PBR texture pack (a `.zip` of map images) into a ready-to-use Godot `StandardMaterial3D` inside this project. The mechanical work (unzip, pick the right maps, drop junk, write the material) is in `ingest.py`; this doc covers the judgment and the steps you run.

Output lives in `content/materials/<name>/` — the texture maps (canonical names) plus `<name>.tres`. Themes (`DungeonTheme`) reference these materials; a material on its own is not a theme.

## When to use

- User points at a downloaded texture/material `.zip` and wants it "in the project".
- Symptoms: "put this in", "ingest this texture", "add these bricks", a path under `~/Downloads/*.zip` of PBR maps.
- NOT for: 3D model kits (`.glb`/`.gltf` MeshLibrary) — that's the theme/kit flow in `content/themes/README.md`. NOT for skyboxes/HDRIs (those go on a `WorldEnvironment`).

## Steps

1. Run the ingest script with the zip path and a lowercase name (`[a-z0-9_]+`):

   ```bash
   python3 .claude/skills/textures/ingest.py <zip_path> <name>
   ```

   It places the maps in `content/materials/<name>/` and writes `<name>.tres`. Read its summary — confirm the right file landed in each slot.

2. Import so Godot picks up the new textures (godot is usually not on PATH here):

   ```bash
   GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . --import
   ```

3. The material is now usable. To put it on a dungeon wall: open the theme's MeshLibrary in the editor and assign `content/materials/<name>/<name>.tres` to the `wall` (or `floor`…) item's mesh. See `content/themes/README.md` for the theme-authoring flow.

## The judgment (what the script encodes — don't redo it by hand)

| Decision | Rule |
|----------|------|
| Normal map | Use **NormalGL** (OpenGL). Godot's normals are GL — **never use NormalDX**; the script drops DX. |
| Junk to drop | `.blend`, `.usdc`, `.mtlx`, the bundled `.tres`, and the bare preview image (no map keyword in its name). |
| Filenames | Normalized to `color/normal/roughness/ao/metallic` + original extension, so the `.tres` is source-agnostic. |
| Required map | `color` (albedo). No color map → error; a material needs a base color. |

## sRGB / normal import correctness (one-time, optional but recommended)

After step 2, Godot imports every PNG as sRGB by default. For correct PBR, the non-color maps should be **linear**:

- In the editor, select `normal.png` → Import tab → set **Normal Map = Enabled** (and sRGB off) → Reimport.
- Select `roughness.png` / `ao.png` / `metallic.png` → set **sRGB = Disabled** → Reimport.
- `color.png` stays sRGB (default).

Skipping this still renders — it just looks slightly off (roughness/normal gamma). Fine for a first look; fix when polishing.

## Common mistakes

- **Committing source junk.** Only `content/materials/<name>/` (maps + `.tres`) belongs in the repo. Don't `git add` the original zip or extracted `.blend`/`.usdc`.
- **Expecting it to show in-game immediately.** A material isn't rendered until it's on a mesh in a theme's MeshLibrary (step 3) and the map uses that theme (`theme: <id>` header).
- **DirectX normals.** If a wall looks like its lighting is inside-out, a DX normal slipped in — re-check the normal slot.
- **Wrong load_steps / missing texture.** If the `.tres` fails to load, run step 2 (import) first — the material references imported textures.
