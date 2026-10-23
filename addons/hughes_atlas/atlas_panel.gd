@tool
extends Control
## Editor workspace and standalone scene share this exact authoring interface.
const Model = preload("atlas_model.gd")
const MAX_VISIBLE := 90
const HISTORY_LIMIT := 32
var document: Dictionary = {}
var dirty := false
var path := Model.DEFAULT_PATH
var disk_hash := ""
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var nodes_by_id := {}
var relations_by_id := {}
var focus_id := "place.school"
var selected_id := ""
var selected_collection := "nodes"
var view_nodes := {}
var port_relations := {}
var rebuilding := false
var move_snapshot: Dictionary = {}
var pending_delete: Array[String] = []
var edit_mode := ""
var edit_original_id := ""
var last_report := ""
var graph: GraphEdit
var view_picker: OptionButton
var scope_picker: OptionButton
var kind_picker: OptionButton
var search: LineEdit
var catalog: ItemList
var focus_toggle: CheckBox
var depth: SpinBox
var details: TextEdit
var edge_list: ItemList
var title_label: Label
var status: Label
var editor_dialog: ConfirmationDialog
var editor_text: CodeEdit
var delete_dialog: ConfirmationDialog
var reload_dialog: ConfirmationDialog
var export_dialog: FileDialog
var open_dialog: FileDialog
var link_dialog: ConfirmationDialog
var link_from: OptionButton
var link_to: OptionButton
var link_relation: OptionButton
var link_qualifiers: CodeEdit
var link_explanation: Label

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
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	return label

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_label(root, "HUGHES ATLAS  /  Social-world authoring — definitions and fictional examples, not a running simulation")
	var toolbar := HFlowContainer.new()
	root.add_child(toolbar)
	view_picker = OptionButton.new()
	toolbar.add_child(view_picker)
	view_picker.item_selected.connect(_change_view)
	_button(toolbar, "Save", save_document)
	_button(toolbar, "Open JSON…", func(): open_dialog.popup_centered_ratio(0.75))
	_button(toolbar, "Export copy…", func(): export_dialog.popup_centered_ratio(0.75))
	_button(toolbar, "Reload", func(): reload_dialog.popup_centered())
	_button(toolbar, "Undo", undo)
	_button(toolbar, "Redo", redo)
	_button(toolbar, "New node", new_node)
	_button(toolbar, "Link…", func(): show_link_dialog(selected_node_id(), ""))
	_button(toolbar, "Edit schema…", edit_schema)
	_button(toolbar, "Validate", func(): _report_validation())
	var filters := HBoxContainer.new()
	root.add_child(filters)
	focus_toggle = CheckBox.new()
	focus_toggle.text = "Neighborhood of selected focus"
	focus_toggle.button_pressed = true
	filters.add_child(focus_toggle)
	focus_toggle.toggled.connect(func(_on): _render_graph())
	_label(filters, "Hops")
	depth = SpinBox.new()
	depth.min_value = 1
	depth.max_value = 3
	depth.value = 1
	filters.add_child(depth)
	depth.value_changed.connect(func(_value): _render_graph())
	scope_picker = OptionButton.new()
	for label in ["Definitions + examples", "Definitions only", "Examples only"]:
		scope_picker.add_item(label)
	filters.add_child(scope_picker)
	scope_picker.item_selected.connect(func(_index): _render_graph())
	_button(filters, "Focus inspected node", func(): set_focus(selected_node_id()))
	_button(filters, "Arrange visible", arrange_visible)
	_label(filters, "Drag RIGHT → LEFT; predicate is printed on its output row.")
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 245
	split.add_child(left)
	_label(left, "GLOBAL CATALOG — double-click to focus")
	search = LineEdit.new()
	search.placeholder_text = "Search names, IDs, descriptions, tags…"
	left.add_child(search)
	search.text_changed.connect(func(_text): _refresh_catalog())
	kind_picker = OptionButton.new()
	left.add_child(kind_picker)
	kind_picker.item_selected.connect(func(_index): _refresh_catalog())
	catalog = ItemList.new()
	catalog.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(catalog)
	catalog.item_selected.connect(func(index): inspect_node(str(catalog.get_item_metadata(index))))
	catalog.item_activated.connect(func(index): set_focus(str(catalog.get_item_metadata(index))))
	var middle := HSplitContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(middle)
	graph = GraphEdit.new()
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.custom_minimum_size.x = 360
	graph.minimap_enabled = true
	graph.show_arrange_button = false
	graph.right_disconnects = false
	middle.add_child(graph)
	graph.node_selected.connect(func(node):
		if node is GraphNode and not rebuilding:
			inspect_node(str(node.get_meta("atlas_id"))))
	graph.connection_request.connect(_connection_request)
	graph.disconnection_request.connect(func(_a, _b, _c, _d): _message("Delete an individual relationship in the inspector. Parallel links may have different holders or dates."))
	graph.delete_nodes_request.connect(_delete_nodes_request)
	graph.begin_node_move.connect(func(): move_snapshot = document.duplicate(true))
	graph.end_node_move.connect(_finish_move)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 330
	middle.add_child(right)
	title_label = _label(right, "Select a node or relationship")
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tools := HFlowContainer.new()
	right.add_child(tools)
	_button(tools, "Edit record…", edit_selected)
	_button(tools, "Delete…", delete_selected)
	_button(tools, "Copy ID", func(): DisplayServer.clipboard_set(selected_id))
	_button(tools, "Focus other end", focus_other_end)
	details = TextEdit.new()
	details.editable = false
	details.custom_minimum_size.y = 245
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	right.add_child(details)
	_label(right, "ALL INCOMING / OUTGOING — including hidden nodes")
	edge_list = ItemList.new()
	edge_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edge_list.custom_minimum_size.y = 180
	right.add_child(edge_list)
	edge_list.item_selected.connect(func(index): inspect_edge(str(edge_list.get_item_metadata(index))))
	status = _label(root, "Loading…")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor_dialog = ConfirmationDialog.new()
	editor_dialog.title = "Edit authored record — Apply validates the whole document"
	editor_dialog.size = Vector2i(820, 620)
	editor_dialog.get_ok_button().text = "Apply"
	editor_dialog.dialog_hide_on_ok = false
	add_child(editor_dialog)
	editor_text = CodeEdit.new()
	editor_text.custom_minimum_size = Vector2(780, 540)
	editor_dialog.add_child(editor_text)
	editor_dialog.confirmed.connect(_apply_editor)
	delete_dialog = ConfirmationDialog.new()
	delete_dialog.title = "Delete authored content?"
	add_child(delete_dialog)
	delete_dialog.confirmed.connect(_confirm_delete)
	reload_dialog = ConfirmationDialog.new()
	reload_dialog.dialog_text = "Reload the on-disk graph? Unsaved edits will be replaced after validation. Undo can restore them."
	add_child(reload_dialog)
	reload_dialog.confirmed.connect(func(): load_document(path, true))
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
			_message("Export or save your current graph before opening another file.")
		else:
			load_document(new_path, false))
	_build_link_dialog()

func _message(message: String) -> void:
	last_report = message
	status.text = message + ("  •  UNSAVED" if dirty else "")

func load_document(new_path: String, keep_undo: bool = false) -> void:
	var result: Dictionary
	var seeded := not FileAccess.file_exists(new_path)
	if seeded:
		if new_path != Model.DEFAULT_PATH:
			_message("Cannot open a missing file. Current document was kept.")
			return
		result = Model.read_seed()
		if not result.has("error"):
			result = {"data": Model.expand_seed(result.data)}
	else:
		result = Model.read_json(new_path)
	if result.has("error"):
		_message(str(result.error) + " — no data overwritten.")
		return
	var errors := Model.validate(result.data)
	if not errors.is_empty():
		_message("Load refused: " + "\n".join(errors))
		return
	if not keep_undo:
		undo_stack.clear()
	if keep_undo and not document.is_empty():
		undo_stack.append(document.duplicate(true))
		_trim_history()
	redo_stack.clear()
	document = result.data
	path = new_path
	disk_hash = "" if seeded else FileAccess.get_file_as_string(path).sha256_text()
	dirty = seeded
	_refresh()
	_message("Bundled seed loaded in memory. Save creates your editable JSON." if seeded else "Loaded " + path)

func _refresh() -> void:
	nodes_by_id = Model.index_by_id(document.nodes)
	relations_by_id = Model.index_by_id(document.relations)
	var old_view := view_picker.selected
	var old_kind := kind_picker.get_item_text(kind_picker.selected) if kind_picker.item_count > 0 else "All kinds"
	view_picker.clear()
	for view in document.views:
		view_picker.add_item(view.label)
	if view_picker.item_count > 0:
		view_picker.select(clampi(old_view, 0, view_picker.item_count - 1))
	kind_picker.clear()
	kind_picker.add_item("All kinds")
	for kind in document.kinds:
		kind_picker.add_item(kind.id)
		kind_picker.set_item_tooltip(kind_picker.item_count - 1, kind.get("description", ""))
		if kind.id == old_kind:
			kind_picker.select(kind_picker.item_count - 1)
	_refresh_catalog()
	_render_graph()
	if selected_collection == "nodes" and nodes_by_id.has(selected_id):
		inspect_node(selected_id)
	elif selected_collection == "edges" and Model.index_by_id(document.edges).has(selected_id):
		inspect_edge(selected_id)
	else:
		selected_id = ""
		title_label.text = "Select a node or relationship"
		details.text = "Select a node. Nothing here is a runtime behavior or a global morality score."
		edge_list.clear()

func _refresh_catalog() -> void:
	catalog.clear()
	var query := search.text.strip_edges().to_lower()
	var kind := kind_picker.get_item_text(kind_picker.selected) if kind_picker.selected > 0 else ""
	for node in document.get("nodes", []):
		if not kind.is_empty() and node.kind != kind:
			continue
		var haystack := (str(node.label) + " " + node.id + " " + node.description + " " + JSON.stringify(node.get("tags", []))).to_lower()
		if not query.is_empty() and not query in haystack:
			continue
		catalog.add_item(node.label + ("  [example]" if node.scope == "example" else ""))
		catalog.set_item_metadata(catalog.item_count - 1, node.id)
		catalog.set_item_tooltip(catalog.item_count - 1, node.id + "\n" + node.description)

func _change_view(index: int) -> void:
	if document.is_empty():
		return
	focus_id = str(document.views[index].get("focus", ""))
	_render_graph()
	if nodes_by_id.has(focus_id):
		inspect_node(focus_id)

func _scope_ok(node: Dictionary) -> bool:
	return scope_picker.selected == 0 or (scope_picker.selected == 1 and node.scope == "definition") or (scope_picker.selected == 2 and node.scope == "example")

func _layout_key() -> String:
	var view_id: String = document.views[view_picker.selected].id if view_picker.selected >= 0 else "all"
	return view_id + ":" + (focus_id if focus_toggle.button_pressed else "overview")

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
	var eligible := {}
	var distances := {}
	if focus_toggle.button_pressed and nodes_by_id.has(focus_id):
		eligible[focus_id] = true
		distances[focus_id] = 0
		var frontier: Array = [focus_id]
		for step in range(int(depth.value)):
			var next: Array = []
			for edge in document.edges:
				if edge.from in frontier and not eligible.has(edge.to):
					eligible[edge.to] = true
					distances[edge.to] = step + 1
					next.append(edge.to)
				if edge.to in frontier and not eligible.has(edge.from):
					eligible[edge.from] = true
					distances[edge.from] = step + 1
					next.append(edge.from)
			frontier = next
	else:
		var domains: Array = document.views[view_picker.selected].domains if view_picker.selected >= 0 else []
		for node in document.nodes:
			if domains.is_empty() or node.domain in domains:
				eligible[node.id] = true
	var ids: Array = eligible.keys()
	ids.sort_custom(func(a, b):
		if distances.get(a, 0) == distances.get(b, 0):
			return str(nodes_by_id[a].label) < str(nodes_by_id[b].label)
		return distances.get(a, 0) < distances.get(b, 0))
	var visible_ids: Array[String] = []
	var candidates := 0
	for id in ids:
		if _scope_ok(nodes_by_id[id]):
			candidates += 1
			if visible_ids.size() < MAX_VISIBLE:
				visible_ids.append(id)
	var predicates := {}
	for id in visible_ids:
		predicates[id] = []
	for edge in document.edges:
		if predicates.has(edge.from) and predicates.has(edge.to):
			if not edge.relation in predicates[edge.from]:
				predicates[edge.from].append(edge.relation)
	var saved_layout: Dictionary = document.get("layout", {}).get(_layout_key(), {})
	var column_rows := {}
	for index in range(visible_ids.size()):
		var id := visible_ids[index]
		var data: Dictionary = nodes_by_id[id]
		var node := GraphNode.new()
		node.name = "v" + str(index)
		node.title = data.label
		node.custom_minimum_size.x = 245
		node.set_meta("atlas_id", id)
		graph.add_child(node)
		var caption := Label.new()
		caption.text = data.kind + "  ·  " + data.scope + "  /  link →"
		caption.tooltip_text = id + "\n" + data.description
		node.add_child(caption)
		var tint := Color.from_hsv(float(document.kinds.find(Model.index_by_id(document.kinds)[data.kind])) / maxf(1.0, float(document.kinds.size())), 0.32, 0.95)
		node.set_slot(0, true, 0, tint, true, 0, tint)
		port_relations[id] = [""]
		predicates[id].sort()
		for predicate in predicates[id]:
			var row := Label.new()
			row.text = str(relations_by_id[predicate].label) + " →"
			row.tooltip_text = relations_by_id[predicate].description
			node.add_child(row)
			node.set_slot(node.get_child_count() - 1, false, 0, tint, true, 0, tint)
			port_relations[id].append(predicate)
		var column: int = int(distances.get(id, index % 4))
		var y: float = float(column_rows.get(column, 30.0))
		column_rows[column] = y + 110.0 + 27.0 * predicates[id].size()
		var xy: Array = saved_layout.get(id, [30.0 + column * 340.0, y])
		node.position_offset = Vector2(float(xy[0]), float(xy[1]))
		view_nodes[id] = node
	for edge in document.edges:
		if view_nodes.has(edge.from) and view_nodes.has(edge.to):
			var port: int = port_relations[edge.from].find(edge.relation)
			if not graph.is_node_connected(view_nodes[edge.from].name, port, view_nodes[edge.to].name, 0):
				graph.connect_node(view_nodes[edge.from].name, port, view_nodes[edge.to].name, 0)
	rebuilding = false
	_message("%d / %d matching nodes visible; %d nodes and %d relationships in the library. %s" % [visible_ids.size(), candidates, document.nodes.size(), document.edges.size(), "Use search/focus for hidden nodes." if candidates > MAX_VISIBLE else "Filters never delete content."])

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

func inspect_node(id: String) -> void:
	if not nodes_by_id.has(id):
		return
	selected_id = id
	selected_collection = "nodes"
	title_label.text = nodes_by_id[id].label + "  [" + nodes_by_id[id].scope + "]"
	details.text = JSON.stringify(nodes_by_id[id], "  ", true)
	edge_list.clear()
	for edge in document.edges:
		if _edge_references(edge, [id]):
			var incoming: bool = edge.to == id
			var other: String = edge.from if incoming else edge.to
			var text: String = ("← " if incoming else "→ ") + relations_by_id[edge.relation].label + " · " + nodes_by_id[other].label
			if edge.from != id and edge.to != id:
				text = "[qualifier reference] " + nodes_by_id[edge.from].label + " → " + relations_by_id[edge.relation].label + " → " + nodes_by_id[edge.to].label
			var q: Dictionary = edge.get("qualifiers", {})
			if q.has("holder"):
				text += " [held by " + nodes_by_id[q.holder].label + "]"
			edge_list.add_item(text)
			edge_list.set_item_metadata(edge_list.item_count - 1, edge.id)
			edge_list.set_item_tooltip(edge_list.item_count - 1, JSON.stringify(edge, "  ", true))

func inspect_edge(id: String) -> void:
	var edges := Model.index_by_id(document.edges)
	if not edges.has(id):
		return
	selected_id = id
	selected_collection = "edges"
	var edge: Dictionary = edges[id]
	title_label.text = nodes_by_id[edge.from].label + " → " + relations_by_id[edge.relation].label + " → " + nodes_by_id[edge.to].label
	details.text = JSON.stringify(edge, "  ", true) + "\n\nRelation meaning:\n" + relations_by_id[edge.relation].description

func focus_other_end() -> void:
	if selected_collection != "edges":
		set_focus(selected_node_id())
		return
	var edge: Dictionary = Model.index_by_id(document.edges).get(selected_id, {})
	if not edge.is_empty():
		set_focus(edge.to if edge.from == focus_id else edge.from)

func _commit(next: Dictionary, description: String) -> bool:
	var errors := Model.validate(next)
	if not errors.is_empty():
		_message("Change refused: " + "\n".join(errors))
		return false
	if next == document:
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
	_message("Undid the previous change. Save to keep this state.")

func redo() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append(document.duplicate(true))
	_trim_history()
	document = redo_stack.pop_back()
	dirty = true
	_refresh()
	_message("Redid the change.")

func _finish_move() -> void:
	if rebuilding or document.is_empty():
		return
	var next := document.duplicate(true)
	if not next.has("layout"):
		next.layout = {}
	if not next.layout.has(_layout_key()):
		next.layout[_layout_key()] = {}
	for id in view_nodes:
		var point: Vector2 = view_nodes[id].position_offset
		next.layout[_layout_key()][id] = [point.x, point.y]
	move_snapshot.clear()
	_commit(next, "Saved the visible arrangement in this view's layout.")

func arrange_visible() -> void:
	if view_nodes.is_empty():
		return
	var index := 0
	var rows := {0: 30.0, 1: 30.0, 2: 30.0, 3: 30.0}
	for id in view_nodes:
		var column := index % 4
		view_nodes[id].position_offset = Vector2(30 + column * 340, rows[column])
		rows[column] += maxf(view_nodes[id].size.y + 50.0, 110.0 + port_relations[id].size() * 27.0)
		index += 1
	_finish_move()

func new_node() -> void:
	if document.is_empty():
		return
	var kind: String = kind_picker.get_item_text(kind_picker.selected) if kind_picker.selected > 0 else "role"
	var record := {"id": kind + ".custom_" + str(Time.get_ticks_usec()), "label": "New " + kind,
		"kind": kind, "domain": "custom", "scope": "definition", "description": "Describe this without prescribing every outcome.", "tags": []}
	_show_editor("new_node", record)

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
	editor_dialog.popup_centered(Vector2i(820, 620))

func _apply_editor() -> void:
	var parser := JSON.new()
	if parser.parse(editor_text.text) != OK or not parser.data is Dictionary:
		_message("Invalid JSON object in the editor; nothing changed.")
		return
	var record: Dictionary = parser.data
	var next := document.duplicate(true)
	if edit_mode == "schema":
		for key in ["kinds", "relations", "views"]:
			if not record.has(key):
				_message("Schema edit requires kinds, relations and views.")
				return
			next[key] = record[key]
	elif edit_mode == "new_node":
		next.nodes.append(record)
	else:
		if record.get("id") != edit_original_id:
			_message("Stable IDs cannot be renamed in place. Create a new record and reconnect explicitly.")
			return
		for index in range(next[edit_mode].size()):
			if next[edit_mode][index].id == edit_original_id:
				next[edit_mode][index] = record
	if _commit(next, "Applied and validated " + edit_mode + " edit."):
		editor_dialog.hide()
		if edit_mode == "new_node":
			set_focus(record.id)

func _build_link_dialog() -> void:
	link_dialog = ConfirmationDialog.new()
	link_dialog.title = "Create a typed relationship"
	link_dialog.dialog_hide_on_ok = false
	add_child(link_dialog)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(790, 520)
	link_dialog.add_child(box)
	_label(box, "Source (right port) → relation → target (left port)")
	link_from = OptionButton.new()
	link_to = OptionButton.new()
	link_relation = OptionButton.new()
	for picker in [link_from, link_to, link_relation]:
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(picker)
	link_from.item_selected.connect(func(_index): _refresh_link_relations())
	link_to.item_selected.connect(func(_index): _refresh_link_relations())
	link_relation.item_selected.connect(func(_index): _describe_link())
	link_explanation = _label(box, "")
	link_explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(box, "Qualifiers JSON: holder, feeling, context, confidence, dates, notes…")
	link_qualifiers = CodeEdit.new()
	link_qualifiers.custom_minimum_size.y = 260
	link_qualifiers.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(link_qualifiers)
	link_dialog.confirmed.connect(_add_link)

func show_link_dialog(source: String, target: String, preferred: String = "") -> void:
	if document.is_empty():
		return
	for picker in [link_from, link_to]:
		picker.clear()
		for node in document.nodes:
			picker.add_item(node.label + "  (" + node.id + ")")
			picker.set_item_metadata(picker.item_count - 1, node.id)
	for index in range(document.nodes.size()):
		if document.nodes[index].id == source:
			link_from.select(index)
		if document.nodes[index].id == target:
			link_to.select(index)
	link_qualifiers.text = "{}"
	_refresh_link_relations()
	for index in range(link_relation.item_count):
		if link_relation.get_item_metadata(index) == preferred:
			link_relation.select(index)
	_describe_link()
	link_dialog.popup_centered(Vector2i(830, 620))

func _picker_id(picker: OptionButton) -> String:
	return str(picker.get_item_metadata(picker.selected)) if picker.selected >= 0 else ""

func _refresh_link_relations() -> void:
	link_relation.clear()
	var source: Dictionary = nodes_by_id.get(_picker_id(link_from), {})
	var target: Dictionary = nodes_by_id.get(_picker_id(link_to), {})
	if source.is_empty() or target.is_empty():
		return
	for relation in document.relations:
		if Model.accepts(relation, source, target):
			link_relation.add_item(relation.label + "  [" + relation.id + "]")
			link_relation.set_item_metadata(link_relation.item_count - 1, relation.id)
	_describe_link()

func _describe_link() -> void:
	var relation: Dictionary = relations_by_id.get(_picker_id(link_relation), {})
	link_explanation.text = str(relation.get("description", "No compatible relations. Choose other endpoints or extend the schema."))
	link_dialog.get_ok_button().disabled = relation.is_empty()

func _connection_request(from_name: StringName, from_port: int, to_name: StringName, _to_port: int) -> void:
	var a: Node = graph.get_node(NodePath(str(from_name)))
	var b: Node = graph.get_node(NodePath(str(to_name)))
	var source: String = a.get_meta("atlas_id")
	var target: String = b.get_meta("atlas_id")
	show_link_dialog(source, target, str(port_relations[source][from_port]))

func _add_link() -> void:
	var parser := JSON.new()
	if parser.parse(link_qualifiers.text) != OK or not parser.data is Dictionary:
		_message("Relationship qualifiers must be a JSON object.")
		return
	var source := _picker_id(link_from)
	var target := _picker_id(link_to)
	var relation := _picker_id(link_relation)
	var q: Dictionary = parser.data
	if relations_by_id[relation].semantics == "subjective" and not q.has("holder"):
		if relation == "perceived_as":
			_message("Perceived-as requires the observer's character/group ID in qualifiers.holder.")
			return
		q.holder = source
	var next := document.duplicate(true)
	var scope := "example" if nodes_by_id[source].scope == "example" or nodes_by_id[target].scope == "example" else "definition"
	var id := "e_" + (source + target + str(Time.get_ticks_usec())).sha256_text().substr(0, 16)
	next.edges.append({"id": id, "from": source, "relation": relation, "to": target, "scope": scope, "qualifiers": q})
	if _commit(next, "Created typed relationship. Meaning and context are stored with it."):
		link_dialog.hide()
		inspect_node(source)
		inspect_edge(id)

func _delete_nodes_request(names: Array[StringName]) -> void:
	pending_delete.clear()
	for node_name in names:
		var node := graph.get_node_or_null(NodePath(str(node_name)))
		if node is GraphNode:
			pending_delete.append(str(node.get_meta("atlas_id")))
	_ask_delete()

func delete_selected() -> void:
	pending_delete.clear()
	if selected_collection == "nodes" and nodes_by_id.has(selected_id):
		pending_delete.append(selected_id)
	elif selected_collection == "edges" and not selected_id.is_empty():
		delete_dialog.dialog_text = "Delete this relationship only? Undo is available."
		delete_dialog.popup_centered()
		return
	_ask_delete()

func _ask_delete() -> void:
	if pending_delete.is_empty():
		return
	var affected := 0
	for edge in document.edges:
		if _edge_references(edge, pending_delete):
			affected += 1
	delete_dialog.dialog_text = "Delete %d node(s) and %d relationships that reference them, including qualifier references? View focus/layout references will be cleared. Undo is available." % [pending_delete.size(), affected]
	delete_dialog.popup_centered()

func _edge_references(edge: Dictionary, ids: Array[String]) -> bool:
	if edge.from in ids or edge.to in ids:
		return true
	for key in ["holder", "context", "object", "feeling", "relationship_type", "claim"]:
		if edge.get("qualifiers", {}).get(key, "") in ids:
			return true
	return false

func _confirm_delete() -> void:
	var next := document.duplicate(true)
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
	_commit(next, "Deleted selected content and validated remaining references.")
	pending_delete.clear()

func _report_validation() -> void:
	if document.is_empty():
		_message("No document loaded.")
		return
	var errors := Model.validate(document)
	_message("Validation passed: IDs, kinds, typed endpoints, holders, scopes, numeric intervals, views and hierarchy cycles." if errors.is_empty() else "\n".join(errors))

func save_document() -> void:
	if document.is_empty():
		return
	var error := Model.save_atomic(document, path, disk_hash)
	if not error.is_empty():
		_message(error)
		return
	disk_hash = FileAccess.get_file_as_string(path).sha256_text()
	dirty = false
	_message("Saved " + path + ". Backup retained when replacing an existing file.")

func _export_copy(export_path: String) -> void:
	if document.is_empty():
		return
	if ProjectSettings.globalize_path(export_path) == ProjectSettings.globalize_path(path):
		save_document()
		return
	var expected := FileAccess.get_file_as_string(export_path).sha256_text() if FileAccess.file_exists(export_path) else ""
	var error := Model.save_atomic(document, export_path, expected)
	_message("Exported copy to " + export_path + "; current document path unchanged." if error.is_empty() else error)

func write_recovery() -> void:
	if dirty and not document.is_empty():
		var recovery := "user://hughes_atlas_recovery.json"
		var expected := FileAccess.get_file_as_string(recovery).sha256_text() if FileAccess.file_exists(recovery) else ""
		var error := Model.save_atomic(document, recovery, expected)
		if not error.is_empty():
			push_warning("Hughes Atlas recovery failed: " + error)
