extends SceneTree

const SAVE_PATH := "user://color_queens_save.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous_save := ""
	var had_save := FileAccess.file_exists(SAVE_PATH)
	if had_save:
		previous_save = FileAccess.get_file_as_string(SAVE_PATH)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	var packed: PackedScene = load("res://scenes/main.tscn")
	assert(packed != null, "Main scene must load")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	assert(not game.tutorial_completed, "Fresh save should require tutorial")
	assert(game.in_tutorial, "Fresh install should enter tutorial immediately")
	assert(game.tutorial_step_index == 0, "Tutorial should start at step 1")
	assert(not game.undo_button.visible, "Tutorial step 1 should hide undo")
	assert(not game.clear_button.visible, "Tutorial step 1 should hide clear")
	assert(not game.hint_button.visible, "Tutorial step 1 should hide hint")

	game._on_cell_pressed(1, 1)
	assert(game.cell_states[1][1] == "blocked", "Tutorial step 1 first tap should mark X")
	game._on_cell_pressed(1, 1)
	assert(game.cell_states[1][1] == "piece", "Tutorial step 1 second tap should place crown")
	game._on_cell_pressed(1, 1)
	assert(game.is_completed, "Tutorial step 1 should complete after cancel")
	await create_timer(2.1).timeout
	await process_frame
	assert(game.tutorial_step_index == 1, "Next should enter tutorial step 2")

	game._on_cell_pressed(0, 0)
	game._on_cell_pressed(0, 0)
	assert(game.is_completed, "Tutorial step 2 should complete after placing crown")
	await create_timer(2.1).timeout
	await process_frame

	game._on_cell_pressed(0, 0)
	assert(game.is_completed, "Tutorial step 3 should complete after excluding adjacent cell")
	await create_timer(2.1).timeout
	await process_frame

	assert(game.undo_button.visible, "Tutorial step 4 should show undo")
	assert(game.clear_button.visible, "Tutorial step 4 should show clear")
	assert(game.hint_button.visible, "Tutorial step 4 should show hint")
	assert(not game.undo_button.disabled, "Tutorial step 4 should start with undo enabled")
	assert(game.clear_button.disabled, "Tutorial step 4 should gate clear until undo")
	assert(game.hint_button.disabled, "Tutorial step 4 should gate hint until clear")
	game._undo()
	assert(game.tutorial_button_stage == 1, "Tutorial step 4 undo should advance button teaching")
	assert(not game.clear_button.disabled, "Tutorial step 4 should enable clear after undo")
	game._clear_board()
	assert(game.tutorial_button_stage == 2, "Tutorial step 4 clear should advance button teaching")
	assert(not game.hint_button.disabled, "Tutorial step 4 should enable hint after clear")
	game._use_hint()
	assert(game.is_completed, "Tutorial step 4 should complete after using hint")
	await create_timer(2.1).timeout
	await process_frame
	assert(game.tutorial_completed, "Tutorial should be saved complete")
	assert(not game.in_tutorial, "Game should leave tutorial")
	assert(int(game.current_level["levelId"]) == 1, "Tutorial should enter formal level 1")
	assert(game._piece_positions().is_empty(), "Formal level 1 should start clean")
	assert(not game.tutorial_skip_button.visible, "Formal level should hide the tutorial top button")

	game._show_home()
	await process_frame
	game._simulate_new_user_flow()
	await process_frame
	assert(game.in_tutorial, "New user button should re-enter tutorial")
	assert(not game.tutorial_completed, "New user button should reset tutorial completion")
	assert(game.tutorial_step_index == 0, "New user button should restart from tutorial step 1")

	game.queue_free()
	await process_frame
	_restore_save(had_save, previous_save)
	print("TUTORIAL SMOKE TEST PASSED")
	quit()


func _restore_save(had_save: bool, contents: String) -> void:
	if had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		file.store_string(contents)
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
