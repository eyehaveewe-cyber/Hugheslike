extends SceneTree
## Native v0.3 integration; actual GraphEdit views, save/reload and cross-language data.
const Model = preload("res://addons/hughes_atlas/atlas_model.gd")
const Storage = preload("res://addons/hughes_atlas/atlas_storage.gd")
const Queries = preload("res://addons/hughes_atlas/atlas_queries.gd")
const AtlasPanel = preload("res://addons/hughes_atlas/atlas_panel.gd")
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
	var result: Dictionary = Model.read_seed()
	check(not result.has("error"), "Commerce packs load: " + str(result.get("error", "")))
	if result.has("error"):
		quit(1)
		return
	var doc: Dictionary = Model.expand_seed(result.data)
	var errors: Array[String] = Model.validate(doc)
	check(errors.is_empty(), "Commerce validation: " + "\n".join(errors))
	if not errors.is_empty():
		quit(1)
		return
	print("NATIVE COMMERCE: %d kinds, %d relations, %d nodes, %d edges, %d views" % [doc.kinds.size(), doc.relations.size(), doc.nodes.size(), doc.edges.size(), doc.views.size()])
	check(doc.kinds.size() == 61 and doc.views.size() == 23, "Eight new kinds and nine new views")
	check(doc.catalog_revision == "0.3" and doc.catalog_packs.size() == 5, "Revision and pack provenance")
	var nodes: Dictionary = Model.index_by_id(doc.nodes)
	var people: Array = doc.nodes.filter(func(node): return node.kind == "character" and node.domain == "commerce_examples")
	check(people.size() == 12, "Twelve new fictional people")
	check(str(nodes["character.ruth"].label).begins_with("Ruth,"), "Biblical cast name")
	var expected_path: String = OS.get_environment("ATLAS_EXPECTED_JSON")
	if not expected_path.is_empty():
		var expected: Dictionary = Model.read_json(expected_path)
		check(expected.has("data") and Storage.json_equal(doc, expected.get("data", {})), "Python and Godot expand identical catalog values")
	else:
		print("Cross-language comparison NOT RUN: ATLAS_EXPECTED_JSON not set.")
	var old_result: Dictionary = Model.read_seed(true, false)
	var old: Dictionary = Model.expand_seed(old_result.data)
	check(old.nodes.size() == 691 and old.edges.size() == 1344, "Previous catalog remains independently loadable")
	old.nodes[0].label = "Keep my edited label"
	old.layout = {"personal": {"place.school": [23, 37]}}
	var combined: Dictionary = Model.merge_missing(old, doc)
	check(not combined.has("error"), "Merge adds commerce without invalidating previous graph")
	if combined.has("data"):
		check(combined.data.nodes[0].label == "Keep my edited label", "Merge preserves existing labels")
		check(combined.data.layout == old.layout, "Merge preserves authored layout")
		check(combined.data.catalog_packs == doc.catalog_packs, "Merge records pack provenance")
		var again: Dictionary = Model.merge_missing(combined.data, doc)
		check(again.has("data") and Storage.json_equal(again.data, combined.data), "Commerce merge is idempotent")
	var save_path: String = "user://commerce_smoke_" + str(Time.get_ticks_usec()) + ".json"
	check(Model.save_atomic(doc, save_path, "").is_empty(), "Save full commerce graph")
	var saved: Dictionary = Model.read_json(save_path)
	check(saved.has("data") and Storage.json_equal(saved.data, doc), "Reload retains every commerce assertion")
	var panel = AtlasPanel.new()
	root.add_child(panel)
	await process_frame
	panel.document = doc.duplicate(true)
	panel._refresh()
	for store in ["grocery", "bank", "video_store"]:
		var index: int = -1
		for i in range(doc.views.size()):
			if doc.views[i].id == store:
				index = i
		check(index >= 0, store + " view registered")
		if index >= 0:
			panel.view_picker.select(index)
			panel.view_picker.item_selected.emit(index)
			await process_frame
			check(panel.focus_id == "place." + store and panel.view_nodes.has("place." + store), store + " view callback selects its root")
			check(panel.graph.get_connection_list().size() > 0, store + " GraphEdit wires exist")
		var route: Dictionary = Queries.shortest_path(doc, "routine.three_stop_errand", "place." + store, {"relation":"commerce_schedule_includes", "direction":"out"})
		check(route.found and route.steps.size() == 1, store + " is part of shared itinerary")
	panel.clear_lenses()
	panel.set_focus("character.ruth")
	check(panel.view_nodes.has("account.ruth_bank_03"), "A person connects to account ownership")
	panel.inspect_node("record.ruth_availability_03")
	check(panel.edge_list.item_count > 0, "Private record's actual assertions are inspectable")
	panel.show_link_dialog("character.hannah", "account.naomi_video_03", "commerce_authorized_on")
	check(panel.link_relation.item_count > 0, "New typed account connection is authorable")
	panel.link_dialog.hide()
	panel.set_focus("catalog_item.film_lake")
	check(panel.view_nodes.has("prop.video_sample_copy_a") and panel.view_nodes.has("prop.video_sample_copy_b"), "Film focus exposes distinct physical copies")
	panel.inspect_node("character.hannah")
	var edit: Dictionary = panel.document.duplicate(true)
	for node in edit.nodes:
		if node.id == "character.hannah":
			node["notes_for_future_plugin"] = "Data-only extension survives editing and export."
	check(panel._commit(edit, "Commerce fixture edit"), "Commerce record edit remains valid")
	panel.undo()
	check(not panel.nodes_by_id["character.hannah"].has("notes_for_future_plugin"), "Undo preserves the original fictional fixture")
	panel.dirty = false
	panel.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	if failures.is_empty():
		print("Hughes Atlas commerce smoke: PASS (%d checks)" % checks)
	else:
		print("Hughes Atlas commerce smoke: FAIL: " + str(failures.size()))
	quit(0 if failures.is_empty() else 1)
