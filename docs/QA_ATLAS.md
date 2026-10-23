# Hughes Atlas 0.2 — observed verification

Date: 2026-10-23 (UTC)
Branch: `docs/repository-updates-2026-10-16`
Starting branch commit: `3fb13b65d185242d160cfc264bac130ca657adc2`
Recovered draft tree: `b8b20853caf42959a948e0582d1b107e2874bad0`
Verified code commit: `fb0911b4f4f406b055a67108a4705b7b10093204`

## Final observed run: PASS

Run: https://github.com/eyehaveewe-cyber/Hugheslike/actions/runs/39989391936
Job: https://github.com/eyehaveewe-cyber/Hugheslike/actions/runs/39989391936/job/120536905509

The job status, every step's conclusion and decoded logs were read. Subsequent
completion-report changes are documentation only; the code tested is identified
above. No local engine execution is claimed.

Environment: GitHub-hosted Ubuntu 24.04.5, Godot
`4.7.2.stable.official.ed1daf0bf`, downloaded from the official release. ZIP
SHA-256 verified as
`cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`.
The workflow has read-only contents permission and does not retain Git credentials.

## Results from the logs

`python3 tools/atlas_data.py` — PASS: unchanged base has 39 kinds, 96 relation
types, 483 nodes, 867 edges, nine views and zero unlinked entries.

`python3 tools/atlas_extended.py` — PASS: combined catalog has 53 kinds,
143 relation types, 691 nodes, 1,344 edges, fourteen views and zero unlinked
entries. Expansion is 14 kinds, 47 predicates, 208 nodes and 477 links.

`python3 -m unittest discover -s tests -p 'test_*.py' -v` — 40 tests PASS.
Coverage includes stable expansion, JSON roundtrip, IDs, endpoint kinds,
holders, reference types, scopes, confidence, numeric intervals, hierarchy
cycles, views/layouts, preserved original records, opposing feelings,
private beliefs, public credit versus contribution, former versus current
roles, required qualifiers and nondestructive/idempotent catalog merge.

`godot --headless --editor --path . --import` — PASS. The editor imported,
registered scripts and initialized the plugin without error markers in the log.

`godot --headless --path . --script tests/atlas_smoke.gd` — PASS, 45 checks.
Actual output: `Hughes Atlas native smoke: PASS (45 checks: model, storage,
queries, UI callbacks)`.

The native test validates the same expanded seed, rejects bad references,
merges without overwriting edits, saves/reads values with precision-sensitive
numbers, rejects stale writers, checks backups, rejects invalid JSON values,
checks directional/symmetric navigation, filters subjective holders, builds
real GraphEdit nodes and wires, applies an edit, undoes/redoes it, emits the
connection-dialog callback, inspects qualifier links, searches predicates,
traces a connection, deletes referenced content and restores it through Undo.

## Failures found and corrected in this pass

Recovery run 39986226903 passed the original 21 Python tests but failed native
parsing: an inferred Variant expression and a test constant named Panel that
shadowed a native class. The panel was explicitly typed and the test renamed.

Expansion run 39988761618 passed all 40 Python tests and native import. A native
roundtrip assertion failed on Godot/JSON representation differences. Storage
was strengthened with full-precision numbers and JSON-domain comparison rather
than allowing approximate numerical equality.

Run 39989147763 exposed StringName dictionary keys created by GDScript shorthand.
Storage now normalizes textual keys without dropping fields; the final run
passes. Non-finite data, unsupported objects and unsafe integer ranges are
rejected. A float precision probe and changed-number/boolean comparisons guard
against hiding actual data loss behind representation normalization.

## Not established by these tests

No hands-on graphical usability pass, screen-layout inspection, mouse gesture
verification, Windows file replacement/recovery test or original-game integration
was performed. No screenshot is claimed. Headless callbacks are not an image or
manual interaction test. Abrupt crashes during multi-step file replacement and
concurrent writers remain outside the verified guarantees.

The catalog's semantic/editorial quality is not proven by structural validation.
Variant conditions are often notes rather than executable expressions. The
holder lens is not an NPC/player knowledge-access system. No runtime social
simulation, schedule execution, emotional changes, forgetting, dialogue engine,
progression loop, original art import, main merge or deployment was tested or
implemented here.
