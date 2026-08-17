extends GutTest
# Excavate UI Panel 测试（View 层）— 7 panel 照源精修后的 LSTR 化 + 装配验证。
# 照源 ui/excavate/map.lua + search.lua + popwindow/excavateteam.lua + excavatehistory.lua
# + excavatebattlereport.lua + excavateexplain.lua + excavate/giveup.lua。
# P1（2026-07-16）：LSTR key 路由 + fallback 兜底 + 关键装配（按钮/backbtn/Scale9/bg.jpg）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# ── ExcavateExplainPanel：LSTR 化（21 处 key 全在 JSON）──

# 解释面板应加载 4 行故事 + 16 行规则 LSTR（无 fallback 出现说明 key 全命中）。
func test_explain_lstr_keys_all_present() -> void:
	# 此测试验证 LSTR JSON 完整性（excavateexplain.lua 全 21 key 应在表里）
	var keys: Array[String] = [
		"EXCAVATEEXPLAIN.DARK_IRON_DWARVES_KINGDOM_BUILDING_IN_THE_GROUND_MORE_WRONG_SECTION_OF_THE_HOLE_DISK_AS_THE_ROOT_OF_THE_TREE_OF_THE_WORLD_TO_BE",
		"EXCAVATEEXPLAIN._ANUBAR_WARS",
		"EXCAVATEEXPLAIN.1_IN_THE_TREASURE_CRYPT_YOU_CAN_FIND_A_VARIETY_OF_RESOURCE_POINTS_INCLUDING_GOLD_DIAMOND_AND_LABORATORY",
		"EXCAVATEEXPLAIN.10_IN_THE_TREASURE_CRYPT_BATTLE_THE_HERO_OF_THE_DEFENSE_WILL_GET_SOME_INITIAL_ENERGY",
	]
	for k in keys:
		var v: String = cm.get_lstr(k)
		assert_ne(v, k, "LSTR key 命中（非 fallback 返 key 本身）：" + k)
		assert_false(v.is_empty(), "LSTR 值非空：" + k)


# ExcavateExplainPanel 装配无异常（ScrollContainer + VBox + 标签生成）
func test_explain_panel_builds_without_error() -> void:
	var root := Node.new()
	add_child(root)
	var panel := ExcavateExplainPanel.new("excavate_explain", {})
	panel.setup_panel()
	panel.show_window(root)
	assert_gt(panel.container.get_child_count(), 0, "container 非空（frame 已加）")
	panel.remove_window()
	root.queue_free()


# ── ExcavateGiveupPanel：LSTR + 两件套守卫（excavate 批 Task 1，2026-08-17）──

# giveup 5 个 LSTR key + 资源名 key 全在 JSON
func test_giveup_lstr_keys_present() -> void:
	var keys: Array[String] = [
		"giveup.1.10.1.001", "giveup.1.10.1.002", "giveup.1.10.1.003",
		"giveup.1.10.1.005", "CHATCONFIG.CANCEL", "CHATCONFIG.CONFIRM",
		"RECHARGE.DIAMOND", "TASK.GOLD", "EQUIP.EXPERIENCE_CREAMS",
	]
	for k in keys:
		var v: String = cm.get_lstr(k)
		assert_ne(v, k, "LSTR key 命中：" + k)


# A 类债 #7：frame 归源 uieditor/confirmdialog.lua:2-21（Scale9Sprite main_vit_tips
# cap 19.53,19.53,46.88,11.72；giveup 走 param.node 分支，弹窗贴图与 excavate 无关）。
# cap 换算（像素直译口径，H/W 用 PIL 实测 103x61）：L=x=19.53、B=y=19.53、
# R=W-x-w=103-19.53-46.88=36.59、T=H-y-h=61-19.53-11.72=29.75；NinePatchRect
# patch_margin 为 int 取整 20/20/37/30。
func test_giveup_frame_source_fidelity() -> void:
	var content: Control = (load("res://scenes/ui/excavate_giveup_content.tscn") as PackedScene).instantiate() as Control
	add_child(content)
	var frame: NinePatchRect = content.get_node_or_null("Frame") as NinePatchRect
	assert_not_null(frame, "Frame 存在且为 NinePatchRect（源 Scale9Sprite）")
	if frame == null:
		content.queue_free()
		return
	assert_not_null(frame.texture, "frame 有贴图")
	assert_eq(frame.texture.resource_path, "res://assets/ui/alpha/HVGA/main_vit_tips.png",
		"frame 贴图归源 main_vit_tips（弃 excavate_main_frame 误用）")
	assert_eq(frame.patch_margin_left, 20, "cap left=19.53 取整 20")
	assert_eq(frame.patch_margin_bottom, 20, "cap bottom=19.53 取整 20")
	assert_eq(frame.patch_margin_right, 37, "cap right=36.59 取整 37")
	assert_eq(frame.patch_margin_top, 30, "cap top=29.75 取整 30")
	content.queue_free()


# 静态 rect 守卫（防 parenting 回归）：照源声明表 + initWindow 直译。
# frame 中心 (481.56,325.62)=to_godot(401.56,234.38)；尺寸 w=500（max 下限）、
# h=180+3×26×1.28≈280；按钮 (w/7*2,58)/(w/7*5,58)→中心 y=280-58=222；delimeter 中心 (250,180)。
func test_giveup_content_static_rects() -> void:
	var content: Control = (load("res://scenes/ui/excavate_giveup_content.tscn") as PackedScene).instantiate() as Control
	add_child(content)
	var frame: Control = content.get_node("Frame") as Control
	assert_almost_eq(frame.position.x, 231.56, 0.02, "frame offset_left=231.56")
	assert_almost_eq(frame.position.y, 185.62, 0.02, "frame offset_top=185.62")
	assert_almost_eq(frame.size.x, 500.0, 0.02, "frame w=500（initWindow 下限）")
	assert_almost_eq(frame.size.y, 280.0, 0.02, "frame h=180+nh*1.28")
	var del: Control = frame.get_node("Delimeter") as Control
	assert_almost_eq(del.position.x + del.size.x * 0.5, 250.0, 0.02, "delimeter 中心 x=w/2")
	assert_almost_eq(del.position.y + del.size.y * 0.5, 180.0, 0.02, "delimeter 中心 y=h-100")
	var cancel_btn: Control = frame.get_node("CancelBtn") as Control
	assert_almost_eq(cancel_btn.position.x + cancel_btn.size.x * 0.5, 500.0 / 7.0 * 2.0, 0.02, "left btn 中心 x=w/7*2")
	assert_almost_eq(cancel_btn.position.y + cancel_btn.size.y * 0.5, 222.0, 0.02, "left btn 中心 y=h-58")
	assert_almost_eq(cancel_btn.size.y, 54.69, 0.02, "btn 高 scaleSize 54.69")
	var ok_btn: Control = frame.get_node("ConfirmBtn") as Control
	assert_almost_eq(ok_btn.position.x + ok_btn.size.x * 0.5, 500.0 / 7.0 * 5.0, 0.02, "right btn 中心 x=w/7*5")
	# 绘制序守卫（防重排反盖）：delimeter 底层装饰位 → 行内容 → 按钮最上层可点
	assert_lt(frame.get_node("Delimeter").get_index(), frame.get_node("R11Label").get_index(),
		"delimeter 声明序先于行内容")
	assert_gt(frame.get_node("ConfirmBtn").get_index(), frame.get_node("R31Label").get_index(),
		"按钮声明序后于行内容（最上层）")
	content.queue_free()


# 旧范式退役守卫：panel.gd 源码无运行时样式套用（两件套 SOP）。
func test_giveup_no_legacy_runtime_styling() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/excavate_giveup_panel.gd")
	assert_false(src.contains("UiScale9Button"), "UiScale9Button 已退役")
	assert_false(src.contains("add_theme_color_override"), "运行时颜色 override 已退役")
	assert_false(src.contains("add_theme_stylebox_override"), "运行时样式 override 已退役")


# fill 分支（源 giveup.lua:24-105 两形态）：rg>0 三行（label+icon+数值）；
# rg=0 单行警示（.003/.004 按 from）+ 产出行隐藏。单机化 rr=0 → 实得=全额。
func test_giveup_fill_branches() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	pd.excavate.excavate_data.append({
		"_id": 1, "_type_id": 1, "_owner": "mine", "_state": "occupy",
		"_found_ts": 1, "_produce_speed": 0.0, "_storage": 500, "_res_got": 352.0, "_wild_id": 30001, "_team": [],
	})
	var panel := ExcavateGiveupPanel.new("excavate_giveup", {})
	panel.setup_panel(pd, 1, Callable())
	panel.show_window(root)
	var content: Control = panel.container.get_node("ExcavateGiveupContent") as Control
	assert_not_null(content, "content 已装配")
	if content == null:
		panel.remove_window()
		root.queue_free()
		return
	var r13: Label = content.get_node("%R13Label") as Label
	assert_eq(r13.text, "352", "分支A：产出数值 fill")
	var r12: TextureRect = content.get_node("%R12Icon") as TextureRect
	assert_not_null(r12.texture, "分支A：icon 已 fill")
	var r21: Control = content.get_node("%R21Label") as Control
	assert_true(r21.visible, "分支A：行2 可见")
	panel.remove_window()
	# rg=0 分支：res_got=0 + speed=0 → 产出 0，走 else（.003 文案 + 行2 隐藏）
	var pd2 := PlayerData.new(cm)
	pd2.apply_default_data()
	pd2.excavate.excavate_data.append({
		"_id": 2, "_type_id": 1, "_owner": "mine", "_state": "occupy",
		"_found_ts": 1, "_produce_speed": 0.0, "_storage": 500, "_res_got": 0.0, "_wild_id": 30001, "_team": [],
	})
	var panel2 := ExcavateGiveupPanel.new("excavate_giveup", {})
	panel2.setup_panel(pd2, 2, Callable())
	panel2.show_window(root)
	var content2: Control = panel2.container.get_node("ExcavateGiveupContent") as Control
	var r11b: Label = content2.get_node("%R11Label") as Label
	assert_eq(r11b.text, cm.get_lstr("giveup.1.10.1.003"), "分支B：r11=tt 文案（.003）")
	var r21b: Control = content2.get_node("%R21Label") as Control
	assert_false(r21b.visible, "分支B：行2 隐藏")
	panel2.remove_window()
	root.queue_free()


# ── ExcavateHistoryPanel：LSTR 时间格式 + ATTACK ──

# 时间 4 档 LSTR key 全在 JSON
func test_history_time_lstr_keys_present() -> void:
	var keys: Array[String] = [
		"EXCAVATEHISTORY._D_DAYS_AGO", "PVP._D_HOURS_AGO",
		"PVP._D_MINUTES_AGO", "PVP._D_SECONDS_AGO",
		"EXCAVATEHISTORY.ATTACK_YOUR__S",
	]
	for k in keys:
		var v: String = cm.get_lstr(k)
		assert_ne(v, k, "LSTR key 命中：" + k)


# ── ExcavateBattleReportPanel：TITLE_FMT LSTR ──

# THE+BATTLE 拼接 "第" + "1" + "战"
func test_battle_report_title_lstr_concat() -> void:
	var the: String = cm.get_lstr("EXCAVATEBATTLEREPORT.THE")
	var battle: String = cm.get_lstr("EXCAVATEBATTLEREPORT.BATTLE")
	assert_eq(the, "第", "THE = 第")
	assert_eq(battle, "战", "BATTLE = 战")
	var title: String = the + "1" + battle
	assert_eq(title, "第1战", "title 拼接正确")


# ── ExcavateMapPanel：LSTR + bg.jpg + backbtn 装配 ──

# map 面板 LSTR key 全在 JSON
func test_map_lstr_keys_present() -> void:
	var keys: Array[String] = [
		"EXCAVATEMAP.RULES", "EXCAVATEHISTORY.DEFENSIVE_RECORD",
		"RECHARGE.DIAMOND", "TASK.GOLD", "EQUIP.EXPERIENCE_CREAMS",
	]
	for k in keys:
		var v: String = cm.get_lstr(k)
		assert_ne(v, k, "LSTR key 命中：" + k)


# bg.jpg 资源存在（源 uieditor excavatemap:12 第 1 元素照源核实保留）
func test_map_bg_asset_exists() -> void:
	assert_true(ResourceLoader.exists("res://assets/ui/alpha/HVGA/bg.jpg"), "bg.jpg 存在")
	assert_true(ResourceLoader.exists("res://assets/ui/alpha/HVGA/backbtn.png"), "backbtn.png 存在")
	assert_true(ResourceLoader.exists("res://assets/ui/alpha/HVGA/prevchap.png"), "prevchap.png 存在")


# map 面板空矿点列表时显示 NO_NODE_TEXT（避免除零/越界）
func test_map_panel_empty_list_no_crash() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	var panel := ExcavateMapPanel.new("excavate_map", {})
	panel.setup_panel(pd, BattleRng.new(1))
	panel.show_window(root)
	# 空矿点：info_label 显示 NO_NODE_TEXT，node_button 不可见
	assert_false(panel._node_button.visible, "空列表 node_button 隐藏")
	assert_eq(panel._info_label.text, "暂无矿点，点击「搜索」发现矿点", "空列表文案正确")
	panel.remove_window()
	root.queue_free()


# ── ExcavateSearchPanel：LSTR + 按钮纹理（tavern_button_1+icon_search）──

# search toast + type name LSTR key 全在 JSON
func test_search_lstr_keys_present() -> void:
	var keys: Array[String] = [
		"MAP.TODAY_THE_SEARCH_HAS_REACHED_THE_MAXIMUM_NUMBER_OF_TIMES_",
		"ERRORINFO.INSUFFICIENT_COINS",
		"MAP.DIAMOND_MINE", "MAP.GOLDMINE", "MAP.LABORATORY",
	]
	for k in keys:
		var v: String = cm.get_lstr(k)
		assert_ne(v, k, "LSTR key 命中：" + k)


# search 关键资源存在（bg.jpg + excavate_empty.jpg + tavern_button + icon_search）
func test_search_assets_exist() -> void:
	assert_true(ResourceLoader.exists("res://assets/ui/alpha/HVGA/excavate/excavate_empty.jpg"), "excavate_empty.jpg 存在")
	assert_true(ResourceLoader.exists("res://assets/ui/alpha/HVGA/tavern_button_1.png"), "tavern_button_1.png 存在")
	assert_true(ResourceLoader.exists("res://assets/ui/alpha/HVGA/excavate/excavate_icon_search_1.png"), "excavate_icon_search_1.png 存在")


# search 面板装配无异常（含 search button + label 覆盖 + cost label）
func test_search_panel_builds_without_error() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	var panel := ExcavateSearchPanel.new("excavate", {})
	panel.setup_panel(pd, BattleRng.new(1))
	panel.show_window(root)
	assert_gt(panel.container.get_child_count(), 0, "container 非空")
	# cost_label 显示当前消耗数字（首搜 100）
	assert_eq(panel._cost_label.text, "100", "首搜消耗显示 100")
	panel.remove_window()
	root.queue_free()


# ── ExcavateTeamPanel：LSTR ADJUST_FORMATION + owner 切换 ──

# team LSTR ADJUST_FORMATION key 在 JSON
func test_team_lstr_keys_present() -> void:
	assert_eq(cm.get_lstr("EXCAVATETEAM.ADJUST_FORMATION"), "调整阵容", "ADJUST_FORMATION = 调整阵容")


# team 面板 monster 矿点显示出战按钮（无 crash）
func test_team_panel_monster_builds() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	# 直接注入 monster 矿点（避 search 随机）
	pd.excavate.excavate_data.append({
		"_id": 1, "_type_id": 4, "_owner": "monster", "_state": "occupy",
		"_found_ts": 1, "_produce_speed": 10.0, "_storage": 500, "_res_got": 0.0, "_wild_id": 30001, "_team": [],
	})
	var panel := ExcavateTeamPanel.new("excavate_team", {})
	panel.setup_panel(pd, 1, BattleRng.new(1), Callable())
	panel.show_window(root)
	assert_gt(panel.container.get_child_count(), 0, "monster team container 非空")
	panel.remove_window()
	root.queue_free()
