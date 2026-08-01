class_name StageDoneScene
extends Control

## 战斗胜利结算场景（View 层）— 照源 ui/stagedone.lua 翻译（2026-07-03，Phase 4 续）。
## 第二十一轮：装配初始隐藏态 + 入场动画 Tween 序列（委托 StageDoneAnimator）+ skipAnim 跳过。
## 装配：bg + shelter + light + star_1-3 + info_bg（lv/gold/exp）+ 英雄经验列表 + 掉落列表 + replay/next。
## 单机化：去 guildInstanceData/bestRankReward(PVP)/mercenary/FCA 特效/draglist 滚动/getNewHero announce/
##   battleStatist/isMaxLevel full bar。speedDiv=1（无战斗速度系统）。doClickReplay/Next→main_scene。
##
## 重构（2026-07-18，hero_detail 范式）：静态结构（bg/shelter/light/star×3/info_bg+装饰+icon+label+
## battleStatistNode 父/replay/next）静态化进 scenes/battle/stage_done_content.tscn（位置/size 可视化调）；
## scene 改为 instantiate + add_child + get_node("%..") + fill。动态（bg texture 按 stage_id / lv·gold·exp
## 文本 / replay visible 按 is_key_stage / battleStatist Scale9 Button + BattleCount Label）运行时 fill。
## hero/loot icon（数量随 _param 变）保留 procedural 挂 _content（保留原 add_child 行为，最少改动）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/battle/stage_done_content.tscn")
const ALPHA_HVGA_DIR: String = "res://assets/ui/alpha/HVGA/"

# 静态节点（bg/shelter/light/star×3/info_bg 父/replay/next）坐标已固化进 stage_done_content.tscn，
# 这里仅保留动态节点（hero/loot icon）+ InfoBg 内 icon texture fill + battleStatist 子（Button + Label）所需常量。
const HERO_ORI_X: float = 195.0
const HERO_ORI_Y: float = 243.0
const HERO_GAP_X: float = 92.0
const LOOT_ORI_X: float = 200.0
const LOOT_ORI_Y: float = 100.0
const LOOT_GAP_X: float = 70.0
const BAR_OFFSET: Vector2 = Vector2(0.0, -8.0)
const EXP_LABEL_OFFSET: Vector2 = Vector2(38.0, -30.0)
const MAX_STARS: int = 3
# battleStatistNode 子位置常量（贴图/CAP 走 C 公共常量；本场景独有的尺寸/偏移）。
const BATTLE_STATIST_SIZE: Vector2 = Vector2(70.0, 50.0)
const BATTLE_STATIST_LABEL_OFFSET: Vector2 = Vector2(35.0, 0.0)
# InfoBg 内 ExpIcon texture（GoldIcon 已静态化进 .tscn；xpicon 缺图 _load 容错 null 不报错）
const EXP_ICON_TEX: String = "xpicon.png"
# 英雄经验条（源 stagedone.lua:364-371,443-449 heroxp-progress-bg/progress/full 三 sprite）。
const HERO_BAR_BG_TEX: String = "heroxp-progress-bg.png"      # 经验槽底（前景 progress 之下）
const HERO_BAR_TEX: String = "heroxp-progress.png"            # 前景进度（scaleX 动画）
const HERO_BAR_FULL_TEX: String = "heroxp-progress-full.png"  # 满级态覆盖（is_max_level 时显示）

var _param: Dictionary = {}
var _cm: ConfigManager = null
var _animator: StageDoneAnimator = null
var _anim_playing: bool = false
var _content: Control = null       # stage_done_content.tscn 实例（静态结构容器）

# 装配节点（animator 操作，从 _content get_node as 取）
var _light: Sprite2D = null
var _info_bg: Sprite2D = null
var _star_nodes: Array = []         # Sprite2D[]
var _hero_icon_nodes: Array = []    # ReadheroIcon[]
var _hero_bars: Array = []          # Sprite2D[]（经验条前景，bar scaleX 动画用）
var _hero_bar_bgs: Array = []       # Sprite2D[]（经验条底，静态显示，z_index 在前景下）
var _hero_bar_fulls: Array = []     # Sprite2D[]（满级态覆盖，is_max_level 时 visible）
var _loot_icon_nodes: Array = []    # Control[]
var _replay_btn: TextureButton = null
var _next_btn: TextureButton = null
var _exp_label: Label = null
var _gold_label: Label = null
var _lv_label: Label = null
var _battle_statist_node: Sprite2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # 接收 gui_input（点击空白跳过）
	# 运行时（SceneManager.change_scene 加载后）：从 GameData.last_result 读 param 自动装配
	if GameData.last_result.has("stage_id") and bool(GameData.last_result.get("victory", false)):
		setup(GameData.last_result, GameData.config)


# 装配（照源 create :1322-1668）。
func setup(p_param: Dictionary, p_cm: ConfigManager) -> void:
	_param = p_param
	_cm = p_cm
	_build_content()
	_fill_static_nodes()
	_fill_info_bg_icons()
	_fill_battle_statist()
	_create_hero_icons()
	_create_loot_icons()
	_animator = StageDoneAnimator.new(self)
	_animator.play_enter()


# 建 UI 内容：静态结构从 .tscn instantiate（位置/size 可视化）。
# 取出 animator 操作的节点引用（light/info_bg/star/btn/label/battleStatist）。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	add_child(_content)
	_light = _content.get_node("%Light") as Sprite2D
	_info_bg = _content.get_node("%InfoBg") as Sprite2D
	_star_nodes.clear()
	for i in MAX_STARS:
		_star_nodes.append((_content.get_node("%Star" + str(i + 1)) as Sprite2D))
	_replay_btn = _content.get_node("%Replay") as TextureButton
	_next_btn = _content.get_node("%Next") as TextureButton
	_exp_label = _content.get_node("%Exp") as Label
	_gold_label = _content.get_node("%Gold") as Label
	_lv_label = _content.get_node("%Lv") as Label
	_battle_statist_node = _content.get_node("%BattleStatistNode") as Sprite2D


# 填静态节点的动态字段：bg texture（按 stage_id）+ lv 文本（玩家等级）+ replay/next visible + 按钮 pressed。
func _fill_static_nodes() -> void:
	var bg: TextureRect = _content.get_node("%Bg") as TextureRect
	bg.texture = StageSettlementCommon.load_battle_bg(int(_param.get("stage_id", 0)), _cm)
	var player_info: Dictionary = _param.get("player_info", {})
	_lv_label.text = "LV " + str(int(player_info.get("ori_level", 1)))
	var is_key: bool = bool(_param.get("is_key_stage", false))
	_replay_btn.visible = is_key
	_replay_btn.pressed.connect(_on_replay_pressed)
	_next_btn.pressed.connect(_on_next_pressed)


# 填 InfoBg 内动态 icon texture（GoldIcon 已静态化进 .tscn；xpicon 缺图 _load 容错 null）。
func _fill_info_bg_icons() -> void:
	(_info_bg.get_node("ExpIcon") as Sprite2D).texture = StageSettlementCommon.load_texture(ALPHA_HVGA_DIR + EXP_ICON_TEX)


# 父 Sprite2D 在 .tscn（pos + modulate.a=0 独立 fade），Button + Label procedural fill 挂父（Scale9 复杂构造）。
func _fill_battle_statist() -> void:
	var btn: Button = UiScale9Button.make_centered(
		ALPHA_HVGA_DIR + StageSettlementCommon.BATTLE_STATIST_TEX,
		ALPHA_HVGA_DIR + StageSettlementCommon.BATTLE_STATIST_PRESS_TEX,
		BATTLE_STATIST_LABEL_OFFSET,
		BATTLE_STATIST_SIZE,
		StageSettlementCommon.BATTLE_STATIST_CAP)
	btn.pressed.connect(_on_battle_statist_pressed)
	_battle_statist_node.add_child(btn)
	var count := Label.new()
	count.name = "BattleCount"
	count.text = StageSettlementCommon.statist_label_text(_cm)
	count.position = BATTLE_STATIST_LABEL_OFFSET
	_battle_statist_node.add_child(count)


# 战斗统计面板弹出（公共逻辑，照源 _on_battle_statist_pressed）。
func _on_battle_statist_pressed() -> void:
	StageSettlementCommon.show_battle_statistics(self, _cm)


# 初始 icon modulate.a=0（playHeroAnim fade in）；bar scaleX=pre_exp/pre_max（playHeroBarAnim 动画到 tExp/tMaxExp）。
func _create_hero_icons() -> void:
	var heroes: Array = _param.get("heroes", [])
	for i in heroes.size():
		var hinfo: Dictionary = heroes[i]
		var ri := ReadheroIcon.new()
		ri.setup({
			"id": int(hinfo.get("id", 0)),
			"rank": int(hinfo.get("rank", 1)),
			"stars": 0,
			"level": int(hinfo.get("level", 1)),
			"hp": int(hinfo.get("hp", 0)),
			"mp": int(hinfo.get("mp", 0)),
		}, _cm)
		ri.position = Vector2(HERO_ORI_X + HERO_GAP_X * i, HERO_ORI_Y)
		ri.icon.modulate.a = 0.0
		_content.add_child(ri)   # setup 内部已 add icon 到 self（照 battle_hero_panel:55）
		# 经验条三层（源 stagedone.lua:364-371,443-449）：bg 静态底 + progress 前景（scaleX 动画）+ full 满级覆盖。
		# bg 先 add（z 序在下），progress 后 add（覆盖 bg），full 最后 add（覆盖 progress，仅 is_max_level visible）。
		var bar_bg := Sprite2D.new()
		bar_bg.texture = StageSettlementCommon.load_texture(ALPHA_HVGA_DIR + HERO_BAR_BG_TEX)
		bar_bg.centered = false
		bar_bg.position = BAR_OFFSET
		ri.icon.add_child(bar_bg)
		_hero_bar_bgs.append(bar_bg)
		var bar := Sprite2D.new()
		bar.texture = StageSettlementCommon.load_texture(ALPHA_HVGA_DIR + HERO_BAR_TEX)
		bar.centered = false
		bar.position = BAR_OFFSET
		var pre_exp: int = int(hinfo.get("exp", 0))
		var pre_max: int = int(hinfo.get("max_exp", 1))
		bar.scale.x = clampf(float(pre_exp) / float(maxi(pre_max, 1)), 0.0, 1.0)
		ri.icon.add_child(bar)
		_hero_bars.append(bar)
		# 满级态覆盖（源 stagedone.lua:1676-1742 isMaxLevel 显示 full bar）；当前数据层 is_max_level 兜底 false。
		var bar_full := Sprite2D.new()
		bar_full.texture = StageSettlementCommon.load_texture(ALPHA_HVGA_DIR + HERO_BAR_FULL_TEX)
		bar_full.centered = false
		bar_full.position = BAR_OFFSET
		bar_full.visible = bool(hinfo.get("is_max_level", false))
		ri.icon.add_child(bar_full)
		_hero_bar_fulls.append(bar_full)
		var exp_lbl := Label.new()
		exp_lbl.text = "EXP +" + str(int(hinfo.get("add_hero_exp", 0)))
		exp_lbl.position = EXP_LABEL_OFFSET
		ri.icon.add_child(exp_lbl)
		_hero_icon_nodes.append(ri)


func _create_loot_icons() -> void:
	var loot_list: Dictionary = _param.get("loot_list", {})
	var i: int = 0
	for id in loot_list:
		var info: Dictionary = loot_list[id]
		var amount: int = int(info.get("amount", 1))
		var icon: Control = ReadequipIcon.create_icon(int(id), amount, _cm)
		icon.position = Vector2(LOOT_ORI_X + LOOT_GAP_X * i, LOOT_ORI_Y)
		icon.scale = Vector2.ZERO
		_content.add_child(icon)
		_loot_icon_nodes.append(icon)
		i += 1


func skip_anim() -> void:
	if not _anim_playing:
		return
	_anim_playing = false
	if _animator != null:
		_animator.kill()
	_exp_label.text = "+" + str(int(_param.get("exp", 0)))
	_gold_label.text = "+" + str(int(_param.get("gold", 0)))
	var stars: int = int(_param.get("stars", 0))
	for i in range(stars):
		if i < _star_nodes.size():
			(_star_nodes[i] as Sprite2D).scale = Vector2.ONE
	var heroes: Array = _param.get("heroes", [])
	for i in range(_hero_icon_nodes.size()):
		var ri: ReadheroIcon = _hero_icon_nodes[i]
		ri.icon.modulate.a = 1.0
		var hinfo: Dictionary = heroes[i] if i < heroes.size() else {}
		var t_exp: int = int(hinfo.get("t_exp", 0))
		var t_max: int = int(hinfo.get("t_max_exp", 1))
		if i < _hero_bars.size():
			(_hero_bars[i] as Sprite2D).scale.x = clampf(float(t_exp) / float(max(t_max, 1)), 0.0, 1.0)
		ri.refresh_level(int(hinfo.get("t_level", 1)))
	for icon in _loot_icon_nodes:
		(icon as Control).scale = Vector2.ONE
	if _animator != null:
		_animator.play_button()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		skip_anim()


# 音效：stagedonelsr clickReply → stageDone.replay = common_click_feedback（soundres:168）。
func _on_replay_pressed() -> void:
	StageSettlementCommon.goto_main_scene()


func _on_next_pressed() -> void:
	StageSettlementCommon.goto_main_scene()
