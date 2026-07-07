extends Control

const LevelStoreScript = preload("res://scripts/level_store.gd")
const LEVELS_PATH := "res://data/levels.json"
const INK := Color("#26334A")
const MUTED := Color("#718096")
const CREAM := Color("#FFF8ED")
const CARD := Color("#FFFFFF")
const REGION_COLORS = [
	Color("#FFE88A"),
	Color("#70B7FF"),
	Color("#82D989"),
	Color("#B59AF1"),
	Color("#FF8C8C"),
	Color("#64D8C4"),
	Color("#F6A6D7"),
	Color("#A8B8D8"),
	Color("#FFB56B")
]

var levels: Array = []
var current_index := 0
var current_level: Dictionary = {}
var selected_region := 1
var paint_solution := false

var level_picker: OptionButton
var name_edit: LineEdit
var tutorial_edit: TextEdit
var region_picker: OptionButton
var solution_mode_button: Button
var board: GridContainer
var status_label: Label


func _ready() -> void:
	levels = LevelStoreScript.load_levels()
	if levels.is_empty():
		_show_fatal_error("没有找到可编辑关卡")
		return
	_build_ui()
	_load_level(0)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = CREAM
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var safe_margin := MarginContainer.new()
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_margin.add_theme_constant_override("margin_left", 18)
	safe_margin.add_theme_constant_override("margin_right", 18)
	safe_margin.add_theme_constant_override("margin_top", 18)
	safe_margin.add_theme_constant_override("margin_bottom", 18)
	add_child(safe_margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	safe_margin.add_child(content)

	content.add_child(_build_top_bar())
	content.add_child(_build_text_fields())
	content.add_child(_build_tool_bar())

	var board_panel := PanelContainer.new()
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.add_theme_stylebox_override("panel", _card_style(CARD, 18, true, 12))
	content.add_child(board_panel)

	board = GridContainer.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.add_theme_constant_override("h_separation", 5)
	board.add_theme_constant_override("v_separation", 5)
	board_panel.add_child(board)

	status_label = Label.new()
	status_label.add_theme_color_override("font_color", MUTED)
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)


func _build_top_bar() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 48
	row.add_theme_constant_override("separation", 8)

	var back := _small_button("返回")
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	row.add_child(back)

	level_picker = OptionButton.new()
	level_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_picker.custom_minimum_size.y = 42
	level_picker.focus_mode = Control.FOCUS_NONE
	level_picker.add_theme_font_size_override("font_size", 16)
	level_picker.add_theme_color_override("font_color", INK)
	level_picker.add_theme_stylebox_override("normal", _button_style(Color("#F1F4F7"), 12))
	for index in range(levels.size()):
		var level: Dictionary = levels[index]
		level_picker.add_item("关卡 %d · %s" % [int(level["levelId"]), str(level.get("name", ""))], index)
	level_picker.item_selected.connect(_on_level_selected)
	row.add_child(level_picker)

	var save := _small_button("保存")
	save.add_theme_stylebox_override("normal", _button_style(Color("#48B985"), 12))
	save.add_theme_stylebox_override("hover", _button_style(Color("#5BC995"), 12))
	save.pressed.connect(_save_levels)
	row.add_child(save)
	return row


func _build_text_fields() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style(CARD, 16, true, 12))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "关卡名称"
	name_edit.text_changed.connect(func(value: String) -> void:
		current_level["name"] = value
		_refresh_level_picker()
	)
	column.add_child(name_edit)

	tutorial_edit = TextEdit.new()
	tutorial_edit.custom_minimum_size.y = 78
	tutorial_edit.placeholder_text = "关卡提示文字"
	tutorial_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	tutorial_edit.text_changed.connect(func() -> void:
		current_level["tutorial"] = tutorial_edit.text
	)
	column.add_child(tutorial_edit)
	return panel


func _build_tool_bar() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 48
	row.add_theme_constant_override("separation", 8)

	region_picker = OptionButton.new()
	region_picker.custom_minimum_size = Vector2(132, 42)
	region_picker.focus_mode = Control.FOCUS_NONE
	region_picker.add_theme_font_size_override("font_size", 15)
	for region in range(1, 10):
		region_picker.add_item("区域 %d" % region, region)
	region_picker.item_selected.connect(func(index: int) -> void:
		selected_region = region_picker.get_item_id(index)
	)
	row.add_child(region_picker)

	solution_mode_button = _small_button("区域模式")
	solution_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	solution_mode_button.pressed.connect(_toggle_solution_mode)
	row.add_child(solution_mode_button)

	var validate := _small_button("检查答案")
	validate.pressed.connect(_validate_current_level)
	row.add_child(validate)
	return row


func _load_level(index: int) -> void:
	_apply_text_edits()
	current_index = index
	current_level = levels[current_index]
	selected_region = 1
	paint_solution = false
	level_picker.select(current_index)
	name_edit.text = str(current_level.get("name", ""))
	tutorial_edit.text = str(current_level.get("tutorial", ""))
	region_picker.select(0)
	_update_solution_button()
	_rebuild_board()
	_validate_current_level()


func _rebuild_board() -> void:
	for child in board.get_children():
		child.queue_free()

	var rows := int(current_level["rows"])
	var cols := int(current_level["cols"])
	board.columns = cols

	for row in range(rows):
		for col in range(cols):
			var button := Button.new()
			button.custom_minimum_size = Vector2(56, 56)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.size_flags_vertical = Control.SIZE_EXPAND_FILL
			button.focus_mode = Control.FOCUS_NONE
			button.add_theme_font_size_override("font_size", 22)
			button.pressed.connect(_on_cell_pressed.bind(row, col))
			board.add_child(button)
	_refresh_cells()


func _refresh_cells() -> void:
	var solution := _solution_set()
	for row in range(int(current_level["rows"])):
		for col in range(int(current_level["cols"])):
			var index := row * int(current_level["cols"]) + col
			var button := board.get_child(index) as Button
			var region_id := int(current_level["regions"][row][col])
			var color: Color = REGION_COLORS[(region_id - 1) % REGION_COLORS.size()]
			var is_solution := solution.has(Vector2i(col, row))
			button.text = "♛" if is_solution else str(region_id)
			button.add_theme_color_override("font_color", INK)
			button.add_theme_stylebox_override("normal", _button_style(color, 10))
			button.add_theme_stylebox_override("hover", _button_style(color.lightened(0.08), 10))
			button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.06), 10))


func _on_cell_pressed(row: int, col: int) -> void:
	if paint_solution:
		_toggle_solution_cell(row, col)
	else:
		current_level["regions"][row][col] = selected_region
	_refresh_cells()
	_validate_current_level()


func _toggle_solution_cell(row: int, col: int) -> void:
	var solution: Array = current_level["solution"]
	for index in range(solution.size()):
		var coordinate = solution[index]
		if int(coordinate[0]) == row and int(coordinate[1]) == col:
			solution.remove_at(index)
			return
	solution.append([row, col])


func _toggle_solution_mode() -> void:
	paint_solution = not paint_solution
	_update_solution_button()


func _update_solution_button() -> void:
	if paint_solution:
		solution_mode_button.text = "答案模式：点皇冠"
		solution_mode_button.add_theme_stylebox_override("normal", _button_style(Color("#FFB84E"), 12))
	else:
		solution_mode_button.text = "区域模式：涂颜色"
		solution_mode_button.add_theme_stylebox_override("normal", _button_style(Color("#F1F4F7"), 12))


func _validate_current_level() -> void:
	var rows := int(current_level["rows"])
	var cols := int(current_level["cols"])
	var target := int(current_level["targetCount"])
	var solution: Array = current_level["solution"]
	var issues: Array[String] = []
	if solution.size() != target:
		issues.append("答案皇冠数量应为 %d 个，现在是 %d 个" % [target, solution.size()])

	var seen_rows := {}
	var seen_cols := {}
	var seen_regions := {}
	var positions: Array[Vector2i] = []
	for coordinate in solution:
		var row := int(coordinate[0])
		var col := int(coordinate[1])
		if row < 0 or row >= rows or col < 0 or col >= cols:
			issues.append("答案坐标超出棋盘")
			continue
		var region := int(current_level["regions"][row][col])
		if seen_rows.has(row):
			issues.append("同一行里有多个皇冠")
		if seen_cols.has(col):
			issues.append("同一列里有多个皇冠")
		if seen_regions.has(region):
			issues.append("同一区域里有多个皇冠")
		seen_rows[row] = true
		seen_cols[col] = true
		seen_regions[region] = true
		positions.append(Vector2i(col, row))

	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			var a := positions[i]
			var b := positions[j]
			if absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1:
				issues.append("皇冠不能相邻，包括斜向相邻")

	if issues.is_empty():
		status_label.text = "当前关卡检查通过，可以保存。"
		status_label.add_theme_color_override("font_color", Color("#23845C"))
	else:
		status_label.text = "需要调整：" + "；".join(issues)
		status_label.add_theme_color_override("font_color", Color("#B93D4D"))


func _save_levels() -> void:
	_apply_text_edits()
	var data := {"levels": levels}
	var file := FileAccess.open(LEVELS_PATH, FileAccess.WRITE)
	if not file:
		status_label.text = "保存失败：无法写入 data/levels.json"
		status_label.add_theme_color_override("font_color", Color("#B93D4D"))
		return
	file.store_string(JSON.stringify(data, "\t"))
	status_label.text = "已保存到 data/levels.json。返回游戏后会读取新关卡。"
	status_label.add_theme_color_override("font_color", Color("#23845C"))


func _on_level_selected(index: int) -> void:
	_load_level(index)


func _apply_text_edits() -> void:
	if current_level.is_empty():
		return
	current_level["name"] = name_edit.text
	current_level["tutorial"] = tutorial_edit.text


func _refresh_level_picker() -> void:
	if not level_picker:
		return
	level_picker.set_item_text(current_index, "关卡 %d · %s" % [int(current_level["levelId"]), str(current_level.get("name", ""))])


func _solution_set() -> Dictionary:
	var result := {}
	for coordinate in current_level["solution"]:
		result[Vector2i(int(coordinate[1]), int(coordinate[0]))] = true
	return result


func _small_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(72, 42)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_stylebox_override("normal", _button_style(Color("#F1F4F7"), 12))
	button.add_theme_stylebox_override("hover", _button_style(Color("#E7EDF2"), 12))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#DDE5EC"), 12))
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


func _show_fatal_error(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
