class_name LevelStore
extends RefCounted

const LEVELS_PATH := "res://data/levels.json"


static func load_levels() -> Array:
	if not FileAccess.file_exists(LEVELS_PATH):
		push_error("Level data not found: %s" % LEVELS_PATH)
		return []

	var file := FileAccess.open(LEVELS_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("levels"):
		push_error("Invalid level JSON")
		return []

	var result: Array = parsed["levels"]
	for level in result:
		_normalize_level(level)
		_validate_level(level)
	return result


static func _normalize_level(level: Dictionary) -> void:
	var rows := int(level.get("rows", 0))
	var cols := int(level.get("cols", rows))
	if not level.has("cols") and rows > 0:
		level["cols"] = rows
	if not level.has("targetCount"):
		level["targetCount"] = level.get("solution", []).size()
	if not level.has("name") or str(level.get("name", "")).strip_edges() == "":
		var size_text := "%dx%d" % [rows, cols]
		var difficulty := str(level.get("difficulty", "")).capitalize()
		level["name"] = "%s %s" % [difficulty, size_text] if difficulty != "" else size_text
	if not level.has("tutorial") or str(level.get("tutorial", "")).strip_edges() == "":
		level["tutorial"] = "放置全部皇冠，满足行、列、颜色区域和相邻规则。"
	if not level.has("difficulty") or str(level.get("difficulty", "")).strip_edges() == "":
		level["difficulty"] = "normal"


static func _validate_level(level: Dictionary) -> void:
	var rows := int(level.get("rows", 0))
	var cols := int(level.get("cols", 0))
	var regions: Array = level.get("regions", [])
	assert(rows > 0 and cols > 0, "Level dimensions must be positive")
	assert(regions.size() == rows, "Region row count does not match level")
	for row in regions:
		assert(row.size() == cols, "Region column count does not match level")
	assert(level.get("solution", []).size() == int(level.get("targetCount", 0)), "Solution size does not match target")
