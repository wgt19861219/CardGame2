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
# 源 isForbidInfoButton（equipcraft.lua:1354）：heroDetail 下合成窗打开期间 infoButton 禁点
# （灰字），合成出目标装备且等级够/关闭合成窗时解禁；handbook 恒 false（:1344-1346）。
var _is_forbid_info_button: bool = false
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
			# 源 doClickCraftButton（equipcraft.lua:211-218）：返回关合成窗回详情态（非关整弹窗），
			# 并刷新 infoButton 文字（heroDetail 且拥有>0 → 装备；否则 → 获取途径）。
			# 旧实现误用 remove_window() → 点返回直接关掉整个弹窗（用户 2026-09-07 报按钮逻辑缺失）。
			AudioPlayer.play_sfx("common_click_feedback")
			_close_craft_panel()
			var close_text: String = EquipCraftInfoBtn.LSTR_EQUIPMENT \
					if _get_amount(_target_id) > 0 and _context == "heroDetail" \
					else EquipCraftInfoBtn.LSTR_WAY_TO_GET
			_info_button_label.text = cm.get_lstr(close_text)
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
	# 源 refreshReplyData（equipcraft.lua:505-511）：合成出的就是弹窗目标装备（up.id==id）且
	# 英雄等级够 → 解禁 infoButton（灰字变白可点，玩家点它穿上刚合成的装备）。
	if _craft_id == _target_id and _context == "heroDetail":
		var judge: Array = _get_judge_level()
		if int(judge[1]) <= int(judge[0]):
			EquipCraftInfoBtn.set_forbid_info_button(self, false)


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


# 源 doClickGetWay :77-89 只 pushScene(stageselect) 压栈不清场（equipcraft 场景保留在栈底，
# 扫荡完逐层 popScene 回本面板看材料）。本项目等价：emit jump_to_stage（场景入口开
# StageSelectPanel 全屏盖住），本面板留在 PopWindow 栈底不自我关闭——2026-09-14 根修，
# 旧实现 remove_window 清场致扫荡返回无处可回落到列表（用户实机反馈）。
# 2026-09-14 二轮（用户拍板受控增强）：源 popScene 回旧场景不重渲染（扫荡回来显示旧数字），
# 本项目优于源——选关面板关闭时刷新拥有量+合成树（扫荡拿到卷轴/装备回来即见）。
func _on_get_way_clicked(stage_id: int) -> void:
	var st: String = StageAccount.stage_type(stage_id)
	if st != "normal" and st != "elite":
		return
	var star: int = _stage_stars(stage_id)
	var prev: int = _stage_stars(stage_id - 1)
	if star + prev > 0:
		AudioPlayer.play_sfx("common_click_feedback")
		jump_to_stage.emit(stage_id)
		_bind_stage_select_refresh()
	else:
		_show_toast(cm.get_lstr(LSTR_CHAPTER_YET_TO_OPEN))


# emit 同步链终点（场景入口 open_stage_select_by_stage → show_window）完成后，栈顶即
# 本次跳转打开的选关面板——从 PopWindow 栈向下找最近的 StageSelectPanel（各次跳转对应
# 新实例，旧面板已销毁其 on_exit 随之而亡，不积累）。register_on_exit 在 remove_window
# 内同步调用（早于 queue_free 帧末出树），无信号生命周期问题。
func _bind_stage_select_refresh() -> void:
	var select_panel: PopWindow = null
	for i in range(PopWindow._open_stack.size() - 1, -1, -1):
		var p: CanvasItem = PopWindow._open_stack[i]
		if p is StageSelectPanel:
			select_panel = p as PopWindow
			break
	if select_panel != null:
		select_panel.register_on_exit(_refresh_after_stage_select)


# 选关关闭（用户扫荡完点返回）→ 刷新详情层拥有量；合成窗打开态则重建树（skip_anim 跳
# 开场动画，材料数/lack 态/金币判定随重建更新）。两 fill 均幂等可重入（清空重填/重建）。
# 双保险：register_on_exit 钩子（二轮）+ _on_became_top 栈顶驱动（四轮，2026-09-14——
# 单点钩子在真实点击路径存在未定位断点，栈顶变化由 _refresh_stack_z 统一驱动覆盖任意
# 关闭方式；两路幂等无害）。
func _refresh_after_stage_select() -> void:
	_refresh_amount()
	if _tree != null and is_instance_valid(_tree):
		_create_craft_tree(_craft_id, true)


# PopWindow._on_became_top（栈顶变化钩子）：选关/关卡详情等子面板任意方式关闭后
# equipcraft 复顶即刷新（覆盖 CloseBtn/shade/级联等全部路径）。
func _on_became_top() -> void:
	_refresh_after_stage_select()


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
	# 源 openCraftPanel（equipcraft.lua:577-584）：heroDetail → infoButton 文字设「装备」+ 灰字禁点
	# （合成窗开着时 infoButton 不可再点，防误触穿/关）；handbook → 文字设「确定」（正常可点，
	# 再点关整个弹窗，forbidInfoButton 内 handbook 恒不禁用 :1344-1346）。
	if _context == "heroDetail":
		_info_button_label.text = cm.get_lstr(EquipCraftInfoBtn.LSTR_EQUIPMENT)
		EquipCraftInfoBtn.set_forbid_info_button(self, true)
	else:
		_info_button_label.text = cm.get_lstr(EquipCraftInfoBtn.LSTR_CONFIRM)
	# 源 openCraftPanel（equipcraft.lua:575-587 / :1246-1268）：点 infoButton 后才建合成窗口 + 合成树。
	# :1259-1266 equipLayer frame 弹性滑 (400,240)→(252,240) 左移让位 + craftWindow 滑 (548,240)
	# + 动画后 setZOrder(2)。滑入动画按用户 2026-08-30 指示退役（受控偏离：直显终点），让位同口径
	# 直设；z 序由 tscn 树序保证（CraftWindow 在 EquipLayer 后）。旧实现漏译让位 → 详情面板原地
	# 压合成窗（用户 2026-09-07 报「原弹窗没消失」）。
	_craft_window.visible = true
	_set_equip_layer_side(true)
	_create_craft_tree(_target_id, false)
	# 源 createCraftWindow 末尾（equipcraft.lua:1253）setHistory(0, id)：打开即记录历史首项
	# → 历史栏顶部显示当前装备小图标 + equip_craft_select 选中框（含下指 V 尖）。
	# 旧实现漏调 → 顶部历史栏区恒空（用户 2026-09-07 报「顶部空白，原版其实有装备图标」）。
	_set_history(0, _target_id)


func _close_craft_panel() -> void:
	# 源 closeCraftPanel（equipcraft.lua:588-608）：initHistory 清历史 + isOpen=false +
	# heroDetail 解禁 infoButton + 详情 frame 弹回中心（让位复位，直设同 open 口径）。
	_is_open = false
	_craft_window.visible = false
	_set_equip_layer_side(false)
	_init_history()
	EquipCraftInfoBtn.set_forbid_info_button(self, false)


# 详情面板让位两态（源 :1259-1261 frame (400,240)↔(252,240)；InfoButton/InfoRemark 源挂
# frame 上随面板走，本项目为 content 独立节点 → 同步平移，位移量 = 252-400 = -148）。
# EquipLayer/InfoButton/InfoRemark 基准值与 equip_craft_content.tscn 静态 offset 一致。
const EQUIP_LAYER_CENTER_POS: Vector2 = Vector2(256.0, 48.0)
const EQUIP_LAYER_SIDE_POS: Vector2 = Vector2(108.0, 48.0)
const INFO_BUTTON_CENTER_POS: Vector2 = Vector2(272.27, 366.85)
const INFO_BUTTON_SIDE_POS: Vector2 = Vector2(124.27, 366.85)
const INFO_REMARK_CENTER_POS: Vector2 = Vector2(281.0, 343.0)
const INFO_REMARK_SIDE_POS: Vector2 = Vector2(133.0, 343.0)


func _set_equip_layer_side(side: bool) -> void:
	_equip_layer.position = EQUIP_LAYER_SIDE_POS if side else EQUIP_LAYER_CENTER_POS
	_info_button.position = INFO_BUTTON_SIDE_POS if side else INFO_BUTTON_CENTER_POS
	_info_remark.position = INFO_REMARK_SIDE_POS if side else INFO_REMARK_CENTER_POS


# ===== Step 4：history 历史记录栏 =====

func _init_history() -> void:
	# 源 initHistory（equipcraft.lua:726-729）置 nil；本项目历史图标挂 %HistoryClip 下 HBox
	# （随 craft_window 隐藏但仍占位）→ 须同步清子节点，否则关闭再打开时 setHistory(0,id)
	# 在旧图标后重复 append（历史栏叠加）。
	if _history_layer != null and is_instance_valid(_history_layer):
		for c in _history_layer.get_children():
			c.free()
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
		var node: Dictionary = EquipCraftFills.append_history_node(self, container_layer, id)
		var icon_bg: Control = node["iconBg"]
		icon_bg.gui_input.connect(_make_history_handler(len_ + 1))
		_history.append({"id": id, "iconBg": icon_bg, "arrow": node["arrow"]})
	elif index <= len_:
		_history_id = index
		# 源 setHistory :875-880 截断时 iconBg 与 arrow 一并删（arrow 随所属条目存引用 :858-863）。
		# 旧实现漏删 arrow → 点返回回退后 view_history_arrow 残留 HBox，反复进出无限叠加
		#（用户 2026-09-07 报「箭头不会消失，会一直叠加」）。
		for i in range(index, len_):
			if i < _history.size():
				var entry: Dictionary = _history[i]
				if is_instance_valid(entry.get("iconBg", null)):
					(entry["iconBg"] as Control).queue_free()
				var arrow: TextureRect = entry.get("arrow", null)
				if arrow != null and is_instance_valid(arrow):
					arrow.queue_free()
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
