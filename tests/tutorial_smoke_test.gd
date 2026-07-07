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
	await create_timer(0.5).timeout
	await process_frame

	assert(not game.tutorial_completed, "Fresh save should require tutorial")
	assert(game.in_tutorial, "Fresh install should enter tutorial immediately")
	assert(game.tutorial_step_index == 0, "Tutorial should start at the single onboarding map")
	assert(int(game.current_level["rows"]) == 5 and int(game.current_level["cols"]) == 5, "Tutorial should use one larger 5x5 map")
	assert(str(game.current_level["kind"]) == "single_map", "Tutorial should run as one guided map")
	assert(not game.top_home_button.visible, "Tutorial should hide the home button")
	assert(game.tutorial_skip_button.visible, "Tutorial should allow skipping")
	assert(game.tutorial_skip_button.text == "跳过", "Tutorial skip button should use full copy")
	assert(game.undo_button.visible, "Tutorial should keep undo available")
	assert(not game.clear_button.visible, "Tutorial should remove clear from the map")
	assert(game.hint_button.visible, "Tutorial should keep hint available")
	assert(game.hint_button.disabled, "Hint should wait until the clue step")
	assert(game.coach_label.text == "每个颜色区域，有且仅有一个皇冠，双击找到第一个皇冠", "Tutorial should start with the first color-region crown clue")
	assert(game.coach_label.get_theme_font_size("font_size") >= 18, "Tutorial guidance should use larger text")
	assert(game.coach_label.get_theme_color("font_color") == Color("#31506D"), "Tutorial guidance should use dark text")
	assert(game.tutorial_hand_label.visible, "Tutorial should show hand pointer")
	assert(game.tutorial_hand_label.get_theme_font_size("font_size") >= 56, "Tutorial hand should be large and easy to notice")
	assert(game.board.tutorial_mask_enabled, "Tutorial should mask non-target cells")
	assert(game.board.tutorial_focus_cell == Vector2i(2, 2), "Tutorial should focus the first crown")

	game._on_cell_pressed(2, 2)
	assert(game.cell_states[2][2] == "empty", "Single tap should not place the first crown")
	game._on_cell_double_pressed(2, 2)
	await process_frame
	assert(game.cell_states[2][2] == "piece", "Double tap should place the first crown")
	assert(game.coach_label.text == "皇冠周围不会出现皇冠，滑动排除周围的格子", "Tutorial should teach surrounding exclusions after first crown")
	assert(game.board.tutorial_focus_cell == Vector2i(2, 1), "Tutorial should start clockwise from the top adjacent cell")

	await _complete_current_exclusions(game)
	assert(game.tutorial_interaction_stage == game.TUTORIAL_PHASE_HINT, "Tutorial should ask for a hint after exclusions")
	assert(game.coach_label.text == "点击提示，获取线索", "Tutorial should guide hint after exclusions")
	assert(not game.hint_button.disabled, "Hint button should be enabled at the clue step")
	await create_timer(0.25).timeout
	await process_frame
	assert(game.tutorial_hand_control == game.hint_button, "Tutorial should point to the hint button")

	game._use_hint()
	await process_frame
	assert(game.tutorial_interaction_stage == game.TUTORIAL_PHASE_HINT_PLACE, "Hint should move to guided crown placement")
	assert(game.coach_label.text == "每个颜色区域，都有一个皇冠，双击找到皇冠", "Hint should explain the color-region crown clue")
	assert(game.board.tutorial_focus_cell == Vector2i(1, 0), "Hint should focus the next crown")
	game._on_cell_pressed(0, 1)
	assert(game.cell_states[0][1] == "empty", "Hinted crown still requires a double tap")
	game._on_cell_double_pressed(0, 1)
	await process_frame
	assert(game.cell_states[0][1] == "piece", "Double tap should place the hinted crown")

	await _complete_current_exclusions(game)
	assert(game.tutorial_interaction_stage == game.TUTORIAL_PHASE_HINT_PLACE, "Tutorial should directly reveal later crown clues")
	assert(game.coach_label.text == "每个颜色区域，都有一个皇冠，双击找到皇冠", "Later clue should skip hint-button teaching")
	assert(game.hint_button.disabled, "Hint button should not be guided after the first hint teaching")
	assert(game.board.tutorial_focus_cell == Vector2i(4, 1), "Direct clue should focus the next crown")
	game._on_cell_double_pressed(1, 4)
	await process_frame

	await _complete_current_exclusions(game)
	assert(game.tutorial_interaction_stage == game.TUTORIAL_PHASE_HINT_PLACE, "Tutorial should keep skipping hint-button teaching")
	assert(game.board.tutorial_focus_cell == Vector2i(3, 4), "Direct clue should focus the following crown")
	game._on_cell_double_pressed(4, 3)
	await process_frame

	await _complete_current_exclusions(game)
	assert(game.tutorial_interaction_stage == game.TUTORIAL_PHASE_HINT_PLACE, "Final crown should skip the hint button")
	assert(game.hint_button.disabled, "Hint should stay disabled when only the final crown remains")
	assert(game.coach_label.text == "每行、每列，都一定会有一个皇冠，双击找到最后一个皇冠", "Final crown should be guided directly")
	assert(game.board.tutorial_focus_cell == Vector2i(0, 3), "Final step should focus the last crown")
	game._on_cell_double_pressed(3, 0)
	await process_frame

	assert(game.is_completed, "Tutorial should complete after all crowns are found")
	assert(game._piece_positions().size() == 5, "Tutorial should find all five crowns on one map")
	assert(game.coach_label.text == "已经了解全部规则，开始真正的挑战吧！", "Tutorial should show final challenge copy")
	assert(game.completion_overlay.visible, "Tutorial should show final start challenge overlay")
	assert(game.completion_next_button.text == "开始挑战", "Tutorial final button should start challenge")

	game._next_level()
	await process_frame
	assert(game.tutorial_completed, "Tutorial should be saved complete")
	assert(not game.in_tutorial, "Game should leave tutorial")
	assert(int(game.current_level["levelId"]) == 1, "Tutorial should enter formal level 1")
	assert(game._piece_positions().is_empty(), "Formal level 1 should start clean")
	assert(not game.tutorial_skip_button.visible, "Formal level should hide the tutorial top button")
	assert(game.top_home_button.visible, "Formal level should restore the home button")
	assert(not game.board.tutorial_mask_enabled, "Formal level should not keep tutorial mask")

	game._show_home()
	await process_frame
	game._simulate_new_user_flow()
	await process_frame
	assert(game.in_tutorial, "New user button should re-enter tutorial")
	assert(not game.tutorial_completed, "New user button should reset tutorial completion")
	assert(game.tutorial_step_index == 0, "New user button should restart tutorial")

	game.queue_free()
	await process_frame
	_restore_save(had_save, previous_save)
	print("TUTORIAL SMOKE TEST PASSED")
	quit()


func _complete_current_exclusions(game) -> void:
	while game.tutorial_interaction_stage == game.TUTORIAL_PHASE_ADJACENT or game.tutorial_interaction_stage == game.TUTORIAL_PHASE_ROW_COL:
		if game.tutorial_interaction_stage == game.TUTORIAL_PHASE_ROW_COL:
			assert(game._tutorial_hand_cell_action() == "single", "Row/column phase should demonstrate tapping, not sliding")
			assert(game.coach_label.text == "皇冠的同行同列不会出现皇冠，标记排除", "Row/column phase should use concise exclusion copy")
			for line_cell in game._tutorial_row_col_cells(game.tutorial_active_crown):
				assert(game.board.guide_cells.has(line_cell), "Row/column phase should keep the entire line highlighted")
		else:
			assert(game._tutorial_hand_cell_action() == "slide", "Adjacent phase should demonstrate sliding")
		var target: Vector2i = _last_empty_valid_exclusion_cell(game)
		assert(target.x >= 0, "Exclusion phase should always have a guided target")
		game._on_cell_dragged(target.y, target.x)
		await process_frame


func _last_empty_valid_exclusion_cell(game) -> Vector2i:
	var result := Vector2i(-1, -1)
	for cell in game._tutorial_single_map_valid_exclusion_cells():
		if game.cell_states[cell.y][cell.x] == "empty":
			result = cell
	return result


func _restore_save(had_save: bool, contents: String) -> void:
	if had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		file.store_string(contents)
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
