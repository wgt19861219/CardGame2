class_name StoneDetailPanel
extends PopWindow

## 碎片详情面板（View 层）— 照源 ui/stonedetail.lua（702 行）。
## 功能：未拥有英雄点碎片不足时弹此面板，展示 碎片图标 + 英雄名 + 拥有量/需求 +
## 获取途径关卡列表（Drop1-3）+ 返回按钮。
##
## 两件套范式（批 1 Task 2，2026-08-15）：完整静态树进 stone_detail_content.tscn
## （无脚本）+ 获取途径行模板 stone_detail_getway_item.tscn；本文件只做业务、信号
## connect、fill（零静态节点构造，工厂调用除外）。静态色/字号走 theme variation
## （StoneDetail* 系列），动态切换色（红/棕）用 font_color override（源 config.color
## 直设颜色语义，非乘法 modulate）。
## 坐标：源 cocos(800x480 左下) → Godot(800x480 左上)；infoContainer 源 (400,242)
## size(285,388) anchor(0.5,0.5) → 容器左 257.5/底 432（480-48），子节点 local(cx,cy) →
## 全屏 (257.5+cx, 432-cy)。board 行内坐标（逻辑 311x67 y-up）在行模板内已翻转。

signal jump_to_stage(stage_id: int)

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/stone_detail_content.tscn")
const GETWAY_ITEM_SCENE: PackedScene = preload("res://scenes/ui/stone_detail_getway_item.tscn")

# ── 动态切换色（源 ccc3；静态色已进 variation）──
const COLOR_AMOUNT_OK: Color = Color(169.0 / 255.0, 91.0 / 255.0, 28.0 / 255.0)
const COLOR_AMOUNT_LOW: Color = Color(226.0 / 255.0, 18.0 / 255.0, 18.0 / 255.0)
# ── LSTR key（源 LSTR 宏，cm.get_lstr 解析；fallback 同步 zh-CN 值）──
const LSTR_WAY_TITLE: String = "STONEDETAIL.WAY_TO_GET_"
const LSTR_WAY_FALLBACK: String = "获得途径："
const LSTR_NOT_OPEN: String = "STONEDETAIL.NOT_YET_OPEN"
const LSTR_NOT_OPEN_FALLBACK: String = "（未开放）"
const LSTR_EMPTY_DEFAULT: String = "STONEDETAIL.THE_HERO_DEBRIS_WILL_NOT_BE_GAINED_FROM_THIS_CROSS_TEMPORARILY"
const LSTR_EMPTY_FALLBACK: String = "该英雄碎片暂不由关卡掉落"
const LSTR_OK: String = "EQUIPCRAFT.RETURN"
const LSTR_OK_FALLBACK: String = "返回"
const LSTR_ELITE: String = "EQUIPCRAFT.ELITE"
const LSTR_CHAPTER_D: String = "EQUIPCRAFT._CHAPTER__D"
const LSTR_CHAPTER_YET: String = "EQUIPCRAFT.CHAPTER_YET_TO_OPEN"
const LSTR_CHAPTER_YET_FALLBACK: String = "关卡尚未开启。"
# ── infoContainer 全屏原点（源 :514-515 setPosition(400,242) + size(285,388)）──
const ICO_OFFSET_X: float = 257.5   # 容器左 x = 400-285/2（源直译，800 口径）
const ICO_BASE_Y: float = 432.0     # 容器底 Godot y = 480-(242-388/2)
# ── 获取途径行布局（源 :272 ox,oy=142,220 + :286 y-50*(i-1)；行挂 draglist listLayer，
#    listLayer 无偏移 → 行中心即 infoContainer 局部 (142, 220-50i)；GetwayClip 原点
#    = cliprect(0,85) 全屏映射 (257.5,182)【800 口径；tscn 现值 (337.5,262) 系 960 口径
#    Task 4 迁后归位】→ 行中心相对裁剪层 (142, 30+50i) 局部差值不变）──
const GETWAY_OX: float = 142.0
const GETWAY_BASE_Y: float = 30.0
const GETWAY_DY: float = 50.0
const MAX_DROPS: int = 3   # 数据表 Drop 1..3（grep 确认 Drop 4 不存在，同 equipcraft）
# ── 行内动态布局（静态定位已在行模板；board 显示 242.7x52.3 = 311x67 ÷ CS）──
const CS: float = 1.28125
const STAGE_ICON_FIX_H: float = 75.0    # 源 :307 fix_height=75（readnode :201 ss=fix_h/逻辑高，显示高恒 75 点，勿再 ÷CS——2026-08-22 巡检订正）
const BOARD_NAME_MAX_W: float = 160.0 / CS  # 源 :351 max_width=160
const ELITE_GAP: float = 6.0 / CS           # 源 :338 right2 offset=6

var cm: Variant = null
var pd: PlayerData = null
var _hero_mgr: HeroManager = null
var _tid: int = 0
var _stone_id: int = 0
var _content: Control = null            # .tscn 根
var _getway_host: Control = null        # %GetwayClip 裁剪层
var _stone_icon_host: Control = null    # %StoneIconHost 零尺寸点挂点
var _getway_rows: Array = []
var _getway_ids: Array = []


func setup_panel(p_tid: int, p_cm: Variant, p_pd: PlayerData, p_hero_mgr: HeroManager) -> void:
	play_open_sfx = true   # T4：原 register_on_enter 音效样板上收基类
	_tid = p_tid
	cm = p_cm
	pd = p_pd
	_hero_mgr = p_hero_mgr
	_stone_id = ReadheroHandbook.get_stone_id(_tid, cm)
	setup()
	_build_content()
	_fill_stone_icon()
	# 源 :608-615 enter 事件里才 createStoneAmount + refreshGetwayLimit；Godot 的
	# get_combined_minimum_size 需入树后 theme 上下文才准（right2 链依赖文字实宽），
	# 故 amount/getway 的 fill 统一挂 on_enter（入树后回调）。
	register_on_enter(_on_panel_enter)
	# 源 EaseBackOut 0.2s：弹窗缩放入场（P2-10）。
	register_on_enter(play_scale_in)


# 源 enter handler 等价：拥有量/需求（createStoneAmount）+ 获取途径列表（createList）。
func _on_panel_enter() -> void:
	_fill_amount()
	_build_getway_list()


# infoContainer 子节点 cocos local → Godot：cx+257.5, 432-cy（见类头注释推导；800 口径）。
func _g(cx: float, cy: float) -> Vector2:
	return Vector2(cx + ICO_OFFSET_X, ICO_BASE_Y - cy)


# 绑定 .tscn 静态节点 + fill 静态文案（动态数据走各 _fill_*）。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	# name（源 :521-527 text=self:getName() = Unit[tid]["Display Name"]）
	(_content.get_node("%NameLabel") as Label).text = _hero_display_name()
	# way title（源 :161-172 STONEDETAIL.WAY_TO_GET_）
	(_content.get_node("%WayTitleLabel") as Label).text = cm.get_lstr(LSTR_WAY_TITLE) if cm != null else LSTR_WAY_FALLBACK
	# ok 按钮（源 :557-600 Scale9 + ok_label "返回"）— 三态/字号走 variation，fill 文案
	var ok_btn: Button = _content.get_node("%OkBtn") as Button
	ok_btn.text = cm.get_lstr(LSTR_OK) if cm != null else LSTR_OK_FALLBACK
	ok_btn.pressed.connect(_on_ok_pressed)
	# close（源 :535-555 close + close_press 双层 Sprite → .tscn TextureButton 双态）
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(_on_close_pressed)
	_stone_icon_host = _content.get_node("%StoneIconHost") as Control
	_getway_host = _content.get_node("%GetwayClip") as Control


func _hero_display_name() -> String:
	var row: Dictionary = cm.get_raw_table(&"Unit").get(str(_tid), {})
	# Display Name 存 LSTR key（Unit.hero.alias.xxx），get_lstr 本地化
	# （eatexp/fragment_compose 同口径；非 key 文本 get_lstr 原样返回）。
	return cm.get_lstr(String(row.get(&"Display Name", "")))


# 碎片图标（源 createIcon :147-175 readequip.createIcon(sid) at (60,290) 中心锚）：
# 动态品质框挂零尺寸点 host 后负半偏移居中（shop IconHost 同款）。源用 createIcon 非
# createIconWithAmount → 无数量角标（拥有量由下方 "(X/Y)" 行承担，2026-08-22 巡检订正）。
func _fill_stone_icon() -> void:
	var icon: Control = ReadequipIcon.create_icon(_stone_id, 0, cm)
	icon.position = -icon.size * 0.5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stone_icon_host.add_child(icon)


# 拥有量/需求（源 createStoneAmount :82-145）：pre 左锚 (100,275)，amount/need right2
# 右缘相接 → fill 按 right2 链重排 x；不足红/够棕走 font_color override（源直设色）。
func _fill_amount() -> void:
	var amount: int = ReadheroHandbook.get_stone_amount(_tid, cm, _hero_mgr)
	var need: int = ReadheroHandbook.get_stone_need(_tid, cm, _hero_mgr)
	var paren: Label = _content.get_node("%AmountLParen") as Label
	var amt: Label = _content.get_node("%AmountLabel") as Label
	var need_lbl: Label = _content.get_node("%AmountNeedLabel") as Label
	amt.text = str(amount)
	amt.add_theme_color_override("font_color", COLOR_AMOUNT_LOW if amount < need else COLOR_AMOUNT_OK)
	need_lbl.text = "/%d)" % need
	amt.position.x = paren.position.x + paren.get_combined_minimum_size().x
	need_lbl.position.x = amt.position.x + amt.get_combined_minimum_size().x


# 获取途径列表（源 createList :252-372）：Drop1-3 过滤（Chapter<=MaxChapter），行实例
# 挂裁剪层（源 draglist listLayer）；空掉落走 empty prompt（源 createEmptyPrompt）。
func _build_getway_list() -> void:
	_getway_rows.clear()
	_getway_ids.clear()
	var equip_info: Dictionary = cm.get_raw_table(&"Equip").get(str(_stone_id), {})
	var stage_table: Dictionary = cm.get_raw_table(&"Stage")
	var max_chapter: int = int(cm.get_raw_table(&"GameConfig").get("MaxChapter", 13))
	var drops: Array = []
	for i in range(1, MAX_DROPS + 1):
		var s: int = int(equip_info.get("Drop " + str(i), 0))
		if s > 0:
			var st_row: Dictionary = stage_table.get(str(s), {})
			if int(st_row.get("Chapter ID", 0)) <= max_chapter:
				drops.append(s)
	if drops.is_empty():
		_show_empty_prompt(equip_info)
		return
	for i in range(drops.size()):
		_build_one_getway(stage_table, drops[i], i)
		_getway_ids.append(drops[i])


func _show_empty_prompt(equip_info: Dictionary) -> void:
	var lbl: Label = _content.get_node("%EmptyPromptLabel") as Label
	var text_key: String = String(equip_info.get("How To Get", LSTR_EMPTY_DEFAULT))
	lbl.text = cm.get_lstr(text_key) if cm != null else LSTR_EMPTY_FALLBACK
	lbl.visible = true


# 单行获取途径（源 :273-366）：行模板 instantiate + fill；行中心 (142, 30+50*i)
# 相对裁剪层（源 board at (ox, oy-50*(i-1)) 中心锚，换算见类头）。
func _build_one_getway(stage_table: Dictionary, raw_sid: int, idx: int) -> void:
	var is_elite: bool = StageAccount.stage_type(raw_sid) == "elite"
	var sid: int = raw_sid
	if is_elite:
		sid = int(stage_table.get(str(raw_sid), {}).get("Stage Group", raw_sid))
	var stage_row: Dictionary = stage_table.get(str(sid), {})
	var row: Control = GETWAY_ITEM_SCENE.instantiate() as Control
	var center: Vector2 = Vector2(GETWAY_OX, GETWAY_BASE_Y + GETWAY_DY * float(idx))
	row.position = center - row.size * 0.5
	row.gui_input.connect(_make_getway_handler(idx))
	_getway_host.add_child(row)
	# stage 图标（源 :299-308 getStageIcon(id) fix_height=75，中心 (35,25) 已在模板锚定）
	var icon: TextureRect = row.get_node("%StageIcon") as TextureRect
	var icon_path: String = StageRes.get_stage_icon(sid, cm)
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path) as Texture2D
		_fill_stage_icon_size(icon)
	# title（源 :309-324 "第X章" LSTR._CHAPTER__D，静态位 (50.7,中心25) 在模板）
	var title: Label = row.get_node("%TitleLabel") as Label
	title.text = (cm.get_lstr(LSTR_CHAPTER_D) if cm != null else "第%d章") % int(stage_row.get("Chapter ID", 0))
	# elite（源 :325-344 "精英" right2 title offset=6，红字，visible=isElite）
	var elite: Label = row.get_node("%EliteLabel") as Label
	elite.text = cm.get_lstr(LSTR_ELITE) if cm != null else "精英"
	_place_right2(elite, title, ELITE_GAP)
	elite.visible = is_elite
	# name（源 :345-360 Stage Name max_width=160 超宽等比缩，静态位 (53.1,中心42.9) 在模板；
	# Stage Name 存 LSTR key → get_lstr 本地化，stage_select 同口径）
	var name_lbl: Label = row.get_node("%NameLabel") as Label
	name_lbl.text = cm.get_lstr(String(stage_row.get("Stage Name", "")))
	var name_w: float = name_lbl.get_combined_minimum_size().x
	if name_w > BOARD_NAME_MAX_W:
		var sc: float = BOARD_NAME_MAX_W / name_w
		name_lbl.scale = Vector2(sc, sc)
	# 剩余次数（源 refreshGetwayLimit :374-450 limitContainer right2 elite）
	_fill_limit(row, raw_sid, title, elite, is_elite)
	_getway_rows.append(row)


# stage 图标等比 fit 高（源 fix_height=75：scale = 75/contentSize.h，级联 board ÷CS）：
# 显示高恒 58.5，宽按贴图等比；模板 anchor 已定中心 (27.3,32.8)，对称重设 offsets。
func _fill_stage_icon_size(icon: TextureRect) -> void:
	var tex: Vector2 = icon.texture.get_size() / CS
	var w: float = tex.x * (STAGE_ICON_FIX_H / tex.y)
	icon.offset_left = -w * 0.5
	icon.offset_right = w * 0.5
	icon.offset_top = -STAGE_ICON_FIX_H * 0.5
	icon.offset_bottom = STAGE_ICON_FIX_H * 0.5


# right2 布局（源 resource_manager right2：x = 前驱右缘 + offset，y 对齐前驱）。
func _place_right2(node: Label, refer: Label, gap: float) -> void:
	var refer_w: float = refer.get_combined_minimum_size().x * refer.scale.x
	node.position = Vector2(refer.position.x + refer_w + gap, node.position.y)


# 剩余次数/未开放（源 refreshGetwayLimit :374-450）：limitContainer 恒挂 elite 右缘
# （elite 节点源里总创建，仅 visible 切换）；count>0 棕（variation），==0 或未开放红
# （font_color override）；Daily Limit<=0 不建（源 ui=nil → 模板节点保持隐藏）。
func _fill_limit(row: Control, raw_sid: int, title: Label, elite: Label, is_elite: bool) -> void:
	var limit_lbl: Label = row.get_node("%LimitLabel") as Label
	if not _is_stage_open(raw_sid):
		limit_lbl.text = cm.get_lstr(LSTR_NOT_OPEN) if cm != null else LSTR_NOT_OPEN_FALLBACK
		limit_lbl.add_theme_color_override("font_color", COLOR_AMOUNT_LOW)
	else:
		var stage_table: Dictionary = cm.get_raw_table(&"Stage")
		var limit: int = int(stage_table.get(str(raw_sid), {}).get("Daily Limit", 0))
		if limit <= 0:
			return
		var lookup_sid: int = int(stage_table.get(str(raw_sid), {}).get("Stage Group", raw_sid)) if is_elite else raw_sid
		var used: int = int(pd.stage_limit.get(lookup_sid, 0))
		var count: int = maxi(0, limit - used)
		limit_lbl.text = "(%d/%d)" % [count, limit]
		if count <= 0:
			limit_lbl.add_theme_color_override("font_color", COLOR_AMOUNT_LOW)
	_place_right2(limit_lbl, elite, 0.0)
	limit_lbl.visible = true


func _is_stage_open(sid: int) -> bool:
	var star: int = pd.stage_manager.stage_stars(sid)
	var prev: int = pd.stage_manager.stage_stars(sid - 1)
	return star + prev > 0


# 本项目 pushScene 降级为 jump_to_stage 信号（调用方可接 SceneManager；未接时面板内 toast 兜底）。
func _on_get_way_clicked(stage_id: int) -> void:
	var st: String = StageAccount.stage_type(stage_id)
	if st != "normal" and st != "elite":
		return
	if _is_stage_open(stage_id):
		AudioPlayer.play_sfx("common_click_feedback")
		jump_to_stage.emit(stage_id)
		remove_window()
	else:
		_show_toast(cm.get_lstr(LSTR_CHAPTER_YET) if cm != null else LSTR_CHAPTER_YET_FALLBACK)


func _make_getway_handler(idx: int) -> Callable:
	return func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			if idx < _getway_ids.size():
				_on_get_way_clicked(int(_getway_ids[idx]))


func _on_close_pressed() -> void:
	AudioPlayer.play_sfx("common_close_popup_window")
	remove_window()


func _on_ok_pressed() -> void:
	AudioPlayer.play_sfx("common_close_popup_window")
	remove_window()
