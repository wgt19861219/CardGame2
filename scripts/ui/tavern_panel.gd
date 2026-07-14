class_name TavernPanel
extends PopWindow

## 抽卡面板（View 层）— 照源 tavern.lua 完整复刻 scroll_board 滑动交互 + magic drop_bg 4 组预览
## （Phase 5.3，2026-07-13）。
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
const POOL_KEYS: Array[String] = ["Bronze", "Gold", "MagicSoul"]
# board 横排中心照源 draglist(80,80)+board_bg ccp(160,205) → Godot (240,355)/(480,355)/(720,355)
const BOARD_CENTER_X: float = 240.0
const BOARD_DX: float = 240.0
const BOARD_CENTER_Y: float = 355.0
const BG_FULL: String = "res://assets/ui/alpha/HVGA/bg.jpg"
const TITLE_BG_RES: String = "res://assets/ui/alpha/HVGA/tavern_title_bg.png"
const TITLE_BG_POS: Vector2 = Vector2(160.0, 180.0)
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/backbtn.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/backbtn-disabled.png"
const CLOSE_BTN_POS: Vector2 = Vector2(20.0, 15.0)  # 左上角留小边（用户偏好更靠左上角）
const RESULT_POS: Vector2 = Vector2(380.0, 420.0)
const STATUS_POS: Vector2 = Vector2(380.0, 240.0)
const PREVIEW_POS: Vector2 = Vector2(380.0, 460.0)
const REFRESH_INTERVAL_SEC: float = 1.0

var _cm: Variant = null
var _player: PlayerData = null
var _rng: BattleRng = null
var _current_pool: String = "Bronze"
var _boards: Dictionary = {}   # key -> builder 返回的 board Dictionary
var _result_label: Label = null
var _status_label: Label = null
var _preview_label: Label = null
var _preview_container: HBoxContainer = null
var _refresh_timer: float = 0.0


func setup_panel(p_player: PlayerData, rng: BattleRng) -> void:
	_player = p_player
	_rng = rng
	_cm = p_player.cm
	setup()
	_create_background()
	_create_close_button()
	_create_boards()
	_create_result_label()
	_status_label = Label.new()
	_status_label.position = STATUS_POS
	container.add_child(_status_label)
	_preview_container = HBoxContainer.new()
	_preview_container.position = Vector2(200.0, 460.0)
	_preview_container.size = Vector2(400.0, 60.0)
	_preview_container.visible = false
	container.add_child(_preview_container)
	_preview_label = Label.new()
	_preview_label.position = PREVIEW_POS
	_preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_preview_label)
	_refresh_countdown_label()


# 面板背景（照源 framework bg.jpg 全屏 + tavern.lua tavern_title_bg :620 标题图）。
func _create_background() -> void:
	var bg := TextureRect.new()
	bg.texture = load(BG_FULL) as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.size = Vector2(960.0, 640.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)
	var title := TextureRect.new()
	title.texture = load(TITLE_BG_RES) as Texture2D
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if title.texture != null:
		title.size = title.texture.get_size()
		title.position = TITLE_BG_POS
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(title)


func _create_close_button() -> void:
	var btn: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS_RES, CLOSE_BTN_POS)
	btn.pressed.connect(remove_window)
	container.add_child(btn)


# 源 createItemLayer:1371 — 3 卡池 board（bronze/gold/magic），每 board = createBaseBoard +
# createCommonLayer/createMagicLayer（scroll_board 13 节点 + 滑动 + magic drop_bg）。per-board check/arrow/one_buy/ten_buy。
func _create_boards() -> void:
	for i in POOL_KEYS.size():
		var key: String = POOL_KEYS[i]
		var center: Vector2 = Vector2(BOARD_CENTER_X + BOARD_DX * i, BOARD_CENTER_Y)
		var cost_info: Dictionary = _read_cost_info(key)
		var handlers: Dictionary = {
			"on_check": _on_check_pressed.bind(key),
			"on_arrow": _on_arrow_pressed.bind(key),
			"on_once": _on_once_pressed.bind(key),
			"on_ten": _on_ten_pressed.bind(key),
		}
		var board: Dictionary = TavernBoardBuilder.create_board(_src_key(key), center, cost_info, handlers)
		container.add_child(board["container"])
		_boards[key] = board


func _src_key(pool_key: String) -> String:
	match pool_key:
		"Bronze": return "bronze"
		"Gold": return "gold"
		"MagicSoul": return "magic"
		_: return "bronze"


# 源 getCost:219 — 读表 Cost + Cost Type（Bronze Gold / Gold·MagicSoul Diamond）。
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


# 源 doCheckTouch:1589 → doClickCheck:1576 — 点 check 切当前 pool + 上滑展开该 board。
func _on_check_pressed(key: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_select_pool(key)
	TavernBoardBuilder.expand((_boards[key] as Dictionary)["scroll_board"])


# 源 doArrowTouch:1690 → doClickArrow:1584 — 点 arrow 滑回该 board。
func _on_arrow_pressed(key: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	TavernBoardBuilder.collapse((_boards[key] as Dictionary)["scroll_board"])


# 源 doOneTouch:1621 → doTavern(key,"one") / doTenTouch:1659 → doTavern(key,"ten")。
func _on_once_pressed(key: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_on_draw(_player, _rng, key, false)


func _on_ten_pressed(key: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_on_draw(_player, _rng, key, true)


# 源 doRefrehMagicHeroIcon:1290 + refreshMagicHeroIcon:1355 — Magic 魂匣预览。
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


# 源 doRefrehMagicHeroIcon:1290 — magic scroll_board 4 组 heroIcons（left3+right1+day3+month1）。
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


# 源 readhero.createIcon({id,length=38}) — 建预览英雄 icon（降级 Label 38×38，centered at cocos (cx,cy)）。
func _add_magic_icon(scroll: Control, tid: int, cx: float, cy: float) -> void:
	var icon := _make_hero_preview_icon(tid)
	if icon == null:
		return
	icon.set_meta("magic_icon", true)
	icon.custom_minimum_size = Vector2(38.0, 38.0)
	icon.size = Vector2(38.0, 38.0)
	# 源 scroll_board (cx,cy) 中心 → Godot 局部 position（y=CLIP_H-cy）
	icon.position = Vector2(cx, TavernBoardBuilder.CLIP_H - cy) - icon.size * 0.5
	scroll.add_child(icon)


# 源 readhero.createIcon({id,length=38}) — 建预览英雄 icon（降级 Label）。
func _make_hero_preview_icon(tid: int) -> Control:
	var unit: Variant = _cm.get_raw_table(&"Unit").get(str(tid), {})
	var hero_name: String = str(unit.get("Name", str(tid))) if unit is Dictionary else str(tid)
	var lbl := Label.new()
	lbl.text = hero_name
	lbl.custom_minimum_size = Vector2(60, 40)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl


func _create_result_label() -> void:
	_result_label = Label.new()
	_result_label.position = RESULT_POS
	_result_label.text = "点击抽卡"
	container.add_child(_result_label)


func _on_draw(p_player: PlayerData, rng: BattleRng, tavern_type: String, is_ten: bool) -> void:
	# 源 doTavern isFree（tavern.lua:67-70）：单抽且 isShowFree；magic 例外十连也判 isShowFree。
	var now: int = int(Time.get_unix_time_from_system())
	var is_free: bool = TavernData.is_show_free(p_player, tavern_type, now) and (tavern_type == "MagicSoul" or not is_ten)
	var r: Dictionary = p_player.draw_tavern_full(tavern_type, is_ten, is_free, 0, rng)
	if not bool(r["ok"]):
		_result_label.text = "资源不足"
		return
	if is_free:
		TavernData.use_free_tavern(p_player, tavern_type, now)
	# 源 network.lua:1295 服务端回复后 refreshFirstTavern 置首抽标记；单机化抽卡成功后直调。
	TavernData.refresh_first_tavern(p_player, tavern_type, is_ten)
	_result_label.text = "产出已展示"
	var loot_popup := PopTavernLoot.new("poptavernloot", {})
	loot_popup.setup_loot(r["loots"], p_player.cm, tavern_type.to_lower())
	loot_popup.show_window(get_parent())
	drawn.emit()
	_refresh_countdown_label()


# 免费状态刷新（源 getCountdownText：CD 倒计时 / bronze 剩余次数）。
func _refresh_countdown_label() -> void:
	if _player == null or _status_label == null:
		return
	var now: int = int(Time.get_unix_time_from_system())
	_status_label.text = String(TavernData.get_countdown_text(_player, _current_pool, now)["text"])


# 源 refreshCountdownHandler:387 — 每秒刷新倒计时。
func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer >= REFRESH_INTERVAL_SEC:
		_refresh_timer = 0.0
		_refresh_countdown_label()
