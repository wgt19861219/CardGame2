class_name SetupPanel
extends PopWindow

## 系统设置面板（View 层）— 照源 ui/popwindow/notification.lua + uieditor/setup.lua +
## setuplist.lua 完整版（2026-08-21 二轮：用户反馈裁剪过度 → 7 通知开关全量照源补全）。
## 入口 configure.lua doClickSetupButton:1399-1408。
##
## 功能：
##   音效开关（doClickSoundButton:129-132）— AudioPlayer.toggle_sound（翻转+持久化+BGM 停/恢复）
##   + 7 通知开关（refreshSwitchButton:78-103 / doClickSwitch:143-147）— NotifySettings
##   （user://notify.cfg 持久化；5 定时项游戏运行中到点 Toast + 技能点回满提醒，见该类头注释）。
##
## 受控裁剪（单机版，源对照）：
##   - CDKey 兑换（doClickCDKeyButton:134-138 服务器验证，源按钮 visible=false）；
##   - 黑名单（doClickBlickListButton:139-142 联机拉黑，源按钮 visible=false）；
##   - 第 4 排右列空槽（源 switch_container_right_4 visible=false）；
##   - 标题「推送设置」（SETUP.PUSH_SET）改「系统设置」（CONFIGURE.SYSTEM.SETTING，
##     与 configure 主面板按钮文案一致）。
##
## chrome 照源直译：frame main_vit_tips 544.53×390.63 @(128.13,42.97)（cap 用
## SaveManagerPanel 同贴图验证值 L15/T26/R43/B20）+ title_bg pvp_tip_title_bg
## 517.34×34.375 + close 骑缝右上。内容行容器化（源 4 大 Layer 叠坐标不逐像素直译，
## stage_detail/battle_pause_layer 先例）：音效行 + 「消息提醒」分隔栏 + 4 排双列开关。
## 显示尺寸口径：uieditor scaleSize/fix_wh 即 cocos 点（音效 55×55、开关 65.63×46.09、
## notice_bg 527.5×34.375），不 ÷CS；贴图被源 fix_wh 拉伸（474→517 等）同款拉伸。
## to_godot(x,y)=(x+80,560-y)，CS=1.28125。

const FRAME_RES: String = "res://assets/ui/alpha/HVGA/main_vit_tips.png"
const TITLE_BG_RES: String = "res://assets/ui/alpha/HVGA/pvp/pvp_tip_title_bg.png"
const NOTICE_BG_RES: String = "res://assets/ui/alpha/HVGA/task_title_bg.png"
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/common/common_tips_button_close_1.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/common/common_tips_button_close_2.png"
const SOUND_ON_RES: String = "res://assets/ui/alpha/HVGA/sound_on.png"
const SOUND_OFF_RES: String = "res://assets/ui/alpha/HVGA/sound_off.png"
const SWITCH_ON_RES: String = "res://assets/ui/alpha/HVGA/playerinfo_button_notice_open.png"
const SWITCH_OFF_RES: String = "res://assets/ui/alpha/HVGA/playerinfo_button_notice_close.png"
const LSTR_TITLE: String = "CONFIGURE.SYSTEM.SETTING"
const LSTR_NEWS: String = "PLAYERINFO.NEWS_ALERT"
const LSTR_SOUND_ON: String = "BATTLE_SCENE.SOUND__ON"
const LSTR_SOUND_OFF: String = "BATTLE_SCENE.SOUND__OFF"

# frame：源 setup.lua Scale9 544.53×390.63 @(128.13,42.97) → Godot (208.13,126.41)。
const FRAME_RECT: Rect2 = Rect2(208.13, 126.41, 544.53, 390.63)
# cap 照 setup.lua 直译：capInsets(11.72,11.72,54.69,23.44) 显示值×CS → L15/T15/w70/h30
# → R=103-15-70=18 / B=61-15-30=16（2026-08-21 修正：此前误用 savemanager.lua 源 cap）。
const FRAME_CAP_LEFT: int = 15
const FRAME_CAP_TOP: int = 15
const FRAME_CAP_RIGHT: int = 18
const FRAME_CAP_BOTTOM: int = 16
# title_bg：517.34×34.375，源 frame 内中心 (275,359.38) → 局部 top=390.63-359.38=31.25。
const TITLE_BG_RECT: Rect2 = Rect2(16.33, 14.06, 517.34, 34.375)
const TITLE_FONT_SIZE: int = 18
const TITLE_COLOR: Color = Color(1.0, 210.0 / 255.0, 16.0 / 255.0)
# close：源 frame 内中心 (532.81,370.31)，50.73×51.52 骑缝右上。
const CLOSE_CENTER: Vector2 = Vector2(532.81, 20.31)
const CLOSE_SIZE: Vector2 = Vector2(50.73, 51.52)
# 音效行：源图标 55×55（scaleSize 显示值不 ÷CS，2026-08-21 二轮修正口径），
# 行区局部 y 60~115 左起 x 60（源 sound 图标偏 frame 左半区）。
const SOUND_ROW_POS: Vector2 = Vector2(60.0, 60.0)
const SOUND_ICON_SIZE: Vector2 = Vector2(55.0, 55.0)
const ROW_SEP: int = 16
const LABEL_FONT_SIZE: int = 18
const LABEL_COLOR: Color = Color(1.0, 237.0 / 255.0, 139.0 / 255.0)
# 分隔线（源 setuplist delimeter×4 pvp_tip_delimiter 475×2px ÷CS=370.7×1.56，
# 位于 音效|notice|r1|r2|r3 区间之间——照源区间语义映射容器化行距）。
const DELIM_RES: String = "res://assets/ui/alpha/HVGA/pvp/pvp_tip_delimiter.png"
const DELIM_SIZE: Vector2 = Vector2(370.7, 1.56)
const DELIM_X: float = 86.9   # x 中心 272.27（frame 中心）- 宽半 185.35
const DELIM_YS: Array[float] = [116.5, 155.0, 216.0, 274.0]

# 「消息提醒」分隔栏：527.5×34.375 横向居中（源 x 中心 265.63≈frame 中心）。
const NOTICE_BG_RECT: Rect2 = Rect2(8.52, 118.0, 527.5, 34.375)
const NOTICE_FONT_SIZE: int = 18
# 开关网格：4 排双列，行高 58（源排距 65.62 收紧容纳），cell 宽 253。
const GRID_POS: Vector2 = Vector2(19.27, 158.0)
const CELL_SIZE: Vector2 = Vector2(253.0, 58.0)
const TIME_FONT_SIZE: int = 16
const SWITCH_ICON_SIZE: Vector2 = Vector2(65.63, 46.09)   # 源 fix_wh 显示值
# UI 位置 → 通知 id（源 4 排双列布局：r1=[1,4] r2=[2,5] r3=[3,6] r4=[7,空]）。
const GRID_IDS: Array = [[1, 4], [2, 5], [3, 6], [7, 0]]
# 定时项的时间标签（源 create:56-74 按服务器时区换算 → 单机本地时区直显源时间点）。
const TIME_LABELS: Dictionary = {1: "12:00", 2: "18:00", 4: "9:00", 5: "21:00"}

var _cm: ConfigManager
var _content: Control = null   # frame 锚定层（局部坐标系：chrome/内容常量均为 frame 局部值）
var _sound_btn: TextureButton = null
var _sound_label: Label = null
var _switch_btns: Dictionary = {}   # id → TextureButton（刷新图标用）


func setup_panel(p_cm: ConfigManager) -> void:
	_cm = p_cm
	setup()
	register_on_enter(play_scale_in)
	_build_content()


# 入口（configure_panel._on_setup 调）。
static func open(parent: Control) -> void:
	var panel := SetupPanel.new("setup", {})
	panel.setup_panel(GameData.config)
	panel.show_window(parent)


func _build_content() -> void:
	# 内容锚定层：所有子元素坐标 = frame 局部值（容器化行/贴图统一坐标空间，
	# 防直挂 container 的屏幕空间错位——2026-08-21 实机 global(29,158) 抓出）。
	_content = Control.new()
	_content.position = FRAME_RECT.position
	_content.size = FRAME_RECT.size
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_content)
	_add_frame()
	_add_title_bar()
	_add_close_btn()
	_add_sound_row()
	_add_notice_bar()
	_add_delimiters()
	_add_switch_grid()


func _add_frame() -> void:
	var frame := NinePatchRect.new()
	frame.texture = load(FRAME_RES) as Texture2D
	frame.position = Vector2.ZERO   # content 已锚定 frame 原点
	frame.size = FRAME_RECT.size
	frame.patch_margin_left = FRAME_CAP_LEFT
	frame.patch_margin_top = FRAME_CAP_TOP
	frame.patch_margin_right = FRAME_CAP_RIGHT
	frame.patch_margin_bottom = FRAME_CAP_BOTTOM
	frame.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	frame.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(frame)


# 标题栏：title_bg 底图（fix_wh 横向拉伸照源）+ 18 号金标题（源 createSubhead 同色号）。
func _add_title_bar() -> void:
	var bg := TextureRect.new()
	bg.texture = load(TITLE_BG_RES) as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.position = TITLE_BG_RECT.position
	bg.size = TITLE_BG_RECT.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(bg)
	var title := Label.new()
	title.text = _cm.get_lstr(LSTR_TITLE)
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = TITLE_BG_RECT.position
	title.size = TITLE_BG_RECT.size
	_content.add_child(title)


func _add_close_btn() -> void:
	var btn := TextureButton.new()
	btn.texture_normal = load(CLOSE_RES) as Texture2D
	btn.texture_pressed = load(CLOSE_PRESS_RES) as Texture2D
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	btn.position = CLOSE_CENTER - CLOSE_SIZE * 0.5
	btn.size = CLOSE_SIZE
	btn.pressed.connect(remove_window)
	_content.add_child(btn)


# 音效行：喇叭图标按钮（点击翻转 AudioPlayer.sound_switch）+ 状态文案。
# 初始态照 AudioPlayer.sound_switch（battle_pause_layer 图标反相教训：初始传真值）。
func _add_sound_row() -> void:
	var row := HBoxContainer.new()
	row.position = SOUND_ROW_POS
	row.add_theme_constant_override("separation", ROW_SEP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sound_btn = TextureButton.new()
	_sound_btn.ignore_texture_size = true
	_sound_btn.stretch_mode = TextureButton.STRETCH_SCALE
	_sound_btn.custom_minimum_size = SOUND_ICON_SIZE
	_sound_btn.size = SOUND_ICON_SIZE
	_sound_btn.texture_normal = _sound_texture(AudioPlayer.sound_switch)
	_sound_btn.pressed.connect(_on_sound_pressed)
	row.add_child(_sound_btn)
	_sound_label = Label.new()
	_sound_label.text = _sound_text(AudioPlayer.sound_switch)
	_sound_label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	_sound_label.add_theme_color_override("font_color", LABEL_COLOR)
	_sound_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sound_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_sound_label)
	_content.add_child(row)


# 「消息提醒」分隔栏（源 notice_bg + NEWS_ALERT 白 18 号，推送开关区标题）。
func _add_notice_bar() -> void:
	var bg := TextureRect.new()
	bg.texture = load(NOTICE_BG_RES) as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.position = NOTICE_BG_RECT.position
	bg.size = NOTICE_BG_RECT.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(bg)
	var label := Label.new()
	label.text = _cm.get_lstr(LSTR_NEWS)
	label.add_theme_font_size_override("font_size", NOTICE_FONT_SIZE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = NOTICE_BG_RECT.position
	label.size = NOTICE_BG_RECT.size
	_content.add_child(label)


# 分隔线×4（源 delimeter：区间隔断，治列表区「占位感」——2026-08-21 用户反馈补全）。
func _add_delimiters() -> void:
	for y: float in DELIM_YS:
		var line := TextureRect.new()
		line.texture = load(DELIM_RES) as Texture2D
		line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		line.position = Vector2(DELIM_X, y)
		line.size = DELIM_SIZE
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(line)


# 4 排双列开关网格（源 switch_container 双列布局容器化；r4 右列源隐藏不建）。
func _add_switch_grid() -> void:
	for row_idx: int in range(GRID_IDS.size()):
		var row := HBoxContainer.new()
		row.position = GRID_POS + Vector2(0.0, row_idx * CELL_SIZE.y)
		row.add_theme_constant_override("separation", 0)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for id: int in GRID_IDS[row_idx]:
			if id == 0:
				continue
			row.add_child(_make_switch_cell(id))
		_content.add_child(row)


# 单个开关 cell：时间标签（16 白，仅定时项）+ 行文案（18 淡黄）+ 开/关图标按钮。
func _make_switch_cell(id: int) -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.size = CELL_SIZE
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text_x: float = 10.0
	if TIME_LABELS.has(id):
		var time_lbl := Label.new()
		time_lbl.text = String(TIME_LABELS[id])
		time_lbl.add_theme_font_size_override("font_size", TIME_FONT_SIZE)
		time_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		time_lbl.position = Vector2(10.0, 0.0)
		time_lbl.size = Vector2(58.0, CELL_SIZE.y)
		time_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(time_lbl)
		text_x = 72.0
	var label := Label.new()
	label.text = _cm.get_lstr(NotifySettings.entry_lstr(id))
	label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	label.add_theme_color_override("font_color", LABEL_COLOR)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(text_x, 0.0)
	label.size = Vector2(CELL_SIZE.x - text_x - SWITCH_ICON_SIZE.x - 10.0, CELL_SIZE.y)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(label)
	var btn := TextureButton.new()
	btn.texture_normal = _switch_texture(NotifySettings.get_switch(id))
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	btn.position = Vector2(CELL_SIZE.x - SWITCH_ICON_SIZE.x - 5.0, (CELL_SIZE.y - SWITCH_ICON_SIZE.y) * 0.5)
	btn.size = SWITCH_ICON_SIZE
	btn.pressed.connect(_on_switch_pressed.bind(id))
	cell.add_child(btn)
	_switch_btns[id] = btn
	return cell


# 照源 doClickSoundButton:129-132：翻转（AudioPlayer 内含持久化 + BGM 停/恢复）+ 刷新图标文案。
func _on_sound_pressed() -> void:
	AudioPlayer.toggle_sound()
	_refresh_sound_row()


func _refresh_sound_row() -> void:
	var on: bool = AudioPlayer.sound_switch
	_sound_btn.texture_normal = _sound_texture(on)
	_sound_label.text = _sound_text(on)


# 照源 doClickSwitch:143-147：翻转 NotifySettings 开关 + refreshSwitchButton 换图标。
func _on_switch_pressed(id: int) -> void:
	NotifySettings.set_switch(id, not NotifySettings.get_switch(id))
	(_switch_btns[id] as TextureButton).texture_normal = _switch_texture(NotifySettings.get_switch(id))


func _sound_texture(on: bool) -> Texture2D:
	return load(SOUND_ON_RES if on else SOUND_OFF_RES) as Texture2D


func _sound_text(on: bool) -> String:
	return _cm.get_lstr(LSTR_SOUND_ON if on else LSTR_SOUND_OFF)


func _switch_texture(on: bool) -> Texture2D:
	return load(SWITCH_ON_RES if on else SWITCH_OFF_RES) as Texture2D
