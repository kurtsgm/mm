class_name DialogueData
extends RefCounted
# 對話圖（node graph）。畸形（缺 start / start 不在 nodes / nodes 非 dict / goto 斷鏈）→ parse 回 null。

var id: String = ""
var start: String = ""
var nodes: Dictionary = {}   # node_id -> { text, image, choices }

static func parse(raw: Dictionary) -> DialogueData:
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var start_id := String(raw.get("start", ""))
	var raw_nodes = raw.get("nodes", null)
	if start_id == "" or typeof(raw_nodes) != TYPE_DICTIONARY:
		return null
	if not raw_nodes.has(start_id):
		return null
	var parsed_nodes := {}
	for nid in raw_nodes:
		var rn = raw_nodes[nid]
		if typeof(rn) != TYPE_DICTIONARY:
			return null
		var choices := []
		for rc in rn.get("choices", []):
			if typeof(rc) != TYPE_DICTIONARY:
				return null
			var goto = rc.get("goto", null)
			var goto_s = null if goto == null else String(goto)
			if goto_s != null and not raw_nodes.has(goto_s):
				return null
			choices.append({
				"text": String(rc.get("text", "")),
				"require": rc.get("require", null),
				"effects": rc.get("effects", []),
				"goto": goto_s,
			})
		parsed_nodes[String(nid)] = {
			"text": String(rn.get("text", "")),
			"image": String(rn.get("image", "")),
			"choices": choices,
		}
	var d := DialogueData.new()
	d.id = String(raw.get("id", ""))
	d.start = start_id
	d.nodes = parsed_nodes
	return d

func has_node(node_id: String) -> bool:
	return nodes.has(node_id)

func node(node_id: String) -> Dictionary:
	return nodes.get(node_id, {})
