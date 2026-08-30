class_name RanklistRows
extends RefCounted

## 排行榜行渲染 helper（View 层纯函数）— 源 ranklist.lua initpvpItemHandler(:574-673) /
## initCommonItemHandler(:775-928) / initglItemHandler(:930-1052) 三套行布局。
## 走查批 C（2026-08-27）像素级补全，撤销头注释披露的四项降级：
## - ranking：前三名裸版 pvp_rank_1st/2nd/3rd.png（HC multilanguage 补源）+ >3 名
##   NumberNode big_pvp 贴图数字（旧 "#N" Label 撤销）；
## - head：TeamHeadIcon（mask 圆裁+恒金框，getTeamHead 等价；旧 Avatar 方图直显撤销）；
##   公会行走 GuildAvatar.Picture 直显（源 readequip.createIcon fres 自定义图，60pt 宽）；
## - level：LevelIcon 等级牌（旧名字合并 "LvN" 撤销）；公会行无等级牌；
## - name：纯名字（源默认白 18 号），公会行布局照源 (200/215,66/68) 独立坐标。
## 行板/patch/尺寸常量自 ranklist_panel 迁入（口径不变）。公会行点击弹 guildsummary
## 未迁移 → 不绑点击（受控裁剪披露）。

const CONTENT_SCALE: float = 1.28125
# 行板（源 initCommonItemHandler :780-793：自己 ranklist_me_bg / 他人 pvp_rank_bg_high）。
const ROW_BOARD_SELF: String = "res://assets/ui/alpha/HVGA/ranklist/ranklist_me_bg.png"
const ROW_BOARD_OTHER: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_bg_high.png"
# 行板九宫格（源 :584 capInsets DG(65,25,545,25) ÷CS 取整；右侧 1/4 固定装饰段）。
const BOARD_PATCH_L: int = 40
const BOARD_PATCH_T: int = 45
const BOARD_PATCH_R: int = 126
const BOARD_PATCH_B: int = 15
# 源 scaleSize DGSizeMake(650,95) = (507.81,74.22) 点。
const BOARD_SIZE: Vector2 = Vector2(507.81, 74.22)
# 行内布局（board 局部，DG×0.78125 + cocos y-up → y=74.22−y_dg）：
# ranking 中心 @(60,50)=(46.88,35.16)；head 中心 @(175,50)=(136.72,35.16)；
# nameBg 左中 @(250,52/67) pvp/common、@(200,66) guild；level 中心 @(250,50/65)；
# name 左中 @(280,52/67)、guild @(215,68)；guild 活跃文案左中 @(215,28)。
const RANKING_CENTER: Vector2 = Vector2(46.88, 35.16)
const HEAD_CENTER: Vector2 = Vector2(136.72, 35.16)
const HEAD_CENTER_GUILD: Vector2 = Vector2(136.72, 36.72)
const HEAD_SIZE_GUILD: float = 60.0
const NAME_BG_LEFT: Vector2 = Vector2(195.31, 33.59)
const NAME_BG_LEFT_COMMON: Vector2 = Vector2(195.31, 21.88)
const NAME_BG_LEFT_GUILD: Vector2 = Vector2(156.25, 22.66)
const LEVEL_CENTER: Vector2 = Vector2(195.31, 35.16)
const LEVEL_CENTER_COMMON: Vector2 = Vector2(195.31, 23.44)
const NAME_LEFT: Vector2 = Vector2(218.75, 33.59)
const NAME_LEFT_COMMON: Vector2 = Vector2(218.75, 21.88)
const NAME_LEFT_GUILD: Vector2 = Vector2(167.97, 21.09)
const LIVENESS_LEFT: Vector2 = Vector2(167.97, 52.34)
const NAME_BG_RES: String = "res://assets/ui/alpha/HVGA/task_name_bg.png"
# nameBg 纹理 422x34px ÷CS。
const NAME_BG_SIZE: Vector2 = Vector2(329.37, 26.54)
# 前三裸版徽章（HC multilanguage/en-US 补源，批 C 2026-08-27）。
const RANK_1ST_RES: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_1st.png"
const RANK_2ND_RES: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_2nd.png"
const RANK_3RD_RES: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_3rd.png"
# record 行（源 :812-905）+ hero_evo_star 星图标（:879-891 detail_star scale 0.5）。
const RECORD_POS: Vector2 = Vector2(187.5, 38.9)
const RECORD_LINE_CENTER_Y: float = 50.9
const STAR_ICON_RES: String = "res://assets/ui/alpha/HVGA/detail_star.png"
const STAR_ICON_SIZE: Vector2 = Vector2(27.31, 27.71)
const VAR_WHITE_18: String = "RanklistWhiteLabel18"
const VAR_RECORD: String = "RanklistRowRecordLabel"


## 行构建（rank=0 为 self 行旧语义已废——self 行由调用方以真实名次入榜）。
## tips_key/with_star 由调用方查 TAB_TREE 传入（common 系 record 行）。
static func make_row(cm: ConfigManager, rank_type: String, tips_key: String, with_star: bool,
		rank: int, row_name: String, level: int, param: int, avatar: int, is_self: bool = false) -> Control:
	var is_guild: bool = rank_type == "guildliveness"
	var is_pvp: bool = rank_type == "pvp" or rank_type == "pvp_r"
	var row := Control.new()
	row.custom_minimum_size = BOARD_SIZE
	var board := NinePatchRect.new()
	board.texture = load(ROW_BOARD_SELF if is_self else ROW_BOARD_OTHER) as Texture2D
	board.patch_margin_left = BOARD_PATCH_L
	board.patch_margin_top = BOARD_PATCH_T
	board.patch_margin_right = BOARD_PATCH_R
	board.patch_margin_bottom = BOARD_PATCH_B
	board.size = BOARD_SIZE
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(board)
	_add_ranking(board, rank)
	if is_guild:
		_add_guild_head(board, cm, avatar)
	else:
		var head := TeamHeadIcon.build(cm, avatar)
		head.position = HEAD_CENTER
		board.add_child(head)
	var name_bg_pos: Vector2 = NAME_BG_LEFT_GUILD if is_guild else (NAME_BG_LEFT if is_pvp else NAME_BG_LEFT_COMMON)
	var name_pos: Vector2 = NAME_LEFT_GUILD if is_guild else (NAME_LEFT if is_pvp else NAME_LEFT_COMMON)
	_add_name(board, row_name, name_bg_pos, name_pos)
	if not is_guild:
		var level_pos: Vector2 = LEVEL_CENTER if is_pvp else LEVEL_CENTER_COMMON
		var level_icon := LevelIcon.build(level)
		level_icon.position = level_pos
		board.add_child(level_icon)
	if not is_pvp:
		_add_record_row(board, cm, tips_key, with_star, param)
	if not is_guild:
		board.set_meta("ranklist_row_click", true)   # 公会行无点击（guildsummary 未迁移披露）
	return row


## ranking：源 :595-604——1/2/3 裸版徽章（行内无缩放），>3 getNumberNode big_pvp。
static func _add_ranking(board: Control, rank: int) -> void:
	var badge_res: String = ""
	match rank:
		1: badge_res = RANK_1ST_RES
		2: badge_res = RANK_2ND_RES
		3: badge_res = RANK_3RD_RES
	if badge_res != "" and ResourceLoader.exists(badge_res):
		var icon := TextureRect.new()
		icon.texture = load(badge_res) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var sz: Vector2 = icon.texture.get_size() / CONTENT_SCALE
		icon.size = sz
		icon.position = RANKING_CENTER - sz * 0.5
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.add_child(icon)
		return
	var num := NumberNode.build(str(rank), "big_pvp")
	num.position = RANKING_CENTER - num.size * 0.5
	board.add_child(num)


## 公会头像：GuildAvatar.Picture 直显等比缩 60pt 宽（源 readequip.createIcon fres 简化披露）。
static func _add_guild_head(board: Control, cm: ConfigManager, avatar: int) -> void:
	var pic: String = String(cm.get_raw_table(&"GuildAvatar").get(str(avatar), {}).get("Picture", ""))
	if pic.is_empty():
		return
	var head_path: String = "res://assets/ui/" + pic.substr(3)
	if not ResourceLoader.exists(head_path):
		return
	var tex: Texture2D = load(head_path)
	var head := TextureRect.new()
	head.texture = tex
	head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var ratio: float = HEAD_SIZE_GUILD / (tex.get_size().x / CONTENT_SCALE) if tex.get_size().x > 0 else 1.0
	var sz: Vector2 = tex.get_size() / CONTENT_SCALE * ratio
	head.size = sz
	head.position = HEAD_CENTER_GUILD - sz * 0.5
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(head)


## nameBg + 名字（纯名，源默认白 18 号）。
static func _add_name(board: Control, row_name: String, bg_left: Vector2, name_left: Vector2) -> void:
	var name_bg := TextureRect.new()
	name_bg.texture = load(NAME_BG_RES) as Texture2D
	name_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	name_bg.size = NAME_BG_SIZE
	name_bg.position = bg_left - Vector2(0.0, NAME_BG_SIZE.y * 0.5)
	name_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(name_bg)
	var name_lbl := Label.new()
	name_lbl.text = row_name
	name_lbl.theme_type_variation = VAR_WHITE_18
	name_lbl.position = name_left - Vector2(0.0, 12.0)
	name_lbl.size = Vector2(240.0, 24.0)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(name_lbl)


## 战力系 record 行（源 :839-905）+ 千分位 value + hero_evo_star 星图标。
static func _add_record_row(board: Control, cm: ConfigManager, tips_key: String, with_star: bool, param: int) -> void:
	if tips_key.is_empty():
		return
	var record := Label.new()
	record.text = cm.get_lstr(tips_key)
	record.theme_type_variation = VAR_RECORD
	record.position = RECORD_POS
	record.size = Vector2(240.0, 24.0)
	record.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	record.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(record)
	var value := Label.new()
	value.text = NumberNode.format_comma(param)
	value.theme_type_variation = VAR_RECORD
	value.position = RECORD_POS
	value.size = Vector2(240.0, 24.0)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(value)
	var star: TextureRect = null
	if with_star:
		star = TextureRect.new()
		star.texture = load(STAR_ICON_RES) as Texture2D
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.size = STAR_ICON_SIZE
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.add_child(star)
	board.ready.connect(_place_record_tail.bind(record, star, value))


## record 右侧精排（源 getRightSidePos(record) + icon anchor(0,0.4)）：
## record 已入树 → get_minimum_size() 解析 variation 18 号字体宽度。
static func _place_record_tail(record: Label, star: TextureRect, value: Label) -> void:
	var value_x: float = RECORD_POS.x + record.get_minimum_size().x
	if star != null:
		star.position = Vector2(value_x, RECORD_LINE_CENTER_Y - STAR_ICON_SIZE.y * 0.4)
		value_x += STAR_ICON_SIZE.x
	value.position = Vector2(value_x, RECORD_POS.y)
