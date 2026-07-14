class_name LanguageChangePanel
extends PopWindow

## 语言切换面板（View 层）— 照源 ui/popwindow/languagechange.lua。
## main_vit_tips 630×440 框 + common_tips_button_close X + 7 语言按钮（lang/<key>.png + CONFIGURE.LANGUAGE.<LANG> 标签）+
## 点选 doClickChangeLanguage → set_language + save + Toast 提示 + remove。
## 源 needRestart 改运行时切换（LanguageManager 内存切 + 持久化，UI 调用方刷新）。确认对话框简化为 Toast（单机化）。

const FRAME_RES: String = "res://assets/ui/alpha/HVGA/main_vit_tips.png"
const FRAME_CAP: Rect2 = Rect2(10.0, 10.0, 58.0, 26.0)      # 源 languagechange.lua:46 CCRectMake(10,10,58,26)
const FRAME_SIZE: Vector2 = Vector2(630.0, 440.0)           # 源 :47 ContentSize 630×440
const FRAME_CENTER: Vector2 = Vector2(400.0, 232.0)         # 源 :48 ccp(400,232)
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/common/common_tips_button_close_1.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/common/common_tips_button_close_2.png"
const CLOSE_POS: Vector2 = Vector2(610.0, 425.0)            # 源 :74 ccp(610,425)
const LANG_ICON_DIR: String = "res://assets/ui/alpha/HVGA/lang/"   # 源 getLanguagePng :71
const GRID_POS: Vector2 = Vector2(150.0, 120.0)
const GRID_COLS: int = 5
# 源 languagechange.lua:96-102 7 语言（实际 lua 包）。
const LANGS: Array = ["en-US", "de-DE", "ko-KR", "zh-CN", "ru-RU", "tr-TR", "pt-BR"]
# 源 languagechange.lua:177 label ccc3(220,176,103)。
const LABEL_COLOR: Color = Color(0.863, 0.690, 0.404)

var _lm: LanguageManager


# 源 cocos(800×480 左下) → Godot(960×640 左上):cx+80, 560-cy（同 battle_view_coords 标准）。
# Phase 4 早期直接用源值漏转，2026-07-14 补 to_godot。
func _g(pos: Vector2) -> Vector2:
	return BattleViewCoords.to_godot(pos.x, pos.y)


func setup_panel(p_lm: LanguageManager) -> void:
	_lm = p_lm
	setup()
	_build_ui()


func _build_ui() -> void:
	# 源 base.lua:75 btRegisterOutClick：点框外 destroy。
	shade_layer.gui_input.connect(_on_shade_input)
	# 源 languagechange.lua:46 main_vit_tips Scale9 630×440 @ ccp(400,232)。
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
	# 源 languagechange.lua:71 common_tips_button_close X @ ccp(610,425)。
	var close: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS_RES, _g(CLOSE_POS))
	close.pressed.connect(remove_window)
	container.add_child(close)
	# 7 语言按钮（源 createLanguageButton :125-192）。
	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.position = GRID_POS
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 40)
	container.add_child(grid)
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
