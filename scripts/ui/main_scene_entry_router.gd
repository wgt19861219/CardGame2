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


# 装备强化入口（源 create:1994-2165 无默认英雄：nohead 占位 + doTalk「请选择英雄」，
# 玩家点「选择英雄」→ doChangeHero → selectwindow 列全部拥有英雄。2026-09-08 四轮
# 用户指示「窗口不要默认放船长/不放默认英雄」→ 对齐源传 null 未选态）。
static func open_equip_strengthen(scene: Node) -> void:
	var p: PlayerData = GameData.player
	if p.hero_manager.heroes.is_empty():
		Toast.show_message("没有英雄，无法进入装备强化")
		return
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(null, GameData.config, p)
	panel.show_window(scene)


# 每日登录奖励入口。
static func open_daily_login(scene: Node) -> void:
	var panel := DailyLoginPanel.new("daily_login", {})
	panel.setup_panel(GameData.player)
	panel.show_window(scene)


# 公会入口（源该按钮联机打开公会界面，guild handler 在 SKIPPED_HANDLERS 单机裁剪清单）。
# 2026-09-13 用户拍板②：恢复公会名义——图鉴有背包面板专属入口（PackagePanel %HandbookBtn），
# 主城建筑不再兼任图鉴。单机无公会面板，点击 Toast 提示（对应源未解锁分支 showToast 语义）。
static func open_guild(scene: Node) -> void:
	Toast.show_message("公会功能未开放")


# 日常任务入口。用 player 持久化 task_manager（2026-09-03 根修任务不显示：临时
# TaskManager.new() 恒空 + 领奖写临时实例不落存档；面板 fill 前 sync_current_tasks 发现任务）。
static func open_task(scene: Node, p_kind: String = "task") -> void:
	var tm: TaskManager = GameData.player.task_manager
	var panel := TaskPanel.new(p_kind, {})
	panel.setup_panel(GameData.player, GameData.config, tm, p_kind)
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


# 资源副本难度弹窗入口（源 degreeWindow.create(key)）。2026-09-12 二轮：源终版
# exercise.create 直转 dungeon_map 后资源试炼在源无入口（degreeWindow 死代码）；
# 本项目保留已验收组件 + 此公共入口 helper，待入口挂载设计拍板（见任务看板）。
static func open_exercise_degree(scene: Node, key: String) -> void:
	var panel := ExerciseDegreePanel.new("exerciseDegree", {})
	panel.setup_panel(key, GameData.player, GameData.player.stage_manager)
	panel.show_window(scene)


# 副本入口（dungeon groups 数据转换 Array → Array[int]）。em=英雄试炼 50005-7 /
# equip=装备副本 50001-4（照源 exercise.create 终版直转的 groupIds）。
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
