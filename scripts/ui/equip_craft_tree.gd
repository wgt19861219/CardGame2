class_name EquipCraftTree
extends RefCounted

## 装备合成树构建（View helper）— 从 EquipCraftPanel 拆出控 ≤400。
## static 方法第一参 panel，照 equip_strengthen_anim.gd 静态拆分范式。
## 主类 _create_craft_tree 转发本类（被 _create_craft_window/_play_craft_effect/_set_history 调用）。

const CONTENT_SCALE: float = 1.28125
# ── 合成树坐标常量（源 cocos 值）──────────────────────────────────────
const NAME_LABEL_POS: Vector2 = Vector2(142.0, 292.0)
const ROOT_ICON_POS: Vector2 = Vector2(141.0, 230.0)
const ROOT_ICON_NO_RECIPE_POS: Vector2 = Vector2(50.0, 250.0)
const COST_TITLE_POS: Vector2 = Vector2(100.0, 85.0)
const COST_POS: Vector2 = Vector2(200.0, 85.0)
const TRUNK_POS: Vector2 = Vector2(142.0, 190.0)
const AMOUNT_LABEL_Y: float = 115.0
const AMOUNT_NEED_OFFSET: float = 9.0
const CRAFT_BTN_POS: Vector2 = Vector2(143.0, 45.0)
# 4 种材料子节点布局（源 childrenPos :953-972，components 1-4）
const CHILDREN_POS: Array = [
	[Vector2(142.0, 150.0)],
	[Vector2(113.0, 150.0), Vector2(171.0, 150.0)],
	[Vector2(83.0, 150.0), Vector2(141.0, 150.0), Vector2(199.0, 150.0)],
	[Vector2(55.0, 150.0), Vector2(113.0, 150.0), Vector2(171.0, 150.0), Vector2(229.0, 150.0)],
]
# 连线精灵（源 lineres :974-988，index = components-1）
const LINE_RES: Array = [
	"res://assets/ui/alpha/HVGA/fragment_compose_arrow.png",
	"res://assets/ui/alpha/HVGA/equip_craft_2.png",
	"res://assets/ui/alpha/HVGA/equip_craft_3.png",
	"res://assets/ui/alpha/HVGA/equip_craft_4.png",
]
const LINE_ROT: Array = [-90.0, 0.0, 0.0, 0.0]
# 获取途径分支（源 :1133-1202，components<1）
const GETWAY_LABEL_POS: Vector2 = Vector2(80.0, 250.0)
const GETWAY_BOARD_Y_BASE: float = 200.0
const GETWAY_BOARD_DY: float = 50.0
const GETWAY_BG_PATH: String = "res://assets/ui/alpha/HVGA/equip_craft_getway_bg.png"
const GETWAY_BOARD_PATH: String = "res://assets/ui/alpha/HVGA/equip_craft_getway_board.png"
const GETWAY_BG_POS: Vector2 = Vector2(142.0, 177.0)
const STAGE_ICON_SIZE: float = 40.0
const BOARD_TITLE_POS: Vector2 = Vector2(50.0, 3.0)
const BOARD_NAME_POS: Vector2 = Vector2(50.0, 25.0)
const BOARD_NAME_MAX_W: float = 160.0
const BOARD_ICON_POS: Vector2 = Vector2(5.0, 5.0)
# 按钮纹理（源 :1008/:1018 package_button 双层 Sprite + Label）
const CRAFT_BTN_RES: String = "res://assets/ui/alpha/HVGA/package_button.png"
const CRAFT_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/package_button_down.png"
# 图标缩放（源 createIcon(id, size) length 语义：源产物逻辑宽 94/CS=73.37 × scale = size）。
# 9bc640e 起 create_icon 内部 _load_sprite 统一 ÷CS（产物显示 73.37），分母用 94/CS
# （旧 /72 系 container 口径，统一后 root/child 实显 61.2/45.9 偏大 2%，2026-08-22 顺修）。
const ROOT_ICON_SCALE: float = 60.0 / (94.0 / CONTENT_SCALE)
const CHILD_ICON_SCALE: float = 45.0 / (94.0 / CONTENT_SCALE)
const ROOT_ICON_NO_RECIPE_SCALE: float = 0.6
# ── 颜色（源 ccc3；静态色走 default_theme variation，动态切换色 fill modulate）──
const COLOR_RED: Color = Color(1.0, 0.0, 0.0)
const COLOR_DARK_RED: Color = Color(155.0 / 255.0, 34.0 / 255.0, 14.0 / 255.0)
const COLOR_BROWN: Color = Color(50.0 / 255.0, 41.0 / 255.0, 31.0 / 255.0)   # amount 动态二态足态色（源 :1091）
const COLOR_WHITE: Color = Color(1.0, 1.0, 1.0)
# ── LSTR key（源 LSTR 宏，panel.cm.get_lstr 取实际值）──
const LSTR_RETURN: String = "EQUIPCRAFT.RETURN"
const LSTR_SYNTHESIS: String = "EQUIPCRAFT.SYNTHESIS"
const LSTR_SYNTHESIS_COST: String = "EQUIPCRAFT.SYNTHESIS_COST_"
const LSTR_WAY_TO_GET: String = "EQUIPCRAFT.WAY_TO_GET_"
const LSTR_EQUIPPED: String = "EQUIPCRAFT.EQUIPPED"
const LSTR_ELITE: String = "EQUIPCRAFT.ELITE"
const LSTR_CHAPTER_D: String = "EQUIPCRAFT._CHAPTER__D"
# ── craftWindow(bg)局部坐标翻转 ──────────────────────────────────────
# panel._craft_window 代表 bg 中心（position=_g(CRAFT_WINDOW_POS)，bg.position=-size/2 对齐中心），
# 故 bg 局部(cx,cy) → Godot 相对中心 = (cx - BG_HALF_W, BG_HALF_H - cy)。照源 equipcraft.lua:949-952。
# bg 局部坐标系 = 显示点空间（equip_craft_bg 纹理 369×493px ÷CS = 288.0×384.8 点，源 cliprect
# 12,300→380 贴 384.8 底缘可证），半尺寸 = 144.0/192.4。旧值 184.5/246.5 为纹理 px 半尺寸直用，
# 树内容整体偏移 (+40.5, 54.1) 出 bg 框（2026-08-22 溢出修复清查修正）。
const BG_HALF_W: float = 369.0 / 2.0 / CONTENT_SCALE
const BG_HALF_H: float = 493.0 / 2.0 / CONTENT_SCALE
# 金币 cost 区装饰（源 equipcraft.lua:1110-1123）：equip_craft_money_bg 框 + 标题 + 数额
# （三元素均中心锚，源无金币 icon）。COST_BG_POS 源 (142,86)。
const COST_BG_RES: String = "res://assets/ui/alpha/HVGA/equip_craft_money_bg.png"
const COST_BG_POS: Vector2 = Vector2(142.0, 86.0)


static func _gl(pos: Vector2) -> Vector2:
	return Vector2(pos.x - BG_HALF_W, BG_HALF_H - pos.y)


# 源 tree 内 createIcon 产物系 bg sprite（anchor 0.5,0.5，position=中心）；本项目 ReadequipIcon
# 容器从左上渲染 frame → 挂点须补偿半显示尺寸才与源中心语义对齐（2026-09-07 修：旧实现左上
# 直挂致 getway 小图标偏 (22,22)、合成树 root/child 同病）。frame 显示 = 94/CS × 95/CS。
const FRAME_DISP: Vector2 = Vector2(94.0 / CONTENT_SCALE, 95.0 / CONTENT_SCALE)


static func _icon_pos(pos: Vector2, icon_scale: float) -> Vector2:
	return _gl(pos) - FRAME_DISP * icon_scale * 0.5


static func create_craft_tree(panel, id: int, skip_anim: bool) -> void:
	if panel._tree != null and is_instance_valid(panel._tree):
		panel._tree.queue_free()
	panel._tree_data.clear()
	panel._get_way_buttons.clear()
	panel._get_way_ids.clear()
	panel._craft_window_data.clear()
	var row: Dictionary = EquipcraftData.get_recipe(id, panel.cm)
	var components: int = int(row.get("Components", 0))
	components = components if components > 0 else 0
	panel._craft_id = id
	panel._components = components
	var tree := Control.new()
	panel._tree = tree
	panel._tree_host.add_child(tree)
	var name_lbl := Label.new()
	name_lbl.text = panel._equip_name(id)
	name_lbl.theme_type_variation = &"EquipCraftRedLabel18"
	tree.add_child(name_lbl)
	# 源 name 系 readnode Label（anchor 0.5,0.5 中心锚）@ccp(142,292) → 居中补偿（2026-09-07
	# 修：旧左上直挂致标题右偏 33px）；挂树后测量（content 已随 show_window 在树上，theme 可解析）。
	name_lbl.position = _gl(NAME_LABEL_POS) - name_lbl.get_combined_minimum_size() * 0.5
	panel._tree_data["name"] = name_lbl
	var root_icon: Control = ReadequipIcon.create_icon(id, 0, panel.cm)
	root_icon.scale = Vector2(ROOT_ICON_SCALE, ROOT_ICON_SCALE)
	tree.add_child(root_icon)
	panel._tree_data["rootBg"] = root_icon
	var expense: int = 99999999
	if components > 0:
		root_icon.position = _icon_pos(ROOT_ICON_POS, ROOT_ICON_SCALE)
		_build_recipe_branch(panel, tree, row, components)
		expense = int(row.get("Expense", 99999999))
		panel._craft_window_data["expense"] = expense
		_build_cost(panel, tree, expense)
		panel._lack_of_component = false
		_judge_lack_of_component(panel)
	else:
		_build_getway_branch(panel, tree, id)
	_build_craft_button(panel, tree, components)


static func _build_recipe_branch(panel, tree: Control, row: Dictionary, components: int) -> void:
	var trunk := TextureRect.new()
	trunk.texture = load(LINE_RES[components - 1])
	trunk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# trunk 源 Sprite 无 fix_size → 显示=纹理/CS（[[content-scale-factor]]）
	var trunk_size: Vector2 = TexDisplaySize.display_size(LINE_RES[components - 1])
	trunk.size = trunk_size
	trunk.position = _gl(TRUNK_POS) - trunk_size / 2.0
	trunk.rotation_degrees = LINE_ROT[components - 1]
	tree.add_child(trunk)
	panel._craft_window_data["nodeid"] = []
	panel._craft_window_data["nodeRepeat"] = []
	panel._craft_window_data["nodeAmount"] = []
	panel._craft_window_data["nodeNeed"] = []
	var nodeid: Array = panel._craft_window_data["nodeid"]
	var node_need: Array = panel._craft_window_data["nodeNeed"]
	var node_amount: Array = panel._craft_window_data["nodeAmount"]
	var node_repeat: Array = panel._craft_window_data["nodeRepeat"]
	var children_pos: Array = CHILDREN_POS[components - 1]
	var children_icons: Array = []
	var amount_labels: Array = []
	for i in range(components):
		var cid: int = int(row.get("Component" + str(i + 1), 0))
		var need: int = max(int(row.get("Component" + str(i + 1) + " Count", 1)), 1)
		node_need.append(need)
		nodeid.append(cid)
		if i == 0:
			node_repeat.append(0)
		else:
			var rep: int = 0
			for j in range(i):
				if nodeid[j] == cid:
					rep += need
				else:
					rep = 0
			node_repeat.append(rep)
		var raw_amount: int = panel._get_amount(cid) - int(node_repeat[i])
		node_amount.append(raw_amount if raw_amount > 0 else 0)
		var child_icon: Control = ReadequipIcon.create_icon(cid, 0, panel.cm)
		child_icon.scale = Vector2(CHILD_ICON_SCALE, CHILD_ICON_SCALE)
		child_icon.position = _icon_pos(children_pos[i], CHILD_ICON_SCALE)
		child_icon.mouse_filter = Control.MOUSE_FILTER_STOP
		child_icon.gui_input.connect(panel._make_tree_node_handler(i))
		tree.add_child(child_icon)
		children_icons.append(child_icon)
		var amount: int = int(node_amount[i])
		if amount < 10000:
			var lbl := Label.new()
			lbl.text = str(amount)
			lbl.theme_type_variation = &"EquipCraftDynLabel18"
			tree.add_child(lbl)
			# 源 :1086-1088 createttf（CCLabelTTF 中心锚）amount 中心 = (childX - w/2, 115)
			# → 视觉"amount 右缘接 need 左缘"连排（2026-09-07 修：旧左上直挂 -20 hack 致
			# 数字行下移 18 且 amount/need 各向两边散开 15px）。
			var amt_center_x: float = children_pos[i].x - lbl.get_combined_minimum_size().x * 0.5
			lbl.position = _gl(Vector2(amt_center_x, AMOUNT_LABEL_Y)) - lbl.get_combined_minimum_size() * 0.5
			lbl.modulate = COLOR_RED if amount < int(node_need[i]) else COLOR_BROWN
			amount_labels.append(lbl)
			var need_lbl := Label.new()
			need_lbl.text = "/" + str(int(node_need[i]))
			need_lbl.theme_type_variation = &"EquipCraftBrownLabel18"
			tree.add_child(need_lbl)
			# 源 :1099-1101 need @ (childX+9) 直译给 9px 间隙，但 MuMu 实机为连排（0.4px）且
			# 用户 2026-09-07 裁决「间距太大」→ 收紧为 amount 右缘（=childX，源中心锚公式所致）
			# +1px（受控偏离源数值）。
			var need_center_x: float = children_pos[i].x + 1.0 + need_lbl.get_combined_minimum_size().x * 0.5
			need_lbl.position = _gl(Vector2(need_center_x, AMOUNT_LABEL_Y)) - need_lbl.get_combined_minimum_size() * 0.5
		else:
			var eq_lbl := Label.new()
			eq_lbl.text = panel.cm.get_lstr(LSTR_EQUIPPED)
			eq_lbl.theme_type_variation = &"EquipCraftBrownLabel18"
			tree.add_child(eq_lbl)
			eq_lbl.position = _gl(children_pos[i]) - eq_lbl.get_combined_minimum_size() * 0.5
	panel._tree_data["children"] = children_icons
	panel._tree_data["amountLabel"] = amount_labels


static func _build_cost(panel, tree: Control, expense: int) -> void:
	# 源 equipcraft.lua:1110-1123 花费区三元素（createttf 系 CCLabelTTF 中心锚；无金币 icon——
	# 旧实现自建 goldicon + 左上直挂三连错：标题右移 46/下移 14.5、金额被按钮切、icon 夹缝不可见，
	# 2026-09-07 照源重排）：
	#   costBg（equip_craft_money_bg sprite 中心锚）@(142,86)
	#   costTitle "合成花费："（createttf 中心锚）@(100,85)
	#   cost 金额（createttf 中心锚）@(200,85)
	# 装饰节点 mouse_filter=IGNORE 避免拦截合成树点击（红线：装饰节点必须 IGNORE）。
	var bg := TextureRect.new()
	bg.texture = load(COST_BG_RES) as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var cost_bg_size: Vector2 = TexDisplaySize.display_size(COST_BG_RES)
	bg.size = cost_bg_size
	bg.position = _gl(COST_BG_POS) - cost_bg_size * 0.5
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree.add_child(bg)
	var cost_title := Label.new()
	cost_title.text = panel.cm.get_lstr(LSTR_SYNTHESIS_COST)
	cost_title.theme_type_variation = &"EquipCraftBrownLabel18"
	tree.add_child(cost_title)
	cost_title.position = _gl(COST_TITLE_POS) - cost_title.get_combined_minimum_size() * 0.5
	panel._tree_data["costTitle"] = cost_title
	var cost_lbl := Label.new()
	cost_lbl.text = str(expense)
	cost_lbl.theme_type_variation = &"EquipCraftDynLabel18"
	tree.add_child(cost_lbl)
	cost_lbl.position = _gl(COST_POS) - cost_lbl.get_combined_minimum_size() * 0.5
	var money: int = panel._player_money()
	cost_lbl.modulate = COLOR_DARK_RED if expense <= money else COLOR_RED
	panel._tree_data["cost"] = cost_lbl


# 历史选中态高亮（源 equipcraft.lua:887-892）：当前 cursor 位置（panel._history_id-1 索引）icon
# 上叠 equip_craft_select 框（上框下 V 尖连体，即 MuMu 实机顶部"图标+下指箭头"观感的箭头部分）。
# 装饰节点 mouse_filter=IGNORE 避免拦截 history icon gui_input（红线：装饰节点必须 IGNORE）。
const CURSOR_META: String = "history_cursor"

static func update_history_cursor(panel) -> void:
	if panel._history_layer == null or not is_instance_valid(panel._history_layer):
		return
	# 移除旧 cursor（按 meta 标记查子树，防 cursor 误挂在 iconBg 内层）。
	for child in panel._history_layer.get_children():
		if child.has_meta(CURSOR_META):
			child.queue_free()
	var idx: int = panel._history_id - 1   # _history_id 1-based → 0-based 索引
	if idx < 0 or idx >= panel._history.size():
		return
	var entry: Dictionary = panel._history[idx]
	var icon_bg: Control = entry.get("iconBg", null)
	if icon_bg == null or not is_instance_valid(icon_bg):
		return
	var tex: Texture2D = load(panel.HISTORY_CURSOR_RES) as Texture2D
	if tex == null:
		return
	var cursor := TextureRect.new()
	cursor.texture = tex
	cursor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# 源 setHistory :884-892：select 框原尺寸显示（57×70px ÷CS = 44.5×54.6 点）中心锚 @历史项
	# 中心。entry["iconBg"] 是 wrapper（无 scale，HBox 重置问题已隔离），icon 视觉 = 从 wrapper
	# 原点渲染 38×38.4（icon_bg 在 wrapper 内 scale 0.518），中心 (19,19.2)。
	var global_w: float = float(tex.get_width()) / CONTENT_SCALE
	var global_h: float = float(tex.get_height()) / CONTENT_SCALE
	cursor.size = Vector2(global_w, global_h)
	# 源 setHistory :892 historyCursor @ (ori.x+…, ori.y-5)：select 框中心比 icon 中心低 5px
	#（cocos y 向上 345<350）→ 顶缘距 bg 顶线恢复源 8px（旧实现同中心致 select 顶贴 bg 边框线
	# 被用户视为「图标超出背景框」，2026-09-07 补译）。
	cursor.position = Vector2(19.0, 19.25 + 5.0) - cursor.size * 0.5
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.set_meta(CURSOR_META, true)
	icon_bg.add_child(cursor)


static func _judge_lack_of_component(panel) -> void:
	var node_amount: Array = panel._craft_window_data.get("nodeAmount", [])
	var node_need: Array = panel._craft_window_data.get("nodeNeed", [])
	var nodeid: Array = panel._craft_window_data.get("nodeid", [])
	for i in range(node_amount.size()):
		if int(node_amount[i]) < int(node_need[i]):
			var cid: int = int(nodeid[i])
			if not panel._is_craftable(cid):
				panel._lack_of_component = true
				return
	panel._lack_of_component = false


static func _build_getway_branch(panel, tree: Control, id: int) -> void:
	(panel._tree_data["rootBg"] as Control).position = _icon_pos(ROOT_ICON_NO_RECIPE_POS, ROOT_ICON_NO_RECIPE_SCALE)
	(panel._tree_data["rootBg"] as Control).scale = Vector2(ROOT_ICON_NO_RECIPE_SCALE, ROOT_ICON_NO_RECIPE_SCALE)
	var bg := TextureRect.new()
	bg.texture = load(GETWAY_BG_PATH)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# getway_bg 源 createSprite 无 fix_size → 显示=纹理/CS（[[content-scale-factor]]）
	var bg_size: Vector2 = TexDisplaySize.display_size(GETWAY_BG_PATH)
	bg.size = bg_size
	bg.position = _gl(GETWAY_BG_POS) - bg_size / 2.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree.add_child(bg)
	var label := Label.new()
	label.text = panel.cm.get_lstr(LSTR_WAY_TO_GET)
	label.theme_type_variation = &"EquipCraftWayTitleLabel"
	tree.add_child(label)
	# 源 :1141-1145 setAnchorPoint(0,0.5) 左中锚 → x 取左缘、y 居中补偿（2026-09-07 修）
	label.position = _gl(GETWAY_LABEL_POS) - Vector2(0.0, label.get_combined_minimum_size().y * 0.5)
	var equip_info: Dictionary = panel.cm.get_raw_table("Equip").get(str(id), {})
	var stage_table: Dictionary = panel.cm.get_raw_table("Stage")
	var max_chapter: int = int(panel.cm.get_raw_table("GameConfig").get("MaxChapter", 13))
	var getway: Array = []
	for i in range(1, 4):
		var s: int = int(equip_info.get("Drop " + str(i), 0))
		if s > 0:
			var st_row: Dictionary = stage_table.get(str(s), {})
			if int(st_row.get("Chapter ID", 0)) <= max_chapter:
				getway.append(s)
	panel._get_way_ids = getway
	for i in range(getway.size()):
		_build_one_getway(panel, tree, stage_table, getway[i], i)


static func _build_one_getway(panel, tree: Control, stage_table: Dictionary, raw_sid: int, idx: int) -> void:
	var is_elite: bool = false
	var sid: int = raw_sid
	if raw_sid >= 10000:
		sid = int(stage_table.get(str(raw_sid), {}).get("Stage Group", raw_sid))
		is_elite = true
	var stage_row: Dictionary = stage_table.get(str(sid), {})
	var board := TextureRect.new()
	board.texture = load(GETWAY_BOARD_PATH)
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# board 源 createSprite 无 fix_size → 显示=纹理/CS（[[content-scale-factor]]）；子节点 position 不动
	var board_size: Vector2 = TexDisplaySize.display_size(GETWAY_BOARD_PATH)
	board.size = board_size
	board.position = _gl(Vector2(142.0, GETWAY_BOARD_Y_BASE - GETWAY_BOARD_DY * idx)) - board_size / 2.0
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.gui_input.connect(panel._make_get_way_handler(idx))
	tree.add_child(board)
	var icon_path: String = StageRes.get_stage_icon(sid, panel.cm)
	if ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(STAGE_ICON_SIZE, STAGE_ICON_SIZE)
		icon.size = Vector2(STAGE_ICON_SIZE, STAGE_ICON_SIZE)
		icon.position = BOARD_ICON_POS
		board.add_child(icon)
	var title := Label.new()
	title.text = panel.cm.get_lstr(LSTR_CHAPTER_D) % int(stage_row.get("Chapter ID", 0))
	title.theme_type_variation = &"EquipCraftBoardLabel"
	title.position = BOARD_TITLE_POS
	board.add_child(title)
	if is_elite:
		var elite := Label.new()
		elite.text = panel.cm.get_lstr(LSTR_ELITE)
		elite.theme_type_variation = &"EquipCraftRedLabel18"
		elite.position = Vector2(BOARD_TITLE_POS.x + title.get_combined_minimum_size().x + 4.0, BOARD_TITLE_POS.y)
		board.add_child(elite)
	var name_lbl := Label.new()
	# Stage Name 存 LSTR key（stage_detail_panel:79 口径 508/535 是 key）→ get_lstr 本地化
	#（同 stone_detail_panel:205 / stage_select_panel:333；裸 key 直接上屏是 Task 2 审查同款问题）
	name_lbl.text = panel.cm.get_lstr(String(stage_row.get("Stage Name", "")))
	name_lbl.theme_type_variation = &"EquipCraftBoardLabel"
	name_lbl.position = BOARD_NAME_POS
	board.add_child(name_lbl)
	var name_w: float = name_lbl.get_combined_minimum_size().x
	if name_w > BOARD_NAME_MAX_W:
		name_lbl.scale = Vector2(BOARD_NAME_MAX_W / name_w, BOARD_NAME_MAX_W / name_w)
	panel._get_way_buttons.append(board)


static func _build_craft_button(panel, tree: Control, components: int) -> void:
	var text: String = panel.cm.get_lstr(LSTR_SYNTHESIS) if components >= 1 else panel.cm.get_lstr(LSTR_RETURN)
	var btn: TextureButton = UiButton.make(CRAFT_BTN_RES, CRAFT_BTN_PRESS_RES, _gl(CRAFT_BTN_POS), text, COLOR_WHITE)
	btn.disabled = panel._lack_of_component or not panel._check_money_enough()
	btn.pressed.connect(panel._on_craft_pressed)
	tree.add_child(btn)
	panel._craft_btn = btn
	panel._craft_btn_label = btn.get_child(0) as Label   # UiButton.make 加 Label 为第一子
