@tool
extends RefCounted
## Catalog boundary: reusable core + additive authored packs, never runtime AI.
const Core = preload("atlas_core.gd")
const Storage = preload("atlas_storage.gd")
const DEFAULT_PATH := Core.DEFAULT_PATH
const SEED_PATH := Core.SEED_PATH
const VERSION := Core.VERSION
const PACK_PATH := "res://addons/hughes_atlas/seed_extension.json"
const REFERENCE_KEYS := ["holder", "context", "object", "feeling", "relationship_type", "claim"]

static func read_json(path: String) -> Dictionary:
	return Core.read_json(path)

static func index_by_id(items: Array) -> Dictionary:
	return Core.index_by_id(items)

static func accepts(relation: Dictionary, source: Dictionary, target: Dictionary) -> bool:
	return Core.accepts(relation, source, target)

static func valid_id(value: Variant) -> bool:
	return Core.valid_id(value)

static func read_seed(include_extensions: bool = true) -> Dictionary:
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
	return {"data": seed}

static func expand_seed(seed: Dictionary) -> Dictionary:
	var doc: Dictionary = Core.expand_seed(seed)
	if not doc.has("seed_errors"):
		doc["catalog_revision"] = str(seed.get("catalog_revision", "0.1"))
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
	errors = validate(merged)
	if not errors.is_empty():
		return {"error": "Catalog merge conflicts with authored schema: " + "\n".join(errors)}
	return {"data": merged, "added": counts, "retained_edits": retained}
