class_name GameBoard
extends Control

signal cell_pressed(row: int, col: int)
signal cell_double_pressed(row: int, col: int)
signal cell_dragged(row: int, col: int)

const BOARD_INK := Color("#31506D")
const BOARD_FRAME := Color("#F8FCFF")
const EMPTY_MARK := "empty"
const PIECE_MARK := "piece"
const BLOCKED_MARK := "blocked"
const HINT_MARK := "hint"

var rows := 6
var cols := 6
var regions: Array = []
var cell_states: Array = []
var error_cells: Dictionary = {}
var guide_cells: Dictionary = {}
var region_colors: Array = []
var piece_symbol := "♛"
var pulse_cell := Vector2i(-1, -1)
var pulse_strength := 0.0
var guide_pulse_cell := Vector2i(-1, -1)
var guide_pulse_cells: Dictionary = {}
var guide_pulse_strength := 0.0
var victory_strength := 0.0
var tutorial_mask_enabled := false
var tutorial_focus_cell := Vector2i(-1, -1)
var last_drag_cell := Vector2i(-1, -1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(300, 300)
	resized.connect(queue_redraw)


func set_level(level: Dictionary, states: Array, colors: Array) -> void:
	rows = int(level["rows"])
	cols = int(level["cols"])
	regions = level["regions"]
	cell_states = states
	region_colors = colors
	error_cells.clear()
	guide_cells.clear()
	tutorial_mask_enabled = false
	tutorial_focus_cell = Vector2i(-1, -1)
	victory_strength = 0.0
	queue_redraw()


func set_states(states: Array) -> void:
	cell_states = states
	queue_redraw()


func set_errors(errors: Dictionary) -> void:
	error_cells = errors
	queue_redraw()


func set_guides(guides: Dictionary) -> void:
	guide_cells = guides
	queue_redraw()


func set_tutorial_focus(cell: Vector2i, enabled: bool) -> void:
	tutorial_focus_cell = cell if enabled else Vector2i(-1, -1)
	tutorial_mask_enabled = enabled and cell.x >= 0 and cell.y >= 0
	queue_redraw()


func play_cell_feedback(row: int, col: int) -> void:
	pulse_cell = Vector2i(col, row)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_pulse, 0.0, 1.0, 0.09)
	tween.tween_method(_set_pulse, 1.0, 0.0, 0.18)


func play_guide_feedback(row: int, col: int) -> void:
	guide_pulse_cell = Vector2i(col, row)
	guide_pulse_cells = {guide_pulse_cell: true}
	_play_guide_feedback_tween()


func play_guide_feedback_for_cells(cells: Array) -> void:
	guide_pulse_cells.clear()
	if cells.is_empty():
		return
	guide_pulse_cell = cells[0]
	for cell in cells:
		guide_pulse_cells[cell] = true
	_play_guide_feedback_tween()


func _play_guide_feedback_tween() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_guide_pulse, 0.0, 1.0, 0.22)
	tween.tween_method(_set_guide_pulse, 1.0, 0.18, 0.30)
	tween.tween_method(_set_guide_pulse, 0.18, 1.0, 0.22)
	tween.tween_method(_set_guide_pulse, 1.0, 0.0, 0.36)


func play_victory() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_method(_set_victory, 0.0, 1.0, 0.24)
	tween.tween_method(_set_victory, 1.0, 0.0, 0.34)


func _set_pulse(value: float) -> void:
	pulse_strength = value
	queue_redraw()


func _set_guide_pulse(value: float) -> void:
	guide_pulse_strength = value
	queue_redraw()


func _set_victory(value: float) -> void:
	victory_strength = value
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click_position := Vector2(-1, -1)
	var is_double_click := false
	var is_drag := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		click_position = event.position
		is_double_click = event.double_click
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		last_drag_cell = Vector2i(-1, -1)
		return
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		click_position = event.position
		is_drag = true
	elif event is InputEventScreenTouch and event.pressed:
		click_position = event.position
		is_double_click = event.double_tap
	elif event is InputEventScreenTouch and not event.pressed:
		last_drag_cell = Vector2i(-1, -1)
		return
	elif event is InputEventScreenDrag:
		click_position = event.position
		is_drag = true
	else:
		return

	var geometry := _board_geometry()
	var board_rect: Rect2 = geometry["rect"]
	if not board_rect.has_point(click_position):
		return
	var cell_size: float = geometry["cell_size"]
	var col := int((click_position.x - board_rect.position.x) / cell_size)
	var row := int((click_position.y - board_rect.position.y) / cell_size)
	if row >= 0 and row < rows and col >= 0 and col < cols:
		var cell := Vector2i(col, row)
		if is_drag:
			if cell != last_drag_cell:
				last_drag_cell = cell
				cell_dragged.emit(row, col)
		elif is_double_click:
			cell_double_pressed.emit(row, col)
		else:
			last_drag_cell = cell
			cell_pressed.emit(row, col)
		accept_event()


func _draw() -> void:
	if regions.is_empty() or cell_states.is_empty():
		return

	var geometry := _board_geometry()
	var board_rect: Rect2 = geometry["rect"]
	var cell_size: float = geometry["cell_size"]
	var outer := StyleBoxFlat.new()
	outer.bg_color = BOARD_FRAME.lerp(Color.WHITE, victory_strength * 0.32)
	outer.corner_radius_top_left = 22
	outer.corner_radius_top_right = 22
	outer.corner_radius_bottom_left = 22
	outer.corner_radius_bottom_right = 22
	draw_style_box(outer, board_rect.grow(7.0))

	for row in range(rows):
		for col in range(cols):
			_draw_cell(row, col, board_rect.position, cell_size)


func _draw_cell(row: int, col: int, origin: Vector2, cell_size: float) -> void:
	var gap := maxf(3.0, cell_size * 0.045)
	var rect := Rect2(origin + Vector2(col, row) * cell_size + Vector2.ONE * gap, Vector2.ONE * (cell_size - gap * 2.0))
	var cell_key := Vector2i(col, row)
	if cell_key == pulse_cell:
		rect = rect.grow(cell_size * 0.045 * pulse_strength)
	if guide_pulse_cells.has(cell_key) or cell_key == guide_pulse_cell:
		rect = rect.grow(cell_size * 0.07 * guide_pulse_strength)

	var region_id := int(regions[row][col]) - 1
	var color: Color = region_colors[region_id % region_colors.size()]
	if error_cells.has(cell_key):
		color = color.lerp(Color("#FF5E67"), 0.58)
	elif guide_cells.has(cell_key):
		var guide_kind := _guide_kind(cell_key)
		if guide_kind == "unit":
			color = color.lerp(Color("#DDF3FF"), 0.44)
		elif guide_kind == "line":
			color = color.lerp(Color("#ECF8FF"), 0.38)
		elif guide_kind == "candidate":
			color = color.lerp(Color("#E7FCEB"), 0.48)
		else:
			color = color.lerp(Color.WHITE, 0.38)
	elif victory_strength > 0.0:
		color = color.lerp(Color.WHITE, victory_strength * 0.32)

	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = int(cell_size * 0.14)
	box.corner_radius_top_right = int(cell_size * 0.14)
	box.corner_radius_bottom_left = int(cell_size * 0.14)
	box.corner_radius_bottom_right = int(cell_size * 0.14)
	if error_cells.has(cell_key):
		box.border_color = Color("#D92F42")
		box.set_border_width_all(maxi(2, int(cell_size * 0.04)))
	elif guide_cells.has(cell_key):
		var guide_kind := _guide_kind(cell_key)
		if guide_kind == "place":
			box.border_color = Color("#2D9E63")
		elif guide_kind == "exclude" or guide_kind == "exclude_empty":
			box.border_color = Color("#F2A43A")
		elif guide_kind == "candidate":
			box.border_color = Color("#5ED982")
		elif guide_kind == "line":
			box.border_color = Color("#9CD5FF")
		else:
			box.border_color = Color("#5CACF2")
		box.set_border_width_all(maxi(3, int(cell_size * (0.055 + guide_pulse_strength * 0.035))))
	draw_style_box(box, rect)

	var state: String = cell_states[row][col]
	if state == PIECE_MARK or state == HINT_MARK:
		_draw_piece(rect, cell_size, state == HINT_MARK)
	elif state == BLOCKED_MARK:
		_draw_blocked(rect, cell_size)

	if guide_cells.has(cell_key) and _guide_kind(cell_key) == "exclude":
		_draw_blocked(rect.grow(-cell_size * 0.08), cell_size)

	if tutorial_mask_enabled:
		if cell_key == tutorial_focus_cell:
			var focus_box := StyleBoxFlat.new()
			focus_box.bg_color = Color(1.0, 1.0, 1.0, 0.0)
			focus_box.border_color = Color("#FFE06F")
			focus_box.set_border_width_all(maxi(4, int(cell_size * (0.065 + guide_pulse_strength * 0.04))))
			focus_box.corner_radius_top_left = int(cell_size * 0.16)
			focus_box.corner_radius_top_right = int(cell_size * 0.16)
			focus_box.corner_radius_bottom_left = int(cell_size * 0.16)
			focus_box.corner_radius_bottom_right = int(cell_size * 0.16)
			draw_style_box(focus_box, rect.grow(cell_size * 0.035))
		elif not guide_cells.has(cell_key):
			var mask_box := StyleBoxFlat.new()
			mask_box.bg_color = Color(0.10, 0.20, 0.30, 0.34)
			mask_box.corner_radius_top_left = int(cell_size * 0.14)
			mask_box.corner_radius_top_right = int(cell_size * 0.14)
			mask_box.corner_radius_bottom_left = int(cell_size * 0.14)
			mask_box.corner_radius_bottom_right = int(cell_size * 0.14)
			draw_style_box(mask_box, rect)


func _guide_kind(cell_key: Vector2i) -> String:
	var value = guide_cells.get(cell_key, "place")
	return str(value)


func _draw_piece(rect: Rect2, cell_size: float, is_hint: bool) -> void:
	if is_hint:
		draw_circle(rect.get_center(), cell_size * 0.35, Color(1.0, 0.84, 0.35, 0.34))
	var font := ThemeDB.fallback_font
	var font_size := int(cell_size * (0.55 + pulse_strength * 0.05))
	var baseline := rect.position.y + rect.size.y * 0.69
	draw_string(font, Vector2(rect.position.x, baseline), piece_symbol, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, BOARD_INK)


func _draw_blocked(rect: Rect2, cell_size: float) -> void:
	var center := rect.get_center()
	var radius := cell_size * 0.14
	var color := Color(0.25, 0.36, 0.47, 0.48)
	var width := maxf(2.0, cell_size * 0.035)
	draw_line(center - Vector2(radius, radius), center + Vector2(radius, radius), color, width, true)
	draw_line(center + Vector2(radius, -radius), center + Vector2(-radius, radius), color, width, true)


func _board_geometry() -> Dictionary:
	var usable_size := Vector2(maxf(1.0, size.x - 18.0), maxf(1.0, size.y - 18.0))
	var board_size := minf(usable_size.x, usable_size.y)
	var cell_size := board_size / float(maxi(rows, cols))
	var actual_size := Vector2(cols * cell_size, rows * cell_size)
	var board_position := (size - actual_size) * 0.5
	return {"rect": Rect2(board_position, actual_size), "cell_size": cell_size}
