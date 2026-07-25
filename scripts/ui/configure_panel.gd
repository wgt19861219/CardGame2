class_name ConfigurePanel
extends PopWindow

const UiScale9Button := preload("res://scripts/ui/ui_scale9_button.gd")

## 设置面板（View 层）— 照源 popwindow/configure.lua createWindow:1062-1316 + createSWButton:719-1061。
## 名字 + 玩家信息 + change_name/change_head/save_manager + setup_button 系统设置 + language_button 语言。
## 单机化裁剪（联机）：createSociety 公会 / createLogoffButton 登出 / createGoogleConnectButton /
## create360Buttons / createSWButton 换服 select_server+Facebook support/web / 玩家信息账号 ID getUserid。
##
## 重构（2026-07-18，照 hero_detail 范式）：chrome（frame/close/head_bg/head_frame/name_bg/name_label/
## 3 info_line/3 Scale9 action 按钮/setup_button/lang_button/lang_label）静态化进 configure_content.tscn
## （位置/size 编辑器可视化调）。head_icon 走 avatar+portrait_mask shader 完全动态，保留 procedural 挂
## %HeadIconHost（位置静态化进 .tscn，icon 局部 pos=0,0）。Scale9 按钮套 _make_sb
## 补九宫格视觉（位置 .tscn，纹理/label fill）。坐标：源 Cocos ccp(左下) → _to_godot - FRAME_POS（frame 内），
## 本重构将所有坐标 + FRAME_POS(224,105) 一次性写死进 .tscn 全屏系。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/configure_content.tscn")
const HEAD_FRAME_RES: Array = [
	"res://assets/ui/alpha/HVGA/main_head_frame_silver.png",
	"res://assets/ui/alpha/HVGA/main_head_frame_gold.png",
]
const HEAD_ICON_SIZE: Vector2 = Vector2(70.0, 70.0)
const HEAD_MASK_RES: String = "res://assets/ui/alpha/HVGA/main_head_mask.png"
const PortraitMaskShader: Shader = preload("res://shaders/portrait_mask.gdshader")
const BTN_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button.png"
const BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button_down.png"
const BTN_CAP: Rect2 = Rect2(15.0, 22.0, 15.0, 25.0)
const LANG_ICON_DIR: String = "res://assets/ui/alpha/HVGA/lang/"
const DEFAULT_LANG_KEY: String = "zh-CN"

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
	_build_content()


# 建 UI 内容：chrome 从 .tscn instantiate（位置/size 可视化）；动态 fill head_frame texture（vip）/
# head_icon（avatar shader，procedural 挂 %HeadIconHost）/name_label.text/3 info_line text/
# 4 Scale9 按钮（apply_with_label 套九宫格 + i18n label）/lang_btn 纹理 + label。
func _build_content() -> void:
	shade_layer.gui_input.connect(_on_shade_input)
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	# head_frame texture 走 vip（源 :1206-1207 head_frame level 颜色 silver/gold）
	var vip_idx: int = 1 if _pd.vip_level > 0 else 0
	(content.get_node("%HeadFrame") as TextureRect).texture = load(HEAD_FRAME_RES[vip_idx])
	_add_head_icon(content.get_node("%HeadIconHost") as Control)
	(content.get_node("%NameLabel") as Label).text = _pd.player_name
	_fill_info_line(content, 0, "%s %d" % [_lbl("ANNOUNCE.TEAM_RATING_"), _pd.team_level])
	_fill_info_line(content, 1, "%s %d/%d" % [_lbl("CONFIGURE.TEAM_EXPERIENCE_"), _pd.team_exp, _pd._exp_to_next()])
	_fill_info_line(content, 2, "%s %d" % [_lbl("PLAYERLEVELDISPLAY.HERO_LEVEL_LIMIT_"), _pd.MAX_TEAM_LEVEL])
	_apply_scale9_btn(content.get_node("%ChangeNameBtn") as Button, _lbl("CONFIGURE.CHANGE_NICKNAME"), _on_change_name)
	_apply_scale9_btn(content.get_node("%ChangeHeadBtn") as Button, _lbl("CONFIGURE.CHANGE_AVATAR"), _on_change_head)
	_apply_scale9_btn(content.get_node("%SaveManagerBtn") as Button, "存档管理", _on_save_manager)
	_apply_scale9_btn(content.get_node("%SetupBtn") as Button, _lbl("CONFIGURE.SYSTEM.SETTING"), _on_setup)
	# language_button 图标（源 :926 getLanguagePng(currentLang) 100×60）→ LanguageChangePanel
	var lang_key: String = DEFAULT_LANG_KEY
	var lm: LanguageManager = _get_lang()
	if lm != null:
		lang_key = lm.get_language()
	(content.get_node("%LangBtn") as TextureButton).texture_normal = load(LANG_ICON_DIR + lang_key + ".png")
	(content.get_node("%LangBtn") as BaseButton).pressed.connect(_on_language)
	(content.get_node("%LangLabel") as Label).text = _lbl("CONFIGURE.LANGUAGE")


# avatar id（0→默认 1，player.lua:378）→ Avatar[id].Picture → load 头像图 + portrait_mask shader 裁剪
# （源 createClippingNode(res, main_head_mask.png) 圆形 mask）→ addChild z=3。host 已在 HEAD_ICON_POS，
# icon 局部 pos=0,0（范式「子组件挂 host pos=0,0」）。ranklist 路径转换范式复用。
func _add_head_icon(host: Control) -> void:
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
	icon.position = Vector2.ZERO   # host 已在 HEAD_ICON_POS，icon 局部原点
	icon.z_index = 3
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PortraitMaskShader
	mat.set_shader_parameter("mask_tex", load(HEAD_MASK_RES))
	icon.material = mat
	host.add_child(icon)


func _fill_info_line(content: Node, idx: int, text: String) -> void:
	(content.get_node("%InfoLine" + str(idx + 1)) as Label).text = text


# .tscn 普通 Button 套 Scale9 StyleBox（sell_number_button + cap 15,22,15,25）+ i18n label + 绑信号。
# 位置/size .tscn 已固化（4 按钮共用 BTN_RES/cap，setup_btn 仅 size 180×55 不同，cap 一致）。
# fill 独立 Label 子节点 %XxxLabel（Button.text 内嵌 label 受 stylebox content_margin 干扰字偏左上，
# 改独立 Label anchors_preset=15 full_rect + horizontal/vertical_alignment=1 稳定居中，范式同 hero_detail）。
# Label 字色/阴影已在 .tscn 静态声明（照源 sell_number_button 文字 浅米色 + 黑描边），不在此覆盖。
func _apply_scale9_btn(btn: Button, label_text: String, handler: Callable) -> void:
	btn.add_theme_stylebox_override("normal", UiScale9Button._make_sb(BTN_RES, BTN_CAP))
	btn.add_theme_stylebox_override("hover", UiScale9Button._make_sb(BTN_RES, BTN_CAP))
	btn.add_theme_stylebox_override("pressed", UiScale9Button._make_sb(BTN_PRESS_RES, BTN_CAP))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# fill 独立 Label 子节点（.tscn 已建 %XxxLabel，命名规则 XxxBtn → XxxLabel）
	var label_name: String = btn.name.replace("Btn", "Label")
	var lbl: Label = btn.get_node_or_null(label_name)
	if lbl != null:
		lbl.text = label_text
	btn.pressed.connect(handler)


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


func _on_setup() -> void:
	Toast.show_message("系统通知（联机推送）单机版暂缓")


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
