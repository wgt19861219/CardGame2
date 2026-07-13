class_name MidasPanel
extends PopWindow

## 点石成金面板（View 层）— 照源 ui/midas.lua（1057 行）完整翻译。
## P1-5（2026-07-11）：去"最小可玩"，照源 create:758-1023 18 节点 + refreshCostBoard 横排 :237-301
## + playGetAcquireAnim 暴击飘字 :37-161 + createMultiWindow 连兑确认弹窗 popConfirmDialog :556-665。
## 坐标：源 cocos(800×480,y向上) → Godot container(960×640 FULL_RECT,cocos 居中 offset 80,80)。
## 资源降级：midas_crip* / midas_get_money 缺 → 文字/Label 降级（common_tips_button_close 已挂载 common/ 子目录）。

const PANEL_COCOS_H: float = 480.0
const OFFSET_X: float = 80.0
const OFFSET_Y: float = 80.0
# 源 create:773-1011 节点资源 + cocos 坐标
const FRAME_RES := "res://assets/ui/alpha/HVGA/main_vit_tips.png"
const FRAME_COCOS: Vector2 = Vector2(400.0, 305.0)    # 源 :782
const FRAME_SIZE: Vector2 = Vector2(425.0, 245.0)     # 源 :785 scaleSize
const FRAME_CAP: int = 10                             # 源 :779 capInsets(10,10,58,26) 近似对称
const ICON_FRAME_RES := "res://assets/ui/alpha/HVGA/equip_frame_white.png"
const ICON_FRAME_COCOS: Vector2 = Vector2(100.0, 205.0)  # 源 :808
const ICON_FRAME_SIZE: Vector2 = Vector2(110.0, 110.0)
const ICON_RES := "res://assets/ui/alpha/HVGA/midas_icon.png"
const ICON_COCOS: Vector2 = Vector2(100.0, 206.0)     # 源 :819
const ICON_SIZE: Vector2 = Vector2(100.0, 100.0)
const NAME_COCOS: Vector2 = Vector2(155.0, 225.0)     # 源 :832 anchor(0,0.5)
const DESC_COCOS: Vector2 = Vector2(155.0, 185.0)     # 源 :845 anchor(0,0.5)
const DESC_COLOR: Color = Color(231.0 / 255.0, 185.0 / 255.0, 108.0 / 255.0)  # 源 :848 ccc3
const COST_BOARD_RES := "res://assets/ui/alpha/HVGA/tip_detail_bg.png"
const COST_BOARD_COCOS: Vector2 = Vector2(213.0, 120.0)  # 源 :858
const COST_BOARD_SIZE: Vector2 = Vector2(425.0, 76.0)    # 源 :861 fix_size
const USE_RES := "res://assets/ui/alpha/HVGA/tavern_button_1.png"      # 源 :884 use
const MULTI_USE_RES := "res://assets/ui/alpha/HVGA/tavern_button_normal_1.png"  # 源 :940
const USE_COCOS: Vector2 = Vector2(130.0, 50.0)       # 源 :1028 解锁 multi 时
const USE_COCOS_SOLO: Vector2 = Vector2(210.0, 50.0)  # 源 :1031 未解锁
const BTN_SIZE: Vector2 = Vector2(150.0, 45.0)        # 源 :891 scaleSize
const MULTI_USE_COCOS: Vector2 = Vector2(300.0, 50.0)  # 源 :944
const USE_LABEL_COLOR: Color = Color(231.0 / 255.0, 206.0 / 255.0, 19.0 / 255.0)   # 源 :933
const MULTI_LABEL_COLOR: Color = Color(1.0, 1.0, 1.0)  # 源 :988 ccc3(231,231,231)
const DISABLED_COLOR: Color = Color(150.0 / 255.0, 150.0 / 255.0, 150.0 / 255.0)  # 源 :217
const CLOSE_RES := "res://assets/ui/alpha/HVGA/common/common_tips_button_close_1.png"  # 源 :995 close
const CLOSE_PRESS_RES := "res://assets/ui/alpha/HVGA/common/common_tips_button_close_2.png"  # 源 :1006 close_press
const CLOSE_COCOS: Vector2 = Vector2(524.0, 305.0)  # 源 :998 mediate anchor 0.5
const SELL_BTN_RES := "res://assets/ui/alpha/HVGA/sell_number_button.png"  # 源 confirmdialog right/left_button normal
const SELL_BTN_PRESS_RES := "res://assets/ui/alpha/HVGA/sell_number_button_down.png"  # 源 press
const SELL_BTN_CAP: Rect2 = Rect2(15.63, 15.63, 19.53, 15.63)  # 源 confirmdialog capInsets
const CONFIRM_BTN_SIZE: Vector2 = Vector2(100.0, 36.0)  # 目标简化弹窗 size（源 confirmdialog scaleSize 125×54.69 九宫格拉伸适配避 ok/cancel 重叠）
const CONFIRM_BTN_LABEL_COLOR: Color = Color(234.0 / 255.0, 225.0 / 255.0, 205.0 / 255.0)  # 源 ccc3(234,225,205) 浅金
# cost_board 横排图标（源 refreshCostBoard :244-298 HorizontalNode）
const RMB_ICON_RES := "res://assets/ui/alpha/HVGA/task_rmb_icon_2.png"   # 源 :255
const ARROW_RES := "res://assets/ui/alpha/HVGA/player_levelup_arrow.png"  # 源 :274
const GOLD_ICON_RES := "res://assets/ui/alpha/HVGA/task_gold_icon_2.png"  # 源 :282
const COST_RMB_COLOR: Color = Color(49.0 / 255.0, 219.0 / 255.0, 1.0)   # 源 :267 ccc3(49,219,255)
const COST_MONEY_COLOR: Color = Color(1.0, 165.0 / 255.0, 49.0 / 255.0)  # 源 :295 ccc3(255,165,49)
const COST_ICON_SIZE: Vector2 = Vector2(28.0, 28.0)
# 暴击飘字（源 playGetAcquireAnim :37-161；midas_crip*.png/midas_get_money.png 缺 → Label 降级）
const CRIP_TEXT: Dictionary = {2: "×2", 3: "×3", 4: "×10"}    # 源 :93-98 times_res
const CRIP_COLOR: Dictionary = {2: Color(1.0, 0.4, 0.7), 3: Color(1.0, 0.4, 0.7), 4: Color(1.0, 0.36, 0.27)}
const ANIM_ORI_COCOS: Vector2 = Vector2(400.0, 280.0)  # 源 :120 金额节点
const ANIM_END_COCOS: Vector2 = Vector2(400.0, 440.0)  # 源 :113 endpos
const CRIP_COCOS: Vector2 = Vector2(400.0, 320.0)      # 源 :106 暴击图
const ANIM_SCALE: float = 3.0                          # 源 :108/124 scale 3
const ANIM_SCALE_DUR: float = 0.2                      # 源 :58 CCScaleTo(0.2)
const ANIM_MOVE_DUR: float = 1.0                       # 源 :71 CCMoveTo(1)
const ANIM_FADE_DUR: float = 1.0                       # 源 :72 CCFadeOut(1)
const GET_MONEY_TEXT: String = "获得金币"               # 源 midas_get_money.png 缺降级
# 连兑确认弹窗（源 createMultiWindow :556-665 popConfirmDialog）
const CONFIRM_FRAME_COCOS: Vector2 = Vector2(400.0, 240.0)
const CONFIRM_FRAME_SIZE: Vector2 = Vector2(360.0, 170.0)
const CONFIRM_TEXT_COLOR: Color = Color(231.0 / 255.0, 185.0 / 255.0, 108.0 / 255.0)  # 源 :634
const CONFIRM_GOLD_COLOR: Color = Color(1.0, 170.0 / 255.0, 50.0 / 255.0)  # 源 :653
# 历史记录区（源 createHistory :710-756 scrollView，frame 外下方扩展）
const HISTORY_POS: Vector2 = Vector2(140.0, 408.0)
const HISTORY_SIZE: Vector2 = Vector2(640.0, 90.0)
const RATIO_TEXT: Dictionary = {1: "", 2: " ×2!", 3: " ×3!", 4: " ×10!!"}
const RATIO_COLOR: Dictionary = {
	1: Color.WHITE, 2: Color(1.0, 0.4, 0.7), 3: Color(1.0, 0.4, 0.7), 4: Color(1.0, 0.36, 0.27),
}

var _midas: MidasManager
var _player: PlayerData
var _cm: ConfigManager
var _history: Array = []            # 源 createHistory 历史记录 [{cost,acquire,ratio}]
var _use_btn: TextureButton = null
var _multi_btn: TextureButton = null
var _use_label: Label = null
var _multi_label: Label = null
var _use_shade: ColorRect = null    # 源 use_disabled 禁用蒙版
var _multi_shade: ColorRect = null
var _forbid_use: bool = false       # 源 forbidUse（anim 期间禁用）
var _multi_unlocked: bool = true    # 源 playerlimit "Multiple Midas"（单机化默认解锁）
var _confirm_layer: Control = null  # 连兑确认弹窗层


func setup_panel(p_player: PlayerData) -> void:
	_player = p_player
	_midas = _player.midas
	_cm = _player.cm
	setup()
	_refresh_view()


# 源 cocos(800×480,y向上) → Godot container(960×640,cocos 居中 offset 80,80)。
static func _to_godot(cocos: Vector2) -> Vector2:
	return Vector2(cocos.x + OFFSET_X, PANEL_COCOS_H - cocos.y + OFFSET_Y)


# 中心 anchor(cocos 0.5) → Godot 左上
static func _center(cocos: Vector2, sz: Vector2) -> Vector2:
	return _to_godot(cocos) - sz * 0.5


# 左中 anchor(cocos 0,0.5) → Godot 左上
static func _left_mid(cocos: Vector2, h: float) -> Vector2:
	var g: Vector2 = _to_godot(cocos)
	return Vector2(g.x, g.y - h * 0.5)


func _refresh_view() -> void:
	for c in container.get_children():
		c.queue_free()
	_use_btn = null
	_multi_btn = null
	_use_label = null
	_multi_label = null
	_use_shade = null
	_multi_shade = null
	_create_frame()
	_create_icon()
	_create_text()
	_create_cost_board()
	_create_buttons()
	_create_history()
	_apply_use_enabled()


# 源 :773-796 frame Scale9Sprite(main_vit_tips) + :994 close
func _create_frame() -> void:
	_add_nine_patch(container, FRAME_RES, _center(FRAME_COCOS, FRAME_SIZE), FRAME_SIZE, FRAME_CAP)
	# close（源 common_tips_button_close，资源在 common/ 子目录；源 :998 ccp(524,305) mediate anchor 0.5）
	var close: TextureButton = UiButton.make(CLOSE_RES, CLOSE_PRESS_RES, _to_godot(CLOSE_COCOS))
	close.pressed.connect(remove_window)
	container.add_child(close)


# 源 :803-821 icon_frame(equip_frame_white) + icon(midas_icon)
func _create_icon() -> void:
	_add_sprite(container, ICON_FRAME_RES, _center(ICON_FRAME_COCOS, ICON_FRAME_SIZE), ICON_FRAME_SIZE)
	_add_sprite(container, ICON_RES, _center(ICON_COCOS, ICON_SIZE), ICON_SIZE)


# 源 :824-849 name(GOLDEN_HAND) + desc(USE_A_SMALL...) + :799 prompt(次数用完)
func _create_text() -> void:
	var name_lbl := Label.new()
	name_lbl.text = "金色手掌"   # 源 MIDAS.GOLDEN_HAND
	name_lbl.position = _left_mid(NAME_COCOS, 24.0)
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(name_lbl)
	var next_cost: int = _get_next_cost()
	var desc := Label.new()
	var desc_text: String = "用少量钻石换大量金币"   # 源 :840
	if next_cost == 0:
		desc_text = "今日次数已用完"   # 源 :799 YOUVE_USED_UP
	desc.text = desc_text + "\n已兑换 %d 次  持有 %d 钻石" % [_midas.midas_times, _player.diamond]
	desc.position = _left_mid(DESC_COCOS, 36.0)
	desc.add_theme_font_size_override("font_size", 18)
	desc.modulate = DESC_COLOR
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(desc)


# 源 refreshCostBoard :237-301：tip_detail_bg 背景 + HorizontalNode 横排(rmb_icon+cost+arrow+gold_icon+acquire)
func _create_cost_board() -> void:
	if _get_next_cost() == 0:
		return   # 次数用完不显示
	_add_sprite(container, COST_BOARD_RES, _center(COST_BOARD_COCOS, COST_BOARD_SIZE), COST_BOARD_SIZE)
	var bar := HBoxContainer.new()
	bar.position = _left_mid(COST_BOARD_COCOS, 30.0) + Vector2(120.0, -15.0)
	bar.size = Vector2(280.0, 30.0)
	bar.add_theme_constant_override("separation", 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bar)
	_add_bar_icon(bar, RMB_ICON_RES)
	_add_bar_label(bar, str(_get_next_cost()), COST_RMB_COLOR)
	_add_bar_icon(bar, ARROW_RES)
	_add_bar_icon(bar, GOLD_ICON_RES)
	_add_bar_label(bar, str(_get_next_acquire()), COST_MONEY_COLOR)


# 源 use/multi_use Scale9Sprite + disabled shade + label；refreshMultiUseButton :1025-1034 显隐
func _create_buttons() -> void:
	var next_cost: int = _get_next_cost()
	if next_cost == 0:
		return
	var use_cocos: Vector2 = USE_COCOS if _multi_unlocked else USE_COCOS_SOLO
	_use_btn = _make_button("兑换", use_cocos, USE_RES, USE_LABEL_COLOR)
	_use_shade = _use_btn.get_child(0) as ColorRect
	_use_label = _use_btn.get_node("Label") as Label
	_use_btn.pressed.connect(_on_use.bind(1))
	if _multi_unlocked:
		var multi: int = _get_multi_count(next_cost)
		if multi > 1:
			_multi_btn = _make_button("连兑 ×%d" % multi, MULTI_USE_COCOS, MULTI_USE_RES, MULTI_LABEL_COLOR)
			_multi_shade = _multi_btn.get_child(0) as ColorRect
			_multi_label = _multi_btn.get_node("Label") as Label
			_multi_btn.pressed.connect(_on_use.bind(multi))


# TextureButton(tavern_button) + shade(use_disabled 蒙版) + label，照源 use 结构
func _make_button(text: String, cocos: Vector2, res: String, label_color: Color) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal = load(res)
	btn.position = _center(cocos, BTN_SIZE)
	btn.size = BTN_SIZE
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	btn.custom_minimum_size = BTN_SIZE
	container.add_child(btn)
	var shade := ColorRect.new()
	shade.color = Color(0.3, 0.3, 0.3, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.visible = false
	btn.add_child(shade)
	var lbl := Label.new()
	lbl.name = "Label"
	lbl.text = text
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.modulate = label_color
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)
	return btn


# 源 setUseButtonEnabled :214-235：disabled shade 显 + label 灰；enable 隐 + label 原 色
func _apply_use_enabled() -> void:
	var use_col: Color = DISABLED_COLOR if _forbid_use else USE_LABEL_COLOR
	var multi_col: Color = DISABLED_COLOR if _forbid_use else MULTI_LABEL_COLOR
	if _use_shade != null and is_instance_valid(_use_shade):
		_use_shade.visible = _forbid_use
	if _use_label != null and is_instance_valid(_use_label):
		_use_label.modulate = use_col
	if _multi_shade != null and is_instance_valid(_multi_shade):
		_multi_shade.visible = _forbid_use
	if _multi_label != null and is_instance_valid(_multi_label):
		_multi_label.modulate = multi_col


func _set_use_enabled(enable: bool) -> void:
	_forbid_use = not enable
	_apply_use_enabled()


# 源 doClickUse → doUse（单次）；createMultiWindow :659 popConfirmDialog（连兑确认）
func _on_use(times: int) -> void:
	if _forbid_use:
		return
	AudioPlayer.play_sfx("common_click_feedback")
	if times > 1:
		_show_confirm(times)   # 源 :659 连兑弹确认
		return
	_do_exchange(times)


# 源 doUse:191 + doUseReply:163：exchange + addMoney + createHistory + playGetAcquireAnim
func _do_exchange(times: int) -> void:
	_set_use_enabled(false)
	var r: Dictionary = _midas.exchange(_player, times)
	if not bool(r.get("ok", false)):
		Toast.show_message("钻石不足（需 %d）" % int(r.get("cost", 0)))
		_set_use_enabled(true)
		return
	var total_gold: int = 0
	var acquired: Array = r["acquired"]
	var single_cost: int = int(r.get("cost", 0)) / times
	for i in acquired.size():
		var a: Dictionary = acquired[i]
		var money: int = int(a.get("money", 0))
		var ratio: int = int(a.get("ratio", 1))
		total_gold += money
		_history.append({"cost": single_cost, "acquire": money, "ratio": ratio})
		_play_acquire_anim(ratio, money, 0.4 * float(i), i == acquired.size() - 1)
	_player.hero_manager.add_money(total_gold)
	if _player.task_manager != null:
		_player.task_manager.record_by_type(_cm, "MidasUse", times)
	_refresh_view()


# 源 playGetAcquireAnim :37-161：crip 图(×2/3/10)+ get_money 标题+金额，scale→move+fade 动作
# 资源缺 midas_crip*.png/midas_get_money.png → Label 降级（合并 title+money）
func _play_acquire_anim(ratio: int, money: int, play_delay: float, is_last: bool) -> void:
	if ratio >= 2 and CRIP_TEXT.has(ratio):
		var crip := Label.new()
		crip.text = str(CRIP_TEXT.get(ratio, ""))
		crip.modulate = CRIP_COLOR.get(ratio, Color.WHITE)
		crip.add_theme_font_size_override("font_size", 48)
		crip.position = _center(CRIP_COCOS, Vector2(80.0, 48.0))
		crip.pivot_offset = Vector2(40.0, 24.0)
		crip.scale = Vector2(ANIM_SCALE, ANIM_SCALE)
		crip.visible = false
		crip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(crip)
		_run_anim(crip, play_delay, _to_godot(ANIM_END_COCOS), false)
	var node := Label.new()
	node.text = "%s %d" % [GET_MONEY_TEXT, money]
	node.modulate = Color(1.0, 0.7, 0.2)
	node.add_theme_font_size_override("font_size", 26)
	node.position = _center(ANIM_ORI_COCOS, Vector2(160.0, 40.0))
	node.pivot_offset = Vector2(80.0, 20.0)
	node.scale = Vector2(ANIM_SCALE, ANIM_SCALE)
	node.visible = false
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(node)
	_run_anim(node, play_delay + 0.2, _to_godot(ANIM_END_COCOS), is_last)


# 源 getAction :78-91：Delay(playDelay)→visible→ScaleTo(0.2,EaseBackOut)→Delay 0.5→MoveTo(1)+FadeOut(1)→remove
func _run_anim(node: Control, delay: float, end_pos: Vector2, is_last: bool) -> void:
	if not is_inside_tree():
		node.queue_free()
		return
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void: node.visible = true)
	tw.tween_property(node, "scale", Vector2.ONE, ANIM_SCALE_DUR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	if is_last:
		tw.tween_callback(func() -> void: _set_use_enabled(true))
	tw.tween_property(node, "position", end_pos, ANIM_MOVE_DUR)
	tw.parallel().tween_property(node, "modulate:a", 0.0, ANIM_FADE_DUR)
	tw.tween_callback(func() -> void: node.queue_free())


# 源 createMultiWindow :556-665 popConfirmDialog：frame + 文案 + goldicon + acquire + 确认/取消
func _show_confirm(times: int) -> void:
	var next_cost: int = _get_next_cost()
	_confirm_layer = Control.new()
	_confirm_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	container.add_child(_confirm_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.4)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_layer.add_child(shade)
	_add_nine_patch(_confirm_layer, FRAME_RES, _center(CONFIRM_FRAME_COCOS, CONFIRM_FRAME_SIZE), CONFIRM_FRAME_SIZE, FRAME_CAP)
	var msg := Label.new()
	msg.text = "消耗 %d 钻石" % (next_cost * times)   # 源 :625 midas.1.10.1.005
	msg.position = _left_mid(Vector2(400.0, 275.0), 24.0)
	msg.modulate = CONFIRM_TEXT_COLOR
	msg.add_theme_font_size_override("font_size", 18)
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_layer.add_child(msg)
	_add_sprite(_confirm_layer, GOLD_ICON_RES, _center(Vector2(360.0, 230.0), COST_ICON_SIZE), COST_ICON_SIZE)
	var amt := Label.new()
	amt.text = "x%d" % (_get_next_acquire() * times)
	amt.position = _left_mid(Vector2(390.0, 230.0), 24.0)
	amt.modulate = CONFIRM_GOLD_COLOR
	amt.add_theme_font_size_override("font_size", 18)
	amt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_layer.add_child(amt)
	var ok: Button = UiScale9Button.make(SELL_BTN_RES, SELL_BTN_PRESS_RES, _center(Vector2(340.0, 170.0), CONFIRM_BTN_SIZE), CONFIRM_BTN_SIZE, SELL_BTN_CAP, "确认", CONFIRM_BTN_LABEL_COLOR)
	ok.pressed.connect(func() -> void:
		_close_confirm()
		_do_exchange(times))
	_confirm_layer.add_child(ok)
	var cancel: Button = UiScale9Button.make(SELL_BTN_RES, SELL_BTN_PRESS_RES, _center(Vector2(460.0, 170.0), CONFIRM_BTN_SIZE), CONFIRM_BTN_SIZE, SELL_BTN_CAP, "取消", CONFIRM_BTN_LABEL_COLOR)
	cancel.pressed.connect(_close_confirm)
	_confirm_layer.add_child(cancel)


func _close_confirm() -> void:
	if _confirm_layer != null and is_instance_valid(_confirm_layer):
		_confirm_layer.queue_free()
	_confirm_layer = null


# 源 createHistory :710-757 scrollView push（降级 Panel + Label 列表）
func _create_history() -> void:
	if _history.is_empty():
		return
	var frame := Panel.new()
	frame.position = HISTORY_POS
	frame.size = HISTORY_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(frame)
	var title := Label.new()
	title.text = "历史记录"
	title.position = Vector2(10.0, 4.0)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(title)
	var y: float = 26.0
	for h in _history:
		var row := Label.new()
		row.text = "耗 %d 钻 → 得 %d 金%s" % [int(h.get("cost", 0)), int(h.get("acquire", 0)), str(RATIO_TEXT.get(int(h.get("ratio", 1)), ""))]
		row.position = Vector2(10.0, y)
		row.modulate = RATIO_COLOR.get(int(h.get("ratio", 1)), Color.WHITE)
		row.add_theme_font_size_override("font_size", 14)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(row)
		y += 18.0


# 源 getCost：GradientPrice[times+1].Midas
func _get_next_cost() -> int:
	var idx: int = _midas.midas_times + 1
	return int(_cm.get_raw_table("GradientPrice").get(str(idx), {}).get("Midas", 0))


# 源 getAcquire：floor(PlayerLevel[level].Midas Money × Midas[times+1].Yield 1)
func _get_next_acquire() -> int:
	var idx: int = _midas.midas_times + 1
	var yield_rate: float = float(_cm.get_raw_table("Midas").get(str(idx), {}).get("Yield 1", 1.0))
	var base_money: int = int(_cm.get_raw_table("PlayerLevel").get(str(_player.team_level), {}).get("Midas Money", 5000))
	return int(float(base_money) * yield_rate)


# 源 getMultiCost :4-14：连续同价档批量次数
func _get_multi_count(cost: int) -> int:
	var count: int = 0
	var gt: Dictionary = _cm.get_raw_table("GradientPrice")
	while (_midas.midas_times + count + 1) <= gt.size():
		var c: int = int(gt.get(str(_midas.midas_times + count + 1), {}).get("Midas", 0))
		if c != cost:
			break
		count += 1
	return maxi(count, 1)


# 辅助：TextureRect 装饰节点（mouse IGNORE）
func _add_sprite(parent: Control, res_path: String, pos: Vector2, sz: Vector2) -> void:
	if not ResourceLoader.exists(res_path):
		return
	var tr := TextureRect.new()
	tr.texture = load(res_path)
	tr.position = pos
	tr.size = sz
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	parent.add_child(tr)


# 辅助：NinePatchRect（Scale9）
func _add_nine_patch(parent: Control, res_path: String, pos: Vector2, sz: Vector2, cap: int) -> NinePatchRect:
	var npr := NinePatchRect.new()
	if ResourceLoader.exists(res_path):
		npr.texture = load(res_path)
	npr.position = pos
	npr.size = sz
	npr.patch_margin_left = cap
	npr.patch_margin_top = cap
	npr.patch_margin_right = cap
	npr.patch_margin_bottom = cap
	npr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(npr)
	return npr


# 辅助：HBox 内图标
func _add_bar_icon(bar: HBoxContainer, res_path: String) -> void:
	if not ResourceLoader.exists(res_path):
		return
	var tr := TextureRect.new()
	tr.texture = load(res_path)
	tr.custom_minimum_size = COST_ICON_SIZE
	tr.ignore_texture_size = true
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(tr)


# 辅助：HBox 内 Label
func _add_bar_label(bar: HBoxContainer, text: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.modulate = col
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(lbl)
