class_name LanguageChangePanel
extends PopWindow

## 语言切换面板（View 层）— 照源 ui/popwindow/languagechange.lua。
## main_vit_tips 630×440 框 + common_tips_button_close X + 7 语言按钮（lang/<key>.png + CONFIGURE.LANGUAGE.<LANG> 标签）+
## 点选 doClickChangeLanguage → set_language + save + reload_current_scene 刷新。
## 源 needRestart 改运行时切换（LanguageManager 内存切 + 持久化，UI 调用方刷新）。确认对话框简化为 Toast（单机化）。
##
## 重构（2026-07-18，照 hero_detail 范式）：chrome（frame/close/lang_grid host）静态化进
## scenes/ui/language_change_content.tscn（位置/size 编辑器可视化调）；7 语言按钮（源固定 7 个）
## 保留 procedural 挂 %LangGrid（VBox+TextureButton+Label 子组件，局部坐标系保留）。
## 坐标：源 cocos(800×480 左下) → _to_godot(cx+80, 560-cy)，frame/close 一次性写死进 .tscn 全屏系。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/language_change_content.tscn")
const LANG_ICON_DIR: String = "res://assets/ui/alpha/HVGA/lang/"   # 源 getLanguagePng :71
# 源 languagechange.lua:96-102 7 语言（实际 lua 包）。
const LANGS: Array = ["en-US", "de-DE", "ko-KR", "zh-CN", "ru-RU", "tr-TR", "pt-BR"]
# 源 languagechange.lua:177 label ccc3(220,176,103)。
const LABEL_COLOR: Color = Color(0.863, 0.690, 0.404)

var _lm: LanguageManager


func setup_panel(p_lm: LanguageManager) -> void:
	_lm = p_lm
	setup()
	_build_content()


# 建 UI 内容：chrome（frame/close/lang_grid host）从 .tscn instantiate；7 语言按钮 procedural 挂 %LangGrid
# （holder VBox + TextureButton + Label 子组件保留，局部坐标系不变）。
func _build_content() -> void:
	# 源 base.lua:75 btRegisterOutClick：点框外 destroy。
	shade_layer.gui_input.connect(_on_shade_input)
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	var grid: GridContainer = content.get_node("%LangGrid") as GridContainer
	for lang in LANGS:
		grid.add_child(_make_lang_button(String(lang)))


# 源 createLanguageButton：lang/<key>.png 图标 + CONFIGURE.LANGUAGE.<LANG> 标签 ccc3(220,176,103)。
func _make_lang_button(lang: String) -> Control:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 4)
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon_path: String = LANG_ICON_DIR + lang + ".png"
	var btn := TextureButton.new()
	var icon_tex: Texture2D = load(icon_path)
	btn.texture_normal = icon_tex
	btn.ignore_texture_size = true
	if icon_tex != null:
		btn.size = icon_tex.get_size()
		btn.custom_minimum_size = icon_tex.get_size()
	btn.pressed.connect(_on_lang_click.bind(lang))
	holder.add_child(btn)
	var lbl := Label.new()
	lbl.text = _lm.get_lstr("CONFIGURE.LANGUAGE." + lang.to_upper())
	lbl.add_theme_color_override("font_color", LABEL_COLOR)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(lbl)
	return holder


# 源 doClickChangeLanguage :240-267 + notification:300-303：切语言 + save + replaceScene(platformlogo) 重启场景刷新 UI。
# 单机化：去 system_setting 网络消息 + 去 logo 中转，reload_current_scene 直接重载当前场景
# （场景重建所有 UI 重读 get_lstr 新语言，等价源 replaceScene 刷新机制；去 Toast，用户直接看到新语言界面 = 切换反馈）。
func _on_lang_click(lang: String) -> void:
	if lang == _lm.get_language():
		return
	_lm.set_language(lang)
	_lm.save_language()
	get_tree().reload_current_scene()


# 源 base.lua:75 btRegisterOutClick：点框外 cancel。
func _on_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			remove_window()
