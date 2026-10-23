@tool
extends RefCounted
## Catalog boundary: reusable core + additive authored packs, never runtime AI.
const Core = preload("atlas_core.gd")
const Storage = preload("atlas_storage.gd")
const DEFAULT_PATH := Core.DEFAULT_PATH
const SEED_PATH := Core.SEED_PATH
const VERSION := Core.VERSION
const PACK_PATH := "res://addons/hughes_atlas/seed_extension.json"
const COMMERCE_MANIFEST := "res://addons/hughes_atlas/packs/commerce_manifest.json"
const REFERENCE_KEYS := ["holder", "context", "object", "feeling", "relationship_type", "claim"]

static func read_json(path: String) -> Dictionary:
	return Core.read_json(path)

static func index_by_id(items: Array) -> Dictionary:
	return Core.index_by_id(items)

static func accepts(relation: Dictionary, source: Dictionary, target: Dictionary) -> bool:
	return Core.accepts(relation, source, target)

static func valid_id(value: Variant) -> bool:
	return Core.valid_id(value)

static func read_seed(include_extensions: bool = true, include_commerce: bool = true) -> Dictionary:
	var result: Dictionary = Core.read_seed()
	if result.has("error") or not include_extensions:
		return result
	var extension: Dictionary = read_json(PACK_PATH)
	if extension.has("error"):
		return extension
	var seed: Dictionary = result.data.duplicate(true)
	for section in ["kinds", "relations", "groups", "links", "views"]:
		var additions: Variant = extension.data.get(section, [])
		if not additions is Array:
			return {"error": "Extension " + section + " must be an array."}
		seed[section].append_array(additions)
	seed["catalog_revision"] = "0.2"
	if include_commerce:
		return append_commerce(seed)
	return {"data": seed}

static func append_commerce(original: Dictionary, manifest_path: String = COMMERCE_MANIFEST) -> Dictionary:
	var manifest_result: Dictionary = read_json(manifest_path)
	if manifest_result.has("error"):
		return manifest_result
	var manifest: Dictionary = manifest_result.data
	if manifest.get("pack_format") != 1 or not manifest.get("files") is Array:
		return {"error": "Commerce manifest requires pack_format=1 and a files array."}
	var seed: Dictionary = original.duplicate(true)
	var loaded: Dictionary = {}
	var pack_ids: Dictionary = {}
	var sources: Array[String] = []
	for filename in manifest.files:
		if not filename is String or filename.is_empty() or filename.get_file() != filename or filename.get_extension() != "json" or filename.begins_with("."):
			return {"error": "Catalog pack filenames must be local JSON basenames."}
		if loaded.has(filename):
			return {"error": "Duplicate catalog pack filename: " + filename}
		loaded[filename] = true
		var part: Dictionary = read_json(manifest_path.get_base_dir().path_join(filename))
		if part.has("error"):
			return part
		var pack_id: Variant = part.data.get("pack_id")
		if not valid_id(pack_id) or pack_ids.has(pack_id):
			return {"error": "Catalog packs require distinct stable pack_id values."}
		pack_ids[pack_id] = true
		for section in ["kinds", "relations", "groups", "links", "views"]:
			var additions: Variant = part.data.get(section, [])
			if not additions is Array or not seed.get(section) is Array:
				return {"error": filename + ": " + section + " must be an array."}
			seed[section].append_array(additions)
		sources.append(pack_id)
	seed["catalog_revision"] = str(manifest.get("catalog_revision", "0.3"))
	seed["catalog_packs"] = sources
	return {"data": seed}

static func expand_seed(seed: Dictionary) -> Dictionary:
	var doc: Dictionary = Core.expand_seed(seed)
	if not doc.has("seed_errors"):
		doc["catalog_revision"] = str(seed.get("catalog_revision", "0.1"))
		if seed.has("catalog_packs"):
			doc["catalog_packs"] = seed.catalog_packs.duplicate(true)
	return doc

static func validate(doc: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var json_error: String = Storage.json_problem(doc)
	if not json_error.is_empty():
		return [json_error]
	for section in ["kinds", "relations", "nodes", "edges", "views"]:
		if not doc.get(section) is Array:
			return Core.validate(doc)
		for record in doc[section]:
			if not record is Dictionary:
				return [section + " entries must be objects."]
			for field in ["id", "kind", "from", "to", "relation", "focus"]:
				if record.has(field) and not record[field] is String:
					errors.append(section + ": " + field + " must be a string.")
			if section == "relations":
				for side in ["source_kinds", "target_kinds", "required_qualifiers"]:
					if record.has(side):
						if not record[side] is Array:
							errors.append(side + " must be an array.")
						else:
							for kind in record[side]:
								if not kind is String:
									errors.append(side + " entries must be strings.")
			if section == "edges" and record.get("qualifiers", {}) is Dictionary:
				for field in REFERENCE_KEYS:
					if record.get("qualifiers", {}).has(field) and not record.qualifiers[field] is String:
						errors.append("Qualifier " + field + " must be a node ID string.")
	if not errors.is_empty():
		return errors
	errors = Core.validate(doc)
	if not errors.is_empty():
		return errors
	var relations: Dictionary = index_by_id(doc.relations)
	for edge in doc.edges:
		var relation: Dictionary = relations[edge.relation]
		var q: Dictionary = edge.get("qualifiers", {})
		for required in relation.get("required_qualifiers", []):
			if not q.has(required):
				errors.append(str(edge.id) + ": requires qualifier " + str(required))
		if relation.get("semantics") == "subjective" and relation.id != "perceived_as":
			if q.get("holder") != edge.from:
				errors.append(str(edge.id) + ": this subjective predicate belongs to the source person.")
		if q.has("evidence_mode") and q.evidence_mode not in ["direct", "reported", "inferred", "imagined"]:
			errors.append(str(edge.id) + ": evidence_mode must be direct, reported, inferred or imagined.")
	return errors

static func save_atomic(doc: Dictionary, path: String, expected_hash: String) -> String:
	var errors: Array[String] = validate(doc)
	if not errors.is_empty():
		return "Save refused: " + "\n".join(errors)
	return Storage.save_json(doc, path, expected_hash)

static func merge_missing(existing: Dictionary, incoming: Dictionary) -> Dictionary:
	var errors: Array[String] = validate(existing)
	errors.append_array(validate(incoming))
	if not errors.is_empty():
		return {"error": "\n".join(errors)}
	var merged: Dictionary = existing.duplicate(true)
	var counts: Dictionary = {}
	var retained: int = 0
	for section in ["kinds", "relations", "nodes", "edges", "views"]:
		var known: Dictionary = index_by_id(merged[section])
		counts[section] = 0
		for record in incoming[section]:
			if not known.has(record.id):
				merged[section].append(record.duplicate(true))
				known[record.id] = record
				counts[section] += 1
			elif not Storage.json_equal(known[record.id], record):
				retained += 1
	merged["catalog_revision"] = str(incoming.get("catalog_revision", "0.2"))
	if incoming.has("catalog_packs"):
		merged["catalog_packs"] = incoming.catalog_packs.duplicate(true)
	errors = validate(merged)
	if not errors.is_empty():
		return {"error": "Catalog merge conflicts with authored schema: " + "\n".join(errors)}
	return {"data": merged, "added": counts, "retained_edits": retained}
