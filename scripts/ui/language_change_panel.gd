class_name LanguageChangePanel
extends PopWindow

## 语言切换面板（View 层）— 照源 ui/popwindow/languagechange.lua。
## frame main_vit_tips 630x440 + close 右上骑边 + 7 语言按钮（frame 局部固定网格，
## 96x62 像素/CS 显示）+ CONFIGURE.LANGUAGE.<LANG> 标签（LangNameLabel variation）+
## 点选 doClickChangeLanguage → set_language + save + reload_current_scene 刷新。
##
## 两件套改造（批 4 Task 1，2026-08-17）：Frame/LangHost/CloseBtn 静态进
## scenes/ui/language_change_content.tscn；语言按钮 procedural 平挂 %LangHost
## （源 readnode root=frame :128，button+label 平级交替；brief 动态行保留 procedural）。
## 坐标照源点空间直译（批 3 口径）：frame 子树 = frame contentSize(630x440) 左下原点
## 点值直译（y' = 440-y）；贴图显示尺寸 = 像素/CS(1.28125)（lang 贴图无 TextureConfig
## 条目，PIL 实测 96x62；勿调 tex_display_size）。
## 受控裁剪：源 cancel_press 1.1x 放大（:157-162）由 TextureButton texture_pressed
## 换图等价；confirm 对话框/GetPlatformOS zh-CN 限制单机化直切（2026-07-18 既有决策）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/language_change_content.tscn")
const LANG_ICON_DIR: String = "res://assets/ui/alpha/HVGA/lang/"
# 源 frame contentSize（:47）——frame 子树点空间直译基准
const FRAME_SIZE := Vector2(630.0, 440.0)
# lang/<key>.png 全语言实测 96x62 像素 → 显示 = /CS（批 4 约束手算）
const LANG_DISPLAY_SIZE := Vector2(96.0, 62.0) / 1.28125
# 标签在按钮中心上方 45（源 :174 position (x, y+45)）
const LABEL_DY: float = 45.0
# 源 :96-100 七语言网格（frame 局部 Cocos 坐标中心锚；其余语言源 :103-119 注释未启用）
const LANG_LAYOUT: Array = [
	{"lang": "en-US", "x": 100.0, "y": 340.0},
	{"lang": "de-DE", "x": 210.0, "y": 340.0},
	{"lang": "ko-KR", "x": 320.0, "y": 340.0},
	{"lang": "zh-CN", "x": 430.0, "y": 340.0},
	{"lang": "ru-RU", "x": 540.0, "y": 340.0},
	{"lang": "tr-TR", "x": 100.0, "y": 250.0},
	{"lang": "pt-BR", "x": 210.0, "y": 250.0},
]

var _lm: LanguageManager
var _content: Control


func setup_panel(p_lm: LanguageManager) -> void:
	_lm = p_lm
	setup()
	register_on_enter(play_scale_in)
	_build_content()


# content 静态树 instantiate + connect close + 语言按钮/标签 procedural 平挂 %LangHost。
# （源 show() EaseBackOut 0.2 弹入 → PopWindow.play_scale_in 基类等价；
# 点遮罩关闭走基类 _on_shade_clicked，源 btRegisterOutClick 等价。）
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	var host: Control = _content.get_node("%LangHost") as Control
	for entry in LANG_LAYOUT:
		var d: Dictionary = entry as Dictionary
		var center := Vector2(float(d["x"]), FRAME_SIZE.y - float(d["y"]))
		host.add_child(_make_lang_button(String(d["lang"]), center))
		host.add_child(_make_lang_label(String(d["lang"]), center))


# 语言按钮（源 :131-146）：frame 局部中心锚定位，显示尺寸 96x62/CS。
func _make_lang_button(lang: String, center: Vector2) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal = load(LANG_ICON_DIR + lang + ".png") as Texture2D
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	btn.position = center - LANG_DISPLAY_SIZE * 0.5
	btn.size = LANG_DISPLAY_SIZE
	btn.pressed.connect(_on_lang_click.bind(lang))
	return btn


# 语言名标签（源 :164-179）：size20 金色走 LangNameLabel variation，四锚同点中心
# 锚定于按钮上方 45（源 position (x, y+45) 中心锚 → y' = 440-y-45）。
func _make_lang_label(lang: String, center: Vector2) -> Label:
	var lbl := Label.new()
	lbl.text = _lm.get_lstr("CONFIGURE.LANGUAGE." + lang.to_upper())
	lbl.theme_type_variation = "LangNameLabel"
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl_anchor := Vector2(center.x / FRAME_SIZE.x, (center.y - LABEL_DY) / FRAME_SIZE.y)
	lbl.anchor_left = lbl_anchor.x
	lbl.anchor_right = lbl_anchor.x
	lbl.anchor_top = lbl_anchor.y
	lbl.anchor_bottom = lbl_anchor.y
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	return lbl


# 单机化：去 system_setting 网络消息 + 去 confirm 中转，直接切换（2026-07-18 既有决策，
# 等价源 doClickChangeLanguage 确认后逻辑；同语言 no-op 照源 :241-243）。
# reload_current_scene 直接重载当前场景（场景重建所有 UI 重读 get_lstr 新语言，
# 等价源 replaceScene 刷新机制）。
func _on_lang_click(lang: String) -> void:
	if lang == _lm.get_language():
		return
	_lm.set_language(lang)
	_lm.save_language()
	get_tree().reload_current_scene()
