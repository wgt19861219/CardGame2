extends GutTest
# 活动列表面板测试 — 照源 ui/activitiesList.lua（标题/节标题/行 fill）+ 两件套范式守卫。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_panel() -> ActivitiesListPanel:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	var panel := ActivitiesListPanel.new("activities_list", {})
	panel.setup_panel(pd)
	panel.show_window(root)
	return panel


func test_content_scene_chrome() -> void:
	var inst := (preload("res://scenes/ui/activities_list_content.tscn") as PackedScene).instantiate() as Control
	add_child(inst)
	assert_ne(inst.get_node("%CloseBtn"), null, "关闭按钮唯一名存在")
	assert_ne(inst.get_node("%ListScroll"), null, "滚动列表唯一名存在")
	assert_ne(inst.get_node("%ListHost"), null, "行宿主唯一名存在")
	assert_ne(inst.get_node("%TitleLabel"), null, "标题唯一名存在")
	var frame: Rect2 = (inst.get_node("Frame") as Control).get_rect()
	assert_almost_eq(frame.get_center().x, 400.0, 0.5, "框中心 x=400（源 ccp(400,200)）")
	assert_almost_eq(frame.get_center().y, 280.0, 0.5, "框中心 y=280（480-200）")
	assert_almost_eq(frame.size.x, 540.0, 0.5, "框宽 540（源 scaleSize）")
	assert_almost_eq(frame.size.y, 300.0, 0.5, "框高 300")
	inst.queue_free()


func test_panel_fills_announcement() -> void:
	var panel := _make_panel()
	var title: String = (panel._content.get_node("%TitleLabel") as Label).text
	assert_eq(title, "精彩活动", "标题照源 LSTR")
	var host := panel._content.get_node("%ListHost") as VBoxContainer
	assert_eq(host.get_children().size(), 2, "节标题 + 1 条公告行（玩法活动临时下线，2026-10-13）")
	var section := host.get_child(0) as Label
	assert_eq(section.text, "进行中", "节标题=进行中")
	var row := host.get_child(1)
	assert_eq(String((row.get_node("%NameLabel") as Label).text), "公告:", "公告行标题")
	assert_eq(String((row.get_node("%DescLabel") as Label).text),
			String(cm.get_raw_table(&"ActivitiesConfig").get("announcement", {}).get("desc", "")),
			"公告行描述（2026-10-13 实际公告文案，与 loading 启动公告同源对照）")
	panel.remove_window()
	panel.get_parent().queue_free()


func test_item_scene_row_size() -> void:
	var inst := (preload("res://scenes/ui/activities_list_item.tscn") as PackedScene).instantiate() as Control
	add_child(inst)
	assert_almost_eq(inst.custom_minimum_size.x, 490.0, 0.5, "行宽 490（源 itemConfig1 bg1 scaleSize）")
	assert_almost_eq(inst.custom_minimum_size.y, 50.0, 0.5, "行高 50")
	inst.queue_free()
