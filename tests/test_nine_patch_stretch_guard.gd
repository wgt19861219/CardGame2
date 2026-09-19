extends GutTest

## 全项目 NinePatchRect 拉伸模式守卫（2026-09-18 三轮）。
## TILE/TILE_FIT 平铺在 tile 边界产生采样接缝暗线（main_vit_tips.png 实测 4 条
## 1px 级全宽暗线）；项目内九宫格中间区均为纯色，平铺与拉伸观感一致但平铺零收益
## 纯劣势，统一引擎默认 STRETCH（对齐源 Axmol Scale9Sprite 默认拉伸）。
## 三案驱动：setup_panel（二轮）/ configure_content.tscn / save_manager 双处（三轮）。

const TSCN_ROOT: String = "res://scenes"
const GD_ROOT: String = "res://scripts"


func test_tscn_no_tiling_axis_stretch() -> void:
	var offenders: Array = []
	_scan_tscn(TSCN_ROOT, offenders)
	assert_eq(offenders.size(), 0, "tscn 禁 TILE/TILE_FIT（axis_stretch 非 0 行）：" + str(offenders))


func test_gd_no_tiling_axis_stretch() -> void:
	var offenders: Array = []
	_scan_gd(GD_ROOT, offenders)
	assert_eq(offenders.size(), 0, "gd 禁 AXIS_STRETCH_MODE_TILE* 赋值行：" + str(offenders))


func _scan_tscn(dir_path: String, offenders: Array) -> void:
	for name: String in DirAccess.get_directories_at(dir_path):
		if not name.begins_with("."):
			_scan_tscn(dir_path + "/" + name, offenders)
	for name: String in DirAccess.get_files_at(dir_path):
		if name.ends_with(".tscn"):
			_check_tscn_file(dir_path + "/" + name, offenders)


func _check_tscn_file(path: String, offenders: Array) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return
	for line: String in text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with(";"):
			continue
		if "axis_stretch" in trimmed and not trimmed.ends_with("= 0"):
			offenders.append("%s: %s" % [path, trimmed])


func _scan_gd(dir_path: String, offenders: Array) -> void:
	for name: String in DirAccess.get_directories_at(dir_path):
		if not name.begins_with("."):
			_scan_gd(dir_path + "/" + name, offenders)
	for name: String in DirAccess.get_files_at(dir_path):
		if name.ends_with(".gd"):
			_check_gd_file(dir_path + "/" + name, offenders)


func _check_gd_file(path: String, offenders: Array) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return
	for line: String in text.split("\n"):
		var trimmed := line.strip_edges()
		# 只拦赋值行；注释（判例说明）不误伤。
		if trimmed.begins_with("#"):
			continue
		if "AXIS_STRETCH_MODE_TILE" in trimmed and "=" in trimmed:
			offenders.append("%s: %s" % [path, trimmed])
