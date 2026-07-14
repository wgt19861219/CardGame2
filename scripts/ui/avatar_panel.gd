class_name AvatarPanel
extends PopWindow

## 头像选择面板（View 层）— 照源 selectwindow/ofavatar.lua 重建。
## 源 selectwindow.base：main_vit_tips 框 530×375 + draglist + btRegisterOutClick（点框外 destroy，无 close 按钮）。
## ofavatar：3 类（free/hero/worldcup）分组 + 标题 + 5 列图标网格（hero_icon_frame_1 + Picture）+
## 解锁判断（Requirement Type nil/HeroRank/PlayerLevel）+ 点选 set_avatar → destroy。

const FRAME_RES: String = "res://assets/ui/alpha/HVGA/main_vit_tips.png"
const FRAME_CAP: Rect2 = Rect2(10.0, 10.0, 58.0, 26.0)        # 源 base.lua:60 CCRectMake(10,10,58,26)
const FRAME_SIZE: Vector2 = Vector2(530.0, 375.0)             # 源 scaleSize 530×375
const FRAME_CENTER: Vector2 = Vector2(400.0, 240.0)           # 源 ccp(400,240) 中心
const ICON_FRAME_RES: String = "res://assets/ui/alpha/HVGA/hero_icon_frame_1.png"
const TITLE_BG_RES: String = "res://assets/ui/alpha/HVGA/detail_title_bg.png"
const TITLE_BG_CAP: Rect2 = Rect2(100.0, 0.0, 304.0, 12.0)    # 源 ofavatar:112 CCRectMake(100,0,304,12)
const SCROLL_POS: Vector2 = Vector2(154.0, 60.0)              # 源 base.lua:8 cliprect (154,60,492,365)
const SCROLL_SIZE: Vector2 = Vector2(492.0, 365.0)
const GRID_COLS: int = 5                                      # 源 ofavatar:147 (i-1)%5
const ICON_PAD: float = 10.0                                 # 源 ofavatar:179 fixNodeSize 框-10
const TITLE_BG_W: float = 300.0                              # 源 ofavatar:113 ContentSize 300
# 源 ofavatar:117 标题 Label ccc3(231,206,19)。
const TITLE_COLOR: Color = Color(0.906, 0.808, 0.075)
const HERO_PIC_PREFIX: String = "res://assets/ui/HERO/"       # 源 "UI/HERO/" → 本项目 res://assets/ui/HERO/

var _pd: PlayerData
var _cm: ConfigManager


# 源 cocos(800×480 左下) → Godot(960×640 左上):cx+80, 560-cy（同 battle_view_coords 标准）。
# Phase 4 早期直接用源值漏转，2026-07-14 补 to_godot。
func _g(pos: Vector2) -> Vector2:
	return BattleViewCoords.to_godot(pos.x, pos.y)


func setup_panel(p_pd: PlayerData, p_cm: ConfigManager) -> void:
	_pd = p_pd
	_cm = p_cm
	setup()
	_build_ui()


func _build_ui() -> void:
	# 源 base.lua:75 btRegisterOutClick：点框外 destroy（无 close 按钮）。
	shade_layer.gui_input.connect(_on_shade_input)
	# 源 base.lua:54 窗口框 main_vit_tips Scale9 530×375 @ ccp(400,240) anchor 0.5,0.5。
	var frame := NinePatchRect.new()
	var frame_tex: Texture2D = load(FRAME_RES)
	frame.texture = frame_tex
	frame.patch_margin_left = int(FRAME_CAP.position.x)
	frame.patch_margin_top = int(FRAME_CAP.position.y)
	if frame_tex != null:
		frame.patch_margin_right = int(frame_tex.get_width() - FRAME_CAP.position.x - FRAME_CAP.size.x)
		frame.patch_margin_bottom = int(frame_tex.get_height() - FRAME_CAP.position.y - FRAME_CAP.size.y)
	frame.size = FRAME_SIZE
	frame.position = _g(FRAME_CENTER) - FRAME_SIZE * 0.5
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(frame)
	# draglist 等价：ScrollContainer cliprect (154,60,492,365)。
	var sc := ScrollContainer.new()
	sc.position = _g(SCROLL_POS)
	sc.size = SCROLL_SIZE
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	container.add_child(sc)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	sc.add_child(vbox)
	# 源 ofavatar:initListData 分类 free/hero/worldcup + 解锁过滤。
	var groups: Dictionary = _build_groups()
	for type_key in ["free", "hero", "worldcup"]:
		if groups.has(type_key) and not (groups[type_key] as Array).is_empty():
			vbox.add_child(_make_title(_type_title(type_key)))
			var grid := GridContainer.new()
			grid.columns = GRID_COLS
			grid.add_theme_constant_override("h_separation", 8)
			grid.add_theme_constant_override("v_separation", 8)
			for entry in groups[type_key]:
				grid.add_child(_make_cell(int(entry["key"]), String(entry["res"])))
			vbox.add_child(grid)


# 源 ofavatar:39 initListData：按 Act Type/Requirement Type 分类 + 解锁过滤。
func _build_groups() -> Dictionary:
	var list: Dictionary = {"free": [], "hero": [], "worldcup": []}
	var raw: Dictionary = _cm.get_raw_table("Avatar")
	for tid_str in raw:
		var row: Dictionary = raw[tid_str]
		var act_type: String = String(row.get("Act Type", ""))
		var req_type: String = String(row.get("Requirement Type", ""))
		var pic: String = String(row.get("Picture", ""))
		# 源 ofavatar:47 Act Type==WorldCup → worldcup / HeroRank → hero / nil/PlayerLevel → free。
		var type_key: String = ""
		if act_type == "WorldCup":
			type_key = "worldcup"
		elif req_type == "HeroRank":
			type_key = "hero"
		elif req_type == "PlayerLevel" or req_type == "":
			type_key = "free"
		else:
			# HeroAwake/HaveItem 源 ofavatar 不加入 list。
			continue
		if not _is_unlocked(row, req_type):
			continue
		if pic == "":
			continue
		(list[type_key] as Array).append({"key": int(row.get("Avatar ID", 0)), "res": _to_res_path(pic)})
	return list


# 源 ofavatar:60-88 解锁判断：nil 直接 / HeroRank（hero rank>=target）/ PlayerLevel（玩家等级>=target）。
func _is_unlocked(row: Dictionary, req_type: String) -> bool:
	if req_type == "":
		return true
	if req_type == "PlayerLevel":
		return _pd.team_level >= int(row.get("Requirement Target", 0))
	if req_type == "HeroRank":
		var hero: HeroInstance = _pd.hero_manager.find_hero_by_tid(int(row.get("Requirement ID", 0)))
		return hero != null and hero.rank >= int(row.get("Requirement Target", 0))
	return false


func _to_res_path(pic: String) -> String:
	# 源 "UI/HERO/Coco.jpg" → 本项目 "res://assets/ui/HERO/Coco.jpg"。
	return HERO_PIC_PREFIX + pic.get_file()


# 源 ofavatar:9 type_title：worldcup/free/hero 标题（LSTR）。
func _type_title(type_key: String) -> String:
	match type_key:
		"free":
			return "基础头像"
		"hero":
			return "英雄头像"
		"worldcup":
			return "世界杯头像"
	return ""


# 源 ofavatar:109 createSubhead：detail_title_bg Scale9 300×12 + Label ccc3(231,206,19) size 18。
func _make_title(text: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(TITLE_BG_W, 20.0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := NinePatchRect.new()
	var bg_tex: Texture2D = load(TITLE_BG_RES)
	bg.texture = bg_tex
	bg.patch_margin_left = int(TITLE_BG_CAP.position.x)
	bg.patch_margin_top = int(TITLE_BG_CAP.position.y)
	if bg_tex != null:
		bg.patch_margin_right = int(bg_tex.get_width() - TITLE_BG_CAP.position.x - TITLE_BG_CAP.size.x)
		bg.patch_margin_bottom = int(bg_tex.get_height() - TITLE_BG_CAP.position.y - TITLE_BG_CAP.size.y)
	bg.size = Vector2(TITLE_BG_W, 12.0)
	bg.position = Vector2(0.0, 4.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bg)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", TITLE_COLOR)
	lbl.position = Vector2(0.0, 0.0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(lbl)
	return holder


# 源 ofavatar:153 createIcon：hero_icon_frame_1 框 + Picture 图（fixNodeSize 框-10）+ 点击 set_avatar。
func _make_cell(aid: int, picture_res: String) -> Control:
	var btn := TextureButton.new()
	var frame_tex: Texture2D = load(ICON_FRAME_RES)
	btn.texture_normal = frame_tex
	btn.ignore_texture_size = true
	if frame_tex != null:
		btn.size = frame_tex.get_size()
		btn.custom_minimum_size = frame_tex.get_size()
	btn.pressed.connect(_on_avatar_selected.bind(aid))
	if ResourceLoader.exists(picture_res):
		var icon := TextureRect.new()
		icon.texture = load(picture_res)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size = btn.size - Vector2(ICON_PAD, ICON_PAD)
		icon.position = Vector2(ICON_PAD * 0.5, ICON_PAD * 0.5)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)
	return btn


# 源 base.lua:75 btRegisterOutClick：点框外区域 destroy。
func _on_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			remove_window()


# 源 ofavatar:258 doSendSet → set_avatar → doSetAvatarReply destroy。
func _on_avatar_selected(aid: int) -> void:
	_pd.set_avatar(aid)
	Toast.show_message("头像已设置")
	remove_window()
