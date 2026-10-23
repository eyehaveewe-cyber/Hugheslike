# Hughes Atlas commerce — observed verification

Date: 2026-10-23 UTC
Branch: `docs/repository-updates-2026-10-16`
Starting commit: `a8eead3408b38ae1690c202d23d12d27578bba77`
Verified code/content commit: `d766bd629328e437a995c67f6a48afda0ccfbc77`

## Observed run: PASS

Run: https://github.com/eyehaveewe-cyber/Hugheslike/actions/runs/39994913207
Job: https://github.com/eyehaveewe-cyber/Hugheslike/actions/runs/39994913207/job/120555807387

The job status, individual step conclusions and decoded logs were read.
All steps completed successfully. The later completion commit changes only
documentation; it does not alter the code or catalogue identified above.
Execution was on GitHub-hosted Ubuntu 24.04.5 with Godot
`4.7.2.stable.official.ed1daf0bf`, not the local chat container. The workflow
verified the official engine ZIP's SHA-256, retained read-only repository
permissions and did not retain checkout credentials.

## Data validation

The unchanged v0.1 baseline passed: 39 kinds, 96 predicates, 483 entries,
867 connections, nine views and zero unlinked entries.

The unchanged v0.2 baseline passed: 53 kinds, 143 predicates, 691 entries,
1,344 connections, fourteen views and zero unlinked entries.

The current commerce catalogue passed: **61 kinds, 177 predicates, 1,072 entries,
2,358 connections, 23 views and zero unlinked entries**. Addition over v0.2:
8 kinds, 34 predicates, 381 entries, 1,014 connections and nine views.

New entry distribution: grocery 92; bank 83; video store 103; shared commerce
48; fictional worked examples 55. There are twelve new people. Incident-link
counts across domains overlap and must not be summed as unique connections.

## Python regression checks: 64 PASS

All 40 earlier tests still pass. The 24 new tests cover complete validation,
pack IDs, exact preservation of older records, connectedness, biblical names
for only the new cast, native-view definitions, located/respondable situations,
a shared errand, work versus physical copies, physical return versus processing,
custody intervals, account holder versus helper, pending availability versus
job-loss inference, private-record holders, business custody versus ownership,
contradictory records, simultaneous feelings, preservation/idempotence of merges,
repeatable expansion, JSON roundtrip, manifest traversal/duplicate rejection,
ordinary outcomes and the absence of external service execution.

Structural correctness does not establish every authored association as good
narrative design or as a validated theory of human behavior.

## Native engine checks

Godot 4.7.2 headless editor import: PASS. The scripts and plugin initialized
without the error markers monitored by the workflow.

`tests/atlas_smoke.gd`: **45 retained checks PASS**. This now explicitly loads
the v0.2 dataset for stable historical regression coverage of model, storage,
queries and UI callbacks. It retains the original exact v0.2 count assertions;
commerce has separate integration coverage rather than weakening that test.

`tests/atlas_commerce_smoke.gd`: **33 new checks PASS** against the full v0.3
catalogue. They cover manifest loading, validation, revision/provenance, new
cast, independently loadable v0.2, nondestructive/idempotent merge, layout
preservation, full-document save/reload, all three actual view-selection
callbacks and GraphEdit wires, shared itinerary traversal, account connections,
record inspection, typed account-link dialog, multiple physical copies, and
record editing/undo.

CI exported the Python-expanded catalogue and set ATLAS_EXPECTED_JSON for the
native test. The value-for-value comparison with Godot's expanded catalogue
passed. This includes IDs, nodes, links, qualifiers, scopes, views and pack
metadata, using the existing JSON-domain comparison for number representation.

Actual end markers:
`Hughes Atlas native smoke: PASS (45 checks: model, storage, queries, UI callbacks)`
`Hughes Atlas commerce smoke: PASS (33 checks)`

## Remaining limits

No graphical screenshot, manual mouse/keyboard usability check, Windows
persistence test or original-game integration was performed. Graph construction
and signal callbacks are not evidence of good screen layout. Recovery retains
the previous documented limitations around unapplied dialog text and sudden
crashes. No new guarantee of crash-proof or concurrent writes is made.

No actual bank service, account arithmetic, inventory economy, autonomous
queue, runtime NPC schedule, information-spread rule, dialogue execution,
playable store map, XP or progression was implemented. The banking examples
are explicitly fictional local arrangements, not current legal/financial advice.
The user's unnamed program was not connected and no compatibility was assumed.

No private game sources or art were imported/published, no main merge was
performed, and no deployment was made. The evidence applies to the requested
branch and verified code commit above.
