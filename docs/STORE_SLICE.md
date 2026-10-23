# Bellwether store slice

This is a newly written, small Godot 4.7.2 game scene brought in from the separate `implementation/store-slice-v0.1` branch. The Hughes Atlas authoring add-on and its source/data remain available in the same project. The historical foundation ZIP's referenced `reference/concept_bundle/`, art `assets/`, and earlier game scenes/scripts were unavailable; that ZIP was not repaired or used as project source.

## Play

Open the root `project.godot` in Godot 4.7.2 and press F5. Move with WASD or the arrow keys. Click a floor tile to walk there or click a labelled fixture to approach and use it. Press E beside something to interact, R to take the sweater bag to Returns, J to view the notebook, Space to wait, and Esc to close the notebook. At the front doors, R begins a fresh visit.

The slice includes a navigable 14 × 12 isometric department-store floor, blocked fixture footprints and route finding. You can hand a sweater bag to the store clerk at Returns, speak to them, browse two racks, buy one scarf for $8, watch the television, and leave through the front doors. Movement and actions advance a simple clock. The notebook records actions the player has taken.

All visible room and character art is **temporary code-drawn geometry**. No supplied sprites were available to replace. The staff dialogue, scarf purchase, and fixture placement are small implementation choices for this slice, not recovered design or a claim that the larger social simulation exists. The unnamed clerk is not the Atlas character Mara.

## Verification

Official Godot 4.7.2 imported and started the game scene. `tests/smoke.gd` checks collision, a reachable approach for every interaction, returning the bag, buying the scarf, leaving, and restart. The two files in `docs/screenshots/` are real 1280 × 800 engine viewport captures made with Godot 4.7.2 on a software-rendered X display; they are not offline composites.

Run the checks with:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . --quit-after 10
```

Current limits: one store room, one stationary staff member, brief authored interactions, and no save system. A hands-on play session on the user's display has not been performed.
