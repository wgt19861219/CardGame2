class_name RanklistMyselfOverlay
extends RefCounted

## 排行榜"我的排名"浮窗 helper（View 层）— 照源 ranklist.lua:1318-1571 createMyselfRankSummary。
## 当 self_rank > 2（前 2 已在列表显）时，在 ScrollLayer 之上叠 pageContainer：
## ranklist_my_bg + 排名图标（1st/2nd/3rd 徽章资源缺→数字 / >3 数字）+ pvp_up/down 升降箭头
## + delta 标签（COMPAREYESTERDAY + |delta|）+ 头像 + 名字 + 等级。
## 单机化裁剪：源 getMyselfRankSummary 联机查 previndex → 本项目 previndex=0（首次），
## delta = self_rank（源 :1364-1365 previndex==0 时 deltaposvalue=index）。
## 批4 Task 8：add_theme 色/号 override 清零 → theme_type_variation（default_theme ranklist 系）。

const BOARD_OFFSET: Vector2 = Vector2(8.0, 7.0)
const ME_BG_RES: String = "res://assets/ui/alpha/HVGA/ranklist/ranklist_my_bg.png"
const PVP_UP_RES: String = "res://assets/ui/alpha/HVGA/pvp/pvp_up.png"
const PVP_DOWN_RES: String = "res://assets/ui/alpha/HVGA/pvp/pvp_down.png"
const RANK_1ST_RES: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_1st_star.png"
const RANK_2ND_RES: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_2nd_star.png"
const RANK_3RD_RES: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_3rd_star.png"
# variation 名（default_theme 批4 Task 8；色/号见 tres 注释）。
const VAR_WHITE_18: String = "RanklistWhiteLabel18"
const VAR_HINT: String = "RanklistOverlayHintLabel"
const VAR_DELTA: String = "RanklistOverlayDeltaLabel"
# ── 2026-08-18 修复轮三 T1：浮窗尺寸/内部布局照源重算 ──
# 源 board 无 fix → 显示 = 纹理 642×107px ÷CS = 501.07×83.51 点（旧实现误用
# TexDisplaySize.display_size——当时公式 base×cs 对无条目散图偏大 1.28×，
# 致浮窗 642 宽超出 512 列表区，用户反馈"太大超出边框"；该公式 2026-08-21 Task5
# 已修正 ÷CS，与本手算等价）。内部坐标源系 ed.DGccp
# （×0.78125）+ cocos y-up → Godot y = BOARD_H - y_dg（旧常量源原文直用三重漏换算）。
const CONTENT_SCALE: float = 1.28125
const BOARD_SIZE: Vector2 = Vector2(642.0 / CONTENT_SCALE, 107.0 / CONTENT_SCALE)   # 501.07×83.51
# ranking (60,50)DG=(46.88,39.06) → y=83.51-39.06=44.45；:1360 scale=min(1,70/点宽)。
const RANK_POS: Vector2 = Vector2(46.88, 44.45)
const RANK_MAX_W: float = 70.0   # 点值（对 ÷CS 后的点宽取 min）
# arrow (130,30)DG；hint (155,67)DG；delta (173,30)DG → y 各翻。
const ARROW_POS: Vector2 = Vector2(101.56, 60.07)
const HINT_POS: Vector2 = Vector2(121.09, 31.17)
const DELTA_POS: Vector2 = Vector2(135.16, 60.07)
# head (175+80,50)DG=(199.22,39.06) → y=44.45；scale 0.85。
const HEAD_POS: Vector2 = Vector2(199.22, 44.45)
const HEAD_SCALE: Vector2 = Vector2(0.85, 0.85)
const HEAD_SIZE: Vector2 = Vector2(60.0, 60.0)
# name (280+80,67)DG=(281.25,52.34) → y=31.17，anchor(0,0.5) 左对齐垂直居中。
const NAME_POS: Vector2 = Vector2(281.25, 31.17)
const Z_ORDER: int = 99
const RANK_TOP_VISIBLE_MAX: int = 2   # 前 2 名已在列表显，浮窗不叠（源 :1330）
const SCROLL_OFFSET_Y: float = 80.0   # 源 rankListMyselfOffsetY（:1336，浮窗显示时列表让位高）


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
	board.size = BOARD_SIZE   # 修复轮三 T1：手算 ÷CS（2026-08-21 Task5 后 TexDisplaySize 等价，保留手算）
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
		# 修复轮三 T1：head 图显示 = 纹理 ÷CS（手算，同 board 口径）。
		var sz: Vector2 = (icon.texture.get_size() / CONTENT_SCALE) if icon.texture != null else Vector2(40.0, 40.0)
		icon.size = sz
		icon.pivot_offset = sz * 0.5
		# 源 :1360 scale=min(1, 70/w)——70 是点值，对点宽取 min。
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
	num.theme_type_variation = VAR_WHITE_18
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
	hint.theme_type_variation = VAR_HINT
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(hint)
	# delta |val|（源 :1397-1410）。
	var dl := Label.new()
	dl.text = str(absi(delta))
	dl.position = DELTA_POS - Vector2(20.0, 10.0)
	dl.size = Vector2(40.0, 20.0)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.theme_type_variation = VAR_DELTA
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
	name_lbl.theme_type_variation = VAR_WHITE_18
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(name_lbl)
