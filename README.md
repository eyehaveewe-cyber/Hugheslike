# Hugheslike — Hughes Atlas 0.3: everyday commerce

**[Recent work, checks and limitations: UPDATES.txt](UPDATES.txt)**

A Godot GraphEdit development library for interconnected people, places,
routines, memories, beliefs and possible situations. This update adds linked
**grocery-store, bank and video-store networks**. It does not import the separate
playable game, private art or any real financial/customer data.

## New connected content

The whole atlas now has **61 categories, 177 relationship types, 1,072 entries,
2,358 connections and 23 views**. This pass adds **381 entries, 1,014 connections,
8 categories, 34 relationship types and 9 views**, with no unlinked entries.
The v0.1 and v0.2 source records remain unchanged.

| New domain | Entries | What it connects |
| --- | ---: | --- |
| Grocery | 92 | Staff, customers, household lists, stock, prices, parcels, favors, closing and 12 situations |
| Bank | 83 | Account holders, permission, requests, receipts, private explanations, record disputes and 12 situations |
| Video store | 103 | Taste, films, individual copies, reservations, membership, return timing and 13 situations |
| Shared commerce vocabulary | 48 | Queues, transactions, stock/account states, agreements and cross-store errands |
| Worked examples | 55 | Twelve people and linked account, return, memory and interpretation examples |

New people use biblical first names: **Joseph, Ruth, Samuel, Naomi, Deborah,
Nathan, Esther, Ezra, Hannah, Caleb, Isaac and Lydia**. They are original
fictional residents, not biblical-character adaptations. Existing authored
characters were not silently renamed.

Ruth's example links wages, pending availability, a checkout pause and an
outsider's unsupported guess. Hannah's example separates a timely physical
tape return from a later processing entry and a disputed fee. A three-stop
errand connects all three businesses without forcing every visit into a crisis.

## Open it

Use **Godot 4.7.2**, open `project.godot`, and select **Hughes Atlas** at the top
of the editor. F5 opens the same atlas as a standalone tool. Select Grocery
store, Bank branch or Video store in the view menu; search Ruth or Hannah for
cross-store examples. The plugin is enabled under Project Settings → Plugins.

For an existing saved graph, choose **Add missing seed content…**, then Save.
Existing record IDs, edited names, metadata and layouts win. Nothing is silently
reseeded over your saved work. New content uses the existing search, focus,
relationship filters, reference wires, connection editor and undo/redo.

[Current working guide](docs/ATLAS_GUIDE.md) ·
[Store networks and example chains](docs/COMMERCE_ATLAS.md) ·
[Data-pack boundary for a future plugin](docs/CATALOG_PACKS.md)

The user's other program has not been integrated. The new networks are plain
JSON packs with a validated manifest and expanded-document export, so a future
adapter need not generate or manipulate Godot scenes.

## Observed checks

[Passing run](https://github.com/eyehaveewe-cyber/Hugheslike/actions/runs/39994913207)
at code commit `d766bd629328e437a995c67f6a48afda0ccfbc77`:

- Three catalog validators PASS, with zero unlinked entries.
- **64 Python tests PASS**, including 24 new commerce tests.
- **Godot 4.7.2 native editor import PASS.**
- **45 retained native regression checks and 33 new native commerce checks PASS.**
- Python and Godot expansion produce the same complete document values.

The commerce checks exercise actual view-selection callbacks, GraphEdit nodes
and wires for each store, copy-level relationships, account connections,
full-document save/reload, editing/undo and nondestructive merging. They run
headlessly on Linux, not as a manual graphical playtest. See
[QA_COMMERCE.md](docs/QA_COMMERCE.md) for exact scope and evidence.

```sh
python tools/atlas_data.py
python tools/atlas_extended.py
python tools/atlas_commerce.py
python -m unittest discover -s tests -p 'test_*.py' -v
godot --headless --path . --script tests/atlas_smoke.gd
godot --headless --path . --script tests/atlas_commerce_smoke.gd
```

Export a new portable document without overwriting an existing file:

```sh
python tools/atlas_commerce.py --export NEW_FILE.json
```

This is authored planning data and editor infrastructure, not 1,072 executable
behaviors. No running inventory economy, bank arithmetic, autonomous queues,
NPC scheduling, information spread, emotional simulation, playable store maps,
quests or XP were added. Visual readability, manual mouse use, Windows
persistence and original-game integration remain unverified. No main merge,
deployment or private asset publication was performed.

The older game description remains in
[FOUNDATION_README_ARCHIVE.md](docs/FOUNDATION_README_ARCHIVE.md); its gameplay
claims do not describe this authoring-only checkout. The v0.2 tests and design
record remain in [QA_ATLAS.md](docs/QA_ATLAS.md) and
[ATLAS_V02.md](docs/ATLAS_V02.md).
