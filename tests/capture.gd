extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	if not _save_viewport("res://docs/screenshots/store-in-engine.png"):
		quit(1)
		return
	scene._plan_interaction("returns")
	for i in 40:
		scene._process(0.2)
	scene.journal_open = true
	scene.queue_redraw()
	await process_frame
	await process_frame
	if not _save_viewport("res://docs/screenshots/returns-and-notebook-in-engine.png"):
		quit(1)
		return
	quit()

func _save_viewport(path: String) -> bool:
	var image = root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("No rendered viewport image is available.")
		return false
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("Could not save the engine viewport.")
		return false
	print("Captured engine viewport: ", path, " (", image.get_width(), "x", image.get_height(), ")")
	return true
