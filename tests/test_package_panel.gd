extends GutTest
# Phase 6 package 复刻 View 主壳：PackagePanel 测试（2026-07-05 第 23 段）。
# 照源 package.lua 两 identity 多 tab + 4 列网格。Logic 走 EquipmentClassifier.classify。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 从 Equip 表动态取某 Category 的一个 id（避免硬编码 id 脆弱）。
func _find_equip_id_by_category(category: String) -> int:
	var raw: Dictionary = cm.get_raw_table(&"Equip")
	for tid_str in raw:
		if String(raw[tid_str].get(&"Category", "")) == category:
			return int(tid_str)
	return 0


# 从 Fragment 表取一个英雄产物配方（key<100）：{tid, frag_id}。
func _find_hero_fragment_recipe() -> Dictionary:
	var raw: Dictionary = cm.get_raw_table(&"Fragment")
	for tid_str in raw:
		if int(tid_str) < 100:
			return {"tid": int(tid_str), "frag_id": int(raw[tid_str].get(&"Fragment ID", 0))}
	return {}


func _make_panel(p_identity: String, p_pd: PlayerData) -> PackagePanel:
	var panel := PackagePanel.new(p_identity, {})
	panel.setup_panel(cm, p_pd)
	return panel


# ── identity → tab 集（源 packageres.list_key）──

func test_setup_package_5_tabs() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	assert_eq(panel._tab_buttons.size(), 5, "package identity 5 tab（all/equip/scroll/stone/consume）")
	assert_eq(panel._tabs, ["all", "equip", "scroll", "stone", "consume"], "tab 顺序照源 packageres")
	assert_eq(int((panel._tab_buttons["all"] as TextureButton).z_index), 3, "默认 all tab 选中（z=3）")
	panel.remove_window()
	root.queue_free()


func test_setup_fragment_3_tabs() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := _make_panel("fragment", pd)
	panel.show_window(root)
	assert_eq(panel._tab_buttons.size(), 3, "fragment identity 3 tab（all/equip/scroll）")
	assert_eq(panel._tabs, ["all", "equip", "scroll"], "tab 顺序照源 packageres")
	panel.remove_window()
	root.queue_free()


# ── 网格填充（classify 输出 → cell）──

func test_package_grid_fills_from_items() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_id_by_category("EQUIP.PARTS")
	assert_gt(eid, 0, "PARTS id 存在")
	pd.add_item(eid, 3)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	assert_eq(panel._grid.get_child_count(), 1, "all tab 显示 1 个 PARTS cell")
	panel.remove_window()
	root.queue_free()


func test_fragment_grid_fills_from_fragments() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var recipe: Dictionary = _find_hero_fragment_recipe()
	assert_false(recipe.is_empty(), "Fragment 表有英雄配方")
	pd.hero_manager.add_fragment(int(recipe["frag_id"]), 5)
	var panel := _make_panel("fragment", pd)
	panel.show_window(root)
	assert_eq(panel._grid.get_child_count(), 1, "fragment all tab 显示 1 个英雄碎片 cell")
	panel.remove_window()
	root.queue_free()


# ── tab 切换 ──

func test_tab_switch_changes_grid() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var parts_id: int = _find_equip_id_by_category("EQUIP.PARTS")
	var reel_id: int = _find_equip_id_by_category("EQUIP.REEL")
	pd.add_item(parts_id, 1)
	pd.add_item(reel_id, 1)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	assert_eq(panel._grid.get_child_count(), 2, "all tab = PARTS+REEL 2 cell")
	panel._select_tab("equip")
	assert_eq(panel._grid.get_child_count(), 1, "equip tab 只 PARTS（REEL 是 scroll）")
	panel._select_tab("scroll")
	assert_eq(panel._grid.get_child_count(), 1, "scroll tab 只 REEL")
	assert_eq(int((panel._tab_buttons["scroll"] as TextureButton).z_index), 3, "scroll tab 选中态（z=3）")
	assert_eq(int((panel._tab_buttons["equip"] as TextureButton).z_index), 1, "equip tab 取消选中（z=1）")
	panel.remove_window()
	root.queue_free()


# tab classbtn 纹理化（2026-07-19，照源 package.lua:378-462 createListButton + hero_package 范式）。
func test_tab_buttons_use_classbtn_texture() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	var all_btn: TextureButton = panel._tab_buttons["all"] as TextureButton
	assert_eq(all_btn.stretch_mode, TextureButton.STRETCH_SCALE, "tab stretch_mode=SCALE（避 KEEP 纹理原尺寸溢出）")
	assert_eq(all_btn.texture_normal.resource_path, PackagePanel.CLASSBTN_SEL_RES, "选中 tab texture_normal=classbtnselected")
	var equip_btn: TextureButton = panel._tab_buttons["equip"] as TextureButton
	assert_eq(equip_btn.texture_normal.resource_path, PackagePanel.CLASSBTN_RES, "未选中 tab texture_normal=classbtn")
	var all_lbl: Label = panel._tab_labels["all"] as Label
	assert_eq(all_lbl.text, "全部", "all tab label LSTR 填充（BATTLEPREPARE.WHOLE=全部）")
	panel.remove_window()
	root.queue_free()


# ── cell 点击链（gui_input → cell_clicked，第 24 段接 equipboard）──

func test_cell_has_click_handler() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_id_by_category("EQUIP.PARTS")
	pd.add_item(eid, 1)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	var cell: Control = panel._grid.get_child(0)
	assert_gt(cell.gui_input.get_connections().size(), 0, "cell gui_input 已连（点击 emit cell_clicked）")
	panel.remove_window()
	root.queue_free()


# 空背包不崩（grid 空）。
func test_empty_player_grid() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	assert_eq(panel._grid.get_child_count(), 0, "空玩家 grid 空")
	panel.remove_window()
	root.queue_free()


# 点 cell 弹 equipboard（单例 + refresh 切换，源 doSelectEquip :185-200 首次 create / 已有 refresh）。
func test_cell_click_switch_refresh_equipboard() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var parts_id: int = _find_equip_id_by_category("EQUIP.PARTS")
	var reel_id: int = _find_equip_id_by_category("EQUIP.REEL")
	assert_gt(parts_id, 0, "PARTS id 存在")
	assert_gt(reel_id, 0, "REEL id 存在")
	pd.add_item(parts_id, 1)
	pd.add_item(reel_id, 1)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	# 首次点 parts cell → 建 _equipboard（非模态浮层）
	panel._on_cell_clicked({"id": parts_id, "amount": 1, "type": 1})
	assert_not_null(panel._equipboard, "首次点 cell 建 _equipboard")
	var board1: EquipboardPanel = panel._equipboard
	assert_eq(board1._item_id, parts_id, "首次 _item_id=parts")
	# 再点 reel cell → refresh 同实例（不重建，源 doSelectEquip refresh；非模态不阻塞 cell 点击）
	panel._on_cell_clicked({"id": reel_id, "amount": 1, "type": 1})
	assert_eq(panel._equipboard, board1, "再点 cell refresh 同实例（非重建）")
	assert_eq(panel._equipboard._item_id, reel_id, "refresh 切换 _item_id=reel")
	panel._equipboard.remove_window()
	panel.remove_window()
	root.queue_free()


# 合成回调刷新 grid（equipboard.composed → _on_sold 重 classify + 重填，源 downFragmentCompose consumeAmount :47-74）。
func test_compose_refreshes_grid() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var parts_id: int = _find_equip_id_by_category("EQUIP.PARTS")
	pd.add_item(parts_id, 1)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	assert_eq(panel._grid.get_child_count(), 1, "初始 1 cell")
	panel._on_cell_clicked({"id": parts_id, "amount": 1, "type": 1})
	assert_not_null(panel._equipboard, "点 cell 建 _equipboard")
	pd.sell_equip(parts_id, 1)   # 模拟持有量变化（合成/卖出消耗，1→0）
	panel._equipboard.composed.emit(parts_id)   # 触发 composed → _on_sold 刷新
	assert_eq(panel._grid.get_child_count(), 0, "composed → _on_sold 刷新 grid，持有量 0 cell 消失")
	panel.remove_window()
	root.queue_free()


# ── 顶部货币条（源 framework.lua:755 sbCreateTitle common，所有非 main 场景建 3 货币条）──

func test_status_bar_built_with_three_bars() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	# 方案 B：HudOverlay autoload 接管 HUD。package 是子场景 → 用 _status_refs_sub（仅 3 货币条）。
	# 注意：HudOverlay 数据源是全局 GameData.player（非测试 pd），gold label 显示全局玩家金币。
	var status_refs: Dictionary = HudOverlay._status_refs_sub
	assert_true(status_refs.has("gold"), "货币条 gold label 装好")
	assert_true(status_refs.has("diamond"), "货币条 diamond label 装好")
	assert_true(status_refs.has("vitality"), "货币条 vitality label 装好")
	var gold_lbl: Label = status_refs["gold"]
	assert_eq(gold_lbl.text, str(GameData.player.hero_manager.gold), "gold label 显示全局玩家金币")
	panel.remove_window()
	root.queue_free()


func test_status_bar_built_on_fragment_identity_too() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := _make_panel("fragment", pd)
	panel.show_window(root)
	# fragment identity 也走 HudOverlay.apply_identity，货币条恒建（源 framework common）。
	var status_refs: Dictionary = HudOverlay._status_refs_sub
	assert_true(status_refs.has("vitality"), "fragment identity 也建货币条（源 framework common）")
	panel.remove_window()
	root.queue_free()


# hud_identity 接线（show_window 切 HudOverlay 的前提）：setup_panel 后 hud_identity=identity。
# 曾有顺序 bug：hud_identity 在 _identity 赋值前取值，首次恒空串 → HudOverlay 不切换。
func test_hud_identity_wired() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := _make_panel("package", pd)
	assert_eq(panel.hud_identity, "package", "setup_panel 后 hud_identity=package（顺序正确）")
	panel.remove_window()
	root.queue_free()


# ══════════ 批 2 两件套守卫（2026-08-16，核对级照源 package.lua/packageres.lua）══════════

const CONTENT_PATH := "res://scenes/ui/package_content.tscn"
const PANEL_PATH := "res://scripts/ui/package_panel.gd"
const THEME_PATH := "res://resources/themes/default_theme.tres"


# 静态树：主壳节点常驻 tscn，rect 照源换算（CCRect 中心锚点 / ÷CS 显示尺寸）。
# 源 package.lua: equipbg 中心 ccp(500,213)（:612-626）；tab ox,oy=706,363 dy=60（:378-462）；
# handbook 中心 ccp(716,55) scaleSize 92x58（:463-538）；draglist rect CCRectMake(355,35,295,355)（:350-368）。
func test_content_static_tree() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	# equipbg（439x491 ÷CS=342.63x383.22，中心 to_godot(500,213)=(580,347)）
	var bg: TextureRect = inst.get_node("Bg") as TextureRect
	assert_almost_eq(bg.offset_left, 408.68, 0.1, "Bg 左 = 580-342.63/2")
	assert_almost_eq(bg.offset_top, 155.39, 0.1, "Bg 顶 = 347-383.22/2")
	assert_almost_eq(bg.size.x, 342.63, 0.1, "Bg 宽 = 439/CS")
	assert_almost_eq(bg.size.y, 383.22, 0.1, "Bg 高 = 491/CS")
	# CloseBtn（backbtn 74x75 ÷CS=57.76x58.54，位置照批 1 惯例 (20,15)，源靠 framework 返回）
	var close_btn: TextureButton = inst.get_node("%CloseBtn") as TextureButton
	assert_almost_eq(close_btn.offset_left, 20.0, 0.01, "CloseBtn 左=20（批1惯例）")
	assert_almost_eq(close_btn.offset_top, 15.0, 0.01, "CloseBtn 顶=15")
	assert_almost_eq(close_btn.size.x, 57.76, 0.01, "CloseBtn 宽 = 74/CS（非旧 80 拉伸变形）")
	assert_almost_eq(close_btn.size.y, 58.54, 0.01, "CloseBtn 高 = 75/CS")
	assert_eq(close_btn.stretch_mode, TextureButton.STRETCH_SCALE, "CloseBtn stretch=SCALE（纹理缩到 /CS 尺寸）")
	# tab 按钮（classbtn 134x75 ÷CS=104.61x58.54；press 中心 (786,197+60k)）
	var tab_all: TextureButton = inst.get_node("%TabAllBtn") as TextureButton
	assert_almost_eq(tab_all.offset_left, 733.7, 0.1, "TabAllBtn 左 = 786-104.61/2")
	assert_almost_eq(tab_all.offset_top, 167.73, 0.1, "TabAllBtn 顶 = 197-58.54/2")
	assert_almost_eq(tab_all.size.x, 104.61, 0.1, "TabAllBtn 宽 = 134/CS（非旧 90 压缩）")
	assert_almost_eq(tab_all.size.y, 58.54, 0.1, "TabAllBtn 高 = 75/CS")
	assert_eq(tab_all.stretch_mode, TextureButton.STRETCH_SCALE, "tab stretch=SCALE（tscn 自足，非运行时设置）")
	var tab_stone: TextureButton = inst.get_node("%TabStoneBtn") as TextureButton
	assert_almost_eq(tab_stone.offset_top, 347.73, 0.1, "TabStoneBtn 顶 = 197+180-58.54/2（dy=60 第4行）")
	# tab label（源 label 中心 x=ox+5 → 791，y 与 press 同 197+60k；size20 shadow(42,31,22)）
	var lbl_all: Label = inst.get_node("%TabAllLabel") as Label
	assert_almost_eq(lbl_all.offset_left, 741.0, 0.1, "TabAllLabel 左 = 791-100/2（照源 ox+5 右偏 5）")
	assert_almost_eq(lbl_all.offset_top, 182.0, 0.1, "TabAllLabel 顶 = 197-30/2")
	assert_almost_eq(lbl_all.size.x, 100.0, 0.1, "TabAllLabel 宽 100")
	assert_almost_eq(lbl_all.size.y, 30.0, 0.1, "TabAllLabel 高 30")
	var lbl_consume: Label = inst.get_node("%TabConsumeLabel") as Label
	assert_almost_eq(lbl_consume.offset_top, 422.0, 0.1, "TabConsumeLabel 顶 = 437-30/2（第5行）")
	assert_eq(String(lbl_all.theme_type_variation), "PackageTabLabel", "tab label 走 PackageTabLabel variation")
	# handbook 按钮（Scale9 scaleSize 92x58 中心 to_godot(716,55)=(796,505)）
	var hb: Button = inst.get_node("%HandbookBtn") as Button
	assert_almost_eq(hb.offset_left, 750.0, 0.01, "HandbookBtn 左 = 796-92/2")
	assert_almost_eq(hb.offset_top, 476.0, 0.01, "HandbookBtn 顶 = 505-58/2")
	assert_almost_eq(hb.size.x, 92.0, 0.01, "HandbookBtn 宽照源 scaleSize 92")
	assert_almost_eq(hb.size.y, 58.0, 0.01, "HandbookBtn 高照源 scaleSize 58")
	assert_eq(String(hb.theme_type_variation), "PackageHandbookBtn", "handbook 走 PackageHandbookBtn 三态 variation")
	# handbook 图标（19x25 ÷CS=14.83x19.51，btn 局部中心 (18,58-31=27)）
	var hb_icon: TextureRect = inst.get_node("%HandbookBtn/HandbookIcon") as TextureRect
	assert_almost_eq(hb_icon.size.x, 14.83, 0.01, "HandbookIcon 宽 = 19/CS（非旧 19 原像素）")
	assert_almost_eq(hb_icon.size.y, 19.51, 0.01, "HandbookIcon 高 = 25/CS")
	assert_almost_eq(hb_icon.position.x + hb_icon.size.x * 0.5, 18.0, 0.01, "HandbookIcon 中心 x=18（照源局部 ccp(18,31)）")
	assert_almost_eq(hb_icon.position.y + hb_icon.size.y * 0.5, 27.0, 0.01, "HandbookIcon 中心 y=58-31（局部 y 翻转）")
	# 滚动区（draglist rect CCRectMake(355,35,295,355) → 435~730 x 170~525）
	var scroll: ScrollContainer = inst.get_node("%ScrollHost") as ScrollContainer
	assert_almost_eq(scroll.offset_left, 435.0, 0.1, "ScrollHost 左 = 355+80")
	assert_almost_eq(scroll.offset_top, 170.0, 0.1, "ScrollHost 顶 = 560-(35+355)")
	assert_almost_eq(scroll.offset_right, 730.0, 0.1, "ScrollHost 右 = 650+80")
	assert_almost_eq(scroll.offset_bottom, 525.0, 0.1, "ScrollHost 底 = 560-35")
	assert_true(scroll.clip_contents, "ScrollHost 裁剪（源 cliprect 等价）")
	# 网格（cell 视觉 = frame 纹理 94×95px ×(74/95)=73.22×74.0（task-11 修，loadEquip 无
	# length 原点尺寸 ≈÷CS）→ 起点局部 (1.39,10.0) 由 MarginHost 承载 + separation 2/6
	# （GridContainer separation 是 int constant，步进 73.22+2=75/74+6=80 照源 dx,dy）；
	# ScrollContainer 强制子节点贴 (0,0)，Grid 直接 offset 会被容器布局覆盖——批 2 实测）
	var grid: GridContainer = inst.get_node("%Grid") as GridContainer
	assert_eq(grid.columns, 4, "Grid 4 列照源")
	var margin_host: MarginContainer = grid.get_parent() as MarginContainer
	assert_not_null(margin_host, "Grid 挂 MarginHost（ScrollHost>MarginHost>Grid 层级）")
	assert_almost_eq(margin_host.get_theme_constant(&"margin_left"), 1, 0.01,
		"MarginHost 左 = int(393-73.22/2+80-435)（margin 是 int constant，1.39 截 1）")
	assert_almost_eq(margin_host.get_theme_constant(&"margin_top"), 10, 0.01,
		"MarginHost 顶 = int(560-(343+74/2)-170)（源首行中心 343，cell 视觉高 74）")
	assert_eq(String(grid.theme_type_variation), "PackageGrid", "Grid separation 走 PackageGrid variation")
	# 迁移发明清理：StatusHost 死节点已删（HudOverlay 接管货币条）
	assert_false(inst.has_node("%StatusHost"), "StatusHost 已删（HudOverlay 接管，防复发）")


# panel 零静态构造（宽口径白名单）：动态弹窗 HandbookPanel/EquipboardPanel + cell wrapper
# 的 Control.new(（task-11：GridContainer 会重置直接 child scale → wrapper 布局载体）。
func test_panel_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_eq(text.count(".new("), text.count("HandbookPanel.new(") + text.count("EquipboardPanel.new(")
		+ text.count("Control.new(") + text.count("NinePatchRect.new("),
		"静态节点零 .new(，仅动态弹窗 + wrapper/NinePatch 边框载体白名单")


# theme variation 接线（GUT 下节点级不解析 variation，读 tres 文本表项）。
# 源字号/色：tab label size20 白 shadow ccc3(42,31,22)(0,2)（package.lua:418-437）；
# handbook label fontinfo ui_normal_button → size17 白 shadow ccc3(63,5,0)(0,2)（fontconfigs.lua:23-30，
# 无 size 覆盖 → 17 非旧 20）；handbook 按钮源 cap CCRectMake(15,22,15,25)（63x67 纹理）→
# margin left=15 top=67-22-25=20 right=63-30=33 bottom=22（Task 1 公式）。
func test_theme_variations_wired() -> void:
	var t: String = FileAccess.get_file_as_string(THEME_PATH)
	assert_true(t.contains("PackageTabLabel/colors/font_shadow_color = Color(0.164706, 0.121569, 0.086275, 1)"),
		"PackageTabLabel shadow=ccc3(42,31,22)（42/255,31/255,22/255）")
	assert_true(t.contains("PackageTabLabel/font_sizes/font_size = 20"), "PackageTabLabel 字号 20")
	assert_true(t.contains("PackageHandbookLabel/font_sizes/font_size = 17"),
		"PackageHandbookLabel 字号 17（fontinfo 默认，无 size 覆盖）")
	assert_true(t.contains("PackageHandbookLabel/colors/font_shadow_color = Color(0.247059, 0.019608, 0, 1)"),
		"PackageHandbookLabel shadow=ccc3(63,5,0)（fontinfo 默认）")
	assert_true(t.contains("PackageHandbookBtn/styles/pressed = SubResource(\"SB_pkg_hb_p\")"),
		"PackageHandbookBtn pressed=SB_pkg_hb_p（sell_number_button_down）")
	var sb_n: int = t.find("SB_pkg_hb_n")
	assert_gt(sb_n, 0, "SB_pkg_hb_n sub_resource 存在")
	var sb_block: String = t.substr(sb_n - 40, 400)
	assert_true(sb_block.contains("texture_margin_left = 15.0"), "SB margin left=源 cap.x=15")
	assert_true(sb_block.contains("texture_margin_top = 20.0"), "SB margin top=67-22-25=20（Task 1 公式）")
	assert_true(sb_block.contains("texture_margin_right = 33.0"), "SB margin right=63-15-15=33")
	assert_true(sb_block.contains("texture_margin_bottom = 22.0"), "SB margin bottom=源 cap.y=22")
	assert_true(t.contains("PackageGrid/constants/h_separation = 2"),
		"PackageGrid h_sep=2（task-11：cell 视觉 73.22，步进 73.22+2=75=源 dx；int constant）")
	assert_true(t.contains("PackageGrid/constants/v_separation = 6"),
		"PackageGrid v_sep=6（task-11：cell 视觉高 74，步进 74+6=80=源 dy；int constant）")


# tab label 恒居底图上（task-11 守卫）：源 package.lua:424 label z=24 > normal 1/3、press 20。
# 曾因 label z=0 被 _update_tab_visual 设 z 的按钮纹理盖住（classbtn 中心不透明，验收"无文字"）。
func test_tab_labels_z_above_buttons() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	for key in ["All", "Equip", "Scroll", "Stone", "Consume"]:
		var lbl: Label = inst.get_node("%Tab" + key + "Label") as Label
		assert_eq(int(lbl.z_index), 24, "Tab%sLabel z=24（源 :424 label z=24 恒居底图上）" % key)
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	var all_btn: TextureButton = panel._tab_buttons["all"] as TextureButton
	var all_lbl: Label = panel._tab_labels["all"] as Label
	assert_eq(int(all_btn.z_index), 3, "选中 tab 按钮 z=3")
	assert_true(int(all_lbl.z_index) > int(all_btn.z_index), "label z=24 > 选中按钮 z=3（文字不被盖）")
	var equip_lbl: Label = panel._tab_labels["equip"] as Label
	var equip_btn: TextureButton = panel._tab_buttons["equip"] as TextureButton
	assert_true(int(equip_lbl.z_index) > int(equip_btn.z_index), "label z=24 > 未选中按钮 z=1")
	panel.remove_window()
	root.queue_free()


# z 逃逸守卫（审查 F1，2026-08-16）：Cocos zOrder 局部于 mainLayer 兄弟排序；Godot
# z_as_relative 默认 true 沿祖先累加——content 挂 PackagePanel（PopWindow z=100
# absolute，pop_window.gd show_window），Tab*Label z=24 曾 effective 124 > 弹窗兜底
# 100，tab 白字穿透 HandbookPanel（图鉴）。修法=content 全部直接子节点绝对化
# （effective=源值）。⚠️ z=0 节点（FrameworkBg/CloseBtn/HandbookBtn/Tab*Btn）必须
# 一并绝对化——若回退 relative 其 effective=100 会反盖绝对化后的 24/10/3 元素
# （tab 文字/格子区被全屏 bg.jpg 盖住）。
func test_tab_z_absolute_no_escape() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	# 带 z 元素绝对化 + 值保持（源序：equipbg 2 :618 / 按钮 1|3 :395 / draglist 10 :355 / label 24 :425）
	for key in ["All", "Equip", "Scroll", "Stone", "Consume"]:
		var lbl: Label = inst.get_node("%Tab" + key + "Label") as Label
		assert_false(lbl.z_as_relative, "Tab%sLabel z_as_relative=false（防 PopWindow z=100 累加逃逸）" % key)
		assert_eq(int(lbl.z_index), 24, "Tab%sLabel z=24（源 :425）" % key)
	var scroll: ScrollContainer = inst.get_node("%ScrollHost") as ScrollContainer
	assert_false(scroll.z_as_relative, "ScrollHost z_as_relative=false（格子区 effective=10 不逃逸）")
	var bg: TextureRect = inst.get_node("Bg") as TextureRect
	assert_false(bg.z_as_relative, "Bg z_as_relative=false（equipbg 源 :618 z=2）")
	# z=0 直接子节点同款绝对化（反盖守卫：relative 会 eff=100 盖过绝对化的 24/10/3）
	for node_name in ["FrameworkBg", "CloseBtn", "HandbookBtn"]:
		var zero_node: CanvasItem = inst.get_node(node_name) as CanvasItem
		assert_false(zero_node.z_as_relative, "%s z_as_relative=false（z=0 基线，防 eff 100 反盖）" % node_name)
	for key in ["All", "Equip", "Scroll", "Stone", "Consume"]:
		var btn0: TextureButton = inst.get_node("%Tab" + key + "Btn") as TextureButton
		assert_false(btn0.z_as_relative, "Tab%sBtn z_as_relative=false（z 由 panel 运行时设 1/3）" % key)
	# 值序（源序保持）+ 全部 < 弹窗兜底 100
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	var lbl_all: Label = inst.get_node("%TabAllLabel") as Label
	var all_btn: TextureButton = panel._tab_buttons["all"] as TextureButton
	var equip_btn: TextureButton = panel._tab_buttons["equip"] as TextureButton
	assert_false(all_btn.z_as_relative, "运行时按钮 z_as_relative=false（_update_tab_visual 同步设）")
	assert_eq(int(all_btn.z_index), 3, "选中按钮 z=3（源 :395 i==1）")
	assert_eq(int(equip_btn.z_index), 1, "未选中按钮 z=1")
	assert_gt(int(lbl_all.z_index), int(scroll.z_index), "label 24 > ScrollHost 10（源 label 最顶）")
	assert_gt(int(scroll.z_index), int(all_btn.z_index), "ScrollHost 10 > 按钮 max 3（格子区盖选中凸出）")
	assert_gt(int(bg.z_index), int(equip_btn.z_index), "Bg 2 > 未选中按钮 1（equipbg 盖 normal 底图）")
	for zi in [int(lbl_all.z_index), int(scroll.z_index), int(all_btn.z_index), int(bg.z_index), int(equip_btn.z_index)]:
		assert_lt(zi, 100, "z=%d < 弹窗兜底 100（不穿透 HandbookPanel/EquipboardPanel）" % zi)
	panel.remove_window()
	root.queue_free()


# cell 显示对齐（修复轮 B 守卫）：wrapper min=视觉盒 73.22×74（步进 75/80 由 min+theme sep
# 2/6 合成）；frame 层 NinePatchRect 1:1 保立体（PIL 实测 equip_frame 边框 6 行层界
# 顶 y2-7/底 y84-88/左右 x3-8、x85-90 含透明缘 → patch 9/8/11/9）；内容层去 frame Sprite2D、
# scale 55/78 落中区、icon 归中 (9,9)。历史：等比缩放 6 层压 4-5 层高光并档（验收"边框糊"）。
func test_grid_cell_display_alignment() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var parts_id: int = _find_equip_id_by_category("EQUIP.PARTS")
	var reel_id: int = _find_equip_id_by_category("EQUIP.REEL")
	pd.add_item(parts_id, 1)
	pd.add_item(reel_id, 1)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	assert_eq(panel._grid.get_child_count(), 2, "2 cell（all tab PARTS+REEL）")
	var wrapper0: Control = panel._grid.get_child(0)
	assert_almost_eq(wrapper0.custom_minimum_size.x, 73.22, 0.01, "wrapper min 宽=视觉宽（格子贴合无重叠）")
	assert_almost_eq(wrapper0.custom_minimum_size.y, 74.0, 0.01, "wrapper min 高=视觉高")
	# 边框层：child(0) = NinePatchRect（1:1 立体层）
	var frame: NinePatchRect = wrapper0.get_child(0) as NinePatchRect
	assert_not_null(frame, "frame 层 = NinePatchRect（修复轮 B：Sprite2D 等比缩放层混叠的反案）")
	assert_eq(frame.patch_margin_left, 9, "patch left=9（层 x3-8 含透明缘）")
	assert_eq(frame.patch_margin_top, 8, "patch top=8（层 y2-7 含透明缘）")
	assert_eq(frame.patch_margin_right, 9, "patch right=9（层 x85-90 含透明缘）")
	assert_eq(frame.patch_margin_bottom, 11, "patch bottom=11（层 y84-88 含透明缘）")
	assert_almost_eq(frame.size.x, 73.22, 0.01, "frame 宽=格子盒（源 73.37 差 0.15px）")
	assert_almost_eq(frame.size.y, 74.0, 0.01, "frame 高 74（源 74.13）")
	assert_true(String(frame.texture.resource_path).begins_with(ReadequipIcon.FRAME_DIR),
		"frame 贴图按品质 equip_frame_<color>.png")
	# 内容层：child(1) = ReadequipIcon 产物（frame Sprite2D 已剥、icon 归中、缩放落中区）
	var cell0: Control = wrapper0.get_child(1) as Control
	assert_almost_eq(cell0.scale.x, 55.0 / 78.0, 0.0001, "内容层 scale=55/78（icon 视觉嵌 NinePatch 中区）")
	assert_almost_eq(cell0.position.x, 9.0 - 9.0 * 55.0 / 78.0, 0.01, "内容层 offset 使 icon 视觉起点=中区左上")
	for c in cell0.get_children():
		var spr := c as Sprite2D
		if spr == null or spr.texture == null:
			continue
		var p: String = spr.texture.resource_path
		assert_false(p.begins_with(ReadequipIcon.FRAME_DIR) or p.begins_with(ReadequipIcon.FRAGMENT_FRAME_DIR),
			"内容层无残留 frame Sprite2D（由 NinePatchRect 接管）")
	panel.remove_window()
	root.queue_free()


# fragment 侧 cell 结构（修复轮 B）：fragment_bg 衬底 NinePatch（渐变带 patch 12/13）+
# fragment_frame 品质框 + 内容层 icon 归中（STONE_ICON_POS (36,38) 溢出格子的既有偏移治理）。
func test_fragment_cell_ninepatch_structure() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var recipe: Dictionary = _find_hero_fragment_recipe()
	pd.hero_manager.add_fragment(int(recipe["frag_id"]), 5)
	var panel := _make_panel("fragment", pd)
	panel.show_window(root)
	assert_eq(panel._grid.get_child_count(), 1, "fragment all tab 1 cell")
	var wrapper: Control = panel._grid.get_child(0)
	var bg: NinePatchRect = wrapper.get_child(0) as NinePatchRect
	assert_not_null(bg, "child(0) = fragment_bg 衬底 NinePatchRect")
	assert_eq(String(bg.texture.resource_path), ReadequipIcon.FRAGMENT_BG_PATH, "衬底贴图 fragment_bg.png")
	assert_eq(bg.patch_margin_top, 12, "衬底 patch top=12（渐变带 y1-11）")
	assert_eq(bg.patch_margin_bottom, 13, "衬底 patch bottom=13（渐变带 y82-89 含透明缘）")
	var frame: NinePatchRect = wrapper.get_child(1) as NinePatchRect
	assert_not_null(frame, "child(1) = fragment_frame 品质框 NinePatchRect")
	assert_true(String(frame.texture.resource_path).begins_with(ReadequipIcon.FRAGMENT_FRAME_DIR),
		"品质框贴图 fragment_frame_<color>.png")
	var cell: Control = wrapper.get_child(2) as Control
	var icon: Sprite2D = null
	for c in cell.get_children():
		var spr := c as Sprite2D
		if spr != null and spr.texture != null \
				and String(spr.texture.resource_path) != ReadequipIcon.SOULSTONE_TAG_PATH \
				and String(spr.texture.resource_path) != ReadequipIcon.TICK_PATH:
			icon = spr
			break
	assert_not_null(icon, "内容层含 icon（含 gocha fallback：碎片 Icon 字段资源缺失回退）")
	assert_eq(icon.position, Vector2(9.0, 9.0), "icon 归中 (9,9)（视觉嵌 NinePatch 中区，旧 (36,38) 溢出）")
	panel.remove_window()
	root.queue_free()


# fill 语义：handbook 按钮文案 LSTR 填充；fragment identity 隐藏 handbook + stone/consume tab。
func test_fill_semantics() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	var hb_label: Label = (panel._content.get_node("%HandbookBtn/HandbookLabel") as Label)
	assert_eq(hb_label.text, "图鉴", "HandbookLabel text=HERODETAIL.BOOK")
	var stone_lbl: Label = panel._tab_labels["stone"] as Label
	assert_eq(stone_lbl.text, "灵魂石", "stone tab label=EQUIP.SOUL_STONE（LSTR fill 非硬编码）")
	panel.remove_window()
	# fragment：handbook 隐藏（源 createHandbookButton 仅 package :526-528）+ stone/consume tab 隐藏
	var panel2 := _make_panel("fragment", pd)
	panel2.show_window(root)
	assert_false((panel2._content.get_node("%HandbookBtn") as Button).visible, "fragment 隐藏 handbook 按钮")
	assert_false((panel2._content.get_node("%TabStoneBtn") as TextureButton).visible, "fragment 隐藏 stone tab")
	assert_false((panel2._content.get_node("%TabConsumeBtn") as TextureButton).visible, "fragment 隐藏 consume tab")
	panel2.remove_window()
	root.queue_free()


# parenting 回归守卫：show_window 后静态 rect 即 global 坐标（PopWindow 全屏 anchor 链）。
func test_tab_global_position() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	var tab_all: TextureButton = panel._tab_buttons["all"] as TextureButton
	assert_almost_eq(tab_all.global_position.x, 733.7, 0.5, "TabAllBtn global x（防 parenting 错位）")
	assert_almost_eq(tab_all.global_position.y, 167.73, 0.5, "TabAllBtn global y")
	var hb: Button = panel._content.get_node("%HandbookBtn") as Button
	assert_almost_eq(hb.global_position.x, 750.0, 0.5, "HandbookBtn global x")
	panel.remove_window()
	root.queue_free()
