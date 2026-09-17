class_name StageDetailPanel
extends PopWindow

## 关卡详情（View 层）— 照源 stagedetail.lua create:1536-1934 完整复刻。
## 两件套（2026-08-16 批3 Task 6）：base 层静态节点固化进 stage_detail_content.tscn
## （编辑器所见即所得），本类只做业务 + 信号 connect + fill（% 取节点填动态数据）
## + 敌方阵容/奖励/星动态内容（数据驱动建节点）。原独立 builder 构造器文件已退役删除，
## 其 fill/动态逻辑并入本类。本项目单机化 pushScene→PopWindow，shade 透明 +
## .tscn %FrameworkBg 补 bg.jpg 还原源视觉。关卡名标题 2026-09-03 改弹窗内自建
## %MapTitleBg+%StageTitle（源 :1620-1646；旧"复用父面板章节标题栏"方案被全屏
## FrameworkBg 盖住致实机标题不可见）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/stage_detail_content.tscn")
const TEAM_MAX: int = 5
# 扫荡次数上限（源 parameter.lua:20-21 default_normal/elite_sweep_times）。
const SWEEP_DEFAULT_NORMAL: int = 10
const SWEEP_DEFAULT_ELITE: int = 3
# 无限制扫荡上限（源 getRepeatInformation:237-238：countLimit==0 → cLimit=999）。
const SWEEP_UNLIMITED: int = 999

# 坐标换算（源 cocos 800×480 左下原点 → Godot 800×480 左上原点）。
const OFFSET_X: float = 0.0
const BASE_Y: float = 480.0
# 次数数字色（源 checkEnabled:785-794 toccc3(16114110)/toccc3(16737841)）。
const C_NUM: Color = Color(245.0 / 255.0, 225.0 / 255.0, 190.0 / 255.0)
const C_DISABLE: Color = Color(1.0, 102.0 / 255.0, 49.0 / 255.0)

const UI_DIR: String = "res://assets/ui/alpha/HVGA/"
const BOSS_TAG_RES: String = UI_DIR + "stagedetail_boss_tag.png"
# boss 标签源点尺寸 77.27×42.93（99×55px÷CS）；Sprite2D 按纹理原像素渲染须 scale 补偿。
const INV_CS: float = 1.0 / 1.28125
# 敌方阵容（源 createEnemy:1142-1192）：boss 边长 80 / 普通 70（cocos 点）。
# ⚠️缩放分母是源 container 实际点尺寸 81.25 = DGSizeMake(104,104)（readnode.lua:19-23
# 104×0.78125），非 104——104 是设计空间名义值。旧分母 104 致头像整体偏小 1.28×
# （2026-09-03 实机对照根修：源 setScale(70/bg:getContentSize().width)=70/81.25）。
const ENEMY_CONTAINER: float = 81.25
# 源 container 中心（距底 81.25/2=40.625）在 ReadheroIcon 104 设计空间的 y = 104-40.625，
# 用于把 icon 的源 container 中心对准 wrapper 中心（两空间 portrait 底对底对齐）
const ENEMY_SRC_CENTER_Y: float = 63.375
const ENEMY_LEN_NORMAL: float = 70.0
const ENEMY_LEN_BOSS: float = 80.0
const ENEMY_BOSS_OX: float = 5.0  # 源 :1169 boss 额外偏移
# boss 标签源 :1179-1181 createSprite 默认 anchor(0.5,0.5) 中心 ccp(52,20)（距 container 底 20）
# → Godot centered + (52, 104-20)；显示 99×55px÷CS=77.27×42.93。
const BOSS_TAG_POS: Vector2 = Vector2(52.0, 84.0)
# TitleBg 细条 Scale9 中心直译（源 titlepos ccp(400,355) → godot(400,125)=480-355），size 随 stage_type。
# 2026-08-22 巡检订正：旧 (480,205) 系 960×640 口径残留（viewport 迁移漏网），运行时 fill 覆盖
# 了 tscn 本正确的 (148,119)-(652,131) 固化位，致细条横穿 Detail 文本区。
const TITLE_BG_CENTER: Vector2 = Vector2(400.0, 125.0)
# 关卡名超宽缩放阈值（源 :1886-1891 w>330 → setScale(330/w)）
const TITLE_MAX_W: float = 330.0

var stage_id: int = 0
var mgr: StageManager = null
var player: PlayerData = null
var rng: BattleRng = null
var _stage_data: StageData = null
var _enemies: Array[Dictionary] = []
var _res_info: Dictionary = {}
var _is_vitality_enabled: bool = false
var _is_count_enabled: bool = false
var _go_button: TextureButton = null
var _go_shade: TextureRect = null
var _reset_btn: TextureButton = null
var _count_number: Label = null
var _power_number: Label = null
var _sweep_ticket: Label = null


func setup_panel(p_sid: int, p_mgr: StageManager, p_player: PlayerData, p_rng: BattleRng) -> void:
	transparent_shade = true   # T4：原 shade 透明 hack 上收基类
	stage_id = p_sid
	mgr = p_mgr
	player = p_player
	rng = p_rng
	# 每日次数跨日清零（源服务器日重置；2026-09-17 经济单机优化补，惰性判定——打开面板即结算）
	player.check_stage_limit_daily_reset(int(Time.get_unix_time_from_system()))
	_stage_data = StageData.from_config(player.cm, p_sid)
	var bd := BattleData.from_config(player.cm, p_sid, 3)
	_enemies = bd.get_monsters()
	_res_info = get_res_info(StageAccount.stage_type(p_sid))
	setup()
	_build_content()


# 建 UI 内容：.tscn instantiate + fill 动态数据/texture；敌人/奖励/星挂各 host。
func _build_content() -> void:
	for c in container.get_children():
		c.queue_free()
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	var info: Dictionary = _get_stage_info()
	_fill_content(content, info)
	create_enemy(content.get_node("%EnemyHBox"), _enemies, player.cm)
	if _stage_data != null:
		create_reward(content.get_node("%RewardHBox"), _stage_data.drops, player.cm)
	apply_stars(content.get_node("%StarHBox"), int(info.get("star", 0)))
	_check_enabled()
	# 详情是关卡选择的子弹窗（stage_select_panel.gd detail.show_window(get_parent())），
	# 不碰 HudOverlay identity——遵循项目范式（battle_reward_popup / excavate_team_panel 等
	# 子弹窗同样不调 apply_identity）。identity 保持父级 stageselect，由 StageSelectPanel
	# 关闭时恢复 main。


# fill base 层动态数据（源 readNode ui_info + checkEnabled 首刷）。
func _fill_content(content: Control, info: Dictionary) -> void:
	var cm: Variant = player.cm
	var left: int = int(info.get("count_limit", 0)) - int(info.get("count", 0))
	var stage_type: String = String(info.get("stage_type", "normal"))
	# Frame3 边框随 stage_type 换图（源 :1597-1607 frame3=frameRes）；
	# 两帧尺寸/位置已 tscn 直译固化（936×507px÷CS 中心(480,355)），撤销 2026-07-20 的
	# 0.9 缩放偏好补偿（批3 Task 5 同口径恢复源几何直译）。
	_set_texture(content.get_node("%Frame3") as TextureRect, String(_res_info.get("frame", "")))
	# TitleBg 细条 scaleSize 随 stage_type（normal 504×12 / 其余 404×12，源 :1608-1618）。
	var bg_size: Vector2 = Vector2(_res_info.get("title_bg_size", Vector2(504.0, 12.0)))
	var title_bg: TextureRect = content.get_node("%TitleBg") as TextureRect
	title_bg.offset_left = TITLE_BG_CENTER.x - bg_size.x * 0.5
	title_bg.offset_right = TITLE_BG_CENTER.x + bg_size.x * 0.5
	title_bg.offset_top = TITLE_BG_CENTER.y - bg_size.y * 0.5
	title_bg.offset_bottom = TITLE_BG_CENTER.y + bg_size.y * 0.5
	# 标题横幅（源 :1620-1646 map_title_bg 随 stage_type 换图 + title Label）。
	# 2026-09-03 补建：旧方案"复用父面板章节标题栏"被本弹窗全屏 FrameworkBg 盖住，
	# 标题实机不可见；照源在弹窗内自建横幅+文字（超 330 宽绕中心缩放，源 :1886-1891）。
	_set_texture(content.get_node("%MapTitleBg") as TextureRect, String(_res_info.get("title_bg", "")))
	var title_lbl: Label = content.get_node("%StageTitle") as Label
	title_lbl.text = String(info.get("title", ""))
	var title_w: float = title_lbl.get_minimum_size().x
	if title_w > TITLE_MAX_W:
		title_lbl.scale = Vector2(TITLE_MAX_W / title_w, 1.0)
	# 文本 fill（LSTR 化硬编码中文，源 :1686/:1730/:1807/:1834/:1848）。
	var detail_lbl: Label = content.get_node("%Detail") as Label
	detail_lbl.text = String(info.get("detail", ""))
	detail_lbl.visible = bool(info.get("is_key_stage", false)) or String(info.get("detail", "")) != ""
	_power_number = content.get_node("%PowerNumber") as Label
	_power_number.text = str(info.get("power", 0))
	_count_number = content.get_node("%CountNumber") as Label
	_count_number.text = str(left)
	(content.get_node("%TotalNumber") as Label).text = "/ " + str(info.get("count_limit", "??"))
	(content.get_node("%PowerTitle") as Label).text = String(cm.get_lstr("STAGEDETAIL.PHYSICAL_EXERTION"))
	(content.get_node("%CountTitle") as Label).text = String(cm.get_lstr("EXERCISE.REMAINING_TIMES_FOR_TODAY_")) + str(left)
	(content.get_node("%ResetLabel") as Label).text = String(cm.get_lstr("EQUIPINFO.PURCHASE"))
	(content.get_node("%EnemyTitle") as Label).text = String(cm.get_lstr("STAGEDETAIL.ENEMY_LINEUP"))
	(content.get_node("%AwardTitle") as Label).text = String(cm.get_lstr("STAGEDETAIL.MAY_BE_OBTAINED"))
	# 交互绑定（源 doClickGo/doResetEliteLimit/doCloseButtonTouch）。
	_go_button = content.get_node("%GoButton") as TextureButton
	_go_button.pressed.connect(_on_go_pressed)
	_go_shade = content.get_node("%GoButtonShade") as TextureRect
	_reset_btn = content.get_node("%Reset") as TextureButton
	_reset_btn.pressed.connect(_on_reset_pressed)
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	# 源 :1906-1910 normal 型（isNormalMode）隐藏次数三件。
	if stage_type == "normal":
		(content.get_node("%CountTitle") as Label).visible = false
		_count_number.visible = false
		(content.get_node("%TotalNumber") as Label).visible = false
	_setup_sweep_cluster(content, int(info.get("star", 0)), stage_type)


# 项目 StageData 首次访问可能缺 row，"关卡 %d" fallback 是项目适配（源 row 必存在）。
func _get_stage_info() -> Dictionary:
	var row: Dictionary = player.cm.get_raw_table("Stage").get(str(stage_id), {})
	# Stage Name/description 存 LSTR key（535 条中 508/425 条是 key），需 get_lstr 本地化
	# （源 lua 直接取因 LSTR 宏已展开；本项目 JSON 存原始 key 须转换，否则标题显示英文 key）。
	var title_raw: String = String(row.get("Stage Name", "关卡 %d" % stage_id))
	var detail_raw: String = String(row.get("description", ""))
	return {
		"title": String(player.cm.get_lstr(title_raw)),
		"detail": String(player.cm.get_lstr(detail_raw)),
		"power": _stage_data.vitality_cost if _stage_data != null else 0,
		"count_limit": _daily_limit(),
		"count": _used_times(),
		"chapter": int(row.get("Chapter ID", 1)),
		"star": mgr.stage_stars(stage_id) if mgr != null else 0,
		"is_key_stage": false,
		"stage_type": StageAccount.stage_type(stage_id),
	}


# 贴图资源信息（源 getResInformation:633-678）：随 stage_type 换边框/标题底/星距/出战按钮位。
static func get_res_info(stage_type: String) -> Dictionary:
	match stage_type:
		"normal":
			return _pack(UI_DIR + "stage-map-frame.png", UI_DIR + "Normal_title_bg.png", Vector2(504.0, 12.0), 55, Vector2(698.0, 80.0), Vector2(400.0, 205.0))
		"elite", "dungeon":
			return _pack(UI_DIR + "stage-map-elite-frame.png", UI_DIR + "Elite_title_bg.png", Vector2(404.0, 12.0), 50, Vector2(678.0, 80.0), Vector2(400.0, 207.0))
		"raid":
			return _pack(UI_DIR + "stage_map_guild_frame.png", UI_DIR + "guild_title_bg.png", Vector2(404.0, 12.0), 50, Vector2(678.0, 80.0), Vector2(400.0, 207.0))
	return _pack(UI_DIR + "stage-map-frame.png", UI_DIR + "Normal_title_bg.png", Vector2(504.0, 12.0), 55, Vector2(698.0, 80.0), Vector2(400.0, 205.0))


static func _pack(frame: String, title_bg: String, bg_size: Vector2, star_gap: int, go_btn: Vector2, frame_pos: Vector2) -> Dictionary:
	return {"frame": frame, "title_bg": title_bg, "title_bg_size": bg_size, "star_gap": star_gap, "go_btn_pos": go_btn, "frame_pos": frame_pos}


static func to_godot(cx: float, cy: float) -> Vector2:
	return Vector2(cx + OFFSET_X, BASE_Y - cy)


static func _set_texture(rect: TextureRect, res_path: String) -> void:
	if rect == null or res_path.is_empty() or not ResourceLoader.exists(res_path):
		return
	rect.texture = load(res_path) as Texture2D


func _check_enabled() -> void:
	var left: int = _left_times()
	if _count_number != null:
		_count_number.text = str(left)
		_count_number.add_theme_color_override("font_color", C_DISABLE if left < 1 else C_NUM)
	var power: int = _stage_data.vitality_cost if _stage_data != null else 0
	_is_vitality_enabled = player.vitality >= power
	var count_limit: int = _daily_limit()
	_is_count_enabled = count_limit > int(player.stage_limit.get(stage_id, 0)) or count_limit <= 0
	if _reset_btn != null:
		_reset_btn.visible = not _is_count_enabled
	if _power_number != null and _is_vitality_enabled and _is_count_enabled:
		_power_number.add_theme_color_override("font_color", C_NUM)
	if _go_shade != null:
		_go_shade.visible = not (_is_vitality_enabled and _is_count_enabled)
	# 扫荡集群券计数刷新（扫荡后 player.get_sweep_times 变化）。
	if _sweep_ticket != null:
		_sweep_ticket.text = str(player.get_sweep_times())


func _left_times() -> int:
	return _daily_limit() - _used_times()


# act 段（资源试炼 20001-20005）组次数语义：limit 查 ActStageGroup.DailyLimit、
# 已用查 mgr.act_times[Stage Group]（进战斗计次在 StageDungeonLogic.check_enter_act_group）；
# 其余类型照旧查 Stage 单关 Daily Limit / player.stage_limit（源 getRepeatInformation 分支）。
func _daily_limit() -> int:
	if StageAccount.stage_type(stage_id) == "act":
		return int(player.cm.get_raw_table("ActStageGroup").get(str(_act_group_id()), {}).get("DailyLimit", 0))
	return int(player.cm.get_raw_table("Stage").get(str(stage_id), {}).get("Daily Limit", 0))


func _used_times() -> int:
	if StageAccount.stage_type(stage_id) == "act":
		if mgr != null:
			StageDungeonLogic.check_act_times_daily_reset(mgr, int(Time.get_unix_time_from_system()))
			return int(mgr.act_times.get(_act_group_id(), 0))
		return 0
	return int(player.stage_limit.get(stage_id, 0))


func _act_group_id() -> int:
	return int(player.cm.get_raw_table("Stage").get(str(stage_id), {}).get("Stage Group", 0))


# 扫荡集群（源 createRepeatBattle:266-468）：满 3 星 + normal/elite 才显示。
# %SweepCluster（Panel 底板 main_vit_tips）内含 SweepOnceBtn（扫荡1次）/SweepSomeBtn（扫荡N次）
# + SweepTicketIcon + SweepTicketCount（券计数）。单机化裁剪：去 VIP 功能解锁（localMode 跳过）；
# 券不足直接 toast 不暴露钻石扫荡路径（源 doPaySweepConfirm 联机流程）。
# 按钮底图走 theme StageSweepBtn variation（tavern_button_normal_1/2 cap 20,15,90,15
# 三态入 theme，2026-08-16 起禁运行时 stylebox override）+ 独立子 Label
# （Button.text 内嵌 label 受 stylebox content_margin 干扰，范式同 hero_detail）。
func _setup_sweep_cluster(content: Control, star: int, stage_type: String) -> void:
	var cluster: Panel = content.get_node("%SweepCluster") as Panel
	if mgr == null or star < 3 or (stage_type != "normal" and stage_type != "elite"):
		cluster.visible = false
		return
	cluster.visible = true
	var cm: Variant = player.cm
	var once_btn: Button = cluster.get_node("%SweepOnceBtn") as Button
	(once_btn.get_node("SweepOnceLabel") as Label).text = String(cm.get_lstr("PRIVILEGE.FARM"))
	once_btn.pressed.connect(_on_sweep_once_pressed)
	var some_btn: Button = cluster.get_node("%SweepSomeBtn") as Button
	var n: int = _sweep_some_times(stage_type)
	var raid_fmt: String = String(cm.get_lstr("STAGEDETAIL.RAID__D_TIMES"))
	if raid_fmt == "STAGEDETAIL.RAID__D_TIMES":
		raid_fmt = "扫荡%d次"
	(some_btn.get_node("SweepSomeLabel") as Label).text = raid_fmt % n
	if n < 1:
		(some_btn.get_node("SweepSomeLabel") as Label).text = String(cm.get_lstr("STAGEDETAIL.RAID_FAILED"))
		some_btn.disabled = true
	else:
		some_btn.pressed.connect(_on_sweep_some_pressed.bind(stage_type))
	_sweep_ticket = cluster.get_node("SweepTicketCount") as Label
	_sweep_ticket.text = str(player.get_sweep_times())


# 扫荡次数上限语义（源 getRepeatInformation:236-240 repeatInfo.cLimit）：Daily Limit=0
# （无限制，普通关皆此）→ 999；否则剩余次数。扫荡上限判断/N 计算用本语义；UI CountNumber
# 显示仍用 _left_times()（normal 型隐藏三件，elite 有真实上限）。漏译本分支曾致普通关
# 扫荡 1 次误报"次数已达上限" + 批量扫荡 N=0 按钮 disabled（2026-09-04 修复）。
func _sweep_count_limit() -> int:
	if _daily_limit() == 0:
		return SWEEP_UNLIMITED
	return _left_times()


# 扫荡N次的 N（源 getRepeatInformation:231-265）：min(剩余进入次数, 普通关10/精英关3)。
func _sweep_some_times(stage_type: String) -> int:
	var cap: int = SWEEP_DEFAULT_ELITE if stage_type == "elite" else SWEEP_DEFAULT_NORMAL
	return maxi(0, mini(_sweep_count_limit(), cap))


func _on_go_pressed() -> void:
	if not (_is_vitality_enabled and _is_count_enabled):
		return
	AudioPlayer.play_sfx("common_click_feedback")
	if mgr == null or player == null or rng == null:
		return
	var panel := BattlePreparePanel.new()
	panel.setup(stage_id, player, mgr, rng, player.cm)
	var parent: Node = get_parent()
	if parent != null:
		parent.add_child(panel)
	remove_window()


# 扫荡1次（源 doRepeatOnce:153-163 → doClickSweep(1)）。单机化去 VIP 校验（localMode 跳过）。
func _on_sweep_once_pressed() -> void:
	_do_sweep(1)


# 扫荡N次（源 doRepeatSome:164-174 → doClickSweep(limit)）。stage_type 由 bind 传入算 N。
func _on_sweep_some_pressed(stage_type: String) -> void:
	_do_sweep(_sweep_some_times(stage_type))


# 扫荡统一执行 + 前置校验（源 doClickSweep:128-151 分层拦截）；成功弹 SweepRewardPopup
#（源 repeatRewardWindow:1946，2026-09-04 补全，原 Toast 简化被用户复验否定）。
func _do_sweep(times: int) -> void:
	if mgr == null or player == null or times <= 0:
		return
	AudioPlayer.play_sfx("common_click_feedback")
	var cm: Variant = player.cm
	if times > _sweep_count_limit():
		Toast.show_message(String(cm.get_lstr("STAGEDETAIL.ENTER_TO_THIS_GAME_POINTS_HAS_REACHED_THE_UPPER_LIMIT_TODAY")))
		return
	var power: int = (_stage_data.vitality_cost if _stage_data != null else 0) * times
	if player.vitality < power:
		Toast.show_message("体力不足")
		return
	if player.get_sweep_times() < times:
		Toast.show_message("扫荡券不足")
		return
	var r: Dictionary = mgr.sweep(stage_id, times, rng, player, "free")
	if bool(r.get("ok", false)):
		_check_enabled()
		_show_sweep_reward(r)
	else:
		# sweep 失败返 reason 而非 msg——旧读 msg 恒落笼统"扫荡失败"，兜底时看不到真实原因。
		Toast.show_message(str({"no_vitality": "体力不足", "no_sweep_coin": "扫荡券不足", "no_diamond": "钻石不足"}.get(String(r.get("reason", "")), "扫荡失败")))


# 扫荡结果弹窗（源 doSendSweepReply:42-67 repeatRewardWindow.create(lootList)，2026-09-04
# 补全原单机化 Toast 简化）：waves 每战一组 + 末组额外奖励（源 readSweepReply el 无 exp/money）。
func _show_sweep_reward(r: Dictionary) -> void:
	var loot_list: Array = []
	for w in (r.get("waves", []) as Array):
		loot_list.append(w)
	loot_list.append({"loots": r.get("raid_bonus", [])})
	var popup := SweepRewardPopup.new("sweepReward", {})
	popup.setup_popup(loot_list, player.cm)
	popup.show_window(get_parent() if get_parent() != null else self)


# 流程：getResetEliteCost 读 GradientPrice[times+1]["Elite Reset"]（梯度计费 20/50/.../1000）
# + checkStageLimitResetTimesMax VIP 次数上限（needHighervip dialog 拒绝）
# + 弹确认框（showConfirmDialog，RESET_COSTS 文案 + 已重置次数）
# + doResetElite 扣钻 + refreshStageEliteLimit（清 stage_limit + reset_times++）。
# 项目单机化：CrusadeResetConfirm 范式简化（文案 + 确认/取消）。
# 单机去 VIP 限制（2026-09-08）：上限按特权档（满级 Elite Reset=14 次）取值，
# 达上限文案改通用（原 needHighervip 文案不再成立——玩家无提升 VIP 途径）。
func _on_reset_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	if StageResetData.is_reset_times_max(player, stage_id):
		Toast.show_message("今日重置次数已达上限")
		return
	var cost: int = StageResetData.get_reset_cost(player, stage_id)
	if cost <= 0:
		Toast.show_message("该关卡无法购买次数")
		return
	var times: int = StageResetData.get_reset_times(player, stage_id)
	# 项目单机化：CrusadeResetConfirm 范式（独立 Control 确认框）。
	var msg: String = String(player.cm.get_lstr("STAGEDETAIL.RESET_COSTS__D_DIAMONDS_\\N_WISH_TO_CONTINUEYOU_HAVE_RESET__D_TIMES_TODAY"))
	if msg == "STAGEDETAIL.RESET_COSTS__D_DIAMONDS_\\N_WISH_TO_CONTINUEYOU_HAVE_RESET__D_TIMES_TODAY":
		msg = "重置关卡进入次数需要花费%d钻石.\n是否继续？（今日已重置%d次）"
	msg = msg % [cost, times]
	var popup := StageResetConfirm.new()
	popup.setup_msg(msg, player.cm)
	popup.confirmed.connect(_do_reset_elite.bind(cost))
	var parent: Node = get_parent()
	if parent != null:
		parent.add_child(popup)


# 单机化：源走 netdata/netreply 网络流程，项目直接本地执行（doResetEliteLimit handler 内逻辑）。
func _do_reset_elite(cost: int) -> void:
	if player.diamond < cost:
		Toast.show_message("钻石不足")  # 项目适配 toast（源 toRecharge dialog；2026-09-17 去充值引导）
		return
	player.diamond -= cost
	StageResetData.refresh_elite_limit(player, stage_id)
	_check_enabled()


# 敌方阵容：照源 createEnemy:1142-1192，容器化（ReadheroIcon 是 Node2D 不能直接进 HBox，
# 套 Control wrapper + custom_minimum_size，范式同 excavate_team_panel._add_hero_icon）。
# boss/普通尺寸差异通过 wrapper size + icon scale 处理，坐标交由 %EnemyHBox 自动排版。
func create_enemy(parent: Node, enemies: Array, cm: Variant) -> void:
	# boss 排在小怪后面（用户偏好：详情阵容 boss 在末尾，区别于战斗站位 Boss Position）。
	var ordered: Array = []
	var bosses: Array = []
	for e in enemies:
		if bool(e.get("is_boss", false)):
			bosses.append(e)
		else:
			ordered.append(e)
	ordered.append_array(bosses)
	for e in ordered:
		var tid: int = int(e.get("tid", 0))
		if tid == 0:
			continue
		var is_boss: bool = bool(e.get("is_boss", false))
		var icon := ReadheroIcon.new()
		var rank: int = mini(ExcavateData.hero_level_to_rank(int(e.get("level", 1))), 8)
		icon.setup({"id": tid, "rank": rank, "stars": int(e.get("stars", 0))}, cm)
		var length: float = ENEMY_LEN_BOSS if is_boss else ENEMY_LEN_NORMAL
		var s: float = length / ENEMY_CONTAINER
		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(ENEMY_CONTAINER * s + (ENEMY_BOSS_OX if is_boss else 0.0), ENEMY_CONTAINER * s)
		wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.scale = Vector2(s, s)
		# x：普通分母巧合 s×40.625=槽半宽居中；boss 槽加宽 5 承载源 +5 偏移。
		# y：源 container 中心（104 空间 y=63.375×s）对准 wrapper 半高（icon 视觉框底部
		# 在 104 空间 y≈104，直接 (0,0) 挂原点会整体偏下 ~20px）
		var wrap_h: float = ENEMY_CONTAINER * s
		icon.position = Vector2(ENEMY_BOSS_OX if is_boss else 0.0, wrap_h * 0.5 - ENEMY_SRC_CENTER_Y * s)
		wrapper.add_child(icon)
		parent.add_child(wrapper)
		if icon.ori_icon is Sprite2D:
			(icon.ori_icon as Sprite2D).flip_h = true
		if is_boss:
			_add_boss_tag(icon)


# boss 标签（源 :1178-1182）：stagedetail_boss_tag.png @ icon 局部 ccp(52,20) z10。
# 贴图 99×55px（HC multilanguage en-US 补缺，2026-08-16），显示 77.27×42.93 点（÷CS scale 补偿）；
# 缺图时 Label "BOSS" 红字 fallback（防御路径，源 createSprite 缺图≈nil 不等效故留）。
func _add_boss_tag(icon: ReadheroIcon) -> void:
	var host: Node = icon.icon if icon.icon != null else icon
	if ResourceLoader.exists(BOSS_TAG_RES):
		var tag := Sprite2D.new()
		tag.texture = load(BOSS_TAG_RES) as Texture2D
		tag.centered = true
		tag.scale = Vector2(INV_CS, INV_CS)
		tag.position = BOSS_TAG_POS
		tag.z_index = 10
		host.add_child(tag)
	else:
		var lbl := Label.new()
		lbl.text = "BOSS"
		lbl.position = Vector2(20.0, 0.0)
		lbl.add_theme_color_override("font_color", Color.RED)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.z_index = 10
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(lbl)


# 奖励：照源 createReward:1193-1211，createIcon(id) 无 length → frame 原样 px/CS
# （73.37×74.14，源 anchor(0.5,0) 底对齐 pos(205+80(i-1),50)，步进 80）。
# 显示尺寸由 ReadequipIcon._load_sprite 内部 ÷CS（9bc640e 统一口径）。
# Task 9 修复：HBox 一帧后重置直接子项 scale（实测 0.7→1.0，图标
# 渲染底 557 压 Frame2 底 553）→ wrapper 承载 HBox 排布（72 槽+8 sep=80 步进照源），
# 内层 icon 在 wrapper（非容器）内保 scale 且底对齐 wrapper 底（源底锚语义）。
const REWARD_FRAME_PX: Vector2 = Vector2(94.0, 95.0)
const REWARD_SLOT: float = 72.0  # = ReadequipIcon.ICON_SIZE（HBox 步进 72+8=80 照源）
# hero 奖励观感三件（源 stagedetail.lua:1199-1200 紫框 createIcon(id,nil,4) +
# doWhenEnter :1911-1918 整体 setScale(0.9) + 叠 getIconFrameByRank 框于局部 (41,40)）。
# rank→hero_icon_frame_N 复用 ReadheroIcon._frame_id_by_rank（RANK_FRAME_IDS 照源
# player.lua frames 表；Unit 表 Initial Rank 全表=1 → 实际恒 frame_1）。
const HERO_REWARD_QUALITY: int = 4
const HERO_REWARD_SCALE: float = 0.9
const HERO_RANK_FRAME_CENTER_UP: Vector2 = Vector2(41.0, 40.0)
const HERO_RANK_FRAME_DIR: String = "res://assets/ui/alpha/HVGA/hero_icon_frame_"

func create_reward(parent: Node, drops: Array, cm: Variant) -> void:
	for d in drops:
		var item_id: int = int(d.get("item_id", 0))
		if item_id == 0:
			continue
		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(REWARD_SLOT, REWARD_SLOT)
		wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vis_size: Vector2 = REWARD_FRAME_PX * INV_CS
		var icon: Control
		var scale_factor: float = 1.0
		if ReadequipIcon.is_hero_id(item_id, cm):
			# 源 :1199-1200 hero 奖励强制紫框（quality=4 覆写 hero 默认白）；
			# :1911-1918 整体 0.9 + 叠 rank 框（底锚语义：底贴 wrapper 底、绕底收缩）。
			icon = ReadequipIcon.create_icon(item_id, 1, cm, 0, false, HERO_REWARD_QUALITY)
			scale_factor = HERO_REWARD_SCALE
			_add_hero_rank_frame(icon, item_id, cm)
		else:
			icon = ReadequipIcon.create_icon(item_id, 1, cm)
		# 显示尺寸已由 create_icon 内部 _load_sprite 统一 ÷CS（9bc640e）；外层不再补偿——
		# 4de6c27 的外层 INV_CS 在统一后成双重 ÷CS（图标实显 57.9 而非 73.4），2026-08-22 摘除。
		icon.scale = Vector2(scale_factor, scale_factor)
		icon.position = Vector2((REWARD_SLOT - vis_size.x * scale_factor) * 0.5, REWARD_SLOT - vis_size.y * scale_factor)
		wrapper.add_child(icon)
		parent.add_child(wrapper)


# hero 奖励叠 rank 框（源 doWhenEnter :1911-1918：Hero.getIconFrameByRank(Initial Rank)
# 叠加于 reward icon 局部 (41,40)，anchor(0.5,0.5) cocos y 上 → Godot centered + y 翻）。
# add_child 排最后 → 渲染在紫框/内容之上（源同序）。
func _add_hero_rank_frame(icon: Control, item_id: int, cm: Variant) -> void:
	var rank: int = int(cm.get_raw_table("Unit").get(str(item_id), {}).get("Initial Rank", 1))
	var path: String = HERO_RANK_FRAME_DIR + str(ReadheroIcon._frame_id_by_rank(rank)) + ".png"
	if not ResourceLoader.exists(path):
		return
	var frame := Sprite2D.new()
	frame.texture = load(path) as Texture2D
	frame.scale = Vector2(INV_CS, INV_CS)
	frame.centered = true
	frame.position = Vector2(HERO_RANK_FRAME_CENTER_UP.x, REWARD_FRAME_PX.y * INV_CS - HERO_RANK_FRAME_CENTER_UP.y)
	icon.add_child(frame)


# 星级：照源 createStars:1212-1261，星星已静态化进 .tscn（%StarHBox 下 Star1/2/3）。
# 按 star_count 切换 3 个 TextureRect 的 texture（detail_star / detail_star_grey）。
func apply_stars(star_box: Node, star_count: int) -> void:
	for i in range(3):
		var star: TextureRect = (star_box.get_child(i)) as TextureRect
		if star == null:
			continue
		var res_path: String = (UI_DIR + "detail_star.png") if i < star_count else (UI_DIR + "detail_star_grey.png")
		if ResourceLoader.exists(res_path):
			star.texture = load(res_path) as Texture2D
