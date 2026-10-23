extends SceneTree
## Native smoke test supplied for Godot; do not report a pass without running it.
const Model = preload("res://addons/hughes_atlas/atlas_model.gd")
const Panel = preload("res://addons/hughes_atlas/atlas_panel.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var result := Model.read_seed()
	if result.has("error"):
		push_error(result.error)
		quit(1)
		return
	var doc := Model.expand_seed(result.data)
	check(Model.validate(doc).is_empty(), "Seed validation")
	check(doc.nodes.size() == 483 and doc.edges.size() == 867, "Seed counts")
	var bad := doc.duplicate(true)
	bad.edges[0].to = "missing.endpoint"
	check(not Model.validate(bad).is_empty(), "Reject missing endpoints")
	var file_path := "user://atlas_smoke_" + str(Time.get_ticks_usec()) + ".json"
	check(Model.save_atomic(doc, file_path, "").is_empty(), "Initial atomic save")
	var loaded := Model.read_json(file_path)
	check(loaded.has("data") and loaded.data == doc, "JSON save/read roundtrip")
	check(not Model.save_atomic(doc, file_path, "stale_hash").is_empty(), "External-change guard")
	var panel = Panel.new()
	root.add_child(panel)
	await process_frame
	panel.document = doc.duplicate(true)
	panel._refresh()
	check(panel.view_nodes.size() > 0, "GraphEdit has visible nodes")
	panel.set_focus("character.avery")
	panel.inspect_node("feeling.trust")
	check(panel.edge_list.item_count > 0, "Qualifier references are inspectable")
	var edited := panel.document.duplicate(true)
	edited.nodes[0].label = "Smoke edit"
	check(panel._commit(edited, "Smoke edit"), "Record edit callback")
	panel.undo()
	check(panel.document.nodes[0].label == doc.nodes[0].label, "Undo restores label")
	panel.redo()
	check(panel.document.nodes[0].label == "Smoke edit", "Redo restores edit")
	panel.show_link_dialog("character.avery", "character.jules", "feels_toward")
	panel.link_qualifiers.text = '{"feeling":"feeling.affection","holder":"character.avery"}'
	panel._add_link()
	check(panel.document.edges.size() == doc.edges.size() + 1, "Typed connection callback")
	panel.undo()
	check(panel.document.edges.size() == doc.edges.size(), "Undo connection")
	panel.dirty = false
	panel.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	if failures.is_empty():
		print("Hughes Atlas native smoke: PASS (model, storage, UI callbacks)")
	else:
		print("Hughes Atlas native smoke: FAIL: " + str(failures.size()))
	quit(0 if failures.is_empty() else 1)
