class_name MainSceneEntryRouter
extends RefCounted

## MainScene 入口路由 helper（批次 1 第 4 拆分 2026-07-25）。
## 从 main_scene.gd 外迁的 20 个 _open_* 入口函数，全 static + scene: Node 参数化
## （对齐 task_row_builder/hero_detail_equip_slots/midas_fills 范式）。
## autoload（GameData/Toast/SceneManager）全局访问；self 经 scene 参数传入。
## 不反向引用 main_scene（main_scene 无 class_name，scene 用 Node 弱类型）。
## 7 个被 task_query.FAST_ROUTE 反射调的方法，main_scene 留薄包装转发本 helper。


# 天梯/PVP 入口。
static func open_ladder(scene: Node) -> void:
	var panel := LadderPanel.new("ladder", {})
	panel.setup_panel(GameData.player, GameData.player.cm, BattleRng.new(randi()))
	panel.show_window(scene)


# 英雄场景入口（SceneManager 切场景，非弹 panel）。
static func open_hero(scene: Node) -> void:
	SceneManager.change_scene("res://scenes/hero/hero_scene.tscn")


# 头像设置入口。
static func open_avatar(scene: Node) -> void:
	var panel := AvatarPanel.new("avatar", {})
	panel.setup_panel(GameData.player, GameData.config)
	panel.show_window(scene)


# 改名入口。
static func open_name(scene: Node) -> void:
	var panel := NameInputPanel.new("name_input", {})
	panel.setup_panel(GameData.player)
	panel.show_window(scene)


# 点石成金入口。
static func open_midas(scene: Node) -> void:
	var panel := MidasPanel.new("midas", {})
	panel.setup_panel(GameData.player)
	panel.show_window(scene)


# 装备强化入口（含阵容校验，单机化裁剪 select_hero 流程，从 team[0] 作默认 hero）。
static func open_equip_strengthen(scene: Node) -> void:
	var p: PlayerData = GameData.player
	if p.team.is_empty():
		Toast.show_message("阵容为空，无法进入装备强化")
		return
	var hero: HeroInstance = p.hero_manager.get_hero(p.team[0])
	if hero == null:
		Toast.show_message("英雄不存在")
		return
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, GameData.config, p)
	panel.show_window(scene)


# 每日登录奖励入口。
static func open_daily_login(scene: Node) -> void:
	var panel := DailyLoginPanel.new("daily_login", {})
	panel.setup_panel(GameData.player)
	panel.show_window(scene)


# 图鉴入口（单机化自建，源该按钮=公会联机）。
static func open_handbook(scene: Node) -> void:
	var panel := HandbookPanel.new("handbook", {})
	panel.setup_panel(GameData.player)
	panel.show_window(scene)


# 日常任务入口。
static func open_task(scene: Node) -> void:
	var tm := TaskManager.new()
	var panel := TaskPanel.new("task", {})
	panel.setup_panel(GameData.player, GameData.config, tm)
	panel.show_window(scene)


# 排行榜入口（单机 NPC 假榜）。
static func open_ranklist(scene: Node, rank_type: String) -> void:
	var rm := RanklistManager.new()
	var panel := RanklistPanel.new("ranklist", {})
	panel.setup_panel(GameData.player, rm, rank_type)
	panel.show_window(scene)


# 背包入口（package/fragment identity）。
static func open_package(scene: Node, panel_identity: String) -> void:
	var panel := PackagePanel.new(panel_identity, {})
	panel.setup_panel(GameData.config, GameData.player)
	panel.show_window(scene)


# 战役入口（选关 → battle_scene → 结算）。
static func open_stage_select(scene: Node) -> void:
	var mgr := GameData.player.stage_manager
	var rng := BattleRng.new(randi())
	var panel := StageSelectPanel.new("stageselect", {})
	panel.setup_panel(mgr, GameData.player, rng)
	panel.show_window(scene)


# 酒馆入口（抽卡）。
static func open_tavern(scene: Node) -> void:
	var panel := TavernPanel.new("tavern", {})
	panel.setup_panel(GameData.player, BattleRng.new(randi()))
	panel.show_window(scene)


# 远征入口（单机化无 tbc 网络）。
static func open_crusade(scene: Node) -> void:
	var panel := CrusadePanel.new("crusade", {})
	panel.setup_panel(GameData.player, BattleRng.new(randi()))
	panel.show_window(scene)


# 商店入口（shop_id 1 普通/2 地精/3 黑市）。
static func open_shop(scene: Node, shop_id: int) -> void:
	var mgr := ShopManager.new(GameData.config)
	var panel := ShopPanel.new("shop", {})
	panel.setup_panel(shop_id, mgr, GameData.player, BattleRng.new(randi()))
	panel.show_window(scene)


# 星际商店入口（灵魂石货币）。
static func open_star_shop(scene: Node) -> void:
	var mgr := ShopManager.new(GameData.config)
	var panel := StarShopPanel.new("starshop", {})
	panel.setup_panel(mgr, GameData.player, BattleRng.new(randi()))
	panel.show_window(scene)


# 试炼入口选择（ExercisePanel 嵌入子组件，add_child 非 show_window）。
static func open_exercise_panel(scene: Node, on_dungeon_groups: Callable) -> void:
	var panel := ExercisePanel.new()
	panel.set_entry_callback(on_dungeon_groups)
	scene.add_child(panel)


# 副本入口（dungeon groups 数据转换 Array → Array[int]）。
static func open_dungeon_groups(scene: Node, mode: String, groups: Array) -> void:
	var gi: Array[int] = []
	for g in groups:
		gi.append(int(g))
	var panel := DungeonMapPanel.new("dungeonMap", {})
	panel.setup_panel(GameData.player, GameData.player.stage_manager, BattleRng.new(randi()), mode, gi)
	panel.show_window(scene)


# 信箱入口。
static func open_mailbox(scene: Node) -> void:
	var panel := MailPanel.new("mailbox", {})
	panel.setup_panel(GameData.player)
	panel.show_window(scene)


# 藏宝地穴入口（excavate_data 空 → Search；非空 → Map）。
static func open_excavate(scene: Node) -> void:
	if GameData.player.excavate.get_data_list().is_empty():
		var sp := ExcavateSearchPanel.new("excavate", {})
		sp.setup_panel(GameData.player, BattleRng.new(randi()))
		sp.show_window(scene)
	else:
		var mp := ExcavateMapPanel.new("excavate_map", {})
		mp.setup_panel(GameData.player, BattleRng.new(randi()))
		mp.show_window(scene)
