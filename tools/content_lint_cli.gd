extends SceneTree

func _initialize() -> void:
	var errors := ContentLint.run()
	for error in errors:
		print("ERROR ", error)
	print("Content registry: %d errors" % errors.size())
	quit(0 if errors.is_empty() else 1)
