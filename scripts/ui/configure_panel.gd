class_name ConfigurePanel
extends PopWindow

## 设置面板（View 层）— 照源 popwindow/configure.lua createWindow:1062-1316 + createSWButton:719-1061。
## 源 statusbar.lua:313-322 headIcon 点击 → ed.ui.configure.create()。main_vit_tips frame + 头像区 +
## 名字 + 玩家信息 + change_name/change_head/save_manager + setup_button 系统设置 + language_button 语言。
## 单机化裁剪（联机）：createSociety 公会 / createLogoffButton 登出 / createGoogleConnectButton /
## create360Buttons / createSWButton 换服 select_server+Facebook support/web / 玩家信息账号 ID getUserid。
## 坐标：源 Cocos ccp(左下原点) → _to_godot(cx+80,560-cy) → frame 内（frame 左上原点）= _to_godot - FRAME_POS。

const FRAME_TEX: String = "res://assets/ui/alpha/HVGA/main_vit_tips.png"
const FRAME_CAP: Rect2 = Rect2(15.0, 20.0, 45.0, 15.0)      # 源 :1081 CCRectMake(15,20,45,15)
const FRAME_SIZE: Vector2 = Vector2(500.0, 350.0)           # 源 :1088 500×250 初始 + createSWButton 扩高（源动态 height）
const FRAME_POS: Vector2 = Vector2(224.0, 105.0)            # 源 frame 顶部中心 ccp(394,455) → 左上
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/common/common_tips_button_close_1.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/common/common_tips_button_close_2.png"
const CLOSE_POS: Vector2 = Vector2(470.0, 5.0)
const HEAD_BG_RES: String = "res://assets/ui/alpha/HVGA/avatar_head_bg.png"
const HEAD_FRAME_RES: Array = [
	"res://assets/ui/alpha/HVGA/main_head_frame_silver.png",
	"res://assets/ui/alpha/HVGA/main_head_frame_gold.png",
]
const HEAD_POS: Vector2 = Vector2(1.0, 55.0)
const HEAD_SIZE: Vector2 = Vector2(80.0, 80.0)
const HEAD_ICON_SIZE: Vector2 = Vector2(70.0, 70.0)   # 源 getHeadIcon length=70（resource_manager.lua:1009）
const HEAD_ICON_POS: Vector2 = Vector2(6.0, 60.0)     # head_bg(1,55)80×80 内居中 70×70 → (1+5,55+5)
const HEAD_MASK_RES: String = "res://assets/ui/alpha/HVGA/main_head_mask.png"   # 源 createClippingNode stencil（configure.lua:80）
const PortraitMaskShader: Shader = preload("res://shaders/portrait_mask.gdshader")
const NAME_BG_RES: String = "res://assets/ui/alpha/HVGA/tip_detail_bg.png"
const NAME_BG_POS: Vector2 = Vector2(113.0, 30.0)
const NAME_BG_SIZE: Vector2 = Vector2(225.0, 30.0)
const NAME_POS: Vector2 = Vector2(125.0, 37.0)
const INFO_POS: Vector2 = Vector2(125.0, 65.0)
const INFO_LINE_H: float = 22.0
const BTN_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button.png"
const BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button_down.png"
const BTN_CAP: Rect2 = Rect2(15.0, 22.0, 15.0, 25.0)
const BTN_SIZE: Vector2 = Vector2(130.0, 55.0)
const BTN_LABEL_COLOR: Color = Color(235.0 / 255.0, 223.0 / 255.0, 207.0 / 255.0)
const CHANGE_NAME_POS: Vector2 = Vector2(406.0, 42.0)
const CHANGE_HEAD_POS: Vector2 = Vector2(406.0, 115.0)
const SAVE_MANAGER_POS: Vector2 = Vector2(406.0, 196.0)
const SETUP_BTN_SIZE: Vector2 = Vector2(180.0, 55.0)        # 源 :34 createSWButton setup_button 180×55
const SETUP_BTN_POS: Vector2 = Vector2(20.0, 285.0)         # 源 setup_button ccp(200,buttonHeight-height-60)
const LANG_BTN_POS: Vector2 = Vector2(220.0, 280.0)         # 源 language_button ccp(162,..) 100×60 图标
const LANG_BTN_SIZE: Vector2 = Vector2(100.0, 60.0)
const LANG_LABEL_POS: Vector2 = Vector2(330.0, 300.0)       # 源 language_label ccp(250,..)
const LANG_ICON_DIR: String = "res://assets/ui/alpha/HVGA/lang/"   # 源 getLanguagePng :71
const LANG_LABEL_COLOR: Color = Color(220.0 / 255.0, 176.0 / 255.0, 103.0 / 255.0)  # 源 :967 ccc3(220,176,103)
const INFO_COLOR: Color = Color(219.0 / 255.0, 196.0 / 255.0, 126.0 / 255.0)

var _pd: PlayerData
var _cm: ConfigManager


# 入口（照源 statusbar:313-322 headIcon→configure）：main_scene head 点击调。
static func open(parent: Control) -> void:
	var panel := ConfigurePanel.new("configure", {})
	panel.setup_panel(GameData.player, GameData.config)
	panel.show_window(parent)


func setup_panel(p_pd: PlayerData, p_cm: ConfigManager) -> void:
	_pd = p_pd
	_cm = p_cm
	setup()
	_build_ui()


func _build_ui() -> void:
	shade_layer.gui_input.connect(_on_shade_input)
	var frame := _make_frame()
	container.add_child(frame)
	var close: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS_RES, CLOSE_POS)
	close.pressed.connect(remove_window)
	container.add_child(close)
	_add_head(frame)
	_add_player_info(frame)
	frame.add_child(_make_btn(CHANGE_NAME_POS, "CONFIGURE.CHANGE_NICKNAME", _on_change_name))
	frame.add_child(_make_btn(CHANGE_HEAD_POS, "CONFIGURE.CHANGE_AVATAR", _on_change_head))
	frame.add_child(_make_btn_raw(SAVE_MANAGER_POS, "存档管理", _on_save_manager))
	_add_sw_buttons(frame)


# createSWButton 单机化（源 :719-1061）：setup_button 系统设置 + language_button 语言（裁换服/Facebook/官网）。
func _add_sw_buttons(frame: Control) -> void:
	# setup_button 系统设置（源 :739 sell_number_button 180×55 → doClickSetupButton:1399 notification.create，
	# 目标无 notification 面板单机化 Toast 占位）。
	var setup_btn: Button = UiScale9Button.make(BTN_RES, BTN_PRESS_RES, SETUP_BTN_POS, SETUP_BTN_SIZE, BTN_CAP, _lbl("CONFIGURE.SYSTEM.SETTING"), BTN_LABEL_COLOR)
	setup_btn.pressed.connect(_on_setup)
	frame.add_child(setup_btn)
	# language_button 语言（源 :926 Sprite getLanguagePng(currentLang) 100×60 + :955 label CONFIGURE.LANGUAGE
	# → :1522 languagechange.create）。目标图标按钮 → LanguageChangePanel。
	var lang_key: String = "zh-CN"
	var lm: LanguageManager = _get_lang()
	if lm != null:
		lang_key = lm.get_language()
	var lang_btn := TextureButton.new()
	lang_btn.texture_normal = load(LANG_ICON_DIR + lang_key + ".png")
	lang_btn.ignore_texture_size = true
	lang_btn.size = LANG_BTN_SIZE
	lang_btn.position = LANG_BTN_POS
	lang_btn.pressed.connect(_on_language)
	frame.add_child(lang_btn)
	var lang_lbl := Label.new()
	lang_lbl.text = _lbl("CONFIGURE.LANGUAGE")
	lang_lbl.position = LANG_LABEL_POS
	lang_lbl.add_theme_font_size_override("font_size", 20)
	lang_lbl.add_theme_color_override("font_color", LANG_LABEL_COLOR)
	lang_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(lang_lbl)


func _make_frame() -> NinePatchRect:
	var frame := NinePatchRect.new()
	var frame_tex: Texture2D = load(FRAME_TEX)
	frame.texture = frame_tex
	frame.patch_margin_left = int(FRAME_CAP.position.x)
	frame.patch_margin_top = int(FRAME_CAP.position.y)
	if frame_tex != null:
		frame.patch_margin_right = int(frame_tex.get_width() - FRAME_CAP.position.x - FRAME_CAP.size.x)
		frame.patch_margin_bottom = int(frame_tex.get_height() - FRAME_CAP.position.y - FRAME_CAP.size.y)
	frame.size = FRAME_SIZE
	frame.position = FRAME_POS
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return frame


func _make_btn(pos: Vector2, lstr_key: String, handler: Callable) -> Button:
	var btn: Button = UiScale9Button.make(BTN_RES, BTN_PRESS_RES, pos, BTN_SIZE, BTN_CAP, _lbl(lstr_key), BTN_LABEL_COLOR)
	btn.pressed.connect(handler)
	return btn


func _make_btn_raw(pos: Vector2, raw_label: String, handler: Callable) -> Button:
	var btn: Button = UiScale9Button.make(BTN_RES, BTN_PRESS_RES, pos, BTN_SIZE, BTN_CAP, raw_label, BTN_LABEL_COLOR)
	btn.pressed.connect(handler)
	return btn


func _add_head(frame: Control) -> void:
	var head_bg := TextureRect.new()
	head_bg.texture = load(HEAD_BG_RES)
	head_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head_bg.size = HEAD_SIZE
	head_bg.position = HEAD_POS
	head_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(head_bg)
	var vip_idx: int = 1 if _pd.vip_level > 0 else 0
	var head_frame := TextureRect.new()
	head_frame.texture = load(HEAD_FRAME_RES[vip_idx])
	head_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head_frame.size = HEAD_SIZE
	head_frame.position = HEAD_POS + Vector2(15.0, 0.0)
	head_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(head_frame)
	_add_head_icon(frame)


# 源 createHeadIcon（configure.lua:79-86）+ getHeadIcon（resource_manager.lua:996-1015）：
# avatar id（0→默认 1，player.lua:378）→ Avatar[id].Picture → load 头像图 + portrait_mask shader 裁剪
# （源 createClippingNode(res, main_head_mask.png) 圆形 mask）→ addChild z=3。ranklist 路径转换范式复用。
func _add_head_icon(frame: Control) -> void:
	var avatar_id: int = _pd.avatar if _pd.avatar > 0 else 1
	var pic: String = String(_cm.get_raw_table(&"Avatar").get(str(avatar_id), {}).get("Picture", ""))
	if pic.is_empty():
		return
	var head_path: String = "res://assets/ui/" + pic.substr(3)   # UI/HERO/X.jpg → assets/ui/HERO/X.jpg
	if not ResourceLoader.exists(head_path):
		return
	var icon := TextureRect.new()
	icon.texture = load(head_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = HEAD_ICON_SIZE
	icon.position = HEAD_ICON_POS
	icon.z_index = 3   # 源 createHeadIcon addChild z=3（configure.lua:83）
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()   # 源 createClippingNode mask 裁剪（resource_manager.lua:650）
	mat.shader = PortraitMaskShader
	mat.set_shader_parameter("mask_tex", load(HEAD_MASK_RES))
	icon.material = mat
	frame.add_child(icon)


func _add_player_info(frame: Control) -> void:
	var name_bg := TextureRect.new()
	name_bg.texture = load(NAME_BG_RES)
	name_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	name_bg.size = NAME_BG_SIZE
	name_bg.position = NAME_BG_POS
	name_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(name_bg)
	var name_lbl := Label.new()
	name_lbl.text = _pd.player_name
	name_lbl.position = NAME_POS
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(name_lbl)
	frame.add_child(_make_info_line(0, "%s %d" % [_lbl("ANNOUNCE.TEAM_RATING_"), _pd.team_level]))
	frame.add_child(_make_info_line(1, "%s %d/%d" % [_lbl("CONFIGURE.TEAM_EXPERIENCE_"), _pd.team_exp, _pd._exp_to_next()]))
	frame.add_child(_make_info_line(2, "%s %d" % [_lbl("PLAYERLEVELDISPLAY.HERO_LEVEL_LIMIT_"), _pd.MAX_TEAM_LEVEL]))


func _make_info_line(idx: int, text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = INFO_POS + Vector2(0.0, INFO_LINE_H * float(idx))
	lbl.add_theme_font_size_override("font_size", 19)
	lbl.add_theme_color_override("font_color", INFO_COLOR)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _on_change_name() -> void:
	var panel := NameInputPanel.new("name_input", {})
	panel.setup_panel(_pd)
	panel.show_window(get_parent())


func _on_change_head() -> void:
	var panel := AvatarPanel.new("avatar", {})
	panel.setup_panel(_pd, _cm)
	panel.show_window(get_parent())


func _on_save_manager() -> void:
	Toast.show_message("存档导出/导入（换机迁移）单机版暂缓")


# 源 doClickSetupButton:1399 → notification.create()（通知/系统设置面板）。目标单机化无 → Toast 占位。
func _on_setup() -> void:
	Toast.show_message("系统通知（联机推送）单机版暂缓")


# 源 language_button → :1522 languagechange.create()。目标 LanguageChangePanel（i18n 闭环）。
func _on_language() -> void:
	var lm: LanguageManager = _get_lang()
	if lm == null:
		return
	var panel := LanguageChangePanel.new()
	panel.setup_panel(lm)
	panel.show_window(get_parent())


func _get_lang() -> LanguageManager:
	var lm: Variant = _cm.get("_lang")
	return lm if lm is LanguageManager else null


func _lbl(key: String) -> String:
	return _cm.get_lstr(key)


func _on_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			remove_window()
