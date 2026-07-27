class_name TavernPanel
extends PopWindow

## 抽卡面板（View 层）— 照源 tavern.lua 完整复刻 scroll_board 滑动交互 + magic drop_bg 4 组预览
## （Phase 5.3，2026-07-13；.tscn 重构 2026-07-17）。
## panel 层静态节点（bg/title_bg/close/result/status/preview_container/preview_label/board_host）
## 从 tavern_content.tscn instantiate（位置/size 可视化），board 卡片（scroll_board 滑动机制 + drop_bg）
## 仍 procedural 由 TavernBoardBuilder.create_board 建（保留滑动交互）。
## 3 卡池 board（源 createItemLayer:1371 bronze/gold/magic）× per-board scroll_board 滑动展开：
## 点 check（源 doClickCheck:1576 上滑 320 露底部按钮区）/ arrow（doClickArrow:1584 滑回）/
## one_buy→doTavern("one") / ten_buy→doTavern("ten")。
## magic drop_bg 4 组 heroIcons（源 doRefrehMagicHeroIcon:1290：left3+right1+day3+month1）。
## Cost + Cost Type 从表读（TavernData.get_tavern_info），magic 源无单抽→builder 不建 once_buy。
## 已接入：免费单抽 + 首抽保底 + 抽卡动画(PopTavernLoot)。
## board 视觉节点 + 滑动机制 + drop_bg 在 TavernBoardBuilder（控行数）。
## 面板级 _preview_container 保留兼容 test_tavern_magic（非独占不能改），magic 主预览在 scroll_board 内。

signal drawn

const TavernBoardBuilder = preload("res://scripts/ui/tavern_board_builder.gd")
const ReadheroIcon = preload("res://scripts/view/battle/readhero_icon.gd")
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/tavern_content.tscn")
const POOL_KEYS: Array[String] = ["Bronze", "Gold", "MagicSoul"]
# board 横排中心照源 draglist(80,80)+board_bg ccp(160,205) → Godot (240,355)/(480,355)/(720,355)
const BOARD_CENTER_X: float = 240.0
const BOARD_DX: float = 240.0
const BOARD_CENTER_Y: float = 355.0
const REFRESH_INTERVAL_SEC: float = 1.0
const MAGIC_VIP_KEY: String = "Magic Soul Box"
# 由 panel 判 key==lstr 走 fallback）。
const LSTR_CHECK: StringName = &"RECHARGE.VIEW"
const LSTR_BUY_D: StringName = &"TAVERN.BUY__D"
const LSTR_DAY_TITLE: StringName = &"TAVERN.TODAYS_HIGHLIGHT"
const LSTR_MONTH_TITLE: StringName = &"TAVERN.HOT_IN_THIS_WEEK"
const LSTR_TEN_PROMPT: Dictionary = {
	"bronze": &"TAVERNRES.ONE_BLUE_ITEM_IS_DOOMED_TO_BE_GOT_IF_YOU_DRAW_10TIMES_AT_ONE_TIME",
	"gold": &"TAVERNRES.HERO_IS_DOOMED_TO_BE_GOT_IF_YOU_DRAW_10TIMES_AT_ONE_TIME",
	"magic": &"TAVERNRES.CAN_GET_MULTIPLE_SOUL_STONES",
}
# LSTR key 缺失时的中文 fallback（cm.get_lstr 缺失返 key 本身，panel 判 key==val 走 fallback）
const FALLBACK_CHECK: String = "查看"
const FALLBACK_BUY_FMT: String = "购买%d个"
const FALLBACK_DAY_TITLE: String = "今日热点"
const FALLBACK_MONTH_TITLE: String = "本周热点"
const FALLBACK_TEN_PROMPT: Dictionary = {
	"bronze": "十连抽必得蓝色物品",
	"gold": "十连抽必得英雄",
	"magic": "可获大量灵魂石",
}

var _cm: Variant = null
var _player: PlayerData = null
var _rng: BattleRng = null
var _current_pool: String = "Bronze"
var _boards: Dictionary = {}   # key -> builder 返回的 board Dictionary
var _result_label: Label = null
var _status_label: Label = null
var _preview_label: Label = null
var _preview_container: HBoxContainer = null
var _board_host: Control = null   # .tscn %BoardHost（3 board container 挂载点）
var _refresh_timer: float = 0.0


func setup_panel(p_player: PlayerData, rng: BattleRng) -> void:
	_player = p_player
	_rng = rng
	_cm = p_player.cm
	setup()
	_build_content()


# panel 层静态节点（bg/title_bg/close/result/status/preview_container/preview_label/board_host）
# 从 tavern_content.tscn instantiate（位置/size 可视化），board 卡片仍由 builder procedural 建。
func _build_content() -> void:
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	_board_host = content.get_node("%BoardHost") as Control
	_result_label = content.get_node("%ResultLabel") as Label
	_status_label = content.get_node("%StatusLabel") as Label
	_preview_container = content.get_node("%PreviewContainer") as HBoxContainer
	_preview_label = content.get_node("%PreviewLabel") as Label
	var close_btn: TextureButton = content.get_node("%CloseBtn") as TextureButton
	close_btn.pressed.connect(remove_window)
	_create_boards()
	_refresh_countdown_label()
	# HudOverlay 切 identity=tavern。
	HudOverlay.apply_identity("tavern")


# 关闭时恢复 HudOverlay identity=main。
func remove_window() -> void:
	HudOverlay.apply_identity("main")
	super.remove_window()


# createCommonLayer/createMagicLayer（scroll_board 13 节点 + 滑动 + magic drop_bg）。per-board check/arrow/one_buy/ten_buy。
# 末尾 playLightAnim（源 :1397）gold/magic light 旋转。
func _create_boards() -> void:
	for i in POOL_KEYS.size():
		var key: String = POOL_KEYS[i]
		var src_key: String = _src_key(key)
		var center: Vector2 = Vector2(BOARD_CENTER_X + BOARD_DX * i, BOARD_CENTER_Y)
		var cost_info: Dictionary = _read_cost_info(key)
		var handlers: Dictionary = {
			"on_check": _on_check_pressed.bind(key),
			"on_arrow": _on_arrow_pressed.bind(key),
			"on_once": _on_once_pressed.bind(key),
			"on_ten": _on_ten_pressed.bind(key),
		}
		var texts: Dictionary = _build_board_texts(src_key)
		var board: Dictionary = TavernBoardBuilder.create_board(src_key, center, cost_info, handlers, texts)
		_board_host.add_child(board["container"])
		_boards[key] = board
		TavernBoardBuilder.play_light_anim(board)
	_refresh_magic_board_visibility()


# showvip > vip → magicLayer.setVisible(false)（源同时重排 bronze/gold 居中；本项目简化保 3 board 横排孔位）。
# showvip <= vip → magicLayer.setVisible(true)（达 unlock-2 起显示；达 unlock 可抽，_on_draw 内门控）。
func _refresh_magic_board_visibility() -> void:
	if _player == null or _cm == null:
		return
	var showvip: int = VipData.get_area_show_vip(MAGIC_VIP_KEY, _cm)
	var magic_board: Dictionary = _boards.get("MagicSoul", {})
	if magic_board.is_empty():
		return
	var container: Control = magic_board.get("container", null)
	if container != null:
		container.visible = showvip <= _player.vip_level


func _build_board_texts(src_key: String) -> Dictionary:
	return {
		"check_label": _lstr_or(LSTR_CHECK, FALLBACK_CHECK),
		"once_label": _lstr_or(LSTR_BUY_D, FALLBACK_BUY_FMT) % 1,
		"ten_label": _lstr_or(LSTR_BUY_D, FALLBACK_BUY_FMT) % 10,
		"day_title": _lstr_or(LSTR_DAY_TITLE, FALLBACK_DAY_TITLE),
		"month_title": _lstr_or(LSTR_MONTH_TITLE, FALLBACK_MONTH_TITLE),
		"ten_prompt_text": _ten_prompt_text(src_key),
	}


func _ten_prompt_text(src_key: String) -> String:
	var lstr_key: StringName = LSTR_TEN_PROMPT.get(src_key, &"")
	if lstr_key == &"":
		return String(FALLBACK_TEN_PROMPT.get(src_key, ""))
	return _lstr_or(lstr_key, String(FALLBACK_TEN_PROMPT.get(src_key, "")))


# cm.get_lstr 缺失（返 key 本身）→ fallback。key 用 StringName 避免 String 比较开销。
func _lstr_or(key: StringName, fallback: String) -> String:
	if _cm == null or not _cm.has_method("get_lstr"):
		return fallback
	var v: String = _cm.get_lstr(String(key))
	return v if v != String(key) else fallback


func _src_key(pool_key: String) -> String:
	match pool_key:
		"Bronze": return "bronze"
		"Gold": return "gold"
		"MagicSoul": return "magic"
		_: return "bronze"


func _read_cost_info(key: String) -> Dictionary:
	var once_row: Dictionary = TavernData.get_tavern_info(key, false, false, 0, _cm)
	var ten_row: Dictionary = TavernData.get_tavern_info(key, true, false, 0, _cm)
	var once_cost: int = int(once_row.get("Cost", 0)) if not once_row.is_empty() else 0
	var once_pay: String = String(once_row.get("Cost Type", "Diamond")) if not once_row.is_empty() else "Diamond"
	return {
		"once_cost": once_cost,
		"ten_cost": int(ten_row.get("Cost", 0)),
		"once_pay": once_pay,
		"ten_pay": String(ten_row.get("Cost Type", "Diamond")),
	}


# 切当前 pool + 刷新倒计时/Magic 预览（供 _on_check_pressed 与外部切池调用，不触滑动）。
func _select_pool(key: String) -> void:
	_current_pool = key
	_refresh_countdown_label()
	_refresh_magicsoul_preview(key)


func _on_check_pressed(key: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_select_pool(key)
	TavernBoardBuilder.expand((_boards[key] as Dictionary)["scroll_board"])


func _on_arrow_pressed(key: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	TavernBoardBuilder.collapse((_boards[key] as Dictionary)["scroll_board"])


func _on_once_pressed(key: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_on_draw(_player, _rng, key, false)


func _on_ten_pressed(key: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_on_draw(_player, _rng, key, true)


# magic scroll_board drop_bg heroIcons 4 组（照源 left3+right1+day3+month1）+
# 面板级 _preview_container 单行（兼容 test_tavern_magic，前 4 hero）。
func _refresh_magicsoul_preview(key: String) -> void:
	if _preview_label == null or _preview_container == null:
		return
	if key == "MagicSoul" and _rng != null:
		var ids: Array[int] = TavernData.ask_magicsoul(_rng)
		_preview_label.text = "今日魂匣预览："
		_preview_label.visible = true
		# 面板级预览（兼容 test_tavern_magic，单行横排前 4 hero：extra+3hero）
		for c in _preview_container.get_children(): c.queue_free()
		for i in range(mini(ids.size(), 4)):
			var icon := _make_hero_preview_icon(ids[i])
			if icon != null:
				_preview_container.add_child(icon)
		_preview_container.visible = true
		# magic scroll_board drop_bg heroIcons 4 组（照源 doRefrehMagicHeroIcon:1290）
		_fill_magic_heroicons(ids)
	else:
		_preview_label.visible = false
		_preview_container.visible = false


# ids[0]=extra(hids[1]→right/month) ids[1,2,3]=hero(hids[2,3,4]→left/day)，照源 hids[5,6] 未用。
func _fill_magic_heroicons(ids: Array[int]) -> void:
	var magic: Dictionary = _boards.get("MagicSoul", {})
	if magic.is_empty():
		return
	var scroll: Control = magic["scroll_board"]
	# 清旧 heroIcons（set_meta "magic_icon" 标记）
	for c in scroll.get_children():
		if c.has_meta("magic_icon"):
			c.queue_free()
	if ids.is_empty():
		return
	var extra_id: int = ids[0]
	var hero_ids: Array[int] = []
	for i in range(1, mini(ids.size(), 4)):
		hero_ids.append(ids[i])
	# left 3 hero（源 ccp(42,175)/(82,175)/(122,175)，ox=42 dx=40）
	for i in hero_ids.size():
		_add_magic_icon(scroll, hero_ids[i], 42.0 + 40.0 * float(i), 175.0)
	# right 1 extra（源 ccp(175,175)）
	_add_magic_icon(scroll, extra_id, 175.0, 175.0)
	# day 3 hero（源 ccp(66,-140)/(108,-140)/(150,-140)，ox=66 dx=42）
	for i in hero_ids.size():
		_add_magic_icon(scroll, hero_ids[i], 66.0 + 42.0 * float(i), -140.0)
	# month 1 extra（源 ccp(107,-63)）
	_add_magic_icon(scroll, extra_id, 107.0, -63.0)


func _add_magic_icon(scroll: Control, tid: int, cx: float, cy: float) -> void:
	var icon := _make_hero_preview_icon(tid)
	if icon == null:
		return
	icon.set_meta("magic_icon", true)
	icon.custom_minimum_size = Vector2(38.0, 38.0)
	icon.size = Vector2(38.0, 38.0)
	icon.position = Vector2(cx, TavernBoardBuilder.CLIP_H - cy) - icon.size * 0.5
	scroll.add_child(icon)


func _make_hero_preview_icon(tid: int) -> Control:
	var unit: Variant = _cm.get_raw_table(&"Unit").get(str(tid), {})
	var hero_name: String = str(unit.get("Name", str(tid))) if unit is Dictionary else str(tid)
	var lbl := Label.new()
	lbl.text = hero_name
	lbl.custom_minimum_size = Vector2(60, 40)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl


func _on_draw(p_player: PlayerData, rng: BattleRng, tavern_type: String, is_ten: bool) -> void:
	# 项目单机化用 Toast（源 toRecharge dialog 的 explaination 文案）。
	if tavern_type == "MagicSoul":
		var ulv: int = VipData.get_area_unlock_vip(MAGIC_VIP_KEY, _cm)
		if ulv > p_player.vip_level:
			var tpl: String = String(_cm.get_lstr("TAVERN.VIP_LEVEL_TO_D_LEVELS_TO_UNLOCK_THIS_FEATURE_NEED_CHARGE"))
			if tpl == "TAVERN.VIP_LEVEL_TO_D_LEVELS_TO_UNLOCK_THIS_FEATURE_NEED_CHARGE":
				tpl = "VIP等级达到%d级解锁该功能，是否充值？"
			_result_label.text = tpl % ulv
			return
	var now: int = int(Time.get_unix_time_from_system())
	var is_free: bool = TavernData.is_show_free(p_player, tavern_type, now) and (tavern_type == "MagicSoul" or not is_ten)
	var r: Dictionary = p_player.draw_tavern_full(tavern_type, is_ten, is_free, 0, rng)
	if not bool(r["ok"]):
		_result_label.text = "资源不足"
		return
	if is_free:
		TavernData.use_free_tavern(p_player, tavern_type, now)
	TavernData.refresh_first_tavern(p_player, tavern_type, is_ten)
	GameData.mark_save_dirty()
	_result_label.text = "产出已展示"
	var loot_popup := PopTavernLoot.new("poptavernloot", {})
	var popup_cost: Dictionary = {"pay": "Diamond", "number": 0}
	if not is_free:
		var row: Dictionary = TavernData.get_tavern_info(tavern_type, is_ten, false, 0, _cm)
		popup_cost = {"pay": String(row.get("Cost Type", "Diamond")), "number": int(row.get("Cost", 0))}
	loot_popup.setup_loot(r["loots"], p_player.cm, tavern_type.to_lower(), "ten" if is_ten else "one", popup_cost)
	loot_popup.show_window(get_parent())
	drawn.emit()
	_refresh_countdown_label()


# 免费状态刷新（源 getCountdownText：CD 倒计时 / bronze 剩余次数）。
func _refresh_countdown_label() -> void:
	if _player == null or _status_label == null:
		return
	var now: int = int(Time.get_unix_time_from_system())
	_status_label.text = String(TavernData.get_countdown_text(_player, _current_pool, now)["text"])


func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer >= REFRESH_INTERVAL_SEC:
		_refresh_timer = 0.0
		_refresh_countdown_label()
