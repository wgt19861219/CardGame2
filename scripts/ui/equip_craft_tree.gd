class_name EquipCraftTree
extends RefCounted

## 装备合成树构建（View helper）— 从 EquipCraftPanel 拆出控 ≤400。
## static 方法第一参 panel，照 equip_strengthen_anim.gd 静态拆分范式。
## 主类 _create_craft_tree 转发本类（被 _create_craft_window/_play_craft_effect/_set_history 调用）。
## 源 ui/equipcraft.lua createCraftTree:927-1233 + 配方分支 :1037-1132 + 获取途径 :1133-1202。

# 源 hello.lua:311 setContentScaleFactor(1.28125)；cocos sprite 显示=纹理/CS（无 fix_size 时）。
const CONTENT_SCALE: float = 1.28125
# ── 合成树坐标常量（源 cocos 值）──────────────────────────────────────
const NAME_LABEL_POS: Vector2 = Vector2(142.0, 292.0)     # 源 :998
const ROOT_ICON_POS: Vector2 = Vector2(141.0, 230.0)      # 源 :1032
const ROOT_ICON_NO_RECIPE_POS: Vector2 = Vector2(50.0, 250.0)  # 源 :1134 components<1
const COST_TITLE_POS: Vector2 = Vector2(100.0, 85.0)      # 源 :1117
const COST_POS: Vector2 = Vector2(200.0, 85.0)            # 源 :1128
const TRUNK_POS: Vector2 = Vector2(142.0, 190.0)          # 源 :1050
const AMOUNT_LABEL_Y: float = 115.0                       # 源 amountLabel y（:1093/:1100）
const AMOUNT_NEED_OFFSET: float = 9.0                     # 源 :1100 x+9
const CRAFT_BTN_POS: Vector2 = Vector2(143.0, 45.0)       # 源 craftButton :1011
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
const GETWAY_LABEL_POS: Vector2 = Vector2(80.0, 250.0)    # 源 :1141
const GETWAY_BOARD_Y_BASE: float = 200.0                  # 源 :1161 200-50*(i-1)
const GETWAY_BOARD_DY: float = 50.0
const GETWAY_BG_PATH: String = "res://assets/ui/alpha/HVGA/equip_craft_getway_bg.png"  # 源 :1136
const GETWAY_BOARD_PATH: String = "res://assets/ui/alpha/HVGA/equip_craft_getway_board.png"  # 源 :1160
const GETWAY_BG_POS: Vector2 = Vector2(142.0, 177.0)      # 源 :1137
const STAGE_ICON_SIZE: float = 40.0                       # 源 :1177 scale 75/width，适配 board 高度（50）
const BOARD_TITLE_POS: Vector2 = Vector2(50.0, 3.0)       # 源 :1181 board 内 title 位置
const BOARD_NAME_POS: Vector2 = Vector2(50.0, 25.0)       # 源 :1194 board 内 name 位置
const BOARD_NAME_MAX_W: float = 160.0                     # 源 :1196 name 宽超 160 缩放
const BOARD_ICON_POS: Vector2 = Vector2(5.0, 5.0)         # 源 :1176 stage icon 位置
# 按钮纹理（源 :1008/:1018 package_button 双层 Sprite + Label）
const CRAFT_BTN_RES: String = "res://assets/ui/alpha/HVGA/package_button.png"
const CRAFT_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/package_button_down.png"
# 图标缩放（源 createIcon(id, size) → ReadequipIcon 72px 基底 × scale）
const ROOT_ICON_SCALE: float = 60.0 / 72.0                # 源 createIcon(id, 60)
const CHILD_ICON_SCALE: float = 45.0 / 72.0               # 源 createIcon(id, 45)
const ROOT_ICON_NO_RECIPE_SCALE: float = 0.6              # 源 :1135 setScale(0.6)
# ── 颜色（源 ccc3）──
const COLOR_RED: Color = Color(1.0, 0.0, 0.0)
const COLOR_DARK_RED: Color = Color(155.0 / 255.0, 34.0 / 255.0, 14.0 / 255.0)  # 源 155,34,14
const COLOR_BROWN: Color = Color(50.0 / 255.0, 41.0 / 255.0, 31.0 / 255.0)      # 源 50,41,31
const COLOR_TITLE: Color = Color(182.0 / 255.0, 65.0 / 255.0, 21.0 / 255.0)     # 源 :1180/:1192
const COLOR_WHITE: Color = Color(1.0, 1.0, 1.0)           # 源 normalColor :10
# ── LSTR key（源 LSTR 宏，panel.cm.get_lstr 取实际值）──
const LSTR_RETURN: String = "EQUIPCRAFT.RETURN"
const LSTR_SYNTHESIS: String = "EQUIPCRAFT.SYNTHESIS"
const LSTR_SYNTHESIS_COST: String = "EQUIPCRAFT.SYNTHESIS_COST_"
const LSTR_WAY_TO_GET: String = "EQUIPCRAFT.WAY_TO_GET_"
const LSTR_EQUIPPED: String = "EQUIPCRAFT.EQUIPPED"
const LSTR_ELITE: String = "EQUIPCRAFT.ELITE"
const LSTR_CHAPTER_D: String = "EQUIPCRAFT._CHAPTER__D"
# ── craftWindow(bg)局部坐标翻转 ──────────────────────────────────────
# 源 craftWindow.mainLayer = bg（equip_craft_bg 369×493 CCSprite），子节点原点 = bg 左下角 y-up。
# panel._craft_window 代表 bg 中心（position=_g(CRAFT_WINDOW_POS)，bg.position=-size/2 对齐中心），
# 故 bg 局部(cx,cy) → Godot 相对中心 = (cx - BG_HALF_W, BG_HALF_H - cy)。照源 equipcraft.lua:949-952。
const BG_HALF_W: float = 184.5   # equip_craft_bg 369/2
const BG_HALF_H: float = 246.5   # equip_craft_bg 493/2


# 源 cocos bg 局部（相对 craftWindow.mainLayer=bg 左下角，y-up）→ Godot _craft_window 局部（相对 bg 中心，y-down）。
static func _gl(pos: Vector2) -> Vector2:
	return Vector2(pos.x - BG_HALF_W, BG_HALF_H - pos.y)


# 源 createCraftTree :927-1233（核心合成树）。
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
	panel._craft_window.add_child(tree)
	var name_lbl := Label.new()
	name_lbl.text = panel._equip_name(id)
	name_lbl.position = _gl(NAME_LABEL_POS)
	tree.add_child(name_lbl)
	panel._tree_data["name"] = name_lbl
	var root_icon: Control = ReadequipIcon.create_icon(id, 0, panel.cm)
	root_icon.scale = Vector2(ROOT_ICON_SCALE, ROOT_ICON_SCALE)
	tree.add_child(root_icon)
	panel._tree_data["rootBg"] = root_icon
	var expense: int = 99999999   # 源 :1121 默认
	if components > 0:
		root_icon.position = _gl(ROOT_ICON_POS)
		_build_recipe_branch(panel, tree, row, components)   # 源 :1037-1132 配方分支
		expense = int(row.get("Expense", 99999999))
		panel._craft_window_data["expense"] = expense
		_build_cost(panel, tree, expense)                     # 源 :1110-1131 金币
		panel._lack_of_component = false                     # 源 :1132
		_judge_lack_of_component(panel)                       # 源 :1214-1228（craftButton 禁用判定）
	else:
		_build_getway_branch(panel, tree, id)                 # 源 :1133-1202 获取途径分支
	_build_craft_button(panel, tree, components)              # 源 craftButton :1004 + craftLabel :1209


# 源 :1037-1132 components>0 配方分支：childrenPos + nodeid/nodeNeed/nodeAmount/nodeRepeat + 子图标+数量。
static func _build_recipe_branch(panel, tree: Control, row: Dictionary, components: int) -> void:
	var trunk := TextureRect.new()
	trunk.texture = load(LINE_RES[components - 1])
	trunk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# trunk 源 Sprite 无 fix_size → 显示=纹理/CS（[[content-scale-factor]]）
	var trunk_size: Vector2 = trunk.texture.get_size() / CONTENT_SCALE
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
		# 源 nodeRepeat :1066-1075（重复材料计数：与前面同 id 累加 need）
		if i == 0:
			node_repeat.append(0)
		else:
			var rep: int = 0
			for j in range(i):
				if nodeid[j] == cid:
					rep += need
				else:
					rep = 0   # 源 else 分支每次清零（照源）
			node_repeat.append(rep)
		# 源 nodeAmount :1076-1079
		var raw_amount: int = panel._get_amount(cid) - int(node_repeat[i])
		node_amount.append(raw_amount if raw_amount > 0 else 0)
		# 源 childBg = createIcon(id, 45) :1080
		var child_icon: Control = ReadequipIcon.create_icon(cid, 0, panel.cm)
		child_icon.scale = Vector2(CHILD_ICON_SCALE, CHILD_ICON_SCALE)
		child_icon.position = _gl(children_pos[i])
		child_icon.mouse_filter = Control.MOUSE_FILTER_STOP
		child_icon.gui_input.connect(panel._make_tree_node_handler(i))   # 源 doTreeNodeTouch :258
		tree.add_child(child_icon)
		children_icons.append(child_icon)
		# 源 amountLabel :1085-1108（<10000 显示拥有量 + "/X"；>=10000 显示已装备）
		var amount: int = int(node_amount[i])
		if amount < 10000:
			var lbl := Label.new()
			lbl.text = str(amount)
			lbl.position = _gl(Vector2(children_pos[i].x - 20.0, AMOUNT_LABEL_Y))
			lbl.modulate = COLOR_RED if amount < int(node_need[i]) else COLOR_BROWN
			tree.add_child(lbl)
			amount_labels.append(lbl)
			var need_lbl := Label.new()
			need_lbl.text = "/" + str(int(node_need[i]))
			need_lbl.position = _gl(Vector2(children_pos[i].x + AMOUNT_NEED_OFFSET, AMOUNT_LABEL_Y))
			need_lbl.modulate = COLOR_BROWN
			tree.add_child(need_lbl)
		else:
			var eq_lbl := Label.new()
			eq_lbl.text = panel.cm.get_lstr(LSTR_EQUIPPED)
			eq_lbl.position = _gl(Vector2(children_pos[i].x, AMOUNT_LABEL_Y))
			eq_lbl.modulate = COLOR_BROWN
			tree.add_child(eq_lbl)
	panel._tree_data["children"] = children_icons
	panel._tree_data["amountLabel"] = amount_labels


# 源 :1110-1131 金币 costTitle + cost。
static func _build_cost(panel, tree: Control, expense: int) -> void:
	var cost_title := Label.new()
	cost_title.text = panel.cm.get_lstr(LSTR_SYNTHESIS_COST)
	cost_title.position = _gl(COST_TITLE_POS)
	cost_title.modulate = COLOR_BROWN
	tree.add_child(cost_title)
	panel._tree_data["costTitle"] = cost_title
	var cost_lbl := Label.new()
	cost_lbl.text = str(expense)
	cost_lbl.position = _gl(COST_POS)
	var money: int = panel._player_money()
	cost_lbl.modulate = COLOR_DARK_RED if expense <= money else COLOR_RED   # 源 :1123-1126
	tree.add_child(cost_lbl)
	panel._tree_data["cost"] = cost_lbl


# 源 :1214-1228 craftButton 禁用判定：任一材料不足且不可合成 → lackOfComponent。
static func _judge_lack_of_component(panel) -> void:
	var node_amount: Array = panel._craft_window_data.get("nodeAmount", [])
	var node_need: Array = panel._craft_window_data.get("nodeNeed", [])
	var nodeid: Array = panel._craft_window_data.get("nodeid", [])
	for i in range(node_amount.size()):
		if int(node_amount[i]) < int(node_need[i]):
			var cid: int = int(nodeid[i])
			if not panel._is_craftable(cid):   # 源 ed.isEquipCraftable(cid)
				panel._lack_of_component = true
				return
	panel._lack_of_component = false


# 源 :1133-1202 components<1 获取途径分支：getway_bg + board 贴图 + Drop1-3 过滤 + isElite + stage 图标 + elite + name 缩放。
static func _build_getway_branch(panel, tree: Control, id: int) -> void:
	(panel._tree_data["rootBg"] as Control).position = _gl(ROOT_ICON_NO_RECIPE_POS)
	(panel._tree_data["rootBg"] as Control).scale = Vector2(ROOT_ICON_NO_RECIPE_SCALE, ROOT_ICON_NO_RECIPE_SCALE)
	var bg := TextureRect.new()   # 源 :1136-1138 getway_bg 装饰背景
	bg.texture = load(GETWAY_BG_PATH)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# getway_bg 源 createSprite 无 fix_size → 显示=纹理/CS（[[content-scale-factor]]）
	var bg_size: Vector2 = bg.texture.get_size() / CONTENT_SCALE
	bg.size = bg_size
	bg.position = _gl(GETWAY_BG_POS) - bg_size / 2.0   # 源 setPosition(142,177) 中心锚定
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree.add_child(bg)
	var label := Label.new()
	label.text = panel.cm.get_lstr(LSTR_WAY_TO_GET)
	label.position = _gl(GETWAY_LABEL_POS)
	label.modulate = COLOR_DARK_RED
	tree.add_child(label)
	# 源 :1144-1156 收集 Drop1-3（Chapter ID <= MaxChapter 过滤）
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


# 源 :1158-1201 单个获取途径 board：isElite 解析 + board 贴图 + stage 图标 + 第 X 章 + 精英 + name 缩放。
static func _build_one_getway(panel, tree: Control, stage_table: Dictionary, raw_sid: int, idx: int) -> void:
	# 源 :1165-1174 isElite 分支：id<10000 普通 / id>=10000 精英（gid=Stage Group，id=gid）
	var is_elite: bool = false
	var sid: int = raw_sid
	if raw_sid >= 10000:
		sid = int(stage_table.get(str(raw_sid), {}).get("Stage Group", raw_sid))
		is_elite = true
	var stage_row: Dictionary = stage_table.get(str(sid), {})
	var board := TextureRect.new()   # 源 :1160 board 贴图（替降级 Panel）+ 可点击
	board.texture = load(GETWAY_BOARD_PATH)
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# board 源 createSprite 无 fix_size → 显示=纹理/CS（[[content-scale-factor]]）；子节点 position 不动
	var board_size: Vector2 = board.texture.get_size() / CONTENT_SCALE
	board.size = board_size
	board.position = _gl(Vector2(142.0, GETWAY_BOARD_Y_BASE - GETWAY_BOARD_DY * idx)) - board_size / 2.0
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.gui_input.connect(panel._make_get_way_handler(idx))   # 源 doGetWayTouch :91-123
	tree.add_child(board)
	# 源 :1175-1178 stage 图标 getStageIcon（复用 StageRes）
	var icon_path: String = StageRes.get_stage_icon(sid, panel.cm)
	if ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(STAGE_ICON_SIZE, STAGE_ICON_SIZE)
		icon.size = Vector2(STAGE_ICON_SIZE, STAGE_ICON_SIZE)
		icon.position = BOARD_ICON_POS
		board.add_child(icon)
	# 源 :1179-1183 title "第 X 章"（LSTR._CHAPTER__D = "第%d章"）
	var title := Label.new()
	title.text = panel.cm.get_lstr(LSTR_CHAPTER_D) % int(stage_row.get("Chapter ID", 0))
	title.position = BOARD_TITLE_POS
	title.modulate = COLOR_TITLE
	board.add_child(title)
	# 源 :1184-1190 isElite 时 "精英" 红字（在 title 后）
	if is_elite:
		var elite := Label.new()
		elite.text = panel.cm.get_lstr(LSTR_ELITE)
		elite.position = Vector2(BOARD_TITLE_POS.x + title.get_combined_minimum_size().x + 4.0, BOARD_TITLE_POS.y)
		elite.modulate = COLOR_RED
		board.add_child(elite)
	# 源 :1191-1200 name + W>160 scale 160/W
	var name_lbl := Label.new()
	name_lbl.text = String(stage_row.get("Stage Name", ""))
	name_lbl.position = BOARD_NAME_POS
	name_lbl.modulate = COLOR_TITLE
	board.add_child(name_lbl)
	var name_w: float = name_lbl.get_combined_minimum_size().x
	if name_w > BOARD_NAME_MAX_W:
		name_lbl.scale = Vector2(BOARD_NAME_MAX_W / name_w, BOARD_NAME_MAX_W / name_w)
	panel._get_way_buttons.append(board)


# 源 :1004-1013 craftButton + :1204-1213 craftLabel（合成/返回按钮）。
# 源 Sprite package_button + Label → UiButton.make 纹理化（TextureButton + 子 Label）。
static func _build_craft_button(panel, tree: Control, components: int) -> void:
	var text: String = panel.cm.get_lstr(LSTR_SYNTHESIS) if components >= 1 else panel.cm.get_lstr(LSTR_RETURN)
	var btn: TextureButton = UiButton.make(CRAFT_BTN_RES, CRAFT_BTN_PRESS_RES, _gl(CRAFT_BTN_POS), text, COLOR_WHITE)
	btn.disabled = panel._lack_of_component or not panel._check_money_enough()
	btn.pressed.connect(panel._on_craft_pressed)
	tree.add_child(btn)
	panel._craft_btn = btn
	panel._craft_btn_label = btn.get_child(0) as Label   # UiButton.make 加 Label 为第一子
