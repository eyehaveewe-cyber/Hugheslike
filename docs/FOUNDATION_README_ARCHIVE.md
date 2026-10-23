# Hugheslike — repository status

**[Recent work, checks and limitations: UPDATES.txt](UPDATES.txt)**

This GitHub repository currently contains documentation only. The foundation
README below was restored on 15 October 2026, but the game project, assets,
scripts, tools and test reports it describes are not present here. Its run
instructions and verification claims describe a separately held foundation;
they are not a playable download or verified test results for this repository.
Private source ZIPs and assets have not been imported or published by this
reporting update. Their publication remains unapproved.

The original foundation description is preserved below for context.

---

# Hugheslike — playable foundation v0.1

A small, illustrated social roguelike prototype built around the supplied art. Open `project.godot` in **Godot 4.7.2** and press **F6** on `scenes/main.tscn`, or **F5** to run the project. The first import may take a little time. No addons or external services are required.

This is the first runnable slice, created from the concept archive and eighteen supplied asset packs. The original concept notes remain under `reference/concept_bundle/`. Names, dialogue and the compact retail-block arrangement are provisional implementation choices.

## Play an afternoon

Start in Bellwether Department Store. Browse, use the television, handle a bag of returned sweaters, speak with the staff, or walk out into the shopping arcade. The arcade connects the department store, Neighborhood Grocery and the Family Diner. Its far-right exit lets you head home at any time.

There are eight NPCs with short routines. Cal takes a break at the diner after twenty simulated minutes. A remark can be misunderstood, and you can learn its context, repeat an assumption, listen, or leave it alone. The notebook records observations available to the player. Private beliefs and the objective event history are separate save data.

Each grid step advances twenty simulated seconds. Other actions spend an appropriate short interval. Menus pause the simulation. New seeds select one of three remark variants and four bounded arrangements of two department-store displays. Architecture and character proportions stay consistent between runs.

| Control | Action |
| --- | --- |
| Left click | Walk to a floor point, person or object; use it on arrival |
| WASD / arrows | Step along the isometric grid |
| E | Interact with the nearest person, prop or exit |
| Space | Wait two simulated minutes |
| Mouse wheel / +/- | Zoom |
| F | Fit the entire room |
| R | Return the carried sweater bag to its counter location |
| J | Notebook |
| M | District map |
| Escape | Pause / close a dialog |
| F5 / F9 | Save / load the afternoon while playing |
| F3 | Toggle the ground-footprint and anchor inspector |

The game has one local save, `user://afternoon.json`, with a versioned schema. It preserves the seed, character, location, positions, clock, money, object states, carried bag, observations, events and NPC beliefs.

## The art defines the space

The native floor diamond is **128 × 64 pixels**, with basis vectors `(64,32)` and `(-64,32)`. Wall height is **192 pixels**. Tiles retain their exact supplied anchors. The reference teen boy is **144 world pixels** tall; the other three playable cast designs retain their source height ratios. Camera zoom changes the view, not collision, movement or relative sizes.

| Space | Ground cells | Purpose |
| --- | --- | --- |
| Department store | 14 × 12 | Clothing displays, returns, layaway, the initial social encounter |
| Shopping arcade | 20 × 7 | Shared circulation, bench, telephone, connections and departure |
| Grocery | 15 × 12 | Aisles, produce, checkout and short staff routines |
| Diner | 13 × 10 | Booths, tables, coffee and a quieter second meeting |

The first block contains 618 floor cells. Fixture footprints reserve real navigable space. Displays and counters have distinct dimensions; sprites are proportionally scaled through metadata instead of stretching their canvases. Wall-mounted objects have explicit elevations. Ground origins support depth sorting as the player walks in front of and behind furniture.

The importer copied 340 independent sprites and all 384 tiles **without changing their image bytes**. `data/assets.json` records source paths, hashes, alpha bounds, anchors, uniform scales and ground footprints. The active scenes received a visual placement pass. Scales for unused catalogue assets are provisional and need their own pass before expansion. Two holiday sheets and restaurant-layout references are preserved as references rather than being treated as individual runtime sprites.

`docs/previews/` contains labelled offline composites of the placement data and source PNGs. These aid scale review; they are not engine screenshots.

## Project structure

| Path | Responsibility |
| --- | --- |
| `scripts/grid_world.gd` | Projection, spatial grammar, collision footprints and pathfinding |
| `scripts/social_sim.gd` | Afternoon state, limited observations, beliefs, event history and persistence |
| `scripts/main.gd` | Scene composition, movement, object interactions, dialogue and interface |
| `scripts/district_map.gd` | Native district-map view |
| `data/rooms.json` | Four authored layouts, links and interactive props |
| `data/people.json` | NPC identities, art and short routes |
| `data/assets.json` | Source-preserving asset registry and scale contract |
| `assets/` | Independent supplied sprites and structural tiles |
| `reference/` | Original concept bundle, pack instructions and metadata |
| `tools/` | Reproducible import, layout-data generation and offline proof rendering |
| `tests/smoke.gd` | Native engine tests of traversal, state and actual UI callbacks |

To regenerate imports, extract the supplied archives into sibling folders named after the ZIP stems, then run `python tools/import_packs.py /absolute/path/to/source_packs`. This optional tool requires Pillow. Running the game itself needs only Godot.

## Verification and present limits

Godot 4.7.2 imported and ran the project headlessly. Tests cover 256 seeds, all free-floor connectivity, fixture overlap, usable approaches, exits and arrivals, movement rejection, sprite hit targeting, carrying and delivery, a social clarification, coffee purchase, offscreen information limits, save/load and notebook bounds. See `docs/QA.md`.

Native graphical rendering and a hands-on five-minute play session still need verification on a display. The supplied characters use static poses, with front/rear views for the player. Resting advances time; a seated-pose animation has not been made. NPC room changes are scheduled state changes. The social event is a small authored rule system, and the current replay variation is deliberately bounded.

The next useful pass is a hands-on check of the department-store camera, furniture grounding, front/back occlusion and click reach. That should precede enlarging the district. School, winter, restaurant, recycling, neighborhood, peer and other supplied families are catalogued for subsequent areas.
