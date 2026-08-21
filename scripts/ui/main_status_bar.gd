class_name MainStatusBar
extends RefCounted

const UIConstants := preload("res://resources/constants/ui_constants.gd")

## 主菜单状态栏（View helper）— 照源 ui/statusbar.lua createHead:554 + createTitle:706。
## 从 main_scene 拆出重建：头像（银/金框切换 + 昵称 + VIP 角标）+ 3 货币条（图标 + 数字 + 加号按钮）。
## 替代旧裸文字 Label 占位。main_scene._build_status_bar 委托本类 + _refresh_status 更新 label。
##
## 入口接线（照源 statusbar.lua:41-68 registerTitleTouchHandler）：
## - money_bg 整条可点 → doClickMidas（gold_plus_handler，main_scene 传 _open_midas）
## - vitality 加号按钮 → buyVitality（vitality_plus_handler）
## - rmb 加号单机化裁剪（充值无单机等价；diamond_plus_handler 空→加号 IGNORE）

# 坐标基准（Task2 迁移）：statusbar 是 framework HUD 层（标准 UI），源 800×480 左下原点 →
# Godot 800×480 左上原点直译 (cx, 480-cy)，无 960×640 居中偏移；ENTRIES 是 map 装饰走
# main_scene 同口径 480-cocos_y。两者统一为源设计分辨率直译。
# 2026-08-21 用户指示贴屏幕左上角：框图（容器内 (0,13.8)~(109.3,95)）左移上移至
# 屏 (5,5) 起距 5px 边距 → 容器原点 (5,-8.8) → 容器中心 HEAD_POS=(73.5,43.7)。
# （源 head_bg_pos=ccp(winLeft+70,434) 距左 70/距顶 46，用户偏好更贴角，受控偏离；
#  贴角定位与 viewport 高无关，Task2 迁移不动。）
const HEAD_POS: Vector2 = Vector2(73.5, 43.7)
const HEAD_SIZE: Vector2 = Vector2(137.0, 105.0)
const HEAD_FRAME_RES: Array = [
	"res://assets/ui/alpha/HVGA/main_head_bg_silver.png",   # VIP=0 银色
	"res://assets/ui/alpha/HVGA/main_head_bg_gold.png",     # VIP>0 金色
]
const HEAD_FRAME_BORDER_RES: Array = [
	"res://assets/ui/alpha/HVGA/main_head_frame_silver.png",
	"res://assets/ui/alpha/HVGA/main_head_frame_gold.png",
]
const NAME_BG_RES: Array = [
	"res://assets/ui/alpha/HVGA/main_head_name_bg_silver.png",
	"res://assets/ui/alpha/HVGA/main_head_name_bg_gold.png",
]
# 头像图（源 statusbar createHead head icon：Avatar[id].Picture + 圆形 mask）。
# 2026-08-21 修复：此前 build 从未建头像图节点（只有框底/框边），换头像无从回传主界面。
const HEAD_MASK_RES: String = "res://assets/ui/alpha/HVGA/main_head_mask.png"
const PortraitMaskShader: Shader = preload("res://shaders/portrait_mask.gdshader")
const HEAD_ICON_SIZE: float = 70.0   # 照 configure._add_head_icon 同款显示尺寸
# icon 位置照源直译：head_icon_pos=ccp(40,54)（uires.lua:41，container 内中心锚、
# cocos 左下原点）→ Godot 中心 (40, 105-54)=(40,51)，左上 =(40-35, 51-35)=(5,16)。
# 头像在框左部圆窗（右侧留给等级/昵称区）。2026-08-21 修正：旧值 (33.5,15) 水平
# 居中拍脑袋致偏右 28.5 出框。
const HEAD_ICON_CENTER: Vector2 = Vector2(40.0, 51.0)   # 源锚点 (40,54) cocos → Godot 中心
# 框贴图显示尺寸照源直译（statusbar.lua:239-262 readnode：head_bg/head_frame 均
# anchor(0,0)@cocos(0,10)，无 scaleSize → 贴图 140×104px ÷CS=109.3×81.2 点尺寸显示，
# 不铺满 137×105 容器）→ Godot pos=(0, 105-10-81.2)=(0,13.8)。2026-08-21 二次修正：
# 旧实现铺满 HEAD_SIZE 拉伸 1.26×，盾窗随放大错位致头像「不在框里」。
const HEAD_BG_DISPLAY: Vector2 = Vector2(109.3, 81.2)
const HEAD_BG_POS: Vector2 = Vector2(0.0, 13.8)
# 昵称底纹（165×47px ÷CS；中心 (64,7) → Godot 中心 (64,98)，突出框下方）。
const NAME_BG_DISPLAY: Vector2 = Vector2(128.8, 36.7)
# 昵称/等级字号与色（源 :643/:661 size16 + ccc3(241,235,206)）。
const NAME_FONT_SIZE: int = 16
const NAME_MAX_WIDTH: float = 110.0   # 源 :653 超宽缩放阈值
const NAME_LEVEL_COLOR: Color = Color(241.0 / 255.0, 235.0 / 255.0, 206.0 / 255.0)
# VIP 角标（源 :580-593 ÷CS 点尺寸）。
const VIP_BG_DISPLAY: Vector2 = Vector2(73.4, 26.5)
const VIP_ICON_DISPLAY: Vector2 = Vector2(28.9, 18.0)
const VIP_BG_RES: String = "res://assets/ui/alpha/HVGA/recharge_vip_bg.png"
const VIP_ICON_RES: String = "res://assets/ui/alpha/HVGA/recharge_vip_icon.png"
# 货币条（源 createTitle getBarConfig：gold/rmb/vitality 三条）
const BAR_BG_RES: String = "res://assets/ui/alpha/HVGA/main_status_number_bg.png"
const GOLD_ICON_RES: String = "res://assets/ui/alpha/HVGA/add_goldicon_small.png"
const DIAMOND_ICON_RES: String = "res://assets/ui/alpha/HVGA/add_rmbicon.png"
const VITALITY_ICON_RES: String = "res://assets/ui/alpha/HVGA/add_vitalityicon.png"
const PLUS_ICON_RES: String = "res://assets/ui/alpha/HVGA/main_status_plus_icon_1.png"
# sprite 显示尺寸（2026-08-15 终版）：货币图标/加号均无 TextureConfig 条目，
# cocos Texture:getContentSize() 返回点尺寸（像素/ContentScaleFactor）→ Sprite 显示=纹理÷CS
# （图标 33.6×30.5/39×29.7/34.4×39、加号 36.7，占 48 高条 63-81% 不顶天；
# 实证链：源码 resource_manager.createSprite→getSpriteFrame→texture:getContentSize
# + 源截图实测 + 用户三轮验收。TexDisplaySize 的 base×cs 公式对无条目散图偏大 1.28×，
# 其全局修复影响 73 处调用另行决策，此处局部口径）。
const CONTENT_SCALE: float = 1.28125
# = 源 money_bg/rmb_bg/vit_bg 中心 ccp(251,450)/(434,450)/(601,450)（statusbar.lua:719/787/853
# createTitle common 型，getInfoBarType 非 shop 一律 common 含 main）。Task2 迁移：800 宽直译 x 不偏移
# （旧 [331,514,681] 为 +80 居中偏移）；y=480-450=30（旧 50 为 960x640 等比近似）。
# 源不等距：money→rmb 间距 183，rmb→vit 间距 167（旧版改等距 183 违反源）。
const BAR_POS_X: Array = [251.0, 434.0, 601.0]
const BAR_Y: float = 30.0
const BAR_SIZE: Vector2 = Vector2(178.0, 48.0)
const VIT_BAR_SIZE: Vector2 = Vector2(145.0, 48.0)
# 货币图标中心点（源 statusbar.lua createTitle，bar 局部坐标，Sprite 默认锚点 0.5,0.5）：
# money_icon ccp(158,23) / rmb_icon ccp(156,23) / vitality_icon ccp(125,23)。
const BAR_ICON_CENTER: Array = [Vector2(158.0, 23.0), Vector2(156.0, 23.0), Vector2(125.0, 23.0)]
# 加号中心（源 vitality_add_icon ccp(20,23) money/rmb 为 empty.png 占位同位，bar 局部，锚点 0.5,0.5）。
const PLUS_CENTER: Vector2 = Vector2(20.0, 23.0)


# 装配完整状态栏（头像 + 货币条）。返回 refs dict 供 _refresh_status 更新 label。
# vitality_plus_handler：体力加号点击回调（main_scene 传 _on_vitality_plus→buy_vitality）。
# gold_plus_handler：金币条整条点击回调（照源 statusbar.lua:41-49 money_bg 可点→doClickMidas，
#   main_scene 传 _open_midas）。非空→bar Control gui_input 连接（整条可点）；空→bar 不响应。
# player/cm：vit_bg 按住提示卡需要（源 statusbar.lua:69-79 pressHandler→createVitalityPrompt）。
#   传入则启用按住提示卡（C12）；不传则 vit_bg 不响应按住（仅 vitality 加号点击仍工作）。
static func build(parent: Control, vitality_plus_handler: Callable = Callable(), head_click_handler: Callable = Callable(), gold_plus_handler: Callable = Callable(), player: PlayerData = null, cm: ConfigManager = null) -> Dictionary:
	var vip_idx: int = 0   # build 时默认银框，refresh 按 PlayerData.vip_level 切金框（P2-5 已实现见 refresh）
	var refs: Dictionary = {}
	# 头像区（源 createHead）
	var head := Control.new()
	head.position = HEAD_POS - HEAD_SIZE / 2.0
	head.size = HEAD_SIZE
	parent.add_child(head)
	refs["head"] = head
	if head_click_handler.is_valid():
		var h: Callable = head_click_handler
		head.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				h.call())
	_add_texture_rect(head, HEAD_FRAME_RES[vip_idx], HEAD_BG_POS, HEAD_BG_DISPLAY, "head_bg")
	# 头像图（head_bg 之上、head_frame 之下——源 addChild(head,3) < head_frame z=5 框纹盖头像缘；
	# build 按 player.avatar 建图，refresh 按 avatar 参数换图。2026-08-21 补全，
	# 此前 build 从未建头像图节点，换头像无从回传主界面）。
	var head_icon := _build_head_icon(player, avatar_id_of(player))
	head.add_child(head_icon)
	refs["head_icon"] = head_icon
	_add_texture_rect(head, HEAD_FRAME_BORDER_RES[vip_idx], HEAD_BG_POS, HEAD_BG_DISPLAY, "head_frame")
	# 昵称底纹 name_bg（2026-08-21 三修照源直译 statusbar.lua:279-286：中心锚
	# ccp(64,7) + 贴图 165×47px ÷CS=128.8×36.7 点尺寸——名字条在头像框**下方突出**，
	# 比框宽横跨两侧；旧值 (3,72) 贴框内底部致遮挡框下缘=「框被压扁」观感）。
	var name_bg: TextureRect = _add_texture_rect(head, NAME_BG_RES[vip_idx],
		Vector2(64.0 - NAME_BG_DISPLAY.x * 0.5, 98.0 - NAME_BG_DISPLAY.y * 0.5),
		NAME_BG_DISPLAY, "name_bg")
	refs["name_bg"] = name_bg
	# 昵称 Label（源 :640-649：parent name_bg mediate 居中，size=16 色(241,235,206)
	# 黑影 (0,2)；超宽 110 缩放 :653-655）。
	var name_lbl := Label.new()
	name_lbl.text = "Player"
	name_lbl.position = Vector2(64.0 - HEAD_SIZE.x * 0.5, 98.0 - 9.0)
	name_lbl.size = Vector2(HEAD_SIZE.x, 18.0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	name_lbl.add_theme_color_override("font_color", NAME_LEVEL_COLOR)
	name_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	name_lbl.add_theme_constant_override("shadow_offset_y", 2)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(name_lbl)
	refs["name"] = name_lbl
	# 等级 Label（2026-08-21 三修照源 :657-667：纯数字文本（无 "Lv." 前缀），
	# 中心 ccp(82,37) → Godot (82,68)，size=16 色(241,235,206)；旧值 (12,55) 带
	# 前缀错位。框右侧徽章区）。
	var level_lbl := Label.new()
	level_lbl.text = "1"
	level_lbl.position = Vector2(62.0, 59.0)
	level_lbl.size = Vector2(40.0, 18.0)
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	level_lbl.add_theme_color_override("font_color", NAME_LEVEL_COLOR)
	level_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(level_lbl)
	refs["level"] = level_lbl
	# VIP 角标（VIP>0 显示；2026-08-21 三修照源 :580-593 中心锚 ccp(90,58)/(85,58)
	# → Godot 中心 (90,47)/(85,47)，贴图 ÷CS 点尺寸 73.4×26.5/28.9×18；旧 50×50 拉伸方图）
	var vip_bg := _add_texture_rect(head, VIP_BG_RES, Vector2(90.0 - VIP_BG_DISPLAY.x * 0.5, 47.0 - VIP_BG_DISPLAY.y * 0.5), VIP_BG_DISPLAY, "vip_bg")
	vip_bg.visible = false
	refs["vip_bg"] = vip_bg
	var vip_icon := _add_texture_rect(head, VIP_ICON_RES, Vector2(85.0 - VIP_ICON_DISPLAY.x * 0.5, 47.0 - VIP_ICON_DISPLAY.y * 0.5), VIP_ICON_DISPLAY, "vip_icon")
	vip_icon.visible = false
	refs["vip_icon"] = vip_icon
	var vip_lbl := Label.new()
	vip_lbl.text = "0"
	vip_lbl.position = Vector2(85.0, 38.0)
	vip_lbl.visible = false
	head.add_child(vip_lbl)
	refs["vip"] = vip_lbl
	# 货币条（源 createTitle gold/rmb/vitality）。vit_bg 用源 145×48（比 money/rmb 178×48 窄）
	refs["gold"] = _build_bar(parent, BAR_POS_X[0], GOLD_ICON_RES, Callable(), BAR_Y, BAR_SIZE, BAR_ICON_CENTER[0])
	refs["diamond"] = _build_bar(parent, BAR_POS_X[1], DIAMOND_ICON_RES, Callable(), BAR_Y, BAR_SIZE, BAR_ICON_CENTER[1])
	refs["vitality"] = _build_bar(parent, BAR_POS_X[2], VITALITY_ICON_RES, vitality_plus_handler, BAR_Y, VIT_BAR_SIZE, BAR_ICON_CENTER[2])
	# gold_plus_handler 非 empty → bar Control（gold Label 的 parent）gui_input 连接整条点击。
	if gold_plus_handler.is_valid():
		var gold_lbl: Label = refs["gold"] as Label
		gold_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 避 Label STOP 吞点击，让 bar 整条可点
		var gold_bar: Control = gold_lbl.get_parent()
		var g: Callable = gold_plus_handler
		gold_bar.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				g.call())
	# 按住 vit_bg 显体力恢复进度提示卡（C12），松开销毁。vit 加号 Button STOP 独立命中不冲突。
	if player != null and cm != null:
		_attach_vit_prompt(refs["vitality"] as Label, parent, player, cm)
	refs["_player"] = player   # _refresh_head_icon 查 Avatar 表用（GameData.player 单例不悬空）
	return refs


# 仅货币条（无头像）— 非 main 场景用（源 framework.createTitle 所有场景建货币条，createHead 只 main）。
# bar_pos_x/bar_y 由调用方传源 common 中心点（源 cocos(251,434,601) y450 → godot 直译 [251,434,601] y30；
# HudOverlay 传本类常量 BAR_POS_X/BAR_Y）。
# parent: 挂载父节点（子场景直接挂 panel/scene）
# gold_plus_handler: 金币"+"回调（照源 statusbar.lua:42-49 registerTitleTouchHandler，子场景也开 midas）
static func build_bars_only(parent: Control, bar_pos_x: Array, bar_y: float, vitality_plus_handler: Callable = Callable(), gold_plus_handler: Callable = Callable()) -> Dictionary:
	var refs: Dictionary = {}
	refs["gold"] = _build_bar(parent, float(bar_pos_x[0]), GOLD_ICON_RES, gold_plus_handler, bar_y, BAR_SIZE, BAR_ICON_CENTER[0])
	refs["diamond"] = _build_bar(parent, float(bar_pos_x[1]), DIAMOND_ICON_RES, Callable(), bar_y, BAR_SIZE, BAR_ICON_CENTER[1])
	refs["vitality"] = _build_bar(parent, float(bar_pos_x[2]), VITALITY_ICON_RES, vitality_plus_handler, bar_y, VIT_BAR_SIZE, BAR_ICON_CENTER[2])
	return refs


# 装配单条货币条：背景条 + 图标 + 数字 label + 加号。返回 label ref。
# plus_handler 非空（vitality）→ 加号是 Button 可点（照源 statusbar:59-68 radius=30 圆形点击 → buyVitality）；
# plus_handler 空（gold/diamond）→ 加号 IGNORE（gold 走 midas_btn，diamond 充值单机化裁剪；避 STOP 吞点击）。
# x/bar_y 为源 Scale9Sprite 中心点（anchor 0.5,0.5），内部转 Godot 左上角定位（减 size/2）。
# icon_center 为源图标中心点（bar 局部）；图标显示尺寸=纹理原始/CONTENT_SCALE 等比（三图标均非正方形，
# 勿统一 32×32 强拉——金币 43×39/钻石 50×38/体力 44×50 会变形，2026-08-15 用户实测反馈）。
static func _build_bar(parent: Control, x: float, icon_res: String, plus_handler: Callable = Callable(), bar_y: float = BAR_Y, bar_size: Vector2 = BAR_SIZE, icon_center: Vector2 = BAR_ICON_CENTER[0]) -> Label:
	var bar := Control.new()
	bar.position = Vector2(x - bar_size.x / 2.0, bar_y - bar_size.y / 2.0)
	bar.size = bar_size
	parent.add_child(bar)
	_add_texture_rect(bar, BAR_BG_RES, Vector2.ZERO, bar_size, "bg")
	var icon_size: Vector2 = (load(icon_res) as Texture2D).get_size() / CONTENT_SCALE
	_add_texture_rect(bar, icon_res, icon_center - icon_size / 2.0, icon_size, "icon")
	var lbl := Label.new()
	lbl.position = Vector2(50.0, 16.0)
	# 不引入 BodyLabel 变体（货币条数值可能有色，仅替换裸数字 14 为常量）
	lbl.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	bar.add_child(lbl)
	# 加号显示尺寸=纹理 47×47÷CS≈36.7（无 TextureConfig 条目散图，显示=点尺寸；
	# 47×47 顶满 48 高条系上一版口径错误，源即 ÷CS 后约 76% 条高），中心照源 ccp(20,23)。
	var plus_size: Vector2 = (load(PLUS_ICON_RES) as Texture2D).get_size() / CONTENT_SCALE
	if plus_handler.is_valid():
		# 加号可点 Button（flat + StyleBoxEmpty 去默认样式；照源圆形点击区 radius=30 ≥ 视觉）。
		# 视觉走子 TextureRect 而非 Button.icon（icon 会把按钮 min size 再撑大且不受控）。
		var plus_btn := Button.new()
		plus_btn.position = PLUS_CENTER - plus_size / 2.0
		plus_btn.size = plus_size
		plus_btn.flat = true
		plus_btn.focus_mode = Control.FOCUS_NONE
		# 走 GhostButton 变体（default_theme.tres：normal/hover/pressed/focus 全 StyleBoxEmpty）
		plus_btn.theme_type_variation = &"GhostButton"
		plus_btn.pressed.connect(plus_handler)
		_add_texture_rect(plus_btn, PLUS_ICON_RES, Vector2.ZERO, plus_size, "plus_icon")
		bar.add_child(plus_btn)
	else:
		# 无处理器（gold/diamond）：IGNORE 避 STOP 吞点击无响应（P1-复审2-3 核心危害）
		var plus := _add_texture_rect(bar, PLUS_ICON_RES, PLUS_CENTER - plus_size / 2.0, plus_size, "plus")
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


# vit_bg 按住提示卡接线（源 statusbar.lua:69-79 pressHandler/liftHandler）。
# vit_bg bar Control mouse_filter=PASS + gui_input 监听 mouse pressed/released（不影响 plus_btn STOP）。
static func _attach_vit_prompt(vit_lbl: Label, parent: Control, player: PlayerData, cm: ConfigManager) -> void:
	if vit_lbl == null:
		return
	vit_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 避 Label STOP 吞事件
	var vit_bar: Control = vit_lbl.get_parent()
	vit_bar.mouse_filter = Control.MOUSE_FILTER_PASS   # 让事件冒泡到 bar（plus_btn 仍独立命中）
	vit_bar.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			if (ev as InputEventMouseButton).pressed:
				VitPromptCard.show(parent, player, cm)
			else:
				VitPromptCard.destroy_prompt())


# 刷新状态栏数值（main_scene._refresh_status 调）。
static func refresh(refs: Dictionary, level: int, gold: int, diamond: int, vitality: int, vitality_max: int, name: String, vip: int, avatar: int) -> void:
	if refs.has("gold"):
		(refs["gold"] as Label).text = str(gold)
	if refs.has("diamond"):
		(refs["diamond"] as Label).text = str(diamond)
	if refs.has("vitality"):
		(refs["vitality"] as Label).text = "%d/%d" % [vitality, vitality_max]
	if refs.has("name"):
		(refs["name"] as Label).text = name
	# P1-15：等级 Label 更新（源 self.playerLevel）
	if refs.has("level"):
		(refs["level"] as Label).text = str(level)   # 2026-08-21 三修：源 :660 纯数字（无 Lv. 前缀）
	if refs.has("name"):
		# 源 :653-655 昵称超宽 110 缩放（防溢出名字条）。
		var nl: Label = refs["name"] as Label
		nl.scale = Vector2.ONE
		var nw: float = nl.get_minimum_size().x
		if nw > NAME_MAX_WIDTH:
			nl.scale.x = NAME_MAX_WIDTH / nw
	# VIP 角标显示切换（源 visible = self.vip > 0）
	var vip_idx: int = 1 if vip > 0 else 0
	if refs.has("vip"):
		(refs["vip"] as Label).text = str(vip)
		(refs["vip"] as Label).visible = vip > 0
	if refs.has("vip_bg"):
		(refs["vip_bg"] as TextureRect).visible = vip > 0
	if refs.has("vip_icon"):
		(refs["vip_icon"] as TextureRect).visible = vip > 0
	# 头像框银/金切换（源 vip>0 用 gold 资源）
	_refresh_head_frame(refs, vip_idx)
	# 头像图随 avatar 参数换图（2026-08-21：换头像后 HudOverlay.refresh 回传主界面）。
	_refresh_head_icon(refs, avatar)


# 换头像后刷新 icon 贴图（refresh 调；meta 记当前 id，未变跳过防高频重载）。
static func _refresh_head_icon(refs: Dictionary, avatar: int) -> void:
	var icon: TextureRect = refs.get("head_icon", null)
	if icon == null:
		return
	var aid: int = avatar if avatar > 0 else 1
	if int(icon.get_meta(&"avatar_id", 0)) == aid:
		return
	icon.set_meta(&"avatar_id", aid)
	icon.texture = _avatar_texture(refs.get("_player", null), aid)


# 头像图节点（Avatar[id].Picture → TextureRect + portrait_mask shader 圆形裁剪，
# configure._add_head_icon 同款范式；资源缺失返回空占位不挂）。
static func _build_head_icon(player: PlayerData, avatar_id: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = "head_icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = Vector2(HEAD_ICON_SIZE, HEAD_ICON_SIZE)
	icon.position = HEAD_ICON_CENTER - Vector2(HEAD_ICON_SIZE, HEAD_ICON_SIZE) * 0.5   # 等比分支再校正
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PortraitMaskShader
	mat.set_shader_parameter("mask_tex", load(HEAD_MASK_RES))
	icon.material = mat
	icon.texture = _avatar_texture(player, avatar_id)
	icon.set_meta(&"avatar_id", avatar_id)   # 初始 meta（refresh 同 id 短路判定基准）
	# 等比：贴图非正方形不强拉方形（源 setScale(length/宽) 等比，高=70×h/w）；
	# 中心保持源锚 (40,51)。2026-08-21 三修（压扁感修正）。
	if icon.texture != null:
		var ts: Vector2 = icon.texture.get_size()
		if ts.x > 1.0:
			var h_eq: float = HEAD_ICON_SIZE * ts.y / ts.x
			icon.size = Vector2(HEAD_ICON_SIZE, h_eq)
			icon.position = Vector2(HEAD_ICON_CENTER.x - HEAD_ICON_SIZE * 0.5, HEAD_ICON_CENTER.y - h_eq * 0.5)
	return icon


# avatar id（0→默认 1，源 player.lua:378；player 可空——build_bars_only 之外均可传）。
static func avatar_id_of(player: PlayerData) -> int:
	if player == null:
		return 1
	return player.avatar if player.avatar > 0 else 1


# Avatar 表查 Picture → Texture2D；查不到（表缺/player 空）返回 null 占位。
static func _avatar_texture(player: PlayerData, avatar_id: int) -> Texture2D:
	if player == null or player.cm == null:
		return null
	var pic: String = String(player.cm.get_raw_table(&"Avatar").get(str(avatar_id), {}).get("Picture", ""))
	if pic.is_empty():
		return null
	var path: String = "res://assets/ui/" + pic.substr(3)   # UI/HERO/X.jpg → assets/ui/HERO/X.jpg
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D




# 头像框银/金资源切换（源 refreshHead:200-280）。
static func _refresh_head_frame(refs: Dictionary, vip_idx: int) -> void:
	var head: Control = refs.get("head", null)
	if head == null:
		return
	var head_bg: TextureRect = head.get_node_or_null("head_bg")
	if head_bg != null:
		head_bg.texture = load(HEAD_FRAME_RES[vip_idx])
	var head_frame: TextureRect = head.get_node_or_null("head_frame")
	if head_frame != null:
		head_frame.texture = load(HEAD_FRAME_BORDER_RES[vip_idx])
	# name_bg 银金切换（照源 refreshHead 头像框同款逻辑，name_bg 也按 vip 切 silver/gold）
	var name_bg: TextureRect = head.get_node_or_null("name_bg")
	if name_bg != null:
		name_bg.texture = load(NAME_BG_RES[vip_idx])


# 辅助：创建 TextureRect 子节点。
static func _add_texture_rect(parent: Control, res_path: String, pos: Vector2, size: Vector2, node_name: String) -> TextureRect:
	var tr := TextureRect.new()
	tr.name = node_name
	tr.texture = load(res_path)
	# EXPAND_IGNORE_SIZE + 显式 size：纹理原始尺寸不撑大（照源 Scale9 scaleSize/fix_size 等价）。
	# 默认 KEEP_SIZE 致 main_status_number_bg 纹理原始尺寸撑大 → 货币条 3 框重叠（memory: texture-rect-expand-ignore-size）。
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.position = pos
	tr.size = size
	tr.custom_minimum_size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr
