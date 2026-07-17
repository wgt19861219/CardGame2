class_name StageDoneScene
extends Control

## 战斗胜利结算场景（View 层）— 照源 ui/stagedone.lua 翻译（2026-07-03，Phase 4 续）。
## 第二十一轮：装配初始隐藏态 + 入场动画 Tween 序列（委托 StageDoneAnimator）+ skipAnim 跳过。
## 装配：bg + shelter + light + star_1-3 + info_bg（lv/gold/exp）+ 英雄经验列表 + 掉落列表 + replay/next。
## 单机化：去 guildInstanceData/bestRankReward(PVP)/mercenary/FCA 特效/draglist 滚动/getNewHero announce/
##   battleStatist/isMaxLevel full bar。speedDiv=1（无战斗速度系统）。doClickReplay/Next→main_scene。

const ALPHA_HVGA_DIR: String = "res://assets/ui/alpha/HVGA/"
const SOURCE_UI_PREFIX: String = "UI/alpha/HVGA/"  # 源 getBattleBgRes 返路径前缀
const MAIN_SCENE_PATH: String = "res://scenes/main_menu/main_scene.tscn"

# 源 stagedone.lua 坐标（960×640 设计坐标系）
const LIGHT_POS: Vector2 = Vector2(372.0, 400.0)   # 源 :1354
const STAR_POS: Array = [Vector2(260.0, 402.0), Vector2(378.0, 410.0), Vector2(488.0, 402.0)]  # 源 :5-9
const STAR_TEX: Array = ["star_left.png", "star_center.png", "star_right.png"]  # 源 :1362/1375/1388
const REPLAY_POS: Vector2 = Vector2(710.0, 315.0)  # 源 :1402 replay
const NEXT_POS: Vector2 = Vector2(710.0, 100.0)    # 源 :1425 next
const INFO_BG_POS: Vector2 = Vector2(380.0, 198.0)  # 源 :1450 info_bg
const INFO_LV_OFFSET: Vector2 = Vector2(-60.0, 90.0)    # 源 lv 相对 info_bg
const INFO_GOLD_OFFSET: Vector2 = Vector2(-10.0, 90.0)  # 源 gold_label
const INFO_EXP_OFFSET: Vector2 = Vector2(60.0, 90.0)    # 源 exp_label
# P1-16（2026-07-11）info_bg 装饰背景层 + gold_icon + exp_title + battleStatist（源 stagedone.lua:1457-1618/1713-1738）
const TOP_WIN_BG_1_TEX: String = "wing_win_bg_1.png"       # 源 :1457 top_win_bg_1
const TOP_WIN_BG_2_TEX: String = "wing_win_bg_2.png"       # 源 :1469 top_win_bg_2
const INFO_TITLE_BG_1_TEX: String = "yellowbar_win_bg.png"  # 源 :1481 info_title_bg_1
const INFO_TITLE_BG_2_TEX: String = "shadow_win_bg.png"     # 源 :1493 info_title_bg_2
const GOLD_ICON_TEX: String = "goldicon_small.png"          # 源 :1535 gold_icon
const EXP_ICON_TEX: String = "xpicon.png"                   # 源 :1716 exp_title
const BATTLE_STATIST_TEX: String = "herodetail-upgrade.png"  # 源 :1575 battleStatist
const BATTLE_STATIST_PRESS_TEX: String = "herodetail-upgrade-mask.png"  # 源 :1592 battleStatist_press
const BATTLE_STATIST_CAP: Rect2 = Rect2(20.0, 20.0, 20.0, 20.0)  # 源 :1576 capInsets CCRectMake(20,20,20,20)
const INFO_TOP_WIN_OFFSET: Vector2 = Vector2(0.0, 140.0)    # 源 :1462 top_win_bg (285,380)
const INFO_TITLE_BG_OFFSET: Vector2 = Vector2(0.0, 90.0)    # 源 :1486 info_title_bg_1 (285,295)
const INFO_TITLE_BG2_OFFSET: Vector2 = Vector2(0.0, 40.0)   # 源 :1498 info_title_bg_2 (285,198)
const INFO_GOLD_ICON_OFFSET: Vector2 = Vector2(-40.0, 90.0) # gold_label(-10,90) 左
const INFO_EXP_ICON_OFFSET: Vector2 = Vector2(30.0, 90.0)   # exp_label(60,90) 左
const INFO_STATIST_OFFSET: Vector2 = Vector2(150.0, 90.0)   # 源 :1567 battleStatistNode (530,320)
const BATTLE_STATIST_SIZE: Vector2 = Vector2(70.0, 50.0)    # 源 :1584
const BATTLE_STATIST_LABEL_OFFSET: Vector2 = Vector2(35.0, 0.0)  # 源 :1616 battleCount (35,0)
const HERO_ORI_X: float = 195.0                     # 源 :21 hero_ori_x
const HERO_ORI_Y: float = 243.0                     # 源 :22
const HERO_GAP_X: float = 92.0                      # 源 :23
const LOOT_ORI_X: float = 200.0                     # 源 :16 loot_ori_x
const LOOT_ORI_Y: float = 100.0                     # 源 :17
const LOOT_GAP_X: float = 70.0                      # 源 :18
const BAR_OFFSET: Vector2 = Vector2(0.0, -8.0)      # 源 :368 bar @ccp(0,-8)（相对 hero icon）
const EXP_LABEL_OFFSET: Vector2 = Vector2(38.0, -30.0)  # 源 :373
const SHELTER_COLOR: Color = Color(0.0, 0.0, 0.0, 150.0 / 255.0)  # 源 :1346 ccc4(0,0,0,150)
const MAX_STARS: int = 3

var _param: Dictionary = {}
var _cm: ConfigManager = null
var _animator: StageDoneAnimator = null
var _anim_playing: bool = false    # 源 animPlaying（skipAnim 守卫 + animator 设 false 收尾）

# 装配节点（animator 操作）
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


# 装配（照源 create :1322-1668，初始隐藏态：light/star/hero/loot/button/info_bg 藏，动画显示）。
func setup(p_param: Dictionary, p_cm: ConfigManager) -> void:
	_param = p_param
	_cm = p_cm
	_create_bg()
	_create_shelter()
	_create_light()
	_create_stars()
	_create_info_bg()
	_create_buttons()
	_create_hero_icons()
	_create_loot_icons()
	_animator = StageDoneAnimator.new(self)
	_animator.play_enter()


# 源 stagedone.lua:1330-1340 bg。源 t="Sprite" config={} 无 fix_size（纯 CCSprite，显示=纹理/CS）。
# 保留 PRESET_FULL_RECT 让 anchors 撑满 viewport(960×640)；补 EXPAND_IGNORE_SIZE 让纹理 stretch 满屏（默认 KEEP_SIZE 不拉伸）。
func _create_bg() -> void:
	var bg := TextureRect.new()
	bg.name = "Bg"
	bg.texture = _load_bg()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 装饰节点吞点击（反模式预防）
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


# 源 :1341-1347 shelter ColorLayer ccc4(0,0,0,150)。IGNORE 让点击到根 Control 触发 skip。
func _create_shelter() -> void:
	var shelter := ColorRect.new()
	shelter.name = "Shelter"
	shelter.color = SHELTER_COLOR
	shelter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shelter.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shelter)


# 源 :1348-1358 light lettherebelight.png（初始 modulate.a=0，playLightAnim fade in + 旋转）。
func _create_light() -> void:
	_light = Sprite2D.new()
	_light.name = "Light"
	_light.texture = _load(ALPHA_HVGA_DIR + "lettherebelight.png")
	_light.position = LIGHT_POS
	_light.modulate.a = 0.0   # 源 playLightAnim :135 setOpacity(0)
	add_child(_light)


# 源 :1359-1394 star_1/2/3（初始 scale=0，playStarAnim 弹出）。
func _create_stars() -> void:
	for i in MAX_STARS:
		var star := Sprite2D.new()
		star.name = "Star" + str(i + 1)
		star.texture = _load(ALPHA_HVGA_DIR + STAR_TEX[i])
		star.position = STAR_POS[i]
		star.scale = Vector2.ZERO   # 源 playStarAnim :183 setScale(0)
		add_child(star)
		_star_nodes.append(star)


# 源 :1444-1531 + createTeamExpBar info_bg bigyellowbar + 装饰背景 + lv/gold/exp Label。
# 初始 modulate.a=0（playInfoBgAnim fade in），gold/exp label "+0"（numberJump 跳动）。
# P1-16：补 4 装饰背景层 + gold_icon + exp_title + battleStatistNode（源 :1457-1618/1713-1738）。
func _create_info_bg() -> void:
	_info_bg = Sprite2D.new()
	_info_bg.name = "InfoBg"
	_info_bg.texture = _load(ALPHA_HVGA_DIR + "bigyellowbar.png")
	_info_bg.position = INFO_BG_POS
	_info_bg.modulate.a = 0.0   # 源 playInfoBgAnim fade in（子节点 modulate 级联）
	add_child(_info_bg)
	# 源 :1457-1500 装饰背景层（先 add，z 低，label/icon 叠在上）
	_add_info_sprite(_info_bg, TOP_WIN_BG_1_TEX, INFO_TOP_WIN_OFFSET)
	_add_info_sprite(_info_bg, TOP_WIN_BG_2_TEX, INFO_TOP_WIN_OFFSET)
	_add_info_sprite(_info_bg, INFO_TITLE_BG_2_TEX, INFO_TITLE_BG2_OFFSET)
	_add_info_sprite(_info_bg, INFO_TITLE_BG_1_TEX, INFO_TITLE_BG_OFFSET)
	var player_info: Dictionary = _param.get("player_info", {})
	# 源 :1504-1531 lv（playerInfo.oriLevel 升级前等级）
	_lv_label = Label.new()
	_lv_label.name = "Lv"
	_lv_label.text = "LV " + str(int(player_info.get("ori_level", 1)))
	_lv_label.position = INFO_LV_OFFSET
	_info_bg.add_child(_lv_label)
	# 源 :1532-1558 gold_icon + gold_label "+gold"（numberJump 跳动，初始 +0）
	_add_info_sprite(_info_bg, GOLD_ICON_TEX, INFO_GOLD_ICON_OFFSET)
	_gold_label = Label.new()
	_gold_label.name = "Gold"
	_gold_label.text = "+0"
	_gold_label.position = INFO_GOLD_OFFSET
	_info_bg.add_child(_gold_label)
	# 源 :1713-1738 exp_title(xpicon) + exp_label "+exp"
	_add_info_sprite(_info_bg, EXP_ICON_TEX, INFO_EXP_ICON_OFFSET)
	_exp_label = Label.new()
	_exp_label.name = "Exp"
	_exp_label.text = "+0"
	_exp_label.position = INFO_EXP_OFFSET
	_info_bg.add_child(_exp_label)
	# 源 :1560-1618 battleStatistNode（"数据"按钮，独立 fade，源 :159）
	_battle_statist_node = _create_battle_statist()
	_battle_statist_node.position = INFO_STATIST_OFFSET
	_battle_statist_node.modulate.a = 0.0   # 源 :159 playInfoBgAnim 独立 fade
	_info_bg.add_child(_battle_statist_node)


# info_bg 内装饰 Sprite（z 低，随 _info_bg modulate 级联 fade）。
func _add_info_sprite(parent: Sprite2D, tex_name: String, offset: Vector2) -> void:
	var spr := Sprite2D.new()
	spr.texture = _load(ALPHA_HVGA_DIR + tex_name)
	spr.position = offset
	parent.add_child(spr)


# 源 :1560-1618 battleStatistNode（Scale9Sprite 按钮图 + battleCount "数据" Label，照源 capInsets 20,20,20,20）。
# 注：Button 在 Sprite2D 下点击可能不触发（无 CanvasLayer），节点渲染照源，点击交互待统计面板接入。
func _create_battle_statist() -> Sprite2D:
	var node := Sprite2D.new()
	node.name = "BattleStatistNode"
	var btn: Button = UiScale9Button.make_centered(ALPHA_HVGA_DIR + BATTLE_STATIST_TEX, ALPHA_HVGA_DIR + BATTLE_STATIST_PRESS_TEX, BATTLE_STATIST_LABEL_OFFSET, BATTLE_STATIST_SIZE, BATTLE_STATIST_CAP)
	btn.pressed.connect(_on_battle_statist_pressed)
	node.add_child(btn)
	var count := Label.new()
	count.name = "BattleCount"
	count.text = _statist_label_text()
	count.position = BATTLE_STATIST_LABEL_OFFSET
	node.add_child(count)
	return node


func _statist_label_text() -> String:
	# 源 T(LSTR("STAGEDONE.DATA"))
	if _cm != null:
		return str(_cm.get_lstr("STAGEDONE.DATA"))
	return "数据"


# 源 doClickStatist → 战斗统计弹窗。单机化：暂无统计面板，Toast 占位（结构就位待补弹窗）。
func _on_battle_statist_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	Toast.show_message("战斗统计")


# 源 :1395-1442 replay/next 按钮（初始 modulate.a=0，playButtonAnim fade in）。
func _create_buttons() -> void:
	var is_key: bool = bool(_param.get("is_key_stage", false))
	_replay_btn = TextureButton.new()
	_replay_btn.name = "Replay"
	_replay_btn.texture_normal = _load(ALPHA_HVGA_DIR + "replaybtn.png")
	_replay_btn.texture_pressed = _load(ALPHA_HVGA_DIR + "replaybtn-disabled.png")
	_replay_btn.position = REPLAY_POS
	_replay_btn.modulate.a = 0.0
	_replay_btn.visible = is_key   # 源 playButtonAnim :574 setVisible(isKeyStage)
	_replay_btn.pressed.connect(_on_replay_pressed)
	add_child(_replay_btn)
	_next_btn = TextureButton.new()
	_next_btn.name = "Next"
	_next_btn.texture_normal = _load(ALPHA_HVGA_DIR + "nextstagebtn.png")
	_next_btn.texture_pressed = _load(ALPHA_HVGA_DIR + "nextstagebtn-disabled.png")
	_next_btn.position = NEXT_POS
	_next_btn.modulate.a = 0.0
	_next_btn.visible = true       # 源 :576 setVisible(true)
	_next_btn.pressed.connect(_on_next_pressed)
	add_child(_next_btn)


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
		add_child(ri)   # setup 内部已 add icon 到 self（照 battle_hero_panel:55）
		# 源 :367-371 bar heroxp-progress.png scaleX(hero.exp/hero.maxExp)（pre 经验）
		var bar := Sprite2D.new()
		bar.texture = _load(ALPHA_HVGA_DIR + "heroxp-progress.png")
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
		add_child(icon)
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
