class_name StageDoneScene
extends Control

## 战斗胜利结算场景（View 层）— 照源 ui/stagedone.lua 翻译（2026-07-03，Phase 4 续）。
## 第二十一轮：装配初始隐藏态 + 入场动画 Tween 序列（委托 StageDoneAnimator）+ skipAnim 跳过。
## 装配：bg + shelter + light + star_1-3 + info_bg（lv/gold/exp）+ 英雄经验列表 + 掉落列表 + replay/next。
## 单机化：去 guildInstanceData/bestRankReward(PVP)/mercenary/FCA 特效/draglist 滚动/getNewHero announce/
##   battleStatist/isMaxLevel full bar。speedDiv=1（无战斗速度系统）。doClickReplay/Next→main_scene。
##
## 重构（2026-08-05）：content.tscn 合并进 scene.tscn（单文件）。所有静态 UI 节点（bg/shelter/light/
## star×3/info_bg+装饰+icon+label+BattleStatistBtn+BattleCount/HeroHost/LootHost/replay/next）固化进
## stage_done_scene.tscn。scene 改为 get_node("%..") + fill。动态（bg texture 按 stage_id / lv·gold·exp
## 文本 / replay visible 按 is_key_stage / BattleStatistBtn Scale9 样式）运行时 fill。
## hero/loot icon（数量随 _param 变）保留 procedural 挂 %HeroHost/%LootHost（Node2D/RefCounted 无法 .tscn 实例化）。

const ALPHA_HVGA_DIR: String = "res://assets/ui/alpha/HVGA/"

# 静态节点（bg/shelter/light/star×3/info_bg 父/replay/next/HeroHost/LootHost）坐标已固化进
# stage_done_scene.tscn（2026-08-05 合并 content.tscn）。这里仅保留动态节点（hero/loot icon 间距、bar 偏移）所需常量。
# 坐标口径：旧 960×640 时代等比转换（x*1.2, (480-y)*1.333）已退役无调用方；viewport 800×480 后按源坐标直译（y 翻转：godot_y = 480 - cocos_y）。
# hero/loot 起始坐标（HERO_ORI/LOOT_ORI）已搬进 %HeroHost/%LootHost 的 position，可视化调。
# 源直译（stagedone.lua:16-23）：hero_gap_x=92 / loot_gap_x=70。旧 110/84 系适配偏大头像的
# 手工补偿，头像÷CS 口径 2026-08-22 已根修后回摆源值（2026-08-28 头像÷CS 专项）。
# 起点口径：源 hero_ori=(195,243)/loot_ori=(200,100) 均为 CCSprite 中心锚点（container
# 104×104 / equip_frame 72），Host 左上原点 = 源中心−半容器（y 翻转），已固化进 tscn。
const HERO_GAP_X: float = 92.0
const LOOT_GAP_X: float = 70.0
# 贴图显示尺寸 = 原始像素 ÷ CS（源 createSprite 等价，照 readequip_icon 口径；heroxp 条无 TextureConfig
# 条目）。2026-08-19 修：原尺寸显示致条大 1.28×（107×17 vs 源 83.5×13.3 点）。
const CONTENT_SCALE: float = 1.28125
# 经验条三层 + EXP 文本源位（源 stagedone.lua:364-374，Cocos 头像 container 104×104 左下原点，
# y=-8/-30 = 头像底下方 8/30 → Godot 左上原点中心线 y = 104+8=112 / 104+30=134）。
# bar/full 源锚点 (0,0.5)（左中）→ Godot centered=false + 左上 y = 112 - 显示高(17/CS)/2；
# barBg 源默认锚点 (0.5,0.5) 中心 (40,-8) → Godot centered=true + (40,112)。
const HERO_CONTAINER_H: float = 104.0
const HERO_EXP_BAR_TEX_H: float = 17.0
const HERO_EXP_BAR_CENTER_Y: float = HERO_CONTAINER_H + 8.0
const HERO_EXP_BAR_POS: Vector2 = Vector2(0.0, HERO_EXP_BAR_CENTER_Y - HERO_EXP_BAR_TEX_H / CONTENT_SCALE * 0.5)
const HERO_EXP_BAR_BG_POS: Vector2 = Vector2(40.0, HERO_EXP_BAR_CENTER_Y)
const HERO_EXP_LABEL_CENTER: Vector2 = Vector2(38.0, HERO_CONTAINER_H + 30.0)
const HERO_EXP_LABEL_SIZE: Vector2 = Vector2(80.0, 18.0)
const HERO_EXP_FONT_SIZE: int = 18
const MAX_STARS: int = 3
# battleStatist 按钮 Scale9 尺寸/CAP（贴图路径走公共常量；本场景独有的尺寸）。
const BATTLE_STATIST_SIZE: Vector2 = Vector2(70.0, 50.0)
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
var _content: Control = null       # 合并后指向 self（保留以兼容 animator/test 的 _content.get_node 调用）

# 装配节点（animator 操作，从 _content get_node as 取）
var _light: Sprite2D = null
var _info_bg: TextureRect = null   # 2026-08-28 批 G：Sprite2D→TextureRect（显示尺寸=568×346.6 ÷CS，独立于子坐标系——源 Cocos 贴图 contentSize 缩放不传子节点变换）
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
var _battle_statist_btn: Button = null
var _battle_count_label: Label = null
var _hero_host: Control = null     # %HeroHost：hero icon 数量动态，procedural 挂此（起始坐标固化进 .tscn）
var _loot_host: Control = null     # %LootHost：loot icon 数量动态，procedural 挂此


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # 接收 gui_input（点击空白跳过）
	HudOverlay.apply_identity("battle")   # 批 G P2-2：显式声明（真实链路靠 battle_scene:226 残留 identity 恰好隐藏 HUD 属脆弱设计）
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


# UI 节点已全部固化进 stage_done_scene.tscn（2026-08-05 合并 content.tscn）。
# _content 指向 self，保留以兼容 animator/test 的 _content.get_node("%..") 调用（最小改动）。
func _build_content() -> void:
	_content = self
	_light = _content.get_node("%Light") as Sprite2D
	_info_bg = _content.get_node("%InfoBg") as TextureRect
	_star_nodes.clear()
	for i in MAX_STARS:
		_star_nodes.append((_content.get_node("%Star" + str(i + 1)) as Sprite2D))
	_replay_btn = _content.get_node("%Replay") as TextureButton
	_next_btn = _content.get_node("%Next") as TextureButton
	_exp_label = _content.get_node("%Exp") as Label
	_gold_label = _content.get_node("%Gold") as Label
	_lv_label = _content.get_node("%Lv") as Label
	_battle_statist_btn = _content.get_node("%BattleStatistBtn") as Button
	_battle_count_label = _content.get_node("%BattleCount") as Label
	_hero_host = _content.get_node("%HeroHost") as Control
	_loot_host = _content.get_node("%LootHost") as Control


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


# Button 已静态化进 .tscn（%BattleStatistBtn + %BattleCount Label 子节点）。
# 运行时只补 Scale9 样式（apply_with_label 不传文案，避免与 %BattleCount 双重显示）+ 文案 + 信号。
func _fill_battle_statist() -> void:
	UiScale9Button.apply_with_label(
		_battle_statist_btn,
		ALPHA_HVGA_DIR + StageSettlementCommon.BATTLE_STATIST_TEX,
		ALPHA_HVGA_DIR + StageSettlementCommon.BATTLE_STATIST_PRESS_TEX,
		StageSettlementCommon.BATTLE_STATIST_CAP)
	_battle_count_label.text = StageSettlementCommon.statist_label_text(_cm)
	_battle_statist_btn.pressed.connect(_on_battle_statist_pressed)


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
			"stars": int(hinfo.get("stars", 0)),   # 源 stars=hero._stars（旧硬编码 0 系漏译，2026-08-28 补）
			"level": int(hinfo.get("level", 1)),
			"hp": int(hinfo.get("hp", 0)),
			"mp": int(hinfo.get("mp", 0)),
		}, _cm)
		ri.position = Vector2(HERO_GAP_X * i, 0.0)
		ri.icon.modulate.a = 0.0
		_hero_host.add_child(ri)   # 起始坐标已固化进 %HeroHost.position，此处相对 host 横向排列
		# 经验条三层（源 stagedone.lua:364-371,443-449）：bg 静态底（中心锚 40,-8）+ progress 前景
		# （左中锚 0,-8，scaleX 动画）+ full 满级覆盖。y 翻转：Cocos -8（底下方 8）→ Godot 中心线 112。
		# 显示尺寸 ÷CS；bar.scale.y = 1/CS 为 scaleX 动画的基准（animator/skip 乘 bar.scale.y 复原）。
		var bar_bg := Sprite2D.new()
		bar_bg.texture = StageSettlementCommon.load_texture(ALPHA_HVGA_DIR + HERO_BAR_BG_TEX)
		bar_bg.centered = true
		bar_bg.position = HERO_EXP_BAR_BG_POS
		bar_bg.scale = Vector2.ONE / CONTENT_SCALE
		ri.icon.add_child(bar_bg)
		_hero_bar_bgs.append(bar_bg)
		var bar := Sprite2D.new()
		bar.texture = StageSettlementCommon.load_texture(ALPHA_HVGA_DIR + HERO_BAR_TEX)
		bar.centered = false
		bar.position = HERO_EXP_BAR_POS
		var pre_exp: int = int(hinfo.get("exp", 0))
		var pre_max: int = int(hinfo.get("max_exp", 1))
		bar.scale = Vector2(clampf(float(pre_exp) / float(maxi(pre_max, 1)), 0.0, 1.0), 1.0) / CONTENT_SCALE
		ri.icon.add_child(bar)
		_hero_bars.append(bar)
		# 满级态覆盖（源 stagedone.lua:1676-1742 isMaxLevel 显示 full bar）；当前数据层 is_max_level 兜底 false。
		var bar_full := Sprite2D.new()
		bar_full.texture = StageSettlementCommon.load_texture(ALPHA_HVGA_DIR + HERO_BAR_FULL_TEX)
		bar_full.centered = false
		bar_full.position = HERO_EXP_BAR_POS
		bar_full.scale = Vector2.ONE / CONTENT_SCALE
		bar_full.visible = bool(hinfo.get("is_max_level", false))
		ri.icon.add_child(bar_full)
		_hero_bar_fulls.append(bar_full)
		var exp_lbl := Label.new()
		exp_lbl.text = "EXP +" + str(int(hinfo.get("add_hero_exp", 0)))
		exp_lbl.size = HERO_EXP_LABEL_SIZE
		exp_lbl.position = HERO_EXP_LABEL_CENTER - HERO_EXP_LABEL_SIZE * 0.5
		exp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		exp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var exp_ls := LabelSettings.new()
		exp_ls.font_size = HERO_EXP_FONT_SIZE
		exp_lbl.label_settings = exp_ls
		ri.icon.add_child(exp_lbl)
		_hero_icon_nodes.append(ri)


func _create_loot_icons() -> void:
	var loot_list: Dictionary = _param.get("loot_list", {})
	var i: int = 0
	for id in loot_list:
		var info: Dictionary = loot_list[id]
		var amount: int = int(info.get("amount", 1))
		var icon: Control = ReadequipIcon.create_icon(int(id), amount, _cm)
		icon.position = Vector2(LOOT_GAP_X * i, 0.0)
		icon.scale = Vector2.ZERO
		_loot_host.add_child(icon)
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
	# fade 组终态（源各段动画均淡入到 1；skip 须补全，否则 kill 冻结在中间透明度）
	_info_bg.modulate.a = 1.0
	_light.modulate.a = 1.0
	_battle_statist_btn.modulate.a = 1.0
	_replay_btn.modulate.a = 1.0
	_next_btn.modulate.a = 1.0
	var stars: int = int(_param.get("stars", 0))
	for i in range(stars):
		if i < _star_nodes.size():
			(_star_nodes[i] as Sprite2D).scale = Vector2.ONE / CONTENT_SCALE   # 星贴图÷CS 终态（批 G：源显示 star_left 87×90）
	var heroes: Array = _param.get("heroes", [])
	for i in range(_hero_icon_nodes.size()):
		var ri: ReadheroIcon = _hero_icon_nodes[i]
		ri.icon.modulate.a = 1.0
		ri.icon.rotation = 0.0
		ri.position.y = 0.0
		var hinfo: Dictionary = heroes[i] if i < heroes.size() else {}
		var t_exp: int = int(hinfo.get("t_exp", 0))
		var t_max: int = int(hinfo.get("t_max_exp", 1))
		if i < _hero_bars.size():
			var bar: Sprite2D = _hero_bars[i]
			# ratio × bar.scale.y（=1/CS 基准）保持 scaleX 动画与创建口径一致
			bar.scale.x = clampf(float(t_exp) / float(max(t_max, 1)), 0.0, 1.0) * bar.scale.y
		ri.refresh_level(int(hinfo.get("t_level", 1)))
	for icon in _loot_icon_nodes:
		(icon as Control).scale = Vector2.ONE
		(icon as Control).rotation = 0.0
	if _animator != null:
		_animator.play_button()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		skip_anim()


# 音效：stagedonelsr clickReply → stageDone.replay = common_click_feedback（soundres:168）。
func _on_replay_pressed() -> void:
	StageSettlementCommon.replay_stage(int(_param.get("stage_id", 0)))


func _on_next_pressed() -> void:
	StageSettlementCommon.next_stage(int(_param.get("stage_id", 0)))
