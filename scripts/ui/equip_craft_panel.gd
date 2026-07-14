class_name EquipCraftPanel
extends PopWindow

## 装备合成面板（View 层）— 照源 ui/equipcraft.lua（1366 行）。
## Step 1+2+3：骨架 + 主面板 + 合成窗口 + createCraftTree 合成树 + craftEquip 合成执行闭环。
## Step 4（playCraftEffect 特效 + history 历史记录 + createInfoButton/puton 穿戴）/ Step 5（入口集成 + 音效）后续轮。
## 单机化：从 HeroDetailPanel 装备槽进（hero/target_id/sid 已定），跳过源 equipboard 完整面板
## （equipLayer 用本地 ofcraft 装备展示照源翻译）。Logic 走 EquipCraftManager.synthesize_equip。
## 坐标：全屏元素（_craft_window/_equip_layer/infoButton）走 _g(BattleViewCoords.to_godot)；
## craftWindow(bg)内局部元素（tree/history，源 add craftWindow.mainLayer）走 EquipCraftTree._gl
## （源 bg 369×493 CCSprite 子节点原点=左下角 y-up，_craft_window 代表 bg 中心，故 _gl 翻 Y + 减半宽高）。

signal equipped_changed   # 穿戴后通知调用方刷新（HeroDetailPanel 接 → refresh_content 装备槽）
signal jump_to_stage(stage_id: int)   # P1-10：获取途径跳转（源 doClickGetWay → stageselect.createByStage）


# ── 坐标常量（源 cocos 值）──────────────────────────────────────────
const CRAFT_WINDOW_POS: Vector2 = Vector2(548.0, 240.0)   # 源 createCraftWindow :1258 进场后
const EQUIP_LAYER_POS: Vector2 = Vector2(252.0, 240.0)    # 源 equipLayer.ui.frame :1256 进场后
const CLOSE_BTN_POS: Vector2 = Vector2(800.0, 50.0)
const CLOSE_BTN_SIZE: Vector2 = Vector2(80.0, 40.0)
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/backbtn.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/backbtn-disabled.png"
const ROOT_ICON_SCALE: float = 60.0 / 72.0                # 源 createIcon(id, 60)（equipLayer 装备图标）
const CRAFT_BG_PATH: String = "res://assets/ui/alpha/HVGA/equip_craft_bg.png"
# ── 颜色（源 ccc3，合成树颜色已迁 EquipCraftTree）──────────────────
const COLOR_RED: Color = Color(1.0, 0.0, 0.0)             # 源 255,0,0（infoButton 等级不足）
const COLOR_BROWN: Color = Color(50.0 / 255.0, 41.0 / 255.0, 31.0 / 255.0)      # 源 50,41,31（prompt 提示文字）
# ── 文字（源 LSTR，合成树文字已迁 EquipCraftTree）──────────────────
const TEXT_SYNTHESIS_SUCCESS: String = "合成成功"         # 源 EQUIPCRAFT.SYNTHESIS_SUCCESS
const TEXT_SYNTHESIS_FAILURE: String = "合成失败"         # 源 EQUIPCRAFT.SYNTHESIS_FAILURE
const TEXT_NO_MATERIAL: String = "没有合适的材料，去收集一些吧"  # 源 EQUIPCRAFT.NO_SUITABLE_MATERIAL...
# ── Step 4 常量（createInfoButton/puton + history + playCraftEffect）──
const TEXT_EQUIPMENT: String = "装备"                    # 源 EQUIPCRAFT.EQUIPMENT（infoButton heroDetail）
const TEXT_CONFIRM: String = "确认"                      # 源 CHATCONFIG.CONFIRM
const TEXT_WAY_TO_GET_BTN: String = "获取途径"           # 源 EQUIPCRAFT.WAY_TO_GET（infoButton 无配方）
const TEXT_SYNTHESIS_FORMULA: String = "合成公式"        # 源 EQUIPCRAFT.SYNTHESIS_FORMULA（infoButton 有配方未开）
const TEXT_BINDS_WHEN_EQUIPPED: String = "装备后与英雄绑定"  # 源 EQUIPCRAFT.BINDS_WHEN_EQUIPPED...
const TEXT_REQUIRED_HERO_LEVEL: String = "需要英雄等级 %d"  # 源 EQUIPCRAFT.REQUIRED_HERO_LEVEL___D
const TEXT_NEED_CRAFT_FIRST: String = "此装备需要先合成"  # 源 EQUIPCRAFT.THIS_PIECE_OF_EQUIPMENT_NEED_TO_BE_SYNTHESIZED_FIRST
const TEXT_CHAPTER_YET_TO_OPEN: String = "章节尚未开启"  # 源 EQUIPCRAFT.CHAPTER_YET_TO_OPEN（获取途径未开）
const INFO_BTN_POS: Vector2 = Vector2(147.0, 40.0)       # 源 :689 infoButton
const INFO_BTN_SIZE: Vector2 = Vector2(110.0, 40.0)
const INFO_REMARK_POS: Vector2 = Vector2(147.0, 80.0)    # 源 :678 infoButtonRemark
const HISTORY_ORIGIN: Vector2 = Vector2(55.0, 350.0)     # 源 :843 ori
const HISTORY_OFFSET_X: float = 58.0                     # 源 :844 offsetX
const HISTORY_ICON_SCALE: float = 40.0 / 72.0            # 源 createSmallIcon（~40px）
const HISTORY_ARROW_PATH: String = "res://assets/ui/alpha/HVGA/view_history_arrow.png"  # 源 :855
const PROMPT_BG_PATH: String = "res://assets/ui/alpha/HVGA/craft_promt_bg.png"          # 源 :331


var cm: Variant = null
var pd: PlayerData = null
var hero: HeroInstance = null
var _target_id: int = 0                 # 源 self.id（合成目标装备 id）
var _context: String = ""               # 源 self.context（heroDetail/handbook）
var _hid: int = 0                       # 源 self.hid
var _sid: int = 0                       # 源 self.sid
var _equip_layer: Control = null        # 源 equipLayer.ui.frame（ofcraft 装备展示）
var _craft_window: Control = null       # 源 craftWindow.mainLayer
var _tree: Control = null               # 源 tree.layer（合成树层）
var _tree_data: Dictionary = {}         # 源 self.tree（节点引用：name/rootBg/children/amountLabel/costBg/cost/craftLabel）
var _craft_window_data: Dictionary = {} # 源 self.craftWindow（nodeid/nodeNeed/nodeAmount/nodeRepeat/expense）
var _components: int = 0                # 源 self.components
var _craft_id: int = 0                  # 源 self.craftid（当前合成树显示的目标）
var _lack_of_component: bool = false    # 源 self.lackOfComponent
var _is_crafting: bool = false          # 源 self.isCrafting
var _craft_btn: Button = null           # 源 tree.craftButton + craftLabel（合成/返回按钮）
var _get_way_buttons: Array = []        # 源 self.getWayButton
var _get_way_ids: Array = []            # 源 self.getWayID
# Step 4（playCraftEffect + history + createInfoButton/puton）
var _history: Array = []                 # 源 self.history（历史条目 [{id,iconBg}]）
var _history_id: int = 0                 # 源 self.historyid
var _history_layer: Control = null       # 源 draglist.listLayer（HBoxContainer 降级，本项目不滚动）
var _info_button: Button = null          # 源 infoButton + infoButtonLabel
var _info_remark: Label = null           # 源 infoButtonRemark（等级需求文字）
var _is_open: bool = true                # 源 self.isOpen（openCraftPanel/closeCraftPanel，默认开）
var _has_play_puton_effect: bool = false # 源 self.hasPlayPutonEffect


# 源 cocos(800×480 左下) → Godot(960×640 左上)：cx+80, 560-cy（同 fragment_compose_panel 范式）。
# 用于全屏元素（_craft_window/_equip_layer/infoButton，add container）。
func _g(pos: Vector2) -> Vector2:
	return BattleViewCoords.to_godot(pos.x, pos.y)


# 源 create(config) :1301 + createPanel :1269。单机化：hero/target_id/sid 由 HeroDetailPanel 传入。
func setup_panel(p_target_id: int, p_cm: Variant, p_pd: PlayerData, p_hero: HeroInstance = null, p_context: String = "heroDetail", p_sid: int = 0) -> void:
	_target_id = p_target_id
	cm = p_cm
	pd = p_pd
	hero = p_hero
	_context = p_context
	_sid = p_sid
	if hero != null:
		_hid = hero.inst_id
	setup()
	_create_close_button()
	_create_equip_layer()
	_create_craft_window(_target_id)
	_init_history()
	_create_info_button()   # 源 :1283 enter 回调
	register_on_enter(func() -> void: AudioPlayer.play_sfx("common_popup_window"))   # 源 equipcraftlsr openWindow :15


func _create_close_button() -> void:
	var btn: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS_RES, CLOSE_BTN_POS)
	btn.pressed.connect(_on_close_pressed)
	container.add_child(btn)


func _on_close_pressed() -> void:
	AudioPlayer.play_sfx("common_close_popup_window")   # 源 equipcraftlsr closeWindow :19
	remove_window()


# 源 equipboard.init("ofcraft", {id, level}) 的 ofcraft 语义本地化翻译。
# 源 equipLayer 提供 ui.frame（装备图标 + 详情）+ refreshAmount（刷新拥有数量）。
# 本项目从 HeroDetailPanel 进（hero 已定），equipLayer 只展示合成目标装备图标 + 拥有数量。
func _create_equip_layer() -> void:
	_equip_layer = Control.new()
	_equip_layer.position = _g(EQUIP_LAYER_POS)
	container.add_child(_equip_layer)
	_refresh_amount()


# 源 equipLayer:refreshAmount（equipboard 刷新装备拥有数量）。
func _refresh_amount() -> void:
	if _equip_layer == null:
		return
	for c in _equip_layer.get_children():
		c.queue_free()
	if _target_id > 0:
		var icon: Control = ReadequipIcon.create_icon(_target_id, _get_amount(_target_id), cm)
		icon.scale = Vector2(ROOT_ICON_SCALE, ROOT_ICON_SCALE)
		_equip_layer.add_child(icon)


# 源 createCraftWindow :1246：合成窗口背景 equip_craft_bg + createCraftTree 初次 + 进场动画。
func _create_craft_window(id: int) -> void:
	_craft_window = Control.new()
	_craft_window.position = _g(CRAFT_WINDOW_POS)
	container.add_child(_craft_window)
	var bg := TextureRect.new()
	bg.texture = load(CRAFT_BG_PATH)
	bg.position = -bg.get_minimum_size() / 2.0   # 源 setPosition(400,240) 中心锚定
	_craft_window.add_child(bg)
	_create_craft_tree(id, false)


# 源 createCraftTree :927-1233（核心合成树）— 委托 EquipCraftTree 控 ≤400。
func _create_craft_tree(id: int, skip_anim: bool) -> void:
	EquipCraftTree.create_craft_tree(self, id, skip_anim)


# 源 craftEquip :368：lackOfComponent/createNeedCraftPrompt + checkMoneyEnough + upCraft（合成）。
func _on_craft_pressed() -> void:
	if _is_crafting:
		return   # 源 :384
	if _components < 1:
		# P1-10：照源 :207-219 components==0 时 historyid>1 返回上一级（setHistory），否则才关
		if _history_id > 1:
			_set_history(_history_id - 1, 0)   # 源 self:setHistory(self.historyid - 1)
		else:
			remove_window()
		return
	if _lack_of_component:
		AudioPlayer.play_sfx("common_alert")   # 源 equipcraftlsr clickCraftButtonDisenabled :35
		_create_need_craft_prompt()   # 源 craftEquip :372 createNeedCraftPrompt
		return
	if not _check_money_enough():
		AudioPlayer.play_sfx("common_alert")   # 源 clickCraftButtonDisenabled
		_show_toast(TEXT_SYNTHESIS_FAILURE)   # 源 showHandyDialog useMidas 单机化降级
		return
	AudioPlayer.play_sfx("common_click_feedback")   # 源 equipcraftlsr clickCraftButton :31
	_perform_craft()


# 源 upCraft :289-318 + craftReply :394。单机化：直调 EquipCraftManager.synthesize_equip。
func _perform_craft() -> void:
	_is_crafting = true
	var ok: bool = EquipCraftManager.synthesize_equip(pd, _craft_id)
	if ok:
		_play_craft_effect()   # 源 craftReply :400 → playCraftEffect（材料飞行+refresh+重建+puton）
	else:
		AudioPlayer.play_sfx("common_alert")   # 源 equipcraftlsr craftFailed :51
		_show_toast(TEXT_SYNTHESIS_FAILURE)
	_is_crafting = false


# 源 refreshReplyData :503-517：equipLayer:refreshAmount（数量刷新）。
func _refresh_reply_data() -> void:
	_refresh_amount()


# 源 checkMoneyEnough :4：craftWindow.expense <= ed.player._money。
func _check_money_enough() -> bool:
	var expense: int = int(_craft_window_data.get("expense", 0))
	return expense <= _player_money()


# 源 getAmount :1330：ed.player.equip_qunty[id]（装备拥有数量）。
func _get_amount(id: int) -> int:
	if pd == null:
		return 0
	return int(pd.items.get(id, 0))


# 源 getComponents :1334：equipcraft[id].Components。
func _get_components(id: int) -> int:
	return int(EquipcraftData.get_recipe(id, cm).get("Components", 0))


# 源 ed.isEquipCraftable(cid)：cid 在 equipcraft 表有 Components>0 → 可递归合成。
func _is_craftable(cid: int) -> bool:
	return _get_components(cid) > 0


func _player_money() -> int:
	if pd == null or pd.hero_manager == null:
		return 0
	return pd.hero_manager.gold


func _equip_name(id: int) -> String:
	return cm.get_lstr(String(cm.get_raw_table("Equip").get(str(id), {}).get("Name", "")))


# 源 ed.showToast（本项目 Toast autoload，headless 安全降级）。
func _show_toast(text: String) -> void:
	if Engine.is_editor_hint():
		return
	var toast_node: Node = Engine.get_main_loop().root.get_node_or_null("/root/Toast")
	if toast_node != null and toast_node.has_method("show_text"):
		toast_node.show_text(text)


# ===== Step 4：playCraftEffect 合成动画 + puton 穿戴 + createNeedCraftPrompt =====

# 源 playCraftEffect :409-482：合成成功动画（材料飞向终点 142,226 + refresh + 重建 + putonEffect）。
# FCA eff_UI_craft_above/below.abc 待 Phase 4 FCA UI 特效支持，本项目 Tween 实现材料飞行（核心表现）。
func _play_craft_effect() -> void:
	var children: Array = _tree_data.get("children", [])
	if children.is_empty():
		return
	var end_pos: Vector2 = EquipCraftTree._gl(Vector2(142.0, 226.0))   # 源 :411（bg 局部→_craft_window 局部）
	var node_need: Array = _craft_window_data.get("nodeNeed", [])
	var nodeid: Array = _craft_window_data.get("nodeid", [])
	for k in range(children.size()):
		var amount: int = int(node_need[k]) if k < node_need.size() else 0
		var fly_count: int = min(amount, 5)        # 源 :418 math.min(amount, 5)
		for i in range(fly_count):
			var element: Control = ReadequipIcon.create_icon(int(nodeid[k]), 0, cm)
			element.scale = Vector2(EquipCraftTree.CHILD_ICON_SCALE, EquipCraftTree.CHILD_ICON_SCALE)
			element.position = (children[k] as Control).position
			_tree.add_child(element)
			var tw: Tween = create_tween().set_parallel(false)
			tw.tween_interval(0.05 * i)            # 源 :428 dt=0.05*(i-1)
			tw.tween_property(element, "position", end_pos, 0.4).set_trans(Tween.TRANS_SINE)
			tw.tween_property(element, "modulate:a", 0.0, 0.2)
			tw.tween_callback(element.queue_free)
	_refresh_reply_data()                          # 源 refreshReplyData :443
	_show_toast(TEXT_SYNTHESIS_SUCCESS)            # 源 :450/454
	_create_craft_tree(_craft_id, true)            # 源 :444 重建合成树
	if _context == "heroDetail":                   # 源 :446-451 heroDetail 合成成功 → putonEffect
		_play_puton_effect()


# 源 playPutonEffect :484-501：穿戴提示（hlv>=elv 才提示，一次性）。
func _play_puton_effect() -> void:
	if _has_play_puton_effect:
		return
	var judge: Array = _get_judge_level()
	if int(judge[0]) < int(judge[1]):
		return
	_has_play_puton_effect = true                 # 源 :500


# 源 getJudgeLevel :519-525：ed.canWearEquip(hid,eid) → [hlv, elv]。
func _get_judge_level() -> Array:
	var hlv: int = hero.level if hero != null else 0
	var elv: int = int(cm.get_raw_table("Equip").get(str(_target_id), {}).get("Level Requirement", 0))
	return [hlv, elv]


# 源 createNeedCraftPrompt :321-366：lackOfComponent 时点合成按钮的提示。
# 遍历 nodeAmount<nodeNeed 且 isCraftable 的材料 → 显示"需先合成"提示框；否则 showToast NO_MATERIAL。
func _create_need_craft_prompt() -> void:
	var node_amount: Array = _craft_window_data.get("nodeAmount", [])
	var node_need: Array = _craft_window_data.get("nodeNeed", [])
	var nodeid: Array = _craft_window_data.get("nodeid", [])
	var children: Array = _tree_data.get("children", [])
	var show_need: bool = false
	for i in range(node_amount.size()):
		if int(node_amount[i]) < int(node_need[i]) and _is_craftable(int(nodeid[i])):
			if i < children.size() and is_instance_valid(children[i]):
				var prompt_bg := TextureRect.new()
				prompt_bg.texture = load(PROMPT_BG_PATH)
				prompt_bg.position = (children[i] as Control).position + Vector2(0.0, -20.0)  # 源 :334 y+20（y-up +20=图标上方 → GD y-down 翻方向 -20，T1 核实 2026-07-14 修）
				prompt_bg.size = Vector2(180.0, 40.0)
				_tree.add_child(prompt_bg)
				var lbl := Label.new()
				lbl.text = TEXT_NEED_CRAFT_FIRST   # 源 :338
				lbl.position = Vector2(10.0, 12.0)
				lbl.modulate = COLOR_BROWN
				prompt_bg.add_child(lbl)
				var tw: Tween = create_tween().set_parallel(false)
				tw.tween_interval(1.0)             # 源 :345 DelayTime 1
				tw.tween_property(prompt_bg, "modulate:a", 0.0, 0.5)  # 源 :346 FadeOut 0.5
				tw.tween_callback(prompt_bg.queue_free)
			show_need = true
			break
	if not show_need:
		_show_toast(TEXT_NO_MATERIAL)             # 源 :364


# 源 putonEquip :526-561 + putonReply :562-573：heroDetail 穿戴闭环。
# 本项目 HeroManager.wear_equip(inst_id, slot) 照源 main.lua:1750（从 hero_equip[tid][rank] 查目标穿），
# 不传 eid（合成目标=hero_equip 该槽应穿装备）、不校验 level/rank（合成时保证）。等级 UI 防护照源 :528。
func _puton_equip() -> void:
	var judge: Array = _get_judge_level()
	if int(judge[0]) < int(judge[1]):
		_show_toast(TEXT_REQUIRED_HERO_LEVEL % int(judge[1]))   # 源 :529
		return
	if pd != null and pd.hero_manager != null and hero != null:
		pd.hero_manager.wear_equip(_hid, _sid)     # 源 :538-541 send wear_equip
		equipped_changed.emit()                     # 通知调用方刷新（HeroDetailPanel refresh_content）
	remove_window()                                # 源 putonReply :570 destroy


func _is_equiped() -> bool:
	if hero == null or _sid < 0 or _sid >= hero.equip_slots.size():
		return false
	return int(hero.equip_slots[_sid]) == _target_id


# ===== P1-10：获取途径跳转（源 doClickGetWay :77-89 + doGetWayTouch :91-123）=====

# 源 ed.player:getStageStar(id)（equipcraft doClickGetWay :80）。本项目 StageManager.stage_stars。
func _stage_stars(sid: int) -> int:
	if pd == null or pd.stage_manager == null:
		return 0
	return pd.stage_manager.stage_stars(sid)


# 源 doClickGetWay :77-89：stageType∈{normal,elite} + getStageStar 判定 → pushScene or Toast。
# 本项目 pushScene 降级为 jump_to_stage signal（HeroDetailPanel 接 → main_scene 打开 StageSelectPanel）。
func _on_get_way_clicked(stage_id: int) -> void:
	var st: String = StageAccount.stage_type(stage_id)
	if st != "normal" and st != "elite":
		return   # 源 :79 非 normal/elite 不跳
	var star: int = _stage_stars(stage_id)
	var prev: int = _stage_stars(stage_id - 1)   # 源 :81 getStageStar(id-1)
	if star + prev > 0:
		AudioPlayer.play_sfx("common_click_feedback")
		jump_to_stage.emit(stage_id)   # 源 :83 pushScene(stageselect.createByStage)
		remove_window()   # 关 equip_craft（源 pushScene 换场景）
	else:
		_show_toast(TEXT_CHAPTER_YET_TO_OPEN)   # 源 :86 CHAPTER_YET_TO_OPEN


# 源 doGetWayTouch :91-123：点 board → doClickGetWay(getWayID[i])。本项目 gui_input 简化。
func _make_get_way_handler(idx: int) -> Callable:
	return func(ev: InputEvent) -> void:
		if not _is_open:
			return
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			var ids: Array = _get_way_ids
			if idx < ids.size():
				_on_get_way_clicked(int(ids[idx]))


# 源 openCraftPanel :575-607 / closeCraftPanel :606（isOpen 状态切换）。本项目合成面板默认开，保留接口。
func _open_craft_panel() -> void:
	_is_open = true


func _close_craft_panel() -> void:
	_is_open = false


# ===== Step 4：history 历史记录栏 + createInfoButton 信息按钮 =====

# 源 initHistory :726。
func _init_history() -> void:
	_history = []
	_history_id = 0


# 源 createHistoryLayer :799（draglist 滚动列表）。本项目 draglist 未做，用 HBoxContainer 水平降级（不滚动）。
func _create_history_layer() -> Control:
	if _history_layer != null and is_instance_valid(_history_layer):
		return _history_layer
	_history_layer = HBoxContainer.new()
	_history_layer.position = EquipCraftTree._gl(HISTORY_ORIGIN)
	_history_layer.add_theme_constant_override("separation", 8)
	_craft_window.add_child(_history_layer)
	return _history_layer


# 源 setHistory :838：index==0 追加历史条目（iconBg+arrow）/ index<=len 切回历史（清尾部+重建 tree）。
func _set_history(index: int, id: int) -> void:
	var container: Control = _create_history_layer()
	var len_: int = _history.size()
	if index == 0 or index > len_:
		_history_id = len_ + 1
		var icon_bg: Control = ReadequipIcon.create_icon(id, 0, cm)
		icon_bg.scale = Vector2(HISTORY_ICON_SCALE, HISTORY_ICON_SCALE)
		if len_ > 0:
			var arrow := TextureRect.new()
			arrow.texture = load(HISTORY_ARROW_PATH)
			arrow.custom_minimum_size = Vector2(20.0, 20.0)
			container.add_child(arrow)
		container.add_child(icon_bg)
		icon_bg.gui_input.connect(_make_history_handler(len_ + 1))
		_history.append({"id": id, "iconBg": icon_bg})
	elif index <= len_:
		_history_id = index
		for i in range(index, len_):
			if i < _history.size() and is_instance_valid(_history[i]["iconBg"]):
				(_history[i]["iconBg"] as Control).queue_free()
		_history.resize(index)
		if index - 1 < _history.size():
			_create_craft_tree(int(_history[index - 1]["id"]), false)


# 源 doTreeNodeTouch :258-288：点子材料 → setHistory(0, nodeid[i]) + createCraftTree(nodeid[i])。
func _make_tree_node_handler(idx: int) -> Callable:
	return func(ev: InputEvent) -> void:
		if not _is_open:
			return
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			var node_amount: Array = _craft_window_data.get("nodeAmount", [])
			if idx < node_amount.size() and int(node_amount[idx]) < 10000:   # 源 :267 已装备不进树
				AudioPlayer.play_sfx("common_click_feedback")   # 源 equipcraftlsr clickTreeNode :39
				var nodeid: Array = _craft_window_data.get("nodeid", [])
				var cid: int = int(nodeid[idx])
				_set_history(0, cid)                  # 源 :277
				_create_craft_tree(cid, false)        # 源 :278


# 源 doClickInHistory :749-772：点历史图标 → setHistory(id) 切回。
func _make_history_handler(idx: int) -> Callable:
	return func(ev: InputEvent) -> void:
		if not _is_open:
			return
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_set_history(idx, 0)


# 源 createInfoButton :610-725：信息按钮（context 决定文字）+ remarkText 等级需求 + 点击 doClickInfoButton。
func _create_info_button() -> void:
	var text: String = TEXT_EQUIPMENT
	var remark_text: String = TEXT_BINDS_WHEN_EQUIPPED
	var remark_color: Color = Color(24.0 / 255.0, 108.0 / 255.0, 0.0)   # 源 ed.toccc3(1598976)
	if _context == "heroDetail":
		var judge: Array = _get_judge_level()
		if _is_equiped():
			text = TEXT_CONFIRM                          # 源 :618
			remark_text = TEXT_REQUIRED_HERO_LEVEL % int(judge[1])
		elif _get_amount(_target_id) == 0:
			text = TEXT_WAY_TO_GET_BTN if _get_components(_target_id) == 0 else TEXT_SYNTHESIS_FORMULA  # 源 :621-625
		if int(judge[0]) < int(judge[1]):                # 源 :648-652 等级不足红字
			remark_text = TEXT_REQUIRED_HERO_LEVEL % int(judge[1])
			remark_color = COLOR_RED
	else:
		text = TEXT_CONFIRM                              # 源 handbook :642
		var elv: int = int(cm.get_raw_table("Equip").get(str(_target_id), {}).get("Level Requirement", 0))
		remark_text = TEXT_REQUIRED_HERO_LEVEL % elv     # 源 :657-658
	_info_remark = Label.new()
	_info_remark.text = remark_text
	_info_remark.position = _g(INFO_REMARK_POS)
	_info_remark.modulate = remark_color
	container.add_child(_info_remark)
	_info_button = Button.new()
	_info_button.text = text
	_info_button.position = _g(INFO_BTN_POS) - INFO_BTN_SIZE / 2.0
	_info_button.size = INFO_BTN_SIZE
	_info_button.pressed.connect(_on_info_pressed)
	container.add_child(_info_button)


# 源 doClickInfoButton :150-173：handbook→open/destroy，heroDetail amount>0→putonEquip，isEquiped→destroy。
func _on_info_pressed() -> void:
	if _context == "handbook":
		if not _is_open:
			_open_craft_panel()
		else:
			remove_window()
		return
	if _get_amount(_target_id) > 0 and not _is_equiped():
		AudioPlayer.play_sfx("common_click_feedback")   # 源 equipcraftlsr clickWearEquip :27
		_puton_equip()                                  # 源 :162
		return
	if _get_amount(_target_id) == 0 and not _is_equiped() and not _is_open:
		_open_craft_panel()                             # 源 :166
		return
	if _is_equiped():
		remove_window()                                 # 源 :169
