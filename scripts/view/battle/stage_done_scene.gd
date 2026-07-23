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
const SOURCE_UI_PREFIX: String = "UI/alpha/HVGA/"  # 源 getBattleBgRes 返路径前缀
const MAIN_SCENE_PATH: String = "res://scenes/main_menu/main_scene.tscn"

# 源 stagedone.lua 坐标常量（960×640 设计坐标系）。
# 静态节点（bg/shelter/light/star×3/info_bg 父/replay/next）坐标已固化进 stage_done_content.tscn，
# 这里仅保留动态节点（hero/loot icon）+ InfoBg 内 icon texture fill + battleStatist 子（Button + Label）所需常量。
const HERO_ORI_X: float = 195.0                     # 源 :21 hero_ori_x
const HERO_ORI_Y: float = 243.0                     # 源 :22
const HERO_GAP_X: float = 92.0                      # 源 :23
const LOOT_ORI_X: float = 200.0                     # 源 :16 loot_ori_x
const LOOT_ORI_Y: float = 100.0                     # 源 :17
const LOOT_GAP_X: float = 70.0                      # 源 :18
const BAR_OFFSET: Vector2 = Vector2(0.0, -8.0)      # 源 :368 bar @ccp(0,-8)（相对 hero icon）
const EXP_LABEL_OFFSET: Vector2 = Vector2(38.0, -30.0)  # 源 :373
const MAX_STARS: int = 3
# battleStatistNode 子（Button + BattleCount Label）procedural fill 挂 BattleStatistNode
const BATTLE_STATIST_TEX: String = "herodetail-upgrade.png"            # 源 :1575 battleStatist
const BATTLE_STATIST_PRESS_TEX: String = "herodetail-upgrade-mask.png" # 源 :1592 battleStatist_press
const BATTLE_STATIST_CAP: Rect2 = Rect2(20.0, 20.0, 20.0, 20.0)       # 源 :1576 capInsets CCRectMake(20,20,20,20)
const BATTLE_STATIST_SIZE: Vector2 = Vector2(70.0, 50.0)              # 源 :1584
const BATTLE_STATIST_LABEL_OFFSET: Vector2 = Vector2(35.0, 0.0)       # 源 :1616 battleCount (35,0)
# InfoBg 内 icon texture（tscn texture 留空，运行时 fill；xpicon 缺图 _load 容错 null 不报错）
const GOLD_ICON_TEX: String = "goldicon_small.png"  # 源 :1535 gold_icon
const EXP_ICON_TEX: String = "xpicon.png"           # 源 :1716 exp_title
const HERO_BAR_TEX: String = "heroxp-progress.png"  # 源 :367 bar

var _param: Dictionary = {}
var _cm: ConfigManager = null
var _animator: StageDoneAnimator = null
var _anim_playing: bool = false    # 源 animPlaying（skipAnim 守卫 + animator 设 false 收尾）
var _content: Control = null       # stage_done_content.tscn 实例（静态结构容器）

# 装配节点（animator 操作，从 _content get_node as 取）
var _light: Sprite2D = null
var _info_bg: Sprite2D = null
var _star_nodes: Array = []         # Sprite2D[]
var _hero_icon_nodes: Array = []    # ReadheroIcon[]
var _hero_bars: Array = []          # Sprite2D[]（经验条，bar scaleX 动画用）
var _loot_icon_nodes: Array = []    # Control[]
var _replay_btn: TextureButton = null
var _next_btn: TextureButton = null
var _exp_label: Label = null        # 源 ui.exp_label（玩家经验跳动）
var _gold_label: Label = null       # 源 ui.gold_label
var _lv_label: Label = null         # 源 ui.lv（玩家等级，playLevelAnim 更新）
var _battle_statist_node: Sprite2D = null  # 源 :1560 battleStatistNode（"数据"按钮）


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
	bg.texture = _load_bg()
	var player_info: Dictionary = _param.get("player_info", {})
	_lv_label.text = "LV " + str(int(player_info.get("ori_level", 1)))
	var is_key: bool = bool(_param.get("is_key_stage", false))
	_replay_btn.visible = is_key   # 源 playButtonAnim :574 setVisible(isKeyStage)
	_replay_btn.pressed.connect(_on_replay_pressed)
	_next_btn.pressed.connect(_on_next_pressed)


# 填 InfoBg 内动态 icon texture（tscn texture 留空，运行时 fill；xpicon 缺图 _load 容错 null）。
func _fill_info_bg_icons() -> void:
	(_info_bg.get_node("GoldIcon") as Sprite2D).texture = _load(ALPHA_HVGA_DIR + GOLD_ICON_TEX)
	(_info_bg.get_node("ExpIcon") as Sprite2D).texture = _load(ALPHA_HVGA_DIR + EXP_ICON_TEX)


# 源 :1560-1618 battleStatistNode（Scale9Sprite 按钮图 + battleCount "数据" Label，照源 capInsets 20,20,20,20）。
# 父 Sprite2D 在 .tscn（pos + modulate.a=0 独立 fade），Button + Label procedural fill 挂父（Scale9 复杂构造）。
func _fill_battle_statist() -> void:
	var btn: Button = UiScale9Button.make_centered(
		ALPHA_HVGA_DIR + BATTLE_STATIST_TEX,
		ALPHA_HVGA_DIR + BATTLE_STATIST_PRESS_TEX,
		BATTLE_STATIST_LABEL_OFFSET,
		BATTLE_STATIST_SIZE,
		BATTLE_STATIST_CAP)
	btn.pressed.connect(_on_battle_statist_pressed)
	_battle_statist_node.add_child(btn)
	var count := Label.new()
	count.name = "BattleCount"
	count.text = _statist_label_text()
	count.position = BATTLE_STATIST_LABEL_OFFSET
	_battle_statist_node.add_child(count)


func _statist_label_text() -> String:
	# 源 T(LSTR("STAGEDONE.DATA"))
	if _cm != null:
		return str(_cm.get_lstr("STAGEDONE.DATA"))
	return "数据"


# 源 doClickStatist → ed.ui.battleStatist.create(ed.engine.unit_list)。finalizer 快照 unit_list 存入 last_result。
# panel 全屏模态挂 scene 根（Control），setup 后自管理（cExit/遮罩关闭 queue_free）。
func _on_battle_statist_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var panel := BattleStatisticsPanel.new()
	add_child(panel)
	panel.setup(Array(GameData.last_result.get("unit_list", [])), _cm)


# 源 :349-387 createHeroIcon（readhero.createIcon + 经验条 bar + exp Label）。
# 初始 icon modulate.a=0（playHeroAnim fade in）；bar scaleX=pre_exp/pre_max（playHeroBarAnim 动画到 tExp/tMaxExp）。
func _create_hero_icons() -> void:
	var heroes: Array = _param.get("heroes", [])
	for i in heroes.size():
		var hinfo: Dictionary = heroes[i]
		var ri := ReadheroIcon.new()
		# 源 :355-363 createIcon level=hero.level（pre 等级，动画到 t_level）
		ri.setup({
			"id": int(hinfo.get("id", 0)),
			"rank": int(hinfo.get("rank", 1)),
			"stars": 0,
			"level": int(hinfo.get("level", 1)),
			"hp": int(hinfo.get("hp", 0)),   # 源 :360 传 readhero.createIcon → _add_hp_info 画血条
			"mp": int(hinfo.get("mp", 0)),   # 源 :361
		}, _cm)
		ri.position = Vector2(HERO_ORI_X + HERO_GAP_X * i, HERO_ORI_Y)
		ri.icon.modulate.a = 0.0   # 源 playHeroAnim :466 setOpacity(0)
		_content.add_child(ri)   # setup 内部已 add icon 到 self（照 battle_hero_panel:55）
		# 源 :367-371 bar heroxp-progress.png scaleX(hero.exp/hero.maxExp)（pre 经验）
		var bar := Sprite2D.new()
		bar.texture = _load(ALPHA_HVGA_DIR + HERO_BAR_TEX)
		bar.centered = false
		bar.position = BAR_OFFSET
		var pre_exp: int = int(hinfo.get("exp", 0))
		var pre_max: int = int(hinfo.get("max_exp", 1))
		bar.scale.x = clampf(float(pre_exp) / float(maxi(pre_max, 1)), 0.0, 1.0)
		ri.icon.add_child(bar)
		_hero_bars.append(bar)
		# 源 :372-374 exp Label "EXP +addHeroExp"（随 icon modulate 显示，静态）
		var exp_lbl := Label.new()
		exp_lbl.text = "EXP +" + str(int(hinfo.get("add_hero_exp", 0)))
		exp_lbl.position = EXP_LABEL_OFFSET
		ri.icon.add_child(exp_lbl)
		# 源 :360-361 hp/mp 传 readhero.createIcon → ReadheroIcon._add_hp_info 画血条（icon 内部，无需外部 Label）
		_hero_icon_nodes.append(ri)


# 源 :491-511 createLootIcon（readequip.createStagedoneLootIcon）。初始 scale=0（playLootAnim 弹出）。
func _create_loot_icons() -> void:
	var loot_list: Dictionary = _param.get("loot_list", {})
	var i: int = 0
	for id in loot_list:
		var info: Dictionary = loot_list[id]
		var amount: int = int(info.get("amount", 1))
		var icon: Control = ReadequipIcon.create_icon(int(id), amount, _cm)
		icon.position = Vector2(LOOT_ORI_X + LOOT_GAP_X * i, LOOT_ORI_Y)
		icon.scale = Vector2.ZERO   # 源 playLootAnim :527 setScale(0)
		_content.add_child(icon)
		_loot_icon_nodes.append(icon)
		i += 1


# 源 skipAnim（:869-908）：kill tween + 跳到终态 + playButtonAnim。
func skip_anim() -> void:
	if not _anim_playing:
		return
	_anim_playing = false
	if _animator != null:
		_animator.kill()
	# 源 :873-878 label 终值
	_exp_label.text = "+" + str(int(_param.get("exp", 0)))
	_gold_label.text = "+" + str(int(_param.get("gold", 0)))
	# 源 :879-882 star 终态（scale=1）
	var stars: int = int(_param.get("stars", 0))
	for i in range(stars):
		if i < _star_nodes.size():
			(_star_nodes[i] as Sprite2D).scale = Vector2.ONE
	# 源 :883-892 hero 终态（opacity=255 + bar scaleX=tExp/tMaxExp + refreshLevel(tLevel)）
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
	# 源 :893-897 loot 终态（scale=1）
	for icon in _loot_icon_nodes:
		(icon as Control).scale = Vector2.ONE
	# 源 :907 playButtonAnim（button fade in）
	if _animator != null:
		_animator.play_button()


# 源 registerTouchHandler（:1279-1286）：点击空白 → skipAnim。
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		skip_anim()


# 源 doClickReplay（:93-110）：replaceScene(stagedetail)。单机化：回 main_scene。
# 音效：stagedonelsr clickReply → stageDone.replay = common_click_feedback（soundres:168）。
func _on_replay_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	SceneManager.change_scene(MAIN_SCENE_PATH)


# 源 doClickNext（:111-132）：popScene。单机化：回 main_scene。
func _on_next_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	SceneManager.change_scene(MAIN_SCENE_PATH)


func _load(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


# bg 资源：StageAccount.get_battle_bg_res 返源路径 "UI/alpha/HVGA/xxx.png" → 转 res://assets/...
func _load_bg() -> Texture2D:
	var src_path: String = StageAccount.get_battle_bg_res(int(_param.get("stage_id", 0)), _cm)
	return _load(src_path.replace(SOURCE_UI_PREFIX, ALPHA_HVGA_DIR))
