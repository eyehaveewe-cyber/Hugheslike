extends SceneTree
## Retained v0.2 model/UI regression; commerce integration has its own native test.
const Model = preload("res://addons/hughes_atlas/atlas_model.gd")
const AtlasPanel = preload("res://addons/hughes_atlas/atlas_panel.gd")
const Queries = preload("res://addons/hughes_atlas/atlas_queries.gd")
const Storage = preload("res://addons/hughes_atlas/atlas_storage.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var result: Dictionary = Model.read_seed(true, false)
	if result.has("error"):
		push_error(str(result.error))
		quit(1)
		return
	var doc: Dictionary = Model.expand_seed(result.data)
	var errors: Array[String] = Model.validate(doc)
	check(errors.is_empty(), "Expanded seed: " + "\n".join(errors))
	if not errors.is_empty():
		quit(1)
		return
	print("NATIVE CATALOG: %d kinds, %d relations, %d nodes, %d edges, %d views" % [doc.kinds.size(), doc.relations.size(), doc.nodes.size(), doc.edges.size(), doc.views.size()])
	check(doc.kinds.size() == 53 and doc.views.size() == 14, "Expanded category and view counts")
	check(doc.nodes.size() > 680 and doc.edges.size() > 1200, "Expanded content is loaded")
	var bad: Dictionary = doc.duplicate(true)
	bad.edges[0].to = "missing.endpoint"
	check(not Model.validate(bad).is_empty(), "Reject missing endpoint")
	bad = doc.duplicate(true)
	for edge in bad.edges:
		if edge.relation == "holds_belief":
			edge.qualifiers.holder = []
			break
	check(not Model.validate(bad).is_empty(), "Malformed holder returns errors rather than crashing")
	var base_result: Dictionary = Model.read_seed(false)
	var base: Dictionary = Model.expand_seed(base_result.data)
	check(base.nodes.size() == 483 and base.edges.size() == 867, "Original catalog preserved")
	base.nodes[0].label = "Authored label to preserve"
	base.layout = {"school:place.school": {"place.school": [123, 456]}}
	var merged: Dictionary = Model.merge_missing(base, doc)
	check(not merged.has("error"), "Merge missing catalog content")
	if not merged.has("error"):
		check(merged.data.nodes[0].label == "Authored label to preserve", "Merge preserves label")
		check(merged.data.layout == base.layout, "Merge preserves layout")
		var again: Dictionary = Model.merge_missing(merged.data, doc)
		check(again.data == merged.data, "Catalog merge is idempotent")
	var file_path: String = "user://atlas_smoke_" + str(Time.get_ticks_usec()) + ".json"
	doc.nodes[0]["precision_probe"] = 0.12345678901234567
	check(Model.save_atomic(doc, file_path, "").is_empty(), "Initial guarded save")
	var loaded: Dictionary = Model.read_json(file_path)
	check(loaded.has("data") and Storage.json_equal(loaded.data, doc), "JSON save/read preserves all values (JSON number semantics)")
	check(loaded.data.nodes[0].precision_probe == doc.nodes[0].precision_probe, "Exact float precision preserved")
	check(loaded.data.schema_version == doc.schema_version, "Schema version value preserved")
	check(not Storage.json_equal({"value": 0.55}, {"value": 0.55000001}), "Roundtrip comparator detects changed numbers")
	check(not Storage.json_equal({"value": true}, {"value": 1}), "Booleans are not numbers")
	check(not Storage.json_problem({"bad": INF}).is_empty(), "Reject infinity")
	check(not Storage.json_problem({"bad": NAN}).is_empty(), "Reject NaN")
	check(not Storage.json_problem({"bad": 9007199254740992}).is_empty(), "Reject non-exact integer range")
	check(not Model.save_atomic(doc, file_path, "stale_hash").is_empty(), "Reject stale writer")
	var hash: String = FileAccess.get_file_as_string(file_path).sha256_text()
	check(Model.save_atomic(doc, file_path, hash).is_empty(), "Save with correct prior hash")
	check(FileAccess.file_exists(file_path + ".bak"), "Previous disk version retained")
	var filter: Dictionary = {"direction": "out", "relation": "carries"}
	var path_check: Dictionary = Queries.shortest_path(doc, "character.tess", "prop.old_radio", filter)
	check(path_check.found and path_check.steps.size() == 1, "Directed one-link path")
	check(not Queries.shortest_path(doc, "prop.old_radio", "character.tess", filter).found, "No invented inverse possession")
	filter.direction = "both"
	check(Queries.shortest_path(doc, "prop.old_radio", "character.tess", filter).found, "Explicit both-direction navigation")
	filter = {"relation": "shared_interest_with", "direction": "out"}
	check(Queries.shortest_path(doc, "character.tess", "character.mara", filter).found, "Declared symmetric links traverse both ways")
	var no_refs: Array[Dictionary] = Queries.arcs(doc, {"qualifiers": false})
	var refs: Array[Dictionary] = Queries.arcs(doc, {"qualifiers": true})
	check(refs.size() > no_refs.size(), "Optional qualifier-reference arcs")
	var holder_arcs: Array[Dictionary] = Queries.arcs(doc, {"semantics": "subjective", "holder": "character.tess"})
	var indexed_edges: Dictionary = Model.index_by_id(doc.edges)
	check(not holder_arcs.is_empty(), "Holder lens retains assertions")
	var holder_ok: bool = true
	for arc in holder_arcs:
		if indexed_edges[arc.edge_id].qualifiers.holder != "character.tess":
			holder_ok = false
	check(holder_ok, "Holder lens does not mix subjective owners")
	var mixed: Array = doc.edges.filter(func(edge): return edge.from == "character.tess" and edge.to == "character.rowan" and edge.relation == "feels_toward")
	check(mixed.size() == 2, "Parallel affection and resentment preserved")
	var panel = AtlasPanel.new()
	root.add_child(panel)
	await process_frame
	panel.document = doc.duplicate(true)
	panel._refresh()
	check(panel.view_nodes.size() > 0, "GraphEdit constructs visible nodes")
	check(panel.graph.get_connection_list().size() > 0, "GraphEdit constructs wires")
	panel.set_focus("character.tess")
	panel.inspect_node("feeling.resentment")
	check(panel.edge_list.item_count > 0, "Qualifier-reference inspection")
	var edited: Dictionary = panel.document.duplicate(true)
	edited.nodes[0].label = "Smoke edit"
	check(panel._commit(edited, "Smoke edit"), "Record edit callback")
	panel.undo()
	check(panel.document.nodes[0].label == doc.nodes[0].label, "Undo edit")
	panel.redo()
	check(panel.document.nodes[0].label == "Smoke edit", "Redo edit")
	panel.show_link_dialog("character.avery", "character.jules", "feels_toward")
	panel.link_qualifiers.text = '{"feeling":"feeling.affection","holder":"character.avery"}'
	panel.link_dialog.confirmed.emit()
	check(panel.document.edges.size() == doc.edges.size() + 1, "Connection dialog callback")
	panel.undo()
	check(panel.document.edges.size() == doc.edges.size(), "Undo connection")
	panel.qualifier_toggle.button_pressed = true
	panel.set_focus("feeling.resentment")
	check(panel.view_nodes.size() > 1, "Qualifier lens makes a feeling's connections visible")
	panel.show_relations()
	panel.relation_search.text = "appraisal"
	panel._refresh_relations()
	check(panel.relation_list.item_count > 0, "Relationship browser search")
	panel.relation_dialog.hide()
	panel.clear_lenses()
	panel.set_focus("character.mara")
	panel.inspect_node("prop.old_radio")
	panel.show_path_dialog()
	panel.trace_path()
	check("assertion:" in panel.path_result.text, "Path dialog traces an actual authored connection")
	panel.path_dialog.hide()
	panel.pending_delete.assign(["feeling.resentment"])
	panel._confirm_delete()
	check(not panel.nodes_by_id.has("feeling.resentment"), "Guarded deletion callback")
	check(Model.validate(panel.document).is_empty(), "Deletion removes reference dependencies")
	panel.undo()
	check(panel.nodes_by_id.has("feeling.resentment"), "Undo restores deleted dependencies")
	panel.arrange_visible()
	check(not panel.document.layout.is_empty(), "Node arrangement persists in document")
	panel.dirty = false
	panel.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(file_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path + suffix))
	if failures.is_empty():
		print("Hughes Atlas native smoke: PASS (%d checks: model, storage, queries, UI callbacks)" % checks)
	else:
		print("Hughes Atlas native smoke: FAIL: " + str(failures.size()))
	quit(0 if failures.is_empty() else 1)
