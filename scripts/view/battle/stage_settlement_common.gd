class_name StageSettlementCommon
extends RefCounted

## 结算弹窗公共逻辑（View 层 helper）— 抽 stage_done_scene / stage_failed_scene 的重复逻辑。
## 照项目既定 helper 范式（BattleHudAssembler / task_query）：extends RefCounted + static 方法。
## 封装：容错加载/bg 资源/"数据"文案/战斗统计面板/回主菜单 + 两场景共享常量。
## 各场景保留自己的位置常量（SIZE/LABEL_OFFSET/POS 差异）与独有逻辑（hero icon / prompt 谓词）。

const ALPHA_HVGA_DIR: String = "res://assets/ui/alpha/HVGA/"
const SOURCE_UI_PREFIX: String = "UI/alpha/HVGA/"
const MAIN_SCENE_PATH: String = "res://scenes/main_menu/main_scene.tscn"
# 战斗统计按钮贴图（两场景相同的 3 个；位置 SIZE/LABEL_OFFSET/POS 各场景自留）。
const BATTLE_STATIST_TEX: String = "herodetail-upgrade.png"
const BATTLE_STATIST_PRESS_TEX: String = "herodetail-upgrade-mask.png"
const BATTLE_STATIST_CAP: Rect2 = Rect2(20.0, 20.0, 20.0, 20.0)


# 容错纹理加载（照源 stage_done/failed _load：缺图返回 null 不报错）。
static func load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


# bg 资源：StageAccount.get_battle_bg_res 返源路径 "UI/alpha/HVGA/xxx.png" → 转 res://assets/...
static func load_battle_bg(stage_id: int, cm: ConfigManager) -> Texture2D:
	var src_path: String = StageAccount.get_battle_bg_res(stage_id, cm)
	return load_texture(src_path.replace(SOURCE_UI_PREFIX, ALPHA_HVGA_DIR))


# 战斗统计按钮 "数据"文案（照源 _statist_label_text；cm 缺失兜底"数据"）。
static func statist_label_text(cm: ConfigManager) -> String:
	if cm != null:
		return str(cm.get_lstr("STAGEDONE.DATA"))
	return "数据"


# 战斗统计面板弹出（照源 _on_battle_statist_pressed：全屏模态挂 parent，setup 后自管理）。
static func show_battle_statistics(parent: Node, cm: ConfigManager) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var panel := BattleStatisticsPanel.new()
	parent.add_child(panel)
	panel.setup(Array(GameData.last_result.get("unit_list", [])), cm)


# 回主菜单（照源 done/failed 4 个按钮处理：音效 + change_scene）。
# sfx_name 默认 common_click_feedback；个别按钮源 nil 不播可传 ""。
static func goto_main_scene(sfx_name: String = "common_click_feedback") -> void:
	if sfx_name != "":
		AudioPlayer.play_sfx(sfx_name)
	SceneManager.change_scene(MAIN_SCENE_PATH)


# 重试跳转目标（源 stagedone.lua:93 doClickReplay / stagefailed.lua:42 doClickBack →
# replaceScene(stagedetail)：回关卡详情可再开战）。
# ch203 lich 段（50022-50030）→ 回 LichMapPanel 并定位该关（该面板即副本详情/入口，
# 2026-10-10 用户反馈"结算点继续回主城两眼一黑"接通）；其余 dungeon 本项目无独立详情
# 面板 → 空 target 保持回主界面（受控简化）；源 hasTriggerShop 弹商店分支无 trigger
# shop 系统不实现。PVP（sid=-1）源 replay 按钮胜利页 isKeyStage=false 天然隐藏 /
# 失败页 arena_mode 隐藏，无跳转目标。
# 范围与 lich_map_panel.GROUP_IDS（50008-10 组 = 9 base 关）同源；StageDungeon 表实测
# lich 段恰为 50022-50030（难度变体共用 base sid）。
const LICH_SID_MIN: int = 50022
const LICH_SID_MAX: int = 50030


static func _is_lich_stage(stage_id: int) -> bool:
	return stage_id >= LICH_SID_MIN and stage_id <= LICH_SID_MAX


static func replay_target(stage_id: int) -> Dictionary:
	if _is_lich_stage(stage_id):
		return {"target": "lichmap", "stage_id": stage_id}
	if StageAccount.is_dungeon_stage(stage_id) or stage_id == StageAccount.ARENA_STAGE_ID:
		return {}
	return {"target": "stagedetail", "stage_id": stage_id}


# 下一关跳转目标（源 stagedone.lua:111 doClickNext → popScene + WinBackToSelect → 选关）。
# ch203 lich 段 → 回 LichMapPanel（可再开战/换难度/换 Boss，源 dungeon 打完回副本地图等价，
# 2026-10-10 用户反馈"结算点继续回主城两眼一黑"接通）。
# PVP（sid=-1）源 next 恒可见（stagedone.lua:577），点击 popScene 回**发起场景**=pvp 面板
# （WinBackToSelect 监听在 stageselect 未开时 no-op；2026-10-09 修正：旧注释把 popScene 理解为
# 回主城致「战斗完大退主界面」用户报修，2026-09-13 修正时误把 PVP 修成空目标）。
static func next_target(stage_id: int) -> Dictionary:
	if _is_lich_stage(stage_id):
		return {"target": "lichmap", "stage_id": stage_id}
	if StageAccount.is_dungeon_stage(stage_id):
		return {}
	if stage_id == StageAccount.ARENA_STAGE_ID:
		return {"target": "ladder"}
	return {"target": "stageselect"}


# PVP 失败页 menu 按钮（源 stagefailed.lua:34-38 doClickMenu → popScene 回发起场景=pvp 面板；
# 2026-10-09 补：旧实现恒回主城，同属 popScene 语义误读）。
static func pvp_menu_back() -> void:
	GameData.pending_stage_result = {"target": "ladder"}
	goto_main_scene()


# 结算页按钮统一跳转：存 pending（main_scene._maybe_resume_stage_result 消费重弹面板）+ 回主界面。
static func replay_stage(stage_id: int) -> void:
	GameData.pending_stage_result = replay_target(stage_id)
	goto_main_scene()


static func next_stage(stage_id: int) -> void:
	GameData.pending_stage_result = next_target(stage_id)
	goto_main_scene()
