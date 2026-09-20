class_name ExerciseMapPanel
extends PopWindow

## 旧版试炼地图（经典样式，2026-09-19 复活）— 源 ui/exercise.lua 旧版地图场景
## （git 5ea4ba7~1 死代码：createExerciseButton 入口 + exerciseres.lua 两页配置）。
##
## 与 DungeonMapPanel（远征地图样式）并列双分支（用户拍板「面板内互切按钮」）：
##   em  = 时光之穴页：exp/money 资源本入口 + cavern 英雄副本聚合入口（dg5-7）；
##   equip = 英雄试炼页：int/agi/str 资源本入口 + cavern。
## 主城两建筑默认开本面板（源终版直转 dungeon_map 属另一分支，SwitchStyleBtn 互切）。
##
## 点击流转（照源 doClickExerciseButton :1284-1296）：
##   资源本 → ExerciseDegreePanel（4 难度窗，2026-09-19 起生产入口挂载）。
##   dg1-4 装备本名牌（二轮）/cavern 英雄本聚合名牌（四轮）均系源后补补丁非原版
##   行为，已按用户指示去除——装备本 50001-4 与英雄本 50005-7 入口全留远征样式侧
##   互切可达；cavern 子窗/DungeonMatrixPopup 组件保留待挂载（ExerciseDegreePanel
##   「待入口挂载」同款先例）。四轮并去中央区背景色块与资源本名牌（源 pristine
##   版入口即纯角色立绘，标识靠失传的弹窗标题图）。
##
## 受控偏离：地图背景/标题图失传替身方案见 exercise_map_content.tscn 头注；
## equip 页 cavern 源半出屏位移右上空区；源 checkExerciseEnabled 终版恒 true
## → 无星期判定/禁用态（detailWindow 不做，源终版不可达）。
## 入口角色 = anim_frames 帧动画（源 .cha 骨骼的资源等价物），fca 挂 content 根
## 场景坐标系直译（坐标细节见 ENTRY_FCAS 注释）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/exercise_map_content.tscn")
const FcaAnimation := preload("res://scripts/ui/fca_animation.gd")
const AtlasSprite := preload("res://scripts/ui/atlas_sprite.gd")

const ANIM_FRAMES_DIR: String = "res://assets/anim_frames/"
const IDLE_ACTION: String = "Idle"
# 入口角色基准显示缩放（bridge 实机校准：1.1 时 97-102 逻辑像素高贴下限 → 1.25 取 ~115-125）
const ENTRY_FCA_SCALE: float = 1.25
# MapLayer 裁剪区原点（场景 (44,90)）：fca 挂 MapLayer 内，fill 坐标 = 源直译 - 原点
const MAP_LAYER_ORIGIN := Vector2(44.0, 90.0)
const MODE_TITLES: Dictionary = {"em": "时光之穴", "equip": "英雄试炼"}
# 互切目标组（切远征样式时按模式带出对应 boss 组）
const EM_MODE_GROUPS: Array[int] = [50005, 50006, 50007]
const EQUIP_MODE_GROUPS: Array[int] = [50001, 50002, 50003, 50004]
const EM_RESOURCE_KEYS: Array[String] = ["exp", "money"]
const EQUIP_RESOURCE_KEYS: Array[String] = ["int", "agi", "str"]
# 源 exerciseres.lua fca 配置直译：[资源名, 场景坐标(to_godot 后), scale]
# exp(178,150)/(234,156) money(560,210) int(180,168) agi(392,197)
# str(623,197)/(654,162)/(600,162)，y=480-cocos_y
const ENTRY_FCAS: Dictionary = {
	"exp": [["NagaPriest", Vector2(178.0, 330.0), 1.0], ["NagaArcher", Vector2(234.0, 324.0), 1.0]],
	"money": [["Tank", Vector2(560.0, 270.0), 1.0]],
	"int": [["Golem", Vector2(180.0, 312.0), 0.8]],
	"agi": [["DragonBaby", Vector2(392.0, 283.0), 0.8]],
	"str": [["DR", Vector2(623.0, 283.0), 0.9], ["Ench", Vector2(654.0, 318.0), 0.9], ["WR", Vector2(600.0, 318.0), 0.9]],
}
var player: PlayerData = null
var stage_manager: StageManager = null
var rng: BattleRng = null
var mode: String = ""
var _content: Control = null

func setup_panel(p_player: PlayerData, p_stage_manager: StageManager, p_rng: BattleRng, p_mode: String) -> void:
	hud_identity = "exerciseMap"   # 场景模拟型（dungeonMap 同款）：不遮蔽 HUD 切 identity
	transparent_shade = true   # content 自带全屏 FrameworkBg（dungeonMap 同款）
	player = p_player
	stage_manager = p_stage_manager
	rng = p_rng
	mode = p_mode
	setup()
	_build_content()

func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	var is_em: bool = mode == "em"
	(_content.get_node("%TitleLabel") as Label).text = String(MODE_TITLES.get(mode, ""))
	(_content.get_node("%EmGroup") as Control).visible = is_em
	(_content.get_node("%EquipGroup") as Control).visible = not is_em
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	(_content.get_node("%SwitchStyleBtn") as BaseButton).pressed.connect(_on_switch_pressed)
	_bind_resource_entries()
	_spawn_entry_fcas()

func _bind_resource_entries() -> void:
	var keys: Array[String] = EM_RESOURCE_KEYS if mode == "em" else EQUIP_RESOURCE_KEYS
	var btn_names: Dictionary = {
		"exp": "%ExpBtn", "money": "%MoneyBtn", "int": "%IntBtn", "agi": "%AgiBtn", "str": "%StrBtn",
	}
	for key in keys:
		var btn := _content.get_node(String(btn_names.get(key, ""))) as BaseButton
		if btn != null:
			btn.pressed.connect(_on_resource_pressed.bind(key))

func _lstr(lstr_key: String) -> String:
	var t: String = String(player.cm.get_lstr(lstr_key))
	return t if t != lstr_key else lstr_key

func _spawn_entry_fcas() -> void:
	var host: Control = _content.get_node("%FcaLayer") as Control
	var keys: Array = EM_RESOURCE_KEYS if mode == "em" else EQUIP_RESOURCE_KEYS
	for key in keys:
		for cfg in ENTRY_FCAS.get(key, []):
			_spawn_fca(host, cfg)

func _spawn_fca(host: Control, cfg: Array) -> void:
	var res_name: String = String(cfg[0])
	var atlas := AtlasSprite.new()
	if not atlas.load_atlas(ANIM_FRAMES_DIR + res_name + "/sheet.plist"):
		atlas.unload()
		return
	var fca := FcaAnimation.new()
	if not fca.load_from_ani(res_name, atlas):
		fca.queue_free()
		return
	var parts := Node2D.new()
	parts.position = (cfg[1] as Vector2) - MAP_LAYER_ORIGIN
	var fca_scale: float = ENTRY_FCA_SCALE * float(cfg[2])
	parts.scale = Vector2(fca_scale, fca_scale)
	parts.add_child(fca)
	host.add_child(parts)
	if fca.has_action(IDLE_ACTION):
		fca.play(IDLE_ACTION)

# ── 点击流转（照源 doClickExerciseButton）──

## 资源本入口 → 4 难度窗（源 degreeWindow.create(key)）
func _on_resource_pressed(key: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var panel := ExerciseDegreePanel.new("exerciseDegree", {})
	panel.setup_panel(key, player, stage_manager)
	panel.show_window(self)

func _on_switch_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var host: Node = get_parent()
	var groups: Array[int] = EM_MODE_GROUPS if mode == "em" else EQUIP_MODE_GROUPS
	remove_window()
	if host != null:
		MainSceneEntryRouter.open_dungeon_groups(host, mode, groups)
