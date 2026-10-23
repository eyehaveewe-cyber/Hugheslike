# Hugheslike — Hughes Atlas 0.2

**[Recent work, checks and limitations: UPDATES.txt](UPDATES.txt)**

A Godot GraphEdit development workspace for a town's interconnected people,
places, routines, memories, beliefs and possible situations. The interrupted
atlas source is recovered, expanded, committed and natively tested. The
separate playable game and private art have NOT been imported.

## The connected library

**53 categories · 143 relationship types · 691 entries · 1,344 links · 14 views**

The expansion adds 208 entries and 477 links beyond the recovered base. Ten
fictional people demonstrate overlapping roles, unequal information, private
expectations, mixed feelings and practical constraints. These are authored
concepts and examples, not hundreds of executable NPC behaviors.

New layers cover interests, preferences, habits, coping strategies, boundaries,
bodily states, appraisals, expectations, constraints, occasions, message
channels, interaction patterns, self-images and life transitions. The original
base records remain unchanged.

## Open it

Use **Godot 4.7.2**, open `project.godot`, then select **Hughes Atlas** at the top
of the editor. F5 opens the same atlas as a standalone tool. The plugin is
enabled in Project Settings → Plugins. Begin with School; search Avery or
Morgan for the original examples, and Rowan, Tess, Mara or Arun for the new ones.

The workspace includes global search, neighborhood focus, typed connections,
JSON record/schema editing, local undo/redo, saved layout and guarded
save/reload/export. New controls filter relation, meaning, direction and holder;
show qualifier-reference wires; browse the relationship registry; and trace a
graph connection. A path is not a causal explanation. The holder lens is an
authoring filter, not a player's knowledge boundary.

**Add missing seed content…** explicitly merges the expanded catalog into a
saved graph, preserving existing records and layouts. It is undoable and
idempotent; there is no silent reseeding over authored work.

[Working guide](docs/ATLAS_GUIDE.md) ·
[Expansion and examples](docs/ATLAS_V02.md) ·
[Relationship design](docs/RELATIONSHIP_DESIGN.md)

## Verification

[Observed passing run](https://github.com/eyehaveewe-cyber/Hugheslike/actions/runs/39989391936)
at code commit `fb0911b4f4f406b055a67108a4705b7b10093204`:

- Base and expanded catalog validation PASS; zero unlinked seed entries.
- **40 Python regression tests PASS.**
- **Godot 4.7.2 native editor import PASS.**
- **45 native checks PASS**, exercising storage, merges, graph queries,
  GraphEdit construction, connection dialogs, record editing, undo/redo,
  reference inspection, relation search, path tracing and guarded deletion.

See [QA_ATLAS.md](docs/QA_ATLAS.md) for commands, failures corrected and scope.
The checks run on Linux headlessly. A hands-on visual pass, Windows save/recovery
behavior and integration with the original game remain unverified. Record
editing still uses JSON rather than a complete form-based inspector.

```sh
python tools/atlas_data.py
python tools/atlas_extended.py
python -m unittest discover -s tests -p 'test_*.py' -v
godot --headless --path . --script tests/atlas_smoke.gd
```

This is still planning/development infrastructure: no running town, automatic
NPC scheduling, information propagation, emotional simulation, dialogue engine,
XP or progression loop. No main merge or deployment is included.

The historical game description is preserved in
[FOUNDATION_README_ARCHIVE.md](docs/FOUNDATION_README_ARCHIVE.md). Its gameplay
and old verification claims do not describe this tools-only checkout.
