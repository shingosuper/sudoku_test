extends Control

const LevelStoreScript = preload("res://scripts/level_store.gd")
const GameBoardScript = preload("res://scripts/game_board.gd")
const SAVE_PATH := "user://color_queens_save.json"
const HINT_COST := 5
const WIN_REWARD := 10
const INK := Color("#26334A")
const MUTED := Color("#718096")
const CREAM := Color("#FFF8ED")
const CARD := Color("#FFFFFF")
const GREEN := Color("#48B985")
const REGION_COLORS = [
	Color("#FFB8C8"),
	Color("#A8D8FF"),
	Color("#BCE6A8"),
	Color("#D8C0FF"),
	Color("#FFD98E"),
	Color("#FFAAA4"),
	Color("#9FE4D8"),
	Color("#C8D5F2"),
	Color("#F3B9E5")
]

var levels: Array = []
var current_level_index := 0
var current_level: Dictionary = {}
var cell_states: Array = []
var move_history: Array = []
var completed_levels: Array = []
var coin_count := 55
var hint_count := 0
var immediate_errors := true
var is_completed := false
var resume_level_id := -1
var resume_states: Array = []
var resume_completed := false

var board
var level_label: Label
var level_name_label: Label
var coin_label: Label
var progress_bar: ProgressBar
var progress_label: Label
var coach_label: Label
var undo_button: Button
var clear_button: Button
var hint_button: Button
var completion_overlay: ColorRect
var completion_title: Label
var reward_label: Label
var toast_label: Label
var help_dialog: AcceptDialog
var toast_tween: Tween


func _ready() -> void:
	levels = LevelStoreScript.load_levels()
	if levels.is_empty():
		_show_fatal_error("没有找到可用关卡")
		return
	_load_save()
	_build_ui()
	current_level_index = clampi(current_level_index, 0, levels.size() - 1)
	_load_level(current_level_index, true)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = CREAM
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var safe_margin := MarginContainer.new()
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_margin.add_theme_constant_override("margin_left", 22)
	safe_margin.add_theme_constant_override("margin_right", 22)
	safe_margin.add_theme_constant_override("margin_top", 20)
	safe_margin.add_theme_constant_override("margin_bottom", 16)
	add_child(safe_margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	safe_margin.add_child(content)

	content.add_child(_build_top_bar())
	content.add_child(_build_level_header())
	content.add_child(_build_progress_row())
	content.add_child(_build_coach())

	board = GameBoardScript.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.cell_pressed.connect(_on_cell_pressed)
	content.add_child(board)

	content.add_child(_build_action_bar())
	content.add_child(_build_ad_placeholder())

	_build_completion_overlay()
	_build_toast()
	_build_help_dialog()


func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 66
	panel.add_theme_stylebox_override("panel", _card_style(CARD, 22, true))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	margin.add_child(row)

	coin_label = Label.new()
	coin_label.text = "●  %d" % coin_count
	coin_label.add_theme_color_override("font_color", Color("#E6A63A"))
	coin_label.add_theme_font_size_override("font_size", 20)
	coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(coin_label)

	var plus_button := _small_button("+")
	plus_button.tooltip_text = "模拟激励广告奖励"
	plus_button.add_theme_stylebox_override("normal", _button_style(GREEN, 13))
	plus_button.add_theme_stylebox_override("hover", _button_style(GREEN.lightened(0.08), 13))
	plus_button.pressed.connect(_on_coin_plus)
	row.add_child(plus_button)

	var heart := Label.new()
	heart.text = "♥  3"
	heart.add_theme_color_override("font_color", Color("#F06B78"))
	heart.add_theme_font_size_override("font_size", 19)
	heart.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(heart)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var rank := _small_button("榜")
	rank.tooltip_text = "排行榜（预留）"
	rank.pressed.connect(func() -> void: _show_toast("排行榜将在后续版本开放"))
	row.add_child(rank)

	var theme_button := _small_button("♛")
	theme_button.tooltip_text = "主题皮肤"
	theme_button.pressed.connect(func() -> void: _show_toast("已使用默认皇冠主题"))
	row.add_child(theme_button)

	var settings := _small_button("⚙")
	settings.tooltip_text = "切换即时纠错"
	settings.pressed.connect(_on_settings)
	row.add_child(settings)
	return panel


func _build_level_header() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 46

	level_label = Label.new()
	level_label.add_theme_color_override("font_color", INK)
	level_label.add_theme_font_size_override("font_size", 27)
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(level_label)

	level_name_label = Label.new()
	level_name_label.add_theme_color_override("font_color", MUTED)
	level_name_label.add_theme_font_size_override("font_size", 16)
	level_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(level_name_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var help := _small_button("?")
	help.tooltip_text = "玩法说明"
	help.pressed.connect(_on_help)
	row.add_child(help)
	return row


func _build_progress_row() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 46
	row.add_theme_constant_override("separation", 10)

	var piece := Label.new()
	piece.text = "♛"
	piece.add_theme_color_override("font_color", Color("#E4A236"))
	piece.add_theme_font_size_override("font_size", 30)
	piece.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(piece)

	progress_bar = ProgressBar.new()
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.custom_minimum_size.y = 24
	progress_bar.show_percentage = false
	progress_bar.add_theme_stylebox_override("background", _button_style(Color("#E8E3DB"), 12))
	progress_bar.add_theme_stylebox_override("fill", _button_style(Color("#FFB84E"), 12))
	row.add_child(progress_bar)

	progress_label = Label.new()
	progress_label.custom_minimum_size.x = 52
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress_label.add_theme_color_override("font_color", INK)
	progress_label.add_theme_font_size_override("font_size", 18)
	row.add_child(progress_label)
	return row


func _build_coach() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 52
	panel.add_theme_stylebox_override("panel", _button_style(Color("#FFF0C9"), 16))

	coach_label = Label.new()
	coach_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coach_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coach_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coach_label.add_theme_color_override("font_color", Color("#72552B"))
	coach_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(coach_label)
	return panel


func _build_action_bar() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 74
	row.add_theme_constant_override("separation", 10)

	undo_button = _action_button("↶  撤销")
	undo_button.pressed.connect(_undo)
	row.add_child(undo_button)

	clear_button = _action_button("×  清除")
	clear_button.pressed.connect(_clear_board)
	row.add_child(clear_button)

	hint_button = _action_button("✦  提示  -%d" % HINT_COST, Color("#EAF8F0"))
	hint_button.add_theme_color_override("font_color", Color("#23845C"))
	hint_button.pressed.connect(_use_hint)
	row.add_child(hint_button)
	return row


func _build_ad_placeholder() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 38
	panel.add_theme_stylebox_override("panel", _button_style(Color("#EEEAE3"), 12))
	var label := Label.new()
	label.text = "广告位 · Demo Placeholder"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("#AAA39A"))
	label.add_theme_font_size_override("font_size", 12)
	panel.add_child(label)
	return panel


func _build_completion_overlay() -> void:
	completion_overlay = ColorRect.new()
	completion_overlay.color = Color(0.08, 0.11, 0.16, 0.62)
	completion_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	completion_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	completion_overlay.z_index = 10
	completion_overlay.hide()
	add_child(completion_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	completion_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(410, 330)
	panel.add_theme_stylebox_override("panel", _card_style(CARD, 28, true, 28))
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var crown := Label.new()
	crown.text = "♛"
	crown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crown.add_theme_color_override("font_color", Color("#FFB84E"))
	crown.add_theme_font_size_override("font_size", 68)
	column.add_child(crown)

	completion_title = Label.new()
	completion_title.text = "关卡完成！"
	completion_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_title.add_theme_color_override("font_color", INK)
	completion_title.add_theme_font_size_override("font_size", 31)
	column.add_child(completion_title)

	reward_label = Label.new()
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.add_theme_color_override("font_color", Color("#D89427"))
	reward_label.add_theme_font_size_override("font_size", 19)
	column.add_child(reward_label)

	var next_button := _action_button("下一关  →", Color("#FFB84E"))
	next_button.add_theme_color_override("font_color", INK)
	next_button.pressed.connect(_next_level)
	column.add_child(next_button)

	var replay_button := Button.new()
	replay_button.text = "重玩本关"
	replay_button.flat = true
	replay_button.add_theme_color_override("font_color", MUTED)
	replay_button.add_theme_font_size_override("font_size", 16)
	replay_button.pressed.connect(_replay_level)
	column.add_child(replay_button)


func _build_toast() -> void:
	toast_label = Label.new()
	toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.position = Vector2(-190, -112)
	toast_label.size = Vector2(380, 48)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_color", Color.WHITE)
	toast_label.add_theme_font_size_override("font_size", 15)
	toast_label.add_theme_stylebox_override("normal", _button_style(Color("#2F3B50"), 18))
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.z_index = 20
	toast_label.modulate.a = 0.0
	add_child(toast_label)


func _build_help_dialog() -> void:
	help_dialog = AcceptDialog.new()
	help_dialog.title = "怎么玩"
	help_dialog.dialog_text = "在每个颜色区域放置一个皇冠，并同时满足：\n\n• 每一行只有一个皇冠\n• 每一列只有一个皇冠\n• 每个颜色区域只有一个皇冠\n• 皇冠不能八方向相邻\n\n点按格子会在皇冠、排除标记、空白间循环。"
	help_dialog.ok_button_text = "知道了"
	help_dialog.unresizable = true
	add_child(help_dialog)


func _load_level(index: int, allow_resume: bool = false) -> void:
	current_level_index = index
	current_level = levels[index]
	is_completed = false
	move_history.clear()
	completion_overlay.hide()

	var rows := int(current_level["rows"])
	var cols := int(current_level["cols"])
	if allow_resume and resume_level_id == int(current_level["levelId"]) and _states_match_size(resume_states, rows, cols):
		cell_states = resume_states.duplicate(true)
		is_completed = resume_completed
	else:
		cell_states = _blank_states(rows, cols)

	level_label.text = "关卡 %d" % int(current_level["levelId"])
	level_name_label.text = "  ·  %s" % str(current_level.get("name", ""))
	coach_label.text = str(current_level.get("tutorial", "放置全部皇冠，满足四条规则。"))
	coach_label.add_theme_color_override("font_color", Color("#72552B"))
	progress_bar.max_value = int(current_level["targetCount"])
	board.set_level(current_level, cell_states, REGION_COLORS)
	_validate_and_update(false)
	if is_completed:
		reward_label.text = "本关已完成 · 继续挑战下一关"
		completion_overlay.show()
	_save_game()


func _on_cell_pressed(row: int, col: int) -> void:
	if is_completed:
		return
	_push_history()
	var state: String = cell_states[row][col]
	match state:
		"empty":
			cell_states[row][col] = "piece"
		"piece", "hint":
			cell_states[row][col] = "blocked"
		"blocked":
			cell_states[row][col] = "empty"
		_:
			cell_states[row][col] = "empty"
	board.set_states(cell_states)
	board.play_cell_feedback(row, col)
	_validate_and_update(true)
	_save_game()


func _undo() -> void:
	if move_history.is_empty() or is_completed:
		return
	cell_states = move_history.pop_back()
	board.set_states(cell_states)
	_validate_and_update(false)
	_save_game()


func _clear_board() -> void:
	if is_completed or _piece_positions().is_empty() and not _has_blocked_cells():
		return
	_push_history()
	cell_states = _blank_states(int(current_level["rows"]), int(current_level["cols"]))
	board.set_states(cell_states)
	_validate_and_update(false)
	_save_game()
	_show_toast("棋盘已清空，可撤销恢复")


func _use_hint() -> void:
	if is_completed:
		return
	if coin_count < HINT_COST:
		_show_toast("金币不足，点顶部 + 可领取演示奖励")
		return

	var target := Vector2i(-1, -1)
	for coordinate in current_level["solution"]:
		var row := int(coordinate[0])
		var col := int(coordinate[1])
		if cell_states[row][col] != "piece" and cell_states[row][col] != "hint":
			target = Vector2i(col, row)
			break
	if target.x < 0:
		_show_toast("所有正确位置都已找到")
		return

	_push_history()
	coin_count -= HINT_COST
	hint_count += 1
	cell_states[target.y][target.x] = "hint"
	board.set_states(cell_states)
	board.play_cell_feedback(target.y, target.x)
	_update_coin_label()
	_validate_and_update(true)
	_save_game()
	_show_toast("提示：已点亮一个正确位置")


func _validate_and_update(allow_completion: bool) -> void:
	var pieces := _piece_positions()
	var conflicts := _find_conflicts(pieces)
	board.set_errors(conflicts if immediate_errors else {})

	progress_bar.value = pieces.size()
	progress_label.text = "%d / %d" % [pieces.size(), int(current_level["targetCount"])]
	undo_button.disabled = move_history.is_empty()
	clear_button.disabled = pieces.is_empty() and not _has_blocked_cells()

	if not conflicts.is_empty() and immediate_errors:
		coach_label.text = "有冲突：红色格子违反了行、列、区域或相邻规则。"
		coach_label.add_theme_color_override("font_color", Color("#B93D4D"))
		if allow_completion:
			Input.vibrate_handheld(35)
	else:
		coach_label.text = str(current_level.get("tutorial", "放置全部皇冠，满足四条规则。"))
		coach_label.add_theme_color_override("font_color", Color("#72552B"))

	if allow_completion and pieces.size() == int(current_level["targetCount"]) and conflicts.is_empty():
		_complete_level()


func _find_conflicts(pieces: Array) -> Dictionary:
	var result := {}
	for i in range(pieces.size()):
		for j in range(i + 1, pieces.size()):
			var a: Vector2i = pieces[i]
			var b: Vector2i = pieces[j]
			var same_row := a.y == b.y
			var same_col := a.x == b.x
			var same_region := int(current_level["regions"][a.y][a.x]) == int(current_level["regions"][b.y][b.x])
			var adjacent := absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1
			if same_row or same_col or same_region or adjacent:
				result[a] = true
				result[b] = true
	return result


func _piece_positions() -> Array:
	var result: Array = []
	for row in range(cell_states.size()):
		for col in range(cell_states[row].size()):
			if cell_states[row][col] == "piece" or cell_states[row][col] == "hint":
				result.append(Vector2i(col, row))
	return result


func _has_blocked_cells() -> bool:
	for row in cell_states:
		if row.has("blocked"):
			return true
	return false


func _complete_level() -> void:
	if is_completed:
		return
	is_completed = true
	var level_id := int(current_level["levelId"])
	var reward := 0
	if not completed_levels.has(level_id):
		completed_levels.append(level_id)
		reward = WIN_REWARD
		coin_count += reward
	_update_coin_label()
	board.play_victory()
	_save_game()
	await get_tree().create_timer(0.55).timeout
	reward_label.text = "●  获得金币 +%d" % reward if reward > 0 else "本关已完成 · 再接再厉"
	completion_title.text = "关卡完成！"
	completion_overlay.show()
	completion_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(completion_overlay, "modulate:a", 1.0, 0.2)


func _next_level() -> void:
	var next_index := current_level_index + 1
	if next_index >= levels.size():
		next_index = 0
	_load_level(next_index)
	if next_index == 0:
		_show_toast("全部体验关卡完成，已回到第一关")


func _replay_level() -> void:
	_load_level(current_level_index)


func _on_coin_plus() -> void:
	coin_count += 10
	_update_coin_label()
	_save_game()
	_show_toast("演示奖励：金币 +10")


func _on_settings() -> void:
	immediate_errors = not immediate_errors
	_validate_and_update(false)
	_show_toast("即时纠错：%s" % ("开启" if immediate_errors else "关闭"))


func _on_help() -> void:
	help_dialog.popup_centered(Vector2i(450, 360))


func _push_history() -> void:
	move_history.append(cell_states.duplicate(true))
	if move_history.size() > 100:
		move_history.pop_front()


func _blank_states(rows: int, cols: int) -> Array:
	var states: Array = []
	for row in range(rows):
		var line: Array = []
		line.resize(cols)
		line.fill("empty")
		states.append(line)
	return states


func _states_match_size(states: Array, rows: int, cols: int) -> bool:
	if states.size() != rows:
		return false
	for row in states:
		if not row is Array or row.size() != cols:
			return false
	return true


func _load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return
	current_level_index = int(data.get("currentLevelIndex", 0))
	coin_count = int(data.get("coinCount", 55))
	hint_count = int(data.get("hintCount", 0))
	completed_levels.assign(data.get("completedLevels", []))
	for index in range(completed_levels.size()):
		completed_levels[index] = int(completed_levels[index])
	resume_level_id = int(data.get("currentLevelId", -1))
	resume_states = data.get("cellStates", [])
	resume_completed = bool(data.get("isCompleted", false))
	immediate_errors = bool(data.get("immediateErrors", true))


func _save_game() -> void:
	if current_level.is_empty():
		return
	var data := {
		"currentLevelIndex": current_level_index,
		"currentLevelId": int(current_level["levelId"]),
		"coinCount": coin_count,
		"completedLevels": completed_levels,
		"selectedTheme": "crown",
		"hintCount": hint_count,
		"immediateErrors": immediate_errors,
		"isCompleted": is_completed,
		"cellStates": cell_states
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func _update_coin_label() -> void:
	if coin_label:
		coin_label.text = "●  %d" % coin_count


func _show_toast(message: String) -> void:
	toast_label.text = message
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.14)
	toast_tween.tween_interval(1.55)
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.24)


func _show_fatal_error(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)


func _small_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(40, 40)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_stylebox_override("normal", _button_style(Color("#F1F4F7"), 13))
	button.add_theme_stylebox_override("hover", _button_style(Color("#E7EDF2"), 13))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#DDE5EC"), 13))
	return button


func _action_button(text: String, color: Color = CARD) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_disabled_color", Color("#B9BEC6"))
	button.add_theme_stylebox_override("normal", _card_style(color, 20, true))
	button.add_theme_stylebox_override("hover", _card_style(color.lightened(0.04), 20, true))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.05), 20))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#EEECE8"), 20))
	return button


func _button_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _card_style(color: Color, radius: int, shadow: bool = false, padding: int = 0) -> StyleBoxFlat:
	var style := _button_style(color, radius)
	if shadow:
		style.shadow_color = Color(0.20, 0.23, 0.30, 0.12)
		style.shadow_size = 7
		style.shadow_offset = Vector2(0, 3)
	if padding > 0:
		style.content_margin_left = padding
		style.content_margin_right = padding
		style.content_margin_top = padding
		style.content_margin_bottom = padding
	return style


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_Z:
				_undo()
			KEY_R:
				_clear_board()
			KEY_H:
				_use_hint()
