extends GutTest
## avatar_panel 试点重构回归测试（Task 4）。
## 验证 6 标准动作闭环，为批次 1（大文件）提供可复用流程参考：
## 1. 翻译注释（# 源 xxx）归零
## 2. add_theme override 归零（仅允许标题色 1 处受控保留，引用 UIConstants.COLOR_TITLE_GOLD）
## 3. 魔法常量归位 UIConstants（通用设计值进常量类，avatar 特有布局参数留脚本）
## 4. 节点静态化（%AvatarList unique_name）
## 5. 动态列表项用容器（VBoxContainer + GridContainer，P1 保留 procedural）
## 6. 信号策略（P2 默认：全代码 connect，无 editor 连）

func test_avatar_panel_no_translation_comments() -> void:
	# 动作 1：翻译注释（# 源 xxx）归零，保留功能注释
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/avatar_panel.gd")
	var count: int = script_text.count("# 源 ")
	assert_eq(count, 0, "avatar_panel.gd 的翻译注释 '# 源 ' 归零")

func test_avatar_panel_add_theme_override_at_most_one() -> void:
	# 动作 2：add_theme override ≤1（仅允许标题色一处例外，P2 决策留批次 1 统一 variation）
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/avatar_panel.gd")
	var count: int = script_text.count("add_theme_")
	assert_lte(count, 1, "avatar_panel.gd add_theme_ override ≤1（仅标题色例外）")
	if count == 1:
		assert_true(script_text.find("UIConstants.COLOR_TITLE_GOLD") != -1,
			"标题色引用 UIConstants.COLOR_TITLE_GOLD")

func test_avatar_panel_list_is_container() -> void:
	# 动作 5：_list 用 VBoxContainer 容器管理动态项（符合 P1 容器模式）
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/avatar_panel.gd")
	assert_true(script_text.find("VBoxContainer") != -1, "_list 用 VBoxContainer 容器")

func test_avatar_panel_uses_ui_constants() -> void:
	# 动作 3：魔法常量归位——通用设计值引用 UIConstants 设计系统
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/avatar_panel.gd")
	assert_true(script_text.find("UIConstants") != -1, "引用 UIConstants 设计系统")

func test_avatar_panel_signals_all_code_connected() -> void:
	# 动作 6：信号策略 P2——所有信号代码 connect，无 editor 连（grep 不出 editor 连特征，
	# 简化断言：connect 关键字存在即代码连）
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/avatar_panel.gd")
	assert_true(script_text.find("connect") != -1, "信号代码 connect（P2 默认规则）")

func test_avatar_panel_static_node_unique_name() -> void:
	# 动作 4：节点静态化——%AvatarList unique_name 在 .tscn 内
	var tscn_text: String = FileAccess.get_file_as_string("res://scenes/ui/avatar_content.tscn")
	assert_true(tscn_text.find("AvatarList") != -1, "avatar_content.tscn 含 AvatarList 节点")
	assert_true(tscn_text.find("unique_name_in_owner") != -1,
		"avatar_content.tscn 节点标记 unique_name_in_owner")

# 九宫格 capInsets 公式守卫（批 2 Task 8）：源 ofavatar.lua:112 CCRectMake(100,0,304,12)，
# detail_title_bg 643×15 → left=100/bottom=0/right=239/top=3。批 1 fde903b 公式：
# top=H-y-h / bottom=y（水平不反转）。曾发生 top=y/bottom=H-y-h 互换（批 1 同族错误）。

func test_avatar_panel_title_bg_cap_formula() -> void:
	# 正确公式形态：top 用 H-y-h（贴图高减 cap 顶），bottom 直接用 cap y
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/avatar_panel.gd")
	assert_true(script_text.contains("patch_margin_bottom = int(TITLE_BG_CAP.position.y)"),
		"margin_bottom 须为 y 形态（防 top/bottom 互换回退）")
	assert_true(script_text.contains("patch_margin_top = int(bg_tex.get_height() - TITLE_BG_CAP.position.y - TITLE_BG_CAP.size.y)"),
		"margin_top 须为 H-y-h 形态（防 top/bottom 互换回退）")
