class_name StageFailedScene
extends Control

## 战斗失败结算场景（View 层）— 照源 ui/stagefailed.lua 翻译（2026-07-03，Phase 4 续）。
## 普通关失败：bg + 黑遮罩 + 旋转光 + 失败标题 + 重玩/回主城按钮。
## param 传递：运行时 GameData.last_result（battle 衔接存）→ _ready 读 → setup；单测手动 setup。
## 单机化：createPrompt 升级提示已实现（6 谓词简化版 + Label 降级，源贴图 battledone_failed_*.png 不在仓库）；
##   excavate_mode 分支照源不接（excavate 结算特殊）；battleStatist 战斗统计按钮无对应场景照源不接；
##   doClickBack/doClickMenu 源 replaceScene(stagedetail)/popScene → 本项目回 main_scene（无独立 stagedetail 场景）。
##
## 重构（2026-07-18，hero_detail 范式）：chrome（bg/shelter/light/title/back/menu/battleStatist）静态化进
## scenes/battle/stage_failed_content.tscn（instantiate + add_child + get_node + fill）。Control 场景根，content
## 挂 scene 自身（无 PopWindow container）。动态：bg texture fill / title text fill / back·menu·statist 信号
## 接线 / battleStatist Scale9 StyleBox（apply_with_label）/ battleStatist count Label（procedural 挂 _content）/
## light 旋转 tween / prompt ≤2 Label 挂 %PromptHost。

const CONTENT_SCENE: PackedScene = preload("res://scenes/battle/stage_failed_content.tscn")
# 坐标口径：旧 960×640 时代等比转换（x*1.2, (480-y)*1.333）已退役无调用方；viewport 800×480 后按源坐标直译（y 翻转：godot_y = 480 - cocos_y）。
# P1-16 battleStatist 战斗统计按钮位置常量（贴图/CAP/路径走公共 helper；本场景独有的位置/偏移）。
const BATTLE_STATIST_POS: Vector2 = Vector2(642.0, 160.0)
const BATTLE_STATIST_LABEL_OFFSET: Vector2 = Vector2(35.0, 26.0)

const PROMPT_Y: float = 420.0
const PROMPT_POS: Array[Vector2] = [Vector2(246.0, PROMPT_Y), Vector2(534.0, PROMPT_Y)]
const ROTATE_DURATION: float = 5.0
const TITLE_FAIL_TEXT: String = "失败"
const TITLE_TIMEOUT_TEXT: String = "超时"
const PROMPT_LABELS: Dictionary = {
	"evolve": "英雄可升星", "heroupgrade": "英雄可进阶", "skillupgrade": "技能可升级",
	"equip": "可穿戴装备", "herolevelup": "英雄可升级", "enhance": "装备可强化",
}

var stage_id: int = 0
var lose_type: String = "fail"
var _cm: ConfigManager = null
var _content: Control = null   # .tscn instantiate（chrome 静态节点 + %PromptHost）


func _ready() -> void:
	# 运行时（SceneManager.change_scene 加载后）：从 GameData.last_result 读 param 自动装配
	# 等价源 stagefailed.create(param)（param 由 battle 衔接存入 GameData）
	if GameData.last_result.has("stage_id") and not GameData.last_result.get("victory", true):
		setup(GameData.last_result, GameData.config)


## 装配场景（照源 stagefailed.lua create :144-400 普通关失败分支）。
func setup(p_param: Dictionary, p_cm: ConfigManager) -> void:
	_cm = p_cm
	stage_id = int(p_param.get("stage_id", 0))
	lose_type = String(p_param.get("lose_type", "fail"))
	_build_content()
	_start_light_rotate()
	_create_prompt()


# 建 UI 内容：chrome 静态节点从 .tscn instantiate（位置/size 可视化调）；fill 动态数据 + 接信号。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate()
	add_child(_content)
	# bg texture 动态（源 :162-171 getBattleBgRes，stage_id 决定）。
	(_content.get_node("Bg") as TextureRect).texture = StageSettlementCommon.load_battle_bg(stage_id, _cm)
	# title text 动态（源 :191-201 getLoseTitleRes，lose_type 决定；源 Sprite 资源缺 → Label 降级）。
	(_content.get_node("Title") as Label).text = TITLE_TIMEOUT_TEXT if lose_type == "timeout" else TITLE_FAIL_TEXT
	# back/menu 按钮（源 :202-247 TextureButton + doClickBack/doClickMenu）。
	(_content.get_node("Back") as BaseButton).pressed.connect(_on_back_pressed)
	(_content.get_node("Menu") as BaseButton).pressed.connect(_on_menu_pressed)
	# battleStatist 按钮（源 :345-392 Scale9 + count Label）：.tscn 普通 Button，运行时套 Scale9 StyleBox。
	var statist_btn: Button = _content.get_node("BattleStatist") as Button
	var tex_dir: String = StageSettlementCommon.ALPHA_HVGA_DIR
	UiScale9Button.apply_with_label(statist_btn, tex_dir + StageSettlementCommon.BATTLE_STATIST_TEX, tex_dir + StageSettlementCommon.BATTLE_STATIST_PRESS_TEX, StageSettlementCommon.BATTLE_STATIST_CAP)
	statist_btn.pressed.connect(_on_battle_statist_pressed)
	# battleStatist count Label（源 :388 battleCount "数据"）— procedural 挂 _content（位置=BATTLE_STATIST_POS + OFFSET）。
	var count := Label.new()
	count.text = StageSettlementCommon.statist_label_text(_cm)
	count.position = BATTLE_STATIST_POS + BATTLE_STATIST_LABEL_OFFSET
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(count)


# 旋转 tween procedural 挂 .tscn Light 节点（坑 4 装饰节点 mouse_filter=IGNORE 对 Sprite2D 不适用）。
func _start_light_rotate() -> void:
	var light: Sprite2D = _content.get_node("Light") as Sprite2D
	var t := create_tween().set_loops()   # CCRepeatForever
	t.tween_property(light, "rotation", TAU, ROTATE_DURATION)   # TAU=360°（源 360 度）


# 音效：源 stagefailedlsr clickBack 读 stageFailed.replay，soundres:180 定义 reply（拼写不一致→nil 不播）。
func _on_back_pressed() -> void:
	StageSettlementCommon.goto_main_scene("")


# 音效：源 stagefailedlsr clickMenu → stageFailed.nextStage = common_click_feedback（soundres:181）。
func _on_menu_pressed() -> void:
	StageSettlementCommon.goto_main_scene()


# 贴图资源 battledone_failed_*.png 不在源仓库 → Label 降级（同 title 范式）。
# 谓词简化版（源 readhero.lua:751-829 全队扫描，本项目用现有能力包装）。挂 %PromptHost（procedural）。
func _create_prompt() -> void:
	if _cm == null or GameData.player == null:
		return
	var hm: HeroManager = GameData.player.hero_manager
	var checks: Array[String] = []
	if _can_hero_evolve(hm):
		checks.append("evolve")
	if _can_upgrade_hero(hm):
		checks.append("heroupgrade")
	if _can_skill_upgrade(hm):
		checks.append("skillupgrade")
	if _can_wear_equip(hm):
		checks.append("equip")
	checks.append("herolevelup")
	if _can_enhance_equip(hm):
		checks.append("enhance")
	var host: Control = _content.get_node("%PromptHost") as Control
	for i in range(mini(checks.size(), 2)):
		var label := Label.new()
		label.text = String(PROMPT_LABELS.get(checks[i], checks[i]))
		label.position = PROMPT_POS[i]
		label.add_theme_font_size_override("font_size", 16)
		host.add_child(label)


# 战斗统计面板弹出（公共逻辑，照源 _on_battle_statist_pressed）。
func _on_battle_statist_pressed() -> void:
	StageSettlementCommon.show_battle_statistics(self, _cm)


func _can_hero_evolve(hm: HeroManager) -> bool:
	for hero in hm.heroes.values():
		var h: HeroInstance = hero
		var data := HeroData.from_config(_cm, h.tid)
		if h.stars < data.max_stars:
			var frag_id: int = _cm.get_int(&"Fragment", h.tid, &"Fragment ID")
			var need: int = _cm.get_int(&"HeroStars", h.stars, &"Upgrade Fragments")
			if hm._fragment_count(frag_id) >= need:
				return true
	return false


func _can_upgrade_hero(hm: HeroManager) -> bool:
	for hero in hm.heroes.values():
		if hm.can_upgrade_rank((hero as HeroInstance).inst_id):
			return true
	return false


func _can_skill_upgrade(hm: HeroManager) -> bool:
	for hero in hm.heroes.values():
		var h: HeroInstance = hero
		for i in h.skill_levels.size():
			if h.skill_levels[i] < h.level:
				return true
	return false


func _can_wear_equip(hm: HeroManager) -> bool:
	for hero in hm.heroes.values():
		for slot in (hero as HeroInstance).equip_slots:
			if int(slot) == 0:
				return true
	return false


func _can_enhance_equip(hm: HeroManager) -> bool:
	for hero in hm.heroes.values():
		for slot in (hero as HeroInstance).equip_slots:
			if int(slot) != 0:
				return true
	return false
