class_name LadderRows
extends RefCounted

## 竞技场排行/记录行渲染 helper（View 层纯函数）— 源 pvp.lua createRankInfo(:1165-1256) /
## createRecordInfo(:1257-1468) / initRankListData(:1833-1850) / initRecordData(:1790-1803) /
## second2hms(:1445-1456)。自 ladder_panel 迁入（走查批 D 2026-08-27 主屏重构拆分，口径不变）。

# 排行行（源 initRankListData :1843-1848）：行高 70（1-10 名）/50（11+ 名），步进 78/58 已含
# +8 间距；底图分档 rankFrameRecource :33-67（1st/2nd/3rd/high/low，setContentSize(475,h)）。
# FIRST_Y 是 host 局部空间首行中心基准 = 源 clip 顶 cocos 400（:1494 cliprect(165,40,470,360)，
# Godot 场景 y=160 即 ScrollContainer 顶）− 首行底图中心 361（bg 290 + rankBg 局部 71）= 39
# （2026-08-18 审查 Critical：旧值 199=560-361 是场景空间值，host y=0 对应场景 160 不可混用）。
const RANK_ROW_W: float = 475.0
const RANK_ROW_H_HIGH: float = 70.0
const RANK_ROW_H_LOW: float = 50.0
const RANK_ROW_GAP: float = 8.0
const RANK_ROW_STEP_HIGH: float = 78.0
const RANK_ROW_STEP_LOW: float = 58.0
const RANK_ROW_FIRST_Y: float = 39.0
const RANK_ROW_TEX_1ST: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_bg_1st.png"
const RANK_ROW_TEX_2ND: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_bg_2nd.png"
const RANK_ROW_TEX_3RD: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_bg_3rd.png"
const RANK_ROW_TEX_HIGH: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_bg_high.png"
const RANK_ROW_TEX_LOW: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_bg_low.png"
# 排行行内（相对 475xh 底图中心，源 createRankInfo :1173-1207 相对 bg 点坐标减底图中心 (150,71)：
# rank(-200,+11)/iconParent(-110,0)，cocos y 向上 → Godot y 取反）：名次/名字 Label 中心锚定照源
# （源 rank Label anchor(0.5,0.5) 中心锚定）；头像组件 getWholeHeadIcon 缺 → "名字 LvN" Label
# 居中占 iconParent 位（ranklist 先例降级披露）。
const RANK_ROW_RANK_DX: float = -200.0
const RANK_ROW_RANK_DY: float = -11.0
const RANK_ROW_NAME_DX: float = -110.0
const RANK_ROW_NAME_DY: float = 0.0
const RANK_RANK_LBL_W: float = 60.0
const RANK_NAME_LBL_W: float = 320.0
const RANK_ROW_LBL_H: float = 24.0
# 记录行（源 initRecordData :1801-1802）：行步进 78、内容高 78n+20；highlight 底图
# scaleSize=CCSizeMake(485,70)（:1271-1280 点值直译，2026-08-18 审查 Important：旧值
# 498.1x75.7 误按"无 scaleSize 原尺寸直译"算，与源矛盾）；FIRST_Y 基准 39 同 RANK 侧
# （源首行底图中心同为 cocos 361）；行内子相对底图中心点值直译（源相对 bg 点坐标减底图中心
# (150,71)：resultEffect(-220,+15)/name(-25,+11)/time(-60,-16)/record(-180,-16)，:1300-1360，
# cocos y 向上 → Godot y 取反成 DY -15/-11/+16/+16）；源 name 宽>140 setScale 压缩未迁移（披露）。
const REC_ROW_W: float = 485.0
const REC_ROW_H: float = 70.0
const REC_ROW_STEP: float = 78.0
const REC_ROW_FIRST_Y: float = 39.0
const REC_ROW_TAIL: float = 20.0
const REC_ROW_TEX: String = "res://assets/ui/alpha/HVGA/pvp/pvp_rank_bg_high.png"
const REC_WIN_TEX: String = "res://assets/ui/alpha/HVGA/pvp/pvp_win.png"
const REC_LOSE_TEX: String = "res://assets/ui/alpha/HVGA/pvp/pvp_lose.png"
const REC_ICON_W: float = 29.7
const REC_ICON_H: float = 49.2
const REC_RESULT_DX: float = -220.0
const REC_RESULT_DY: float = -15.0
const REC_NAME_DX: float = -25.0
const REC_NAME_DY: float = -11.0
const REC_TIME_DX: float = -60.0
const REC_TIME_DY: float = 16.0
const REC_RANK_DX: float = -180.0
const REC_LBL_H: float = 24.0
# 榜单/记录 host 内容宽（ScrollContainer 裁剪语义，host 只需撑内容高）。
const RANK_CLIP_W: float = 470.0
const REC_CLIP_W: float = 490.0
# 相对时间阈值（秒，源 :1445-1456 second2hms 分档）。
const SEC_PER_MINUTE: int = 60
const SEC_PER_HOUR: int = 3600
const SEC_PER_DAY: int = 86400


# 行 y（源 initRankListData :1843-1847 公式直译）：源 cocos y 向上
# y = 290 - adjust - 78*(min(10,i)-1) - 58*max(0,i-10)（i 增 y 减 = 行向下，第 1 名最上；i>10 时
# adjust=8），转 Godot y 向下 → 首行中心 39 + step 单调递增。基准 39 是 host（ScrollContainer
# 内容）局部空间值 = 源 clip 顶 cocos 400 − 首行底图中心 361（2026-08-18 审查 Critical：旧实现
# 199-step 方向反 + 199=560-(290+71) 是场景空间值误塞 host 局部，双重修正）。
static func rank_row_y(i: int) -> float:
	var step: float = RANK_ROW_STEP_HIGH * float(mini(10, i) - 1) + RANK_ROW_STEP_LOW * float(maxi(0, i - 10))
	if i > 10:
		step += RANK_ROW_GAP
	return RANK_ROW_FIRST_Y + step - rank_row_h(i) * 0.5


static func rank_row_h(rank_num: int) -> float:
	return RANK_ROW_H_HIGH if rank_num <= 10 else RANK_ROW_H_LOW


# 榜单总高（源 :1848 totalHeight 直译，无 adjust 项——adjust 只进各行 y 不进总高）。
static func rank_total_height(count: int) -> float:
	return RANK_ROW_STEP_HIGH * float(mini(10, count)) + RANK_ROW_STEP_LOW * float(maxi(0, count - 10))


# 排行行（源 createRankInfo :1165-1256）：rankBg 分档底图 475xh + 名次白 20 + 名字白 20
# （源 getWholeHeadIcon 头像组件缺 → "名字 LvN" Label 降级，ranklist 先例披露；
# 1st/2nd/3rd 名次图 HC 有存量但 ranklist 面板同降级，一致性不拷）。
static func make_rank_row(rank_num: int, label_text: String) -> Control:
	var h: float = rank_row_h(rank_num)
	var tex_path: String = RANK_ROW_TEX_HIGH
	if rank_num == 1:
		tex_path = RANK_ROW_TEX_1ST
	elif rank_num == 2:
		tex_path = RANK_ROW_TEX_2ND
	elif rank_num == 3:
		tex_path = RANK_ROW_TEX_3RD
	elif rank_num > 10:
		tex_path = RANK_ROW_TEX_LOW
	var row := Control.new()
	row.size = Vector2(RANK_ROW_W, h)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := TextureRect.new()
	bg.name = "RankBg"
	bg.texture = load(tex_path) as Texture2D
	bg.size = Vector2(RANK_ROW_W, h)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bg)
	var cx: float = RANK_ROW_W * 0.5
	var cy: float = h * 0.5
	var rank_lbl := Label.new()
	rank_lbl.text = "#%d" % rank_num
	rank_lbl.theme_type_variation = "LadderWhiteLabel20"
	rank_lbl.position = Vector2(cx + RANK_ROW_RANK_DX - RANK_RANK_LBL_W * 0.5, cy + RANK_ROW_RANK_DY - RANK_ROW_LBL_H * 0.5)
	rank_lbl.size = Vector2(RANK_RANK_LBL_W, RANK_ROW_LBL_H)
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(rank_lbl)
	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.theme_type_variation = "LadderWhiteLabel20"
	name_lbl.position = Vector2(cx + RANK_ROW_NAME_DX - RANK_NAME_LBL_W * 0.5, cy + RANK_ROW_NAME_DY - RANK_ROW_LBL_H * 0.5)
	name_lbl.size = Vector2(RANK_NAME_LBL_W, RANK_ROW_LBL_H)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(name_lbl)
	return row


# 记录行：底图 highlight（源 :1271-1280）+ 胜负图（:1425-1432 pvp_win/lose）+ 名字/时间/
# 排名（行内相对底图中心直译）。源 _deta_rank/review/share 依赖 _replay_id 与对手 summary
# 数据（本项目 records 仅 {result,time,rank}）→ 显当前排名、胜负字降级、review/share 不建（披露）。
static func make_record_row(rec: Dictionary, idx: int, cm: ConfigManager) -> Control:
	var row := Control.new()
	row.size = Vector2(REC_ROW_W, REC_ROW_H)
	row.position.y = REC_ROW_FIRST_Y + REC_ROW_STEP * float(idx) - REC_ROW_H * 0.5
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := TextureRect.new()
	bg.name = "RecBg"
	bg.texture = load(REC_ROW_TEX) as Texture2D
	bg.size = row.size
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bg)
	var cx: float = REC_ROW_W * 0.5
	var cy: float = REC_ROW_H * 0.5
	var victory: bool = str(rec.get("result", "")) == "victory"
	var result_icon := TextureRect.new()
	result_icon.name = "ResultIcon"
	result_icon.texture = load(REC_WIN_TEX if victory else REC_LOSE_TEX) as Texture2D
	result_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result_icon.size = Vector2(REC_ICON_W, REC_ICON_H)
	result_icon.position = Vector2(cx + REC_RESULT_DX - REC_ICON_W * 0.5, cy + REC_RESULT_DY - REC_ICON_H * 0.5)
	result_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(result_icon)
	var name_lbl := Label.new()
	name_lbl.name = "NameLbl"
	name_lbl.text = "胜利" if victory else "失败"
	name_lbl.theme_type_variation = "LadderWhiteShadowLabel20"
	name_lbl.position = Vector2(cx + REC_NAME_DX, cy + REC_NAME_DY - REC_LBL_H * 0.5)
	name_lbl.size = Vector2(140.0, REC_LBL_H)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(name_lbl)
	var time_lbl := Label.new()
	time_lbl.name = "TimeLbl"
	time_lbl.text = relative_time(int(rec.get("time", 0)), cm)
	time_lbl.theme_type_variation = "LadderTimeLabel20"
	time_lbl.position = Vector2(cx + REC_TIME_DX, cy + REC_TIME_DY - REC_LBL_H * 0.5)
	time_lbl.size = Vector2(200.0, REC_LBL_H)
	time_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(time_lbl)
	var rank_lbl := Label.new()
	rank_lbl.text = "%s%d" % [cm.get_lstr("PVP.RANK_"), int(rec.get("rank", 0))]
	rank_lbl.theme_type_variation = "LadderOrangeLabel20"
	rank_lbl.position = Vector2(cx + REC_RANK_DX, cy + REC_TIME_DY - REC_LBL_H * 0.5)
	rank_lbl.size = Vector2(120.0, REC_LBL_H)
	rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(rank_lbl)
	return row


# 相对时间（源 :1445-1456 second2hms：>=24h 1天前 / >=1h N小时前 / >=1m N分钟前 / N秒前）。
static func relative_time(unix_time: int, cm: ConfigManager) -> String:
	var elapsed: int = maxi(0, int(Time.get_unix_time_from_system()) - unix_time)
	if elapsed >= SEC_PER_DAY:
		return cm.get_lstr("PVP.1_DAY_AGO")
	if elapsed >= SEC_PER_HOUR:
		return cm.get_lstr("PVP._D_HOURS_AGO") % [elapsed / SEC_PER_HOUR]
	if elapsed >= SEC_PER_MINUTE:
		return cm.get_lstr("PVP._D_MINUTES_AGO") % [elapsed / SEC_PER_MINUTE]
	return cm.get_lstr("PVP._D_SECONDS_AGO") % [elapsed]
