extends SceneTree
# 給 content/maps/*.json 中缺 id 的 monster entity 補 UUIDv7 並寫回（重排版）。
# 執行：godot --headless --path . --script res://tools/assign_encounter_uuids.gd
func _initialize() -> void:
	var dir := "res://content/maps"
	var da := DirAccess.open(dir)
	var changed := 0
	for f in da.get_files():
		if not f.ends_with(".json"):
			continue
		var path := "%s/%s" % [dir, f]
		var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var modified := false
		for e in raw.get("entities", []):
			if typeof(e) == TYPE_DICTIONARY and String(e.get("type", "")) == "monster" and String(e.get("id", "")) == "":
				e["id"] = Uuidv7.generate()
				modified = true
		if modified:
			var fw := FileAccess.open(path, FileAccess.WRITE)
			fw.store_string(JSON.stringify(raw, "\t"))
			fw.close()
			changed += 1
			print("uid 補入：", f)
	print("完成，更新 %d 張圖" % changed)
	quit()
