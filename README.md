# Hugheslike — Hughes Atlas development workspace

**[Recent work, checks and limitations: UPDATES.txt](UPDATES.txt)**

Hughes Atlas is a Godot GraphEdit authoring workspace for interconnected people,
places, actions and experiences. The interrupted draft has been recovered into
this branch. The separate playable foundation and its art are NOT imported.

The recovered seed describes 39 kinds, 96 relation types, 483 nodes and 867
links. These are authored definitions and fictional examples, not executable
NPC behaviors. Search, neighborhood focus, typed connection dialogs, record
editing, undo/redo and JSON persistence are included in the source.

Open `project.godot`, choose **Hughes Atlas**, or use F5 for the standalone tool.
The intended test engine is Godot 4.7.2. Native behavior is under verification;
see the actual [Actions runs](../../actions) and [QA record](docs/QA_ATLAS.md).
Earlier draft claims of passing tests are not treated as evidence in this
recovery. They must be supported by a newly observed test result.

[Working guide](docs/ATLAS_GUIDE.md) · [Relationship design](docs/RELATIONSHIP_DESIGN.md)

```sh
python tools/atlas_data.py
python -m unittest discover -s tests -p 'test_*.py' -v
godot --headless --path . --script tests/atlas_smoke.gd
```

No running town, NPC simulation, private art import, main merge or deployment.
The previous foundation README is preserved byte-for-byte in
[FOUNDATION_README_ARCHIVE.md](docs/FOUNDATION_README_ARCHIVE.md); its game and
verification descriptions do not describe this tools-only checkout.
