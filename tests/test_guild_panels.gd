extends GutTest
# 公会一期 View 守卫（2026-09-19）：三组两件套 tscn 结构（% 唯一名）+ panel fill 数据绑定
# + feature_catalog 翻转守卫（guild 移入 DOMAINS）。
# panel 测试全用自建 PlayerData（dungeon e2e 判例：不碰共享 GameData.player）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_pd(level: int = 80) -> PlayerData:
	var pd := PlayerData.new(cm)
	pd.team_level = level
	return pd


# ── tscn 结构守卫（% 唯一名齐全，防重命名断链）───────────────────────

func test_guild_join_content_structure() -> void:
	var scene: PackedScene = load("res://scenes/ui/guild_join_content.tscn")
	var root := scene.instantiate() as Control
	add_child_autofree(root)
	for node_name: String in ["CloseBtn", "Title", "TabJoin", "TabFind", "TabCreate", "TabLight",
			"JoinView", "Rows", "EmptyLabel", "FindView", "IdInput", "SearchBtn", "ResultHost",
			"CreateView", "NameInput", "IconGrid", "CreateBtn"]:
		assert_ne(root.get_node_or_null("%%%s" % node_name), null, "%%%s 存在" % node_name)


func test_guild_content_structure() -> void:
	var scene: PackedScene = load("res://scenes/ui/guild_content.tscn")
	var root := scene.instantiate() as Control
	add_child_autofree(root)
	for node_name: String in ["CloseBtn", "Title", "Icon", "GuildName", "IdLabel", "SloganLabel",
			"MemberLabel", "VitalityLabel", "LeaveBtn", "SortLoginBtn", "SortActiveBtn",
			"SortInstanceBtn", "Rows", "ShopBtn", "WorshipBtn", "WorshipTag"]:
		assert_ne(root.get_node_or_null("%%%s" % node_name), null, "%%%s 存在" % node_name)


func test_guild_worship_content_structure() -> void:
	var scene: PackedScene = load("res://scenes/ui/guild_worship_content.tscn")
	var root := scene.instantiate() as Control
	add_child_autofree(root)
	for node_name: String in ["Title", "CloseBtn", "HeadHost", "TargetLabel", "TimesLabel",
			"Opt1", "Opt2", "Opt3", "PendingLabel", "ClaimBtn"]:
		assert_ne(root.get_node_or_null("%%%s" % node_name), null, "%%%s 存在" % node_name)


func test_guild_item_templates_structure() -> void:
	var join_item := (load("res://scenes/ui/guild_join_item.tscn") as PackedScene).instantiate() as Control
	add_child_autofree(join_item)
	for node_name: String in ["Icon", "Name", "Slogan", "LevelLimit", "JoinType", "JoinBtn"]:
		assert_ne(join_item.get_node_or_null("%%%s" % node_name), null, "join item %%%s 存在" % node_name)
	var member_item := (load("res://scenes/ui/guild_member_item.tscn") as PackedScene).instantiate() as Control
	add_child_autofree(member_item)
	for node_name: String in ["HeadHost", "Name", "Level", "JobTag", "Desc", "WorshipBtn"]:
		assert_ne(member_item.get_node_or_null("%%%s" % node_name), null, "member item %%%s 存在" % node_name)


# ── GuildJoinPanel fill（三 tab + NPC 列表 5 行 + 图标网格 20）────────

func test_guild_join_panel_fills_npc_list() -> void:
	var host: Control = add_child_autofree(Control.new())
	var panel := GuildJoinPanel.new("guild_join", {})
	panel.setup_panel(_make_pd(), GuildManager.new(cm))
	panel.show_window(host)
	await get_tree().process_frame
	var content: Control = panel.container.get_child(panel.container.get_child_count() - 1)
	var rows: VBoxContainer = content.get_node("%Rows") as VBoxContainer
	assert_eq(rows.get_child_count(), 5, "NPC 公会列表 5 行")
	var first: Control = rows.get_child(0)
	assert_eq((first.get_node("%Name") as Label).text, "英雄殿堂 (9人)", "首行名+人数（源列表格式）")
	var grid: GridContainer = content.get_node("%IconGrid") as GridContainer
	assert_eq(grid.get_child_count(), 20, "创建图标 20 个候选（受控偏离：源 289）")
	assert_true(content.get_node("%JoinView").visible, "默认加入公会 tab")
	assert_false(content.get_node("%CreateView").visible, "创建 tab 默认隐藏")
	panel.remove_window()


# ── GuildPanel fill（头部 + 9 成员 + 膜拜按钮等级显隐）───────────────

func test_guild_panel_fills_head_and_members() -> void:
	var host: Control = add_child_autofree(Control.new())
	var pd := _make_pd(80)
	var mgr := GuildManager.new(cm)
	mgr.join_guild(pd, 10001)
	var panel := GuildPanel.new("guild", {})
	panel.setup_panel(pd, mgr, BattleRng.new(12345))
	panel.show_window(host)
	await get_tree().process_frame
	var content: Control = panel.container.get_child(panel.container.get_child_count() - 1)
	assert_eq((content.get_node("%GuildName") as Label).text, "英雄殿堂", "公会名 fill")
	assert_eq((content.get_node("%VitalityLabel") as Label).text, "5000", "活跃 5000 基值 fill")
	var rows: VBoxContainer = content.get_node("%Rows") as VBoxContainer
	assert_eq(rows.get_child_count(), 9, "成员 9 行（玩家+8 NPC）")
	# 等级显隐口径（源 guild.lua:257）：玩家 80 级 → 可膜拜 lv>=81 的 NPC（90/88/85/82 四名）。
	var worship_visible: int = 0
	var player_job: String = ""
	for c in rows.get_children():
		var row := c as Control
		if (row.get_node("%WorshipBtn") as Button).visible:
			worship_visible += 1
		if (row.get_node("%Name") as Label).text == pd.player_name:
			player_job = (row.get_node("%JobTag") as Label).text
	assert_eq(worship_visible, 4, "80 级玩家 4 个可膜拜 NPC（90/88/85/82 级）")
	assert_eq(player_job, "会长", "玩家行职位=会长（chairman）")
	panel.remove_window()


# ── GuildWorshipPanel fill（三档文案 + VIP 锁定 disabled）────────────

func test_guild_worship_panel_fills_options() -> void:
	var host: Control = add_child_autofree(Control.new())
	var pd := _make_pd(80)
	var mgr := GuildManager.new(cm)
	mgr.join_guild(pd, 10001)
	var member: Dictionary = {"uid": 9001, "name": "亚历山大", "level": 90, "avatar": 10, "job": "elder"}
	var panel := GuildWorshipPanel.new("guild_worship", {})
	panel.setup_panel(pd, mgr, member)
	panel.show_window(host)
	await get_tree().process_frame
	var content: Control = panel.container.get_child(panel.container.get_child_count() - 1)
	assert_eq((content.get_node("%TargetLabel") as Label).text, "亚历山大 Lv.90", "膜拜对象 fill")
	assert_true((content.get_node("%Opt1") as Button).text.contains("免费"), "档 1 免费文案")
	assert_true((content.get_node("%Opt2") as Button).text.contains("金币"), "档 2 金币文案")
	assert_true((content.get_node("%Opt3") as Button).disabled, "档 3 VIP0 锁定 disabled（源 rmbWorship）")
	assert_false((content.get_node("%PendingLabel") as Label).visible, "无挂起奖励隐藏")
	panel.remove_window()


# ── feature_catalog 翻转守卫 ────────────────────────────────────────

func test_catalog_guild_flipped_to_domains() -> void:
	var catalog := FeatureCatalog.new()
	assert_true(catalog.DOMAINS.has("guild"), "guild 域存在（2026-09-19 一期翻转）")
	assert_false(catalog.is_skipped("guild"), "guild 不再 SKIPPED")
	assert_true(catalog.is_skipped("chat"), "公会聊天永久裁剪留 SKIPPED")
	assert_true(catalog.is_skipped("request_guild_log"), "公会日志永久裁剪留 SKIPPED")
	assert_eq(catalog.IMPLEMENTATIONS.get("guild"), "GuildManager", "实现映射 GuildManager")
	assert_eq(catalog.total_source_count(), 71, "数学闭合 52+19=71 保持")


# ── 入口路由源码守卫 ────────────────────────────────────────────────

func test_router_open_guild_no_toast_placeholder() -> void:
	# Toast 占位（「公会功能未开放」）已退役，open_guild 按入会态分流两面板。
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/main_scene_entry_router.gd")
	assert_false(src.contains("公会功能未开放"), "Toast 占位文案退役")
	assert_true(src.contains("GuildJoinPanel") and src.contains("GuildPanel"), "分流两面板")
