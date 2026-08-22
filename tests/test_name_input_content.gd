extends GutTest

# NameInputPanel 两件套守卫测试（批 4 Task 2，2026-08-17）。
# 照源 ui/popwindow/bename.lua（434 行）：
#   frame main_vit_tips cap(10,10,58,26) setContentSize(355,180) 中心(400,355)；
#   readnode root=frame（:294）→ 子节点 frame 局部左下原点点值直译（y' = 180-y）；
#   title size20（:148-159）/ name_bg activate_input cap(12,10,12,22) 235x42（:160-174）/
#   roll 骰子钮（:175-198）/ ok/cancel sell_number_button cap(15,22,15,25) 110x45
#   中心(235,35)/(115,35)（:199-292）/ edit CCLabelTTF 22 号 ccc3(198,175,126)（:32-48）。
#   源无 close 节点（点 frame 外=取消 → PopWindow shade 等价）、弹窗内无字数提示
#   Label（超长走 Toast，brief 该点与源不符从源）。
# 贴图 PIL 实测（2026-08-17，均无 TextureConfig 条目）：main_vit_tips 103x61、
# activate_input 47x55、naming_button_roll_1/2 80x75（显示 = 80x75/CS1.28125）。
# 守卫：静态树 rect / NinePatch cap 公式（top/bottom 防反写）/ frame 局部直译 /
# global 级防 parenting / 绘制序（edit 后声明盖 name_bg）/ variation 接线（复用
# SB_pkg_hb_n/p 同图同 cap）/ panel fill 语义（空名 roll 照源 createEdit / 超长
# 拒绝照源 doSetName :394-399）。

const CONTENT_PATH: String = "res://scenes/ui/name_input_content.tscn"
const PANEL_PATH: String = "res://scripts/ui/name_input_panel.gd"
const THEME_PATH: String = "res://resources/themes/default_theme.tres"
const AFFIXCOUNT_PATH: String = "res://resources/data/AffixCount.json"
# 源 name 长度上限（:395-398 gsub UTF-8 首字节计数 = 字符数 > 13 拒绝）
const NAME_MAX_LENGTH: int = 13
# main_vit_tips 103x61，scaleSize(355,180) 中心(400,355) → Godot 中心(480,205)
const FRAME_L: float = 222.5
const FRAME_T: float = 35.0
const FRAME_W: float = 355.0
const FRAME_H: float = 180.0
# naming_button_roll 80x75 → /CS = 62.44x58.54（与源 hit 区 :83 62x59 吻合）
const ROLL_W: float = 62.44
const ROLL_H: float = 58.54
# 源 ok/cancel scaleSize 直译
const BTN_W: float = 110.0
const BTN_H: float = 45.0

var _cm: ConfigManager


func before_all() -> void:
	_cm = ConfigManager.new()
	_cm.load_all()


# ── content 静态树（源 :141-295 readnode root=frame → 子节点挂 Frame 局部坐标）──

func test_content_static_tree() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	# Frame（源 Scale9 main_vit_tips scaleSize(355,180) 中心(400,355) →
	# Godot 中心 (480,205) → 左上 (480-177.5, 205-90)）
	var frame: NinePatchRect = inst.get_node("%Frame") as NinePatchRect
	assert_almost_eq(frame.offset_left, FRAME_L, 0.1, "Frame 左 = to_godot(400,355).x - 355/2")
	assert_almost_eq(frame.offset_top, FRAME_T, 0.1, "Frame 顶 = to_godot(400,355).y - 180/2")
	assert_almost_eq(frame.offset_right - frame.offset_left, FRAME_W, 0.1, "Frame 宽 = 源 setContentSize 直译")
	assert_almost_eq(frame.offset_bottom - frame.offset_top, FRAME_H, 0.1, "Frame 高 = 源 setContentSize 直译")
	assert_eq(frame.texture.resource_path, "res://assets/ui/alpha/HVGA/main_vit_tips.png",
		"Frame 贴图照源 main_vit_tips")
	# cap(10,10,58,26) 批 1 公式（贴图 103x61）：left=10 top=61-10-26=25
	# right=103-10-58=35 bottom=10（改造前 top/bottom 写反，批内通病）
	assert_eq(frame.patch_margin_left, 10, "NinePatch left = cap.x")
	assert_eq(frame.patch_margin_top, 25, "NinePatch top = H-y-h = 61-10-26（防反写回归）")
	assert_eq(frame.patch_margin_right, 35, "NinePatch right = W-x-w = 103-10-58（水平不反转）")
	assert_eq(frame.patch_margin_bottom, 10, "NinePatch bottom = cap.y（防反写回归）")
	# NameBg（源 activate_input cap(12,10,12,22) scaleSize(235,42) frame 局部
	# (30,95) anchor(0,0.5) → 局部左中 (30, 180-95=85)）
	var name_bg: NinePatchRect = inst.get_node("%NameBg") as NinePatchRect
	assert_eq(name_bg.get_parent(), frame, "NameBg 挂 Frame 子树（源 readnode root=frame）")
	assert_almost_eq(name_bg.offset_left, 30.0, 0.1, "NameBg 左 = 源 frame 局部 x=30（anchor 0,0.5 左缘）")
	assert_almost_eq(name_bg.offset_top, 64.0, 0.1, "NameBg 顶 = 85-42/2（y'=180-95 中心）")
	assert_almost_eq(name_bg.offset_right - name_bg.offset_left, 235.0, 0.1, "NameBg 宽 = 源 scaleSize 直译")
	assert_almost_eq(name_bg.offset_bottom - name_bg.offset_top, 42.0, 0.1, "NameBg 高 = 源 scaleSize 直译")
	# cap(12,10,12,22) 批 1 公式（贴图 47x55）：left=12 top=55-10-22=23
	# right=47-12-12=23 bottom=10
	assert_eq(name_bg.patch_margin_left, 12, "NameBg cap left = 12")
	assert_eq(name_bg.patch_margin_top, 23, "NameBg cap top = H-y-h = 55-10-22（防反写回归）")
	assert_eq(name_bg.patch_margin_right, 23, "NameBg cap right = W-x-w = 47-12-12")
	assert_eq(name_bg.patch_margin_bottom, 10, "NameBg cap bottom = cap.y = 10（防反写回归）")
	assert_eq(name_bg.mouse_filter, Control.MOUSE_FILTER_IGNORE, "NameBg 装饰层不吞点击")
	# RollBtn（源 roll Sprite frame 局部(300,95) 中心锚，80x75/CS 显示）
	var roll_btn: TextureButton = inst.get_node("%RollBtn") as TextureButton
	assert_eq(roll_btn.get_parent(), frame, "RollBtn 挂 Frame 子树")
	assert_almost_eq(roll_btn.offset_left + roll_btn.size.x * 0.5, 300.0, 0.1,
		"RollBtn 中心 x = 源 frame 局部 300 直译")
	assert_almost_eq(roll_btn.offset_top + roll_btn.size.y * 0.5, 85.0, 0.1,
		"RollBtn 中心 y = 180-95（y' 翻转）")
	assert_almost_eq(roll_btn.size.x, ROLL_W, 0.1, "RollBtn 宽 = 80/CS（非原始像素）")
	assert_almost_eq(roll_btn.size.y, ROLL_H, 0.1, "RollBtn 高 = 75/CS（与源 hit 区 62x59 吻合）")
	assert_eq(roll_btn.texture_normal.resource_path,
		"res://assets/ui/alpha/HVGA/naming_button_roll_1.png", "normal 照源 roll")
	assert_eq(roll_btn.texture_pressed.resource_path,
		"res://assets/ui/alpha/HVGA/naming_button_roll_2.png",
		"源 roll_press Sprite visible 切换 → texture_pressed 等价（受控裁剪）")
	assert_eq(roll_btn.stretch_mode, TextureButton.STRETCH_SCALE,
		"TextureButton stretch_mode=0 显式（默认 KEEP 不填 rect，批 2 方法论）")
	# OkBtn/CancelBtn（源 Scale9 sell_number_button 110x45 中心(235,35)/(115,35)）
	var ok_btn: Button = inst.get_node("%OkBtn") as Button
	assert_eq(ok_btn.get_parent(), frame, "OkBtn 挂 Frame 子树")
	assert_almost_eq(ok_btn.offset_left + BTN_W * 0.5, 235.0, 0.1, "OkBtn 中心 x = 源 frame 局部 235")
	assert_almost_eq(ok_btn.offset_top + BTN_H * 0.5, 145.0, 0.1, "OkBtn 中心 y = 180-35（y' 翻转）")
	assert_almost_eq(ok_btn.size.x, BTN_W, 0.1, "OkBtn 宽 = 源 scaleSize 直译")
	assert_almost_eq(ok_btn.size.y, BTN_H, 0.1, "OkBtn 高 = 源 scaleSize 直译")
	assert_eq(String(ok_btn.theme_type_variation), "NameInputButton",
		"OkBtn 九宫格三态走 NameInputButton variation（禁运行时 stylebox override）")
	var cancel_btn: Button = inst.get_node("%CancelBtn") as Button
	assert_almost_eq(cancel_btn.offset_left + BTN_W * 0.5, 115.0, 0.1,
		"CancelBtn 中心 x = 源 frame 局部 115")
	assert_almost_eq(cancel_btn.offset_top + BTN_H * 0.5, 145.0, 0.1, "CancelBtn 中心 y = 180-35")
	assert_eq(String(cancel_btn.theme_type_variation), "NameInputButton", "CancelBtn 同款 variation")
	# Input（源 edit CCLabelTTF frame 局部(40,95) anchor(0,0.5) → 左中 (40,85)；
	# 高 32 给足 22 号 min 行高，rect 中心恒 85）
	var input: LineEdit = inst.get_node("%Input") as LineEdit
	assert_eq(input.get_parent(), frame, "Input 挂 Frame 子树（源 ui.bg:addChild）")
	assert_almost_eq(input.offset_left, 40.0, 0.1, "Input 左 = 源 frame 局部 x=40（name_bg 内缩 10）")
	assert_almost_eq(input.offset_top + input.size.y * 0.5, 85.0, 0.1, "Input 垂直中心 = 180-95")
	assert_eq(String(input.theme_type_variation), "NameInputLabel",
		"Input 走 NameInputLabel variation（22 号 ccc3(198,175,126) + 透明底）")
	# Title（源 Label size20 frame 局部(30,150) anchor(0,0.5) → 左中 (30,30)；
	# vertical_alignment center + rect 中心 30 对字号变化稳健）
	var title: Label = inst.get_node("%Title") as Label
	assert_almost_eq(title.position.x, 30.0, 0.1, "Title 左 = 源 frame 局部 x=30")
	assert_almost_eq(title.position.y + title.size.y * 0.5, 30.0, 0.1, "Title 垂直中心 = 180-150")
	assert_eq(String(title.theme_type_variation), "NameInputTitleLabel", "Title 走 variation（20 号白）")
	assert_eq(title.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Title 装饰不吞点击")


# global 级防 parenting（frame 局部→全屏）：frame 左上 (302.5,115) + 局部中心。
func test_global_position_guard() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	await get_tree().process_frame
	var ok_btn: Control = inst.get_node("%OkBtn") as Control
	assert_almost_eq(ok_btn.global_position.x + ok_btn.size.x * 0.5, 457.5, 0.5,
		"OkBtn 全屏中心 x = 302.5+235（frame 局部→全屏防 parenting 错位）")
	assert_almost_eq(ok_btn.global_position.y + ok_btn.size.y * 0.5, 180.0, 0.5,
		"OkBtn 全屏中心 y = 115+145")
	var roll_btn: Control = inst.get_node("%RollBtn") as Control
	assert_almost_eq(roll_btn.global_position.x + roll_btn.size.x * 0.5, 522.5, 0.5,
		"RollBtn 全屏中心 x = 302.5+300")
	assert_almost_eq(roll_btn.global_position.y + roll_btn.size.y * 0.5, 120.0, 0.5,
		"RollBtn 全屏中心 y = 115+85")


# 绘制序守卫：源 readnode 声明序 title→name_bg→roll→ok→cancel（:146-292）+
# edit 后挂（createEdit :301 在 readNode :294 之后）→ Input 收尾声明盖 name_bg。
func test_draw_order() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	var frame: Node = inst.get_node("%Frame")
	var order: Array = []
	for i in range(frame.get_child_count()):
		order.append(String(frame.get_child(i).name))
	assert_eq(order, ["Title", "NameBg", "RollBtn", "OkBtn", "CancelBtn", "Input"],
		"子序照源声明序（readnode 序 + edit 最后盖 name_bg）")


# theme variation 接线（GUT 下节点级不解析 variation，读 tres 文本表项）。
# ok/cancel 复用 SB_pkg_hb_n/p（sell_number_button 同图同 cap(15,22,15,25) 先例）。
func test_theme_variation_wired() -> void:
	var t: String = FileAccess.get_file_as_string(THEME_PATH)
	assert_true(t.contains("NameInputTitleLabel/base_type = &\"Label\""),
		"NameInputTitleLabel variation 注册")
	assert_true(t.contains("NameInputTitleLabel/font_sizes/font_size = 20"),
		"Title 字号 20（源 size=20）")
	assert_true(t.contains("NameInputLabel/base_type = &\"LineEdit\""),
		"NameInputLabel variation 注册（LineEdit 首个 variation）")
	assert_true(t.contains("NameInputLabel/font_sizes/font_size = 22"),
		"Input 字号 22（源 CCLabelTTF 22）")
	assert_true(t.contains("NameInputLabel/colors/font_color = Color(0.776471, 0.686275, 0.494118, 1)"),
		"Input 字色 = 198,175,126（/255）")
	assert_true(t.contains("NameInputButton/base_type = &\"Button\""),
		"NameInputButton variation 注册")
	assert_true(t.contains("NameInputButton/font_sizes/font_size = 17"),
		"按钮字号 17（源 fontinfo ui_normal_button size=17）")
	assert_true(t.contains("NameInputButton/colors/font_color = Color(0.921569, 0.882353, 0.803922, 1)"),
		"按钮字色 = 235,225,205（源 config.color 覆盖 fontinfo 默认白）")
	assert_true(t.contains("NameInputButton/styles/normal = SubResource(\"SB_pkg_hb_n\")"),
		"按钮 normal 复用 SB_pkg_hb_n（sell_number cap(15,22,15,25) 同图同 cap）")
	assert_true(t.contains("NameInputButton/styles/pressed = SubResource(\"SB_pkg_hb_p\")"),
		"按钮 pressed 复用 SB_pkg_hb_p（sell_number_button_down）")


# panel 静态构造白名单（宽口径）：静态结构全在 tscn，panel 内应零 .new(。
func test_panel_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_eq(text.count(".new("), 0,
		"panel .new( = 0（Scale9 运行时套样式已退役，按钮静态化进 tscn+theme）")


# ── panel fill 语义（源 createEdit :32-48 + doSetName :383-409）──

# Title/Button 文案走 LSTR（源 T(LSTR(...))）；空名 roll 随机名
# （源 :39-47 无 GC 昵称 → rollName，单机化等价）。
func test_panel_fill_semantics() -> void:
	var pd := PlayerData.new(_cm)
	pd.player_name = ""
	var panel: NameInputPanel = NameInputPanel.new()
	panel.setup_panel(pd)
	add_child_autofree(panel)
	var title: Label = panel._content.get_node("%Title") as Label
	assert_eq(title.text, _cm.get_lstr("BENAME.A_NAME_FOR_YOUR_TEAM_"),
		"Title 文案照源 LSTR（非硬编码）")
	assert_eq((panel._content.get_node("%OkBtn") as Button).text,
		_cm.get_lstr("CHATCONFIG.CONFIRM"), "OkBtn 文案 = 源 ok_label CHATCONFIG.CONFIRM")
	assert_eq((panel._content.get_node("%CancelBtn") as Button).text,
		_cm.get_lstr("CHATCONFIG.CANCEL"), "CancelBtn 文案 = 源 cancel_label CHATCONFIG.CANCEL")
	var affixcount: Array = JSON.parse_string(FileAccess.get_file_as_string(AFFIXCOUNT_PATH)) as Array
	assert_true(affixcount.has(panel._input.text) and panel._input.text != "",
		"空名 → roll 随机名照源 createEdit（affixcount 词库 5356 项）")


# 既有名直显不 roll（源 uname 非空分支：GC 名/现名优先）。
func test_panel_fill_existing_name_kept() -> void:
	var pd := PlayerData.new(_cm)
	pd.player_name = "OldName"
	var panel: NameInputPanel = NameInputPanel.new()
	panel.setup_panel(pd)
	add_child_autofree(panel)
	assert_eq(panel._input.text, "OldName", "既有名直显（源 :40-41 string.len(uname)>0 不 roll）")


# 确认校验照源 doSetName：空名 toast 拒绝（:384-387）、超 13 字符拒绝
# （:393-399 gsub 首字节计数 = 字符数）；合法名 set + mark dirty + 关窗。
func test_confirm_validation() -> void:
	var pd := PlayerData.new(_cm)
	pd.player_name = "OldName"
	var panel: NameInputPanel = NameInputPanel.new()
	panel.setup_panel(pd)
	add_child_autofree(panel)
	# 空名拒绝
	panel._input.text = ""
	panel._on_confirm()
	assert_eq(pd.player_name, "OldName", "空名不落盘（源 PLEASE_ENTER_A_NAME toast 分支）")
	# 超 13 字符拒绝（源 :395-398 count > 13）
	panel._input.text = "a".repeat(NAME_MAX_LENGTH + 1)
	panel._on_confirm()
	assert_eq(pd.player_name, "OldName", "超 13 字符不落盘（源 NAME_CAN_NOT_EXCEED 拒绝分支）")
	# 13 字符边界放行（源 > 13 才拒，13 合法）
	panel._input.text = "b".repeat(NAME_MAX_LENGTH)
	panel._on_confirm()
	assert_eq(pd.player_name, "b".repeat(NAME_MAX_LENGTH),
		"13 字符边界放行（源 > 13 才拒）")


# roll 按钮 fill 接线：pressed 后名字来自词库（源 doClickRoll → rollName :9-16）。
func test_roll_signal_wired() -> void:
	var pd := PlayerData.new(_cm)
	pd.player_name = "Keep"
	var panel: NameInputPanel = NameInputPanel.new()
	panel.setup_panel(pd)
	add_child_autofree(panel)
	(panel._content.get_node("%RollBtn") as BaseButton).pressed.emit()
	var affixcount: Array = JSON.parse_string(FileAccess.get_file_as_string(AFFIXCOUNT_PATH)) as Array
	assert_true(affixcount.has(panel._input.text), "roll 信号接线 → 名字来自 affixcount 词库")
