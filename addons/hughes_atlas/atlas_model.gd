@tool
extends RefCounted
## Plain-data authoring model. It deliberately executes no NPC behavior.
const SEED_PATH := "res://addons/hughes_atlas/seed_catalog.json"
const DEFAULT_PATH := "res://data/atlas/hughes_atlas.json"
const VERSION := 1

static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "File not found: " + path}
	var parser := JSON.new()
	var error := parser.parse(FileAccess.get_file_as_string(path))
	if error != OK:
		return {"error": "%s, line %d: %s" % [path, parser.get_error_line(), parser.get_error_message()]}
	if not parser.data is Dictionary:
		return {"error": "Expected a JSON object: " + path}
	return {"data": parser.data}

static func read_seed() -> Dictionary:
	var result := read_json(SEED_PATH)
	if result.has("error"):
		return result
	for key in ["groups", "links"]:
		var part := read_json(SEED_PATH.get_base_dir().path_join("seed_nodes.json" if key == "groups" else "seed_links.json"))
		if part.has("error"):
			return part
		if not part.data.get(key) is Array:
			return {"error": "Seed section must be an array: " + key}
		result.data[key] = part.data[key]
	return result

static func seed_errors(seed: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["kinds", "relations", "groups", "links", "views"]:
		if not seed.get(key) is Array:
			errors.append("Seed section must be an array: " + key)
	if not errors.is_empty():
		return errors
	var kinds := index_by_id(seed.kinds)
	var relations := index_by_id(seed.relations)
	var ids := {}
	for group in seed.groups:
		if not group is Dictionary or not kinds.has(group.get("kind")) or not group.get("rows") is Array:
			errors.append("Malformed seed group.")
			continue
		for row in group.rows:
			if not row is Array or row.size() != 3:
				errors.append("Seed node row must be [suffix, label, description].")
				continue
			if not row[0] is String or not row[1] is String or not row[2] is String:
				errors.append("Seed node cells must be strings.")
				continue
			ids[group.kind + "." + row[0]] = true
	for row in seed.links:
		if not row is Array or row.size() < 3 or row.size() > 4:
			errors.append("Malformed seed link row.")
			continue
		if not row[0] is String or not row[1] is String or not row[2] is String:
			errors.append("Seed link endpoints and relation must be strings.")
			continue
		if not relations.has(row[1]):
			errors.append("Unknown seed relation: " + row[1])
		if row.size() == 4 and not row[3] is Dictionary:
			errors.append("Seed link qualifiers must be an object.")
		for id in (row[0] + " " + row[2]).split(" ", false):
			if not ids.has(id):
				errors.append("Unknown seed endpoint: " + id)
	return errors

static func expand_seed(seed: Dictionary) -> Dictionary:
	var errors := seed_errors(seed)
	if not errors.is_empty():
		return {"schema_version": -1, "seed_errors": errors}
	var doc := {"schema_version": VERSION, "title": seed.get("title", "Hughes Atlas"),
		"kinds": seed.kinds.duplicate(true), "relations": seed.relations.duplicate(true),
		"views": seed.views.duplicate(true), "nodes": [], "edges": [], "layout": {}}
	var by_id := {}
	var rels := index_by_id(doc.relations)
	for group in seed.groups:
		for row in group.rows:
			var id: String = group.kind + "." + row[0]
			var node := {"id": id, "label": row[1], "kind": group.kind,
				"domain": group.domain, "scope": group.get("scope", "definition"),
				"description": row[2], "tags": []}
			doc.nodes.append(node)
			by_id[id] = node
	for row in seed.links:
		for source in str(row[0]).split(" ", false):
			for target in str(row[2]).split(" ", false):
				var qualifiers: Dictionary = row[3].duplicate(true) if row.size() > 3 else {}
				var relation: String = row[1]
				if rels[relation].semantics == "subjective" and not qualifiers.has("holder"):
					qualifiers.holder = source
				var scope := "example" if by_id[source].scope == "example" or by_id[target].scope == "example" else "definition"
				var key := source + "|" + relation + "|" + target + "|" + str(qualifiers.get("id_suffix", ""))
				doc.edges.append({"id": "e_" + key.sha256_text().substr(0, 16),
					"from": source, "relation": relation, "to": target, "scope": scope,
					"qualifiers": qualifiers})
	return doc

static func index_by_id(items: Array) -> Dictionary:
	var result := {}
	for item in items:
		if item is Dictionary and item.has("id"):
			result[item.id] = item
	return result

static func accepts(relation: Dictionary, source: Dictionary, target: Dictionary) -> bool:
	var left: Array = relation.get("source_kinds", [])
	var right: Array = relation.get("target_kinds", [])
	if not ("*" in left or source.kind in left):
		return false
	if not ("*" in right or target.kind in right):
		return false
	return relation.id != "subtype_of" or source.kind == target.kind

static func valid_id(value: Variant) -> bool:
	if not value is String:
		return false
	var pattern := RegEx.new()
	pattern.compile("^[a-z][a-z0-9_.-]*$")
	return pattern.search(value) != null

static func validate(doc: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if doc.has("seed_errors"):
		errors.assign(doc.seed_errors)
		return errors
	if doc.get("schema_version") != VERSION:
		errors.append("Unsupported schema_version; expected 1. No automatic migration.")
	for collection in ["kinds", "relations", "nodes", "edges", "views"]:
		if not doc.get(collection) is Array:
			errors.append(collection + " must be an array.")
	if not errors.is_empty():
		return errors
	for collection in ["kinds", "relations", "nodes", "edges", "views"]:
		var seen := {}
		for item in doc[collection]:
			if not item is Dictionary or not valid_id(item.get("id")):
				errors.append(collection + ": every record needs a stable lowercase id.")
				continue
			if seen.has(item.id):
				errors.append(collection + ": duplicate id " + item.id)
			seen[item.id] = true
	if not errors.is_empty():
		return errors
	var kinds := index_by_id(doc.kinds)
	var nodes := index_by_id(doc.nodes)
	var relations := index_by_id(doc.relations)
	for relation in doc.relations:
		for side in ["source_kinds", "target_kinds"]:
			if not relation.get(side) is Array or relation[side].is_empty():
				errors.append(relation.id + ": " + side + " must be a nonempty array.")
				continue
			for kind in relation[side]:
				if kind != "*" and not kinds.has(kind):
					errors.append(relation.id + ": unknown kind " + str(kind))
		if relation.get("semantics") not in ["structural", "fact", "temporal", "subjective", "normative", "possibility", "design"]:
			errors.append(relation.id + ": unknown semantics.")
		if not relation.get("label") is String:
			errors.append(relation.id + ": label must be text.")
	for node in doc.nodes:
		if not kinds.has(node.get("kind")):
			errors.append(node.id + ": unknown kind.")
		for field in ["label", "domain", "description"]:
			if not node.get(field) is String:
				errors.append(node.id + ": " + field + " must be text.")
		if node.get("scope") not in ["definition", "example"]:
			errors.append(node.id + ": scope must be definition or example.")
		if not node.get("tags", []) is Array:
			errors.append(node.id + ": tags must be an array.")
	if not errors.is_empty():
		return errors
	var adjacency := {"subtype_of": {}, "contains": {}, "precedes": {}}
	for edge in doc.edges:
		var source: String = str(edge.get("from", ""))
		var target: String = str(edge.get("to", ""))
		var relation: String = str(edge.get("relation", ""))
		if not nodes.has(source) or not nodes.has(target) or not relations.has(relation):
			errors.append(edge.id + ": missing endpoint or relation definition.")
			continue
		if not accepts(relations[relation], nodes[source], nodes[target]):
			errors.append(edge.id + ": incompatible endpoint kinds for " + relation)
		if source == target:
			errors.append(edge.id + ": self-links are not supported; use an explicit record.")
		var scope := "example" if nodes[source].scope == "example" or nodes[target].scope == "example" else "definition"
		if edge.get("scope") != scope:
			errors.append(edge.id + ": scope must be " + scope)
		if not edge.get("qualifiers", {}) is Dictionary:
			errors.append(edge.id + ": qualifiers must be an object.")
			continue
		var q: Dictionary = edge.get("qualifiers", {})
		if relations[relation].semantics == "subjective" and not q.has("holder"):
			errors.append(edge.id + ": subjective relations require a knowledge/feeling holder.")
		for ref in ["holder", "context", "object", "feeling", "relationship_type", "claim"]:
			if q.has(ref) and not nodes.has(q[ref]):
				errors.append(edge.id + ": unknown " + ref + " reference.")
		for ref in ["holder", "feeling", "relationship_type", "claim"]:
			if not q.has(ref) or not nodes.has(q[ref]):
				continue
			var allowed: Array = {"holder": ["character", "group"], "feeling": ["feeling"],
				"relationship_type": ["relationship"], "claim": ["belief", "rumor"]}[ref]
			if nodes[q[ref]].kind not in allowed:
				errors.append(edge.id + ": wrong kind for " + ref)
		if relation == "feels_toward" and (not q.has("feeling") or q.get("holder") != source):
			errors.append(edge.id + ": feels_toward needs a feeling and holder=source.")
		if relation == "has_relationship" and not q.has("relationship_type"):
			errors.append(edge.id + ": specify relationship_type.")
		for fraction in ["confidence", "strength"]:
			if q.has(fraction):
				if not (q[fraction] is float or q[fraction] is int) or q[fraction] < 0 or q[fraction] > 1:
					errors.append(edge.id + ": " + fraction + " must be between 0 and 1.")
		for tick in ["start_tick", "end_tick"]:
			if q.has(tick) and not (q[tick] is float or q[tick] is int):
				errors.append(edge.id + ": numeric " + tick + " required.")
		if q.get("start_tick") is float or q.get("start_tick") is int:
			if (q.get("end_tick") is float or q.get("end_tick") is int) and q.end_tick < q.start_tick:
				errors.append(edge.id + ": end_tick precedes start_tick.")
		if adjacency.has(relation):
			if not adjacency[relation].has(source):
				adjacency[relation][source] = []
			adjacency[relation][source].append(target)
	for relation in adjacency:
		for start in adjacency[relation]:
			var pending: Array = adjacency[relation][start].duplicate()
			var visited := {}
			while not pending.is_empty():
				var next: String = pending.pop_back()
				if next == start:
					errors.append("Cycle in " + relation + " at " + start)
					break
				if not visited.has(next):
					visited[next] = true
					pending.append_array(adjacency[relation].get(next, []))
	for view in doc.views:
		if not view.get("label") is String or not view.get("domains") is Array:
			errors.append(view.id + ": view needs label and domains array.")
		if view.has("focus") and not nodes.has(view.focus):
			errors.append(view.id + ": view focus references a missing node.")
	if not doc.get("layout", {}) is Dictionary:
		errors.append("layout must be an object.")
	else:
		for view_key in doc.get("layout", {}):
			if not doc.layout[view_key] is Dictionary:
				errors.append("layout view must be an object.")
				continue
			for id in doc.layout[view_key]:
				var xy: Variant = doc.layout[view_key][id]
				if not xy is Array or xy.size() != 2:
					errors.append("layout positions must be [x, y].")
				elif not (xy[0] is float or xy[0] is int) or not (xy[1] is float or xy[1] is int):
					errors.append("layout coordinates must be numeric.")
	return errors

static func save_atomic(doc: Dictionary, path: String, expected_hash: String) -> String:
	var errors := validate(doc)
	if not errors.is_empty():
		return "Save refused: " + "\n".join(errors)
	var current := FileAccess.get_file_as_string(path).sha256_text() if FileAccess.file_exists(path) else ""
	if current != expected_hash:
		return "Save refused: the file changed outside this atlas. Export a copy, then reload and reconcile."
	var directory := ProjectSettings.globalize_path(path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return "Cannot create data directory: " + directory
	var text := JSON.stringify(doc, "\t", true) + "\n"
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return "Cannot write temporary file: " + error_string(FileAccess.get_open_error())
	file.store_string(text)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or FileAccess.get_file_as_string(temp) != text:
		return "Temporary write failed. Original file was not changed."
	var absolute := ProjectSettings.globalize_path(path)
	var backup := absolute + ".bak"
	var had_file := FileAccess.file_exists(path)
	if had_file:
		if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup) != OK:
			return "Cannot replace backup. Original file was not changed."
		if DirAccess.rename_absolute(absolute, backup) != OK:
			return "Cannot make backup. Original file was not changed."
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), absolute) != OK:
		if had_file:
			DirAccess.rename_absolute(backup, absolute)
		return "Could not install saved file; inspect the .bak recovery copy."
	return ""
