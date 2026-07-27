class_name EquipCraftPanel
extends PopWindow

## Step 1+2+3：骨架 + 主面板 + 合成窗口 + createCraftTree 合成树 + craftEquip 合成执行闭环。
## Step 4（playCraftEffect 特效 + history 历史记录）/ Step 5（入口集成 + 音效）。
## 坐标：全屏元素（_craft_window/_equip_layer/infoButton）走 _g(BattleViewCoords.to_godot)；
## 拆分：EquipCraftTree 控合成树构建；EquipCraftInfoBtn 控 infoButton/puton/playPutonEffect 闭环。

signal equipped_changed   # 穿戴后通知调用方刷新（HeroDetailPanel 接 → refresh_content 装备槽）
signal jump_to_stage(stage_id: int)   # P1-10：获取途径跳转

# panel 层静态化进 equip_craft_content.tscn（CloseBtn + EquipLayer + CraftWindow.Bg + TreeHost
# + InfoButton/InfoButtonLabel + InfoRemark）。位置/size 可视化，运行时 fill 动态数据/连接信号。
# 合成树（EquipCraftTree）+ 历史栏 procedural 挂 %TreeHost（_craft_window 子层，坐标系不变）。
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/equip_craft_content.tscn")


# 纯 Sprite（CCSprite / ed.createSprite 无 fix_size）→ Godot 需 EXPAND_IGNORE_SIZE + size=tex/CS 等价。
const CONTENT_SCALE: float = 1.28125
const CRAFT_WINDOW_POS: Vector2 = Vector2(548.0, 240.0)
const EQUIP_LAYER_POS: Vector2 = Vector2(252.0, 240.0)
const CLOSE_BTN_POS: Vector2 = Vector2(20.0, 15.0)  # 左上角留小边（用户偏好更靠左上角）
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/backbtn.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/backbtn-disabled.png"
const ROOT_ICON_SCALE: float = 60.0 / 72.0
const CRAFT_BG_PATH: String = "res://assets/ui/alpha/HVGA/equip_craft_bg.png"
const COLOR_BROWN: Color = Color(50.0 / 255.0, 41.0 / 255.0, 31.0 / 255.0)
# 装备详情面板 fill 常量（照 equipboard_panel 范式 A，源 equipboard board.lua 校准）
const ICON_POS: Vector2 = Vector2(14.0, 21.0)
const ATT_TOP: float = 98.0
const LSTR_HAVE: String = "EQUIPINFO.HAVE"
const LSTR_ITEM: String = "EQUIPINFO.ITEM"
const ATT_LABEL_COLOR: Color = Color(0.251, 0.247, 0.247, 1)
# ── LSTR key──
const LSTR_SYNTHESIS_SUCCESS: String = "EQUIPCRAFT.SYNTHESIS_SUCCESS"
const LSTR_SYNTHESIS_FAILURE: String = "EQUIPCRAFT.SYNTHESIS_FAILURE"
const LSTR_NO_MATERIAL: String = "EQUIPCRAFT.NO_SUITABLE_MATERIAL_GO_TO_COLLECT_SOME"
const LSTR_NEED_CRAFT_FIRST: String = "EQUIPCRAFT.THIS_PIECE_OF_EQUIPMENT_NEED_TO_BE_SYNTHESIZED_FIRST"
const LSTR_CHAPTER_YET_TO_OPEN: String = "EQUIPCRAFT.CHAPTER_YET_TO_OPEN"
# ── Step 4 常量（history + playCraftEffect）──
const HISTORY_ORIGIN: Vector2 = Vector2(55.0, 350.0)
const HISTORY_ICON_SCALE: float = 40.0 / 72.0
const HISTORY_ARROW_PATH: String = "res://assets/ui/alpha/HVGA/view_history_arrow.png"
const PROMPT_BG_PATH: String = "res://assets/ui/alpha/HVGA/craft_promt_bg.png"


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


# 用于全屏元素（_craft_window/_equip_layer/infoButton，add container）。
func _g(pos: Vector2) -> Vector2:
	return BattleViewCoords.to_godot(pos.x, pos.y)


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
	_build_content()
	_refresh_amount()
	_init_history()
	_create_info_button()
	# 源 openCraftPanel（equipcraft.lua:575-587）才建合成树/合成窗口；初始弹窗只显装备+infoButton，
	# 点 infoButton → _open_craft_panel 才 visible=true + _create_craft_tree。受控偏离源架构。
	_craft_window.visible = false
	register_on_enter(func() -> void: AudioPlayer.play_sfx("common_popup_window"))


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


func _refresh_amount() -> void:
	if _equip_layer == null:
		return
	# 图标挂 %IconHost（照 equipboard_panel _fill_icon 范式，ICON_POS 相对 EquipLayer 左上角）
	for c in _icon_host.get_children():
		c.free()
	if _target_id > 0:
		var icon: Control = ReadequipIcon.create_icon(_target_id, _get_amount(_target_id), cm)
		icon.scale = Vector2(ROOT_ICON_SCALE, ROOT_ICON_SCALE)
		icon.position = ICON_POS
		_icon_host.add_child(icon)
	# 装备名（照 equipboard_panel:165，_equip_name 取 Equip.Name 的 LSTR）
	_name_label.text = _equip_name(_target_id)
	# 拥有数量（照 equipboard_panel:166-167，"拥有 X 个" 格式）
	var amt: int = _get_amount(_target_id)
	_amount_label.text = "%s %d %s" % [String(cm.get_lstr(LSTR_HAVE)), amt, String(cm.get_lstr(LSTR_ITEM))]
	# 属性介绍（照 equipboard_panel _fill_att，ReadequipData.get_description 多行 VBox）
	for c in _att_host.get_children():
		c.free()
	var rows: Array = ReadequipData.get_description(_target_id, 0, cm)
	for row in rows:
		var r: Dictionary = row as Dictionary
		var lbl := Label.new()
		lbl.text = String(r.get("att", "")) + String(r.get("add", ""))
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", ATT_LABEL_COLOR)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_att_host.add_child(lbl)


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


func _show_toast(text: String) -> void:
	if Engine.is_editor_hint():
		return
	var toast_node: Node = Engine.get_main_loop().root.get_node_or_null("/root/Toast")
	if toast_node != null and toast_node.has_method("show_message"):
		toast_node.show_message(text)


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
	# 源 openCraftPanel（equipcraft.lua:575-587）：点 infoButton 后才建合成窗口 + 合成树。
	_craft_window.visible = true
	_create_craft_tree(_target_id, false)


func _close_craft_panel() -> void:
	_is_open = false
	_craft_window.visible = false


# ===== Step 4：history 历史记录栏 =====

func _init_history() -> void:
	_history = []
	_history_id = 0


func _create_history_layer() -> Control:
	if _history_layer != null and is_instance_valid(_history_layer):
		return _history_layer
	_history_layer = HBoxContainer.new()
	_history_layer.position = EquipCraftTree._gl(HISTORY_ORIGIN)
	_history_layer.add_theme_constant_override("separation", 8)
	_tree_host.add_child(_history_layer)
	return _history_layer


func _set_history(index: int, id: int) -> void:
	var container_layer: Control = _create_history_layer()
	var len_: int = _history.size()
	if index == 0 or index > len_:
		_history_id = len_ + 1
		var icon_bg: Control = ReadequipIcon.create_icon(id, 0, cm)
		icon_bg.scale = Vector2(HISTORY_ICON_SCALE, HISTORY_ICON_SCALE)
		if len_ > 0:
			# HBoxContainer 管子节点 layout，须用 custom_minimum_size（非 size）分配空间 + EXPAND_IGNORE_SIZE 让纹理 stretch 入框。
			var arrow := TextureRect.new()
			arrow.texture = load(HISTORY_ARROW_PATH)
			arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			arrow.custom_minimum_size = TexDisplaySize.display_size(HISTORY_ARROW_PATH)
			arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container_layer.add_child(arrow)
		container_layer.add_child(icon_bg)
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
