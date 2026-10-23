# Hugheslike — playable store slice + Hughes Atlas 0.3

**[Recent work, checks and limitations: UPDATES.txt](UPDATES.txt)**

This integration branch combines the new playable Bellwether store scene with
the existing Hughes Atlas GraphEdit development library. Open `project.godot`
in **Godot 4.7.2** and press **F5** to play the store slice. The **Hughes Atlas**
tab remains available in the editor; select `addons/hughes_atlas/atlas.tscn`
and press **F6** to run it as a standalone tool.

The store scene is new source from `implementation/store-slice-v0.1`. Its room
and people use marked temporary 2D drawings. The historical foundation ZIP and
private sprites were not imported, and Atlas entries do not drive the game at
runtime. [Store controls and limits](docs/STORE_SLICE.md) ·
[real engine store screenshot](docs/screenshots/store-in-engine.png) ·
[returns and notebook screenshot](docs/screenshots/returns-and-notebook-in-engine.png)

Hughes Atlas records interconnected people, places, routines, memories, beliefs
and possible situations. Its existing **grocery-store, bank and video-store
networks** are preserved here. They contain no real financial/customer data.

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

## Use Hughes Atlas

In the Godot editor, select **Hughes Atlas** at the top. To open the standalone
Atlas, select `addons/hughes_atlas/atlas.tscn` and press F6. Select Grocery
store, Bank branch or Video store in the view menu; search Ruth or Hannah for
cross-store examples. The plugin remains enabled under Project Settings → Plugins.

For an existing saved graph, choose **Add missing seed content…**, then Save.
Existing record IDs, edited names, metadata and layouts win. Nothing is silently
reseeded over your saved work. New content uses the existing search, focus,
relationship filters, reference wires, connection editor and undo/redo.

[Current working guide](docs/ATLAS_GUIDE.md) ·
[Store networks and example chains](docs/COMMERCE_ATLAS.md) ·
[Data-pack boundary for a future plugin](docs/CATALOG_PACKS.md)

The game and Atlas now share this editable Godot project. The networks remain
plain JSON packs with a validated manifest and expanded-document export. No
adapter maps those records to game actions or NPC knowledge yet.

## Atlas baseline checks

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

These 1,072 Atlas entries remain authored planning data, not executable
behaviors. The new game has one playable department-store map; there are no
playable grocery, bank or video-store maps, running inventory economy, bank
arithmetic, autonomous queues, NPC scheduling, information spread, emotional
simulation, quests or XP. Windows persistence and a hands-on play session
remain unverified. No main merge, deployment or private asset publication was
performed.

The older game description remains in
[FOUNDATION_README_ARCHIVE.md](docs/FOUNDATION_README_ARCHIVE.md); its larger
gameplay claims do not describe this small slice. The v0.2 tests and design
record remain in [QA_ATLAS.md](docs/QA_ATLAS.md) and
[ATLAS_V02.md](docs/ATLAS_V02.md).
