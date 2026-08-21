class_name AvatarPanel
extends PopWindow

## 头像选择面板（View 层）。
## 3 类（free/hero/worldcup）分组 + 标题 + 5 列图标网格 + 解锁判断 + 点选 set_avatar → destroy。
## 点框外区域 destroy（无 close 按钮，PopWindow shade 点击关闭基类等价源 btRegisterOutClick）。
##
## 完整树化（批 4 Task 3，2026-08-17；2026-07-18 chrome 静态化 → 完整两件套）：
## - chrome 静态：frame + 裁剪滚动层进 avatar_content.tscn；滚动条贴图 fill 期
##   override（引擎缺口例外）
## - 分类标题行走行模板 avatar_title_item.tscn（数量随解锁变 1-3 个，fill 只填文案）
## - 头像网格 procedural 保留挂 %AvatarList，间距走 AvatarGrid variation（源步进换算）
## - 标题金/解锁提示同款 18 号色走 AvatarTitleLabel variation（受控 override 退役）
## - 照源补 free 组末尾解锁提示（ofavatar.lua:123-128 createUnlockPrompt，此前漏译）
## - 标题文案走 LSTR（源 type_title；worldcup"球队头像"此前硬编码"世界杯头像"不符）
## - icon 显示 106/CS=82.73 手算（批 4 口径：无 TextureConfig 条目散图 ÷CS，勿调 tex_display_size）
## cocos(800×480 左下) → Godot(960×640 左上)：(cx+80, 560-cy)，CS=1.28125。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/avatar_content.tscn")
const TITLE_ITEM_SCENE: PackedScene = preload("res://scenes/ui/avatar_title_item.tscn")
const ICON_FRAME_RES: String = "res://assets/ui/alpha/HVGA/hero_icon_frame_1.png"
const SCROLL_TRACK_RES: String = "res://assets/ui/alpha/HVGA/scroll_bar_bg.png"
const SCROLL_GRABBER_RES: String = "res://assets/ui/alpha/HVGA/scroll_bar.png"
const GRID_COLS: int = 5
# icon 内边距：fixNodeSize 框-10（Picture 比 frame 内缩 5px 两侧）。
const ICON_PAD: float = 10.0
# hero_icon_frame_1 106×106 / CS = 82.73（无 TextureConfig 条目，÷CS 轨道手算）。
const ICON_FRAME_DISPLAY: Vector2 = Vector2(82.73, 82.73)
const HERO_PIC_PREFIX: String = "res://assets/ui/HERO/"
# 分类标题 LSTR 键（ofavatar.lua type_title :9-13；type_priority :4-8 顺序 free/hero/worldcup）。
const LSTR_TITLE_KEYS: Dictionary = {
	"free": "HEROSELECT.BASIC_AVATAR",
	"hero": "HEROSELECT.HERO_AVATAR",
	"worldcup": "ofavatar.1.10.1.001",
}
# free 组末尾解锁提示（:124 T(LSTR(...))）。
const LSTR_TIPS_KEY: String = "HEROSELECT.TIPS__HERO_ADVANCED_TO_PURPLE_CAN_BE_SET_TO_AVATAR"

var _pd: PlayerData
var _cm: ConfigManager
var _content: Control = null
var _list: VBoxContainer = null   # .tscn %AvatarList（标题行/网格/提示 procedural 挂载）


func setup_panel(p_pd: PlayerData, p_cm: ConfigManager) -> void:
	_pd = p_pd
	_cm = p_cm
	setup()
	_build_ui()


# 建 UI：chrome 从 .tscn instantiate；分类标题行（行模板）+ 头像网格（procedural）
# + free 组末尾解锁提示，按解锁分组挂 %AvatarList（源 createIconList :205-214 +
# createIcon :153-188 的标题/网格/提示三段结构，容器化等价）。
func _build_ui() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	_list = _content.get_node("%AvatarList") as VBoxContainer
	_style_scrollbar()
	# 分类 free/hero/worldcup + 解锁过滤（源 type_priority 顺序）。
	var groups: Dictionary = _build_groups()
	for type_key: String in ["free", "hero", "worldcup"]:
		if groups.has(type_key) and not (groups[type_key] as Array).is_empty():
			_list.add_child(_make_title(type_key))
			var grid := GridContainer.new()
			grid.columns = GRID_COLS
			# 间距照源步进换算（x 100/y 90 − icon 82.73 → 17/7）走 theme variation。
			grid.theme_type_variation = &"AvatarGrid"
			for entry: Dictionary in groups[type_key]:
				grid.add_child(_make_cell(int(entry["key"]), String(entry["res"])))
			_list.add_child(grid)
			# free 组末尾解锁提示（源 createIcon :163-167 仅 free 组最后一项后挂）。
			if type_key == "free":
				_list.add_child(_make_tips())


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


# 分类标题行：行模板实例 + fill 文案（源 createSubhead :109-121，18 号标题金）。
func _make_title(type_key: String) -> Control:
	var inst: Control = TITLE_ITEM_SCENE.instantiate() as Control
	(inst.get_node("%TitleLabel") as Label).text = _cm.get_lstr(LSTR_TITLE_KEYS[type_key])
	return inst


# free 组末尾解锁提示（源 createUnlockPrompt :123-128：18 号金同 createSubhead
# 色号 → 复用 AvatarTitleLabel；行高 40 = 源 additionHeight :22-25 计账）。
func _make_tips() -> Label:
	var tips := Label.new()
	tips.text = _cm.get_lstr(LSTR_TIPS_KEY)
	tips.theme_type_variation = &"AvatarTitleLabel"
	tips.custom_minimum_size = Vector2(0.0, 40.0)
	tips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tips.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tips


# 创建头像单元：hero_icon_frame_1 框 + Picture 图（fixNodeSize 框-10）+ 点击 set_avatar。
func _make_cell(aid: int, picture_res: String) -> Control:
	var btn := TextureButton.new()
	btn.texture_normal = load(ICON_FRAME_RES)
	btn.ignore_texture_size = true
	# stretch_mode=0（SCALE）显式——TextureButton 默认 2（KEEP）不填 rect（批 2 方法论）。
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	# ed.createSprite 无 fix → 显示 = 纹理 106/CS（÷CS 轨道手算，批 4 口径）。
	btn.custom_minimum_size = ICON_FRAME_DISPLAY
	btn.pressed.connect(_on_avatar_selected.bind(aid))
	if ResourceLoader.exists(picture_res):
		var icon := TextureRect.new()
		icon.texture = load(picture_res)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size = ICON_FRAME_DISPLAY - Vector2(ICON_PAD, ICON_PAD)
		icon.position = Vector2(ICON_PAD * 0.5, ICON_PAD * 0.5)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)
	return btn


# 滚动条照源贴图（源 draglist bar：base.lua createListLayer :11-14 + draglist.lua
# :1116-1204，轨道 scroll_bar_bg + 滑块 scroll_bar.png 竖向、滚动时显）。
# ScrollContainer 默认灰圆角条 → StyleBoxTexture 贴图化；add_theme_stylebox_override
# 属滚动条引擎缺口例外（SOP 条款）。位置贴容器右缘（源在列表左侧 x=150，
# internal child 不可移，受控偏差）。
func _style_scrollbar() -> void:
	var scroll: ScrollContainer = _content.get_node("%AvatarScroll") as ScrollContainer
	var vs: VScrollBar = scroll.get_v_scroll_bar()
	var track := StyleBoxTexture.new()
	track.texture = load(SCROLL_TRACK_RES)
	var grabber := StyleBoxTexture.new()
	grabber.texture = load(SCROLL_GRABBER_RES)
	for key: StringName in ["scroll", "scroll_focus"]:
		vs.add_theme_stylebox_override(key, track)
	for key: StringName in ["grabber", "grabber_highlight", "grabber_pressed"]:
		vs.add_theme_stylebox_override(key, grabber)


# 点选 set_avatar → destroy（源 doSendSet :258-265 单机化：直写 PlayerData + toast）。
# 2026-08-21 补 HudOverlay.refresh——换头像回传主界面 HUD 头像框（icon 随 avatar 换图）。
func _on_avatar_selected(aid: int) -> void:
	_pd.set_avatar(aid)
	HudOverlay.refresh()
	Toast.show_message("头像已设置")
	remove_window()
