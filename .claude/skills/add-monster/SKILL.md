---
name: add-monster
description: Use when adding a monster/enemy/encounter to the mm game — a new creature the party fights, optionally one that inflicts a status ailment (poison/burn/sleep/paralysis/silence), placed as an encounter on a map tile. Triggers 怪物, 敵人, 放怪, 遭遇, 中毒怪, 放異常的怪, monster, enemy, encounter, bestiary, mob.
---

# add-monster — add a creature + encounter to the mm game

## Overview

A monster in mm is a `MonsterDef` `.tres` in `content/monsters/`, registered as a Bestiary **encounter group**, and dropped onto a map tile as a `monster` entity. Stepping on that tile starts combat. Adding one is **data only** — no engine code, no save-schema change. This skill front-loads the schema, the status-inflict + resistance tables, the UUID tool, and the footguns so you don't reverse-engineer them (the baseline reverse-engineer takes ~50 tool calls).

Data flow (you touch the **bold** parts):
**`content/monsters/<id>.tres`** → `Bestiary._GROUPS["<grp>"]` → **`{type:monster, encounter:"<grp>", pos}` in `content/maps/*.json`** → `MapImporter` → `main.gd` step-on → `Bestiary.group_defs_for` → `EncounterSystem` → `CombatLayer`.

## When to use

- "Add a 怪物/敵人 to <map>", "make a monster that poisons/sleeps the party", "put a tougher encounter in the dungeon".
- NOT for changing how combat *works* (turn order, formulas, the status system itself) — that's engine code under `engine/combat/`, governed by spec, not this skill.
- NOT for mixed-species groups (a pack of 2 goblins + 1 ogre): the current Bestiary group is **one monster type × count**. Mixing needs an engine change — out of scope.

## 1. Write the MonsterDef (`content/monsters/<id>.tres`)

Copy this; `id` MUST be unique + lowercase (it is the **kill-quest key** `monster_id`). Filename ≈ `id` by convention.

```ini
[gd_resource type="Resource" script_class="MonsterDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://resources/monster_def.gd" id="1_def"]

[resource]
script = ExtResource("1_def")
id = "fire_imp"                 ; monster_id — kill-quest target key; unique, lowercase
display_name = "火焰小鬼"
level = 1
hp_max = 6
might = 3
armor = 0
speed = 14                      ; > party member ⇒ acts first
accuracy = 10
luck = 2
xp_reward = 8
gold_reward = 3
drop_item_id = ""               ; a REAL item id (below) or "" for no drop
drop_chance = 0.0               ; 0.0–1.0
resistances = { 1: 75, 2: -50 } ; Element:percent — +resist / -weakness
inflict_kind = 2                ; StatusEffect.Kind to inflict on hit; -1 = none
inflict_potency = 2             ; per-tick HP, ONLY POISON/BURN read this
inflict_duration = 3            ; rounds
inflict_chance = 0.5            ; 0.0–1.0 roll on a successful hit
```

Omit `sprite` (combat shows a placeholder billboard; real art is a separate art task). For a no-tick kind (SLEEP/PARALYSIS/SILENCE) **delete the `inflict_potency` line** — it is meaningless there.

**Status inflict — `inflict_kind`** (`StatusEffect.Kind`; leave `-1` for a plain attacker):

| kind | value | effect | potency? | leaves combat? |
|---|---|---|---|---|
| POISON | 1 | DoT each round, **can kill in combat** | yes | **YES — lingers in overworld** (5-step tick, floors HP 1) |
| BURN | 2 | DoT each round | yes | no (combat only) |
| SLEEP | 3 | skips turn; **any hit wakes** | no | no |
| PARALYSIS | 4 | 50% chance to skip turn | no | no |
| SILENCE | 5 | cannot cast spells | no | no |

**`resistances` keys — `Element`** (`{int: percent}`, negative = weakness): `0` PHYSICAL, `1` FIRE, `2` COLD, `3` ELECTRIC, `4` POISON, `5` MAGIC. (goblin is `{1: -50}` = fire-weak.)

**Real `drop_item_id` values** (id ≠ filename for some): `potion, ether, revive` (revive_herb), `short_sword, leather` (leather_armor), `lucky_charm`. Verify: `grep '"id"' content/items/*.tres` — wait, those are `.tres`: `grep -h '^id' content/items/*.tres`.

## 2. Register a Bestiary encounter group

In `presentation/combat/bestiary.gd`, add one line to `_GROUPS` (a group = N copies of one monster):

```gdscript
"fi": {"path": "res://content/monsters/fire_imp.tres", "count": 3},
```

Pick a short, unique group id (`"fi"`). The map's `encounter` field references THIS id, not the monster id.

## 3. Place the encounter on a map

Add to the target `content/maps/<map>.json` `entities` array (create the array if absent) — **leave `id` off**, the tool fills it:

```json
{ "type": "monster", "encounter": "fi", "pos": [3, 1] }
```

- **`pos` is `[x, y]` = `[column, row]`** — i.e. the cell is `grid[y][x]`. To check against the start `@` or other entities, read its column/row in the `grid` rows the same way (rows are the y axis).
- Cell MUST be FLOOR (`.`), in-bounds. **Do NOT** use the start cell (`@`), a gate/entry cell, or a cell already holding a vendor/chest/scene/questgiver/another monster — overlapping triggers fight.
- **Do NOT resize the grid** (wild maps are asserted 5×5 by `test_world_maps.gd`).

## 4. Assign the persistent UUID — run the tool, don't hand-roll

Each monster entity needs a unique `id` (UUIDv7) so a defeated encounter stays cleared across save/load. Add the entity WITHOUT `id` (step 3), then:

```bash
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . --script res://tools/assign_encounter_uuids.gd
```

It fills every `id`-less `monster` entity and rewrites the JSON (tab-indented — that reformat is expected/correct).

## 5. Smoke tests (mirror the existing ones)

- `tests/presentation/test_bestiary.gd`: `Bestiary.group_defs_for("fi")` returns `count` defs with the right `inflict_kind`.
- `tests/engine/combat/test_monster_id.gd`: the `.tres` has `id == "<id>"`.
- `tests/content/test_world_maps.gd`: load the map via `MapImporter`, assert `map.has_encounter(Vector2i(x,y))` and `map.get_encounter_uid(Vector2i(x,y)) != ""` (use the getter, not the raw `encounter_uids` dict).
- (status monster) `tests/engine/combat/test_monster_inflict.gd`: run the real `.tres` through `CombatSystem` and assert a party member actually gets the status on hit.

## 6. Import, then test (order matters)

```bash
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit
```

Commit the `.tres`, the bestiary edit, the map JSON, and the tests. (A `.tres`/JSON-only change leaves no tracked import artifact — `.godot/` is gitignored; a `.gd.uid` appears only if you added a brand-new `.gd` test/script file.)

## Common mistakes

| Mistake | Symptom / fix |
|---|---|
| Ran GUT before `--import` (esp. fresh checkout/worktree) | A burst of "Identifier … not declared" parse errors + texture/PNG import failures — NOT real breakage, a missing `.godot/` cache. Run `--import` once, re-test. |
| Hand-rolled the encounter `id`, or left it `""` | Defeated encounter won't persist / respawns after save-load. Leave `id` off and run `tools/assign_encounter_uuids.gd`. |
| Missing / duplicate `.tres` `id` | Kill-quests (`notify_kill`) can't track this species. Set a unique lowercase `id`. |
| `encounter` points at the monster id, not the group id | `Bestiary.group_defs_for` returns empty → no monster spawns. The map references the `_GROUPS` key. |
| `inflict_potency` on SLEEP/PARALYSIS/SILENCE | Ignored (only POISON/BURN read potency). Conversely POISON/BURN with potency 0 = 0 damage. |
| Expected BURN/SLEEP to linger after combat | Only **POISON** leaves combat into the overworld; the rest are combat-only. |
| Resistance sign flipped | Negative = weakness, positive = resist. A fire creature: `{1: 75, 2: -50}`. |
| Monster on start/gate/occupied cell, or resized grid | Spawns on the party, collides with another trigger, or breaks `test_world_maps.gd` (5×5). Use an empty FLOOR cell. |
| `drop_item_id` = a filename | `revive` not `revive_herb`, `leather` not `leather_armor`. `drop_chance` is 0–1. |
| Listed several species in one group | Bestiary group is one type × count; mixed packs need an engine change (out of scope). |

## Reference

Data model: `resources/monster_def.gd`, `engine/combat/monster.gd` (`from_def` carries `inflict_*`/`resistances`), `presentation/combat/bestiary.gd`, `engine/combat/encounter_system.gd`. Status kinds: `engine/combat/status_effect.gd` (`Kind`), inflict applied in `engine/combat/combat_system.gd::monster_act`. Elements: `resources/spell_def.gd` (`Element`). Encounter trigger + clear: `presentation/world/main.gd`. UUID tool: `tools/assign_encounter_uuids.gd`. Status system spec: `docs/superpowers/specs/2026-06-27-status-ailments-design.md`.
