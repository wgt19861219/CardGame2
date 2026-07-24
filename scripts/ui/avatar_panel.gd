class_name AvatarPanel
extends PopWindow

## 头像选择面板（View 层）。
## 3 类（free/hero/worldcup）分组 + 标题 + 5 列图标网格 + 解锁判断 + 点选 set_avatar → destroy。
## 点框外区域 destroy（无 close 按钮）。
##
## 重构（2026-07-18 chrome 静态化 / 2026-07-24 UI 重构试点）：
## - chrome（frame + draglist 容器）静态化进 scenes/ui/avatar_content.tscn（位置/size 编辑器可视化调）
## - 分类标题 + 头像网格数量随解锁项变，保留 procedural 挂 %AvatarList（容器管理动态项，P1）
## - add_theme override 归零（GridContainer 间距走 default_theme.tres；仅保留标题色 1 处受控 override，
##   引用 UIConstants.COLOR_TITLE_GOLD，子类型 variation 留批次 1 统一决策）
## - 信号全代码 connect（P2 默认规则）
## cocos(800×480 左下) → Godot(960×640 左上)：(cx+80, 560-cy)，纹理显示=纹理/CS（CONTENT_SCALE=1.28125）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/avatar_content.tscn")
# cocos sprite 显示=纹理/CS（无 fix 时），CS=setContentScaleFactor(615/480)=1.28125。
const CONTENT_SCALE: float = 1.28125
const ICON_FRAME_RES: String = "res://assets/ui/alpha/HVGA/hero_icon_frame_1.png"
const TITLE_BG_RES: String = "res://assets/ui/alpha/HVGA/detail_title_bg.png"
# NinePatch 九宫格中心区（detail_title_bg.png 的可拉伸矩形）。
const TITLE_BG_CAP: Rect2 = Rect2(100.0, 0.0, 304.0, 12.0)
const GRID_COLS: int = 5
# icon 内边距：fixNodeSize 框-10（Picture 比 frame 内缩 5px 两侧）。
const ICON_PAD: float = 10.0
const TITLE_BG_W: float = 300.0
const HERO_PIC_PREFIX: String = "res://assets/ui/HERO/"

var _pd: PlayerData
var _cm: ConfigManager
var _list: VBoxContainer = null   # .tscn %AvatarList（分类标题 + 头像网格容器）


func setup_panel(p_pd: PlayerData, p_cm: ConfigManager) -> void:
	_pd = p_pd
	_cm = p_cm
	setup()
	_build_ui()


# 建 UI 内容：chrome 静态节点从 .tscn instantiate（位置/size 可视化）；分类标题 + 头像网格 procedural 挂 %AvatarList。
# GridContainer 间距走 default_theme.tres（h/v_separation=8），不在此 override。
func _build_ui() -> void:
	shade_layer.gui_input.connect(_on_shade_input)
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	_list = content.get_node("%AvatarList") as VBoxContainer
	# 分类 free/hero/worldcup + 解锁过滤。
	var groups: Dictionary = _build_groups()
	for type_key in ["free", "hero", "worldcup"]:
		if groups.has(type_key) and not (groups[type_key] as Array).is_empty():
			_list.add_child(_make_title(_type_title(type_key)))
			var grid := GridContainer.new()
			grid.columns = GRID_COLS
			for entry in groups[type_key]:
				grid.add_child(_make_cell(int(entry["key"]), String(entry["res"])))
			_list.add_child(grid)


# 按 Act Type/Requirement Type 分类 + 解锁过滤。
func _build_groups() -> Dictionary:
	var list: Dictionary = {"free": [], "hero": [], "worldcup": []}
	var raw: Dictionary = _cm.get_raw_table("Avatar")
	for tid_str in raw:
		var row: Dictionary = raw[tid_str]
		var act_type: String = String(row.get("Act Type", ""))
		var req_type: String = String(row.get("Requirement Type", ""))
		var pic: String = String(row.get("Picture", ""))
		# Act Type==WorldCup → worldcup / HeroRank → hero / nil/PlayerLevel → free。
		var type_key: String = ""
		if act_type == "WorldCup":
			type_key = "worldcup"
		elif req_type == "HeroRank":
			type_key = "hero"
		elif req_type == "PlayerLevel" or req_type == "":
			type_key = "free"
		else:
			# HeroAwake/HaveItem 不加入 list。
			continue
		if not _is_unlocked(row, req_type):
			continue
		if pic == "":
			continue
		(list[type_key] as Array).append({"key": int(row.get("Avatar ID", 0)), "res": _to_res_path(pic)})
	return list


# 解锁判断：nil 直接 / HeroRank（hero rank>=target）/ PlayerLevel（玩家等级>=target）。
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
	# "UI/HERO/Coco.jpg" → 本项目 "res://assets/ui/HERO/Coco.jpg"（只取文件名挂本项目前缀）。
	return HERO_PIC_PREFIX + pic.get_file()


# 分类标题文案。
func _type_title(type_key: String) -> String:
	match type_key:
		"free":
			return "基础头像"
		"hero":
			return "英雄头像"
		"worldcup":
			return "世界杯头像"
	return ""


# 创建分类标题：detail_title_bg Scale9 300×12 + Label（标题金）。
# 标题色用 UIConstants.COLOR_TITLE_GOLD override（与全局 Label 白不同；子类型 variation 留批次 1 统一）。
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
	# 受控 override：标题金色与全局 Label 白不同，留至批次 1 统一 variation 决策。
	lbl.add_theme_color_override("font_color", UIConstants.COLOR_TITLE_GOLD)
	lbl.position = Vector2(0.0, 0.0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(lbl)
	return holder


# 创建头像单元：hero_icon_frame_1 框 + Picture 图（fixNodeSize 框-10）+ 点击 set_avatar。
func _make_cell(aid: int, picture_res: String) -> Control:
	var btn := TextureButton.new()
	var frame_tex: Texture2D = load(ICON_FRAME_RES)
	btn.texture_normal = frame_tex
	btn.ignore_texture_size = true
	if frame_tex != null:
		# frame ed.createSprite 无 fix → 显示=纹理×CS/CS（setScale(ContentScale)，此前漏乘 ContentScale）。
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


# 点框外区域 destroy（btRegisterOutClick 范式：无 close 按钮）。
func _on_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			remove_window()


# 点选 set_avatar → destroy。
func _on_avatar_selected(aid: int) -> void:
	_pd.set_avatar(aid)
	Toast.show_message("头像已设置")
	remove_window()
