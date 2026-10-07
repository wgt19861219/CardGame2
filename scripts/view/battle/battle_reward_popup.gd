class_name BattleRewardPopup
extends PopWindow

## 战斗结算奖励弹窗（照源 crusade.lua showRewardResult :344-394 + crusadeconfig.lua
## rewardLayer :1201-1306：getitem_bg Scale9 底板 + equip_detail_title_bg 标题横幅 +
## "获得的奖励" title_yellow + 图标富文本行 + tavern_button 确定钮）。
##
## 2026-10-06 修复（验收记录-远征宝箱弹窗缺失-2026-10-06）：旧实现仅遮罩 + 裸 Label
## （"ChestBox x1" 英文键名直出）+ herodetail X 钮，无背景框/标题/确认钮——逻辑弹窗了
## 但视觉上没有弹窗，用户报"远征点击宝箱没有奖励弹窗"。照源补全视觉层；ChestBox 槽位
## 照源 apply_rewards 折算口径显示为远征币（源 UI 层不出现 ChestBox，服务器下发前已折算）。
## 静态视觉层 procedural 构建（tscn 结构性改动走编辑器规范通道，此处不动 tscn 结构，
## 参照 stage_done_best_rank_popup 同域先例）；tscn 旧 CloseBtn 隐藏由确定钮承担关闭。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/battle_reward_popup_content.tscn")
const UiScale9 := preload("res://scripts/ui/ui_scale9_button.gd")
# 源坐标（cocos 中心/局部）→ Godot：to_godot(x,y)=(x,480-y)；尺寸/边距 = px÷CS(1.28125)。
const CONTENT_SCALE: float = 1.28125
# 源 rewardLayer layerColor ccc4(0,0,0,190)（比 PopWindow 默认 150 深，照源）。
const SHADE_ALPHA: float = 190.0 / 255.0
# rewardBg（common_getitem_bg 593×252 Scale9 cap(70,84,325,10) scaleSize 400×220）。
# 2026-10-06 二轮修正：Scale9 的 scaleSize 系 cocos 点空间直用不÷CS（RuleFrame 550×360
# 先例）；旧 400/CS×220/CS 偏小 1.28× 且 T123+B66=189 > 高 171.7 致上下边框区互叠
# （NinePatchRect margin 同时定义纹理裁剪与控件边距）→ 倒角变形（用户实机反馈）。
# 六轮修正：源 rewardBg 中心 to_godot(400,270)=y210 系源偏上设计（顶 100/底 160 不对称），
# 用户指示「奖励不居中」→ 整窗下移 30 点至屏幕垂直正中（bg 中心 240，标题/行/钮同步 +30）。
const BG_RES: String = "res://assets/ui/alpha/HVGA/common/common_getitem_bg.png"
const BG_CENTER: Vector2 = Vector2(400.0, 240.0)
const BG_SIZE: Vector2 = Vector2(400.0, 220.0)
const BG_MARGIN_LEFT: int = 55    # round(70/CS)
const BG_MARGIN_TOP: int = 123    # round(158/CS)（源 cap top = 252-84-10）
const BG_MARGIN_RIGHT: int = 155  # round(198/CS)（= 593-70-325）
const BG_MARGIN_BOTTOM: int = 66  # round(84/CS)
# 标题（七轮：横幅贴图左右不对称退役，只留金色描边文字；中心原 to_godot(400,338)+30 整窗下移）。
const TITLE_BG_CENTER: Vector2 = Vector2(400.0, 172.0)
const TITLE_LABEL_HALF_H: float = 12.0
const TITLE_LSTR_KEY: String = "CRUSADECONFIG.REWARDS_RECEIVED"
const TITLE_LSTR_FALLBACK: String = "你获得了以下奖励"
const TITLE_FONT_SIZE: int = 20
# 源 title_yellow ccc3(251,206,16)。
const TITLE_COLOR: Color = Color(251.0 / 255.0, 206.0 / 255.0, 16.0 / 255.0)
# 奖励行（七轮修正：用户指示「奖励在弹窗中间的背景框居中位置」——行中心=bg 正中 240，
# 弃源偏上 11 点口径；行容器铺 bg 内宽水平居中排列）。
const REWARD_ROW_CENTER: Vector2 = Vector2(400.0, 240.0)
const REWARD_ROW_WIDTH: float = 300.0
const REWARD_ROW_HEIGHT: float = 46.0
const REWARD_ROW_SEPARATION: int = 14
# 图标显示尺寸 = px÷CS（源富文本 <sprite> 无 scale 原大口径）。
const GOLD_ICON_RES: String = "res://assets/ui/alpha/HVGA/goldicon_small.png"
const GOLD_ICON_SIZE: Vector2 = Vector2(43.0 / CONTENT_SCALE, 40.0 / CONTENT_SCALE)
const DRAGON_ICON_RES: String = "res://assets/ui/alpha/HVGA/money_dragonscale_small.png"
const DRAGON_ICON_SIZE: Vector2 = Vector2(39.0 / CONTENT_SCALE, 39.0 / CONTENT_SCALE)
# 钻石（rmbicon 47×45，通关奖励受控增强 2026-10-06；stage_done_best_rank 同图先例）。
const DIAMOND_ICON_RES: String = "res://assets/ui/alpha/HVGA/rmbicon.png"
const DIAMOND_ICON_SIZE: Vector2 = Vector2(47.0 / CONTENT_SCALE, 45.0 / CONTENT_SCALE)
# 源 <item|id|0.6> 装备/道具图标 0.6 缩放。
const ITEM_ICON_SCALE: Vector2 = Vector2(0.6, 0.6)
const REWARD_FONT_SIZE: int = 18
const REWARD_TEXT_COLOR: Color = Color.WHITE
# 确定钮（tavern_button_normal 166×63 Scale9 cap(14,20,60,23) scaleSize 120×48，
# 中心局部 (0,63) → to_godot(400,213)；scaleSize 点空间直用不÷CS，同二轮修正）。
const CONFIRM_RES_NORMAL: String = "res://assets/ui/alpha/HVGA/tavern_button_normal_1.png"
const CONFIRM_RES_PRESSED: String = "res://assets/ui/alpha/HVGA/tavern_button_normal_2.png"
const CONFIRM_CAP: Rect2 = Rect2(14.0, 20.0, 60.0, 23.0)
const CONFIRM_CENTER: Vector2 = Vector2(400.0, 297.0)
const CONFIRM_SIZE: Vector2 = Vector2(120.0, 48.0)
const CONFIRM_LSTR_KEY: String = "CHATCONFIG.CONFIRM"
const CONFIRM_LSTR_FALLBACK: String = "确定"
# 奖励类型键（CrusadeRewards 表 Type N 原始口径，同 CrusadeManager.REWARD_*；
# diamond 为通关奖励受控增强槽〔2026-10-06 用户指示：并入宝箱弹窗展示〕）。
const TYPE_GOLD: String = "gold"
const TYPE_DIAMOND: String = "diamond"
const TYPE_CRUSADE_POINT: String = "CrusadePoint"
const TYPE_CHEST_BOX: String = "ChestBox"
const TYPE_ITEM: String = "Item"

var _content: Control = null              # .tscn 根（%RewardHost/%CloseBtn 持有者）
var _reward_host: Control = null          # .tscn %RewardHost（reward 节点容器）
var _cm_ref: Variant = null               # ConfigManager（LSTR 解析，setup_rewards 注入）


func setup_rewards(rewards: Array, p_cm: Variant) -> void:
	_cm_ref = p_cm
	setup()
	shade_layer.color.a = SHADE_ALPHA
	_build_content()
	_show_rewards(rewards, p_cm)


# panel 层从 .tscn instantiate + 照源补 rewardLayer 静态视觉（bg/标题/确定钮）。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	_reward_host = _content.get_node("%RewardHost") as Control
	# 旧 X 关闭钮退役（源 rewardLayer 无 X：任意点关闭 + 确定钮）——隐藏而非删（tscn 结构不动）。
	(_content.get_node("%CloseBtn") as BaseButton).visible = false
	_build_reward_bg()
	_build_title()
	var btn := UiScale9.make_centered(
		CONFIRM_RES_NORMAL, CONFIRM_RES_PRESSED, CONFIRM_CENTER, CONFIRM_SIZE, CONFIRM_CAP,
		_lstr(CONFIRM_LSTR_KEY, CONFIRM_LSTR_FALLBACK, _cm_ref))
	btn.pressed.connect(remove_window)
	_content.add_child(btn)


# 源 rewardBg Scale9Sprite（底板先挂，z 序在标题/行/钮之下）。
func _build_reward_bg() -> void:
	var bg := NinePatchRect.new()
	bg.name = "RewardBg"
	bg.texture = load(BG_RES) as Texture2D
	bg.position = BG_CENTER - BG_SIZE * 0.5
	bg.size = BG_SIZE
	bg.patch_margin_left = BG_MARGIN_LEFT
	bg.patch_margin_top = BG_MARGIN_TOP
	bg.patch_margin_right = BG_MARGIN_RIGHT
	bg.patch_margin_bottom = BG_MARGIN_BOTTOM
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 点击穿到 shade（源任意点关闭）
	_content.add_child(bg)
	# 2026-10-06 三轮修正：tscn 的 %RewardHost 先进树，bg 后 add 会画在奖励行之上面
	# （用户实机报「奖励显示在弹窗层下面」）——前移到首子位，对齐源 rewardBg 最底层 z 序。
	_content.move_child(bg, 0)


# 七轮修正（用户实机反馈「标题两边的装饰物间距都不统一，而且超出边框」）：源
# equip_detail_title_bg 贴图本身左右花纹不对称（PIL 实证 左端 60px 花纹 336px vs 右端
# 223px，源美术如此），布局无法修对称——横幅退役，只留金色描边标题文字（受控偏离）。
func _build_title() -> void:
	var lbl := Label.new()
	lbl.name = "TitleLabel"
	lbl.text = _lstr(TITLE_LSTR_KEY, TITLE_LSTR_FALLBACK, _cm_ref)
	lbl.position = Vector2(TITLE_BG_CENTER.x - BG_SIZE.x * 0.5, TITLE_BG_CENTER.y - TITLE_LABEL_HALF_H)
	lbl.size = Vector2(BG_SIZE.x, TITLE_LABEL_HALF_H * 2.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	lbl.add_theme_color_override("font_color", TITLE_COLOR)
	lbl.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(lbl)


# 奖励行：水平居中排（源 RichText 流式 icon+文字；middle 垂直居中）。
func _show_rewards(rewards: Array, p_cm: Variant) -> void:
	for c in _reward_host.get_children():
		c.queue_free()
	var row := HBoxContainer.new()
	row.name = "RewardRow"
	row.position = REWARD_ROW_CENTER - Vector2(REWARD_ROW_WIDTH, REWARD_ROW_HEIGHT) * 0.5
	row.size = Vector2(REWARD_ROW_WIDTH, REWARD_ROW_HEIGHT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", REWARD_ROW_SEPARATION)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward_host.add_child(row)
	for r in rewards:
		var stype: String = String(r.get("type", ""))
		var amount: int = int(r.get("amount", 0))
		if stype == TYPE_ITEM:
			var icon: Control = ReadequipIcon.create_icon(int(r.get("id", 0)), amount, p_cm)
			icon.scale = ITEM_ICON_SCALE
			row.add_child(icon)
			continue
		var pair := _currency_pair(stype, amount, int(r.get("id", 0)))
		row.add_child(_icon_rect(pair["res"], pair["size"]))
		row.add_child(_reward_label(pair["text"]))


# 图标+文案对（照源 RichText <sprite|..><text|..>）：CrusadePoint/ChestBox 均按源
# local_server getCrusadeReward 折算口径（crusadepoint=amount×10；chestbox=coins×10）
# 显示远征币，与 apply_rewards 实际入账一致。
func _currency_pair(stype: String, amount: int, id: int) -> Dictionary:
	if stype == TYPE_GOLD:
		return {"res": GOLD_ICON_RES, "size": GOLD_ICON_SIZE, "text": str(amount)}
	if stype == TYPE_DIAMOND:
		return {"res": DIAMOND_ICON_RES, "size": DIAMOND_ICON_SIZE, "text": "x" + str(amount)}
	if stype == TYPE_CRUSADE_POINT:
		var points: int = amount * CrusadeManager.CRUSADE_POINT_MULTIPLIER
		return {"res": DRAGON_ICON_RES, "size": DRAGON_ICON_SIZE, "text": "x" + str(points)}
	if stype == TYPE_CHEST_BOX:
		var coins: int = int(CrusadeManager.CHEST_BOX_COIN_MAP.get(id, CrusadeManager.CHEST_BOX_COIN_DEFAULT))
		var box_points: int = coins * CrusadeManager.CRUSADE_POINT_MULTIPLIER
		return {"res": DRAGON_ICON_RES, "size": DRAGON_ICON_SIZE, "text": "x" + str(box_points)}
	return {"res": DRAGON_ICON_RES, "size": DRAGON_ICON_SIZE, "text": "x" + str(amount)}


func _icon_rect(res: String, size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load(res) as Texture2D
	icon.custom_minimum_size = size
	icon.size = size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	# 2026-10-06 三轮修正：HBox 子项默认 FILL 会被垂直拉伸到行高（30×30 图标拉成
	# 46×30 变形，用户实机报「图标拉伸变形」）——SHRINK_CENTER 保等比居中。
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _reward_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", REWARD_FONT_SIZE)
	lbl.add_theme_color_override("font_color", REWARD_TEXT_COLOR)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _lstr(key: String, fallback: String, cm: Variant) -> String:
	if cm != null:
		var v: String = cm.get_lstr(key)
		return v if v != key else fallback
	return fallback
