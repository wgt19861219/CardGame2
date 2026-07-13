extends GutTest
# Phase 6 equipdetail 弹窗测试（2026-07-05 第 26 段）。
# 照源 equipdetail.lua frame + 3 段滚动。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _find_equip_with_drop() -> int:
	var raw: Dictionary = cm.get_raw_table(&"Equip")
	for tid_str in raw:
		if int(raw[tid_str].get("Drop 1", 0)) > 0:
			return int(tid_str)
	return 0


func test_setup_builds_frame() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := EquipdetailPanel.new("equipdetail", {})
	panel.setup_panel(_find_equip_with_drop(), cm, pd)
	panel.show_window(root)
	assert_gt(panel.container.get_child_count(), 0, "frame 已建（container 有子）")
	panel.remove_window()
	root.queue_free()


func test_close_removes_window() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := EquipdetailPanel.new("equipdetail", {})
	panel.setup_panel(_find_equip_with_drop(), cm, pd)
	panel.show_window(root)
	panel._on_close_pressed()
	await get_tree().process_frame
	assert_false(is_instance_valid(panel), "close 后 panel 销毁")
	if is_instance_valid(root):
		root.queue_free()


# EquipboardPanel prop 右按钮 → 弹 EquipdetailPanel（第 26 段接 check）。
func test_equipboard_prop_opens_detail() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_with_drop()
	var cell: Dictionary = {"id": eid, "makeId": eid, "amount": 1, "category": "EQUIP.PARTS", "type": 1}
	var board := EquipboardPanel.new("equipboard", {})
	board.setup_panel(cell, cm, pd)
	board.show_window(root)
	board._on_right_pressed()   # prop → _open_detail
	var has_detail: bool = false
	for c in root.get_children():
		if c is EquipdetailPanel:
			has_detail = true
			c.queue_free()
			break
	assert_true(has_detail, "EquipboardPanel prop 右按钮弹 EquipdetailPanel")
	board.remove_window()
	root.queue_free()


# P1-12：panel_bg Scale9 贴图装配（equip_detail_panel_bg.png，替 Panel 降级）。
func test_panel_bg_texture_assembled() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := EquipdetailPanel.new("equipdetail", {})
	panel.setup_panel(_find_equip_with_drop(), cm, pd)
	panel.show_window(root)
	var nps: Array = panel.find_children("*", "NinePatchRect", true, false)
	assert_gt(nps.size(), 0, "panel_bg NinePatchRect 装配（替 Panel）")
	var found: bool = false
	for np in nps:
		var t: NinePatchRect = np
		if t.texture != null and String(t.texture.resource_path).find("equip_detail_panel_bg") >= 0:
			found = true
			break
	assert_true(found, "panel_bg 贴图 equip_detail_panel_bg")
	panel.remove_window()
	root.queue_free()


# P1-12：获取途径关卡图标装配（key_stages/stage-N.png，源 :256 createSprite(way.res)）。
func test_get_way_stage_icon_assembled() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_with_drop()
	var panel := EquipdetailPanel.new("equipdetail", {})
	panel.setup_panel(eid, cm, pd)
	panel.show_window(root)
	var query_data: Dictionary = EquipdetailQuery.query(eid, cm, pd)
	var get_way: Array = query_data["get_way"]
	if get_way.size() > 0:
		var first_res: String = String((get_way[0] as Dictionary).get("res", ""))
		assert_true(_has_tex(panel, first_res), "获取途径关卡图标装配（key_stages/stage-N）")
	else:
		assert_true(true, "该装备无 get_way，跳过")
	panel.remove_window()
	root.queue_free()


# 递归查 TextureRect by resource_path。
func _has_tex(node: Node, path: String) -> bool:
	if node is TextureRect and node.texture != null and node.texture.resource_path == path:
		return true
	for c in node.get_children():
		if _has_tex(c, path):
			return true
	return false
