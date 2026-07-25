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
# 图标缩放（源 createIcon(id, size) → ReadequipIcon 72px 基底 × scale）
const ROOT_ICON_SCALE: float = 60.0 / 72.0
const CHILD_ICON_SCALE: float = 45.0 / 72.0
const ROOT_ICON_NO_RECIPE_SCALE: float = 0.6
# ── 颜色（源 ccc3）──
const COLOR_RED: Color = Color(1.0, 0.0, 0.0)
const COLOR_DARK_RED: Color = Color(155.0 / 255.0, 34.0 / 255.0, 14.0 / 255.0)
const COLOR_BROWN: Color = Color(50.0 / 255.0, 41.0 / 255.0, 31.0 / 255.0)
const COLOR_TITLE: Color = Color(182.0 / 255.0, 65.0 / 255.0, 21.0 / 255.0)
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
const BG_HALF_W: float = 184.5   # equip_craft_bg 369/2
const BG_HALF_H: float = 246.5   # equip_craft_bg 493/2


static func _gl(pos: Vector2) -> Vector2:
	return Vector2(pos.x - BG_HALF_W, BG_HALF_H - pos.y)


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
	name_lbl.position = _gl(NAME_LABEL_POS)
	tree.add_child(name_lbl)
	panel._tree_data["name"] = name_lbl
	var root_icon: Control = ReadequipIcon.create_icon(id, 0, panel.cm)
	root_icon.scale = Vector2(ROOT_ICON_SCALE, ROOT_ICON_SCALE)
	tree.add_child(root_icon)
	panel._tree_data["rootBg"] = root_icon
	var expense: int = 99999999
	if components > 0:
		root_icon.position = _gl(ROOT_ICON_POS)
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
		child_icon.position = _gl(children_pos[i])
		child_icon.mouse_filter = Control.MOUSE_FILTER_STOP
		child_icon.gui_input.connect(panel._make_tree_node_handler(i))
		tree.add_child(child_icon)
		children_icons.append(child_icon)
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
	cost_lbl.modulate = COLOR_DARK_RED if expense <= money else COLOR_RED
	tree.add_child(cost_lbl)
	panel._tree_data["cost"] = cost_lbl


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
	(panel._tree_data["rootBg"] as Control).position = _gl(ROOT_ICON_NO_RECIPE_POS)
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
	label.position = _gl(GETWAY_LABEL_POS)
	label.modulate = COLOR_DARK_RED
	tree.add_child(label)
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
	title.position = BOARD_TITLE_POS
	title.modulate = COLOR_TITLE
	board.add_child(title)
	if is_elite:
		var elite := Label.new()
		elite.text = panel.cm.get_lstr(LSTR_ELITE)
		elite.position = Vector2(BOARD_TITLE_POS.x + title.get_combined_minimum_size().x + 4.0, BOARD_TITLE_POS.y)
		elite.modulate = COLOR_RED
		board.add_child(elite)
	var name_lbl := Label.new()
	name_lbl.text = String(stage_row.get("Stage Name", ""))
	name_lbl.position = BOARD_NAME_POS
	name_lbl.modulate = COLOR_TITLE
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
