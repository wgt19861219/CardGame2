class_name MidasPanel
extends PopWindow

## 点石成金面板（View 层）— 照源 ui/midas.lua（1057 行）。
## 2026-07-17 重构（hero_detail 范式）：panel 层 18 节点静态化进 midas_content.tscn
## （frame/close/icon/name/desc/prompt/cost_board/use/multi + cost_board 内 bar 5 子），
## 本类 instantiate + get_node("%..") 取节点 + fill 动态数据（text/visible/数字）。
## 保留 procedural：playGetAcquireAnim 暴击飘字 + popConfirmDialog 连兑确认 + 历史记录动态挂。
## 坐标：源 cocos(800×480,y向上) → Godot container(960×640 FULL_RECT,cocos 居中 offset 80,80)。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/midas_content.tscn")

# _show_confirm 弹窗 frame + 图标 + 按钮（procedural 弹窗，非 .tscn 静态）
const FRAME_RES := "res://assets/ui/alpha/HVGA/main_vit_tips.png"
const FRAME_CAP: int = 10
const CONFIRM_FRAME_COCOS: Vector2 = Vector2(400.0, 240.0)
const CONFIRM_FRAME_SIZE: Vector2 = Vector2(360.0, 170.0)
const RMB_ICON_RES := "res://assets/ui/alpha/HVGA/task_rmb_icon_2.png"
const GOLD_ICON_RES := "res://assets/ui/alpha/HVGA/task_gold_icon_2.png"
const COST_ICON_SIZE: Vector2 = Vector2(28.0, 28.0)
const SELL_BTN_RES := "res://assets/ui/alpha/HVGA/sell_number_button.png"
const SELL_BTN_PRESS_RES := "res://assets/ui/alpha/HVGA/sell_number_button_down.png"
const SELL_BTN_CAP: Rect2 = Rect2(15.63, 15.63, 19.53, 15.63)
const CONFIRM_BTN_SIZE: Vector2 = Vector2(100.0, 36.0)
const CONFIRM_BTN_LABEL_COLOR: Color = Color(234.0 / 255.0, 225.0 / 255.0, 205.0 / 255.0)
const CONFIRM_TEXT_COLOR: Color = Color(231.0 / 255.0, 185.0 / 255.0, 108.0 / 255.0)
const CONFIRM_GOLD_COLOR: Color = Color(1.0, 170.0 / 255.0, 50.0 / 255.0)

const USE_COCOS: Vector2 = Vector2(130.0, 50.0)
const USE_COCOS_SOLO: Vector2 = Vector2(210.0, 50.0)
const BTN_SIZE: Vector2 = Vector2(150.0, 45.0)
const USE_LABEL_COLOR: Color = Color(231.0 / 255.0, 206.0 / 255.0, 19.0 / 255.0)
const MULTI_LABEL_COLOR: Color = Color(1.0, 1.0, 1.0)
const DISABLED_COLOR: Color = Color(150.0 / 255.0, 150.0 / 255.0, 150.0 / 255.0)

const CRIP_TEXT: Dictionary = {2: "×2", 3: "×3", 4: "×10"}
const CRIP_COLOR: Dictionary = {2: Color(1.0, 0.4, 0.7), 3: Color(1.0, 0.4, 0.7), 4: Color(1.0, 0.36, 0.27)}
const ANIM_ORI_COCOS: Vector2 = Vector2(400.0, 280.0)
const ANIM_END_COCOS: Vector2 = Vector2(400.0, 440.0)
const CRIP_COCOS: Vector2 = Vector2(400.0, 320.0)
const ANIM_SCALE: float = 3.0
const ANIM_SCALE_DUR: float = 0.2
const ANIM_MOVE_DUR: float = 1.0
const ANIM_FADE_DUR: float = 1.0
const GET_MONEY_TEXT: String = "获得金币"

const LSTR_PROMPT := "MIDAS.YOUVE_USED_UP_DAILY_GOLDEN_HAND_TIMES_\\N_UPGRADING_YOUR_VIP_LEVEL_OFFERS_YOU_MORE_TIMES"
const LSTR_USE := "MIDAS.USE"
const LSTR_MULTI := "midas.1.10.1.002"

var _midas: MidasManager
var _player: PlayerData
var _cm: ConfigManager
var _history: Array = []
var _content: Control = null
var _close_btn: TextureButton = null
var _use_btn: TextureButton = null
var _multi_btn: TextureButton = null
var _use_label: Label = null
var _multi_label: Label = null
var _use_shade: ColorRect = null
var _multi_shade: ColorRect = null
var _prompt: Label = null
var _cost_board_root: Control = null
var _cost_label: Label = null
var _acquire_label: Label = null
var _name_label: Label = null
var _desc_label: Label = null
var _history_host: Control = null
var _forbid_use: bool = false
var _multi_unlocked: bool = true
var _confirm_layer: Control = null


# LSTR 解析包装（cm 缺失返空串避免 null 解引用）。
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
	MidasRenderer.rebuild_history(_history_host, _history, func(k: String) -> String: return _T(k))


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


func _fill_buttons() -> void:
	var next_cost: int = _get_next_cost()
	if next_cost == 0:
		_use_btn.visible = false
		_multi_btn.visible = false
		return
	var use_cocos: Vector2 = USE_COCOS if _multi_unlocked else USE_COCOS_SOLO
	_use_btn.position = MidasRenderer.center(use_cocos, BTN_SIZE)
	_use_btn.visible = true
	if not _multi_unlocked:
		_multi_btn.visible = false
		return
	var multi: int = _get_multi_count(next_cost)
	var show_multi: bool = multi > 1
	_multi_btn.visible = show_multi
	if show_multi:
		_multi_label.text = "%s ×%d" % [_T(LSTR_MULTI), multi]


func _apply_source_visibility() -> void:
	var has_times: bool = _midas.midas_times < _get_max_times()
	_prompt.visible = not has_times
	_cost_board_root.visible = has_times


func _refresh_button() -> void:
	var has_times: bool = _midas.midas_times < _get_max_times()
	_use_label.text = _T(LSTR_USE) if has_times else _T("MIDAS.VIEW_VIP")


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


func _do_exchange(times: int) -> void:
	_set_use_enabled(false)
	var r: Dictionary = _midas.exchange(_player, times)
	if not bool(r.get("ok", false)):
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
	node.position = MidasRenderer.center(cocos, sz)
	node.pivot_offset = sz * 0.5
	node.scale = Vector2(ANIM_SCALE, ANIM_SCALE)
	node.visible = false
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(node)
	_run_anim(node, delay, MidasRenderer.to_godot(ANIM_END_COCOS), is_last)
	return node


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
	MidasRenderer.add_nine_patch(_confirm_layer, FRAME_RES, MidasRenderer.center(CONFIRM_FRAME_COCOS, CONFIRM_FRAME_SIZE), CONFIRM_FRAME_SIZE, FRAME_CAP)
	MidasRenderer.make_label(_confirm_layer, "%s %d %s" % [_T(LSTR_MULTI), times, _T("midas.1.10.1.003")], CONFIRM_TEXT_COLOR, MidasRenderer.left_mid(Vector2(400.0, 285.0), 24.0))
	MidasRenderer.make_texture(_confirm_layer, RMB_ICON_RES, MidasRenderer.center(Vector2(345.0, 255.0), COST_ICON_SIZE), COST_ICON_SIZE)
	MidasRenderer.make_label(_confirm_layer, "%s ×%d" % [_T("midas.1.10.1.004"), total_cost], Color(50.0 / 255.0, 190.0 / 255.0, 223.0 / 255.0), MidasRenderer.left_mid(Vector2(400.0, 255.0), 24.0))
	MidasRenderer.make_texture(_confirm_layer, GOLD_ICON_RES, MidasRenderer.center(Vector2(345.0, 225.0), COST_ICON_SIZE), COST_ICON_SIZE)
	MidasRenderer.make_label(_confirm_layer, "%s ×%d" % [_T("midas.1.10.1.005"), total_acquire], CONFIRM_GOLD_COLOR, MidasRenderer.left_mid(Vector2(400.0, 225.0), 24.0))
	var ok: Button = UiScale9Button.make(SELL_BTN_RES, SELL_BTN_PRESS_RES, MidasRenderer.center(Vector2(340.0, 170.0), CONFIRM_BTN_SIZE), CONFIRM_BTN_SIZE, SELL_BTN_CAP, _T("CHATCONFIG.CONFIRM"), CONFIRM_BTN_LABEL_COLOR)
	ok.pressed.connect(func() -> void:
		_close_confirm()
		_do_exchange(times))
	_confirm_layer.add_child(ok)
	var cancel: Button = UiScale9Button.make(SELL_BTN_RES, SELL_BTN_PRESS_RES, MidasRenderer.center(Vector2(460.0, 170.0), CONFIRM_BTN_SIZE), CONFIRM_BTN_SIZE, SELL_BTN_CAP, _T("CHATCONFIG.CANCEL"), CONFIRM_BTN_LABEL_COLOR)
	cancel.pressed.connect(_close_confirm)
	_confirm_layer.add_child(cancel)


func _close_confirm() -> void:
	if _confirm_layer != null and is_instance_valid(_confirm_layer):
		_confirm_layer.queue_free()
	_confirm_layer = null


func _get_next_cost() -> int:
	var idx: int = _midas.midas_times + 1
	return int(_cm.get_raw_table("GradientPrice").get(str(idx), {}).get("Midas", 0))


func _get_next_acquire() -> int:
	var idx: int = _midas.midas_times + 1
	var yield_rate: float = float(_cm.get_raw_table("Midas").get(str(idx), {}).get("Yield 1", 1.0))
	var base_money: int = int(_cm.get_raw_table("PlayerLevel").get(str(_player.team_level), {}).get("Midas Money", 5000))
	return int(float(base_money) * yield_rate)


func _get_multi_count(cost: int) -> int:
	var count: int = 0
	var gt: Dictionary = _cm.get_raw_table("GradientPrice")
	while (_midas.midas_times + count + 1) <= gt.size():
		var c: int = int(gt.get(str(_midas.midas_times + count + 1), {}).get("Midas", 0))
		if c != cost:
			break
		count += 1
	return maxi(count, 1)


func _get_max_times() -> int:
	return _cm.get_raw_table("GradientPrice").size()
