extends SceneTree

const SAVE_PATH := "user://color_queens_save.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous_save := ""
	var had_save := FileAccess.file_exists(SAVE_PATH)
	if had_save:
		previous_save = FileAccess.get_file_as_string(SAVE_PATH)

	var packed: PackedScene = load("res://scenes/main.tscn")
	assert(packed != null, "Main scene must load")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	assert(game.levels.size() >= 50, "MVP should include 50 default levels")
	assert(game.home_screen != null, "Home screen should exist")
	assert(game.game_screen != null, "Game screen should exist")
	game._show_game()
	await process_frame
	assert(game.board != null and game.board.size.x >= 400.0, "Board must render at a mobile-friendly size")

	for level in game.levels:
		_validate_solution(level)

	game.immediate_errors = true
	game._load_level(0)
	game._on_cell_pressed(0, 0)
	assert(game.cell_states[0][0] == "blocked", "First tap must place an exclusion mark")
	game._on_cell_pressed(0, 0)
	assert(game.cell_states[0][0] == "empty", "Second tap must clear an exclusion mark")
	game._on_cell_double_pressed(0, 0)
	assert(game.cell_states[0][0] == "piece", "Double tap must place a piece")
	game._on_cell_double_pressed(0, 1)
	assert(game.board.error_cells.size() == 2, "Two pieces in one row must conflict")
	game._undo()
	assert(game._piece_positions().size() == 1, "Undo must restore the previous board")
	game._clear_board()
	assert(game._piece_positions().is_empty(), "Clear must remove pieces")

	game.hint_count = 3
	game._update_hint_button()
	var coins_before: int = game.coin_count
	var hints_before: int = game.hint_count
	game._use_hint()
	assert(game._piece_positions().is_empty(), "Hint should teach without placing a piece")
	assert(game.board.guide_cells.size() >= 1, "Hint must highlight the best next reasoning step")
	assert(str(game.coach_label.text).length() >= 20, "Hint must explain why this step is useful now")
	assert(game.hint_count == hints_before - 1, "Hint must consume one available use")
	assert(game.coin_count == coins_before, "Free hint uses must not charge coins")

	game._load_level(0)
	for coordinate in game.current_level["solution"]:
		game._on_cell_double_pressed(int(coordinate[0]), int(coordinate[1]))
	assert(game.is_completed, "A valid solution must complete the level")

	await create_timer(0.8).timeout
	game.queue_free()
	await process_frame
	_restore_save(had_save, previous_save)
	print("SMOKE TEST PASSED: levels, conflicts, undo, clear, hint and completion")
	quit()


func _validate_solution(level: Dictionary) -> void:
	var rows := int(level["rows"])
	var cols := int(level["cols"])
	assert(rows == 6 and cols == 6, "Default levels should stay 6x6")
	assert(level["regions"].size() == rows, "Region row count must match level")
	for region_row in level["regions"]:
		assert(region_row.size() == cols, "Region column count must match level")

	var seen_rows := {}
	var seen_cols := {}
	var seen_regions := {}
	var positions: Array[Vector2i] = []
	for coordinate in level["solution"]:
		var row := int(coordinate[0])
		var col := int(coordinate[1])
		var region := int(level["regions"][row][col])
		assert(not seen_rows.has(row), "Solution row must be unique")
		assert(not seen_cols.has(col), "Solution column must be unique")
		assert(not seen_regions.has(region), "Solution region must be unique")
		seen_rows[row] = true
		seen_cols[col] = true
		seen_regions[region] = true
		positions.append(Vector2i(col, row))
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			var a := positions[i]
			var b := positions[j]
			assert(not (absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1), "Solution pieces cannot be adjacent")
	assert(_count_solutions(level, 2) == 1, "Each default level should have a unique solution")
	assert(str(level.get("difficulty", "")) != "", "Each default level should have a difficulty label")
	assert(str(level.get("logicStatus", "")) == "no_guess", "Each default level should be marked as no-guess solvable")
	assert(level.get("hintSteps", []).size() == int(level.get("targetCount", 0)), "Each default level should prepare one hint step per target")
	assert(level.get("solveSteps", []).size() >= int(level.get("targetCount", 0)), "Each default level should prepare a logical solve path")


func _count_solutions(level: Dictionary, limit: int) -> int:
	var rows := int(level["rows"])
	var cols := int(level["cols"])
	var used_cols := {}
	var used_regions := {}
	var positions: Array[Vector2i] = []
	return _search_solutions(level, rows, cols, 0, used_cols, used_regions, positions, limit)


func _search_solutions(level: Dictionary, rows: int, cols: int, row: int, used_cols: Dictionary, used_regions: Dictionary, positions: Array[Vector2i], limit: int) -> int:
	if row >= rows:
		return 1

	var count := 0
	for col in range(cols):
		if used_cols.has(col):
			continue
		var region := int(level["regions"][row][col])
		if used_regions.has(region):
			continue
		var candidate := Vector2i(col, row)
		var adjacent := false
		for position in positions:
			if absi(position.x - candidate.x) <= 1 and absi(position.y - candidate.y) <= 1:
				adjacent = true
				break
		if adjacent:
			continue

		used_cols[col] = true
		used_regions[region] = true
		positions.append(candidate)
		count += _search_solutions(level, rows, cols, row + 1, used_cols, used_regions, positions, limit - count)
		positions.pop_back()
		used_cols.erase(col)
		used_regions.erase(region)
		if count >= limit:
			return count
	return count


func _restore_save(had_save: bool, contents: String) -> void:
	if had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		file.store_string(contents)
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
