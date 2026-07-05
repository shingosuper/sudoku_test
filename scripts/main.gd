extends Control

const LevelStoreScript = preload("res://scripts/level_store.gd")
const GameBoardScript = preload("res://scripts/game_board.gd")
const SAVE_PATH := "user://color_queens_save.json"
const SAVE_VERSION := 3
const HINT_COST := 5
const INITIAL_HINT_COUNT := 3
const WIN_REWARD := 10
const INK := Color("#26334A")
const MUTED := Color("#718096")
const CREAM := Color("#FFF8ED")
const CARD := Color("#FFFFFF")
const GREEN := Color("#48B985")
const REGION_COLOR_NAMES = ["黄色", "蓝色", "绿色", "紫色", "红色", "青色", "粉色", "灰蓝色", "橙色"]
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

const TUTORIAL_LEVELS = [
	{
		"levelId": -101,
		"title": "新手教程 1/4",
		"name": "",
		"rows": 4,
		"cols": 4,
		"targetCount": 3,
		"tutorial": "按提示点同一个格子：先标记 X，再放皇冠，最后取消。",
		"regions": [
			[1, 1, 2, 2],
			[1, 1, 2, 2],
			[3, 3, 4, 4],
			[3, 3, 4, 4]
		],
		"target": [1, 1]
	},
	{
		"levelId": -102,
		"title": "新手教程 2/4",
		"name": "",
		"rows": 4,
		"cols": 4,
		"targetCount": 1,
		"tutorial": "每行、每列、每个颜色区域都只能有一个皇冠。",
		"regions": [
			[1, 1, 2, 2],
			[1, 1, 2, 2],
			[3, 3, 4, 4],
			[3, 3, 4, 4]
		],
		"target": [0, 0]
	},
	{
		"levelId": -103,
		"title": "新手教程 3/4",
		"name": "",
		"rows": 4,
		"cols": 4,
		"targetCount": 1,
		"tutorial": "皇冠周围 8 个相邻格都不能再放皇冠。",
		"regions": [
			[1, 1, 2, 2],
			[1, 1, 2, 2],
			[3, 3, 4, 4],
			[3, 3, 4, 4]
		],
		"prefill": [[1, 1]],
		"target": [0, 0]
	},
	{
		"levelId": -104,
		"title": "新手教程 4/4",
		"name": "",
		"rows": 4,
		"cols": 4,
		"targetCount": 1,
		"tutorial": "遇到卡点时使用提示。提示会解释观察范围，不会替你落子。",
		"regions": [
			[1, 1, 2, 2],
			[1, 1, 2, 2],
			[3, 3, 4, 4],
			[3, 3, 4, 4]
		],
		"target": [2, 0]
	}
]

var levels: Array = []
var current_level_index := 0
var current_level: Dictionary = {}
var cell_states: Array = []
var move_history: Array = []
var completed_levels: Array = []
var coin_count := 55
var hint_count := INITIAL_HINT_COUNT
var immediate_errors := true
var is_completed := false
var active_hint_step: Dictionary = {}
var active_hint_stage := 0
var resume_level_id := -1
var resume_states: Array = []
var resume_completed := false
var tutorial_completed := false
var tutorial_started := false
var tutorial_step_index := 0
var tutorial_interaction_stage := 0
var tutorial_button_stage := 0
var in_tutorial := false

var home_screen: Control
var game_screen: Control
var home_coin_label: Label
var home_heart_label: Label
var home_star_label: Label
var home_level_label: Label
var home_area_label: Label
var home_progress_bar: ProgressBar
var home_progress_label: Label
var home_start_button: Button
var home_chest_label: Label
var board
var level_picker: OptionButton
var level_label: Label
var help_button: Button
var coin_label: Label
var progress_bar: ProgressBar
var progress_label: Label
var coach_label: Label
var undo_button: Button
var clear_button: Button
var hint_button: Button
var tutorial_skip_button: Button
var completion_overlay: ColorRect
var completion_title: Label
var reward_label: Label
var completion_next_button: Button
var completion_replay_button: Button
var toast_label: Label
var help_dialog: AcceptDialog
var tutorial_skip_dialog: ConfirmationDialog
var tutorial_resume_dialog: ConfirmationDialog
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
	if tutorial_completed:
		_show_home()
	elif tutorial_started:
		_show_home()
		tutorial_resume_dialog.popup_centered(Vector2i(420, 220))
	else:
		_start_tutorial_step(0)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = CREAM
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	home_screen = _build_home_screen()
	add_child(home_screen)

	game_screen = _build_game_screen()
	add_child(game_screen)

	_build_completion_overlay()
	_build_toast()
	_build_tutorial_dialogs()


func _build_home_screen() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var sky := ColorRect.new()
	sky.color = Color("#75D8FF")
	sky.set_anchor(SIDE_RIGHT, 1.0)
	sky.set_anchor(SIDE_BOTTOM, 0.48)
	root.add_child(sky)

	var garden := ColorRect.new()
	garden.color = Color("#75CF57")
	garden.set_anchor(SIDE_TOP, 0.48)
	garden.set_anchor(SIDE_RIGHT, 1.0)
	garden.set_anchor(SIDE_BOTTOM, 1.0)
	root.add_child(garden)

	var lake := ColorRect.new()
	lake.color = Color("#45BEE8")
	lake.set_anchor(SIDE_LEFT, 0.0)
	lake.set_anchor(SIDE_TOP, 0.38)
	lake.set_anchor(SIDE_RIGHT, 1.0)
	lake.set_anchor(SIDE_BOTTOM, 0.50)
	root.add_child(lake)

	var path := ColorRect.new()
	path.color = Color("#D9B061")
	path.set_anchor(SIDE_LEFT, 0.43)
	path.set_anchor(SIDE_TOP, 0.45)
	path.set_anchor(SIDE_RIGHT, 0.57)
	path.set_anchor(SIDE_BOTTOM, 0.77)
	root.add_child(path)

	root.add_child(_build_home_castle())
	root.add_child(_build_home_primary_buttons())
	return root


func _build_home_top_resources() -> Control:
	var bar := HBoxContainer.new()
	bar.set_anchor(SIDE_LEFT, 0.0)
	bar.set_anchor(SIDE_RIGHT, 1.0)
	bar.offset_left = 18
	bar.offset_top = 18
	bar.offset_right = -18
	bar.offset_bottom = 62
	bar.add_theme_constant_override("separation", 8)

	home_coin_label = _resource_label("●  %d" % coin_count, Color("#E6A63A"))
	bar.add_child(home_coin_label)

	home_heart_label = _resource_label("♥  3", Color("#F06B78"))
	bar.add_child(home_heart_label)

	home_star_label = _resource_label("★  %d" % completed_levels.size(), Color("#5D74D9"))
	bar.add_child(home_star_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	var settings := _small_button("⚙")
	settings.tooltip_text = "设置"
	settings.pressed.connect(_on_settings)
	bar.add_child(settings)
	return bar


func _build_home_castle() -> Control:
	var castle := VBoxContainer.new()
	castle.set_anchor(SIDE_LEFT, 0.08)
	castle.set_anchor(SIDE_TOP, 0.09)
	castle.set_anchor(SIDE_RIGHT, 0.92)
	castle.set_anchor(SIDE_BOTTOM, 0.47)
	castle.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "Color Queens"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#FFFFFF"))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.28))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.add_theme_font_size_override("font_size", 34)
	castle.add_child(title)

	var castle_body := Label.new()
	castle_body.text = "♛\n▟▙  ▟▙\n▛▜▛▜"
	castle_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	castle_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	castle_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	castle_body.add_theme_color_override("font_color", Color("#5A6FA7"))
	castle_body.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 0.65))
	castle_body.add_theme_constant_override("shadow_offset_x", 0)
	castle_body.add_theme_constant_override("shadow_offset_y", 4)
	castle_body.add_theme_font_size_override("font_size", 58)
	castle.add_child(castle_body)

	home_area_label = Label.new()
	home_area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_area_label.add_theme_color_override("font_color", Color("#254165"))
	home_area_label.add_theme_font_size_override("font_size", 17)
	castle.add_child(home_area_label)
	return castle


func _build_home_side_buttons() -> Control:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var daily := _floating_home_button("礼")
	daily.position = Vector2(18, 114)
	daily.tooltip_text = "每日奖励"
	daily.pressed.connect(func() -> void:
		coin_count += 10
		_update_coin_label()
		_update_home()
		_save_game()
		_show_toast("每日奖励：金币 +10")
	)
	layer.add_child(daily)

	var chest := _floating_home_button("箱")
	chest.position = Vector2(18, 176)
	chest.tooltip_text = "宝箱"
	chest.pressed.connect(func() -> void: _show_toast("继续通关，皇冠宝箱即将开启"))
	layer.add_child(chest)

	var editor := _floating_home_button("编")
	editor.position = Vector2(18, 238)
	editor.tooltip_text = "关卡编辑器"
	editor.pressed.connect(_open_level_editor)
	layer.add_child(editor)

	var event := _floating_home_button("!")
	event.set_anchor(SIDE_LEFT, 1.0)
	event.set_anchor(SIDE_RIGHT, 1.0)
	event.offset_left = -70
	event.offset_top = 136
	event.offset_right = -18
	event.offset_bottom = 188
	event.tooltip_text = "活动"
	event.pressed.connect(func() -> void: _show_toast("活动将在后续版本开放"))
	layer.add_child(event)

	var rank := _floating_home_button("榜")
	rank.set_anchor(SIDE_LEFT, 1.0)
	rank.set_anchor(SIDE_RIGHT, 1.0)
	rank.offset_left = -70
	rank.offset_top = 198
	rank.offset_right = -18
	rank.offset_bottom = 250
	rank.tooltip_text = "排行榜"
	rank.pressed.connect(func() -> void: _show_toast("排行榜将在后续版本开放"))
	layer.add_child(rank)
	return layer


func _build_home_primary_buttons() -> Control:
	var column := VBoxContainer.new()
	column.set_anchor(SIDE_LEFT, 0.0)
	column.set_anchor(SIDE_TOP, 0.68)
	column.set_anchor(SIDE_RIGHT, 1.0)
	column.set_anchor(SIDE_BOTTOM, 0.84)
	column.offset_left = 36
	column.offset_right = -36
	column.add_theme_constant_override("separation", 12)

	home_start_button = _royal_home_button("开始关卡", Color("#28A83C"))
	home_start_button.custom_minimum_size.y = 64
	home_start_button.pressed.connect(_start_current_flow)
	column.add_child(home_start_button)

	var newbie := _royal_home_button("新人流程", Color("#F2A51E"))
	newbie.custom_minimum_size.y = 56
	newbie.pressed.connect(_simulate_new_user_flow)
	column.add_child(newbie)
	return column


func _build_home_bottom_nav() -> Control:
	var panel := PanelContainer.new()
	panel.set_anchor(SIDE_TOP, 1.0)
	panel.set_anchor(SIDE_RIGHT, 1.0)
	panel.set_anchor(SIDE_BOTTOM, 1.0)
	panel.offset_top = -78
	panel.add_theme_stylebox_override("panel", _button_style(Color("#1679D4"), 0))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)

	row.add_child(_nav_button("★", "星"))
	row.add_child(_nav_button("杯", "杯"))

	var home := _nav_button("城", "主页")
	home.disabled = true
	row.add_child(home)

	row.add_child(_nav_button("队", "队"))
	row.add_child(_nav_button("⚙", "设"))
	return panel


func _build_home_resource_bar() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 58
	row.add_theme_constant_override("separation", 8)

	home_coin_label = _resource_label("●  %d" % coin_count, Color("#E6A63A"))
	row.add_child(home_coin_label)

	home_heart_label = _resource_label("♥  3", Color("#F06B78"))
	row.add_child(home_heart_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var settings := _small_button("⚙")
	settings.tooltip_text = "设置"
	settings.pressed.connect(_on_settings)
	row.add_child(settings)

	var editor := _small_button("编")
	editor.tooltip_text = "关卡编辑器"
	editor.pressed.connect(_open_level_editor)
	row.add_child(editor)
	return row


func _build_home_hero() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = 410
	panel.add_theme_stylebox_override("panel", _card_style(Color("#DDEFFD"), 24, true, 18))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var title := Label.new()
	title.text = "Color Queens"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", INK)
	title.add_theme_font_size_override("font_size", 36)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "皇冠花园"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("#52627A"))
	subtitle.add_theme_font_size_override("font_size", 18)
	column.add_child(subtitle)

	var castle := Label.new()
	castle.text = "♛\n▟▙  ▟▙\n▛▜▛▜"
	castle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	castle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	castle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	castle.add_theme_color_override("font_color", Color("#385B86"))
	castle.add_theme_font_size_override("font_size", 54)
	column.add_child(castle)

	home_area_label = Label.new()
	home_area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_area_label.add_theme_color_override("font_color", Color("#385B86"))
	home_area_label.add_theme_font_size_override("font_size", 18)
	column.add_child(home_area_label)
	return panel


func _build_home_progress() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 86
	panel.add_theme_stylebox_override("panel", _card_style(CARD, 18, true, 14))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	home_level_label = Label.new()
	home_level_label.add_theme_color_override("font_color", INK)
	home_level_label.add_theme_font_size_override("font_size", 19)
	column.add_child(home_level_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)

	home_progress_bar = ProgressBar.new()
	home_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home_progress_bar.custom_minimum_size.y = 22
	home_progress_bar.show_percentage = false
	home_progress_bar.add_theme_stylebox_override("background", _button_style(Color("#E8E3DB"), 11))
	home_progress_bar.add_theme_stylebox_override("fill", _button_style(Color("#48B985"), 11))
	row.add_child(home_progress_bar)

	home_progress_label = Label.new()
	home_progress_label.custom_minimum_size.x = 70
	home_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	home_progress_label.add_theme_color_override("font_color", MUTED)
	home_progress_label.add_theme_font_size_override("font_size", 15)
	row.add_child(home_progress_label)
	return panel


func _build_home_actions() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)

	home_start_button = _action_button("开始关卡", Color("#FFB84E"))
	home_start_button.custom_minimum_size.y = 66
	home_start_button.add_theme_font_size_override("font_size", 23)
	home_start_button.pressed.connect(_start_current_flow)
	column.add_child(home_start_button)

	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 70
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)

	var daily := _action_button("每日奖励", Color("#FFFFFF"))
	daily.pressed.connect(func() -> void:
		coin_count += 10
		_update_coin_label()
		_update_home()
		_save_game()
		_show_toast("每日奖励：金币 +10")
	)
	row.add_child(daily)

	var chest := _action_button("宝箱", Color("#FFFFFF"))
	chest.pressed.connect(func() -> void: _show_toast("继续通关，皇冠宝箱即将开启"))
	row.add_child(chest)
	return column


func _build_home_nav() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 54
	row.add_theme_constant_override("separation", 8)

	var home := _action_button("主页", Color("#EAF8F0"))
	home.disabled = true
	row.add_child(home)

	var event := _action_button("活动")
	event.pressed.connect(func() -> void: _show_toast("活动将在后续版本开放"))
	row.add_child(event)

	var shop := _action_button("商店")
	shop.pressed.connect(func() -> void: _show_toast("商店将在后续版本开放"))
	row.add_child(shop)
	return row


func _build_game_screen() -> Control:
	var safe_margin := MarginContainer.new()
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_margin.add_theme_constant_override("margin_left", 12)
	safe_margin.add_theme_constant_override("margin_right", 12)
	safe_margin.add_theme_constant_override("margin_top", 16)
	safe_margin.add_theme_constant_override("margin_bottom", 12)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	safe_margin.add_child(content)

	content.add_child(_build_top_bar())
	content.add_child(_build_level_header())
	content.add_child(_build_coach())

	board = GameBoardScript.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.cell_pressed.connect(_on_cell_pressed)
	content.add_child(board)

	content.add_child(_build_action_bar())
	return safe_margin


func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 60
	panel.add_theme_stylebox_override("panel", _card_style(CARD, 18, true))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	margin.add_child(row)

	var home_button := _small_button("⌂")
	home_button.tooltip_text = "返回首页"
	home_button.pressed.connect(_show_home)
	row.add_child(home_button)

	tutorial_skip_button = _small_button("跳")
	tutorial_skip_button.tooltip_text = "跳过新手教程"
	tutorial_skip_button.pressed.connect(_on_tutorial_button_pressed)
	tutorial_skip_button.hide()
	row.add_child(tutorial_skip_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	return panel


func _build_level_header() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 46

	level_label = Label.new()
	level_label.add_theme_color_override("font_color", INK)
	level_label.add_theme_font_size_override("font_size", 27)
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(level_label)

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
	panel.custom_minimum_size.y = 78
	panel.add_theme_stylebox_override("panel", _button_style(Color("#FFF0C9"), 16))

	coach_label = Label.new()
	coach_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coach_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coach_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coach_label.add_theme_color_override("font_color", Color("#72552B"))
	coach_label.add_theme_font_size_override("font_size", 13)
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

	hint_button = _action_button("", Color("#EAF8F0"))
	hint_button.add_theme_color_override("font_color", Color("#23845C"))
	hint_button.pressed.connect(_use_hint)
	row.add_child(hint_button)
	_update_hint_button()
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
	panel.custom_minimum_size = Vector2(430, 370)
	panel.add_theme_stylebox_override("panel", _card_style(CARD, 28, true, 28))
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
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

	completion_next_button = _action_button("下一关  →", Color("#FFB84E"))
	completion_next_button.custom_minimum_size.y = 58
	completion_next_button.add_theme_color_override("font_color", INK)
	completion_next_button.add_theme_font_size_override("font_size", 22)
	completion_next_button.pressed.connect(_next_level)
	column.add_child(completion_next_button)

	completion_replay_button = Button.new()
	completion_replay_button.text = "重玩本关"
	completion_replay_button.flat = true
	completion_replay_button.custom_minimum_size.y = 52
	completion_replay_button.add_theme_color_override("font_color", MUTED)
	completion_replay_button.add_theme_font_size_override("font_size", 19)
	completion_replay_button.pressed.connect(_replay_level)
	column.add_child(completion_replay_button)


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
	help_dialog.dialog_text = "在每个颜色区域放置一个皇冠，并同时满足：\n\n• 每一行只有一个皇冠\n• 每一列只有一个皇冠\n• 每个颜色区域只有一个皇冠\n• 皇冠不能八方向相邻\n\n第一次点按标记 X，第二次点按放置皇冠，第三次恢复空白。"
	help_dialog.ok_button_text = "知道了"
	help_dialog.unresizable = true
	add_child(help_dialog)


func _build_tutorial_dialogs() -> void:
	tutorial_skip_dialog = ConfirmationDialog.new()
	tutorial_skip_dialog.title = "跳过新手教程？"
	tutorial_skip_dialog.dialog_text = "跳过后会直接进入第 1 关，并记为已完成新手教程。"
	tutorial_skip_dialog.ok_button_text = "确认跳过"
	tutorial_skip_dialog.cancel_button_text = "继续教程"
	tutorial_skip_dialog.confirmed.connect(func() -> void: _finish_tutorial(true))
	add_child(tutorial_skip_dialog)

	tutorial_resume_dialog = ConfirmationDialog.new()
	tutorial_resume_dialog.title = "继续新手教程？"
	tutorial_resume_dialog.dialog_text = "检测到你还没有完成新手教程。"
	tutorial_resume_dialog.ok_button_text = "继续教程"
	tutorial_resume_dialog.cancel_button_text = "重新开始"
	tutorial_resume_dialog.confirmed.connect(func() -> void: _start_tutorial_step(tutorial_step_index))
	tutorial_resume_dialog.canceled.connect(func() -> void: _start_tutorial_step(0))
	add_child(tutorial_resume_dialog)


func _load_level(index: int, allow_resume: bool = false) -> void:
	in_tutorial = false
	if tutorial_skip_button:
		tutorial_skip_button.hide()
	if level_picker:
		level_picker.disabled = false
	current_level_index = index
	current_level = levels[index]
	is_completed = false
	active_hint_step.clear()
	active_hint_stage = 0
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
	if help_button:
		help_button.show()
	if completion_next_button:
		completion_next_button.text = "下一关  →"
	if completion_replay_button:
		completion_replay_button.text = "重玩本关"
	if undo_button:
		undo_button.show()
	if clear_button:
		clear_button.show()
	if hint_button:
		hint_button.show()
	_update_level_picker()
	coach_label.text = str(current_level.get("tutorial", "放置全部皇冠，满足四条规则。"))
	coach_label.add_theme_color_override("font_color", Color("#72552B"))
	if progress_bar:
		progress_bar.max_value = int(current_level["targetCount"])
	board.set_level(current_level, cell_states, REGION_COLORS)
	_validate_and_update(false)
	_update_home()
	if is_completed:
		reward_label.text = "本关已完成 · 继续挑战下一关"
		completion_overlay.show()
	_save_game()


func _on_cell_pressed(row: int, col: int) -> void:
	if in_tutorial:
		_on_tutorial_cell_pressed(row, col)
		return
	if is_completed:
		return
	active_hint_step.clear()
	active_hint_stage = 0
	board.set_guides({})
	_push_history()
	var state: String = cell_states[row][col]
	match state:
		"empty":
			cell_states[row][col] = "blocked"
		"piece", "hint":
			cell_states[row][col] = "empty"
		"blocked":
			cell_states[row][col] = "piece"
		_:
			cell_states[row][col] = "empty"
	board.set_states(cell_states)
	board.play_cell_feedback(row, col)
	_validate_and_update(true)
	_save_game()


func _undo() -> void:
	if in_tutorial:
		_use_tutorial_undo()
		return
	if move_history.is_empty() or is_completed:
		return
	cell_states = move_history.pop_back()
	board.set_states(cell_states)
	_validate_and_update(false)
	_save_game()


func _clear_board() -> void:
	if in_tutorial:
		_use_tutorial_clear()
		return
	if is_completed or _piece_positions().is_empty() and not _has_blocked_cells():
		return
	_push_history()
	cell_states = _blank_states(int(current_level["rows"]), int(current_level["cols"]))
	active_hint_step.clear()
	active_hint_stage = 0
	board.set_states(cell_states)
	board.set_guides({})
	_validate_and_update(false)
	_save_game()
	_show_toast("棋盘已清空，可撤销恢复")


func _use_hint() -> void:
	if in_tutorial:
		_use_tutorial_hint()
		return
	if is_completed:
		return

	var hint := _build_best_next_hint()
	if hint.is_empty():
		_show_toast("当前没有明显可提示的位置")
		return
	if hint_count <= 0 and coin_count < HINT_COST:
		_show_toast("提示次数与金币不足，点顶部 + 可领取演示奖励")
		return

	if hint_count > 0:
		hint_count -= 1
	else:
		coin_count -= HINT_COST

	var guides: Dictionary = hint.get("guides", {})
	board.set_guides(guides)
	var target: Vector2i = hint["target"]
	if target.x >= 0:
		board.play_guide_feedback(target.y, target.x)
	coach_label.text = str(hint["message"])
	coach_label.add_theme_color_override("font_color", Color("#23845C"))
	_update_coin_label()
	_update_hint_button()
	_save_game()
	_show_toast("已给出当前最优先的一步判断")


func _validate_and_update(allow_completion: bool) -> void:
	var pieces := _piece_positions()
	var conflicts := _find_conflicts(pieces)
	board.set_errors(conflicts if immediate_errors else {})

	if progress_bar:
		progress_bar.value = pieces.size()
	if progress_label:
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


func _build_best_next_hint() -> Dictionary:
	var unit_hint := _best_single_candidate_hint()
	if not unit_hint.is_empty():
		return unit_hint

	var lock_hint := _best_locked_candidate_hint()
	if not lock_hint.is_empty():
		return lock_hint

	var subset_hint := _best_subset_lock_hint()
	if not subset_hint.is_empty():
		return subset_hint

	var lookahead_hint := _best_lookahead_exclusion_hint()
	if not lookahead_hint.is_empty():
		return lookahead_hint

	var exclusion_hint := _best_exclusion_hint()
	if not exclusion_hint.is_empty():
		return exclusion_hint

	return _best_candidate_focus_hint()


func _best_single_candidate_hint() -> Dictionary:
	var best := {}
	for row in range(int(current_level["rows"])):
		if _row_has_piece(row):
			continue
		var unit_cells := _row_cells(row)
		var candidates := _available_candidates_in_cells(unit_cells)
		if candidates.size() == 1:
			best = _choose_stronger_unit_hint(best, _make_single_candidate_hint("第 %d 行" % [row + 1], candidates[0], unit_cells))

	for col in range(int(current_level["cols"])):
		if _col_has_piece(col):
			continue
		var unit_cells := _col_cells(col)
		var candidates := _available_candidates_in_cells(unit_cells)
		if candidates.size() == 1:
			best = _choose_stronger_unit_hint(best, _make_single_candidate_hint("第 %d 列" % [col + 1], candidates[0], unit_cells))

	for region_id in _region_ids():
		if _region_has_piece(region_id):
			continue
		var unit_cells := _region_cells(region_id)
		var candidates := _available_candidates_in_cells(unit_cells)
		if candidates.size() == 1:
			best = _choose_stronger_unit_hint(best, _make_single_candidate_hint(_region_name(region_id), candidates[0], unit_cells))
	return best


func _choose_stronger_unit_hint(current: Dictionary, candidate: Dictionary) -> Dictionary:
	if current.is_empty():
		return candidate
	if int(candidate.get("score", 0)) > int(current.get("score", 0)):
		return candidate
	return current


func _make_single_candidate_hint(unit_name: String, target: Vector2i, unit_cells: Array[Vector2i]) -> Dictionary:
	var exclusions := _excluded_cells_in_cells(unit_cells)
	var guides := _guides_for_unit(unit_cells, _available_candidates_in_cells(unit_cells), exclusions)
	guides[target] = "place"
	return {
		"target": target,
		"guides": guides,
		"score": exclusions.size(),
		"message": _best_single_candidate_message(unit_name, target, unit_cells, exclusions)
	}


func _best_single_candidate_message(unit_name: String, target: Vector2i, unit_cells: Array[Vector2i], exclusions: Array[Dictionary]) -> String:
	var summary := _exclusion_summary(exclusions)
	var detail := _first_exclusion_detail(exclusions)
	var target_region := int(current_level["regions"][target.y][target.x])
	var target_text := "第 %d 行第 %d 列" % [target.y + 1, target.x + 1]
	var message := "%s还需要 1 个皇冠，%s，所以只剩 %s。" % [unit_name, summary, target_text]
	message += " 这个格所在列还剩 %d 个候选，%s还剩 %d 个候选。" % [_available_candidates_in_col(target.x).size(), _region_name(target_region), _available_candidates_in_region(target_region).size()]
	if detail != "":
		message += " 例如：%s。" % detail
	return message


func _best_locked_candidate_hint() -> Dictionary:
	for row in range(int(current_level["rows"])):
		if _row_has_piece(row):
			continue
		var candidates := _available_candidates_in_row(row)
		if candidates.size() >= 2 and candidates.size() <= 3:
			var region_id := _shared_region(candidates)
			if region_id > 0:
				var other_cells := _candidate_cells_except(_available_candidates_in_region(region_id), candidates)
				if not other_cells.is_empty():
					return _make_locked_hint("第 %d 行" % [row + 1], candidates, _region_name(region_id), other_cells)

	for col in range(int(current_level["cols"])):
		if _col_has_piece(col):
			continue
		var candidates := _available_candidates_in_col(col)
		if candidates.size() >= 2 and candidates.size() <= 3:
			var region_id := _shared_region(candidates)
			if region_id > 0:
				var other_cells := _candidate_cells_except(_available_candidates_in_region(region_id), candidates)
				if not other_cells.is_empty():
					return _make_locked_hint("第 %d 列" % [col + 1], candidates, _region_name(region_id), other_cells)

	for region_id in _region_ids():
		if _region_has_piece(region_id):
			continue
		var candidates := _available_candidates_in_region(region_id)
		if candidates.size() >= 2 and candidates.size() <= 3:
			var row := _shared_row(candidates)
			if row >= 0:
				var other_cells := _candidate_cells_except(_available_candidates_in_row(row), candidates)
				if not other_cells.is_empty():
					return _make_locked_hint(_region_name(region_id), candidates, "第 %d 行" % [row + 1], other_cells)
			var col := _shared_col(candidates)
			if col >= 0:
				var other_cells := _candidate_cells_except(_available_candidates_in_col(col), candidates)
				if not other_cells.is_empty():
					return _make_locked_hint(_region_name(region_id), candidates, "第 %d 列" % [col + 1], other_cells)
	return {}


func _make_locked_hint(source_name: String, locked_cells: Array[Vector2i], target_name: String, other_cells: Array[Vector2i]) -> Dictionary:
	var guides := {}
	for cell in locked_cells:
		guides[cell] = "candidate"
	for cell in other_cells:
		guides[cell] = "exclude"
	var focus := locked_cells[0]
	return {
		"target": focus,
		"guides": guides,
		"message": "%s的皇冠只可能在这些绿色候选里，而这些候选都落在%s内。因此%s里的其它橙色候选可以先排除。" % [source_name, target_name, target_name]
	}


func _best_subset_lock_hint() -> Dictionary:
	var pairs := [
		["row", "col"],
		["col", "row"],
		["row", "region"],
		["col", "region"],
		["region", "row"],
		["region", "col"]
	]
	for pair in pairs:
		var source_kind := str(pair[0])
		var target_kind := str(pair[1])
		var units := _open_unit_candidates(source_kind)
		for group_size in range(2, 4):
			var combinations := _unit_index_combinations(units.size(), group_size)
			for combination in combinations:
				var source_names: Array[String] = []
				var source_cells: Array[Vector2i] = []
				var target_values: Array[int] = []
				for unit_position in combination:
					var unit: Dictionary = units[int(unit_position)]
					source_names.append(str(unit["name"]))
					for cell in unit["candidates"]:
						if not source_cells.has(cell):
							source_cells.append(cell)
						var value := _cell_unit_value(cell, target_kind)
						if not target_values.has(value):
							target_values.append(value)
				if target_values.size() != group_size:
					continue
				var other_cells: Array[Vector2i] = []
				for target_value in target_values:
					for cell in _available_candidates_for_unit(target_kind, target_value):
						if not source_cells.has(cell) and not other_cells.has(cell):
							other_cells.append(cell)
				if not other_cells.is_empty():
					return _make_subset_lock_hint(source_names, source_cells, target_kind, target_values, other_cells)
	return {}


func _make_subset_lock_hint(source_names: Array[String], source_cells: Array[Vector2i], target_kind: String, target_values: Array[int], other_cells: Array[Vector2i]) -> Dictionary:
	var guides := {}
	for cell in source_cells:
		guides[cell] = "candidate"
	for cell in other_cells:
		guides[cell] = "exclude"
	var target_names: Array[String] = []
	for value in target_values:
		target_names.append(_unit_name_by_kind(target_kind, value))
	return {
		"target": other_cells[0],
		"guides": guides,
		"message": "%s的皇冠只能落在%s里。因为这些单元彼此占满了这组位置，所以%s中其它橙色候选可以排除。" % ["、".join(source_names), "、".join(target_names), "、".join(target_names)]
	}


func _best_lookahead_exclusion_hint() -> Dictionary:
	for row in range(int(current_level["rows"])):
		for col in range(int(current_level["cols"])):
			var cell := Vector2i(col, row)
			if not _is_available_candidate(cell):
				continue
			var blocked_unit := _blocked_unit_after_assume(cell)
			if blocked_unit.is_empty():
				continue
			var unit_name := _unit_name_by_kind(str(blocked_unit["kind"]), int(blocked_unit["index"]))
			var guides := {}
			guides[cell] = "exclude"
			for peer in _unit_cells_by_kind(str(blocked_unit["kind"]), int(blocked_unit["index"])):
				if peer != cell:
					guides[peer] = "unit"
			return {
				"target": cell,
				"guides": guides,
				"message": "如果第 %d 行第 %d 列放皇冠，%s就没有任何可放位置了。所以这个橙色格一定不是皇冠，可以先标 X。" % [row + 1, col + 1, unit_name]
			}
	return {}


func _best_exclusion_hint() -> Dictionary:
	for row in range(int(current_level["rows"])):
		for col in range(int(current_level["cols"])):
			var cell := Vector2i(col, row)
			if cell_states[row][col] != "empty":
				continue
			var reason := _first_conflict_reason(cell)
			if reason == "":
				continue
			var guides := {}
			guides[cell] = "exclude"
			for piece in _piece_positions():
				if _piece_conflicts_with_cell(piece, cell):
					guides[piece] = "place"
					break
			return {
				"target": cell,
				"guides": guides,
				"message": "第 %d 行第 %d 列可以排除：%s。这个格不可能放皇冠，先标 X 能减少后面的候选。" % [row + 1, col + 1, reason]
			}
	return {}


func _best_candidate_focus_hint() -> Dictionary:
	var best := Vector2i(-1, -1)
	var best_score := 999
	for row in range(int(current_level["rows"])):
		for col in range(int(current_level["cols"])):
			var cell := Vector2i(col, row)
			if not _is_available_candidate(cell):
				continue
			var score := _available_candidates_in_row(row).size() + _available_candidates_in_col(col).size() + _available_candidates_in_region(int(current_level["regions"][row][col])).size()
			if score < best_score:
				best_score = score
				best = cell
	if best.x < 0:
		return {}
	var region_id := int(current_level["regions"][best.y][best.x])
	var guides := {}
	for cell in _row_cells(best.y):
		guides[cell] = "unit"
	for cell in _available_candidates_in_row(best.y):
		guides[cell] = "candidate"
	guides[best] = "place"
	return {
		"target": best,
		"guides": guides,
		"message": "当前没有唯一答案，但第 %d 行第 %d 列最值得优先比较：它所在行剩 %d 个候选，列剩 %d 个候选，%s剩 %d 个候选。先围绕这些候选继续排除。" % [best.y + 1, best.x + 1, _available_candidates_in_row(best.y).size(), _available_candidates_in_col(best.x).size(), _region_name(region_id), _available_candidates_in_region(region_id).size()]
	}


func _guides_for_unit(unit_cells: Array[Vector2i], candidates: Array[Vector2i], exclusions: Array[Dictionary]) -> Dictionary:
	var guides := {}
	for cell in unit_cells:
		guides[cell] = "unit"
	for item in exclusions:
		guides[item["cell"]] = "exclude"
	for cell in candidates:
		guides[cell] = "candidate"
	return guides


func _exclusion_summary(exclusions: Array[Dictionary]) -> String:
	var blocked := 0
	var occupied := 0
	var conflict := 0
	for item in exclusions:
		var reason := str(item["reason"])
		if reason == "已标 X":
			blocked += 1
		elif reason == "已有皇冠":
			occupied += 1
		else:
			conflict += 1
	var parts: Array[String] = []
	if blocked > 0:
		parts.append("%d 个已被你标 X" % blocked)
	if occupied > 0:
		parts.append("%d 个已经有皇冠" % occupied)
	if conflict > 0:
		parts.append("%d 个会和已有皇冠冲突" % conflict)
	if parts.is_empty():
		return "其它格都不适合"
	return "其它格中：" + "，".join(parts)


func _first_exclusion_detail(exclusions: Array[Dictionary]) -> String:
	for item in exclusions:
		var reason := str(item["reason"])
		if reason != "已标 X" and reason != "已有皇冠":
			var cell: Vector2i = item["cell"]
			return "第 %d 行第 %d 列被排除，因为%s" % [cell.y + 1, cell.x + 1, reason]
	return ""


func _piece_conflicts_with_cell(piece: Vector2i, cell: Vector2i) -> bool:
	return piece.y == cell.y or piece.x == cell.x or int(current_level["regions"][piece.y][piece.x]) == int(current_level["regions"][cell.y][cell.x]) or (absi(piece.x - cell.x) <= 1 and absi(piece.y - cell.y) <= 1)


func _region_name(region_id: int) -> String:
	var index := region_id - 1
	if index >= 0 and index < REGION_COLOR_NAMES.size():
		return "%s区域" % REGION_COLOR_NAMES[index]
	return "这个颜色区域"


func _shared_region(cells: Array[Vector2i]) -> int:
	if cells.is_empty():
		return -1
	var region_id := int(current_level["regions"][cells[0].y][cells[0].x])
	for cell in cells:
		if int(current_level["regions"][cell.y][cell.x]) != region_id:
			return -1
	return region_id


func _shared_row(cells: Array[Vector2i]) -> int:
	if cells.is_empty():
		return -1
	var row := cells[0].y
	for cell in cells:
		if cell.y != row:
			return -1
	return row


func _shared_col(cells: Array[Vector2i]) -> int:
	if cells.is_empty():
		return -1
	var col := cells[0].x
	for cell in cells:
		if cell.x != col:
			return -1
	return col


func _candidate_cells_except(cells: Array[Vector2i], excluded: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		if not excluded.has(cell):
			result.append(cell)
	return result


func _open_unit_candidates(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in _unit_indices_by_kind(kind):
		if _unit_has_piece(kind, index):
			continue
		var candidates := _available_candidates_for_unit(kind, index)
		if candidates.size() > 1:
			result.append({
				"index": index,
				"name": _unit_name_by_kind(kind, index),
				"candidates": candidates
			})
	return result


func _available_candidates_for_unit(kind: String, index: int) -> Array[Vector2i]:
	match kind:
		"row":
			return _available_candidates_in_row(index)
		"col":
			return _available_candidates_in_col(index)
		"region":
			return _available_candidates_in_region(index)
		_:
			return []


func _unit_indices_by_kind(kind: String) -> Array[int]:
	var result: Array[int] = []
	match kind:
		"row":
			for row in range(int(current_level["rows"])):
				result.append(row)
		"col":
			for col in range(int(current_level["cols"])):
				result.append(col)
		"region":
			return _region_ids()
	return result


func _unit_has_piece(kind: String, index: int) -> bool:
	match kind:
		"row":
			return _row_has_piece(index)
		"col":
			return _col_has_piece(index)
		"region":
			return _region_has_piece(index)
		_:
			return false


func _unit_name_by_kind(kind: String, index: int) -> String:
	match kind:
		"row":
			return "第 %d 行" % [index + 1]
		"col":
			return "第 %d 列" % [index + 1]
		"region":
			return _region_name(index)
		_:
			return "这个单元"


func _unit_cells_by_kind(kind: String, index: int) -> Array[Vector2i]:
	match kind:
		"row":
			return _row_cells(index)
		"col":
			return _col_cells(index)
		"region":
			return _region_cells(index)
		_:
			return []


func _cell_unit_value(cell: Vector2i, kind: String) -> int:
	match kind:
		"row":
			return cell.y
		"col":
			return cell.x
		"region":
			return int(current_level["regions"][cell.y][cell.x])
		_:
			return -1


func _unit_index_combinations(count: int, group_size: int) -> Array[Array]:
	var result: Array[Array] = []
	if group_size == 2:
		for a in range(count):
			for b in range(a + 1, count):
				result.append([a, b])
	elif group_size == 3:
		for a in range(count):
			for b in range(a + 1, count):
				for c in range(b + 1, count):
					result.append([a, b, c])
	return result


func _blocked_unit_after_assume(cell: Vector2i) -> Dictionary:
	var kinds := ["row", "col", "region"]
	for kind in kinds:
		for index in _unit_indices_by_kind(kind):
			if _unit_has_piece_after_assume(kind, index, cell):
				continue
			var has_candidate := false
			for unit_cell in _unit_cells_by_kind(kind, index):
				if _is_available_after_assume(unit_cell, cell):
					has_candidate = true
					break
			if not has_candidate:
				return {"kind": kind, "index": index}
	return {}


func _unit_has_piece_after_assume(kind: String, index: int, assumed: Vector2i) -> bool:
	if _cell_unit_value(assumed, kind) == index:
		return true
	return _unit_has_piece(kind, index)


func _is_available_after_assume(position: Vector2i, assumed: Vector2i) -> bool:
	if position == assumed:
		return false
	if not _is_available_candidate(position):
		return false
	if position.y == assumed.y or position.x == assumed.x:
		return false
	if int(current_level["regions"][position.y][position.x]) == int(current_level["regions"][assumed.y][assumed.x]):
		return false
	if absi(position.x - assumed.x) <= 1 and absi(position.y - assumed.y) <= 1:
		return false
	return true


func _select_prepared_hint_step() -> Dictionary:
	var steps: Array = current_level.get("hintSteps", [])
	for raw_step in steps:
		var step: Dictionary = raw_step
		if _hint_step_still_relevant(step):
			return step
	var fallback := _build_teaching_hint()
	if fallback.is_empty():
		return {}
	return {
		"target": [fallback["target"].y, fallback["target"].x],
		"unit": "row",
		"unitIndex": fallback["target"].y,
		"title": "观察第 %d 行" % [fallback["target"].y + 1],
		"technique": "候选排除"
	}


func _hint_step_still_relevant(step: Dictionary) -> bool:
	if step.is_empty() or not step.has("target"):
		return false
	var target := _step_target(step)
	if target.x < 0:
		return false
	var state: String = cell_states[target.y][target.x]
	return state != "piece" and state != "hint"


func _build_staged_hint(step: Dictionary, stage: int) -> Dictionary:
	if step.is_empty():
		return _build_teaching_hint()
	var target := _step_target(step)
	var unit_cells := _step_unit_cells(step)
	if unit_cells.is_empty():
		return _build_teaching_hint()

	var unit_name := _step_unit_name(step)
	var candidates := _available_candidates_in_cells(unit_cells)
	var exclusions := _excluded_cells_in_cells(unit_cells)
	var stage_number := clampi(stage + 1, 1, 3)

	if stage_number == 1:
		var guides := {}
		for cell in unit_cells:
			guides[cell] = "unit"
		return {
			"stage": stage_number,
			"target": target,
			"guides": guides,
			"message": "提示 1/3：先看%s。这个单元最终需要 1 个皇冠，先不要急着放，先找哪些格子还可能成为候选。" % unit_name
		}

	if stage_number == 2:
		var guides := {}
		for cell in candidates:
			guides[cell] = "candidate"
		for item in exclusions:
			guides[item["cell"]] = "exclude"
		return {
			"stage": stage_number,
			"target": target if candidates.has(target) else Vector2i(-1, -1),
			"guides": guides,
			"message": _candidate_breakdown_message(unit_name, candidates, exclusions, unit_cells)
		}

	var final_guides := {}
	var final_target := target
	if candidates.size() == 1:
		final_target = candidates[0]
		final_guides[final_target] = "place"
		return {
			"stage": stage_number,
			"target": final_target,
			"guides": final_guides,
			"message": "%s现在只剩 1 个合法候选：第 %d 行第 %d 列。原因是其它格已经被 X、已有皇冠或冲突规则排除了。" % [unit_name, final_target.y + 1, final_target.x + 1]
		}
	if candidates.has(target):
		final_guides[target] = "place"
		return {
			"stage": stage_number,
			"target": target,
			"guides": final_guides,
			"message": "%s还剩 %d 个候选。绿色格是预设解题路径中的下一步候选，但现在还需要你结合其它行、列或颜色区域继续验证。" % [unit_name, candidates.size()]
		}
	if not candidates.is_empty():
		final_target = candidates[0]
		final_guides[final_target] = "candidate"
		return {
			"stage": stage_number,
			"target": final_target,
			"guides": final_guides,
			"message": "%s的原提示位置已经不适合当前棋盘。先从这个仍合法的候选继续分析。" % unit_name
		}
	return _build_teaching_hint()


func _step_target(step: Dictionary) -> Vector2i:
	var target: Array = step.get("target", [])
	if target.size() < 2:
		return Vector2i(-1, -1)
	return Vector2i(int(target[1]), int(target[0]))


func _step_unit_cells(step: Dictionary) -> Array[Vector2i]:
	var unit := str(step.get("unit", "row"))
	var unit_index := int(step.get("unitIndex", 0))
	match unit:
		"row":
			return _row_cells(unit_index)
		"col":
			return _col_cells(unit_index)
		"region":
			return _region_cells(unit_index)
		_:
			return _row_cells(_step_target(step).y)


func _step_unit_name(step: Dictionary) -> String:
	var unit := str(step.get("unit", "row"))
	var unit_index := int(step.get("unitIndex", 0))
	match unit:
		"row":
			return "第 %d 行" % [unit_index + 1]
		"col":
			return "第 %d 列" % [unit_index + 1]
		"region":
			return _region_name(unit_index)
		_:
			return "这个单元"


func _available_candidates_in_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		if _is_available_candidate(cell):
			result.append(cell)
	return result


func _excluded_cells_in_cells(cells: Array[Vector2i]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell in cells:
		var state: String = cell_states[cell.y][cell.x]
		if state == "blocked":
			result.append({"cell": cell, "reason": "已标 X"})
		elif state == "piece" or state == "hint":
			result.append({"cell": cell, "reason": "已有皇冠"})
		else:
			var reason := _first_conflict_reason(cell)
			if reason != "":
				result.append({"cell": cell, "reason": reason})
	return result


func _candidate_breakdown_message(unit_name: String, candidates: Array[Vector2i], exclusions: Array[Dictionary], unit_cells: Array[Vector2i]) -> String:
	var blocked := 0
	var occupied := 0
	var conflict := 0
	for item in exclusions:
		var reason := str(item["reason"])
		if reason == "已标 X":
			blocked += 1
		elif reason == "已有皇冠":
			occupied += 1
		else:
			conflict += 1
	var reasons: Array[String] = []
	if blocked > 0:
		reasons.append("%d 个已被你标 X" % blocked)
	if occupied > 0:
		reasons.append("%d 个已有皇冠" % occupied)
	if conflict > 0:
		reasons.append("%d 个会和已有皇冠冲突" % conflict)
	var reason_text := "目前没有明确排除格"
	if not reasons.is_empty():
		reason_text = "已经排除：" + "，".join(reasons)
	return "提示 2/3：%s共有 %d 格，%s；还剩 %d 个绿色候选。先比较这些候选的列和颜色区域。" % [unit_name, unit_cells.size(), reason_text, candidates.size()]


func _build_teaching_hint() -> Dictionary:
	var rows := int(current_level["rows"])
	var cols := int(current_level["cols"])

	for row in range(rows):
		if _row_has_piece(row):
			continue
		var row_candidates := _available_candidates_in_row(row)
		if row_candidates.size() == 1:
			var position: Vector2i = row_candidates[0]
			return {
				"kind": "place",
				"target": position,
				"message": _single_candidate_message("第 %d 行" % [row + 1], position, _row_cells(row))
			}

	for col in range(cols):
		if _col_has_piece(col):
			continue
		var col_candidates := _available_candidates_in_col(col)
		if col_candidates.size() == 1:
			var position: Vector2i = col_candidates[0]
			return {
				"kind": "place",
				"target": position,
				"message": _single_candidate_message("第 %d 列" % [col + 1], position, _col_cells(col))
			}

	for region_id in _region_ids():
		if _region_has_piece(region_id):
			continue
		var region_candidates := _available_candidates_in_region(region_id)
		if region_candidates.size() == 1:
			var position: Vector2i = region_candidates[0]
			return {
				"kind": "place",
				"target": position,
				"message": _single_candidate_message(_region_name(region_id), position, _region_cells(region_id))
			}

	var exclusion_hint := _build_exclusion_hint()
	if not exclusion_hint.is_empty():
		return exclusion_hint

	var fallback := _build_candidate_hint()
	if not fallback.is_empty():
		return fallback
	return {}


func _build_exclusion_hint() -> Dictionary:
	for row in range(int(current_level["rows"])):
		for col in range(int(current_level["cols"])):
			if cell_states[row][col] != "empty":
				continue
			var reason := _first_conflict_reason(Vector2i(col, row))
			if reason != "":
				return {
					"kind": "exclude",
					"target": Vector2i(col, row),
					"message": "橙色格可以排除：%s。点它标记 X，可以缩小候选范围。" % reason
				}
	return {}


func _build_candidate_hint() -> Dictionary:
	var best := Vector2i(-1, -1)
	var best_score := 999
	for row in range(int(current_level["rows"])):
		for col in range(int(current_level["cols"])):
			var position := Vector2i(col, row)
			if not _is_available_candidate(position):
				continue
			var row_count := _available_candidates_in_row(row).size()
			var col_count := _available_candidates_in_col(col).size()
			var region_count := _available_candidates_in_region(int(current_level["regions"][row][col])).size()
			var score := row_count + col_count + region_count
			if score < best_score:
				best_score = score
				best = position
	if best.x < 0:
		return {}
	var region_id := int(current_level["regions"][best.y][best.x])
	return {
		"kind": "place",
		"target": best,
		"message": "绿色格目前仍是合法候选：第 %d 行还有 %d 个候选，第 %d 列还有 %d 个候选，%s还有 %d 个候选。它还不能确定，但值得重点比较。" % [best.y + 1, _available_candidates_in_row(best.y).size(), best.x + 1, _available_candidates_in_col(best.x).size(), _region_name(region_id), _available_candidates_in_region(region_id).size()]
	}


func _single_candidate_message(unit_name: String, position: Vector2i, unit_cells: Array[Vector2i]) -> String:
	var blocked := 0
	var conflict := 0
	var occupied := 0
	for cell in unit_cells:
		if cell == position:
			continue
		var state: String = cell_states[cell.y][cell.x]
		if state == "blocked":
			blocked += 1
		elif state == "piece" or state == "hint":
			occupied += 1
		elif _first_conflict_reason(cell) != "":
			conflict += 1
	var reasons: Array[String] = []
	if blocked > 0:
		reasons.append("%d 个已被你标 X" % blocked)
	if conflict > 0:
		reasons.append("%d 个会和已有皇冠冲突" % conflict)
	if occupied > 0:
		reasons.append("%d 个已经有皇冠" % occupied)
	var reason_text := "其它格都不适合"
	if not reasons.is_empty():
		reason_text = "其它格中：" + "，".join(reasons)
	return "%s还需要一个皇冠。%s；所以只剩第 %d 行第 %d 列。" % [unit_name, reason_text, position.y + 1, position.x + 1]


func _available_candidates_in_row(row: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for col in range(int(current_level["cols"])):
		var position := Vector2i(col, row)
		if _is_available_candidate(position):
			result.append(position)
	return result


func _available_candidates_in_col(col: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in range(int(current_level["rows"])):
		var position := Vector2i(col, row)
		if _is_available_candidate(position):
			result.append(position)
	return result


func _available_candidates_in_region(region_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _region_cells(region_id):
		if _is_available_candidate(cell):
			result.append(cell)
	return result


func _is_available_candidate(position: Vector2i) -> bool:
	if cell_states[position.y][position.x] != "empty":
		return false
	return _first_conflict_reason(position) == ""


func _first_conflict_reason(position: Vector2i) -> String:
	for piece in _piece_positions():
		if piece.y == position.y:
			return "它和第 %d 行第 %d 列的皇冠在同一行" % [piece.y + 1, piece.x + 1]
		if piece.x == position.x:
			return "它和第 %d 行第 %d 列的皇冠在同一列" % [piece.y + 1, piece.x + 1]
		if int(current_level["regions"][piece.y][piece.x]) == int(current_level["regions"][position.y][position.x]):
			return "它和第 %d 行第 %d 列的皇冠都在%s" % [piece.y + 1, piece.x + 1, _region_name(int(current_level["regions"][position.y][position.x]))]
		if absi(piece.x - position.x) <= 1 and absi(piece.y - position.y) <= 1:
			return "它和第 %d 行第 %d 列的皇冠相邻" % [piece.y + 1, piece.x + 1]
	return ""


func _row_cells(row: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for col in range(int(current_level["cols"])):
		result.append(Vector2i(col, row))
	return result


func _col_cells(col: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in range(int(current_level["rows"])):
		result.append(Vector2i(col, row))
	return result


func _region_cells(region_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in range(int(current_level["rows"])):
		for col in range(int(current_level["cols"])):
			if int(current_level["regions"][row][col]) == region_id:
				result.append(Vector2i(col, row))
	return result


func _region_ids() -> Array[int]:
	var result: Array[int] = []
	for row in current_level["regions"]:
		for region in row:
			var region_id := int(region)
			if not result.has(region_id):
				result.append(region_id)
	return result


func _row_has_piece(row: int) -> bool:
	for col in range(int(current_level["cols"])):
		if cell_states[row][col] == "piece" or cell_states[row][col] == "hint":
			return true
	return false


func _col_has_piece(col: int) -> bool:
	for row in range(int(current_level["rows"])):
		if cell_states[row][col] == "piece" or cell_states[row][col] == "hint":
			return true
	return false


func _region_has_piece(region_id: int) -> bool:
	for cell in _region_cells(region_id):
		if cell_states[cell.y][cell.x] == "piece" or cell_states[cell.y][cell.x] == "hint":
			return true
	return false


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



func _start_tutorial_step(index: int) -> void:
	in_tutorial = true
	tutorial_started = true
	tutorial_step_index = clampi(index, 0, TUTORIAL_LEVELS.size() - 1)
	tutorial_interaction_stage = 0
	tutorial_button_stage = 0
	current_level = TUTORIAL_LEVELS[tutorial_step_index]
	is_completed = false
	active_hint_step.clear()
	active_hint_stage = 0
	move_history.clear()
	completion_overlay.hide()
	cell_states = _blank_states(int(current_level["rows"]), int(current_level["cols"]))
	for coordinate in current_level.get("prefill", []):
		cell_states[int(coordinate[0])][int(coordinate[1])] = "piece"
	level_label.text = str(current_level.get("name", ""))
	coach_label.text = str(current_level["tutorial"])
	coach_label.add_theme_color_override("font_color", Color("#72552B"))
	if progress_bar:
		progress_bar.max_value = int(current_level["targetCount"])
		progress_bar.value = 0
	if progress_label:
		progress_label.text = "%d / %d" % [0, int(current_level["targetCount"])]
	if level_picker:
		level_picker.disabled = true
	if tutorial_skip_button:
		_update_tutorial_button()
	if completion_next_button:
		completion_next_button.text = "下一步  →" if tutorial_step_index < TUTORIAL_LEVELS.size() - 1 else "进入第 1 关  →"
	if completion_replay_button:
		completion_replay_button.text = "重来本步"
	board.set_level(current_level, cell_states, REGION_COLORS)
	_set_tutorial_guides()
	_update_tutorial_action_bar()
	_show_game()
	_update_hint_button()
	_update_home()
	_save_game()


func _set_tutorial_guides() -> void:
	var guides := {}
	var target := _tutorial_target()
	match tutorial_step_index:
		0:
			guides[target] = "place"
		1:
			for cell in _row_cells(target.y):
				guides[cell] = "unit"
			for cell in _col_cells(target.x):
				guides[cell] = "unit"
			for cell in _region_cells(int(current_level["regions"][target.y][target.x])):
				guides[cell] = "unit"
			guides[target] = "place"
		2:
			for row in range(int(current_level["rows"])):
				for col in range(int(current_level["cols"])):
					if absi(col - 1) <= 1 and absi(row - 1) <= 1 and not (col == 1 and row == 1):
						guides[Vector2i(col, row)] = "exclude"
			guides[target] = "exclude"
		3:
			guides[target] = "candidate"
	board.set_guides(guides)


func _update_tutorial_action_bar() -> void:
	if not undo_button or not clear_button or not hint_button:
		return
	var show_actions := in_tutorial and tutorial_step_index == 3
	undo_button.visible = show_actions
	clear_button.visible = show_actions
	hint_button.visible = show_actions
	if not show_actions:
		return
	undo_button.disabled = tutorial_button_stage != 0
	clear_button.disabled = tutorial_button_stage != 1
	hint_button.disabled = tutorial_button_stage != 2
	if tutorial_button_stage == 0:
		coach_label.text = "先点底部的撤销按钮。它可以撤回上一步操作。"
	elif tutorial_button_stage == 1:
		coach_label.text = "现在点清除按钮。它会帮你重新整理当前棋盘。"
	else:
		coach_label.text = "最后点提示按钮。它会解释下一步该观察哪里。"


func _tutorial_target() -> Vector2i:
	var target: Array = current_level.get("target", [0, 0])
	return Vector2i(int(target[1]), int(target[0]))


func _on_tutorial_cell_pressed(row: int, col: int) -> void:
	if is_completed:
		return
	var target := _tutorial_target()
	if Vector2i(col, row) != target:
		_show_toast("先点高亮的教程格子")
		board.play_guide_feedback(target.y, target.x)
		return
	var state: String = cell_states[row][col]
	match state:
		"empty":
			cell_states[row][col] = "blocked"
		"blocked":
			cell_states[row][col] = "piece"
		_:
			cell_states[row][col] = "empty"
	board.set_states(cell_states)
	board.play_cell_feedback(row, col)
	_validate_tutorial_step(row, col)
	_save_game()


func _validate_tutorial_step(row: int, col: int) -> void:
	match tutorial_step_index:
		0:
			var expected := ["blocked", "piece", "empty"]
			if cell_states[row][col] == expected[tutorial_interaction_stage]:
				tutorial_interaction_stage += 1
				if progress_bar:
					progress_bar.value = tutorial_interaction_stage
				if progress_label:
					progress_label.text = "%d / 3" % tutorial_interaction_stage
				if tutorial_interaction_stage == 1:
					coach_label.text = "很好，X 表示这里先排除。再点一次，把它变成皇冠。"
				elif tutorial_interaction_stage == 2:
					coach_label.text = "这就是皇冠。再点一次，可以取消这个格子的状态。"
				elif tutorial_interaction_stage >= 3:
					_complete_tutorial_step("你学会了点击、放皇冠和取消。")
		1:
			if cell_states[row][col] == "piece":
				if progress_bar:
					progress_bar.value = 1
				if progress_label:
					progress_label.text = "1 / 1"
				board.set_guides(_tutorial_unique_guides(Vector2i(col, row)))
				_complete_tutorial_step("记住：同一行、同一列、同一颜色区域都只能有一个皇冠。")
			else:
				coach_label.text = "这一关需要把高亮格点成皇冠。"
		2:
			if cell_states[row][col] == "blocked":
				if progress_bar:
					progress_bar.value = 1
				if progress_label:
					progress_label.text = "1 / 1"
				_complete_tutorial_step("很好，皇冠周围相邻格都要排除。")
			else:
				cell_states[row][col] = "empty"
				board.set_states(cell_states)
				coach_label.text = "这里和皇冠相邻，不能放皇冠。点成 X 来排除它。"
				_show_toast("相邻格不能放皇冠")
		3:
			_show_toast("这一关按底部按钮顺序学习：撤销、清除、提示")


func _tutorial_unique_guides(piece: Vector2i) -> Dictionary:
	var guides := {}
	for cell in _row_cells(piece.y):
		if cell != piece:
			guides[cell] = "exclude"
	for cell in _col_cells(piece.x):
		if cell != piece:
			guides[cell] = "exclude"
	for cell in _region_cells(int(current_level["regions"][piece.y][piece.x])):
		if cell != piece:
			guides[cell] = "exclude"
	guides[piece] = "place"
	return guides


func _use_tutorial_undo() -> void:
	if tutorial_step_index != 3:
		_show_toast("教程关卡中请按高亮提示操作")
		return
	if tutorial_button_stage != 0:
		_show_toast("先按当前高亮的按钮")
		return
	tutorial_button_stage = 1
	_show_toast("撤销：可以回到上一步。")
	_update_tutorial_action_bar()


func _use_tutorial_clear() -> void:
	if tutorial_step_index != 3:
		_start_tutorial_step(tutorial_step_index)
		_show_toast("已重来本步教程")
		return
	if tutorial_button_stage != 1:
		_show_toast("先按当前高亮的按钮")
		return
	tutorial_button_stage = 2
	_show_toast("清除：可以清空当前尝试，重新开始。")
	_update_tutorial_action_bar()


func _use_tutorial_hint() -> void:
	if tutorial_step_index != 3:
		_show_toast("提示会在第 4 个教程关中演示")
		return
	if tutorial_button_stage != 2:
		_show_toast("先学习撤销和清除，再使用提示")
		return
	var target := _tutorial_target()
	board.set_guides({
		Vector2i(0, 0): "unit",
		Vector2i(1, 0): "exclude",
		target: "place",
		Vector2i(3, 0): "candidate"
	})
	board.play_guide_feedback(target.y, target.x)
	coach_label.text = "提示会标出观察范围和候选格，但不会替你放皇冠。正式关卡中，当每行、每列、每个颜色区域都有一个皇冠，且皇冠互不相邻时就会通关。"
	coach_label.add_theme_color_override("font_color", Color("#23845C"))
	tutorial_button_stage = 3
	_update_tutorial_action_bar()
	if progress_bar:
		progress_bar.value = 1
	if progress_label:
		progress_label.text = "1 / 1"
	_complete_tutorial_step("你学会了使用提示，也知道了通关目标。")


func _complete_tutorial_step(message: String) -> void:
	is_completed = true
	board.play_victory()
	_save_game()
	_show_toast("%s 完成：%s" % [str(current_level["title"]), message])
	await get_tree().create_timer(2.0).timeout
	if in_tutorial and is_completed:
		_next_tutorial_step()


func _next_tutorial_step() -> void:
	if tutorial_step_index >= TUTORIAL_LEVELS.size() - 1:
		_finish_tutorial(false)
	else:
		_start_tutorial_step(tutorial_step_index + 1)


func _request_skip_tutorial() -> void:
	if in_tutorial:
		tutorial_skip_dialog.popup_centered(Vector2i(420, 220))


func _on_tutorial_button_pressed() -> void:
	if in_tutorial:
		_request_skip_tutorial()
	else:
		_start_tutorial_step(0)


func _finish_tutorial(skipped: bool) -> void:
	tutorial_completed = true
	tutorial_started = false
	in_tutorial = false
	tutorial_step_index = 0
	tutorial_button_stage = 0
	_load_level(0)
	_show_game()
	_save_game()
	_show_toast("已跳过教程，进入第 1 关" if skipped else "新手教程完成，进入第 1 关")


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
	_update_home()
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
	if in_tutorial:
		_next_tutorial_step()
		return
	var next_index := current_level_index + 1
	if next_index >= levels.size():
		next_index = 0
	_load_level(next_index)
	if next_index == 0:
		_show_toast("全部体验关卡完成，已回到第一关")


func _replay_level() -> void:
	if in_tutorial:
		_start_tutorial_step(tutorial_step_index)
		return
	_load_level(current_level_index)


func _on_coin_plus() -> void:
	coin_count += 10
	_update_coin_label()
	_update_home()
	_save_game()
	_show_toast("演示奖励：金币 +10")


func _on_settings() -> void:
	immediate_errors = not immediate_errors
	_validate_and_update(false)
	_show_toast("即时纠错：%s" % ("开启" if immediate_errors else "关闭"))


func _on_help() -> void:
	help_dialog.popup_centered(Vector2i(450, 360))


func _open_level_editor() -> void:
	get_tree().change_scene_to_file("res://scenes/level_editor.tscn")


func _on_level_selected(index: int) -> void:
	if index == current_level_index:
		return
	_load_level(index)
	_show_game()
	_save_game()
	_show_toast("已切换到关卡 %d" % int(current_level["levelId"]))


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
	if int(data.get("saveVersion", 1)) >= SAVE_VERSION:
		hint_count = maxi(0, int(data.get("hintCount", INITIAL_HINT_COUNT)))
	else:
		# Version 1 stored the number of hints used, not the remaining count.
		hint_count = INITIAL_HINT_COUNT
	completed_levels.assign(data.get("completedLevels", []))
	for index in range(completed_levels.size()):
		completed_levels[index] = int(completed_levels[index])
	resume_level_id = int(data.get("currentLevelId", -1))
	resume_states = data.get("cellStates", [])
	resume_completed = bool(data.get("isCompleted", false))
	immediate_errors = bool(data.get("immediateErrors", true))
	tutorial_completed = bool(data.get("tutorialCompleted", false))
	tutorial_started = bool(data.get("tutorialStarted", false))
	tutorial_step_index = clampi(int(data.get("tutorialStepIndex", 0)), 0, TUTORIAL_LEVELS.size() - 1)


func _save_game() -> void:
	if current_level.is_empty():
		return
	var data := {
		"saveVersion": SAVE_VERSION,
		"currentLevelIndex": current_level_index,
		"currentLevelId": int(current_level["levelId"]),
		"coinCount": coin_count,
		"completedLevels": completed_levels,
		"selectedTheme": "crown",
		"hintCount": hint_count,
		"immediateErrors": immediate_errors,
		"isCompleted": is_completed,
		"cellStates": cell_states,
		"tutorialCompleted": tutorial_completed,
		"tutorialStarted": tutorial_started,
		"tutorialStepIndex": tutorial_step_index
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func _update_coin_label() -> void:
	if coin_label:
		coin_label.text = "●  %d" % coin_count
	if home_coin_label:
		home_coin_label.text = "●  %d" % coin_count


func _update_hint_button() -> void:
	if not hint_button:
		return
	if in_tutorial:
		hint_button.text = "✦  提示"
		return
	if hint_count > 0:
		hint_button.text = "✦  提示  ×%d" % hint_count
	else:
		hint_button.text = "✦  提示  -%d" % HINT_COST


func _update_level_picker() -> void:
	if level_picker and level_picker.selected != current_level_index:
		level_picker.select(current_level_index)


func _show_home() -> void:
	if home_screen:
		home_screen.show()
	if game_screen:
		game_screen.hide()
	if completion_overlay:
		completion_overlay.hide()
	_update_home()


func _start_current_flow() -> void:
	if tutorial_completed:
		_show_game()
	elif tutorial_started:
		tutorial_resume_dialog.popup_centered(Vector2i(420, 220))
	else:
		_start_tutorial_step(0)


func _simulate_new_user_flow() -> void:
	tutorial_completed = false
	tutorial_started = false
	tutorial_step_index = 0
	tutorial_interaction_stage = 0
	current_level_index = 0
	resume_level_id = -1
	resume_states = []
	resume_completed = false
	completion_overlay.hide()
	_start_tutorial_step(0)
	_show_toast("已进入新人流程")


func _show_game() -> void:
	if home_screen:
		home_screen.hide()
	if game_screen:
		game_screen.show()
	_update_tutorial_button()
	if board:
		board.queue_redraw()


func _update_tutorial_button() -> void:
	if not tutorial_skip_button:
		return
	if in_tutorial:
		tutorial_skip_button.text = "跳"
		tutorial_skip_button.tooltip_text = "跳过新手教程"
		tutorial_skip_button.show()
	else:
		tutorial_skip_button.hide()


func _update_home() -> void:
	if not home_screen or levels.is_empty():
		return
	var level_id := int(levels[current_level_index]["levelId"])
	var area_index := int(current_level_index / 10) + 1
	var area_start := (area_index - 1) * 10
	var area_end := mini(area_start + 10, levels.size())
	var area_completed := 0
	for index in range(area_start, area_end):
		if completed_levels.has(int(levels[index]["levelId"])):
			area_completed += 1

	if home_coin_label:
		home_coin_label.text = "●  %d" % coin_count
	if home_heart_label:
		home_heart_label.text = "♥  3"
	if home_star_label:
		home_star_label.text = "★  %d" % completed_levels.size()
	if home_level_label:
		home_level_label.text = "下一关：%d" % level_id
	if home_area_label:
		home_area_label.text = "第 %d 庭院 · 已修复 %d / %d" % [area_index, area_completed, area_end - area_start]
	if home_progress_bar:
		home_progress_bar.max_value = area_end - area_start
		home_progress_bar.value = area_completed
	if home_progress_label:
		home_progress_label.text = "%d / %d" % [area_completed, area_end - area_start]
	if home_start_button:
		if tutorial_completed:
			home_start_button.text = "开始第 %d 关" % level_id
		elif tutorial_started:
			home_start_button.text = "继续新手教程"
		else:
			home_start_button.text = "开始新手教程"


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


func _resource_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(88, 42)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_stylebox_override("normal", _card_style(CARD, 18, true, 8))
	return label


func _floating_home_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(52, 52)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_stylebox_override("normal", _card_style(Color("#FFFFFF"), 18, true))
	button.add_theme_stylebox_override("hover", _card_style(Color("#F5F8FC"), 18, true))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#DFE8F2"), 18))
	return button


func _royal_home_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.24))
	button.add_theme_constant_override("shadow_offset_y", 3)
	button.add_theme_stylebox_override("normal", _card_style(color, 22, true))
	button.add_theme_stylebox_override("hover", _card_style(color.lightened(0.08), 22, true))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.08), 22))
	return button


func _nav_button(icon: String, label_text: String) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [icon, label_text]
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#DCEBFF"))
	button.add_theme_stylebox_override("normal", _button_style(Color("#2189E6"), 12))
	button.add_theme_stylebox_override("hover", _button_style(Color("#3297F0"), 12))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#1069B7"), 12))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#0F63B1"), 12))
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
