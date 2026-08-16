class_name MidasPanel
extends PopWindow

## 点石成金面板（View 层）— 照源 ui/midas.lua（1057 行）。
## 批 2 Task 6 两件套改造（2026-08-16）：静态结构归 midas_content.tscn
## （坐标照源直译：readnode 第二段挂 ui.content，content 原点 cocos(187.5,172.5)，
## 修正旧版当场景空间的系统性偏移）；历史区 = 行模板 + MidasFills 纯 fill；
## 连兑确认 = 独立 MidasConfirm 弹窗（源 popConfirmDialog）。
## 保留 procedural：暴击飘字 transient Label（唯一动态节点构造）。
## 按钮位置切换（源 refreshMultiUseButton 解锁/锁定）fill 用 godot 预计算常量。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/midas_content.tscn")

# use 按钮双位（源 refreshMultiUseButton :1025-1034：(130,50)/(210,50) content 局部
# → 场景 (317.5,222.5)/(397.5,222.5) → godot 中心 (397.5,337.5)/(477.5,337.5)，
# 减半宽 75 → 左上 pos）。
const USE_POS: Vector2 = Vector2(322.5, 315.0)
const USE_POS_SOLO: Vector2 = Vector2(402.5, 315.0)

# 暴击飘字坐标（源 playGetAcquireAnim :100-160 (400,320)/(400,280)/(400,440) 场景空间
# → godot 中心 (480,240)/(480,280)/(480,120)，pos=中心-半尺寸）。
const CRIP_POS: Vector2 = Vector2(440.0, 216.0)
const ANIM_ORI_POS: Vector2 = Vector2(400.0, 260.0)
const ANIM_END_CENTER: Vector2 = Vector2(480.0, 120.0)

const ANIM_SCALE: float = 3.0
const ANIM_SCALE_DUR: float = 0.2
const ANIM_MOVE_DUR: float = 1.0
const ANIM_FADE_DUR: float = 1.0
const CRIP_TEXT: Dictionary = {2: "×2", 3: "×3", 4: "×10"}
const CRIP_COLOR: Dictionary = {2: Color(1.0, 0.4, 0.7), 3: Color(1.0, 0.4, 0.7), 4: Color(1.0, 0.36, 0.27)}
const GET_MONEY_TEXT: String = "获得金币"

const USE_LABEL_COLOR: Color = Color(231.0 / 255.0, 206.0 / 255.0, 19.0 / 255.0)
const MULTI_LABEL_COLOR: Color = Color(1.0, 1.0, 1.0)
const DISABLED_COLOR: Color = Color(150.0 / 255.0, 150.0 / 255.0, 150.0 / 255.0)

const LSTR_PROMPT := "MIDAS.YOUVE_USED_UP_DAILY_GOLDEN_HAND_TIMES_\\N_UPGRADING_YOUR_VIP_LEVEL_OFFERS_YOU_MORE_TIMES"
const LSTR_USE := "MIDAS.USE"
const LSTR_MULTI := "midas.1.10.1.002"
const LSTR_MULTI_UNLOCK: StringName = &"Multiple Midas"

var _midas: MidasManager
var _player: PlayerData
var _cm: ConfigManager
var _history: Array = []
var _content: Control = null
var _close_btn: TextureButton = null
var _use_btn: Button = null
var _multi_btn: Button = null
var _use_label: Label = null
var _multi_label: Label = null
var _use_disabled_tex: TextureRect = null
var _prompt: Label = null
var _cost_board_root: Control = null
var _cost_label: Label = null
var _acquire_label: Label = null
var _name_label: Label = null
var _desc_label: Label = null
var _times_text_label: Label = null
var _times_left_label: Label = null
var _times_max_label: Label = null
var _history_frame: CanvasItem = null
var _history_scroll: ScrollContainer = null
var _history_rows: VBoxContainer = null
var _forbid_use: bool = false
var _multi_unlocked: bool = true
var _confirm_window: MidasConfirm = null


# LSTR 解析包装（cm 缺失返空串避免 null 解引用）。
func _T(key: String) -> String:
	if _cm == null:
		return ""
	return String(_cm.get_lstr(key))


func _make_resolver() -> Callable:
	return func(k: String) -> String: return _T(k)


func setup_panel(p_player: PlayerData) -> void:
	_player = p_player
	_midas = _player.midas
	_cm = _player.cm
	var limit := FeatureLimit.new(_cm)
	_multi_unlocked = limit.check_area_unlock(LSTR_MULTI_UNLOCK, _player.team_level, _player.vip_level)
	setup()
	_build_content()
	_refresh_view()


# 建内容：instantiate .tscn + 缓存节点引用 + 绑信号。位置/size .tscn 已固化不碰。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	_close_btn = _content.get_node("%CloseBtn") as TextureButton
	_close_btn.pressed.connect(remove_window)
	_use_btn = _content.get_node("%UseBtn") as Button
	_multi_btn = _content.get_node("%MultiBtn") as Button
	_use_disabled_tex = _use_btn.get_child(0) as TextureRect
	_use_label = _use_btn.get_node("Label") as Label
	_multi_label = _multi_btn.get_node("Label") as Label
	_use_btn.pressed.connect(_on_use.bind(1))
	_multi_btn.pressed.connect(_on_multi_pressed)
	_name_label = _content.get_node("%NameLabel") as Label
	_desc_label = _content.get_node("%DescLabel") as Label
	_prompt = _content.get_node("%PromptLabel") as Label
	_cost_board_root = _content.get_node("%CostBoardRoot") as Control
	_cost_label = _content.get_node("%CostLabel") as Label
	_acquire_label = _content.get_node("%AcquireLabel") as Label
	_times_text_label = _content.get_node("%TimesTextLabel") as Label
	_times_left_label = _content.get_node("%TimesLeftLabel") as Label
	_times_max_label = _content.get_node("%TimesMaxLabel") as Label
	_history_frame = _content.get_node("%HistoryFrame") as CanvasItem
	_history_scroll = _content.get_node("%HistoryScroll") as ScrollContainer
	_history_rows = _content.get_node("%HistoryRows") as VBoxContainer


# fill 动态数据（text/visible/数字/按钮 position）；不 free content（常驻）。
func _refresh_view() -> void:
	_fill_text()
	_fill_cost_board()
	_fill_buttons()
	_apply_source_visibility()
	_refresh_button()
	_apply_use_enabled()
	_fill_history()


func _fill_text() -> void:
	_name_label.text = _T("MIDAS.GOLDEN_HAND")
	_desc_label.text = _T("MIDAS.USE_A_SMALL_AMOUNT_OF_DIAMONDS_IN_EXCHANGE_FOR_LARGE_SUMS_OF_MONEY")
	var left: int = maxi(_get_max_times() - _midas.midas_times, 0)
	_times_text_label.text = _T("MIDAS.AVAILABLE_TODAY")
	_times_left_label.text = str(left)
	_times_max_label.text = "/" + str(_get_max_times())
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
	_use_btn.position = USE_POS if _multi_unlocked else USE_POS_SOLO
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


# 历史区（源 createHistory :710-757 首次兑换建框 + refreshHistory push 逐条）：
# 静态化后 visible 切换 + MidasFills 全量 fill（行模板 + 滚到底）。
func _fill_history() -> void:
	_history_frame.visible = not _history.is_empty()
	MidasFills.fill_history_rows(_history_scroll, _history_rows, _history, _make_resolver())


func _apply_use_enabled() -> void:
	var use_col: Color = DISABLED_COLOR if _forbid_use else USE_LABEL_COLOR
	var multi_col: Color = DISABLED_COLOR if _forbid_use else MULTI_LABEL_COLOR
	if _use_disabled_tex != null:
		_use_disabled_tex.visible = _forbid_use
	if _use_label != null:
		_use_label.modulate = use_col
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
		_create_anim_label(str(CRIP_TEXT.get(ratio, "")), CRIP_COLOR.get(ratio, Color.WHITE), 48, CRIP_POS, Vector2(80.0, 48.0), play_delay, false)
	_create_anim_label("%s %d" % [GET_MONEY_TEXT, money], Color(1.0, 0.7, 0.2), 26, ANIM_ORI_POS, Vector2(160.0, 40.0), play_delay + 0.2, is_last)


# 暴击飘字 Label 工厂（transient 动画节点，panel 唯一动态 UI 构造；坐标 godot 预计算）。
func _create_anim_label(text: String, color: Color, font_sz: int, pos: Vector2, sz: Vector2, delay: float, is_last: bool) -> Label:
	var node := Label.new()
	node.text = text
	node.modulate = color
	node.add_theme_font_size_override("font_size", font_sz)
	node.position = pos
	node.pivot_offset = sz * 0.5
	node.scale = Vector2(ANIM_SCALE, ANIM_SCALE)
	node.visible = false
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(node)
	_run_anim(node, delay, ANIM_END_CENTER - sz * 0.5, is_last)
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


# 连兑确认弹窗（源 createMultiWindow :550-666 → 独立 MidasConfirm PopWindow）。
func _show_confirm(times: int) -> void:
	var next_cost: int = _get_next_cost()
	var total_cost: int = next_cost * times
	var total_acquire: int = _get_next_acquire() * times
	var confirm := MidasConfirm.new("midasconfirm")
	confirm.setup_confirm(times, total_cost, total_acquire, _make_resolver(), func() -> void: _do_exchange(times))
	confirm.show_window(get_parent())
	_confirm_window = confirm


func _close_confirm() -> void:
	if _confirm_window != null and is_instance_valid(_confirm_window):
		_confirm_window.remove_window()
	_confirm_window = null


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
