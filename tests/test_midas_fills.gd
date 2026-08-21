extends GutTest
## MidasFills 纯数据填充单测（批 2 Task 6，midas_renderer 改写为 fills 范式）。
## 历史行 = midas_history_item.tscn 行模板 + fill；确认弹窗 = 独立 tscn + fill。
## 替代原 test_midas_renderer.gd（坐标工具/静态建节点工厂消亡，用例迁移不缩水）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _resolver() -> Callable:
	return func(k: String) -> String: return String(cm.get_lstr(k))


func test_fill_history_empty() -> void:
	var host := VBoxContainer.new()
	add_child(host)
	MidasFills.fill_history_rows(null, host, [], _resolver())
	assert_eq(host.get_child_count(), 0, "空 history 不挂载")
	host.free()


func test_fill_history_mounts_rows() -> void:
	var host := VBoxContainer.new()
	add_child(host)
	var history: Array = [
		{"cost": 100, "acquire": 200, "ratio": 1},
		{"cost": 100, "acquire": 400, "ratio": 2},
		{"cost": 100, "acquire": 600, "ratio": 1},
	]
	MidasFills.fill_history_rows(null, host, history, _resolver())
	assert_eq(host.get_child_count(), 3, "3 行挂 3 行模板实例")
	host.free()


# 行模板静态结构（源 initHistoryItemHandler :425-545 直译）：
# 6 节点 HBox（USE/cost/token icon/GET/gold icon/acquire）+ RatioHost 固定位。
func test_row_template_static_rects() -> void:
	var inst: Control = load("res://scenes/ui/midas_history_item.tscn").instantiate() as Control
	add_child(inst)
	assert_almost_eq(inst.size.x, 340.0, 0.5, "行宽 = 源 itemSize DG(435)=339.8")
	assert_almost_eq(inst.size.y, 28.0, 0.5, "行高 = 源 itemSize DG(35)≈28")
	var bar: HBoxContainer = inst.get_node("Bar") as HBoxContainer
	assert_eq(bar.get_child_count(), 6, "行内 6 子节点（源 HorizontalNode 6 节点）")
	var token_icon: TextureRect = bar.get_node("TokenIcon") as TextureRect
	assert_almost_eq(token_icon.size.y, 23.44, 0.5, "token icon 高 = DGLen(30)=23.44（源 :494）")
	assert_almost_eq(token_icon.size.x / token_icon.size.y, 43.0 / 41.0, 0.05, "token icon 等比（43x41px）")
	var gold_icon: TextureRect = bar.get_node("GoldIcon") as TextureRect
	assert_almost_eq(gold_icon.size.y, 27.34, 0.5, "gold icon 高 = DGLen(35)=27.34（源 :515）")
	assert_almost_eq(gold_icon.size.x / gold_icon.size.y, 43.0 / 40.0, 0.05, "gold icon 等比（43x40px）")
	# ratio 图固定位：源 DGccp(330,13)=(257.8,10.16) anchor(0,0.5) 行内
	var ratio_host: Control = inst.get_node("RatioHost") as Control
	assert_almost_eq(ratio_host.position.x, 257.8, 0.5, "RatioHost x = DG(330)=257.8（源 :540）")
	assert_almost_eq(ratio_host.position.y + ratio_host.size.y * 0.5, 17.84, 0.6, "RatioHost 垂直中心 = 28-DG(13)")
	inst.free()


# fill 行内文本 + variation（源 :467-529：USE 黄/cost 蓝/GET 黄/acquire 橙）。
func test_row_labels_filled() -> void:
	var host := VBoxContainer.new()
	add_child(host)
	MidasFills.fill_history_rows(null, host, [{"cost": 10, "acquire": 5000, "ratio": 1}], _resolver())
	var row: Control = host.get_child(0) as Control
	var bar: HBoxContainer = row.get_node("Bar") as HBoxContainer
	var first: Label = bar.get_child(0) as Label
	assert_eq(first.text, String(cm.get_lstr("MIDAS.USE")), "行首 Label = MIDAS.USE（源 :469）")
	assert_true(first.theme_type_variation == &"MidasHistoryLabel", "行 label variation=MidasHistoryLabel")
	assert_eq((bar.get_node("CostLabel") as Label).text, "10", "cost fill")
	assert_eq((bar.get_node("GetLabel") as Label).text, String(cm.get_lstr("ADDEQUIP.GET")), "GET 文案 fill（源 :500）")
	assert_eq((bar.get_node("AcquireLabel") as Label).text, "5000", "acquire fill")
	host.free()


# ratio>=2 行补 ratio 标记（源 :532-544 ratio_res 图；项目资源缺 → Label 降级 ×N!）。
func test_row_ratio_label_fallback() -> void:
	var host := VBoxContainer.new()
	add_child(host)
	MidasFills.fill_history_rows(null, host, [{"cost": 10, "acquire": 10000, "ratio": 4}], _resolver())
	var row: Control = host.get_child(0) as Control
	var ratio_host: Control = row.get_node("RatioHost") as Control
	assert_eq(ratio_host.get_child_count(), 1, "ratio=4 补降级节点（源 :532-544）")
	var last: Label = ratio_host.get_child(0) as Label
	assert_eq(last.text, " ×10!!", "ratio=4 降级 Label ×10!!（RATIO_TEXT[4]）")
	host.free()


# ratio 图资源缺失是现实（assets midas/ 仅数字图）→ 降级路径必走 Label。
func test_row_ratio_image_missing_in_assets() -> void:
	assert_false(ResourceLoader.exists("res://assets/ui/alpha/HVGA/midas/midas_crip2.png"),
		"midas_crip2.png 资源缺（实况）→ fill 走 Label 降级")
	assert_false(ResourceLoader.exists("res://assets/ui/alpha/HVGA/midas/midas_crip10.png"), "midas_crip10.png 资源缺")


# 滚动到底（源 refreshHistory :705 scrollView:move2end(0.4) 逐条滚到最新行）。
func test_scroll_to_end() -> void:
	var host := VBoxContainer.new()
	var scroll := ScrollContainer.new()
	scroll.add_child(host)
	add_child(scroll)
	var history: Array = []
	for i in range(30):
		history.append({"cost": 10, "acquire": 5000, "ratio": 1})
	MidasFills.fill_history_rows(scroll, host, history, _resolver())
	await get_tree().process_frame
	assert_gt(scroll.get_v_scroll_bar().max_value, scroll.size.y, "30 行内容超视口（需滚动）")
	assert_almost_eq(scroll.scroll_vertical, scroll.get_v_scroll_bar().max_value, 2.0,
		"fill 后滚到底（源 move2end）")
	scroll.free()


# 确认弹窗静态 rect（源 uieditor/confirmdialog.lua 声明表 + initWindow widthMax w=600：
# frame DG(600,180+nh*1.28) 中心 (401.56,234.38)；按钮 DGccp(w/7*2|5,58) frame 局部）。
func test_confirm_static_rects() -> void:
	var inst: Control = load("res://scenes/ui/midas_confirm_content.tscn").instantiate() as Control
	add_child(inst)
	var frame: NinePatchRect = inst.get_node("%Frame") as NinePatchRect
	assert_almost_eq(frame.size.x, 468.75, 0.5, "frame 宽 = DG(600)（widthMax w=600）")
	assert_almost_eq(frame.position.x + frame.size.x * 0.5, 401.56, 0.5, "frame 中心 x = 80+401.56（声明表）")
	assert_almost_eq(frame.position.y + frame.size.y * 0.5, 245.62, 0.5, "frame 中心 y = 560-234.38")
	# capInsets CCRectMake(19.53,19.53,46.88,11.72) 纹理 103x61 → int 取整
	assert_almost_eq(float(frame.patch_margin_left), 20.0, 0.5, "patch_left=round(19.53)")
	assert_almost_eq(float(frame.patch_margin_right), 37.0, 0.5, "patch_right=round(103-19.53-46.88)")
	assert_almost_eq(float(frame.patch_margin_top), 30.0, 0.5, "patch_top=round(61-19.53-11.72)")
	assert_almost_eq(float(frame.patch_margin_bottom), 20.0, 0.5, "patch_bottom=round(19.53)")
	var ok_btn: Button = frame.get_node("%OkBtn") as Button
	assert_almost_eq(ok_btn.size.x, 125.0, 0.5, "OkBtn 宽 = 源 scaleSize 125")
	assert_almost_eq(ok_btn.size.y, 54.69, 0.5, "OkBtn 高 = 源 scaleSize 54.69")
	assert_true(String(ok_btn.theme_type_variation) == "MidasConfirmBtn", "OkBtn variation=MidasConfirmBtn")
	# 右按钮 frame 局部 DGccp(600/7*5,58)=(334.8,45.3) → godot frame 内 (334.8, 高-45.3)
	assert_almost_eq(ok_btn.position.x + ok_btn.size.x * 0.5, 334.82, 0.6, "OkBtn 中心 x = frame 局部 DG(w/7*5)")
	var delimeter: TextureRect = frame.get_node("%Delimeter") as TextureRect
	assert_almost_eq(delimeter.position.x + delimeter.size.x * 0.5, frame.size.x * 0.5, 0.5,
		"Delimeter 水平居中（源 initWindow DGccp(w/2,100)）")
	inst.free()


# 确认弹窗 3 行 fill（源 createMultiWindow :556-657 ChaosNode）。
func test_confirm_rows_filled() -> void:
	var inst: Control = load("res://scenes/ui/midas_confirm_content.tscn").instantiate() as Control
	add_child(inst)
	MidasFills.fill_confirm_texts(inst, 3, 60, 15000, _resolver())
	var rows: VBoxContainer = inst.get_node("%Frame/%Rows") as VBoxContainer
	assert_eq(rows.get_child_count(), 3, "3 行（连兑次数/花费/获得）")
	var row_times: HBoxContainer = rows.get_child(0) as HBoxContainer
	assert_eq((row_times.get_node("TimesCountLabel") as Label).text, "3", "连兑次数 fill")
	var row_cost: HBoxContainer = rows.get_child(1) as HBoxContainer
	assert_eq((row_cost.get_node("CostLabel") as Label).text, "x60", "总花费 fill（源 :616 x..count*cost）")
	var row_gain: HBoxContainer = rows.get_child(2) as HBoxContainer
	assert_eq((row_gain.get_node("GainLabel") as Label).text, "x15000", "总获得 fill（源 :648 x..acquire）")
	inst.free()


# fills .new( 宽口径白名单：仅 ratio 降级两工厂（Label/TextureRect，资源缺现实路径）。
func test_fills_new_whitelist() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/midas_fills.gd")
	var allowed: int = script_text.count("Label.new(") + script_text.count("TextureRect.new(")
	assert_eq(script_text.count(".new("), allowed, "fills .new( 仅 ratio 降级 Label/TextureRect")
	assert_lte(allowed, 2, "降级工厂 ≤2 处")
	assert_false(script_text.contains("HBoxContainer.new("), "禁建静态行容器（行结构归 tscn 模板）")
	assert_false(script_text.contains("add_theme_"), "fills 禁样式 override")
