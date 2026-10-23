# Hugheslike — Hughes Atlas development workspace

**[Recent work, checks and limitations: UPDATES.txt](UPDATES.txt)**

Hughes Atlas 0.2 is a Godot GraphEdit authoring workspace for interconnected
people, places, routines and experiences. The interrupted draft is recovered
and expanded on this branch. The separate game and private art are not imported.

[Expanded relationships and controls](docs/ATLAS_V02.md) ·
[Working guide](docs/ATLAS_GUIDE.md) · [Verification](docs/QA_ATLAS.md)

Open `project.godot`, choose **Hughes Atlas**, or use F5 for the standalone tool.
The intended test engine is Godot 4.7.2. The tool provides global search, typed
links, inspector editing, local undo/redo and guarded JSON save/reload/export.
New controls filter relationships by meaning, direction and subjective holder;
show qualifier references; browse all relation definitions; and trace a graph
connection without pretending it is causation. Explicit missing-catalog merge
preserves authored records and layouts.

Fourteen new layers cover interests, preferences, habits, coping, boundaries,
bodily states, appraisals, expectations, practical constraints, occasions,
message channels, recurring interaction patterns, self-images and life changes.
The preserved original seed has 39 kinds, 96 relation types, 483 entries and
867 links; the additive expansion is validated separately. These are authored
concepts and fictional examples, not executable NPC behaviors.

Recovery checks passed base data validation and 21 Python tests. Godot found
startup-blocking errors in the previous draft. This expansion fixes those
reported errors and adds native/query regression tests; see the actual Actions
runs and QA record for whether the new version passes.

```sh
python tools/atlas_data.py
python tools/atlas_extended.py
python -m unittest discover -s tests -p 'test_*.py' -v
godot --headless --path . --script tests/atlas_smoke.gd
```

No runtime social simulation, player knowledge implementation, private-source
import, main merge or deployment is included. The historical game description
is preserved in [FOUNDATION_README_ARCHIVE.md](docs/FOUNDATION_README_ARCHIVE.md)
and does not describe this tools-only checkout.
