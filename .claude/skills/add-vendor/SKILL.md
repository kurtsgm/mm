---
name: add-vendor
description: Use when adding a shop to the mm game — a 道具店/武器店/防具店 (buy-sell goods), 法術店 (learn spells), or 神殿/旅店 (paid services like revive/heal/rest) — placed on a map tile the party steps onto to trade. Triggers: 商店, 商人, 開店, vendor, shop, merchant, 神殿, 旅店, 法術店, 賣東西, 買東西.
---

# add-vendor — place a shop/service on a map in the mm game

## Overview

The mm game has a data-driven vendor framework: a shop is a JSON file in `content/vendors/` plus one `vendor` entity on a map. Stepping on that tile opens `VendorOverlay`. Adding a shop is **data only** — no engine code, no save changes. This skill front-loads the schema, the conventions, and the footguns so you don't reverse-engineer them.

Data flow (you only touch the two **bold** parts):
**`content/vendors/<id>.json`** → `VendorCatalog.load_vendor(id)`; **`{type:vendor,pos,id}` in a `content/maps/*.json`** → `MapImporter` → `MapData.vendors` → `main.gd::_try_vendor` → `VendorOverlay`.

## When to use

- "Add a 商店 / 商人 / 神殿 / 旅店 / 法術店 to <map>", "let the player buy/sell/learn/heal somewhere".
- NOT for changing how shops *work* (transaction rules, UI) — that's engine code in `engine/world/vendor_transaction.gd` / `presentation/ui/vendor_overlay.gd`, governed by the spec, not this skill.

## The three kinds (copy a template)

Filename MUST equal `id`; `id` is unique and lowercase. `kind` MUST be exactly `goods` / `spells` / `services` (else the catalog returns `{}` and the game logs "（商店 … 遺失）").

```jsonc
// goods — buy AND sell items. Buy price = ItemDef.value; sell = floor(value * sell_factor, default 0.5).
{ "id": "oak_general_store", "kind": "goods", "name": "橡鎮雜貨舖",
  "greeting": "歡迎光臨。",            // optional
  "sell_factor": 0.5,                  // optional
  "stock": ["potion", "ether", "revive", "short_sword", "leather"] }   // real item ids

// spells — learn spells (buy-only, pick a character). Price = SpellDef.gold_cost.
{ "id": "oak_mage", "kind": "spells", "name": "橡鎮法師塔",
  "spells": ["spark", "heal", "bless"] }   // each spell's .tres MUST have gold_cost > 0, else it's free

// services — paid effects (神殿/旅店). target "character" picks one; "party" applies to all.
{ "id": "oak_temple", "kind": "services", "name": "橡鎮神殿",
  "offers": [
    { "name": "復活同伴", "cost": 100, "effect": "revive",    "target": "character" },
    { "name": "治療傷勢", "cost": 50,  "effect": "heal_full", "target": "character" },
    { "name": "住宿一晚", "cost": 20,  "effect": "rest",      "target": "party" } ] }
```

`effect` vocabulary (v1): `revive` / `heal_full` / `rest` ONLY. Any other effect renders nothing and silently no-ops — don't invent `cure` etc.

## Real ids (use these, not filenames)

- **Items** (`content/items/*.tres` — note id ≠ filename for two): `potion, ether, revive` (revive_herb.tres), `short_sword, leather` (leather_armor.tres), `lucky_charm`.
- **Spells** (`content/spells/*.tres`): arcane = `spark, flame_wave, weaken`; divine = `heal, revive, bless`; utility = `teleport, town_portal`. A spell is learnable only by a class whose school matches: **Sorcerer→arcane**, **Cleric/Paladin→divine** (others can't learn any). So a 法術店 selling `spark` is only useful to Cassia(Sorcerer); `heal/bless` to Marcus(Cleric)/Cordelia(Paladin).
- Verify any id exists before using it: `grep -r '"id"' content/items` / `grep id content/spells/*.tres`.

## Steps

1. **Write** `content/vendors/<id>.json` from the matching template above. Verify every item/spell id is real.
2. **(spells only)** For each sold spell, ensure its `content/spells/<spell>.tres` has `gold_cost = N` in the `[resource]` block (alongside `sp_cost`). Default 0 = "free/not for sale" — set a price or the shop gives it away.
3. **Pick a tile** on the target `content/maps/<map>.json` grid and add to its `entities` array:
   `{ "type": "vendor", "pos": [x, y], "id": "<id>" }`
   - The cell MUST be FLOOR (`.`) and in-bounds. **Do NOT** use the start cell (`@`), an `entries`/gate cell, or a cell already holding a chest/scene/portal/monster — overlapping triggers fight.
   - **Do NOT resize the grid** (wild maps are asserted 5×5 by `test_world_maps.gd`). If the map has no `entities` key yet, add one.
4. **Add a smoke test** so the wiring is guarded (mirror existing tests):
   - in `tests/presentation/test_vendor_catalog.gd`: `VendorCatalog.load_vendor("<id>")` returns the dict with the right `kind`.
   - in `tests/content/test_world_maps.gd`: load the map via `MapImporter`, assert `map.has_vendor(Vector2i(x,y))` and `get_vendor(...)["id"] == "<id>"`.
5. **Import then test** (order matters — see gotcha):
   ```bash
   GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . --import
   "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit
   ```
   Commit the JSON, the map edit, the test(s), any new `.gd.uid`, and (spells) the `.tres` edits.

## Common mistakes

| Mistake | Symptom / fix |
|---|---|
| Skipped `--import` before GUT (esp. fresh checkout) | Dozens of "Identifier … not declared" parse errors — NOT real breakage; it's a missing `.godot/` import cache. Run `--import` once, re-test. |
| `kind` typo or omitted | Catalog returns `{}`; in-game logs "（商店 … 遺失）". Must be exactly goods/spells/services. |
| Filename ≠ id | `load_vendor(id)` reads `content/vendors/<id>.json` — they must match. |
| Vendor on start/gate/occupied cell | Shop opens on spawn, or collides with chest/scene. Pick an empty FLOOR cell. |
| Resized the grid to make room | `test_world_maps.gd` fails (wild maps are 5×5). Place within the existing grid. |
| Spell in a 法術店 with no `gold_cost` | Sold for 0 gold. Set `gold_cost` on its `.tres`. |
| Used a filename as an id | `revive` not `revive_herb`, `leather` not `leather_armor`. Grep to confirm. |
| Unknown `effect` in a service | Renders/does nothing. Only `revive`/`heal_full`/`rest` exist in v1. |

## Reference

Schema authority: `docs/superpowers/specs/2026-06-26-vendor-service-framework-design.md`. Engine/data model: `engine/world/vendor_transaction.gd`, `engine/party/spell_eligibility.gd`, `resources/map_data.gd` (`vendors`/`has_vendor`/`get_vendor`), `resources/spell_def.gd` (`gold_cost`), `presentation/world/vendor_catalog.gd`, `presentation/ui/vendor_overlay.gd`.
