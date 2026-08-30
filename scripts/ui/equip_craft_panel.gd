class_name EquipCraftPanel
extends PopWindow

## Step 1+2+3：骨架 + 主面板 + 合成窗口 + createCraftTree 合成树 + craftEquip 合成执行闭环。
## Step 4（playCraftEffect 特效 + history 历史记录）/ Step 5（入口集成 + 音效）。
## 两件套（批 1 Task 10）：静态结构/样式归 equip_craft_content.tscn + default_theme；
## 动态 fill 归 EquipCraftFills（装备详情/历史栏动态行）；合成树构建归 EquipCraftTree（真动态数据
## 结构：components 1-4 + getway 0-3 board 全数据驱动，保留 procedural 挂 %TreeHost）；
## infoButton/puton/playCraftEffect 闭环归 EquipCraftInfoBtn（节点已在 tscn，helper 纯 fill/流程）。

signal equipped_changed   # 穿戴后通知调用方刷新（HeroDetailPanel 接 → refresh_content 装备槽）
signal jump_to_stage(stage_id: int)   # P1-10：获取途径跳转

# panel 层静态化进 equip_craft_content.tscn（CloseBtn + EquipLayer + CraftWindow.Bg + TreeHost
# + HistoryClip + InfoButton/InfoButtonLabel + InfoRemark）。位置/size 可视化，运行时 fill 动态数据/连接信号。
# 合成树（EquipCraftTree）procedural 挂 %TreeHost；历史栏动态行（EquipCraftFills）挂 %HistoryClip。
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/equip_craft_content.tscn")

# ── LSTR key──
const LSTR_SYNTHESIS_SUCCESS: String = "EQUIPCRAFT.SYNTHESIS_SUCCESS"
const LSTR_SYNTHESIS_FAILURE: String = "EQUIPCRAFT.SYNTHESIS_FAILURE"
const LSTR_NO_MATERIAL: String = "EQUIPCRAFT.NO_SUITABLE_MATERIAL_GO_TO_COLLECT_SOME"
const LSTR_NEED_CRAFT_FIRST: String = "EQUIPCRAFT.THIS_PIECE_OF_EQUIPMENT_NEED_TO_BE_SYNTHESIZED_FIRST"
const LSTR_CHAPTER_YET_TO_OPEN: String = "EQUIPCRAFT.CHAPTER_YET_TO_OPEN"
# 历史选中态高亮（源 equipcraft.lua:887-892）：当前 cursor 位置 icon 上叠 equip_craft_select 框。
const HISTORY_CURSOR_RES: String = "res://assets/ui/alpha/HVGA/equip_craft_select.png"


var cm: Variant = null
var pd: PlayerData = null
var hero: HeroInstance = null
var _target_id: int = 0
var _context: String = ""
var _hid: int = 0
var _sid: int = 0
var _content: Control = null            # .tscn 根（EquipCraftContent），info_btn/remark 取节点用
var _equip_layer: Control = null        # .tscn %EquipLayer（装备详情 Frame 容器）
var _icon_host: Control = null          # .tscn %IconHost（EquipLayer 子，挂装备图标）
var _name_label: Label = null           # .tscn %NameLabel（装备名）
var _amount_label: Label = null         # .tscn %AmountLabel（拥有数量）
var _att_host: VBoxContainer = null     # .tscn %AttHost（属性介绍多行）
var _craft_window: Control = null       # .tscn %CraftWindow
var _tree_host: Control = null          # .tscn %TreeHost（_craft_window 子，挂动态 tree/history）
var _tree: Control = null
var _tree_data: Dictionary = {}
var _craft_window_data: Dictionary = {}
var _components: int = 0
var _craft_id: int = 0
var _lack_of_component: bool = false
var _is_crafting: bool = false
var _craft_btn: BaseButton = null
var _craft_btn_label: Label = null
var _get_way_buttons: Array = []
var _get_way_ids: Array = []
# Step 4（playCraftEffect + history）
var _history: Array = []
var _history_id: int = 0
var _history_layer: Control = null
var _info_button: BaseButton = null
var _info_button_label: Label = null
var _info_remark: Label = null
var _is_open: bool = false
var _has_play_puton_effect: bool = false


func setup_panel(p_target_id: int, p_cm: Variant, p_pd: PlayerData, p_hero: HeroInstance = null, p_context: String = "heroDetail", p_sid: int = 0) -> void:
	play_open_sfx = true   # T4：原 register_on_enter 音效样板上收基类
	_target_id = p_target_id
	cm = p_cm
	pd = p_pd
	hero = p_hero
	_context = p_context
	_sid = p_sid
	if hero != null:
		_hid = hero.inst_id
	setup()
	_build_content()
	_refresh_amount()
	_init_history()
	_create_info_button()
	# 源 openCraftPanel（equipcraft.lua:575-587）才建合成树/合成窗口；初始弹窗只显装备+infoButton，
	# 点 infoButton → _open_craft_panel 才 visible=true + _create_craft_tree。受控偏离源架构。
	_craft_window.visible = false


# 建 UI 内容：base 层从 equip_craft_content.tscn instantiate（位置/size 可视化）+ 连接信号。
# 合成树（EquipCraftTree）保留 procedural 挂 %TreeHost（坐标系不变）。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	_content = content
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(_on_close_pressed)
	_equip_layer = _content.get_node("%EquipLayer") as Control
	_icon_host = _content.get_node("%IconHost") as Control
	_name_label = _content.get_node("%NameLabel") as Label
	_amount_label = _content.get_node("%AmountLabel") as Label
	_att_host = _content.get_node("%AttHost") as VBoxContainer
	_craft_window = _content.get_node("%CraftWindow") as Control
	_tree_host = _content.get_node("%TreeHost") as Control
	_info_button = _content.get_node("%InfoButton") as BaseButton
	_info_button_label = _content.get_node("%InfoButtonLabel") as Label
	_info_remark = _content.get_node("%InfoRemark") as Label
	(_info_button as BaseButton).pressed.connect(func() -> void: EquipCraftInfoBtn._on_info_pressed(self))


func _on_close_pressed() -> void:
	AudioPlayer.play_sfx("common_close_popup_window")
	remove_window()


# 装备详情 fill（icon/名/拥有量/属性行）下沉 EquipCraftFills（两件套范式，行数治理）。
func _refresh_amount() -> void:
	EquipCraftFills.fill_equip_layer(self)


# bg 已在 .tscn（%CraftWindow.%Bg，位置/size 静态化），本函数保留 stub 兼容旧调用（仅委托 _create_craft_tree）。
func _create_craft_window(id: int) -> void:
	_create_craft_tree(id, false)


func _create_craft_tree(id: int, skip_anim: bool) -> void:
	EquipCraftTree.create_craft_tree(self, id, skip_anim)


func _on_craft_pressed() -> void:
	if _is_crafting:
		return
	if _components < 1:
		if _history_id > 1:
			_set_history(_history_id - 1, 0)
		else:
			remove_window()
		return
	if _lack_of_component:
		AudioPlayer.play_sfx("common_alert")
		_create_need_craft_prompt()
		return
	if not _check_money_enough():
		AudioPlayer.play_sfx("common_alert")
		_show_toast(cm.get_lstr(LSTR_SYNTHESIS_FAILURE))
		return
	AudioPlayer.play_sfx("common_click_feedback")
	_perform_craft()


func _perform_craft() -> void:
	_is_crafting = true
	var ok: bool = EquipCraftManager.synthesize_equip(pd, _craft_id)
	if ok:
		GameData.mark_save_dirty()   #
		_play_craft_effect()
	else:
		AudioPlayer.play_sfx("common_alert")
		_show_toast(cm.get_lstr(LSTR_SYNTHESIS_FAILURE))
	_is_crafting = false


func _refresh_reply_data() -> void:
	_refresh_amount()


func _check_money_enough() -> bool:
	var expense: int = int(_craft_window_data.get("expense", 0))
	return expense <= _player_money()


func _get_amount(id: int) -> int:
	if pd == null:
		return 0
	return int(pd.items.get(id, 0))


func _get_components(id: int) -> int:
	return int(EquipcraftData.get_recipe(id, cm).get("Components", 0))


func _is_craftable(cid: int) -> bool:
	return _get_components(cid) > 0


func _player_money() -> int:
	if pd == null or pd.hero_manager == null:
		return 0
	return pd.hero_manager.gold


func _equip_name(id: int) -> String:
	return cm.get_lstr(String(cm.get_raw_table("Equip").get(str(id), {}).get("Name", "")))




# ===== Step 4：playCraftEffect 合成动画 + createNeedCraftPrompt =====
# 已拆 EquipCraftInfoBtn.play_craft_effect / create_need_craft_prompt（控 ≤400）。


func _create_info_button() -> void:
	EquipCraftInfoBtn.create_info_button(self)


func _on_info_pressed() -> void:
	EquipCraftInfoBtn._on_info_pressed(self)


func _puton_equip() -> void:
	EquipCraftInfoBtn.puton_equip(self)


func _is_equiped() -> bool:
	return EquipCraftInfoBtn._is_equipped(self)


func _get_judge_level() -> Array:
	return EquipCraftInfoBtn.get_judge_level(self)


func _play_puton_effect() -> void:
	EquipCraftInfoBtn.play_puton_effect(self)


func _play_craft_effect() -> void:
	EquipCraftInfoBtn.play_craft_effect(self)


func _create_need_craft_prompt() -> void:
	EquipCraftInfoBtn.create_need_craft_prompt(self)



func _stage_stars(sid: int) -> int:
	if pd == null or pd.stage_manager == null:
		return 0
	return pd.stage_manager.stage_stars(sid)


# 本项目 pushScene 降级为 jump_to_stage signal（HeroDetailPanel 接 → main_scene 打开 StageSelectPanel）。
func _on_get_way_clicked(stage_id: int) -> void:
	var st: String = StageAccount.stage_type(stage_id)
	if st != "normal" and st != "elite":
		return
	var star: int = _stage_stars(stage_id)
	var prev: int = _stage_stars(stage_id - 1)
	if star + prev > 0:
		AudioPlayer.play_sfx("common_click_feedback")
		jump_to_stage.emit(stage_id)
		remove_window()   # 关 equip_craft
	else:
		_show_toast(cm.get_lstr(LSTR_CHAPTER_YET_TO_OPEN))


func _make_get_way_handler(idx: int) -> Callable:
	return func(ev: InputEvent) -> void:
		if not _is_open:
			return
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			var ids: Array = _get_way_ids
			if idx < ids.size():
				_on_get_way_clicked(int(ids[idx]))


func _open_craft_panel() -> void:
	_is_open = true
	# 源 openCraftPanel（equipcraft.lua:575-587 / :1256-1266）：点 infoButton 后才建合成窗口 + 合成树。
	# :1256-1266 弹性滑入（EaseBackOut position.y -h→0）——用户 2026-08-30 不要此动画（七~九轮
	# 反馈「装备物品触发侧滑」即此），受控偏离：直显不滑入。
	_craft_window.visible = true
	_create_craft_tree(_target_id, false)


func _close_craft_panel() -> void:
	_is_open = false
	_craft_window.visible = false


# ===== Step 4：history 历史记录栏 =====

func _init_history() -> void:
	_history = []
	_history_id = 0


# 历史栏容器构建下沉 EquipCraftFills（挂 %HistoryClip 裁剪域，源 draglist cliprect）。
func _create_history_layer() -> Control:
	return EquipCraftFills.create_history_layer(self)


func _set_history(index: int, id: int) -> void:
	var container_layer: Control = _create_history_layer()
	var len_: int = _history.size()
	if index == 0 or index > len_:
		_history_id = len_ + 1
		var icon_bg: Control = EquipCraftFills.append_history_node(self, container_layer, id)
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
	# 源 equipcraft.lua:887-892：刷新历史 cursor 高亮（当前 _history_id 对应 icon 上叠 select 框）。
	EquipCraftTree.update_history_cursor(self)


func _make_tree_node_handler(idx: int) -> Callable:
	return func(ev: InputEvent) -> void:
		if not _is_open:
			return
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			var node_amount: Array = _craft_window_data.get("nodeAmount", [])
			if idx < node_amount.size() and int(node_amount[idx]) < 10000:
				AudioPlayer.play_sfx("common_click_feedback")
				var nodeid: Array = _craft_window_data.get("nodeid", [])
				var cid: int = int(nodeid[idx])
				_set_history(0, cid)
				_create_craft_tree(cid, false)


func _make_history_handler(idx: int) -> Callable:
	return func(ev: InputEvent) -> void:
		if not _is_open:
			return
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_set_history(idx, 0)
