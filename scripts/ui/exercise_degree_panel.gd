class_name ExerciseDegreePanel
extends PopWindow

## 资源副本难度选择弹窗（View 层）— 源 exercise.lua degreeWindow.create(:692-770)。
##
## exp/money/int/agi/str（ActStageGroup 20001-20005 经验/金币/智力/敏捷/力量试炼）入口
## 专用；em/equip（英雄/装备副本）仍走 DungeonMapPanel。2026-09-12 修复：旧实现 5 个
## 资源入口误走 dungeon_map（get_dungeon_bosses 期望数组 Stages，资源组是字典 → 迭代
## 字典键生成假 boss，实机开图标题「装备副本」+ 假站位节点）。
##
## 直译与裁剪：
## - 框架（蒙层/frame/close/title）与 createDegree 4 难度槽照源；难度标题图
##   act_select_difficulty_*_1/2.png 与 act_select_lock.png 源资源库缺失 → 文字 Label
##   替代（锁定态显示「Lv N」，比源 lock 图多解锁等级信息）。
## - CD 倒计时板裁剪：ActStageGroup CD 字段全表实测 0，无倒计时语义；次数行保留。
## - 进战斗照源 doGotoStage(:126-149) 检查链（等级/次数/体力）→ stagedetail
##   （本项目 StageDetailPanel 子弹窗叠放，源 pushScene 保留 degree 层语义一致）。
## - 计次在 Logic 层（源 battle_engine.lua:1128 胜利结算 addActTimes，本项目
##   StageDungeonLogic.record_act_win 于 exit_stage 胜利分支；进战斗只校验），
##   本面板只读展示（源客户端同款：getLeftTimes 读、服务端记）。
## - heroLimit（20005 Gender 必须女性英雄，源 createForExercise 传参）：2026-09-19
##   照源回归补全——经 StageDetailPanel 透传 BattlePreparePanel.hero_limit 过滤
##   可选英雄（Unit 表 Gender 字段原键比较，源 readhero.getAllListWithLimit）。
##
## 两件套范式：完整静态树进 exercise_degree_content.tscn（无脚本），本文件只做业务 +
## 信号 connect + fill。弹窗是短蒙层弹窗，不设 hud_identity（沿用父级，源为 exercise
## 场景内子弹窗，不切 HUD）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/exercise_degree_content.tscn")

const DEGREE_COUNT: int = 4
const DEGREE_LABELS: Array = ["难度 I", "难度 II", "难度 III", "难度 IV"]
const LOCK_TEXT_FMT: String = "Lv %d"
# 源 setSpriteGray（resource_manager.lua:871-877）= ccc3(100,100,100)+opacity 180
# （dungeon_map_panel 同款先例）。
const GRAY_MODULATE := Color(100.0 / 255.0, 100.0 / 255.0, 100.0 / 255.0, 180.0 / 255.0)
# LSTR key（源 LSTR 宏，cm.get_lstr 解析，无命中返 key 本身 → fallback 同步 zh-CN 值）
const LSTR_TITLE: String = "EXERCISE.PLEASE_SELECT_DIFFICULTY_LEVEL"
const LSTR_TITLE_FALLBACK: String = "选择难度"
const LSTR_TIMES: String = "EXERCISE.REMAINING_TIMES_FOR_TODAY_"
const LSTR_TIMES_FALLBACK: String = "今日剩余次数:"
const LSTR_NO_TIMES: String = "EXERCISE.YOUVE_REACHED_OUT_THE_MAXIMUM_NUMBERS_TODAY"
const LSTR_NO_TIMES_FALLBACK: String = "今日次数已用完"

var key: String = ""
var player: PlayerData = null
var mgr: StageManager = null
var _stages: Array = []            # [{id, vit}]（ExerciseManager.get_stages 升序）
var _content: Control = null
var _slot_btns: Array[TextureButton] = []
var _slot_icons: Array[TextureRect] = []
var _slot_titles: Array[Label] = []


func setup_panel(p_key: String, p_player: PlayerData, p_mgr: StageManager) -> void:
	key = p_key
	player = p_player
	mgr = p_mgr
	var em := ExerciseManager.new()
	em.setup(player.cm)
	_stages = em.get_stages(key)
	setup()
	_build_content()


func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	# 标题：源 title 固定「选择难度」（组入口名由调用方语境区分，弹窗内不重复）。
	(_content.get_node("%Title") as Label).text = _lstr(LSTR_TITLE, LSTR_TITLE_FALLBACK)
	_slot_btns.clear()
	_slot_icons.clear()
	_slot_titles.clear()
	for i in range(1, DEGREE_COUNT + 1):
		var btn := _content.get_node("%Slot" + str(i)) as TextureButton
		_slot_btns.append(btn)
		_slot_icons.append(_content.get_node("%Slot" + str(i) + "Icon") as TextureRect)
		_slot_titles.append(_content.get_node("%Slot" + str(i) + "Title") as Label)
		btn.pressed.connect(_on_slot_pressed.bind(i - 1))
	_fill_slots()
	_fill_times()


## 槽 fill（源 createDegree :449-560 + setSpriteGray 锁定分支）：vit 数字 / 解锁灰化 /
## 锁定标题换「Lv N」（源 lock 图缺失的文字替代）。数据不足 4 槽（表配置缺）时隐藏。
func _fill_slots() -> void:
	var cm: Variant = player.cm
	for i in range(DEGREE_COUNT):
		var btn := _slot_btns[i]
		if i >= _stages.size():
			btn.visible = false
			_slot_icons[i].visible = false
			_slot_titles[i].visible = false
			continue
		var s: Dictionary = _stages[i]
		var sid: int = int(s["id"])
		var unlock_level: int = int(cm.get_int(&"Stage", sid, &"Unlock Level"))
		var unlocked: bool = unlock_level <= player.team_level
		(_content.get_node("%Slot" + str(i + 1) + "VitNum") as Label).text = str(int(s["vit"]))
		btn.modulate = GRAY_MODULATE if not unlocked else Color(1, 1, 1, 1)
		_slot_icons[i].modulate = btn.modulate
		_slot_titles[i].text = DEGREE_LABELS[i] if unlocked else LOCK_TEXT_FMT % unlock_level


## 次数行 fill（源 createcdBoard :383-432 else 分支；次数用尽文案 :344-352）。
func _fill_times() -> void:
	var left: int = _left_times()
	var title_label := _content.get_node("%TimesTitle") as Label
	var num_label := _content.get_node("%TimesNumber") as Label
	if left <= 0:
		title_label.text = _lstr(LSTR_NO_TIMES, LSTR_NO_TIMES_FALLBACK)
		num_label.text = ""
	else:
		title_label.text = _lstr(LSTR_TIMES, LSTR_TIMES_FALLBACK)
		num_label.text = str(left)


func _lstr(lstr_key: String, fallback: String) -> String:
	var t: String = String(player.cm.get_lstr(lstr_key))
	return t if t != lstr_key else fallback


## 剩余次数（源 getLeftTimes = DailyLimit - getActTimes；act_times 与 dungeon 共用，
## check_act_times_daily_reset 跨日清零）。
func _left_times() -> int:
	StageDungeonLogic.check_act_times_daily_reset(mgr, int(Time.get_unix_time_from_system()))
	var em := ExerciseManager.new()
	em.setup(player.cm)
	var sgid: int = int(ExerciseManager.ENTRY_STAGE.get(key, 0))
	return maxi(0, em.get_daily_limit(key) - int(mgr.act_times.get(sgid, 0)))


## 进战斗检查链照源 doGotoStage(:126-149)：等级 → 次数 → 体力 → stagedetail。
func _on_slot_pressed(idx: int) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	if idx >= _stages.size():
		return
	var s: Dictionary = _stages[idx]
	var sid: int = int(s["id"])
	var cm: Variant = player.cm
	var unlock_level: int = int(cm.get_int(&"Stage", sid, &"Unlock Level"))
	if unlock_level > player.team_level:
		# Toast 文案项目自定（dungeon_map._enter_error_text 先例；LSTR key 含 %d 格式化
		# 与无命中回退交织，不值当——中文值即源 zh-CN 语义）。
		Toast.show_message("战队 %d 级开放" % unlock_level)
		return
	if _left_times() <= 0:
		Toast.show_message(LSTR_NO_TIMES_FALLBACK)
		return
	if player.vitality < int(s["vit"]):
		# 源 showHandyDialog("buyVitality") → 单机 toast（无充值弹窗）。
		Toast.show_message("体力不足")
		return
	var detail := StageDetailPanel.new("stagedetail", {})
	# heroLimit（源 createForExercise :143-147 传 {heroLimit=组 Limit Type/Detail}；20005 组
	# Gender=ACTSTAGEGROUP.FEMALE 限女性英雄，Unit 表 Gender 字段原键比较）透传布阵过滤。
	var em2 := ExerciseManager.new()
	em2.setup(player.cm)
	detail.setup_panel(sid, mgr, player, BattleRng.new(randi()), em2.get_hero_limit(key))
	detail.show_window(self)
