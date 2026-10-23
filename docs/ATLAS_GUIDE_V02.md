# Hughes Atlas 0.2 — working guide

Hughes Atlas is a Godot GraphEdit development workspace, not a running town or
a player's notebook. Its 53 categories, 143 relation types, 691 entries and
1,344 links are authored vocabulary and fictional examples. Fourteen views
inspect the same graph; they are not separate copies of its data.

## Open it

Use Godot 4.7.2. Open this branch's `project.godot`, then choose **Hughes Atlas**
at the top of the editor. The plugin is enabled under Project Settings →
Plugins. F5 opens the same interface as a standalone tool. This tools project
now declares the 4.7 engine feature level; it does not alter the separate,
unimported game. See QA_ATLAS.md for observed checks and remaining limits.

For later integration, copy the entire `addons/hughes_atlas/` directory into
the actual game and enable its plugin. Do not replace the game's main scene,
project settings or save data. Test that integration separately.

## Start with people and situations

School network begins at the school grounds. Search **Avery** for the original
student/hall-monitor/caregiver example, **Morgan** for present authority and
past student life, or **Robin** for incomplete witnessing and a theft belief.
The bicycle owner, borrower, witness and recipient of an allegation do not
share the same information.

Search **Rowan** or **Tess** for a concert promise, work conflict and late
explanation. Tess has affection and resentment toward Rowan simultaneously.
Search **Mara** for retirement, an old radio, personal boundaries and a shared
repair interest. **Arun** supplies a contrasting interpretation of a public
help offer. The unequal poster-credit example connects Avery and Tess again.

Double-click a catalog item to focus it. The global search checks labels, IDs,
descriptions and tags. Its kind filter narrows the catalog independently of the
canvas's relation filters. Select one, two or three neighborhood hops. Disable
Focus neighborhood to browse a view's domains instead.

The canvas shows up to 90 nodes and reports how many matched. Hidden content is
not deleted. The right-hand inspector lists every incident relationship and
supported qualifier reference, even when its other nodes are not on the canvas.
Arrange stores visible positions; Fit adjusts zoom to the visible graph.

## Read a connection before using it

Every relation has source kinds, target kinds, a readable meaning and one of
seven semantic categories: structural, fact, temporal, subjective, normative,
possibility or design. Even a fact is an authored assertion in its stated
scope, not an external truth or proof that a simulation executed it.

**Relation library…** searches the complete predicate registry and shows use
counts. A relation can exist even before an example uses it. Use the canvas's
relation/meaning filters to isolate a useful question instead of displaying
every line simultaneously. Incoming/outgoing filters follow declared direction;
symmetric relationships allow navigation both ways. Feelings are not made
reciprocal just because friendship or shared interests are symmetric.

The holder filter restricts subjective assertions to a chosen person or group.
It does NOT implement NPC/player information access: authored structural and
objective records remain visible. A runtime knowledge interface needs its own
observation, access and disclosure rules.

Turn on **Show context / holder references** to draw labeled reference wires for
metadata such as a feeling, context, object or knowledge holder. These are not
additional causal claims. A connection like Tess → feels toward → Rowan can
reference affection, resentment or a particular incident. Parallel records
remain separate in the inspector even where the canvas uses a shared wire.

**Find connection…** finds a shortest graph connection of up to eight hops under
the current filters. The report names every actual assertion and marks reverse
traversal. This is a navigation aid, not a causal explanation, inferred fact,
psychological model or proof that two people know one another.

## Edit the graph

New node opens an editable JSON record. Use a stable lowercase ID, label,
registered kind, domain, scope (`definition` or `example`), description and tags.
Existing IDs cannot be renamed in place; changing labels is safe. Additional
JSON fields are retained, but do not become executable behavior.

Drag a right-hand new-link port to another node's left port, or use **Link…**.
The dialog offers compatible predicates and source/target pickers for nodes
outside the visible neighborhood. Predicate rows on nodes also support a
preferred relation. Reference rows are not editable links: edit their owning
relationship's qualifier metadata in the inspector.

Select a node or individual relationship and choose **Edit record…**. This is a
JSON editor, not yet a full form-based property inspector. **Schema…** edits the
kind registry, relation registry and views; incompatible changes are rejected
rather than deleting existing content. Validation errors explain what prevented
an edit. No write occurs when validation fails.

For a directed feeling, include the actual feeling and source holder:

```json
{
  "holder": "character.tess",
  "feeling": "feeling.resentment",
  "context": "event.concert_absence_02",
  "strength": 0.65,
  "notes": "Coexists with affection; does not determine the next action."
}
```

`perceived_as` uses the observer or audience as holder, not automatically the
person being judged. Other subjective predicates belong to their source
person. `has_relationship` requires `relationship_type`; `shared_interest_with`
requires `object` to identify the shared interest. `heard_from` can reference a
claim, and a loan can identify its object. Confidence/strength are numbers from
0 to 1. Optional evidence_mode is direct, reported, inferred or imagined.

The checked reference qualifiers are holder, context, object, feeling,
relationship_type and claim. Extra metadata remains inert. Symbolic
valid_from/valid_until strings are preserved without guessed calendar math;
numeric start_tick/end_tick receive an ordering check. Qualifiers and notes
are authoring context, not evaluated conditions.

Delete a node or relationship through the inspector. Node deletion confirms
how many dependent links will be removed, including metadata references.
View-focus and layout references are cleaned too. Undo/Redo retain 32 local
snapshots, including movement and catalog merges. They are atlas-local, not
Godot's global scene-edit history.

## Add the expansion without erasing your work

The original seed is preserved. `seed_extension.json` adds the new categories,
relations, entries and views. First use expands the combined seed in memory.
Once `data/atlas/hughes_atlas.json` exists, it is loaded as authored: no new seed
is automatically written over it.

Use **Add missing seed content…** to merge missing stable IDs explicitly. Existing
records, labels, schema choices, custom fields and layouts win. The combined
graph must validate before it replaces the in-memory document. The operation
is undoable and idempotent. It is additive, not a three-way synchronization:
deliberately deleted bundled entries will be re-added when it is requested.
Export before a large authoring change. See ATLAS_V02.md for the design details.

## Save, export and recover

Save writes the current document only after validation and an external-change
hash check. A temporary file is checked before installation. The previous file
is retained as `.bak` when replacing an existing save. Failure to replace it
attempts rollback and reports the backup location. No claim is made that this
multi-rename process is immune to a machine crash or concurrent writers.

Godot StringName keys created by dictionary shorthand are normalized to JSON
strings. Floats use full-precision serialization. Non-finite numbers, non-JSON
objects and integers outside the JSON reader's exact range are rejected rather
than silently corrupting metadata. JSON has one number type; validation and
tests distinguish preserved numeric values from int/float representation.

**Export…** writes a complete copy but does not change the active path or clear
its unsaved state. Opening a different graph requires saving the current one
first. **Reload** asks for confirmation, validates before replacing anything,
and remains undoable. A failed open keeps the current graph. An external edit
causes a stale-writer refusal: export a copy, then reconcile rather than forcing
a last-writer-wins overwrite.

Save explicitly before ending a session. The editor's external-data save
callback also saves dirty content. Disabling the plugin or closing the
standalone tool writes unsaved document state to
`user://hughes_atlas_recovery.json`. Godot's user-data-folder command locates
that directory. Recovery is not automatically restored; open it explicitly.
Unapplied text still inside an edit dialog is not part of the document, and
an abrupt process crash may occur before recovery is written.

## Checks and source organization

```sh
python tools/atlas_data.py
python tools/atlas_extended.py
python -m unittest discover -s tests -p 'test_*.py' -v
godot --headless --path . --script tests/atlas_smoke.gd
```

The first validator checks the unchanged base. The second checks the expanded
catalog. To export a new complete copy without Godot:

```sh
python tools/atlas_extended.py --export /your/new/path/hughes_atlas.json
```

The exporter refuses to overwrite an existing file. The Godot smoke exercises
real model, storage, query and UI callback paths; a passing headless run does
not establish graphical readability, manual mouse interaction or Windows saves.

The base core expands legacy seed definitions. The model facade owns catalog
composition, validation and merge. Storage owns JSON compatibility and guarded
writes. Queries own read-only traversal. The panel owns the visible authoring
commands. No layer chooses NPC behavior from possibility edges.

The next planning use is a school-week review: trace how duties, access,
partial witnessing and private expectations can intersect, including days
where nothing dramatic happens. Runtime scheduling, forgetting, dialogue
execution, emotional change and game integration remain separate future work.

Official references used:
- https://docs.godotengine.org/en/stable/classes/class_graphedit.html
- https://docs.godotengine.org/en/stable/classes/class_graphnode.html
- https://docs.godotengine.org/en/stable/classes/class_json.html
- https://docs.godotengine.org/en/stable/tutorials/plugins/editor/making_main_screen_plugins.html
