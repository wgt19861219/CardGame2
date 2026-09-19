class_name SetupPanel
extends PopWindow

## 系统设置面板（View 层）— 照源 ui/popwindow/notification.lua + uieditor/setup.lua。
## 入口 configure.lua doClickSetupButton:1399-1408。
##
## 功能（2026-09-19 五轮用户指示「背景音和音效分开设置+音量调节」）：
##   - 背景音乐行：图标开关（toggle_bgm：翻转+持久化+BGM 停/恢复）+ 音量滑条
##     （set_bgm_volume → Music 总线）；音效行同构（toggle_sfx / set_sfx_volume → Sfx 总线）；
##   - 开关与音量正交：off 不动音量，滑条随时可调即时生效（AudioPlayer 持久化）。
##   受控偏离：源 notification.lua 仅单音效开关（soundSwitch 同管 BGM+SFX）无音量调节，
##   双通道拆分 + 音量为单机版原生增强（LSTR 亦无双通道词条，行名硬编码中文，先例
##   configure「存档管理」）。
##
## 受控裁剪（单机版，源对照）：
##   - CDKey 兑换（doClickCDKeyButton:134-138 服务器验证，源按钮 visible=false）；
##   - 黑名单（doClickBlickListButton:139-142 联机拉黑，源按钮 visible=false）；
##   - 标题「推送设置」（SETUP.PUSH_SET）改「系统设置」（CONFIGURE.SYSTEM.SETTING）。
##   - 7 通知开关 + 「消息提醒」栏 + 相关全局提醒（2026-09-18 四轮整体退役）。
##
## chrome 照源直译：frame main_vit_tips 544.53 宽（cap L12/T12/R14/B12 验证值）+ title_bg
## pvp_tip_title_bg 517.34×34.375 + close 骑缝右上。显示尺寸口径：uieditor scaleSize/fix_wh
## 即 cocos 点（图标 55×55），不 ÷CS。to_godot(x,y)=(x,480-y)，CS=1.28125。

const FRAME_RES: String = "res://assets/ui/alpha/HVGA/main_vit_tips.png"
const TITLE_BG_RES: String = "res://assets/ui/alpha/HVGA/pvp/pvp_tip_title_bg.png"
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/common/common_tips_button_close_1.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/common/common_tips_button_close_2.png"
const SOUND_ON_RES: String = "res://assets/ui/alpha/HVGA/sound_on.png"
const SOUND_OFF_RES: String = "res://assets/ui/alpha/HVGA/sound_off.png"
const LSTR_TITLE: String = "CONFIGURE.SYSTEM.SETTING"
const BGM_LABEL_TEXT: String = "背景音乐"
const SFX_LABEL_TEXT: String = "音效"

# frame：源 setup.lua Scale9 544.53×390.63 @(128.13,42.97)（源即水平居中）。2026-09-19 五轮
# 双通道加高 150→190（title 14~48 + 背景音乐行 58~113 + 音效行 123~178 + 底距 12），
# y 垂直居中 (480-190)/2；x 修正 208.13→127.74=(800-544.53)/2（四轮遗留手误：源 128.13
# 误写 208.13 偏右 80 点，2026-09-19 实机截图量化检测抓出）。
const FRAME_RECT: Rect2 = Rect2(127.74, 145.0, 544.53, 190.0)
# cap 照 setup.lua：capInsets(11.72,11.72,54.69,23.44)（点单位）＝ 纹理px L15/T15/w70/h30，
# R=103-15-70=18 / B=61-15-30=16（2026-08-21 修正源引用；2026-08-22 patch ÷CS 观感专项）。
# patch_margin 须显示点值 = 纹理px÷CS(1.28125) 取整 → L12/T12/R14/B12（2026-09-18 修正：
# 4dd3b7c 曾把 L/B 误算成点值11.72再÷CS=9 的双重换算，B9 < 贴图底边框带 12px〔纹理 y=49~54
# 深色带〕，平铺时该带泄进中间区每 40px 重复一次 → 弹窗"一横一横"横纹）。
const FRAME_CAP_LEFT: int = 12
const FRAME_CAP_TOP: int = 12
const FRAME_CAP_RIGHT: int = 14
const FRAME_CAP_BOTTOM: int = 12
# title_bg：517.34×34.375，源 frame 内中心 (275,359.38) → 局部 top=390.63-359.38=31.25。
const TITLE_BG_RECT: Rect2 = Rect2(16.33, 14.06, 517.34, 34.375)
const TITLE_FONT_SIZE: int = 18
const TITLE_COLOR: Color = Color(1.0, 210.0 / 255.0, 16.0 / 255.0)
# close：源 frame 内中心 (532.81,370.31)，50.73×51.52 骑缝右上。
const CLOSE_CENTER: Vector2 = Vector2(532.81, 20.31)
const CLOSE_SIZE: Vector2 = Vector2(50.73, 51.52)
# 声音两行（同构）：行区局部 x 60 起、行高 55（图标 55×55 照源 scaleSize 不 ÷CS）。
# 行内：图标(55) + sep12 + 类别名(86) + sep12 + 滑条(190) + sep12 + 百分比(48) = 415。
const ROW_X: float = 60.0
const BGM_ROW_Y: float = 58.0
const SFX_ROW_Y: float = 123.0
const ROW_HEIGHT: float = 55.0
const ROW_SEP: int = 12
const SOUND_ICON_SIZE: Vector2 = Vector2(55.0, 55.0)
const LABEL_W: float = 86.0
const PCT_W: float = 48.0
const LABEL_FONT_SIZE: int = 18
const LABEL_COLOR: Color = Color(1.0, 237.0 / 255.0, 139.0 / 255.0)

var _cm: ConfigManager
var _content: Control = null   # frame 锚定层（局部坐标系：chrome/内容常量均为 frame 局部值）
var _bgm_btn: TextureButton = null
var _bgm_bar: VolumeBar = null
var _bgm_pct: Label = null
var _sfx_btn: TextureButton = null
var _sfx_bar: VolumeBar = null
var _sfx_pct: Label = null


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
	_add_sound_rows()


func _add_frame() -> void:
	var frame := NinePatchRect.new()
	frame.texture = load(FRAME_RES) as Texture2D
	frame.position = Vector2.ZERO   # content 已锚定 frame 原点
	frame.size = FRAME_RECT.size
	frame.patch_margin_left = FRAME_CAP_LEFT
	frame.patch_margin_top = FRAME_CAP_TOP
	frame.patch_margin_right = FRAME_CAP_RIGHT
	frame.patch_margin_bottom = FRAME_CAP_BOTTOM
	# 拉伸模式用默认 STRETCH（2026-09-18 二轮：TILE_FIT 平铺在 tile 边界产生 1px 采样
	# 接缝暗线〔实测 4 条，亮度差 2.4%〕；中间区是纯色，平铺与拉伸观感一致，STRETCH 无缝
	# 且对齐源 Axmol Scale9Sprite 默认拉伸语义）。
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


# 双通道声音行（2026-09-19 五轮）：背景音乐/音效各一行，初始态照 AudioPlayer 双通道
# 真值（battle_pause_layer 图标反相教训：初始传真值）。
func _add_sound_rows() -> void:
	var bgm_row: Array = _build_channel_row(BGM_ROW_Y, BGM_LABEL_TEXT, AudioPlayer.bgm_switch, AudioPlayer.bgm_volume)
	_bgm_btn = bgm_row[0] as TextureButton
	_bgm_bar = bgm_row[1] as VolumeBar
	_bgm_pct = bgm_row[2] as Label
	_bgm_btn.pressed.connect(_on_bgm_pressed)
	_bgm_bar.value_changed.connect(_on_bgm_volume)

	var sfx_row: Array = _build_channel_row(SFX_ROW_Y, SFX_LABEL_TEXT, AudioPlayer.sfx_switch, AudioPlayer.sfx_volume)
	_sfx_btn = sfx_row[0] as TextureButton
	_sfx_bar = sfx_row[1] as VolumeBar
	_sfx_pct = sfx_row[2] as Label
	_sfx_btn.pressed.connect(_on_sfx_pressed)
	_sfx_bar.value_changed.connect(_on_sfx_volume)


# 通道行同构构建：图标开关(55×55) + 类别名 + VolumeBar(命中区=行高) + 百分比。
# 返回 [btn, bar, pct]（调用方存成员 + 接信号）。
func _build_channel_row(row_y: float, label_text: String, on: bool, volume: float) -> Array:
	var row := HBoxContainer.new()
	row.position = Vector2(ROW_X, row_y)
	row.add_theme_constant_override("separation", ROW_SEP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var btn := TextureButton.new()
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	btn.custom_minimum_size = SOUND_ICON_SIZE
	btn.texture_normal = _sound_texture(on)
	row.add_child(btn)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	label.add_theme_color_override("font_color", LABEL_COLOR)
	label.custom_minimum_size = Vector2(LABEL_W, ROW_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	var bar := VolumeBar.new(ROW_HEIGHT)   # 命中区=行高（55），条体 15 在其内居中
	row.add_child(bar)
	bar.set_value(volume)
	var pct := Label.new()
	pct.text = _pct_text(volume)
	pct.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	pct.add_theme_color_override("font_color", LABEL_COLOR)
	pct.custom_minimum_size = Vector2(PCT_W, ROW_HEIGHT)
	pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pct.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pct)
	_content.add_child(row)
	return [btn, bar, pct]


func _on_bgm_pressed() -> void:
	AudioPlayer.toggle_bgm()
	_bgm_btn.texture_normal = _sound_texture(AudioPlayer.bgm_switch)


func _on_sfx_pressed() -> void:
	AudioPlayer.toggle_sfx()
	_sfx_btn.texture_normal = _sound_texture(AudioPlayer.sfx_switch)


func _on_bgm_volume(ratio: float) -> void:
	AudioPlayer.set_bgm_volume(ratio)
	_bgm_pct.text = _pct_text(AudioPlayer.bgm_volume)


func _on_sfx_volume(ratio: float) -> void:
	AudioPlayer.set_sfx_volume(ratio)
	_sfx_pct.text = _pct_text(AudioPlayer.sfx_volume)


func _sound_texture(on: bool) -> Texture2D:
	return load(SOUND_ON_RES if on else SOUND_OFF_RES) as Texture2D


func _pct_text(ratio: float) -> String:
	return "%d%%" % roundi(ratio * 100.0)
