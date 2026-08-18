class_name ConfigurePanel
extends PopWindow

## 设置面板（View 层）— 照源 popwindow/configure.lua createWindow:1062-1316 + createSWButton:719-1061。
## 名字 + 玩家信息 + change_name/change_head/save_manager + setup_button 系统设置 + language_button 语言。
## 单机化裁剪（联机）：createSociety 公会 / createLogoffButton 登出 / createGoogleConnectButton /
## create360Buttons / createSWButton 换服 select_server+Facebook support/web / 玩家信息账号 ID getUserid。
##
## 完整树化（批 4 Task 10，2026-08-18，照 avatar/ladder 范式）：全部静态结构（frame/close/头区/
## name/info/4 Scale9 按钮/3 分隔线/lang 底排）进 configure_content.tscn，坐标照源直译（换算依据
## 见 tscn 头注释）。panel 只做业务 + 信号 connect + fill：head_frame texture（vip）/
## head_icon（avatar shader，procedural 挂 %HeadIconHost）/name/3 info_line/按钮 label/lang 纹理。
## Scale9 按钮样式 2026-07-18 用 _make_sb 运行时套 → 收敛 ConfigureActionBtn variation
## （同图同 cap 复用 theme SB_pkg_hb_n/p），Scale9 按钮工厂依赖退役。
## 单机化重排（受控偏离，tscn 注释记录）：language_button 源 debug_mode 隐藏（:1052-1056），
## 单机版语言切换为正式功能 → 占被裁 select_server 底排位。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/configure_content.tscn")
const HEAD_FRAME_RES: Array = [
	"res://assets/ui/alpha/HVGA/main_head_frame_silver.png",
	"res://assets/ui/alpha/HVGA/main_head_frame_gold.png",
]
const HEAD_ICON_SIZE: Vector2 = Vector2(70.0, 70.0)
const HEAD_MASK_RES: String = "res://assets/ui/alpha/HVGA/main_head_mask.png"
const PortraitMaskShader: Shader = preload("res://shaders/portrait_mask.gdshader")
const LANG_ICON_DIR: String = "res://assets/ui/alpha/HVGA/lang/"
const DEFAULT_LANG_KEY: String = "zh-CN"
const LSTR_LEVEL_CAP: String = "CONFIGURE.HAS_REACHED_THE_LEVEL_CAP"

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


# fill 动态内容（静态树 .tscn）：head_frame texture 走 vip（源 :1206-1207 silver/gold）/
# head_icon（avatar shader，procedural 挂 %HeadIconHost）/name/3 info_line 文案/
# 4 按钮 label + 信号/lang_btn 纹理 + label。样式全部 .tscn + theme variation 静态化。
func _build_content() -> void:
	shade_layer.gui_input.connect(_on_shade_input)
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	var vip_idx: int = 1 if _pd.vip_level > 0 else 0
	(content.get_node("%HeadFrame") as TextureRect).texture = load(HEAD_FRAME_RES[vip_idx])
	_add_head_icon(content.get_node("%HeadIconHost") as Control)
	(content.get_node("%NameLabel") as Label).text = _pd.player_name
	_fill_info_lines(content)
	_bind_action_btn(content.get_node("%ChangeNameBtn") as Button, _lbl("CONFIGURE.CHANGE_NICKNAME"), _on_change_name)
	_bind_action_btn(content.get_node("%ChangeHeadBtn") as Button, _lbl("CONFIGURE.CHANGE_AVATAR"), _on_change_head)
	_bind_action_btn(content.get_node("%SaveManagerBtn") as Button, "存档管理", _on_save_manager)
	_bind_action_btn(content.get_node("%SetupBtn") as Button, _lbl("CONFIGURE.SYSTEM.SETTING"), _on_setup)
	# language_button 图标（源 :926 getLanguagePng(currentLang) 100×60）→ LanguageChangePanel
	var lang_key: String = DEFAULT_LANG_KEY
	var lm: LanguageManager = _get_lang()
	if lm != null:
		lang_key = lm.get_language()
	(content.get_node("%LangBtn") as TextureButton).texture_normal = load(LANG_ICON_DIR + lang_key + ".png")
	(content.get_node("%LangBtn") as BaseButton).pressed.connect(_on_language)
	(content.get_node("%LangLabel") as Label).text = _lbl("CONFIGURE.LANGUAGE")


# avatar id（0→默认 1，player.lua:378）→ Avatar[id].Picture → load 头像图 + portrait_mask shader 裁剪
# （源 createClippingNode(res, main_head_mask.png) 圆形 mask）→ addChild z=3。host 已照源 (185,363)
# 定位进 .tscn，icon 局部 pos=0,0（范式「子组件挂 host pos=0,0」）。ranklist 路径转换范式复用。
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
	icon.position = Vector2.ZERO   # host 已照源定位，icon 局部原点
	icon.z_index = 3
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PortraitMaskShader
	mat.set_shader_parameter("mask_tex", load(HEAD_MASK_RES))
	icon.material = mat
	host.add_child(icon)


# 玩家信息 3 行（源 createPlayerInformation:120-209，title size19 金 + text 接排；账号 ID 行单机化裁剪）。
# 满级时战队等级行追加 ps（源 :130 checkLevelMax + :186-206 ps 挂 text 右侧 → 单 Label 接排近似）。
func _fill_info_lines(content: Node) -> void:
	var line1: String = "%s %d" % [_lbl("ANNOUNCE.TEAM_RATING_"), _pd.team_level]
	if _pd.team_level >= _pd.MAX_TEAM_LEVEL:
		line1 += " " + _lbl(LSTR_LEVEL_CAP)
	_fill_info_line(content, 0, line1)
	_fill_info_line(content, 1, "%s %d/%d" % [_lbl("CONFIGURE.TEAM_EXPERIENCE_"), _pd.team_exp, _pd._exp_to_next()])
	_fill_info_line(content, 2, "%s %d" % [_lbl("PLAYERLEVELDISPLAY.HERO_LEVEL_LIMIT_"), _pd.MAX_TEAM_LEVEL])


func _fill_info_line(content: Node, idx: int, text: String) -> void:
	(content.get_node("%InfoLine" + str(idx + 1)) as Label).text = text


# 动作按钮绑定：九宫格样式 .tscn 已挂 ConfigureActionBtn variation（同图同 cap 复用
# SB_pkg_hb_n/p），此处只 fill 独立 Label 子节点（%XxxLabel，命名规则 XxxBtn → XxxLabel，
# Button.text 受 stylebox content_margin 干扰不用）+ 绑 pressed。
func _bind_action_btn(btn: Button, label_text: String, handler: Callable) -> void:
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
