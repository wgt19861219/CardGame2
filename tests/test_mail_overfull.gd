extends GutTest

## MailOverfullPopup 验证（P1-4：照源 overfull.lua 溢满弹窗替 Toast 降级）。


# frame（common_alert_bg）+ 2 按钮（强行领取/稍后领取）装配。
func test_popup_assembles_frame_and_buttons() -> void:
	var popup := MailOverfullPopup.new()
	popup.setup([{"id": 371, "amount": 5}], GameData.config)
	add_child(popup)
	await get_tree().process_frame   # 等 _ready → _build
	assert_true(_has_tex(popup, popup.FRAME_TEX), "frame 装配（common_alert_bg）")
	var btns: Array = popup.find_children("*", "TextureButton", true, false)
	assert_eq(btns.size(), 2, "2 按钮（强行领取+稍后领取）")
	popup.free()


# left_button「强行领取」→ emit confirmed（源 overfull.lua:10-16 leftCallback）。
func test_popup_confirmed_signal() -> void:
	var popup := MailOverfullPopup.new()
	popup.setup([{"id": 371, "amount": 5}], GameData.config)
	add_child(popup)
	await get_tree().process_frame
	var received: Array = []   # Array 引用类型避 GDScript lambda 捕获 bool 值副本坑
	popup.confirmed.connect(func() -> void: received.append(true))
	popup._on_left()
	assert_eq(received.size(), 1, "left 触发 confirmed signal")
	popup.free()


# 溢出物品 4 列网格（源 overfull.lua:68-70 4 列）。
func test_popup_grid_4_cols() -> void:
	var popup := MailOverfullPopup.new()
	popup.setup([{"id": 371, "amount": 5}, {"id": 372, "amount": 3}], GameData.config)
	add_child(popup)
	await get_tree().process_frame
	var grids: Array = popup.find_children("*", "GridContainer", true, false)
	assert_eq(grids.size(), 1, "1 个 GridContainer")
	var grid: GridContainer = grids[0]
	assert_eq(grid.columns, 4, "网格 4 列（源 :68-70）")
	assert_eq(grid.get_child_count(), 2, "2 溢出物品图标")
	popup.free()


# P1（2026-07-16）：UI 文案 LSTR 化验证（title/desc/按钮文本走 GameData.config.get_lstr）。
func test_popup_texts_use_lstr() -> void:
	var popup := MailOverfullPopup.new()
	popup.setup([{"id": 371, "amount": 5}], GameData.config)
	add_child(popup)
	await get_tree().process_frame
	var cfg: ConfigManager = GameData.config
	var texts: Array = []
	for l in popup.find_children("*", "Label", true, false):
		texts.append(String(l.text))
	assert_true(texts.has(cfg.get_lstr("mailoverfull.1.10.1.003")), "title 走 LSTR mailoverfull.1.10.1.003")
	assert_true(texts.has(cfg.get_lstr("overfull.1.10.1.001")), "desc1 走 LSTR overfull.1.10.1.001")
	assert_true(texts.has(cfg.get_lstr("overfull.1.10.1.002")), "desc2 走 LSTR overfull.1.10.1.002")
	assert_true(texts.has(cfg.get_lstr("overfull.1.10.1.003")), "desc3 走 LSTR overfull.1.10.1.003")
	assert_true(texts.has(cfg.get_lstr("mailoverfull.1.10.1.001")), "left 按钮 LSTR mailoverfull.1.10.1.001")
	assert_true(texts.has(cfg.get_lstr("mailoverfull.1.10.1.002")), "right 按钮 LSTR mailoverfull.1.10.1.002")
	popup.free()


func _has_tex(node: Node, path: String) -> bool:
	if node is TextureRect and node.texture != null and node.texture.resource_path == path:
		return true
	for c in node.get_children():
		if _has_tex(c, path):
			return true
	return false
