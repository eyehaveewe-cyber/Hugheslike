# Hughes Atlas 0.3 — working guide

The active catalogue has 61 categories, 177 relationship types, 1,072 entries,
2,358 links and 23 views. It is an authoring library, not a running town. All
views inspect one shared document, so the same person, duty, memory or object
can connect school, home, the grocery, bank and video store.

## Open and bring in the new content

Use Godot 4.7.2. Open this branch's `project.godot` and select Hughes Atlas at the
top of the editor. F5 opens the same interface standalone. The plugin is enabled
under Project Settings → Plugins. To add it to the separate game later, copy
`addons/hughes_atlas/` as a whole and test that integration; do not replace the
game's main scene, settings or saves.

A fresh atlas expands all bundled packs in memory. Once
`data/atlas/hughes_atlas.json` exists, the editor loads that authored document
instead. To update an existing saved atlas, use **Add missing seed content…**,
review, then Save. Existing records and layouts are preserved; the merge is
undoable and idempotent. It adds missing IDs rather than silently overwriting
or renaming your work.

## Explore

Choose Grocery store, Bank branch or Video store. Each has a second view for
its social or record/copy relationships. Across all three stores follows the
shared errand. Ruth: wages, privacy and groceries and Hannah: the return and
the record open worked examples. School and every previous view remain present.
New example names are biblical; old authored names have not been forcibly
changed. See COMMERCE_ATLAS.md for the actual scenario chains.

Global catalog search checks labels, IDs, descriptions and tags. Double-click
to focus an entry. One to three hops controls the local neighborhood. Disable
neighborhood focus to browse a selected view's domains. The kind filter applies
to the catalog; relation, meaning, direction and holder filters apply to graph
navigation. Clear the lenses when a desired connection seems hidden.

The canvas shows at most 90 matching nodes and reports the count. Hidden data
is not deleted. The right-hand inspector lists all incident assertions and
supported qualifier references, even when their endpoints are not visible.
Arrange saves positions for a view; Fit adjusts the visible graph's zoom.

Relation library searches predicate definitions and usage counts. Find
connection traces actual graph assertions, marking reverse traversal. It is a
navigation aid, not causal inference. Holder filtering is author-only; an
actual player/NPC knowledge interface must enforce observation and disclosure
separately. Show context/holder references reveals metadata wires without
pretending those wires are additional causal assertions.

## Author

New node opens JSON with a stable ID, readable label, registered kind, domain,
scope, description and tags. Change labels freely; existing IDs cannot be
renamed in place. Definitions and examples remain separate scopes. The property
editor is still JSON rather than a complete form-based inspector.

Drag a right-hand new-link port to a left-hand port, or use Link. Only compatible
predicates are offered. Both endpoints can also be chosen in the dialog, so
they need not be visible together. Select a node or a particular relationship
and Edit record; Schema edits kinds, relations and views. Invalid changes are
refused, not silently repaired by dropping data.

Feelings, beliefs and other subjective assertions need their actual holder.
For example, a directed feeling can use:

```json
{
  "holder": "character.hannah",
  "feeling": "feeling.resentment",
  "context": "event.hannah_taste_comment_03",
  "strength": 0.35,
  "notes": "Coexists with affection; does not command the next action."
}
```

Perceived-as uses the observer/audience as holder, not automatically the person
being judged. Other subjective predicates belong to their source person.
Supported checked references are holder, context, object, feeling,
relationship_type and claim. Confidence/strength range from 0 to 1. Optional
evidence_mode is direct, reported, inferred or imagined. Symbolic periods are
preserved without invented calendar math; numeric start/end ticks are checked
for order. Notes and conditions remain authored context, not code.

Parallel relationships can share endpoints but differ in holder, period or
context. The inspector retains each record even when the canvas shares a wire.
Delete individual records there. Node deletion confirms dependent links,
cleans supported references and can be undone. Undo/Redo retain 32 local
snapshots, including arrangements and catalogue merges; they are not Godot's
global scene-edit history.

## Save, export and recovery

Save validates and checks the on-disk hash before writing. A temporary file is
verified, the previous file is retained as `.bak`, and a stale writer is refused.
Export writes a full portable copy without changing the active path or clearing
its unsaved state. Open requires saving the current graph first. Reload asks
for confirmation and is undoable. A failed load preserves the current document.
Export a copy before reconciling external changes instead of overwriting them.

Save explicitly before ending a session. Editor external-data save also saves
dirty content. Plugin disable or normal standalone close writes unsaved document
state to `user://hughes_atlas_recovery.json`; locate it through Godot's user-data
folder command and open it explicitly. Unapplied edit-dialog text is not part
of the document, and sudden process/machine failure can precede recovery. The
multi-rename save process is not claimed crash-proof or concurrent-writer safe.

## Data packs and checks

Commerce packs live in `addons/hughes_atlas/packs/` and are composed through
`commerce_manifest.json`. Stable IDs bridge the packs; old source records remain
unchanged. A future program can target a compact pack or the complete expanded
JSON. The actual external-program adapter is not built; see CATALOG_PACKS.md.

```sh
python tools/atlas_data.py
python tools/atlas_extended.py
python tools/atlas_commerce.py
python tools/atlas_commerce.py --export NEW_FILE.json
python -m unittest discover -s tests -p 'test_*.py' -v
godot --headless --path . --script tests/atlas_smoke.gd
godot --headless --path . --script tests/atlas_commerce_smoke.gd
```

The first two validators preserve historical baselines; the third validates the
current combined catalogue. Exports refuse to overwrite files. Native commerce
checks can additionally compare Python and Godot expansion by setting
ATLAS_EXPECTED_JSON to a Python-exported document. CI does this comparison.

Read QA_COMMERCE.md for observed passing checks and remaining limits. Headless
callbacks establish neither visual readability nor manual mouse behavior.
No runtime transaction processing, account arithmetic, autonomous schedules,
knowledge propagation, dialogue execution or progression loop is implemented.
The complete previous working guide is preserved in ATLAS_GUIDE_V02.md.
