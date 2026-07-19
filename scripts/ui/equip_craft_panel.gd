class_name EquipCraftPanel
extends PopWindow

## 装备合成面板（View 层）— 照源 ui/equipcraft.lua（1366 行）。
## Step 1+2+3：骨架 + 主面板 + 合成窗口 + createCraftTree 合成树 + craftEquip 合成执行闭环。
## Step 4（playCraftEffect 特效 + history 历史记录）/ Step 5（入口集成 + 音效）。
## 单机化：从 HeroDetailPanel 装备槽进（hero/target_id/sid 已定），跳过源 equipboard 完整面板
## （equipLayer 用本地 ofcraft 装备展示照源翻译）。Logic 走 EquipCraftManager.synthesize_equip。
## 坐标：全屏元素（_craft_window/_equip_layer/infoButton）走 _g(BattleViewCoords.to_godot)；
## craftWindow(bg)内局部元素（tree/history，源 add craftWindow.mainLayer）走 EquipCraftTree._gl
## （源 bg 369×493 CCSprite 子节点原点=左下角 y-up，_craft_window 代表 bg 中心，故 _gl 翻 Y + 减半宽高）。
## 拆分：EquipCraftTree 控合成树构建；EquipCraftInfoBtn 控 infoButton/puton/playPutonEffect 闭环。

signal equipped_changed   # 穿戴后通知调用方刷新（HeroDetailPanel 接 → refresh_content 装备槽）
signal jump_to_stage(stage_id: int)   # P1-10：获取途径跳转（源 doClickGetWay → stageselect.createByStage）

# panel 层静态化进 equip_craft_content.tscn（CloseBtn + EquipLayer + CraftWindow.Bg + TreeHost
# + InfoButton/InfoButtonLabel + InfoRemark）。位置/size 可视化，运行时 fill 动态数据/连接信号。
# 合成树（EquipCraftTree）+ 历史栏 procedural 挂 %TreeHost（_craft_window 子层，坐标系不变）。
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/equip_craft_content.tscn")


# ── 坐标常量（源 cocos 值）──────────────────────────────────────────
# 源 hello.lua:311 setContentScaleFactor(615/480)=1.28125：cocos sprite contentSize=纹理/CS，position 不变。
# 纯 Sprite（CCSprite / ed.createSprite 无 fix_size）→ Godot 需 EXPAND_IGNORE_SIZE + size=tex/CS 等价。
const CONTENT_SCALE: float = 1.28125
const CRAFT_WINDOW_POS: Vector2 = Vector2(548.0, 240.0)   # 源 createCraftWindow :1258 进场后
const EQUIP_LAYER_POS: Vector2 = Vector2(252.0, 240.0)    # 源 equipLayer.ui.frame :1256 进场后
const CLOSE_BTN_POS: Vector2 = Vector2(20.0, 15.0)  # 左上角留小边（用户偏好更靠左上角）
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/backbtn.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/backbtn-disabled.png"
const ROOT_ICON_SCALE: float = 60.0 / 72.0                # 源 createIcon(id, 60)（equipLayer 装备图标）
const CRAFT_BG_PATH: String = "res://assets/ui/alpha/HVGA/equip_craft_bg.png"
# ── 颜色（源 ccc3，合成树/infoBtn 颜色已迁 EquipCraftTree/EquipCraftInfoBtn）──
const COLOR_BROWN: Color = Color(50.0 / 255.0, 41.0 / 255.0, 31.0 / 255.0)      # 源 50,41,31（prompt 提示文字）
# ── LSTR key（源 LSTR 宏，cm.get_lstr 取实际值；infoBtn LSTR 已迁 EquipCraftInfoBtn）──
const LSTR_SYNTHESIS_SUCCESS: String = "EQUIPCRAFT.SYNTHESIS_SUCCESS"
const LSTR_SYNTHESIS_FAILURE: String = "EQUIPCRAFT.SYNTHESIS_FAILURE"
const LSTR_NO_MATERIAL: String = "EQUIPCRAFT.NO_SUITABLE_MATERIAL_GO_TO_COLLECT_SOME"
const LSTR_NEED_CRAFT_FIRST: String = "EQUIPCRAFT.THIS_PIECE_OF_EQUIPMENT_NEED_TO_BE_SYNTHESIZED_FIRST"
const LSTR_CHAPTER_YET_TO_OPEN: String = "EQUIPCRAFT.CHAPTER_YET_TO_OPEN"
# ── Step 4 常量（history + playCraftEffect）──
const HISTORY_ORIGIN: Vector2 = Vector2(55.0, 350.0)     # 源 :843 ori
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
var _content: Control = null            # .tscn 根（EquipCraftContent），info_btn/remark 取节点用
var _equip_layer: Control = null        # .tscn %EquipLayer（源 equipLayer.ui.frame）
var _craft_window: Control = null       # .tscn %CraftWindow（源 craftWindow.mainLayer = bg 中心）
var _tree_host: Control = null          # .tscn %TreeHost（_craft_window 子，挂动态 tree/history）
var _tree: Control = null               # 源 tree.layer（合成树层，挂 _tree_host）
var _tree_data: Dictionary = {}         # 源 self.tree（节点引用：name/rootBg/children/amountLabel/costBg/cost/craftLabel）
var _craft_window_data: Dictionary = {} # 源 self.craftWindow（nodeid/nodeNeed/nodeAmount/nodeRepeat/expense）
var _components: int = 0                # 源 self.components
var _craft_id: int = 0                  # 源 self.craftid（当前合成树显示的目标）
var _lack_of_component: bool = false    # 源 self.lackOfComponent
var _is_crafting: bool = false          # 源 self.isCrafting
var _craft_btn: BaseButton = null       # 源 tree.craftButton（TextureButton， EquipCraftTree 建；BaseButton 容纳 Texture/Button）
var _craft_btn_label: Label = null      # 源 tree.craftLabel（独立 Label，EquipCraftTree 建）
var _get_way_buttons: Array = []        # 源 self.getWayButton
var _get_way_ids: Array = []            # 源 self.getWayID
# Step 4（playCraftEffect + history）
var _history: Array = []                 # 源 self.history（历史条目 [{id,iconBg}]）
var _history_id: int = 0                 # 源 self.historyid
var _history_layer: Control = null       # 源 draglist.listLayer（HBoxContainer 降级，本项目不滚动）
var _info_button: BaseButton = null     # 源 infoButton（TextureButton，EquipCraftInfoBtn 建；BaseButton 容纳 Texture/Button）
var _info_button_label: Label = null     # 源 infoButtonLabel（独立 Label，EquipCraftInfoBtn 建）
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
	_build_content()
	_refresh_amount()
	_create_craft_tree(_target_id, false)
	_init_history()
	_create_info_button()   # 源 :1283 enter 回调
	register_on_enter(func() -> void: AudioPlayer.play_sfx("common_popup_window"))   # 源 equipcraftlsr openWindow :15


# 建 UI 内容：base 层从 equip_craft_content.tscn instantiate（位置/size 可视化）+ 连接信号。
# 合成树（EquipCraftTree）保留 procedural 挂 %TreeHost（坐标系不变）。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	_content = content
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(_on_close_pressed)
	_equip_layer = _content.get_node("%EquipLayer") as Control
	_craft_window = _content.get_node("%CraftWindow") as Control
	_tree_host = _content.get_node("%TreeHost") as Control
	_info_button = _content.get_node("%InfoButton") as BaseButton
	_info_button_label = _content.get_node("%InfoButtonLabel") as Label
	_info_remark = _content.get_node("%InfoRemark") as Label
	(_info_button as BaseButton).pressed.connect(func() -> void: EquipCraftInfoBtn._on_info_pressed(self))


func _on_close_pressed() -> void:
	AudioPlayer.play_sfx("common_close_popup_window")   # 源 equipcraftlsr closeWindow :19
	remove_window()


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
# bg 已在 .tscn（%CraftWindow.%Bg，位置/size 静态化），本函数保留 stub 兼容旧调用（仅委托 _create_craft_tree）。
func _create_craft_window(id: int) -> void:
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
		_show_toast(cm.get_lstr(LSTR_SYNTHESIS_FAILURE))   # 源 showHandyDialog useMidas 单机化降级
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
		_show_toast(cm.get_lstr(LSTR_SYNTHESIS_FAILURE))
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


# ===== Step 4：playCraftEffect 合成动画 + createNeedCraftPrompt =====
# 已拆 EquipCraftInfoBtn.play_craft_effect / create_need_craft_prompt（控 ≤400）。

# ===== 转发 EquipCraftInfoBtn（保留 panel._xxx 接口供测试，照源边界）=====

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
		_show_toast(cm.get_lstr(LSTR_CHAPTER_YET_TO_OPEN))   # 源 :86 CHAPTER_YET_TO_OPEN


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


# ===== Step 4：history 历史记录栏 =====

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
	_tree_host.add_child(_history_layer)
	return _history_layer


# 源 setHistory :838：index==0 追加历史条目（iconBg+arrow）/ index<=len 切回历史（清尾部+重建 tree）。
func _set_history(index: int, id: int) -> void:
	var container_layer: Control = _create_history_layer()
	var len_: int = _history.size()
	if index == 0 or index > len_:
		_history_id = len_ + 1
		var icon_bg: Control = ReadequipIcon.create_icon(id, 0, cm)
		icon_bg.scale = Vector2(HISTORY_ICON_SCALE, HISTORY_ICON_SCALE)
		if len_ > 0:
			# 源 equipcraft.lua:855 ed.createSprite("view_history_arrow.png") 无 fix_size（纯 Sprite 显示=纹理/CS）。
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
