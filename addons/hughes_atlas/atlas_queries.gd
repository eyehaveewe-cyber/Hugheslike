@tool
extends RefCounted
## Read-only graph queries. Connectivity is never evidence of causation or knowledge.
const Model = preload("atlas_model.gd")

static func matches(edge: Dictionary, relations: Dictionary, filter: Dictionary) -> bool:
	var relation: Dictionary = relations[edge.relation]
	if not str(filter.get("relation", "")).is_empty() and edge.relation != filter.relation:
		return false
	if not str(filter.get("semantics", "")).is_empty() and relation.semantics != filter.semantics:
		return false
	var holder: String = str(filter.get("holder", ""))
	if not holder.is_empty() and relation.semantics == "subjective" and edge.get("qualifiers", {}).get("holder") != holder:
		return false
	var scope: int = int(filter.get("scope", 0))
	return scope == 0 or (scope == 1 and edge.scope == "definition") or (scope == 2 and edge.scope == "example")

static func arcs(doc: Dictionary, filter: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var relations: Dictionary = Model.index_by_id(doc.relations)
	for edge in doc.edges:
		if not matches(edge, relations, filter):
			continue
		result.append({"from": edge.from, "to": edge.to, "relation": edge.relation,
			"edge_id": edge.id, "qualifier": "", "symmetric": relations[edge.relation].get("symmetric", false)})
		if filter.get("qualifiers", false):
			for key in Model.REFERENCE_KEYS:
				var target: String = str(edge.get("qualifiers", {}).get(key, ""))
				if not target.is_empty() and target != edge.from and target != edge.to:
					result.append({"from": edge.from, "to": target, "relation": edge.relation,
						"edge_id": edge.id, "qualifier": key, "symmetric": false})
	return result

static func adjacency(graph_arcs: Array[Dictionary], direction: String = "both") -> Dictionary:
	var result: Dictionary = {}
	for arc in graph_arcs:
		for reverse in [false, true]:
			if direction == "out" and reverse and not arc.symmetric:
				continue
			if direction == "in" and not reverse and not arc.symmetric:
				continue
			var source: String = arc.to if reverse else arc.from
			var target: String = arc.from if reverse else arc.to
			if not result.has(source):
				result[source] = []
			result[source].append({"target": target, "arc": arc, "reverse": reverse})
	return result

static func neighborhood(doc: Dictionary, focus: String, hops: int, filter: Dictionary) -> Dictionary:
	var links: Dictionary = adjacency(arcs(doc, filter), str(filter.get("direction", "both")))
	var distances: Dictionary = {focus: 0}
	var frontier: Array[String] = [focus]
	for step in range(clampi(hops, 0, 3)):
		var next: Array[String] = []
		for id in frontier:
			for hop in links.get(id, []):
				if not distances.has(hop.target):
					distances[hop.target] = step + 1
					next.append(str(hop.target))
		frontier = next
	return distances

static func shortest_path(doc: Dictionary, source: String, target: String, filter: Dictionary, max_hops: int = 8) -> Dictionary:
	var nodes: Dictionary = Model.index_by_id(doc.nodes)
	if not nodes.has(source) or not nodes.has(target):
		return {"found": false, "reason": "Choose two existing nodes."}
	if source == target:
		return {"found": true, "steps": [], "visited": 1}
	var links: Dictionary = adjacency(arcs(doc, filter), str(filter.get("direction", "both")))
	var visited: Dictionary = {source: true}
	var parents: Dictionary = {}
	var frontier: Array[String] = [source]
	var found: bool = false
	for level in range(max_hops):
		var next: Array[String] = []
		for id in frontier:
			for hop in links.get(id, []):
				if visited.has(hop.target):
					continue
				visited[hop.target] = true
				parents[hop.target] = {"previous": id, "hop": hop}
				if hop.target == target:
					found = true
					break
				next.append(str(hop.target))
			if found:
				break
		if found or next.is_empty():
			break
		frontier = next
	if not found:
		return {"found": false, "reason": "No connection within %d hops under these filters. This says nothing about causation." % max_hops, "visited": visited.size()}
	var steps: Array[Dictionary] = []
	var cursor: String = target
	while cursor != source:
		var parent: Dictionary = parents[cursor]
		steps.push_front({"from": parent.previous, "to": cursor, "arc": parent.hop.arc, "reverse": parent.hop.reverse})
		cursor = str(parent.previous)
	return {"found": true, "steps": steps, "visited": visited.size()}
