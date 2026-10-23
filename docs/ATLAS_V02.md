# Hughes Atlas 0.2 — more connections, usable ways to inspect them

This pass recovers the unfinished GraphEdit authoring tool and expands it. It
remains a development library, not a social simulation, a player knowledge
screen or a generated town. No progression system is introduced.

## New character layers

Interests, preferences, habits, coping strategies, personal boundaries, bodily
states, appraisals, expectations, practical constraints, occasions,
communication channels, interaction patterns, self-images and life transitions
join the existing roles, history, feelings, moods, actions, memories and places.

The useful distinctions are concrete. Enjoying music does not establish skill.
Wanting to attend a concert does not mean a parent can leave work. Receiving a
message is different from the sender assuming it arrived. A person can feel
affection and resentment toward the same person at the same time. Public
support can coexist with private disagreement. Receiving credit is separate
from contributing work, and bearing a cost is separate from causing it.

## Four new people and connected cases

Rowan is a teacher, parent and caregiver who sees themself as reliable. Tess is
Rowan's teenage child, a student worker and musician. A cover shift and delayed
message intersect with a promised concert visit. Tess remembers an empty seat
and forms an interpretation before hearing the explanation. The atlas records
these separately; it does not force reconciliation or broadcast private facts.

Mara is a retired driver with repair and music interests, a preference for
independent help and a privately meaningful anniversary. Arun, a librarian and
choir regular, offers a ride publicly. Their appraisals differ. Mara and Tess
also repair an old radio: a mundane shared activity that need not become a
revelation scene or a friendship reward.

Avery and Tess contribute to a concert poster, but public credit is uneven.
The record distinguishes participation, recognition, private feeling, memory
and a possible later correction. Someone can support a friend publicly and
remain privately hurt.

Every new record is an authored definition or explicitly fictional example.
The dates of fictional events are symbolic or relative unless an author adds
specific times. Possibility edges are proposed associations, never executable
behavior, diagnostic rules or universal emotional outcomes.

## Navigate without showing the entire town at once

The catalog search remains global. Double-click a record to focus a one-, two-
or three-hop neighborhood. The canvas caps visible nodes at 90 without
removing hidden data. The inspector always lists the selected node's full set
of relationships, including references in qualifiers.

The new relation and meaning filters separate structure, authored fact,
subjective assertion, local norm, temporal ordering, possibility and design
association. Direction can be incoming, outgoing or both. Declared symmetric
relations navigate in both directions without fabricating reciprocal feelings.

A holder lens shows one person's subjective assertions. It is an authoring
filter, NOT a security boundary: objective and structural authoring records
remain visible. It must never be presented as everything a player or NPC knows.

Turn on **Show context / holder references** to see how a feeling, context or
knowledge holder participates in qualified links. These wires are marked as
references, not ordinary causal or social assertions. Change their metadata in
the relationship inspector rather than drawing an ambiguous replacement wire.

**Relation library…** searches predicate names, explanations, source/target kinds
and meanings, including predicates not yet used by the seed. It shows use counts.
**Find connection…** traces a shortest graph connection, using current filters,
up to eight hops. Every step names the actual assertion. This is navigation,
not a causal explanation, proof of truth or evidence of awareness.

## Keep existing authoring work

The base seed remains unchanged. A separate additive catalog pack extends it.
An existing saved graph is loaded as-is and is never silently reseeded.
**Add missing seed content…** explicitly merges missing IDs after confirmation.
Existing records, custom fields, labels, schema edits and layout positions win.
An incompatible combined graph is rejected. The merge is undoable and
idempotent. It is additive: deliberately deleted bundled entries will be added
back when this button is used. Export a copy before a large authoring change.

The base model owns legacy expansion/storage validation; the catalog boundary
owns additive loading, qualifier requirements and merge rules; pure query code
owns graph traversal; the panel owns presentation and user commands. Neither
queries nor the panel runs NPC decisions. This keeps an authoring association
from silently becoming a runtime rule.

## Run checks

```sh
python tools/atlas_data.py
python tools/atlas_extended.py
python -m unittest discover -s tests -p 'test_*.py' -v
godot --headless --path . --script tests/atlas_smoke.gd
```

The first validator checks the preserved original seed; the second checks the
combined catalog. Use `python tools/atlas_extended.py --export NEW_FILE.json`
to write an expanded copy; it refuses to overwrite an existing file. Native
checks exercise the real GraphEdit and dialogs through their callbacks, but do
not substitute for a human visual pass or Windows persistence checks.

Read QA_ATLAS.md and the Actions logs for observed results. Test code and a
workflow definition are not themselves evidence of a passing run.
