class_name GameBoard
extends Control

signal cell_pressed(row: int, col: int)
signal cell_double_pressed(row: int, col: int)
signal cell_drag_started(row: int, col: int)
signal cell_dragged(row: int, col: int)
signal cell_drag_ended()

const BOARD_INK := Color("#26334A")
const EMPTY_MARK := "empty"
const PIECE_MARK := "piece"
const BLOCKED_MARK := "blocked"
const HINT_MARK := "hint"
const WRONG_MARK := "wrong"

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
var press_cell := Vector2i(-1, -1)
var last_drag_cell := Vector2i(-1, -1)
var tracking_press := false
var dragging := false



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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_pointer(event.position, event.double_click)
		else:
			_finish_pointer(event.position)
		accept_event()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_start_pointer(event.position, event.double_tap)
		else:
			_finish_pointer(event.position)
		accept_event()
		return
	if event is InputEventMouseMotion and tracking_press and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_update_drag(event.position)
		accept_event()
		return
	if event is InputEventScreenDrag and tracking_press:
		_update_drag(event.position)
		accept_event()


func _start_pointer(position: Vector2, is_double: bool) -> void:
	var cell := _cell_at_position(position)
	if cell.x < 0:
		_reset_pointer()
		return
	if is_double:
		_reset_pointer()
		cell_double_pressed.emit(cell.y, cell.x)
		return
	tracking_press = true
	dragging = false
	press_cell = cell
	last_drag_cell = cell


func _finish_pointer(position: Vector2) -> void:
	if not tracking_press:
		_reset_pointer()
		return
	if dragging:
		cell_drag_ended.emit()
	else:
		var cell := _cell_at_position(position)
		if cell == press_cell:
			cell_pressed.emit(cell.y, cell.x)
	_reset_pointer()


func _update_drag(position: Vector2) -> void:
	var cell := _cell_at_position(position)
	if cell.x < 0 or cell == last_drag_cell:
		return
	if not dragging:
		dragging = true
		cell_drag_started.emit(press_cell.y, press_cell.x)
	last_drag_cell = cell
	cell_dragged.emit(cell.y, cell.x)


func _reset_pointer() -> void:
	tracking_press = false
	dragging = false
	press_cell = Vector2i(-1, -1)
	last_drag_cell = Vector2i(-1, -1)


func _cell_at_position(position: Vector2) -> Vector2i:
	var geometry := _board_geometry()
	var board_rect: Rect2 = geometry["rect"]
	if not board_rect.has_point(position):
		return Vector2i(-1, -1)
	var cell_size: float = geometry["cell_size"]
	var col := int((position.x - board_rect.position.x) / cell_size)
	var row := int((position.y - board_rect.position.y) / cell_size)
	if row >= 0 and row < rows and col >= 0 and col < cols:
		return Vector2i(col, row)
	return Vector2i(-1, -1)

func _draw() -> void:
	if regions.is_empty() or cell_states.is_empty():
		return

	var geometry := _board_geometry()
	var board_rect: Rect2 = geometry["rect"]
	var cell_size: float = geometry["cell_size"]
	var outer := StyleBoxFlat.new()
	outer.bg_color = BOARD_INK.lerp(Color.WHITE, victory_strength * 0.32)
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
			color = color.lerp(Color("#CDE8FF"), 0.42)
		elif guide_kind == "line":
			color = color.lerp(Color("#E0F0FF"), 0.34)
		elif guide_kind == "candidate":
			color = color.lerp(Color("#D9F8DF"), 0.44)
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
			box.border_color = Color("#23845C")
		elif guide_kind == "exclude" or guide_kind == "exclude_empty":
			box.border_color = Color("#D98A24")
		elif guide_kind == "candidate":
			box.border_color = Color("#48B985")
		elif guide_kind == "line":
			box.border_color = Color("#86BDEB")
		else:
			box.border_color = Color("#3C8DDE")
		box.set_border_width_all(maxi(3, int(cell_size * (0.055 + guide_pulse_strength * 0.035))))
	draw_style_box(box, rect)

	var state: String = cell_states[row][col]
	if state == PIECE_MARK or state == HINT_MARK:
		_draw_piece(rect, cell_size, state == HINT_MARK)
	elif state == BLOCKED_MARK:
		_draw_blocked(rect, cell_size)
	elif state == WRONG_MARK:
		_draw_wrong(rect, cell_size)

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
	draw_string(font, Vector2(rect.position.x, baseline), piece_symbol, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, Color("#26334A"))


func _draw_blocked(rect: Rect2, cell_size: float) -> void:
	var center := rect.get_center()
	var radius := cell_size * 0.14
	var color := Color(0.20, 0.26, 0.35, 0.5)
	var width := maxf(2.0, cell_size * 0.035)
	draw_line(center - Vector2(radius, radius), center + Vector2(radius, radius), color, width, true)
	draw_line(center + Vector2(radius, -radius), center + Vector2(-radius, radius), color, width, true)


func _draw_wrong(rect: Rect2, cell_size: float) -> void:
	var center := rect.get_center()
	var radius := cell_size * 0.20
	var color := Color("#D92F42")
	var width := maxf(3.0, cell_size * 0.055)
	draw_line(center - Vector2(radius, radius), center + Vector2(radius, radius), color, width, true)
	draw_line(center + Vector2(radius, -radius), center + Vector2(-radius, radius), color, width, true)
	draw_circle(center, cell_size * 0.31, Color(1.0, 0.12, 0.18, 0.12))


func _board_geometry() -> Dictionary:
	var usable_size := Vector2(maxf(1.0, size.x - 18.0), maxf(1.0, size.y - 18.0))
	var board_size := minf(usable_size.x, usable_size.y)
	var cell_size := board_size / float(maxi(rows, cols))
	var actual_size := Vector2(cols * cell_size, rows * cell_size)
	var board_position := (size - actual_size) * 0.5
	return {"rect": Rect2(board_position, actual_size), "cell_size": cell_size}
