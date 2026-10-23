# Hughes Atlas 0.1 — working guide

This is a development library and editable Godot GraphEdit workspace. It is not
an NPC simulator, a new playable town, or an import of the private foundation.

## Open it

Open the repository's new `project.godot` in Godot. The **Hughes Atlas** main-screen
tab is enabled in Project Settings → Plugins. F5 opens the same atlas interface
as a standalone tool, not the historical game in the archived foundation README.

This small tools project declares a Godot 4.3 API baseline and GL Compatibility.
The original foundation README names 4.7.2; no original project was available to
upgrade or downgrade. Native launch, GDScript parsing and compatibility with the
user's installed engine remain **NOT RUN** in this delivery. See `QA_ATLAS.md`.

For later integration, copy the entire `addons/hughes_atlas/` directory into the
actual game's project and enable its plugin. Keep that directory name. It does
not replace the game's main scene, controller, save data or autoloads. Its default
authored-data destination is `res://data/atlas/hughes_atlas.json`.

## First things to inspect

Start on **School network**: the school is distinct from its institution, and
contains the gym, cafeteria, corridor, lockers, bike rack, office and support
space. Double-click any catalog item to focus it. The focus can cross view
boundaries; select one, two or three hops. Turn neighborhood focus off to browse
the selected view's domains instead. Scope filters distinguish definitions from
invented examples. The catalog search is global and intentionally independent
of the canvas's view/scope filters.

Search **Avery** to see a student who is also a hall monitor and sibling
caregiver. Search **Morgan** for a principal who formerly attended this school,
has a family role, values fairness, and has a temporary weary mood. Search
**Robin** for a witness whose interpretation is not the same as the event.
Search **trust** and inspect links that reference it as a feeling qualifier.

The nine views are School; Character layers; Feelings and motives; Memory and
belief; Town and travel; Conversation and aftermath; Routines and duties;
Fictional worked example; All categories. They are views of one graph, not nine
copies of the data.

The canvas renders at most 90 matching nodes at once and reports the matching
and visible counts. This is a readability/performance bound, not lost data.
Search, focus and the incoming/outgoing list still reach the full library.
Connections name their predicate on the source node's output row. The right-hand
inspector lists all incident relationships and supported qualifier references,
even when their other endpoints are outside the visible canvas.

## Authoring

**New node** opens a JSON record with a stable ID, label, kind, domain, scope,
description and tags. Choose a kind in the catalog filter to use it as the new
node's default. Edit the record, then Apply. Existing IDs cannot be renamed in
place: that would silently break cross-references. Labels remain editable.

Drag a node's right port onto another node's left port. The link dialog offers
only predicates compatible with those endpoint kinds. It provides complete
source/target pickers too, so the two nodes need not be on the same canvas. The
**Link…** toolbar button opens this dialog without dragging. The dropdown shows
both the readable relation and its stable ID. Read its meaning before applying.

Select a node or relationship in the inspector and use **Edit record…**. This
edits the complete JSON record, including extra fields. **Edit schema…** exposes
the kind registry, typed relation registry and views. A schema change that
invalidates existing content is refused; it does not silently discard links.

Ordinary links need no qualifiers. Subjective links need a `holder` reference.
For `feels_toward`, add the feeling ID and use the source person as holder:

```json
{
  "holder": "character.avery",
  "feeling": "feeling.trust",
  "context": "event.bike_loan_01",
  "strength": 0.8,
  "notes": "Trust about this loan, not every situation."
}
```

For `perceived_as`, set the actual observer/audience as holder. Do not use the
person being judged unless it really is self-perception. `has_relationship`
requires `relationship_type`. `heard_from` can identify a `claim`; `borrowed_from`
can identify an `object`. Confidence and strength range from 0 to 1. These are
authoring values, not implemented probability or emotional-scoring mechanics.

Multiple relationship records can share endpoints and predicate but have
different holders, periods or contexts. GraphEdit shows one wire per visible
endpoint/predicate combination; the inspector retains every individual record.
Delete individual relationships there rather than tearing off an ambiguous
wire. Qualifier references are inspectable in the list, not additional causal
wires on the canvas.

Deleting a node asks for confirmation and removes relationships referencing it
through an endpoint or supported qualifier. View focus and layout references
are cleaned as well. The deletion count is shown beforehand. **Undo/Redo** keep
32 in-memory edits, including node layout changes. They are atlas-local buttons,
not the Godot scene editor's global history.

## Persistence and recovery

The bundled seed expands in memory on first use. **Save** creates the authored
JSON file. Once that file exists it is loaded instead; the seed is never applied
over it. Opening a damaged or unsupported document reports errors and does not
replace the current in-memory graph. Save validates before writing a temporary
file, checks its bytes, retains the previous on-disk version as `.bak`, then
installs the new file. External file changes are detected by a content hash;
a stale writer is refused. Export a copy before reconciling competing edits.

**Export copy…** writes a full portable document without changing the current
file path. Existing-path confirmation comes from the file dialog. **Open JSON…**
refuses to replace an unsaved document; save the current document first. Export
alone does not clear its unsaved state. **Reload** asks for confirmation and
remains undoable. Normal save also runs on the editor's
external-data save callback. Save explicitly before ending a session.

Disabling the plugin or closing the standalone tool writes unsaved graph data
to `user://hughes_atlas_recovery.json`. The actual user-data directory is shown
by Godot's project user-data-folder command. This is a recovery copy, not an
automatically restored edit session. Text still inside an unapplied edit dialog
is not part of the document or recovery file. An abrupt process crash may occur
before recovery is written.

## Data and what it does not execute

`seed_catalog.json` contains the kinds, relation definitions and views.
`seed_nodes.json` contains grouped node rows. `seed_links.json` contains compact
relationship recipes. Each recipe is `[source IDs, relation ID, target IDs,
optional qualifiers]`; space-separated IDs intentionally expand to the authored
source/target pair set. A stable hash of endpoints, predicate and optional
`id_suffix` creates seed edge IDs. Add an `id_suffix` for a second seed assertion
with the same triple and different context. Live edits receive separate stable
IDs. Editing a seed does not merge it into an existing authored graph.

The expanded document stores nodes and edges separately from `layout`.
Each edge records `from`, `relation`, `to`, `scope` and `qualifiers`.
Supported qualifier references are holder, context, object, feeling,
relationship_type and claim. Unknown extra metadata survives edits, but is not
interpreted or reference-checked. Symbolic `valid_from` / `valid_until` strings
are preserved without inventing calendar arithmetic; numeric `start_tick` and
`end_tick` receive an ordering check.

A definition is reusable vocabulary. An example is invented demonstration data,
not established Hugheslike canon or a record of a played simulation. A
`possibility` relation such as `can_evoke` or `motivates` is not an executable
rule. Its conditions and notes are not evaluated. A `design` relation connects
an author-facing theme; it never causes an event. Even `fact` means an authored
assertion in its stated scope, not external factual evidence.

There is no automatic inverse-feeling propagation, inferred guilt, rumor
broadcast, schedule execution, graph-to-behavior compilation, runtime access
control, memory decay, save-game migration or progression system in this pass.
The editor is an authoring view that can see all example beliefs. It must not be
used directly as a player's omniscient knowledge interface.

## Checks and handoff

Run the dependency-free data checks from the repository root:

```sh
python tools/atlas_data.py
python -m unittest discover -s tests -p 'test_*.py' -v
```

Export the complete expanded seed to a new path:

```sh
python tools/atlas_data.py --export /your/new/path/hughes_atlas.json
```

The exporter refuses to overwrite any existing file. A native smoke test is
provided, but was not run for this delivery:

```sh
godot --headless --path . --script tests/atlas_smoke.gd
```

Before game integration, launch the actual editor, connect two nodes, edit a
holder-qualified feeling, save/reload, undo a deletion, and disable/re-enable
the plugin. Then review a school week using the atlas rather than adding XP.
The next simulation step should be a small resolver that consumes selected,
explicitly executable rules—not a system that treats all graph edges as code.

Official API references consulted for this implementation:
- https://docs.godotengine.org/en/stable/classes/class_graphedit.html
- https://docs.godotengine.org/en/stable/classes/class_graphnode.html
- https://docs.godotengine.org/en/stable/tutorials/plugins/editor/making_main_screen_plugins.html
