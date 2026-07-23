class_name MidasPanel
extends PopWindow

## 点石成金面板（View 层）— 照源 ui/midas.lua（1057 行）。
## 2026-07-17 重构（hero_detail 范式）：panel 层 18 节点静态化进 midas_content.tscn
## （frame/close/icon/name/desc/prompt/cost_board/use/multi + cost_board 内 bar 5 子），
## 本类 instantiate + get_node("%..") 取节点 + fill 动态数据（text/visible/数字）。
## 保留 procedural：playGetAcquireAnim 暴击飘字 + popConfirmDialog 连兑确认 + 历史记录动态挂。
## 坐标：源 cocos(800×480,y向上) → Godot container(960×640 FULL_RECT,cocos 居中 offset 80,80)。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/midas_content.tscn")

const PANEL_COCOS_H: float = 480.0
const OFFSET_X: float = 80.0
const OFFSET_Y: float = 80.0

# _show_confirm 弹窗 frame + 图标 + 按钮（procedural 弹窗，非 .tscn 静态）
const FRAME_RES := "res://assets/ui/alpha/HVGA/main_vit_tips.png"
const FRAME_CAP: int = 10                             # 源 frame capInsets(10,10,58,26) 近似对称
const CONFIRM_FRAME_COCOS: Vector2 = Vector2(400.0, 240.0)
const CONFIRM_FRAME_SIZE: Vector2 = Vector2(360.0, 170.0)
const RMB_ICON_RES := "res://assets/ui/alpha/HVGA/task_rmb_icon_2.png"   # 源 refreshCostBoard :255
const GOLD_ICON_RES := "res://assets/ui/alpha/HVGA/task_gold_icon_2.png" # 源 :282
const COST_ICON_SIZE: Vector2 = Vector2(28.0, 28.0)
const SELL_BTN_RES := "res://assets/ui/alpha/HVGA/sell_number_button.png"           # 源 confirmdialog 按钮
const SELL_BTN_PRESS_RES := "res://assets/ui/alpha/HVGA/sell_number_button_down.png"
const SELL_BTN_CAP: Rect2 = Rect2(15.63, 15.63, 19.53, 15.63)   # 源 confirmdialog capInsets
const CONFIRM_BTN_SIZE: Vector2 = Vector2(100.0, 36.0)
const CONFIRM_BTN_LABEL_COLOR: Color = Color(234.0 / 255.0, 225.0 / 255.0, 205.0 / 255.0)
const CONFIRM_TEXT_COLOR: Color = Color(231.0 / 255.0, 185.0 / 255.0, 108.0 / 255.0)  # 源 :634
const CONFIRM_GOLD_COLOR: Color = Color(1.0, 170.0 / 255.0, 50.0 / 255.0)             # 源 :653

# use/multi 按钮 cocos（源 refreshMultiUseButton :1025-1034；_multi_unlocked 切 use 位置 + multi visible）
const USE_COCOS: Vector2 = Vector2(130.0, 50.0)       # 源 :1028 解锁 multi 时
const USE_COCOS_SOLO: Vector2 = Vector2(210.0, 50.0)  # 源 :1031 未解锁
const BTN_SIZE: Vector2 = Vector2(150.0, 45.0)        # 源 :891 scaleSize
const USE_LABEL_COLOR: Color = Color(231.0 / 255.0, 206.0 / 255.0, 19.0 / 255.0)   # 源 :933
const MULTI_LABEL_COLOR: Color = Color(1.0, 1.0, 1.0)  # 源 :988 ccc3(231,231,231)
const DISABLED_COLOR: Color = Color(150.0 / 255.0, 150.0 / 255.0, 150.0 / 255.0)   # 源 :217

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
const GET_MONEY_TEXT: String = "获得金币"               # 源 midas_get_money.png 缺 → Label 降级（无 LSTR）

# LSTR key（源 midas.lua T(LSTR(...))；多处复用保 const）
const LSTR_PROMPT := "MIDAS.YOUVE_USED_UP_DAILY_GOLDEN_HAND_TIMES_\\N_UPGRADING_YOUR_VIP_LEVEL_OFFERS_YOU_MORE_TIMES"
const LSTR_USE := "MIDAS.USE"                              # 源 refreshButton times<maxTimes / use 按钮 / 历史行
const LSTR_MULTI := "midas.1.10.1.002"                     # 源 multi_use_label + createMultiWindow 段1 "连续使用"

# 历史记录（源 createHistory :710-756 scrollView；C8 照源 initHistoryItemHandler :425-545 每行
# 6 节点横向布局 + 可选 ratio 图。HBoxContainer 替源 HorizontalNode + separation=5 近似 offset。）
const HISTORY_LINE_HEIGHT: float = 28.0    # 源 itemSize=(435,35)；缩 28 容纳 24 icon
const HISTORY_START_Y: float = 2.0
const HISTORY_ROW_X: float = 4.0
const HISTORY_FONT: int = 14               # 源 size=20（缩 14 适配行高 + 排版紧凑）
const HISTORY_ICON_H: float = 22.0         # 源 fix_height=30/35（goldicon），缩 22 适配行高
const HISTORY_SEP: int = 5                 # HBoxContainer separation（源 offset=5/10 简化统一）
# 源 initHistoryItemHandler :487-498 shop_token_icon + :508-517 goldicon_small
const HISTORY_TOKEN_RES: String = "res://assets/ui/alpha/HVGA/shop_token_icon.png"
const HISTORY_GOLD_RES: String = "res://assets/ui/alpha/HVGA/goldicon_small.png"
# 源 :532-544 ratio_res（midas_crip2/3/10.png）缺 → Label 降级（与暴击飘字 CRIP_TEXT 降级一致）
const HISTORY_RATIO_RES: Dictionary = {
	2: "res://assets/ui/alpha/HVGA/midas/midas_crip2.png",
	3: "res://assets/ui/alpha/HVGA/midas/midas_crip3.png",
	4: "res://assets/ui/alpha/HVGA/midas/midas_crip10.png",
}
# 源 :466-528 行内 6 节点 color ccc3→Color
const HISTORY_USE_COLOR: Color = Color(1.0, 246.0 / 255.0, 143.0 / 255.0)      # 源 ccc3(255,246,143)
const HISTORY_COST_COLOR: Color = Color(50.0 / 255.0, 223.0 / 255.0, 253.0 / 255.0)  # 源 ccc3(50,223,253)
const HISTORY_GET_COLOR: Color = Color(1.0, 246.0 / 255.0, 143.0 / 255.0)      # 源 ccc3(255,246,143)
const HISTORY_ACQUIRE_COLOR: Color = Color(1.0, 175.0 / 255.0, 52.0 / 255.0)   # 源 ccc3(255,175,52)
const RATIO_TEXT: Dictionary = {1: "", 2: " ×2!", 3: " ×3!", 4: " ×10!!"}
const RATIO_COLOR: Dictionary = {
	1: Color.WHITE, 2: Color(1.0, 0.4, 0.7), 3: Color(1.0, 0.4, 0.7), 4: Color(1.0, 0.36, 0.27),
}

var _midas: MidasManager
var _player: PlayerData
var _cm: ConfigManager
var _history: Array = []            # 源 createHistory 历史记录 [{cost,acquire,ratio}]
var _content: Control = null        # .tscn instantiate 根（container 子）
var _close_btn: TextureButton = null
var _use_btn: TextureButton = null
var _multi_btn: TextureButton = null
var _use_label: Label = null
var _multi_label: Label = null
var _use_shade: ColorRect = null    # 源 use_disabled 禁用蒙版（UseBtn 子 0）
var _multi_shade: ColorRect = null
var _prompt: Label = null           # 源 :864-879 prompt（maxTimes 时显 YOUVE_USED_UP）
var _cost_board_root: Control = null  # cost_board 根（含 bg + bar），refreshCost 切 visible
var _cost_label: Label = null       # bar 内 cost 数字（源 refreshCostBoard :267）
var _acquire_label: Label = null    # bar 内 acquire 数字（源 :295）
var _name_label: Label = null
var _desc_label: Label = null
var _history_host: Control = null   # 源 scrollView 简化容器（动态历史行挂载）
var _forbid_use: bool = false       # 源 forbidUse（anim 期间禁用）
var _multi_unlocked: bool = true    # 源 playerlimit "Multiple Midas"（单机化默认解锁）
var _confirm_layer: Control = null  # 连兑确认弹窗层


# LSTR 解析包装（源 T(LSTR(key)) 等价；cm 缺失返空串避免 null 解引用）。
func _T(key: String) -> String:
	if _cm == null:
		return ""
	return String(_cm.get_lstr(key))


func setup_panel(p_player: PlayerData) -> void:
	_player = p_player
	_midas = _player.midas
	_cm = _player.cm
	setup()
	_build_content()
	_refresh_view()


# 建内容：instantiate .tscn + 缓存节点引用 + 绑信号。位置/size .tscn 已固化不碰。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate()
	container.add_child(_content)
	_close_btn = _content.get_node("%CloseBtn") as TextureButton
	_close_btn.pressed.connect(remove_window)
	_use_btn = _content.get_node("%UseBtn") as TextureButton
	_multi_btn = _content.get_node("%MultiBtn") as TextureButton
	_use_shade = _use_btn.get_child(0) as ColorRect
	_use_label = _use_btn.get_node("Label") as Label
	_multi_shade = _multi_btn.get_child(0) as ColorRect
	_multi_label = _multi_btn.get_node("Label") as Label
	_use_btn.pressed.connect(_on_use.bind(1))
	_multi_btn.pressed.connect(_on_multi_pressed)
	_name_label = _content.get_node("%NameLabel") as Label
	_desc_label = _content.get_node("%DescLabel") as Label
	_prompt = _content.get_node("%PromptLabel") as Label
	_cost_board_root = _content.get_node("%CostBoardRoot") as Control
	_cost_label = _content.get_node("%CostLabel") as Label
	_acquire_label = _content.get_node("%AcquireLabel") as Label
	_history_host = _content.get_node("%HistoryHost") as Control


# fill 动态数据（text/visible/数字/按钮 position）；不 free content（常驻）。
func _refresh_view() -> void:
	_fill_text()
	_fill_cost_board()
	_fill_buttons()
	_apply_source_visibility()
	_refresh_button()
	_apply_use_enabled()
	_rebuild_history()


func _fill_text() -> void:
	_name_label.text = _T("MIDAS.GOLDEN_HAND")
	var left: int = maxi(_get_max_times() - _midas.midas_times, 0)
	_desc_label.text = "%s\n%s%d/%d)" % [
		_T("MIDAS.USE_A_SMALL_AMOUNT_OF_DIAMONDS_IN_EXCHANGE_FOR_LARGE_SUMS_OF_MONEY"),
		_T("MIDAS.AVAILABLE_TODAY"), left, _get_max_times()]
	_prompt.text = _T(LSTR_PROMPT)


func _fill_cost_board() -> void:
	_cost_label.text = str(_get_next_cost())
	_acquire_label.text = str(_get_next_acquire())


# 源 refreshMultiUseButton :1025-1034：_multi_unlocked 切 use position + multi visible。
func _fill_buttons() -> void:
	var next_cost: int = _get_next_cost()
	if next_cost == 0:
		_use_btn.visible = false
		_multi_btn.visible = false
		return
	var use_cocos: Vector2 = USE_COCOS if _multi_unlocked else USE_COCOS_SOLO
	_use_btn.position = _center(use_cocos, BTN_SIZE)
	_use_btn.visible = true
	if not _multi_unlocked:
		_multi_btn.visible = false
		return
	var multi: int = _get_multi_count(next_cost)
	var show_multi: bool = multi > 1
	_multi_btn.visible = show_multi
	if show_multi:
		_multi_label.text = "%s ×%d" % [_T(LSTR_MULTI), multi]


# 源 refreshCost :398-410：times<max → cost_board 显；否则 prompt 显
func _apply_source_visibility() -> void:
	var has_times: bool = _midas.midas_times < _get_max_times()
	_prompt.visible = not has_times
	_cost_board_root.visible = has_times


# 源 refreshButton :412-423：use 按钮文本 times<maxTimes → MIDAS.USE，否则 MIDAS.VIEW_VIP
func _refresh_button() -> void:
	var has_times: bool = _midas.midas_times < _get_max_times()
	_use_label.text = _T(LSTR_USE) if has_times else _T("MIDAS.VIEW_VIP")


# 源 setUseButtonEnabled :214-235：disabled shade 显 + label 灰；enable 隐 + label 原 色
func _apply_use_enabled() -> void:
	var use_col: Color = DISABLED_COLOR if _forbid_use else USE_LABEL_COLOR
	var multi_col: Color = DISABLED_COLOR if _forbid_use else MULTI_LABEL_COLOR
	if _use_shade != null:
		_use_shade.visible = _forbid_use
	if _use_label != null:
		_use_label.modulate = use_col
	if _multi_shade != null:
		_multi_shade.visible = _forbid_use
	if _multi_label != null:
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
		_show_confirm(times)
		return
	_do_exchange(times)


# multi 按钮按下时实时算 multi count（_midas.midas_times 变化后 multi 跟着变，无需重绑信号）。
func _on_multi_pressed() -> void:
	var next_cost: int = _get_next_cost()
	if next_cost == 0:
		return
	var multi: int = _get_multi_count(next_cost)
	if multi > 1:
		_on_use(multi)


# 源 doUse:191 + doUseReply:163：exchange + addMoney + createHistory + playGetAcquireAnim
func _do_exchange(times: int) -> void:
	_set_use_enabled(false)
	var r: Dictionary = _midas.exchange(_player, times)
	if not bool(r.get("ok", false)):
		# 源 doUse:195 showHandyDialog("toRecharge")；单机化无充值 → 降级 toast
		Toast.show_message(_T("DIALOG.OUT_OF_DIAMONDS_WANT_TO_GET_SOME"))
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


# 源 playGetAcquireAnim :37-161：crip 图(×2/3/10) + get_money 标题+金额，scale→move+fade 动作
# 资源缺 midas_crip*.png/midas_get_money.png → Label 降级（合并 title+money）
func _play_acquire_anim(ratio: int, money: int, play_delay: float, is_last: bool) -> void:
	if ratio >= 2 and CRIP_TEXT.has(ratio):
		_create_anim_label(str(CRIP_TEXT.get(ratio, "")), CRIP_COLOR.get(ratio, Color.WHITE), 48, CRIP_COCOS, Vector2(80.0, 48.0), play_delay, false)
	_create_anim_label("%s %d" % [GET_MONEY_TEXT, money], Color(1.0, 0.7, 0.2), 26, ANIM_ORI_COCOS, Vector2(160.0, 40.0), play_delay + 0.2, is_last)


# 暴击飘字 Label 工厂（_play_acquire_anim 提取，避免 crip/node 两段重复属性赋值）
func _create_anim_label(text: String, color: Color, font_sz: int, cocos: Vector2, sz: Vector2, delay: float, is_last: bool) -> Label:
	var node := Label.new()
	node.text = text
	node.modulate = color
	node.add_theme_font_size_override("font_size", font_sz)
	node.position = _center(cocos, sz)
	node.pivot_offset = sz * 0.5
	node.scale = Vector2(ANIM_SCALE, ANIM_SCALE)
	node.visible = false
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(node)
	_run_anim(node, delay, _to_godot(ANIM_END_COCOS), is_last)
	return node


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


# 源 createMultiWindow :556-665 popConfirmDialog：三段 ChaosNode（连续使用 N 次的得失 / 要花费： / 可获得：）
# + popConfirmDialog 默认 frame + 确认/取消（confirmdialog.lua 默认按钮 CHATCONFIG.CONFIRM/CANCEL）
func _show_confirm(times: int) -> void:
	var next_cost: int = _get_next_cost()
	var total_cost: int = next_cost * times
	var total_acquire: int = _get_next_acquire() * times
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
	# 源 :559-592 段1：midas.1.10.1.002(连续使用) + count + midas.1.10.1.003(次的得失)
	_make_label(_confirm_layer, "%s %d %s" % [_T(LSTR_MULTI), times, _T("midas.1.10.1.003")], CONFIRM_TEXT_COLOR, _left_mid(Vector2(400.0, 285.0), 24.0))
	# 源 :594-623 段2：midas.1.10.1.004(要花费：) + shop_token + "x"+count*cost
	_make_texture(_confirm_layer, RMB_ICON_RES, _center(Vector2(345.0, 255.0), COST_ICON_SIZE), COST_ICON_SIZE)
	_make_label(_confirm_layer, "%s ×%d" % [_T("midas.1.10.1.004"), total_cost], Color(50.0 / 255.0, 190.0 / 255.0, 223.0 / 255.0), _left_mid(Vector2(400.0, 255.0), 24.0))
	# 源 :625-655 段3：midas.1.10.1.005(可获得：) + goldicon + "x"+acquire
	_make_texture(_confirm_layer, GOLD_ICON_RES, _center(Vector2(345.0, 225.0), COST_ICON_SIZE), COST_ICON_SIZE)
	_make_label(_confirm_layer, "%s ×%d" % [_T("midas.1.10.1.005"), total_acquire], CONFIRM_GOLD_COLOR, _left_mid(Vector2(400.0, 225.0), 24.0))
	# 源 confirmdialog editorui 默认 sell_number_button + CHATCONFIG.CONFIRM/CANCEL
	var ok: Button = UiScale9Button.make(SELL_BTN_RES, SELL_BTN_PRESS_RES, _center(Vector2(340.0, 170.0), CONFIRM_BTN_SIZE), CONFIRM_BTN_SIZE, SELL_BTN_CAP, _T("CHATCONFIG.CONFIRM"), CONFIRM_BTN_LABEL_COLOR)
	ok.pressed.connect(func() -> void:
		_close_confirm()
		_do_exchange(times))
	_confirm_layer.add_child(ok)
	var cancel: Button = UiScale9Button.make(SELL_BTN_RES, SELL_BTN_PRESS_RES, _center(Vector2(460.0, 170.0), CONFIRM_BTN_SIZE), CONFIRM_BTN_SIZE, SELL_BTN_CAP, _T("CHATCONFIG.CANCEL"), CONFIRM_BTN_LABEL_COLOR)
	cancel.pressed.connect(_close_confirm)
	_confirm_layer.add_child(cancel)


func _close_confirm() -> void:
	if _confirm_layer != null and is_instance_valid(_confirm_layer):
		_confirm_layer.queue_free()
	_confirm_layer = null


# 源 createHistory :710-757 scrollView push（每行 initHistoryItemHandler :425-545 6 节点 + 可选 ratio 图）
# .tscn %HistoryHost 静态化（位置/size 固化），行 HBoxContainer 动态挂 host（局部坐标）。
# C8（2026-07-23）：照源补多节点（USE/cost/token icon/GET/gold icon/acquire + 可选 ratio 图）替单行 Label。
func _rebuild_history() -> void:
	for c in _history_host.get_children():
		c.queue_free()
	if _history.is_empty():
		return
	var y: float = HISTORY_START_Y
	for h in _history:
		var ratio: int = int(h.get("ratio", 1))
		var row := HBoxContainer.new()
		row.position = Vector2(HISTORY_ROW_X, y)
		row.add_theme_constant_override("separation", HISTORY_SEP)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 源 :466-475 USE label（ccc3(255,246,143)）
		_add_history_label(row, _T(LSTR_USE), HISTORY_USE_COLOR)
		# 源 :476-486 cost 数字（ccc3(50,223,253)）
		_add_history_label(row, str(int(h.get("cost", 0))), HISTORY_COST_COLOR)
		# 源 :487-496 shop_token icon（fix_height=30）
		_add_history_icon(row, HISTORY_TOKEN_RES)
		# 源 :497-507 GET label（ccc3(255,246,143)）
		_add_history_label(row, _T("ADDEQUIP.GET"), HISTORY_GET_COLOR)
		# 源 :508-517 goldicon_small（fix_height=35）
		_add_history_icon(row, HISTORY_GOLD_RES)
		# 源 :518-528 acquire 数字（ccc3(255,175,52)）
		_add_history_label(row, str(int(h.get("acquire", 0))), HISTORY_ACQUIRE_COLOR)
		# 源 :532-544 可选 ratio_res（ratio>=2，ccc3(255,104,174) or ratio=10 ccc3(194,91,68)）
		if ratio >= 2:
			_add_history_ratio(row, ratio)
		_history_host.add_child(row)
		y += HISTORY_LINE_HEIGHT


# 历史 HBoxContainer 子 Label 工厂（源 :466-528 各 Label 节点；text+color+size 一致）
func _add_history_label(parent: HBoxContainer, text: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.modulate = col
	lbl.add_theme_font_size_override("font_size", HISTORY_FONT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)


# 历史 HBoxContainer 子 TextureRect 工厂（源 :488-495 / :508-516 Sprite fix_height）
func _add_history_icon(parent: HBoxContainer, res_path: String) -> void:
	if not ResourceLoader.exists(res_path):
		return
	var tex: Texture2D = load(res_path) as Texture2D
	if tex == null:
		return
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	# 源 fix_height=N（按纹路高缩放保持宽高比，避 TextureRect 原尺寸撑大行高）
	var th: float = float(tex.get_height())
	var tw: float = float(tex.get_width())
	var ratio_h: float = HISTORY_ICON_H if th > 0.0 else HISTORY_ICON_H
	tr.custom_minimum_size = Vector2(tw * ratio_h / maxf(th, 1.0), HISTORY_ICON_H)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)


# 源 :532-544 ratio_res（ratio>=2）。midas_crip*.png 缺 → Label "×N" 降级（与 CRIP_TEXT 一致）。
func _add_history_ratio(parent: HBoxContainer, ratio: int) -> void:
	var res_path: String = String(HISTORY_RATIO_RES.get(ratio, ""))
	if res_path != "" and ResourceLoader.exists(res_path):
		_add_history_icon(parent, res_path)
		return
	# 降级 Label（源 ratio_config[ratio].color）
	var rtext: String = String(RATIO_TEXT.get(ratio, ""))
	if rtext == "":
		return
	_add_history_label(parent, rtext, RATIO_COLOR.get(ratio, Color.WHITE))


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


# 源 player.getMidasMaxTimes 基于 VIP level；单机化无 VIP → GradientPrice 表行数（兑换档数=最大次数）
func _get_max_times() -> int:
	return _cm.get_raw_table("GradientPrice").size()


# 坐标转换（源 cocos(800×480 左下) → Godot container(960×640 左上 offset 80,80)）。
# 静态方法保留：测试守护源→Godot 公式正确性 + _show_confirm/_play_acquire_anim 坐标计算复用。
static func _to_godot(cocos: Vector2) -> Vector2:
	return Vector2(cocos.x + OFFSET_X, PANEL_COCOS_H - cocos.y + OFFSET_Y)


# 中心 anchor(cocos 0.5) → Godot 左上
static func _center(cocos: Vector2, sz: Vector2) -> Vector2:
	return _to_godot(cocos) - sz * 0.5


# 左中 anchor(cocos 0,0.5) → Godot 左上
static func _left_mid(cocos: Vector2, h: float) -> Vector2:
	var g: Vector2 = _to_godot(cocos)
	return Vector2(g.x, g.y - h * 0.5)


# 辅助：装饰 TextureRect（_show_confirm 弹窗图标 procedural 创建）
func _make_texture(parent: Control, res_path: String, pos: Vector2, sz: Vector2) -> TextureRect:
	if not ResourceLoader.exists(res_path):
		return null
	var tr := TextureRect.new()
	tr.texture = load(res_path)
	tr.position = pos
	tr.size = sz
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr


# 辅助：装饰 Label（_show_confirm 弹窗文本 procedural 创建）
func _make_label(parent: Control, text: String, col: Color, pos: Vector2 = Vector2.ZERO, sz: int = 18) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.modulate = col
	lbl.add_theme_font_size_override("font_size", sz)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	return lbl


# 辅助：NinePatchRect（Scale9；_show_confirm 弹窗 frame procedural 创建）
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
