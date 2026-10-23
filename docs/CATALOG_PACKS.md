# Data-pack boundary for a future authoring plugin

The user's other program has not been identified or connected. This describes
the format it could target; it is not an implemented adapter or a claim of
compatibility with an unknown API. The existing GraphEdit editor remains the
authoring interface.

## Why data packs rather than generated Godot scenes

A future tool should contribute definitions and assertions, not generate scene
nodes or inject scripts. Graph layout, content meaning and runtime execution
are different concerns. Stable IDs let the author reorganize the canvas without
changing what an assertion means. JSON can also be reviewed without the engine.

An alternative would be to make each institution its own scene-owned database.
That would duplicate people, feelings and household commitments across stores.
The selected approach adds all three packs to one shared document, then uses
views to inspect it. Another alternative, a remote graph database, adds a service
and permissions problem without being necessary for this authoring pass.

## Compact authoring-pack shape

Each local pack is a JSON object with a distinct `pack_id`. Optional arrays are
`kinds`, `relations`, `groups`, `links`, and `views`. Missing sections mean no
additions; a section of the wrong type is rejected. Names and descriptions are
ordinary text, not commands. The manifest names local `.json` basenames only;
path traversal, duplicate filenames and duplicate pack identifiers are refused.

A group supplies a registered kind, domain, definition/example scope and rows:

```json
{
  "pack_id": "example_pack",
  "groups": [{
    "kind": "role",
    "domain": "example_shop",
    "scope": "definition",
    "rows": [["example_clerk", "Example clerk", "Describe the responsibility."]]
  }],
  "links": [["role.example_clerk", "works_at", "institution.grocery"]]
}
```

Rows are `[id suffix, display label, description]`. Full node ID is
`kind.suffix`. A link row is `[source IDs, relation ID, target IDs, optional
qualifiers]`. Space-separated source and target IDs expand to their Cartesian
pair set deliberately; they are not natural-language lists. Use one pair when
individual contexts differ. An `id_suffix` in qualifiers distinguishes repeated
seed assertions with the same endpoints and predicate. Relations declare source
kinds, target kinds, meaning and symmetry; a new relation is not executable AI.

A new source pack must be added to the local manifest by an explicit repository
change. Merely placing an arbitrary file on disk does not execute or load it.
`atlas_model.gd` owns composition and document validation. The same compact
content is checked by `tools/atlas_commerce.py`; CI compares the actual Python
and Godot expanded documents value for value.

## Expanded-document boundary

The editor's Open JSON / Export controls use the existing schema-version-1
expanded document: kinds, relations, nodes, edges, views and layouts. Edges
carry stable IDs, endpoints, predicate, scope and qualifier metadata. A future
plugin can produce this full form instead of compact packs. It must include
every referenced definition and pass the existing validator before becoming
an active authoring document.

Do not treat an external program's generated suggestions as approved authored
facts. Stage and validate them first. Existing record IDs win during the bundled
missing-content merge; this avoids silently replacing the author's text. That
merge is not a general conflict-resolution or live synchronization system.
A real adapter will need an explicit preview/accept workflow and a policy for
intentional edits, deletions and ID collisions. Neither is claimed here.

Keep the following distinctions at this boundary:

- Definitions versus fictional examples and proposed scenarios.
- World occurrence versus a receipt, ledger, interpretation or recollection.
- Physical item versus catalogue work and its different copies.
- Request, authorization, custody, ownership, fulfillment and administrative entry.
- Private holder versus an audience that has actually received information.

A graph path is navigation, not an inferred causal chain or permission grant.
An author can see all fixture records; an eventual player interface must not
inherit that omniscience. New optional metadata survives editing but remains
inert unless a separate, explicit runtime contract is designed and tested.

## Practical handoff checklist

Supply the program's actual export format and integration boundary when it is
available. Map its stable entities and relationships to these definitions,
validate references and private holders, preview changes against an existing
authored graph, and preserve a rollback copy. Do not introduce account-service
connections, credentials, runtime script evaluation or executable content to
solve a planning-data import problem.

New example people in the commerce pack use biblical first names. This is an
authoring preference, not a validation rule imposed on the user's own future
characters. Display labels can change without renaming stable IDs.
