class_name AvatarPanel
extends PopWindow

## 头像选择面板（View 层）— 照源 selectwindow/ofavatar.lua 重建。
## 源 selectwindow.base：main_vit_tips 框 530×375 + draglist + btRegisterOutClick（点框外 destroy，无 close 按钮）。
## ofavatar：3 类（free/hero/worldcup）分组 + 标题 + 5 列图标网格（hero_icon_frame_1 + Picture）+
## 解锁判断（Requirement Type nil/HeroRank/PlayerLevel）+ 点选 set_avatar → destroy。
##
## 重构（2026-07-18，hero_detail 范式）：chrome（frame + draglist 容器）静态化进
## scenes/ui/avatar_content.tscn（位置/size 编辑器可视化调）；分类标题 + 头像网格数量随解锁项变，
## 保留 procedural 挂 %AvatarList。源 cocos(800×480 左下) → Godot(960×640 左上)：(cx+80, 560-cy)，
## 纹理显示=纹理/CS（源 hello.lua:311 setContentScaleFactor(615/480)=1.28125，无 fix 时）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/avatar_content.tscn")
const CONTENT_SCALE: float = 1.28125   # 源 hello.lua:311 setContentScaleFactor(1.28125)，cocos sprite 显示=纹理/CS（无 fix 时）
const ICON_FRAME_RES: String = "res://assets/ui/alpha/HVGA/hero_icon_frame_1.png"
const TITLE_BG_RES: String = "res://assets/ui/alpha/HVGA/detail_title_bg.png"
const TITLE_BG_CAP: Rect2 = Rect2(100.0, 0.0, 304.0, 12.0)    # 源 ofavatar:112 CCRectMake(100,0,304,12)
const GRID_COLS: int = 5                                      # 源 ofavatar:147 (i-1)%5
const ICON_PAD: float = 10.0                                 # 源 ofavatar:179 fixNodeSize 框-10
const TITLE_BG_W: float = 300.0                              # 源 ofavatar:113 ContentSize 300
# 源 ofavatar:117 标题 Label ccc3(231,206,19)。
const TITLE_COLOR: Color = Color(0.906, 0.808, 0.075)
const HERO_PIC_PREFIX: String = "res://assets/ui/HERO/"       # 源 "UI/HERO/" → 本项目 res://assets/ui/HERO/

var _pd: PlayerData
var _cm: ConfigManager
var _list: VBoxContainer = null   # .tscn %AvatarList（分类标题 + 头像网格容器）


func setup_panel(p_pd: PlayerData, p_cm: ConfigManager) -> void:
	_pd = p_pd
	_cm = p_cm
	setup()
	_build_ui()


# 建 UI 内容：chrome 静态节点从 .tscn instantiate（位置/size 可视化）；分类标题 + 头像网格 procedural 挂 %AvatarList。
# 源 base.lua:54 main_vit_tips Scale9 530×375 @ ccp(400,240) + base.lua:8 cliprect (154,60,492,365)。
# 源 base.lua:75 btRegisterOutClick：点框外 destroy（无 close 按钮）。
func _build_ui() -> void:
	shade_layer.gui_input.connect(_on_shade_input)
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	_list = content.get_node("%AvatarList") as VBoxContainer
	# 源 ofavatar:initListData 分类 free/hero/worldcup + 解锁过滤。
	var groups: Dictionary = _build_groups()
	for type_key in ["free", "hero", "worldcup"]:
		if groups.has(type_key) and not (groups[type_key] as Array).is_empty():
			_list.add_child(_make_title(_type_title(type_key)))
			var grid := GridContainer.new()
			grid.columns = GRID_COLS
			grid.add_theme_constant_override("h_separation", 8)
			grid.add_theme_constant_override("v_separation", 8)
			for entry in groups[type_key]:
				grid.add_child(_make_cell(int(entry["key"]), String(entry["res"])))
			_list.add_child(grid)


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
		# 源 ofavatar:173 frame ed.createSprite 无 fix → 显示=纹理×CS/CS（ed.createSprite setScale(ContentScale)，此前漏乘 ContentScale）
		var frame_size: Vector2 = TexDisplaySize.display_size(ICON_FRAME_RES)
		btn.size = frame_size
		btn.custom_minimum_size = frame_size
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
