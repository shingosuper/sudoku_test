extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/level_editor.tscn")
	assert(packed != null, "Level editor scene must load")
	var editor = packed.instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame

	assert(editor.levels.size() >= 5, "Editor must load levels")
	assert(editor.board != null, "Editor board must exist")
	assert(editor.board.get_child_count() > 0, "Editor must create editable cells")
	editor._on_cell_pressed(0, 0)
	assert(int(editor.current_level["regions"][0][0]) == editor.selected_region, "Region paint must update a cell")
	editor._toggle_solution_mode()
	assert(editor.paint_solution, "Editor must switch to solution mode")

	editor.queue_free()
	await process_frame
	print("EDITOR SMOKE TEST PASSED: load, paint and mode switch")
	quit()
