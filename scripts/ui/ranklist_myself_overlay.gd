class_name RanklistMyselfOverlay
extends RefCounted

## 排行榜"我的排名"浮窗 helper（View 层）— 照源 ranklist.lua:1318-1571 createMyselfRankSummary。
## 走查批 C（2026-08-27）像素级重做，撤销旧披露降级：
## - ranking：前三裸版 pvp_rank_1st/2nd/3rd.png（HC multilanguage 补源）/ >3 NumberNode
##   big_pvp 贴图数字 + scale=min(1,70/点宽)（:1357-1360；旧 "#N" Label 撤销）；
## - head：TeamHeadIcon（getTeamHead 等价，:1418-1424）外层 scale 0.85（旧方图直显撤销）；
## - nameBg + LevelIcon + 纯名（:1429-1460；旧名字合并 "LvN" 撤销）；
## - tips 行补齐（:1520-1565）：tipsText ccc3(241,193,113) + 千分位值 ccc3(255,234,198)。
## 显示条件照源 :1330-1336：mode==pvp 不建（源 index==1 pvp / index==2 top_arena 排除，
## 本项目无 top_arena tab）、self_rank<0 不建；旧 RANK_TOP_VISIBLE_MAX（前 2 不叠）系
## 误读撤销——源无排名数判断，rank<=3 浮窗内用徽章图（:1350-1355）。
## 单机化：previndex=0 → delta=self_rank（源 :1364-1365）；guildliveness 玩家无公会，
## 浮窗以个人名/头像显示（源 _guild_name/_guild_summary 分支，受控偏离披露）。

const BOARD_OFFSET: Vector2 = Vector2(8.0, 7.0)
const ME_BG_RES: String = "res://assets/ui/alpha/HVGA/ranklist/ranklist_my_bg.png"
const PVP_UP_RES: String = "res://assets/ui/alpha/HVGA/pvp/pvp_up.png"
const PVP_DOWN_RES: String = "res://assets/ui/alpha/HVGA/pvp/pvp_down.png"
const RANK_1ST_RES: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_1st.png"
const RANK_2ND_RES: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_2nd.png"
const RANK_3RD_RES: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_3rd.png"
const NAME_BG_RES: String = "res://assets/ui/alpha/HVGA/task_name_bg.png"
# variation 名（default_theme 批4 Task 8 + 批 C 新增 RanklistOverlayValueLabel）。
const VAR_WHITE_18: String = "RanklistWhiteLabel18"
const VAR_HINT: String = "RanklistOverlayHintLabel"
const VAR_DELTA: String = "RanklistOverlayDeltaLabel"
const VAR_VALUE: String = "RanklistOverlayValueLabel"
# 浮窗尺寸/内部布局（源 ed.DGccp ×0.78125 + cocos y-up → Godot y=83.51−y_dg；修复轮三 T1 口径）。
const CONTENT_SCALE: float = 1.28125
const BOARD_SIZE: Vector2 = Vector2(642.0 / CONTENT_SCALE, 107.0 / CONTENT_SCALE)   # 501.07×83.51
const RANK_POS: Vector2 = Vector2(46.88, 44.45)        # (60,50)DG 中心
const RANK_MAX_W: float = 70.0                          # :1360 scale=min(1,70/w)
const ARROW_POS: Vector2 = Vector2(101.56, 60.07)      # (130,30)DG
const HINT_POS: Vector2 = Vector2(121.09, 31.17)       # (155,67)DG
const DELTA_POS: Vector2 = Vector2(135.16, 60.07)      # (173,30)DG
const HEAD_POS: Vector2 = Vector2(199.22, 44.45)       # (175+80,50)DG
const HEAD_SCALE: float = 0.85                          # :1424
const NAME_BG_LEFT: Vector2 = Vector2(257.81, 31.17)   # (250+80,67)DG anchor(0,0.5)
const LEVEL_CENTER: Vector2 = Vector2(257.81, 32.73)   # (250+80,65)DG
const NAME_LEFT: Vector2 = Vector2(281.25, 31.17)      # (280+80,67)DG anchor(0,0.5)
const GUILD_NAME_DG_DX: float = -40.0                   # :1450 nameoffset
const TIPS_LEFT: Vector2 = Vector2(250.0, 63.2)        # (240+80,26)DG anchor(0,0.5)
const NAME_BG_SIZE: Vector2 = Vector2(329.37, 26.54)
const Z_ORDER: int = 99
const SCROLL_OFFSET_Y: float = 80.0   # 源 rankListMyselfOffsetY（:1336，浮窗显示时列表让位高）


## 建"我的排名"浮窗挂 parent（ScrollLayer 之上）。mode==pvp 或 self_rank<0 → 不建（源 :1330）。
## 返 pageContainer（或 null 当跳过）。单机化：prev_index=0 → delta=self_rank（源 :1365）。
static func build(parent: Control, cm: ConfigManager, rank_type: String, self_rank: int,
		self_param: int, player_name: String, level: int, avatar_id: int) -> Control:
	if rank_type == "pvp" or self_rank < 0:
		return null
	var is_guild: bool = rank_type == "guildliveness"
	var page := Control.new()
	page.name = "PageContainer"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.z_index = Z_ORDER
	parent.add_child(page)
	var board := _make_board(page)
	_add_rank_icon(board, self_rank)
	_add_delta_arrow(board, self_rank)
	var head := TeamHeadIcon.build(cm, avatar_id)
	head.position = HEAD_POS
	head.pivot_offset = Vector2.ZERO
	head.scale = Vector2(HEAD_SCALE, HEAD_SCALE)
	board.add_child(head)
	var guild_dx: float = GUILD_NAME_DG_DX * 0.78125 if is_guild else 0.0
	_add_name(board, player_name, is_guild, guild_dx)
	if not is_guild:
		var level_icon := LevelIcon.build(level)
		level_icon.position = LEVEL_CENTER
		board.add_child(level_icon)
	_add_tips(board, cm, rank_type, self_param, guild_dx)
	return page


# ranklist_my_bg.png（源 :1338-1348 board anchor(0,1) pos(8,7)）。
static func _make_board(page: Control) -> TextureRect:
	var board := TextureRect.new()
	board.texture = load(ME_BG_RES) as Texture2D
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.size = BOARD_SIZE
	board.position = BOARD_OFFSET
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(board)
	return board


# 源 :1349-1361 ranking：1st/2nd/3rd 徽章 / >3 big_pvp 数字，均 scale=min(1,70/点宽)。
static func _add_rank_icon(board: TextureRect, self_rank: int) -> void:
	var badge_res: String = ""
	match self_rank:
		1: badge_res = RANK_1ST_RES
		2: badge_res = RANK_2ND_RES
		3: badge_res = RANK_3RD_RES
	var node: Control = null
	if badge_res != "" and ResourceLoader.exists(badge_res):
		var icon := TextureRect.new()
		icon.texture = load(badge_res) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size = icon.texture.get_size() / CONTENT_SCALE
		node = icon
	else:
		node = NumberNode.build(str(self_rank), "big_pvp")
	var s: float = minf(1.0, RANK_MAX_W / node.size.x) if node.size.x > 0.0 else 1.0
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(s, s)
	node.position = RANK_POS - node.size * 0.5
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(node)


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
		var sz: Vector2 = arrow.texture.get_size() / CONTENT_SCALE
		arrow.size = sz
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


# 源 :1429-1460 nameBg 左中 @(250+x,67) + 纯名 @(280+x,67)；公会 xoffset=-40。
static func _add_name(board: TextureRect, player_name: String, is_guild: bool, guild_dx: float) -> void:
	var name_bg := TextureRect.new()
	name_bg.texture = load(NAME_BG_RES) as Texture2D
	name_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	name_bg.size = NAME_BG_SIZE
	name_bg.position = NAME_BG_LEFT + Vector2(guild_dx, -NAME_BG_SIZE.y * 0.5)
	name_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(name_bg)
	var name_lbl := Label.new()
	name_lbl.text = player_name
	name_lbl.theme_type_variation = VAR_WHITE_18
	name_lbl.position = NAME_LEFT + Vector2(guild_dx, -12.0)
	name_lbl.size = Vector2(240.0, 24.0)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(name_lbl)


# 源 :1520-1565 tips 行：tipsText ccc3(241,193,113) + 千分位值 ccc3(255,234,198) 右接。
# tipsText 键即行内 record 同键（调用方 TAB_TREE tips_key 语义）；本项目复用
# RanklistOverlayHintLabel（同色 241,193,113）+ RanklistOverlayValueLabel（255,234,198）。
static func _add_tips(board: TextureRect, cm: ConfigManager, rank_type: String, self_param: int, guild_dx: float) -> void:
	var tips_key: String = ""
	match rank_type:
		"pvp_r": tips_key = "RANKLIST.ARENARANKWITHTWODOT"
		"guildliveness": tips_key = "ranklist.1.10.1.003"
		"top_gs": tips_key = "RANKLIST.TOPFIFTEENFIGHTVALUE"
		"full_hero_gs": tips_key = "RANKLIST.ALLHEROFIGHTVALUE"
		"hero_team_gs": tips_key = "RANKLIST.TOPFIVEFIGHTVALUE"
		"hero_evo_star": tips_key = "RANKLIST.HEROALLSTAR"
	if tips_key.is_empty():
		return
	var record := Label.new()
	record.text = cm.get_lstr(tips_key)
	record.theme_type_variation = VAR_HINT
	record.position = TIPS_LEFT + Vector2(guild_dx, -10.0)
	record.size = Vector2(220.0, 20.0)
	record.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	record.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(record)
	var value := Label.new()
	value.text = NumberNode.format_comma(self_param)
	value.theme_type_variation = VAR_VALUE
	value.position = TIPS_LEFT + Vector2(guild_dx + 220.0, -10.0)
	value.size = Vector2(120.0, 20.0)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(value)
