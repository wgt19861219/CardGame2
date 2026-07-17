class_name HeroDetailPanel
extends PopWindow

## 英雄详情面板（View 层）— 属性 + 装备槽 + 升星/分解/强化按钮（信号）。
## Phase A+B 重构（2026-07-17）：base 层 + tab view 全静态化进 hero_detail_content.tscn（instantiate + fill），
## 位置/size 编辑器可视化调。tab（detail=属性 / card=图鉴 / skill=技能）visible 切换（不再 free+重建）。
## 信号由调用方接 hero_manager.evolve/split + pd.enhance_equip（单机化省源 net 层）。
## 照源 heropackage.lua / equipstrengthen.lua 交互简化。

signal evolve_requested
signal split_requested
signal upgrade_rank_requested              # 进阶（rank+1，6 槽穿齐 Hero_equip[rank] 配方）
signal upgrade_skill_requested(idx: int)   # 技能升级（idx 0-3）

# base + tab view 子场景（Phase A+B 静态化：位置+size 在 .tscn 可视化）。
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/hero_detail_content.tscn")
# 源 baseres.lua:5 att_name 全集 21 个（照源 attributes.lua 循环 #att_name，禁裁剪）。
const DISPLAY_ATTRIBS: Array[String] = ["STR", "INT", "AGI", "HP", "AD", "AP", "ARM", "MR", "CRIT", "MCRIT", "HPS", "MPS", "DODG", "ARMP", "MRI", "LFS", "CDR", "HEAL", "HIT", "SKL", "SILR"]
# 源 baseres.lua:80 att_pre（属性显示前缀 LSTR key）。SILR 源 T("") 空 → 用 key 本身 fallback。
const ATTR_PRE_LSTR: Dictionary = {
	"STR": "BASERES.STRENGTH_", "INT": "BASERES.INTELLIGENCE_", "AGI": "BASERES.AGILITY_",
	"HP": "BASERES.MAXIMUM_HP_", "AD": "BASERES.PHYSICAL_ATTACK_", "AP": "BASERES.MAGIC_STRENGTH_",
	"ARM": "BASERES.PHYSICAL_ARMOR_", "MR": "BASERES.MAGIC_RESISTANCE_",
	"CRIT": "BASERES.PHYSICAL_CRIT_", "MCRIT": "BASERES.MAGIC_CRIT_",
	"HPS": "BASERES.HP_REPLIES_", "MPS": "BASERES.ENERGY_RECOVERY_", "DODG": "BASERES.DODGE_",
	"ARMP": "BASERES.PHYSICAL_ARMOR_PENETRATION", "MRI": "BASERES.IGNORE_MAGIC_RESISTANCE",
	"LFS": "BASERES.VAMPIRE_LEVEL_", "CDR": "BASERES.REDUCE_ENERGY_CONSUMPTION",
	"HEAL": "BASERES.IMPROVE_THERAPEUTIC_SKILL_EFFECT",
	"HIT": "baseres.1.10.1.004", "SKL": "baseres.1.10.1.005",
}
# 源 baseres.lua:105 att_suffix（属性后缀，大多空）。
const ATTR_SUFFIX: Dictionary = {"CDR": "%", "HEAL": "%", "SKL": " "}
# 源 param.lua:54 skill_unlock_color_text（rank→颜色 LSTR key）。
const RANK_COLOR_LSTR: Dictionary = {
	1: "HERODETAILRES.WHITE", 2: "HERODETAILRES.GREEN", 3: "HERODETAILRES.GREEN",
	4: "HERODETAILRES.BLUE", 5: "HERODETAILRES.BLUE", 6: "HERODETAILRES.BLUE",
	7: "HERODETAILRES.PURPLE", 8: "HERODETAILRES.PURPLE", 9: "HERODETAILRES.PURPLE",
	10: "HERODETAILRES.PURPLE", 11: "HERODETAILRES.PURPLE",
	12: "HERODETAILRES.ORANGE", 13: "HERODETAILRES.ORANGE", 14: "HERODETAILRES.ORANGE",
	15: "HERODETAILRES.ORANGE", 16: "HERODETAILRES.ORANGE", 17: "HERODETAILRES.ORANGE",
	18: "HERODETAILRES.RED", 19: "HERODETAILRES.RED", 20: "HERODETAILRES.RED",
	21: "HERODETAILRES.RED", 22: "HERODETAILRES.RED", 23: "HERODETAILRES.RED",
}
# 源 window.lua LSTR key（技能解锁 / 分解二次确认文案）。
const LSTR_SKILL_UNLOCK: StringName = &"HERODETAILSKILL.ADVANCED_TO__S_TO_UNLOCK"
const LSTR_SPLIT_CONFIRM: StringName = &"window.1.10.1.003"
const LIST_TOP: float = 415.0
const LIST_LEFT: float = 24.0
const LINE_HEIGHT: float = 30.0
# 源 getEquipIconPos（herodetail/window.lua:1100-1108）：6 槽 2 列 × 3 行，环绕角色立绘。
const EQUIP_POS_X: float = 255.0      # 源 :1101 equip_icon_pos_x
const EQUIP_POS_Y: float = 385.0      # 源 :1102 equip_icon_pos_y
const EQUIP_X_GAP: float = 289.0      # 源 :1103 左/右列间距
const EQUIP_Y_GAP: float = 70.0       # 源 :1104 行间距
const EQUIP_SLOT_COUNT: int = 6       # 源 createEquipIcons :1080 6 槽
const EQUIP_GRAY_MODULATE: Color = Color(0.4, 0.4, 0.4, 1.0)   # 源 setSpriteGray 未穿戴配方灰显
const SKILL_COUNT: int = 4                 # 源 4 技能槽（skillstren.lua createSkill）
# 源 skillstren.lua 技能行坐标（skillLayer 挂 animLayer 原点，ccp 为 cocos 世界坐标）。
# ori_height=350（:750）/ bd_height=90（:751 行高）。第 i 行（i 从 0）：icon ccp(320, 350-90*i)。
const SKILL_ORI_HEIGHT: float = 350.0       # 源 :750 ori_height
const SKILL_BD_HEIGHT: float = 90.0         # 源 :751 bd_height（行高）
const SKILL_ICON_COCOS_X: float = 320.0     # 源 :424 icon ccp(320, ori-bd*i)
const SKILL_NAME_COCOS_X: float = 365.0     # 源 :427 nameLabel ccp(365, ori+20-bd*i)
const SKILL_LVL_COCOS_X: float = 365.0      # 源 :322 lvl ccp(365, ori-5-bd*i)
const SKILL_BTN_COCOS_X: float = 495.0      # 源 :351 升级按钮 ccp(495, ori-15-bd*i)
const SKILL_NAME_DY: float = 20.0           # 源 name y 偏移 +20
const SKILL_LVL_DY: float = -5.0            # 源 lvl y 偏移 -5
const SKILL_BTN_DY: float = -15.0           # 源 btn y 偏移 -13-2
const SKILL_BTN_SIZE: Vector2 = Vector2(80.0, 28.0)
const EQUIP_FRAME_WHITE_PATH: String = "res://assets/ui/alpha/HVGA/equip_frame_white.png"
const UI_PATH_PREFIX: String = "UI/"       # 源路径前缀 → res://assets/ui/
const UI_PATH_REPLACE: String = "res://assets/ui/"
const SKILL_GRAY_MODULATE: Color = Color(0.4, 0.4, 0.4, 1.0)   # 源 setSpriteGray 灰显近似
const SKILL_ICON_BTN_SIZE: Vector2 = Vector2(40.0, 40.0)   # 技能图标可点击区
const SKILL_DESC_POS: Vector2 = Vector2(400.0, 100.0)      # 描述弹板位置
const SKILL_GROWTH_COLOR: Color = Color(1.0, 0.81, 0.07)   # 源 ccc3(231,206,19) 成长值黄
const GS_POP_SCALE: float = 1.2                             # 源 ScaleTo(0.2,1.2)
const GS_POP_DURATION: float = 0.2                          # 源 0.2s
# 源 createBottomButtons（window.lua:1395-1663）三 tab：detail(属性)/card(图鉴)/skill(技能)。
const TAB_DETAIL: String = "detail"   # 源 doClickDetail → setOpenMode("att") 属性层
const TAB_CARD: String = "card"       # 源 doClickCard → setOpenMode("card") 图鉴层
const TAB_SKILL: String = "skill"     # 源 doClickSkill → setOpenMode("skill") 技能层
const DEFAULT_TAB: String = TAB_CARD   # 用户指示（2026-07-17）：默认 card 图鉴。源 setOpenMode(nil)=doMoveBack 无 tab，用户要进显图鉴
const BASE_SLIDE_OFFSET: float = 140.0   # 源 doMove（window.lua:300）base container 右移量，让位 tab 内容
# 源 doOpenDetail/Skill/Card pop endPos=ccp(-200,0)（window.lua:430/386/513）：tab 内容 container 显示态左移 200。
# tab 内容层挂 animLayer 原点（cocos 世界坐标），内容 ccp 需叠加此 pop 偏移。
const TAB_POP_OFFSET_X: float = -200.0
# 源 att 内容走 draglist→att.bg(ccp(400,240), attributes.lua:603)→container 链，att ccp 额外 +400（bg 基准）。
# skill/card 内容直接挂 container（无 bg 中间层），只叠 TAB_POP_OFFSET_X。
const ATT_BG_COCOS_X: float = 400.0

var hero: HeroInstance = null
var cm: Variant = null
var hero_manager: HeroManager = null
var pd: PlayerData = null
var _desc_label: Label = null   # 当前技能描述 Label（null 无，源 destroyDescBoard）
var _gs_label: Label = null     # GS 战斗力 Label（.tscn %GsNum，源 ui.gs createInfoBoard:1254-1268）
var _pre_gs: int = -1           # 源 pregs（上次显示 gs，refreshgsAfterWear:172/175 比对）
var _current_tab: String = ""   # 当前激活 tab（源 self.openMode：nil/att/card/skill）
var _tab_buttons: Dictionary = {}   # tab_key → Button（.tscn %TabBtn，源 ui.detail/card/skill）
var _base_layer: Control = null   # .tscn %BaseLayer（base 元素层），开 tab 时整体右移让位（照源 doMove window.lua:300 ccp(140,0)）
var _tab_views: Dictionary = {}    # Phase B：tab_key → Control（.tscn %TabCardView/Detail/Skill，visible 切换）
var _skill_host: Control = null    # .tscn %SkillListHost（技能行动态挂）
var _desc_host: Control = null     # .tscn %DescHost（技能描述动态挂）


func setup_panel(p_hero: HeroInstance, p_cm: Variant, p_mgr: HeroManager = null, p_pd: PlayerData = null) -> void:
	hero = p_hero
	cm = p_cm
	hero_manager = p_mgr
	pd = p_pd
	setup()   # PopWindow.setup（shade + container）
	_build_content()


# 建 UI 内容。Phase A+B：base + tab view 从 .tscn instantiate（位置/size 可视化）+ fill 动态数据/样式；
# tab 内容 fill 一次到各 host（visible 切换，不再 free+重建）。
# 源 createWindow（window.lua:2384-2396）base 常显 + setOpenMode 开 tab overlay。
func _build_content(tab: String = DEFAULT_TAB) -> void:
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	_base_layer = content.get_node("%BaseLayer") as Control
	var result: Dictionary = HeroDetailBuilder.setup_base(_base_layer, hero, cm)
	_gs_label = result["gs_label"] as Label
	_tab_buttons = result["tab_buttons"] as Dictionary
	_pre_gs = hero.gs if hero != null else -1
	_bind_signals()
	_show_equips()
	_tab_views = {
		"card": content.get_node("%TabCardView") as Control,
		"detail": content.get_node("%TabDetailView") as Control,
		"skill": content.get_node("%TabSkillView") as Control,
	}
	_skill_host = (_tab_views["skill"] as Control).get_node("%SkillListHost") as Control
	_desc_host = (_tab_views["skill"] as Control).get_node("%DescHost") as Control
	_fill_card_view()
	_fill_attributes()
	_fill_skills()
	_show_tab_content(tab)


## 升星/技能升级后刷新内容（数据变 → 重建 UI）。call_deferred 避信号处理中 free 按钮自身崩。
func refresh_content() -> void:
	call_deferred("_rebuild_content")


func _rebuild_content() -> void:
	var saved_tab: String = _current_tab if _current_tab != "" else DEFAULT_TAB
	for c in container.get_children():
		c.free()
	_desc_label = null   # 旧 desc label 已 free，清引用
	_build_content(saved_tab)


# 绑定 .tscn 静态按钮信号：%CloseBtn + 4 action（升星/进阶/分解/强化）+ 3 tab。
func _bind_signals() -> void:
	(_base_layer.get_node("%CloseBtn") as BaseButton).pressed.connect(func() -> void:
		AudioPlayer.play_sfx("common_close_popup_window")   # 源 heroDetail.closeWindow（soundres.lua:204）
		remove_window())
	_wire_action_button("%EvolveBtn", evolve_requested, "common_click_feedback")   # 源 heroDetail.clickUpgrade（soundres.lua:217）
	_wire_action_button("%UpgradeRankBtn", upgrade_rank_requested, "common_click_feedback")   # 源 hero_upgrade（:867-901 rank+1）
	(_base_layer.get_node("%SplitBtn") as BaseButton).pressed.connect(_on_split_pressed)
	(_base_layer.get_node("%EnhanceBtn") as BaseButton).pressed.connect(_on_strengthen_pressed)
	for key in _tab_buttons:
		(_tab_buttons[key] as BaseButton).pressed.connect(_on_tab_pressed.bind(key))


func _wire_action_button(node_path: String, sig: Signal, sound_key: String) -> void:
	(_base_layer.get_node(node_path) as BaseButton).pressed.connect(func() -> void:
		if not sound_key.is_empty():
			AudioPlayer.play_sfx(sound_key)
		sig.emit())


# 源 equipstrengthen 独立面板（2176 行），本项目从 HeroDetailPanel "强化"按钮进。
func _on_strengthen_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm, pd)
	panel.show_window(get_parent())


# ---- Phase B：tab 内容 fill（挂各 host，visible 切换）----

# 标记动态 tab 内容子节点（测试识别 "tab 内容已渲染"；Phase B 不用于 free）。
func _add_tab_content(host: Control, node: Node) -> void:
	node.set_meta(&"tab_content", true)
	host.add_child(node)


# fill card view（%CardFrame texture + %CardArtHost Art + %CardNameLabel 名字，源 card.lua:127-140）。
func _fill_card_view() -> void:
	if cm == null:
		return
	var view: Control = _tab_views["card"] as Control
	HeroDetailBuilder.setup_card_view(view, hero, cm)
	var art_host: Control = view.get_node("%CardArtHost") as Control
	for c in art_host.get_children():
		c.set_meta(&"tab_content", true)   # Art 标记（测试识别 card 内容渲染）


# 源 attributes.lua:133 createAttDetail 循环 res.att_name（全 21）+ res.att_pre[k]..":" + base + addIcon + add + suffix。
# 本项目合并成单 label "LSTR_pre: all (+add) suffix"（视觉等价简化）。显示等价：源 base+add ≈ 本项目 all=(base+add)。
func _fill_attributes() -> void:
	if hero == null:
		return
	var host: Control = (_tab_views["detail"] as Control).get_node("%AttribListHost") as Control
	var att: Dictionary = ReadheroAttribs.get_hero_att_by_hero(hero, cm)
	# 源 attributes.lua attLayer 挂 animLayer 原点，ccp 为 cocos 世界坐标：list_left=24 / list_top=415（:30-32）。
	var cocos_y: float = LIST_TOP
	for key in DISPLAY_ATTRIBS:
		if not att.has(key):
			continue   # 源 ReadheroAttribs v==0 跳过（仅显示非零属性）
		var row: Dictionary = att[key]
		var pre: String = get_lstr_fallback(ATTR_PRE_LSTR.get(key, ""), key)
		var suffix: String = String(ATTR_SUFFIX.get(key, ""))
		var lbl := Label.new()
		lbl.text = pre + ": " + str(int(row["all"])) + " (+" + str(int(row["add"])) + ")" + suffix
		lbl.position = HeroDetailBuilder.to_godot(LIST_LEFT + TAB_POP_OFFSET_X + ATT_BG_COCOS_X, cocos_y)
		_add_tab_content(host, lbl)
		cocos_y -= LINE_HEIGHT   # 源下一行 cocos y 减（往下）


# cm 可能为 null（测试降级）的 LSTR fallback：key 空或 cm null → 返 fallback（源英文 key）。
func get_lstr_fallback(lstr_key: String, fallback: String) -> String:
	if lstr_key.is_empty() or cm == null:
		return fallback
	return String(cm.get_lstr(lstr_key))


# 源 window.lua:170-191 refreshgsAfterWear：gs 变了 → 更新文本 + 锚点居中 + scale 1.2→1
# （EASE_BACK_OUT）+ 还原锚点左中。本项目调 hero_manager.calc_gs 重算（源读 hero._gs，
# 本项目重算语义等价，第二十七轮）。
func refresh_gs_after_wear() -> void:
	if hero == null or hero_manager == null or _gs_label == null:
		return
	var gs: int = hero_manager.calc_gs(hero)
	if gs == _pre_gs:
		return
	_gs_label.text = str(gs)
	_gs_label.pivot_offset = _gs_label.size * 0.5   # 源 setNodeAnchor(0.5,0.5) 居中缩放
	_pre_gs = gs
	var tw := create_tween()
	tw.tween_property(_gs_label, "scale", Vector2(GS_POP_SCALE, GS_POP_SCALE), GS_POP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_gs_label, "scale", Vector2.ONE, GS_POP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if _gs_label != null:
			_gs_label.pivot_offset = Vector2(0, _gs_label.size.y * 0.5))   # 源 :180 还原 (0,0.5)


# 源 createEquipIcons（herodetail/window.lua:1071-1098）6 槽全显示 + createEquipIcon（:1110-1135）三态：
# ceid>0 已穿戴 / eid>0 未穿戴配方灰显 / eid==0 无配方 unknown 占位（ReadequipIcon.create_icon(0) white 边框）。
# 空槽也连 gui_input 可点进 equipcraft（源 doClickEquip 不检查 isEquiped）。
func _show_equips() -> void:
	if hero == null:
		return
	var host: Control = _base_layer.get_node("%EquipSlotHost") as Control
	var rank_equip: Dictionary = cm.get_raw_table(&"Hero_equip").get(str(hero.tid), {}).get(str(hero.rank), {})
	for i in EQUIP_SLOT_COUNT:
		var ceid: int = int(hero.equip_slots[i]) if i < hero.equip_slots.size() else 0   # 已穿戴
		var eid: int = int(rank_equip.get("Equip" + str(i + 1) + " ID", 0))              # Hero_equip 配方
		var icon: Control = _create_equip_slot_icon(ceid, eid)
		# 源 getEquipIconPos（window.lua:1105-1106）：cocos x = 255+289*((i)%2), y = 385-70*floor(i/2)（i 从 0）。
		# 源 anchor(0.5,0.5) 中心 → Godot Control position = godot_center - icon.size/2（create_icon 显式 set size 可读）。
		var cocos_x: float = EQUIP_POS_X + EQUIP_X_GAP * float(i % 2)
		var cocos_y: float = EQUIP_POS_Y - EQUIP_Y_GAP * float(i / 2)
		icon.position = HeroDetailBuilder.to_godot(cocos_x, cocos_y) - icon.size * 0.5
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.gui_input.connect(_make_equip_click_handler(i))   # 源 doClickEquip → equipcraft（空槽也可点）
		host.add_child(icon)   # 装备挂 %EquipSlotHost（base 层组织，随 base 右移让位）


# 源 createEquipIcon 三态：icon_id = ceid or eid；未穿戴配方（ceid<=0 and eid>0）灰显 setSpriteGray。
func _create_equip_slot_icon(ceid: int, eid: int) -> Control:
	var icon_id: int = ceid if ceid > 0 else eid   # 源 equips[i].id = 0<ceid and ceid or eid
	var icon: Control = ReadequipIcon.create_icon(icon_id, 1, cm)
	icon.set_meta(&"equip_slot", true)   # 标记装备槽（测试计数 + 节点识别）
	if ceid <= 0 and eid > 0:
		icon.modulate = EQUIP_GRAY_MODULATE   # 源 setSpriteGray（未穿戴配方灰显）
	return icon


# 源 heropackage → equipcraft：点装备槽图标 → 弹 EquipCraftPanel（合成/查看该装备配方）。
func _make_equip_click_handler(slot: int) -> Callable:
	return func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_open_equip_craft(slot)


# 源 doClickEquip（herodetail/window.lua:247-276）：item_id = ceid（已穿戴）or eid（配方），传 equipcraft 合成/查看。
func _open_equip_craft(slot: int) -> void:
	if hero == null:
		return
	var ceid: int = int(hero.equip_slots[slot]) if slot >= 0 and slot < hero.equip_slots.size() else 0
	var rank_equip: Dictionary = cm.get_raw_table(&"Hero_equip").get(str(hero.tid), {}).get(str(hero.rank), {})
	var eid: int = int(rank_equip.get("Equip" + str(slot + 1) + " ID", 0))
	var item_id: int = ceid if ceid > 0 else eid   # 源 equips[id].id = ceid or eid
	if item_id <= 0:
		return   # 无配方无穿戴（eid==0 unknown 占位），不弹
	var panel := EquipCraftPanel.new("equipcraft", {})
	panel.setup_panel(item_id, cm, pd, hero, "heroDetail", slot)
	panel.equipped_changed.connect(refresh_content)   # 穿戴后刷新装备槽（灰显配方→已穿戴图标）
	panel.jump_to_stage.connect(_on_equip_craft_jump)   # P1-10：获取途径跳转（源 doClickGetWay）
	panel.show_window(get_parent())   # openWindow 音效由 EquipCraftPanel register_on_enter 自播


# P1-10 源 equipcraft doClickGetWay :83 pushScene(stageselect.createByStage(id))。
# 本项目 stageselect 是弹窗（非场景）：关 hero_detail + 托 main_scene 打开 StageSelectPanel（定位章）。
func _on_equip_craft_jump(stage_id: int) -> void:
	remove_window()   # 源 pushScene 换场景 → 关 hero_detail
	var ms: Node = get_tree().current_scene
	if ms != null and ms.has_method("open_stage_select_by_stage"):
		ms.open_stage_select_by_stage(stage_id)


# 源 skillstren.lua createSkill + createSkillIcon + createSkillUnlockLabel。
# 每槽：技能图标（SkillGroup.Icon + equip_frame_white 边框）+ Display Name。
# rank < SkillGroup[slot].Unlock → 灰显图标 + "rank X 解锁"（源 :442-451，不显示等级+按钮）。
# 否则：lv.X 显示等级 + 升级按钮（源 :452 createSkillLevelBoard）。
# 显示等级 = skill_levels[slot] - InitLevel + 1（源 controller.getCacheSkillLevelDisplay）。
func _fill_skills() -> void:
	if hero == null:
		return
	var sg: Dictionary = cm.get_raw_table(&"SkillGroup").get(str(hero.tid), {})
	for i in SKILL_COUNT:
		var slot_info: Dictionary = sg.get(str(i + 1), {})
		var display_name: String = cm.get_lstr(String(slot_info.get("Display Name", "skill" + str(i + 1))))
		var init_level: int = int(slot_info.get("Init Level", 1))
		var unlock_rank: int = int(slot_info.get("Unlock", 1))
		var icon_res: String = String(slot_info.get("Icon", ""))
		# 源 skillLayer 挂 animLayer 原点，ccp 为 cocos 世界坐标：icon ccp(320, ori_height-bd_height*i)（skillstren.lua:424）。
		var cocos_y: float = SKILL_ORI_HEIGHT - SKILL_BD_HEIGHT * float(i)   # 第 i 行 icon y 基准（i=0→350）
		var locked: bool = hero.rank < unlock_rank
		_create_skill_icon(icon_res, cocos_y, locked, i)   # 源 createSkillIcon + :433 灰显
		var name_lbl := Label.new()
		name_lbl.text = display_name
		name_lbl.position = HeroDetailBuilder.to_godot(SKILL_NAME_COCOS_X + TAB_POP_OFFSET_X, cocos_y + SKILL_NAME_DY)
		_add_tab_content(_skill_host, name_lbl)
		if locked:   # 源 createSkillUnlockLabel :445 ccp(365, ori-5-bd*i)
			var color_text: String = get_lstr_fallback(RANK_COLOR_LSTR.get(unlock_rank, ""), str(unlock_rank))
			var unlock_lbl := Label.new()
			unlock_lbl.text = get_lstr_fallback(LSTR_SKILL_UNLOCK, "rank %s 解锁") % color_text
			unlock_lbl.position = HeroDetailBuilder.to_godot(SKILL_LVL_COCOS_X + TAB_POP_OFFSET_X, cocos_y + SKILL_LVL_DY)
			_add_tab_content(_skill_host, unlock_lbl)
		else:   # 已解锁 → 等级 + 升级按钮（源 lvl ccp(365,ori-5) :322 / btn ccp(495,ori-15) :351）
			var cur_level: int = int(hero.skill_levels[i]) if i < hero.skill_levels.size() else 1
			var show_level: int = cur_level - init_level + 1
			var lvl_lbl := Label.new()
			lvl_lbl.text = "lv." + str(show_level)
			lvl_lbl.position = HeroDetailBuilder.to_godot(SKILL_LVL_COCOS_X + TAB_POP_OFFSET_X, cocos_y + SKILL_LVL_DY)
			_add_tab_content(_skill_host, lvl_lbl)
			_create_skill_upgrade_button(i, HeroDetailBuilder.to_godot(SKILL_BTN_COCOS_X + TAB_POP_OFFSET_X, cocos_y + SKILL_BTN_DY))


# 源 readhero.lua:1011 createSkillIcon + skillstren.lua:758 board_i pressHandler。
# 边框 Sprite2D（equip_frame_white centered 居中）+ 图标 TextureButton（可点击 → 描述弹板）。
# locked=true 灰显（源 skillstren.lua:434 setSpriteGray，modulate 降亮近似）。
func _create_skill_icon(icon_res: String, cocos_y: float, locked: bool, slot: int) -> void:
	var tex: Texture2D = _load_ui_texture(icon_res)
	if tex == null:
		return
	# 源 icon ccp(320, cocos_y) anchor(0.5,0.5) 中心 → Godot 中心点（Sprite2D position=中心）。
	var icon_pos: Vector2 = HeroDetailBuilder.to_godot(SKILL_ICON_COCOS_X + TAB_POP_OFFSET_X, cocos_y)
	var frame := Sprite2D.new()
	frame.texture = _load_texture(EQUIP_FRAME_WHITE_PATH)
	if frame.texture != null:
		frame.position = icon_pos
		if locked:
			frame.modulate = SKILL_GRAY_MODULATE
		_add_tab_content(_skill_host, frame)
	var btn := TextureButton.new()
	btn.texture_normal = tex
	btn.texture_hover = tex
	btn.ignore_texture_size = true
	btn.size = SKILL_ICON_BTN_SIZE
	btn.position = icon_pos - SKILL_ICON_BTN_SIZE * 0.5   # TextureButton 左上 = 中心 - size/2
	if locked:
		btn.modulate = SKILL_GRAY_MODULATE
	btn.pressed.connect(func() -> void: _toggle_skill_desc(slot))
	btn.set_meta(&"skill_icon", true)   # 标记技能图标（测试区分 vs close/action 按钮图）
	_add_tab_content(_skill_host, btn)


func _create_skill_upgrade_button(idx: int, pos: Vector2) -> void:
	# 源 skillstren.lua:345 createSkillLevelBoard 按钮：Sprite herodetail_skill_upgrade_button_1.png 无文字。
	var btn: TextureButton = HeroDetailBuilder.create_skill_upgrade_button(_skill_host, pos + SKILL_BTN_SIZE * 0.5)
	btn.set_meta(&"tab_content", true)   # 标记 tab 内容（测试识别）
	btn.set_meta(&"skill_upgrade", true)   # 标记技能升级按钮（测试识别）
	btn.pressed.connect(func() -> void:
		Events.bus.emit_tutorial_step(&"SUclickLevelup")   # Phase 8 SU（技能升级 → tutorial try_complete）
		upgrade_skill_requested.emit(idx))


# 源 UI 路径 "UI/ITEM/s10.jpg" → res://assets/ui/ITEM/s10.jpg（仿 readhero_icon.gd:81 Portrait 映射）。
func _load_ui_texture(ui_path: String) -> Texture2D:
	if ui_path.is_empty():
		return null
	var path: String = ui_path.replace(UI_PATH_PREFIX, UI_PATH_REPLACE) if ui_path.begins_with(UI_PATH_PREFIX) else ui_path
	return _load_texture(path)


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


# 源 skillstren.lua:14 createDescBoard + :8 destroyDescBoard。点击图标 toggle 描述（源按住 board_i 显示）。
# 描述 = Skill.Description（get_skill_description）+ 成长值（get_skill_desc，黄色）。
func _toggle_skill_desc(slot: int) -> void:
	Events.bus.emit_tutorial_step(&"SUclickSkillButton")   # 源 herodetail/window.lua:1659（点技能按钮）
	if _desc_label != null and int(_desc_label.get_meta("slot", -1)) == slot:
		_hide_skill_desc()
		return
	_hide_skill_desc()
	if hero == null:
		return
	var desc: String = ReadheroSkill.get_skill_description(hero, slot + 1, cm)
	var growth: String = ReadheroSkill.get_skill_desc(hero, slot + 1, cm)
	var lbl := Label.new()
	lbl.text = desc + ("\n" + growth if not growth.is_empty() else "")
	lbl.position = SKILL_DESC_POS
	lbl.add_theme_font_size_override("font_size", 13)
	if not growth.is_empty():
		lbl.modulate = SKILL_GROWTH_COLOR
	_add_tab_content(_desc_host, lbl)
	lbl.set_meta("slot", slot)
	_desc_label = lbl


func _hide_skill_desc() -> void:
	if _desc_label != null:
		_desc_label.queue_free()
		_desc_label = null


# ---- 底栏 tab 切换（源 createBottomButtons + setOpenMode/doClickDetail/Card/Skill）----

# 源 doClickDetail/Card/Skill（window.lua:454/519/391）：点 tab → setOpenMode。同 tab 再点 → setOpenMode(nil) 关（base 回位）。
func _on_tab_pressed(key: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")   # 源 tab 点击反馈
	if _current_tab == key:
		_close_tab()   # 源 doClickX: if layer setOpenMode(nil)（同 tab toggle 关，base 回位）
		return
	_show_tab_content(key)


# 源 setOpenMode（window.lua:318-367）：切 tab layer visible + base 右移让位 + 切选中态。
# Phase B：tab view 常驻（.tscn），visible 切换（不再 free+重建）。
func _show_tab_content(key: String) -> void:
	_current_tab = key
	HeroDetailBuilder.set_tab_selected(_tab_buttons, key)
	if _base_layer != null:
		_base_layer.position.x = BASE_SLIDE_OFFSET   # 源 doMove :300 base 右移让位 tab 内容
	for k in _tab_views:
		(_tab_views[k] as CanvasItem).visible = (k == key)


# 源 setOpenMode(nil) → doMoveBack（window.lua:289-296 base 回 (0,0)）+ destroyXLayer。
func _close_tab() -> void:
	_current_tab = ""
	HeroDetailBuilder.set_tab_selected(_tab_buttons, "")
	if _base_layer != null:
		_base_layer.position.x = 0.0   # 源 doMoveBack :291 base 回位
	for k in _tab_views:
		(_tab_views[k] as CanvasItem).visible = false
	_hide_skill_desc()


# ---- 信号→Logic 便捷封装（调用方接信号后调，或直调）----

# 升星：hero_manager.evolve（扣碎片+金币，stars+1）。返是否成功。
func perform_evolve() -> bool:
	if hero_manager == null or hero == null:
		return false
	var ok: bool = hero_manager.evolve(hero.inst_id)
	if ok:
		AudioPlayer.play_sfx("common_hero_upgrade")   # 源 heroDetail.upgradeReply（升星回复成功，soundres.lua:223）
	else:
		AudioPlayer.play_sfx("common_alert")          # 源 heroDetail.clickDisabledUpgrade（条件不满足拒，soundres.lua:216）
	return ok


# 进阶：hero_manager.upgrade_rank（6 槽穿齐 Hero_equip[rank] 配方 → rank+1 + 重置槽 + 重算 gs）。返是否成功。
func perform_upgrade_rank() -> bool:
	if hero_manager == null or hero == null:
		return false
	var ok: bool = hero_manager.upgrade_rank(hero.inst_id)
	if ok:
		AudioPlayer.play_sfx("common_hero_upgrade")
	else:
		AudioPlayer.play_sfx("common_alert")
	return ok


# 分解按钮：照源 herosplit/window.lua:88-104 firstConfirm popConfirmDialog 二次确认 → emit split_requested。
func _on_split_pressed() -> void:
	# 源 herosplit:97-99 T(LSTR("window.1.10.1.003"), name) = "是否确认分解英雄%s？"
	var display_name: String = HeroDetailBuilder.get_display_name(hero, cm) if hero != null else ""
	var msg_pattern: String = get_lstr_fallback(LSTR_SPLIT_CONFIRM, "确认分解 %s？")
	var confirm := HeroSplitConfirm.new()
	confirm.set_message(msg_pattern % display_name)
	confirm.confirmed.connect(func() -> void: emit_signal("split_requested"))
	get_parent().add_child(confirm)


# 分解：hero_manager.split（移除英雄，返碎片 {fragment_id,count}）。
func perform_split() -> Dictionary:
	if hero_manager == null or hero == null:
		return {}
	return hero_manager.split(hero.inst_id)


# 装备强化：pd.enhance_equip（照源 ui/equipstrengthen + local_server：材料 Enhance Value 经验 +
# Unit Price 金币双消耗，exp 累积）。materials: {item_id:count}（玩家选材料，扣 PlayerData.items）。
# 材料选择 UI 下轮做（源独立 equipstrengthen 面板 2176 行）。
func perform_enhance(slot: int, materials: Dictionary) -> bool:
	if pd == null or hero == null:
		return false
	return pd.enhance_equip(hero.inst_id, slot, materials)


# 技能升级：pd.upgrade_hero_skill（扣技能点 + hero_manager.upgrade_skill_level 扣金币+升技能）。
func perform_upgrade_skill(idx: int) -> bool:
	if pd == null or hero == null:
		return false
	return pd.upgrade_hero_skill(hero.inst_id, idx)
