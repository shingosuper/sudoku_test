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
	assert(game.coach_label.text == "请点击该格子", "Tutorial step 1 should start with tap instruction")
	assert(game.tutorial_hand_label.visible, "Tutorial step 1 should show hand pointer")

	game._on_cell_pressed(1, 1)
	assert(game.cell_states[1][1] == "blocked", "Tutorial step 1 first tap should mark X")
	assert(game.coach_label.text == "标注排除成功，再次点击", "Tutorial step 1 first tap should explain blocked mark")
	game._on_cell_pressed(1, 1)
	assert(game.cell_states[1][1] == "piece", "Tutorial step 1 second tap should place crown")
	assert(game.coach_label.text == "标注皇冠成功，再次点击", "Tutorial step 1 second tap should explain crown mark")
	game._on_cell_pressed(1, 1)
	assert(game.is_completed, "Tutorial step 1 should complete after cancel")
	assert(game.coach_label.text == "撤销成功，完成操作", "Tutorial step 1 third tap should explain clearing mark")
	assert(not game.tutorial_hand_label.visible, "Tutorial step 1 should hide hand after completion")
	await create_timer(2.1).timeout
	await process_frame
	assert(game.tutorial_step_index == 1, "Next should enter tutorial step 2")
	assert(game._piece_positions().is_empty(), "Tutorial step 2 should start without pre-placed crowns")
	assert(game.coach_label.text == "看高亮的这一行和这一列，交叉处就是要放皇冠的格子。", "Tutorial step 2 should explain row and column crossing")
	assert(game.tutorial_hand_label.visible, "Tutorial step 2 should show hand pointer")
	assert(game.board.guide_cells.size() == 7, "Tutorial step 2 should highlight one row, one column, and the target")
	assert(game.board.guide_cells.get(Vector2i(2, 2)) == "place", "Tutorial step 2 crossing cell should be the target guide")
	assert(game.board.guide_cells.get(Vector2i(0, 2)) == "line", "Tutorial step 2 should highlight the target row")
	assert(game.board.guide_cells.get(Vector2i(2, 0)) == "line", "Tutorial step 2 should highlight the target column")

	game._on_cell_pressed(2, 2)
	assert(game.is_completed, "Tutorial step 2 should complete after placing crown")
	assert(game.cell_states[2][2] == "piece", "Tutorial step 2 target tap should place crown directly")
	assert(game.coach_label.text == "成功找到皇冠", "Tutorial step 2 should show success copy")
	await create_timer(2.1).timeout
	await process_frame
	assert(game.tutorial_hand_label.visible, "Tutorial step 3 should show hand pointer for adjacent exclusions")
	assert(game.board.guide_cells.size() == 1, "Tutorial step 3 should only highlight the currently guided adjacent cell")
	var clockwise_coordinates := [[0, 1], [0, 2], [1, 2], [2, 2], [2, 1], [2, 0], [1, 0], [0, 0]]
	for coordinate in clockwise_coordinates:
		assert(game.cell_states[int(coordinate[0])][int(coordinate[1])] == "empty", "Tutorial step 3 adjacent cells should start empty")
	assert(game.board.guide_cells.get(Vector2i(1, 0)) == "exclude_empty", "Tutorial step 3 should start guiding clockwise from the top cell")

	for coordinate in clockwise_coordinates:
		game._on_cell_pressed(int(coordinate[0]), int(coordinate[1]))
		if not game.is_completed:
			assert(game.board.guide_cells.size() == 1, "Tutorial step 3 should keep only one active guided cell")
	assert(game.is_completed, "Tutorial step 3 should complete after excluding all adjacent cells")
	assert(game.tutorial_center_popup.text == "皇冠的周围全部被排除", "Tutorial step 3 should show centered completion copy")
	assert(not game.tutorial_hand_label.visible, "Tutorial step 3 should hide hand after all adjacent cells are excluded")
	await create_timer(2.1).timeout
	await process_frame

	assert(game.undo_button.visible, "Tutorial step 4 should show undo")
	assert(game.clear_button.visible, "Tutorial step 4 should show clear")
	assert(game.hint_button.visible, "Tutorial step 4 should show hint")
	assert(game.coach_label.text == "棋盘上先放了一个 X。请点击撤销按钮，让它恢复为空白。", "Tutorial step 4 should start with undo demo copy")
	assert(game.cell_states[1][1] == "blocked", "Tutorial step 4 should start with an X for undo demo")
	assert(not game.undo_button.disabled, "Tutorial step 4 should start with undo enabled")
	assert(game.clear_button.disabled, "Tutorial step 4 should gate clear until undo")
	assert(game.hint_button.disabled, "Tutorial step 4 should gate hint until clear")
	game._undo()
	assert(game.tutorial_button_stage == 1, "Tutorial step 4 undo should advance button teaching")
	assert(game.cell_states[1][1] == "empty", "Tutorial step 4 undo should restore the X to empty")
	await create_timer(0.6).timeout
	await process_frame
	assert(game.cell_states[0][0] == "blocked", "Tutorial step 4 clear demo should prepare a blocked mark")
	assert(game.cell_states[1][2] == "piece", "Tutorial step 4 clear demo should prepare a crown mark")
	assert(game.cell_states[3][3] == "blocked", "Tutorial step 4 clear demo should prepare another blocked mark")
	assert(not game.clear_button.disabled, "Tutorial step 4 should enable clear after undo")
	game._clear_board()
	assert(game.tutorial_button_stage == 2, "Tutorial step 4 clear should advance button teaching")
	assert(game.cell_states[0][0] == "empty", "Tutorial step 4 clear should empty first demo mark")
	assert(game.cell_states[1][2] == "empty", "Tutorial step 4 clear should empty crown demo mark")
	assert(game.cell_states[3][3] == "empty", "Tutorial step 4 clear should empty final demo mark")
	assert(not game.hint_button.disabled, "Tutorial step 4 should enable hint after clear")
	game._use_hint()
	assert(not game.is_completed, "Tutorial step 4 should not complete until the hinted action is performed")
	assert(game.tutorial_button_stage == 3, "Tutorial step 4 hint should advance to guided board action")
	assert(game.board.guide_cells.get(Vector2i(0, 2)) == "place", "Tutorial step 4 hint should guide a real target")
	assert(game.coach_label.text == "提示：这个格子当前可以放皇冠。请按照提示点击高亮格子。", "Tutorial step 4 hint should explain the action")
	assert(game.tutorial_hand_label.visible, "Tutorial step 4 hint should show hand pointer on target")
	game._on_cell_pressed(2, 0)
	assert(game.is_completed, "Tutorial step 4 should complete after following the hint")
	assert(game.cell_states[2][0] == "piece", "Tutorial step 4 hinted target should become a crown")
	assert(game.coach_label.text == "已经了解全部规则，开始真正的挑战吧！", "Tutorial step 4 should show final challenge copy")
	assert(game.completion_overlay.visible, "Tutorial step 4 should show final start challenge overlay")
	assert(game.completion_next_button.text == "开始挑战", "Tutorial step 4 final button should start challenge")
	game._next_level()
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
