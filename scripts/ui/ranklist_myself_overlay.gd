class_name RanklistMyselfOverlay
extends RefCounted

## 排行榜"我的排名"浮窗 helper（View 层）— 照源 ranklist.lua:1318-1571 createMyselfRankSummary。
## 当 self_rank > 2（前 2 已在列表显）时，在 ScrollLayer 之上叠 pageContainer：
## ranklist_my_bg + 排名图标（1st/2nd/3rd 徽章资源缺→数字 / >3 数字）+ pvp_up/down 升降箭头
## + delta 标签（COMPAREYESTERDAY + |delta|）+ 头像 + 名字 + 等级。
## 单机化裁剪：源 getMyselfRankSummary 联机查 previndex → 本项目 previndex=0（首次），
# delta = self_rank（源 :1364-1365 previndex==0 时 deltaposvalue=index）。

const BOARD_OFFSET: Vector2 = Vector2(8.0, 7.0)
const ME_BG_RES: String = "res://assets/ui/alpha/HVGA/ranklist/ranklist_my_bg.png"
const PVP_UP_RES: String = "res://assets/ui/alpha/HVGA/pvp/pvp_up.png"
const PVP_DOWN_RES: String = "res://assets/ui/alpha/HVGA/pvp/pvp_down.png"
const RANK_1ST_RES: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_1st_star.png"
const RANK_2ND_RES: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_2nd_star.png"
const RANK_3RD_RES: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_3rd_star.png"
# 源 :1359 ranking:setPosition(60,50)；:1360 scale=min(1, 70/w)。
const RANK_POS: Vector2 = Vector2(60.0, 50.0)
const RANK_MAX_W: float = 70.0
# 源 :1378 arrow pos(130,30) anchor(0.5,0.5)；:1389 hint "较昨日" pos(155,67)；:1405 delta |val| pos(173,30)。
const ARROW_POS: Vector2 = Vector2(130.0, 30.0)
const HINT_POS: Vector2 = Vector2(155.0, 67.0)
const DELTA_POS: Vector2 = Vector2(173.0, 30.0)
# 源 :1423 head pos(175+xOffset,50) scale 0.85；xOffset=80（源 :1362）。
const HEAD_POS: Vector2 = Vector2(255.0, 50.0)
const HEAD_SCALE: Vector2 = Vector2(0.85, 0.85)
const HEAD_SIZE: Vector2 = Vector2(60.0, 60.0)
# 源 :1436/1458 name pos(280+xOffset,67) anchor(0,0.5)。
const NAME_POS: Vector2 = Vector2(360.0, 67.0)
const HINT_COLOR: Color = Color(241.0 / 255.0, 193.0 / 255.0, 113.0 / 255.0)
const DELTA_COLOR: Color = Color(242.0 / 255.0, 98.0 / 255.0, 60.0 / 255.0)
const FONT_SIZE: int = 18
const Z_ORDER: int = 99
const RANK_TOP_VISIBLE_MAX: int = 2   # 前 2 名已在列表显，浮窗不叠（源 :1330）


# 建"我的排名"浮窗挂 parent（ScrollLayer 之上）。self_rank<=2 → 不建（前 2 已列表内显）。
# 返 pageContainer（或 null 当跳过）。单机化：prev_index=0 → delta=|self_rank|（源 :1365）。
static func build(parent: Control, self_rank: int, player_name: String, level: int, avatar_pic_path: String) -> Control:
	if self_rank <= RANK_TOP_VISIBLE_MAX or self_rank < 0:
		return null
	var page := Control.new()
	page.name = "PageContainer"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.z_index = Z_ORDER
	parent.add_child(page)
	var board := _make_board(page)
	_add_rank_icon(board, self_rank)
	# 单机化 prev_index=0 → delta=self_rank（上升 self_rank 位）。源 :1364-1365。
	_add_delta_arrow(board, self_rank)
	_add_head(board, avatar_pic_path)
	_add_name(board, player_name, level)
	return page


# ranklist_my_bg.png（源 :1338-1348 board anchor(0,1) pos(8,7)）。
static func _make_board(page: Control) -> TextureRect:
	var board := TextureRect.new()
	board.texture = load(ME_BG_RES) as Texture2D
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.size = TexDisplaySize.display_size(ME_BG_RES) if board.texture != null else Vector2(400.0, 80.0)
	# 源 anchor(0,1) pos(8,7) y-up → Godot y-down：page 内 (8, pageH-7-boardH)；page 无 size，用 board 左上 (8,7) 近似。
	board.position = BOARD_OFFSET
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(board)
	return board


# 源 :1349-1361 ranking：1st/2nd/3rd 用徽章图（资源存在）；>3 用数字节点。
static func _add_rank_icon(board: TextureRect, self_rank: int) -> void:
	var res: String = ""
	match self_rank:
		1: res = RANK_1ST_RES
		2: res = RANK_2ND_RES
		3: res = RANK_3RD_RES
	if res != "" and ResourceLoader.exists(res):
		var icon := TextureRect.new()
		icon.texture = load(res) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var sz: Vector2 = TexDisplaySize.display_size(res) if icon.texture != null else Vector2(40.0, 40.0)
		icon.size = sz
		icon.pivot_offset = sz * 0.5
		# 源 :1360 scale=min(1, 70/w)。
		var s: float = minf(1.0, RANK_MAX_W / sz.x) if sz.x > 0.0 else 1.0
		icon.scale = Vector2(s, s)
		icon.position = RANK_POS - sz * 0.5
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.add_child(icon)
		return
	# >3 数字 Label（源 :1357 getNumberNode folder big_pvp；本项目无数字图集 → Label 降级）。
	var num := Label.new()
	num.text = "#%d" % self_rank
	num.position = RANK_POS - Vector2(30.0, 12.0)
	num.size = Vector2(60.0, 24.0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", FONT_SIZE)
	num.add_theme_color_override("font_color", Color.WHITE)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(num)


# 源 :1370-1411 delta>0 显 pvp_up + |delta|；delta<0 显 pvp_down + |delta|；delta==0 不显。
# 单机化 prev=0 → delta=self_rank（恒 >0 显 up）。
static func _add_delta_arrow(board: TextureRect, delta: int) -> void:
	if delta == 0:
		return
	var arrow_res: String = PVP_UP_RES if delta > 0 else PVP_DOWN_RES
	if ResourceLoader.exists(arrow_res):
		var arrow := TextureRect.new()
		arrow.texture = load(arrow_res) as Texture2D
		arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var sz: Vector2 = TexDisplaySize.display_size(arrow_res) if arrow.texture != null else Vector2(20.0, 20.0)
		arrow.size = sz
		arrow.pivot_offset = sz * 0.5
		arrow.position = ARROW_POS - sz * 0.5
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.add_child(arrow)
	# hint "较昨日"（源 :1381-1394 RANKLIST.COMPAREYESTERDAY）。
	var hint := Label.new()
	hint.text = "较昨日"
	hint.position = HINT_POS - Vector2(40.0, 10.0)
	hint.size = Vector2(80.0, 20.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", FONT_SIZE)
	hint.add_theme_color_override("font_color", HINT_COLOR)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(hint)
	# delta |val|（源 :1397-1410）。
	var dl := Label.new()
	dl.text = str(absi(delta))
	dl.position = DELTA_POS - Vector2(20.0, 10.0)
	dl.size = Vector2(40.0, 20.0)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.add_theme_font_size_override("font_size", FONT_SIZE)
	dl.add_theme_color_override("font_color", DELTA_COLOR)
	dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(dl)


# 源 :1412-1426 head getTeamHead（avatar Picture），pos(175+xOffset,50) scale 0.85。
static func _add_head(board: TextureRect, avatar_pic_path: String) -> void:
	if avatar_pic_path.is_empty() or not ResourceLoader.exists(avatar_pic_path):
		return
	var head := TextureRect.new()
	head.texture = load(avatar_pic_path) as Texture2D
	head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.size = HEAD_SIZE
	head.pivot_offset = HEAD_SIZE * 0.5
	head.scale = HEAD_SCALE
	head.position = HEAD_POS - HEAD_SIZE * 0.5
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(head)


# 源 :1453-1460 name pos(280+xOffset,67) anchor(0,0.5)。
static func _add_name(board: TextureRect, player_name: String, level: int) -> void:
	var name_lbl := Label.new()
	name_lbl.text = "%s Lv%d" % [player_name, level]
	name_lbl.position = NAME_POS - Vector2(0.0, 10.0)
	name_lbl.add_theme_font_size_override("font_size", FONT_SIZE)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(name_lbl)
