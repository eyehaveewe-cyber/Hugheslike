@tool
extends Control
## Shared editor/standalone workspace. It authors assertions, never executes NPC AI.
const Model = preload("atlas_model.gd")
const Queries = preload("atlas_queries.gd")
const MAX_VISIBLE := 90
const HISTORY_LIMIT := 32
var document: Dictionary = {}
var dirty: bool = false
var path: String = Model.DEFAULT_PATH
var disk_hash: String = ""
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var nodes_by_id: Dictionary = {}
var relations_by_id: Dictionary = {}
var view_nodes: Dictionary = {}
var port_relations: Dictionary = {}
var focus_id: String = "place.school"
var selected_id: String = ""
var selected_collection: String = "nodes"
var rebuilding: bool = false
var pending_delete: Array[String] = []
var edit_mode: String = ""
var edit_original_id: String = ""
var last_report: String = ""
var graph: GraphEdit
var view_picker: OptionButton
var scope_picker: OptionButton
var kind_picker: OptionButton
var relation_picker: OptionButton
var semantics_picker: OptionButton
var holder_picker: OptionButton
var direction_picker: OptionButton
var search: LineEdit
var catalog: ItemList
var focus_toggle: CheckBox
var qualifier_toggle: CheckBox
var depth: SpinBox
var details: TextEdit
var edge_list: ItemList
var title_label: Label
var status: Label
var editor_dialog: ConfirmationDialog
var editor_text: CodeEdit
var delete_dialog: ConfirmationDialog
var reload_dialog: ConfirmationDialog
var merge_dialog: ConfirmationDialog
var export_dialog: FileDialog
var open_dialog: FileDialog
var error_dialog: AcceptDialog
var link_dialog: ConfirmationDialog
var link_from: OptionButton
var link_to: OptionButton
var link_relation: OptionButton
var link_qualifiers: CodeEdit
var link_explanation: Label
var relation_dialog: AcceptDialog
var relation_search: LineEdit
var relation_list: ItemList
var relation_details: TextEdit
var path_dialog: AcceptDialog
var path_from: OptionButton
var path_to: OptionButton
var path_result: TextEdit

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	if not Engine.is_editor_hint():
		OS.low_processor_usage_mode = true
		get_tree().auto_accept_quit = false
	load_document(path)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not Engine.is_editor_hint():
		write_recovery()
		get_tree().quit()

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _label(parent: Node, text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	parent.add_child(label)
	return label

func _option(parent: Node, labels: Array[String]) -> OptionButton:
	var picker: OptionButton = OptionButton.new()
	for text in labels:
		picker.add_item(text)
	parent.add_child(picker)
	return picker

func _build_ui() -> void:
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_label(root, "HUGHES ATLAS  /  People, places and the connections between them")
	var toolbar: HFlowContainer = HFlowContainer.new()
	root.add_child(toolbar)
	view_picker = _option(toolbar, [])
	view_picker.item_selected.connect(_change_view)
	_button(toolbar, "Save", save_document)
	_button(toolbar, "Open…", func(): open_dialog.popup_centered_ratio(0.75))
	_button(toolbar, "Export…", func(): export_dialog.popup_centered_ratio(0.75))
	_button(toolbar, "Reload", func(): reload_dialog.popup_centered())
	_button(toolbar, "Undo", undo)
	_button(toolbar, "Redo", redo)
	_button(toolbar, "New node", new_node)
	_button(toolbar, "Link…", func(): show_link_dialog(selected_node_id(), ""))
	_button(toolbar, "Relation library…", show_relations)
	_button(toolbar, "Find connection…", show_path_dialog)
	_button(toolbar, "Add missing seed content…", func(): merge_dialog.popup_centered())
	_button(toolbar, "Schema…", edit_schema)
	_button(toolbar, "Validate", _report_validation)
	var filters: HFlowContainer = HFlowContainer.new()
	root.add_child(filters)
	focus_toggle = CheckBox.new()
	focus_toggle.text = "Focus neighborhood"
	focus_toggle.button_pressed = true
	filters.add_child(focus_toggle)
	focus_toggle.toggled.connect(func(_value): _render_graph())
	_label(filters, "Hops")
	depth = SpinBox.new()
	depth.min_value = 1
	depth.max_value = 3
	depth.value = 1
	filters.add_child(depth)
	depth.value_changed.connect(func(_value): _render_graph())
	scope_picker = _option(filters, ["All content", "Definitions only", "Example links + their concepts"])
	scope_picker.item_selected.connect(func(_index): _render_graph())
	direction_picker = _option(filters, ["Both directions", "Outgoing", "Incoming"])
	direction_picker.item_selected.connect(func(_index): _render_graph())
	qualifier_toggle = CheckBox.new()
	qualifier_toggle.text = "Show context / holder references"
	qualifier_toggle.tooltip_text = "Reference wires describe metadata on a relationship, not another causal or social assertion."
	filters.add_child(qualifier_toggle)
	qualifier_toggle.toggled.connect(func(_value): _render_graph())
	_button(filters, "Focus inspected", func(): set_focus(selected_node_id()))
	_button(filters, "Arrange", arrange_visible)
	_button(filters, "Fit", fit_visible)
	var lenses: HFlowContainer = HFlowContainer.new()
	root.add_child(lenses)
	relation_picker = _option(lenses, ["All relations"])
	relation_picker.item_selected.connect(func(_index): _render_graph())
	semantics_picker = _option(lenses, ["All meanings", "structural", "fact", "temporal", "subjective", "normative", "possibility", "design"])
	semantics_picker.item_selected.connect(func(_index): _render_graph())
	holder_picker = _option(lenses, ["All holders (author view)"])
	holder_picker.item_selected.connect(func(_index): _render_graph())
	_button(lenses, "Clear lenses", clear_lenses)
	var explanation: Label = _label(root, "Authoring view, not a player's knowledge. Holder filtering hides other subjective assertions, not all unknown facts. Possibility links do not run behavior.")
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var split: HSplitContainer = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size.x = 240
	split.add_child(left)
	_label(left, "CATALOG — double-click to focus")
	search = LineEdit.new()
	search.placeholder_text = "Search names, IDs, descriptions, tags…"
	left.add_child(search)
	search.text_changed.connect(func(_text): _refresh_catalog())
	kind_picker = _option(left, ["All kinds"])
	kind_picker.item_selected.connect(func(_index): _refresh_catalog())
	catalog = ItemList.new()
	catalog.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(catalog)
	catalog.item_selected.connect(func(index): inspect_node(str(catalog.get_item_metadata(index))))
	catalog.item_activated.connect(func(index): set_focus(str(catalog.get_item_metadata(index))))
	var center: HSplitContainer = HSplitContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(center)
	graph = GraphEdit.new()
	graph.custom_minimum_size.x = 320
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.minimap_enabled = true
	graph.show_arrange_button = false
	graph.right_disconnects = false
	center.add_child(graph)
	graph.node_selected.connect(func(node):
		if node is GraphNode and not rebuilding:
			inspect_node(str(node.get_meta("atlas_id"))))
	graph.connection_request.connect(_connection_request)
	graph.delete_nodes_request.connect(_delete_nodes_request)
	graph.end_node_move.connect(_finish_move)
	graph.disconnection_request.connect(func(_a, _b, _c, _d): _message("Select an individual relationship in the inspector to remove it; one wire can represent multiple contexts."))
	var right: VBoxContainer = VBoxContainer.new()
	right.custom_minimum_size.x = 320
	center.add_child(right)
	title_label = _label(right, "Select a node or relationship")
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions: HFlowContainer = HFlowContainer.new()
	right.add_child(actions)
	_button(actions, "Edit record…", edit_selected)
	_button(actions, "Delete…", delete_selected)
	_button(actions, "Copy ID", func(): DisplayServer.clipboard_set(selected_id))
	_button(actions, "Other end", focus_other_end)
	details = TextEdit.new()
	details.editable = false
	details.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	details.custom_minimum_size.y = 200
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(details)
	_label(right, "ALL CONNECTIONS — including hidden references")
	edge_list = ItemList.new()
	edge_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edge_list.custom_minimum_size.y = 160
	right.add_child(edge_list)
	edge_list.item_selected.connect(func(index): inspect_edge(str(edge_list.get_item_metadata(index))))
	status = _label(root, "Loading…")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_dialogs()

func _build_dialogs() -> void:
	error_dialog = AcceptDialog.new()
	error_dialog.title = "Atlas: change not applied"
	add_child(error_dialog)
	editor_dialog = ConfirmationDialog.new()
	editor_dialog.title = "Edit record — stable ID, kind, scope, description and optional metadata"
	editor_dialog.dialog_hide_on_ok = false
	editor_dialog.get_ok_button().text = "Apply"
	add_child(editor_dialog)
	editor_text = CodeEdit.new()
	editor_text.custom_minimum_size = Vector2(760, 500)
	editor_dialog.add_child(editor_text)
	editor_dialog.confirmed.connect(_apply_editor)
	delete_dialog = ConfirmationDialog.new()
	add_child(delete_dialog)
	delete_dialog.confirmed.connect(_confirm_delete)
	reload_dialog = ConfirmationDialog.new()
	reload_dialog.dialog_text = "Reload on-disk content? Unsaved changes will be replaced after validation; Undo can restore them."
	add_child(reload_dialog)
	reload_dialog.confirmed.connect(func(): load_document(path, true))
	merge_dialog = ConfirmationDialog.new()
	merge_dialog.dialog_text = "Add missing bundled categories, nodes, relationships and views? Existing records, edits and layouts win. Nothing is deleted. Undo is available."
	add_child(merge_dialog)
	merge_dialog.confirmed.connect(merge_catalog)
	export_dialog = FileDialog.new()
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.filters = PackedStringArray(["*.json ; Atlas JSON"])
	export_dialog.current_file = "hughes_atlas_copy.json"
	add_child(export_dialog)
	export_dialog.file_selected.connect(_export_copy)
	open_dialog = FileDialog.new()
	open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.filters = PackedStringArray(["*.json ; Atlas JSON"])
	add_child(open_dialog)
	open_dialog.file_selected.connect(func(new_path):
		if dirty:
			_error("Save your current graph before opening another document. Export preserves a copy but does not mark the current graph saved.")
		else:
			load_document(new_path))
	link_dialog = ConfirmationDialog.new()
	link_dialog.title = "Typed relationship — source → meaning → target"
	link_dialog.dialog_hide_on_ok = false
	add_child(link_dialog)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(760, 490)
	link_dialog.add_child(box)
	_label(box, "Source")
	link_from = _option(box, [])
	_label(box, "Target")
	link_to = _option(box, [])
	_label(box, "Compatible relation")
	link_relation = _option(box, [])
	link_from.item_selected.connect(func(_index): _refresh_link_relations())
	link_to.item_selected.connect(func(_index): _refresh_link_relations())
	link_relation.item_selected.connect(func(_index): _describe_link())
	link_explanation = _label(box, "")
	link_explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(box, "Qualifiers JSON: holder, feeling, context, object, confidence, dates, notes…")
	link_qualifiers = CodeEdit.new()
	link_qualifiers.custom_minimum_size.y = 210
	box.add_child(link_qualifiers)
	link_dialog.confirmed.connect(_add_link)
	relation_dialog = AcceptDialog.new()
	relation_dialog.title = "Relationship library — names, endpoint types and meanings"
	add_child(relation_dialog)
	var rel_box: VBoxContainer = VBoxContainer.new()
	rel_box.custom_minimum_size = Vector2(820, 550)
	relation_dialog.add_child(rel_box)
	relation_search = LineEdit.new()
	relation_search.placeholder_text = "Search meaning, ID or source/target kind…"
	rel_box.add_child(relation_search)
	relation_search.text_changed.connect(func(_text): _refresh_relations())
	var rel_split: HSplitContainer = HSplitContainer.new()
	rel_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rel_box.add_child(rel_split)
	relation_list = ItemList.new()
	relation_list.custom_minimum_size = Vector2(330, 450)
	rel_split.add_child(relation_list)
	relation_details = TextEdit.new()
	relation_details.editable = false
	relation_details.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	relation_details.custom_minimum_size.x = 470
	rel_split.add_child(relation_details)
	relation_list.item_selected.connect(func(index):
		var id: String = str(relation_list.get_item_metadata(index))
		relation_details.text = JSON.stringify(relations_by_id[id], "  ", true))
	path_dialog = AcceptDialog.new()
	path_dialog.title = "Find a connection — connectivity, not causation or inferred truth"
	add_child(path_dialog)
	var path_box: VBoxContainer = VBoxContainer.new()
	path_box.custom_minimum_size = Vector2(850, 550)
	path_dialog.add_child(path_box)
	_label(path_box, "Uses the canvas's relation, meaning, holder, direction and reference filters. Maximum 8 hops.")
	path_from = _option(path_box, [])
	path_to = _option(path_box, [])
	_button(path_box, "Trace connection", trace_path)
	path_result = TextEdit.new()
	path_result.editable = false
	path_result.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	path_result.custom_minimum_size.y = 400
	path_box.add_child(path_result)

func _message(message: String) -> void:
	last_report = message
	status.text = message + ("  •  UNSAVED" if dirty else "")

func _error(message: String) -> void:
	_message(message)
	error_dialog.dialog_text = message
	error_dialog.popup_centered(Vector2i(740, 300))

func load_document(new_path: String, keep_undo: bool = false) -> void:
	var result: Dictionary = {}
	var seeded: bool = not FileAccess.file_exists(new_path)
	if seeded:
		if new_path != Model.DEFAULT_PATH:
			_error("File does not exist. Current document kept.")
			return
		result = Model.read_seed()
		if not result.has("error"):
			result = {"data": Model.expand_seed(result.data)}
	else:
		result = Model.read_json(new_path)
	if result.has("error"):
		_error(str(result.error))
		return
	var errors: Array[String] = Model.validate(result.data)
	if not errors.is_empty():
		_error("Load refused: " + "\n".join(errors))
		return
	if not keep_undo:
		undo_stack.clear()
	elif not document.is_empty():
		undo_stack.append(document.duplicate(true))
		_trim_history()
	redo_stack.clear()
	document = result.data
	path = new_path
	disk_hash = "" if seeded else FileAccess.get_file_as_string(path).sha256_text()
	dirty = seeded
	_refresh()
	_message("Expanded seed loaded in memory. Save creates your editable file." if seeded else "Loaded " + path + ". New bundled content is available through Add missing seed content.")

func _refresh() -> void:
	nodes_by_id = Model.index_by_id(document.nodes)
	relations_by_id = Model.index_by_id(document.relations)
	var old_view: int = view_picker.selected
	var old_kind: String = kind_picker.get_item_text(kind_picker.selected) if kind_picker.selected > 0 else ""
	var old_relation: String = _picker_id(relation_picker)
	var old_holder: String = _picker_id(holder_picker)
	view_picker.clear()
	for view in document.views:
		view_picker.add_item(str(view.label))
	if view_picker.item_count > 0:
		view_picker.select(clampi(old_view, 0, view_picker.item_count - 1))
	kind_picker.clear()
	kind_picker.add_item("All kinds")
	for kind in document.kinds:
		kind_picker.add_item(str(kind.id))
		if kind.id == old_kind:
			kind_picker.select(kind_picker.item_count - 1)
	relation_picker.clear()
	relation_picker.add_item("All relations")
	relation_picker.set_item_metadata(0, "")
	for relation in document.relations:
		relation_picker.add_item(str(relation.label))
		relation_picker.set_item_metadata(relation_picker.item_count - 1, relation.id)
		if relation.id == old_relation:
			relation_picker.select(relation_picker.item_count - 1)
	holder_picker.clear()
	holder_picker.add_item("All holders (author view)")
	holder_picker.set_item_metadata(0, "")
	for node in document.nodes:
		if node.kind in ["character", "group"]:
			holder_picker.add_item(str(node.label) + " — holder")
			holder_picker.set_item_metadata(holder_picker.item_count - 1, node.id)
			if node.id == old_holder:
				holder_picker.select(holder_picker.item_count - 1)
	_refresh_catalog()
	_render_graph()
	if selected_collection == "nodes" and nodes_by_id.has(selected_id):
		inspect_node(selected_id)
	elif selected_collection == "edges" and Model.index_by_id(document.edges).has(selected_id):
		inspect_edge(selected_id)
	else:
		selected_id = ""
		details.text = "Select a node to inspect its full record and all incoming/outgoing connections."
		edge_list.clear()

func _refresh_catalog() -> void:
	catalog.clear()
	var query: String = search.text.strip_edges().to_lower()
	var kind: String = kind_picker.get_item_text(kind_picker.selected) if kind_picker.selected > 0 else ""
	for node in document.get("nodes", []):
		if not kind.is_empty() and node.kind != kind:
			continue
		var haystack: String = (str(node.label) + " " + str(node.id) + " " + str(node.description) + " " + JSON.stringify(node.get("tags", []))).to_lower()
		if not query.is_empty() and not query in haystack:
			continue
		catalog.add_item(str(node.label) + ("  [example]" if node.scope == "example" else ""))
		catalog.set_item_metadata(catalog.item_count - 1, node.id)
		catalog.set_item_tooltip(catalog.item_count - 1, str(node.id) + "\n" + str(node.description))

func _filter() -> Dictionary:
	return {"relation": _picker_id(relation_picker), "semantics": semantics_picker.get_item_text(semantics_picker.selected) if semantics_picker.selected > 0 else "",
		"holder": _picker_id(holder_picker), "scope": scope_picker.selected, "qualifiers": qualifier_toggle.button_pressed,
		"direction": ["both", "out", "in"][direction_picker.selected]}

func clear_lenses() -> void:
	relation_picker.select(0)
	semantics_picker.select(0)
	holder_picker.select(0)
	scope_picker.select(0)
	direction_picker.select(0)
	qualifier_toggle.set_pressed_no_signal(false)
	_render_graph()

func _change_view(index: int) -> void:
	if document.is_empty():
		return
	focus_id = str(document.views[index].get("focus", ""))
	_render_graph()
	if nodes_by_id.has(focus_id):
		inspect_node(focus_id)

func _layout_key() -> String:
	var id: String = str(document.views[view_picker.selected].id) if view_picker.selected >= 0 else "all"
	return id + ":" + (focus_id if focus_toggle.button_pressed else "overview")

func _arc_key(arc: Dictionary) -> String:
	return str(arc.relation) + ("|" + str(arc.qualifier) if not str(arc.qualifier).is_empty() else "")

func _render_graph() -> void:
	if document.is_empty():
		return
	rebuilding = true
	graph.clear_connections()
	for child in graph.get_children():
		if child is GraphNode:
			graph.remove_child(child)
			child.queue_free()
	view_nodes.clear()
	port_relations.clear()
	var filter: Dictionary = _filter()
	var arcs: Array[Dictionary] = Queries.arcs(document, filter)
	var distances: Dictionary = {}
	if focus_toggle.button_pressed and nodes_by_id.has(focus_id):
		distances = Queries.neighborhood(document, focus_id, int(depth.value), filter)
	else:
		var domains: Array = document.views[view_picker.selected].domains if view_picker.selected >= 0 else []
		var linked: Dictionary = {}
		for arc in arcs:
			linked[arc.from] = true
			linked[arc.to] = true
		for node in document.nodes:
			if (domains.is_empty() or node.domain in domains) and (linked.has(node.id) or scope_picker.selected == 0):
				distances[node.id] = 0
	var ids: Array = distances.keys()
	ids.sort_custom(func(a, b):
		if distances[a] != distances[b]:
			return distances[a] < distances[b]
		return str(nodes_by_id[a].label) < str(nodes_by_id[b].label))
	var visible: Array[String] = []
	for id in ids:
		if visible.size() >= MAX_VISIBLE:
			break
		visible.append(str(id))
	var predicates: Dictionary = {}
	for id in visible:
		predicates[id] = []
	for arc in arcs:
		if predicates.has(arc.from) and predicates.has(arc.to):
			var key: String = _arc_key(arc)
			if not key in predicates[arc.from]:
				predicates[arc.from].append(key)
	var saved: Dictionary = document.get("layout", {}).get(_layout_key(), {})
	var rows: Dictionary = {}
	for index in range(visible.size()):
		var id: String = visible[index]
		var data: Dictionary = nodes_by_id[id]
		var node: GraphNode = GraphNode.new()
		node.name = "n_" + id.sha256_text().substr(0, 16)
		node.title = str(data.label)
		node.custom_minimum_size.x = 245
		node.set_meta("atlas_id", id)
		node.tooltip_text = str(data.description)
		graph.add_child(node)
		var caption: Label = _label(node, str(data.kind) + " · " + str(data.scope) + "  /  new link →")
		caption.tooltip_text = id + "\n" + str(data.description)
		var hue: float = float(absi(str(data.kind).hash()) % 360) / 360.0
		var tint: Color = Color.from_hsv(hue, 0.28, 0.96)
		node.set_slot(0, true, 0, tint, true, 0, tint)
		port_relations[id] = [""]
		predicates[id].sort()
		for key in predicates[id]:
			var parts: PackedStringArray = str(key).split("|")
			var text: String = str(relations_by_id[parts[0]].label)
			if parts.size() > 1:
				text += " [" + parts[1] + " ref]"
			var row: Label = _label(node, text + " →")
			row.tooltip_text = str(relations_by_id[parts[0]].description)
			node.set_slot(node.get_child_count() - 1, false, 0, tint, true, 0, tint)
			port_relations[id].append(key)
		var column: int = index % 4
		var y: float = float(rows.get(column, 30.0))
		rows[column] = y + 115.0 + 27.0 * predicates[id].size()
		var xy: Array = saved.get(id, [30.0 + column * 345.0, y])
		node.position_offset = Vector2(float(xy[0]), float(xy[1]))
		view_nodes[id] = node
	for arc in arcs:
		if view_nodes.has(arc.from) and view_nodes.has(arc.to):
			var port: int = port_relations[arc.from].find(_arc_key(arc))
			if not graph.is_node_connected(view_nodes[arc.from].name, port, view_nodes[arc.to].name, 0):
				graph.connect_node(view_nodes[arc.from].name, port, view_nodes[arc.to].name, 0)
	rebuilding = false
	_message("%d / %d matching nodes shown • %d kinds, %d relation types, %d entries, %d links. Filters do not delete data." % [visible.size(), ids.size(), document.kinds.size(), document.relations.size(), document.nodes.size(), document.edges.size()])

func fit_visible() -> void:
	if view_nodes.is_empty() or graph.size.x <= 0:
		return
	var bounds: Rect2 = Rect2()
	var first: bool = true
	for id in view_nodes:
		var node: GraphNode = view_nodes[id]
		var rect: Rect2 = Rect2(node.position_offset, node.size)
		bounds = rect if first else bounds.merge(rect)
		first = false
	graph.zoom = clampf(minf(graph.size.x / (bounds.size.x + 100), graph.size.y / (bounds.size.y + 100)), graph.zoom_min, graph.zoom_max)
	graph.scroll_offset = (bounds.position - Vector2(40, 40)) * graph.zoom

func arrange_visible() -> void:
	var index: int = 0
	var rows: Dictionary = {}
	for id in view_nodes:
		var column: int = index % 4
		var y: float = float(rows.get(column, 30.0))
		view_nodes[id].position_offset = Vector2(30.0 + column * 345.0, y)
		rows[column] = y + maxf(float(view_nodes[id].size.y) + 45, 120.0 + port_relations[id].size() * 27)
		index += 1
	_finish_move()

func _finish_move() -> void:
	if rebuilding or document.is_empty():
		return
	var next: Dictionary = document.duplicate(true)
	if not next.has("layout"):
		next.layout = {}
	if not next.layout.has(_layout_key()):
		next.layout[_layout_key()] = {}
	for id in view_nodes:
		var point: Vector2 = view_nodes[id].position_offset
		next.layout[_layout_key()][id] = [point.x, point.y]
	_commit(next, "Stored this view's arrangement.")

func set_focus(id: String) -> void:
	if not nodes_by_id.has(id):
		_message("Select a node in the catalog first.")
		return
	focus_id = id
	focus_toggle.set_pressed_no_signal(true)
	graph.scroll_offset = Vector2.ZERO
	_render_graph()
	inspect_node(id)

func selected_node_id() -> String:
	if selected_collection == "nodes" and nodes_by_id.has(selected_id):
		return selected_id
	return focus_id if nodes_by_id.has(focus_id) else ""

func _edge_references(edge: Dictionary, ids: Array[String]) -> bool:
	if edge.from in ids or edge.to in ids:
		return true
	for key in Model.REFERENCE_KEYS:
		if edge.get("qualifiers", {}).get(key, "") in ids:
			return true
	return false

func inspect_node(id: String) -> void:
	if not nodes_by_id.has(id):
		return
	selected_id = id
	selected_collection = "nodes"
	title_label.text = str(nodes_by_id[id].label) + " [" + str(nodes_by_id[id].scope) + "]"
	details.text = JSON.stringify(nodes_by_id[id], "  ", true)
	edge_list.clear()
	for edge in document.edges:
		if not _edge_references(edge, [id]):
			continue
		var text: String = str(nodes_by_id[edge.from].label) + " → " + str(relations_by_id[edge.relation].label) + " → " + str(nodes_by_id[edge.to].label)
		if edge.from != id and edge.to != id:
			text = "[reference] " + text
		var q: Dictionary = edge.get("qualifiers", {})
		if q.has("feeling"):
			text += " (" + str(nodes_by_id[q.feeling].label) + ")"
		if q.has("holder"):
			text += " [" + str(nodes_by_id[q.holder].label) + "]"
		edge_list.add_item(text)
		edge_list.set_item_metadata(edge_list.item_count - 1, edge.id)
		edge_list.set_item_tooltip(edge_list.item_count - 1, JSON.stringify(edge, "  ", true))

func inspect_edge(id: String) -> void:
	var record: Dictionary = Model.index_by_id(document.edges).get(id, {})
	if record.is_empty():
		return
	selected_id = id
	selected_collection = "edges"
	title_label.text = str(relations_by_id[record.relation].label) + "  [" + str(record.scope) + "]"
	details.text = JSON.stringify(record, "  ", true) + "\n\nMeaning: " + str(relations_by_id[record.relation].description)

func focus_other_end() -> void:
	if selected_collection == "edges":
		var edge: Dictionary = Model.index_by_id(document.edges).get(selected_id, {})
		if not edge.is_empty():
			set_focus(str(edge.to) if edge.from == focus_id else str(edge.from))
	else:
		set_focus(selected_node_id())

func _commit(next: Dictionary, description: String) -> bool:
	var errors: Array[String] = Model.validate(next)
	if not errors.is_empty():
		_error("Change refused: " + "\n".join(errors))
		return false
	if next == document:
		_message("No changes needed.")
		return true
	undo_stack.append(document.duplicate(true))
	_trim_history()
	redo_stack.clear()
	document = next.duplicate(true)
	dirty = true
	_refresh()
	_message(description)
	return true

func _trim_history() -> void:
	while undo_stack.size() > HISTORY_LIMIT:
		undo_stack.pop_front()

func undo() -> void:
	if undo_stack.is_empty():
		return
	redo_stack.append(document.duplicate(true))
	document = undo_stack.pop_back()
	dirty = true
	_refresh()
	_message("Undid the previous edit. Save to retain this state.")

func redo() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append(document.duplicate(true))
	_trim_history()
	document = redo_stack.pop_back()
	dirty = true
	_refresh()
	_message("Redid the edit.")

func new_node() -> void:
	if document.is_empty():
		return
	var kind: String = kind_picker.get_item_text(kind_picker.selected) if kind_picker.selected > 0 else "role"
	_show_editor("new_node", {"id": kind + ".custom_" + str(Time.get_ticks_usec()), "label": "New " + kind,
		"kind": kind, "domain": "custom", "scope": "definition", "description": "Describe this concept or example.", "tags": []})

func edit_selected() -> void:
	var record: Dictionary = Model.index_by_id(document.get(selected_collection, [])).get(selected_id, {})
	if not record.is_empty():
		_show_editor(selected_collection, record)

func edit_schema() -> void:
	if not document.is_empty():
		_show_editor("schema", {"kinds": document.kinds, "relations": document.relations, "views": document.views})

func _show_editor(mode: String, record: Dictionary) -> void:
	edit_mode = mode
	edit_original_id = str(record.get("id", ""))
	editor_text.text = JSON.stringify(record, "  ", true)
	editor_dialog.popup_centered(Vector2i(820, 600))

func _apply_editor() -> void:
	var parser: JSON = JSON.new()
	if parser.parse(editor_text.text) != OK or not parser.data is Dictionary:
		_error("Expected a valid JSON object. No change applied.")
		return
	var record: Dictionary = parser.data
	var next: Dictionary = document.duplicate(true)
	if edit_mode == "schema":
		for key in ["kinds", "relations", "views"]:
			if not record.has(key):
				_error("Schema edit needs kinds, relations and views.")
				return
			next[key] = record[key]
	elif edit_mode == "new_node":
		next.nodes.append(record)
	else:
		if record.get("id") != edit_original_id:
			_error("Keep stable IDs unchanged. Create a replacement node and reconnect explicitly instead.")
			return
		for index in range(next[edit_mode].size()):
			if next[edit_mode][index].id == edit_original_id:
				next[edit_mode][index] = record
	if _commit(next, "Applied and validated the record edit."):
		editor_dialog.hide()
		if edit_mode == "new_node":
			set_focus(str(record.id))

func _picker_id(picker: OptionButton) -> String:
	if picker.selected < 0:
		return ""
	var value: Variant = picker.get_item_metadata(picker.selected)
	return str(value) if value is String else ""

func _populate_nodes(picker: OptionButton, preferred: String) -> void:
	picker.clear()
	for node in document.nodes:
		picker.add_item(str(node.label) + "  (" + str(node.id) + ")")
		picker.set_item_metadata(picker.item_count - 1, node.id)
		if node.id == preferred:
			picker.select(picker.item_count - 1)

func show_link_dialog(source: String, target: String, preferred: String = "") -> void:
	if document.is_empty():
		return
	_populate_nodes(link_from, source)
	_populate_nodes(link_to, target)
	link_qualifiers.text = "{}"
	_refresh_link_relations()
	for index in range(link_relation.item_count):
		if link_relation.get_item_metadata(index) == preferred:
			link_relation.select(index)
	_describe_link()
	link_dialog.popup_centered(Vector2i(810, 620))

func _refresh_link_relations() -> void:
	link_relation.clear()
	var source: Dictionary = nodes_by_id.get(_picker_id(link_from), {})
	var target: Dictionary = nodes_by_id.get(_picker_id(link_to), {})
	if source.is_empty() or target.is_empty():
		return
	for relation in document.relations:
		if Model.accepts(relation, source, target):
			link_relation.add_item(str(relation.label) + " [" + str(relation.id) + "]")
			link_relation.set_item_metadata(link_relation.item_count - 1, relation.id)
	_describe_link()

func _describe_link() -> void:
	var relation: Dictionary = relations_by_id.get(_picker_id(link_relation), {})
	link_explanation.text = str(relation.get("description", "No compatible relation. Select other endpoints or extend the schema."))
	if not relation.is_empty():
		link_explanation.text += "\nMeaning: " + str(relation.semantics)
		if relation.has("required_qualifiers"):
			link_explanation.text += " • Required: " + ", ".join(relation.required_qualifiers)
	link_dialog.get_ok_button().disabled = relation.is_empty()

func _connection_request(from_name: StringName, from_port: int, to_name: StringName, _to_port: int) -> void:
	var source_node: Node = graph.get_node(NodePath(str(from_name)))
	var target_node: Node = graph.get_node(NodePath(str(to_name)))
	var source: String = str(source_node.get_meta("atlas_id"))
	var target: String = str(target_node.get_meta("atlas_id"))
	var key: String = str(port_relations[source][from_port])
	if "|" in key:
		_message("Reference wires are qualifier metadata. Edit the individual relationship in the inspector, or use the new-link port.")
		return
	show_link_dialog(source, target, key)

func _add_link() -> void:
	var parser: JSON = JSON.new()
	if parser.parse(link_qualifiers.text) != OK or not parser.data is Dictionary:
		_error("Qualifiers must be a JSON object.")
		return
	var source: String = _picker_id(link_from)
	var target: String = _picker_id(link_to)
	var relation: String = _picker_id(link_relation)
	if not relations_by_id.has(relation):
		_error("Choose a compatible relation.")
		return
	var q: Dictionary = parser.data
	if relations_by_id[relation].semantics == "subjective" and not q.has("holder"):
		if relation == "perceived_as":
			_error("Perceived-as needs the observer or audience in qualifiers.holder.")
			return
		q.holder = source
	var next: Dictionary = document.duplicate(true)
	var scope: String = "example" if nodes_by_id[source].scope == "example" or nodes_by_id[target].scope == "example" else "definition"
	var id: String = "e_" + (source + target + str(Time.get_ticks_usec())).sha256_text().substr(0, 16)
	next.edges.append({"id": id, "from": source, "relation": relation, "to": target, "scope": scope, "qualifiers": q})
	if _commit(next, "Created a typed relationship with its context retained."):
		link_dialog.hide()
		inspect_node(source)
		inspect_edge(id)

func _delete_nodes_request(names: Array[StringName]) -> void:
	pending_delete.clear()
	for node_name in names:
		var node: Node = graph.get_node_or_null(NodePath(str(node_name)))
		if node is GraphNode:
			pending_delete.append(str(node.get_meta("atlas_id")))
	_ask_delete()

func delete_selected() -> void:
	pending_delete.clear()
	if selected_collection == "nodes" and nodes_by_id.has(selected_id):
		pending_delete.append(selected_id)
	elif selected_collection == "edges" and not selected_id.is_empty():
		delete_dialog.dialog_text = "Delete this individual relationship? Undo is available."
		delete_dialog.popup_centered()
		return
	_ask_delete()

func _ask_delete() -> void:
	if pending_delete.is_empty():
		return
	var affected: int = 0
	for edge in document.edges:
		if _edge_references(edge, pending_delete):
			affected += 1
	delete_dialog.dialog_text = "Delete %d node(s) and %d relationships that reference them? This includes holder, feeling and context references. Undo is available." % [pending_delete.size(), affected]
	delete_dialog.popup_centered()

func _confirm_delete() -> void:
	var next: Dictionary = document.duplicate(true)
	if pending_delete.is_empty():
		next.edges = next.edges.filter(func(edge): return edge.id != selected_id)
	else:
		next.nodes = next.nodes.filter(func(node): return not node.id in pending_delete)
		next.edges = next.edges.filter(func(edge): return not _edge_references(edge, pending_delete))
		for view in next.views:
			if view.get("focus", "") in pending_delete:
				view.erase("focus")
		for key in next.get("layout", {}):
			for id in pending_delete:
				next.layout[key].erase(id)
	_commit(next, "Deleted the selected content and validated remaining references.")
	pending_delete.clear()

func merge_catalog() -> void:
	var result: Dictionary = Model.read_seed()
	if result.has("error"):
		_error(str(result.error))
		return
	var merge: Dictionary = Model.merge_missing(document, Model.expand_seed(result.data))
	if merge.has("error"):
		_error(str(merge.error))
		return
	_commit(merge.data, "Added missing bundled content: " + JSON.stringify(merge.added) + ". Retained %d existing edited records." % int(merge.retained_edits))

func show_relations() -> void:
	_refresh_relations()
	relation_dialog.popup_centered(Vector2i(880, 630))

func _refresh_relations() -> void:
	relation_list.clear()
	var query: String = relation_search.text.strip_edges().to_lower()
	var counts: Dictionary = {}
	for edge in document.get("edges", []):
		counts[edge.relation] = int(counts.get(edge.relation, 0)) + 1
	for relation in document.get("relations", []):
		if not query.is_empty() and not query in JSON.stringify(relation).to_lower():
			continue
		relation_list.add_item(str(relation.label) + "  (" + str(counts.get(relation.id, 0)) + ")")
		relation_list.set_item_metadata(relation_list.item_count - 1, relation.id)

func show_path_dialog() -> void:
	_populate_nodes(path_from, focus_id)
	_populate_nodes(path_to, selected_node_id())
	path_result.text = "Choose two nodes, then trace. A connection is not proof of causation, awareness, agreement or executable behavior."
	path_dialog.popup_centered(Vector2i(900, 640))

func trace_path() -> void:
	var result: Dictionary = Queries.shortest_path(document, _picker_id(path_from), _picker_id(path_to), _filter())
	if not result.found:
		path_result.text = str(result.reason)
		return
	var lines: Array[String] = ["GRAPH CONNECTION ONLY — not a causal explanation or inferred fact.", ""]
	for step in result.steps:
		var arc: Dictionary = step.arc
		var label: String = str(relations_by_id[arc.relation].label)
		if not str(arc.qualifier).is_empty():
			label += " [" + str(arc.qualifier) + " reference]"
		lines.append(str(nodes_by_id[step.from].label) + (" ← " if step.reverse else " → ") + label + (" ← " if step.reverse else " → ") + str(nodes_by_id[step.to].label))
		lines.append("  assertion: " + str(arc.edge_id))
	if result.steps.is_empty():
		lines.append("The two selections are the same node.")
	path_result.text = "\n".join(lines)

func _report_validation() -> void:
	var errors: Array[String] = Model.validate(document)
	if errors.is_empty():
		_message("Validation passed: typed links, holders, required qualifiers, scopes, references, numeric intervals and hierarchy checks.")
	else:
		_error("\n".join(errors))

func save_document() -> void:
	if document.is_empty():
		return
	var error: String = Model.save_atomic(document, path, disk_hash)
	if not error.is_empty():
		_error(error)
		return
	disk_hash = FileAccess.get_file_as_string(path).sha256_text()
	dirty = false
	_message("Saved " + path + ". Previous on-disk version retained as .bak when replacing a file.")

func _export_copy(export_path: String) -> void:
	if document.is_empty():
		return
	if ProjectSettings.globalize_path(export_path) == ProjectSettings.globalize_path(path):
		save_document()
		return
	var expected: String = FileAccess.get_file_as_string(export_path).sha256_text() if FileAccess.file_exists(export_path) else ""
	var error: String = Model.save_atomic(document, export_path, expected)
	if error.is_empty():
		_message("Exported a copy to " + export_path + "; current file and dirty state unchanged.")
	else:
		_error(error)

func write_recovery() -> void:
	if dirty and not document.is_empty():
		var recovery: String = "user://hughes_atlas_recovery.json"
		var expected: String = FileAccess.get_file_as_string(recovery).sha256_text() if FileAccess.file_exists(recovery) else ""
		var error: String = Model.save_atomic(document, recovery, expected)
		if not error.is_empty():
			push_warning("Hughes Atlas recovery failed: " + error)
