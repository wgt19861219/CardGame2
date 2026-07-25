class_name StoneDetailPanel
extends PopWindow

## 碎片详情面板（View 层）— 照源 ui/stonedetail.lua（702 行）。
## 功能：未拥有英雄点碎片不足时弹此面板，展示 碎片图标 + 英雄名 + 拥有量/需求 +
## 获取途径关卡列表（Drop1-3）+ 返回按钮。源 mainLayer(shade) + frame(fragment_compose_bg) +
## infoContainer(285×388 子坐标系) + draglist(获取途径列表)。
## 重构范式：base 层静态化进 stone_detail_content.tscn（位置/size 可视化），运行时 fill 动态数据。
## 坐标：源 cocos(800×480 左下) → Godot(960×640 左上)。
## infoContainer 源位于 ccp(400,242) size(285,388)，anchor(0.5,0.5) → bottom-left cocos(257.5,48)。
## 其子节点 local(cx,cy) → Godot = (337.5+cx, 512-cy)。frame bg 同 rect（fragment_compose_bg 288×385）。

signal jump_to_stage(stage_id: int)

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/stone_detail_content.tscn")

# ── 资源路径 ──
const GETWAY_BOARD_PATH: String = "res://assets/ui/alpha/HVGA/equip_craft_getway_board.png"
const OK_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-n.png"
const OK_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-pressed-n.png"
const OK_CAP: Rect2 = Rect2(15.0, 15.0, 138.0, 19.0)
# ── 颜色（源 ccc3）──
const COLOR_NAME: Color = Color(184.0 / 255.0, 6.0 / 255.0, 6.0 / 255.0)
const COLOR_WAY_TITLE: Color = Color(155.0 / 255.0, 34.0 / 255.0, 14.0 / 255.0)
const COLOR_AMOUNT_OK: Color = Color(169.0 / 255.0, 91.0 / 255.0, 28.0 / 255.0)
const COLOR_AMOUNT_LOW: Color = Color(226.0 / 255.0, 18.0 / 255.0, 18.0 / 255.0)
const COLOR_BOARD_TITLE: Color = Color(182.0 / 255.0, 65.0 / 255.0, 21.0 / 255.0)
const COLOR_ELITE: Color = Color(1.0, 0.0, 0.0)
const COLOR_LIMIT_OK: Color = COLOR_AMOUNT_OK
const COLOR_LIMIT_LOW: Color = COLOR_AMOUNT_LOW
const COLOR_NOT_OPEN: Color = COLOR_AMOUNT_LOW
const COLOR_EMPTY: Color = Color(109.0 / 255.0, 62.0 / 255.0, 0.0)
# ── LSTR key（源 LSTR 宏，cm.get_lstr 解析；fallback 同步 zh-CN 值）──
const LSTR_WAY_TITLE: String = "STONEDETAIL.WAY_TO_GET_"
const LSTR_WAY_FALLBACK: String = "获得途径："
const LSTR_NOT_OPEN: String = "STONEDETAIL.NOT_YET_OPEN"
const LSTR_NOT_OPEN_FALLBACK: String = "（未开放）"
const LSTR_EMPTY_DEFAULT: String = "STONEDETAIL.THE_HERO_DEBRIS_WILL_NOT_BE_GAINED_FROM_THIS_CROSS_TEMPORARILY"
const LSTR_EMPTY_FALLBACK: String = "该英雄碎片暂不由关卡掉落"
const LSTR_OK: String = "EQUIPCRAFT.RETURN"
const LSTR_OK_FALLBACK: String = "返回"
const LSTR_ELITE: String = "EQUIPCRAFT.ELITE"
const LSTR_CHAPTER_D: String = "EQUIPCRAFT._CHAPTER__D"
const LSTR_CHAPTER_YET: String = "EQUIPCRAFT.CHAPTER_YET_TO_OPEN"
const LSTR_CHAPTER_YET_FALLBACK: String = "关卡尚未开启。"
# ── infoContainer 坐标变换常量（源 :514 setPosition(400,242) + size(285,388) anchor 0.5,0.5）──
const ICO_OFFSET_X: float = 337.5   # 400 - 285/2 + 80（infoContainer bottom-left cocos.x → Godot.x）
const ICO_BASE_Y: float = 512.0     # 560 - (242 - 388/2)（infoContainer bottom-left cocos.y → Godot.y）
# ── 获取途径 board 布局（源 :272 ox,oy + :286 y-50*(i-1)）──
const GETWAY_OX_COCOS: float = 142.0
const GETWAY_OY_COCOS: float = 220.0
const GETWAY_DY: float = 50.0
const MAX_DROPS: int = 3   # 数据表 Drop 1..3（grep 确认 Drop 4 不存在，同 equipcraft）
# board 内子节点（源 :303-356 icon/title/elite/name 相对 board 左下 y-up）
const BOARD_PADDING: float = 5.0
const BOARD_ICON_FIX_H: float = 40.0
const BOARD_NAME_MAX_W: float = 160.0


var cm: Variant = null
var pd: PlayerData = null
var _hero_mgr: HeroManager = null
var _tid: int = 0
var _stone_id: int = 0
var _content: Control = null            # .tscn 根
var _getway_buttons: Array = []
var _getway_ids: Array = []
var _stone_icon_host: Control = null
var _getway_host: Control = null


func setup_panel(p_tid: int, p_cm: Variant, p_pd: PlayerData, p_hero_mgr: HeroManager) -> void:
	_tid = p_tid
	cm = p_cm
	pd = p_pd
	_hero_mgr = p_hero_mgr
	_stone_id = ReadheroHandbook.get_stone_id(_tid, cm)
	setup()
	_build_content()
	_fill_stone_icon()
	_fill_amount()
	_build_getway_list()
	register_on_enter(func() -> void: AudioPlayer.play_sfx("common_popup_window"))


# infoContainer 子节点 cocos local → Godot：cx+337.5, 512-cy（见类头注释推导）。
func _g(cx: float, cy: float) -> Vector2:
	return Vector2(cx + ICO_OFFSET_X, ICO_BASE_Y - cy)


# 运行时 fill 动态数据/连接信号。碎片图标 + 获取途径列表保留 procedural 挂 host。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	# name（源 :521-527 text=self:getName() = Unit[tid]["Display Name"]）
	var name_lbl: Label = _content.get_node("%NameLabel") as Label
	name_lbl.text = _hero_display_name()
	name_lbl.modulate = COLOR_NAME
	# way title（源 :161-172 STONEDETAIL.WAY_TO_GET_）
	var way_lbl: Label = _content.get_node("%WayTitleLabel") as Label
	way_lbl.text = cm.get_lstr(LSTR_WAY_TITLE) if cm != null else LSTR_WAY_FALLBACK
	way_lbl.modulate = COLOR_WAY_TITLE
	# close（源 :535-555 close + close_press 双层 Sprite → .tscn TextureButton 双态）
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(_on_close_pressed)
	# ok 按钮（源 :557-600 Scale9 cap 15,15,138,19 + ok_label "返回"）— .tscn Button 运行时套 Scale9
	var ok_btn: Button = _content.get_node("%OkBtn") as Button
	var ok_text: String = cm.get_lstr(LSTR_OK) if cm != null else LSTR_OK_FALLBACK
	UiScale9Button.apply_with_label(ok_btn, OK_RES, OK_PRESS_RES, OK_CAP, ok_text)
	ok_btn.pressed.connect(_on_ok_pressed)
	_stone_icon_host = _content.get_node("%StoneIconHost") as Control
	_getway_host = _content.get_node("%GetwayHost") as Control


func _hero_display_name() -> String:
	var row: Dictionary = cm.get_raw_table(&"Unit").get(str(_tid), {})
	return String(row.get(&"Display Name", ""))


func _fill_stone_icon() -> void:
	var amount: int = ReadheroHandbook.get_stone_amount(_tid, cm, _hero_mgr)
	var icon: Control = ReadequipIcon.create_icon(_stone_id, amount, cm)
	icon.position = _g(60.0, 290.0)
	_stone_icon_host.add_child(icon)


func _fill_amount() -> void:
	var amount: int = ReadheroHandbook.get_stone_amount(_tid, cm, _hero_mgr)
	var need: int = ReadheroHandbook.get_stone_need(_tid, cm, _hero_mgr)
	(_content.get_node("%AmountLabel") as Label).text = str(amount)
	(_content.get_node("%AmountLabel") as Label).modulate = COLOR_AMOUNT_LOW if amount < need else COLOR_AMOUNT_OK
	(_content.get_node("%AmountNeedLabel") as Label).text = "/" + str(need) + ")"


func _build_getway_list() -> void:
	_getway_buttons.clear()
	_getway_ids.clear()
	var equip_info: Dictionary = cm.get_raw_table(&"Equip").get(str(_stone_id), {})
	var stage_table: Dictionary = cm.get_raw_table(&"Stage")
	var max_chapter: int = int(cm.get_raw_table(&"GameConfig").get("MaxChapter", 13))
	var drops: Array = []
	for i in range(1, MAX_DROPS + 1):
		var s: int = int(equip_info.get("Drop " + str(i), 0))
		if s > 0:
			var st_row: Dictionary = stage_table.get(str(s), {})
			if int(st_row.get("Chapter ID", 0)) <= max_chapter:
				drops.append(s)
	if drops.is_empty():
		_show_empty_prompt(equip_info)
		return
	for i in range(drops.size()):
		_build_one_getway(stage_table, drops[i], i)
		_getway_ids.append(drops[i])


func _show_empty_prompt(equip_info: Dictionary) -> void:
	var lbl: Label = _content.get_node("%EmptyPromptLabel") as Label
	var text_key: String = String(equip_info.get("How To Get", LSTR_EMPTY_DEFAULT))
	lbl.text = cm.get_lstr(text_key) if cm != null else LSTR_EMPTY_FALLBACK
	if cm == null:
		lbl.text = LSTR_EMPTY_FALLBACK
	lbl.modulate = COLOR_EMPTY
	lbl.visible = true


func _build_one_getway(stage_table: Dictionary, raw_sid: int, idx: int) -> void:
	var is_elite: bool = StageAccount.stage_type(raw_sid) == "elite"
	var sid: int = raw_sid
	if is_elite:
		sid = int(stage_table.get(str(raw_sid), {}).get("Stage Group", raw_sid))
	var stage_row: Dictionary = stage_table.get(str(sid), {})
	# board（源 :280-291 equip_craft_getway_board.png at (ox, oy-50*(i-1))，anchor 0.5,0.5）
	var board := TextureRect.new()
	board.texture = load(GETWAY_BOARD_PATH)
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var board_size: Vector2 = TexDisplaySize.display_size(GETWAY_BOARD_PATH)
	board.size = board_size
	var center: Vector2 = _g(GETWAY_OX_COCOS, GETWAY_OY_COCOS - GETWAY_DY * float(idx))
	board.position = center - board_size * 0.5
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.gui_input.connect(_make_getway_handler(idx))
	_getway_host.add_child(board)
	# stage 图标（源 :299-308 getStageIcon(id) at (35,25) fix_height=75）
	var icon_path: String = StageRes.get_stage_icon(sid, cm)
	if ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size = Vector2(BOARD_ICON_FIX_H, BOARD_ICON_FIX_H)
		icon.position = Vector2(BOARD_PADDING, BOARD_PADDING)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.add_child(icon)
	# title（源 :309-324 "第X章" LSTR._CHAPTER__D at (65,35) anchor(0,0.5)）
	var chapter_id: int = int(stage_row.get("Chapter ID", 0))
	var title := Label.new()
	title.text = (cm.get_lstr(LSTR_CHAPTER_D) if cm != null else "第%d章") % chapter_id
	title.position = Vector2(65.0 - 0.0, 35.0 - title.get_combined_minimum_size().y * 0.5)
	title.modulate = COLOR_BOARD_TITLE
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(title)
	# elite（源 :325-344 "精英" right2 title offset=6，红字，visible=isElite）
	if is_elite:
		var elite := Label.new()
		elite.text = cm.get_lstr(LSTR_ELITE) if cm != null else "精英"
		elite.position = Vector2(65.0 + title.get_combined_minimum_size().x + 6.0, 35.0 - elite.get_combined_minimum_size().y * 0.5)
		elite.modulate = COLOR_ELITE
		elite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.add_child(elite)
	# name（源 :345-360 Stage Name at (68,12) anchor(0,0.5) max_width=160）
	var name_lbl := Label.new()
	name_lbl.text = String(stage_row.get("Stage Name", ""))
	name_lbl.position = Vector2(68.0, 12.0 - name_lbl.get_combined_minimum_size().y * 0.5)
	name_lbl.modulate = COLOR_BOARD_TITLE
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(name_lbl)
	var name_w: float = name_lbl.get_combined_minimum_size().x
	if name_w > BOARD_NAME_MAX_W:
		var sc: float = BOARD_NAME_MAX_W / name_w
		name_lbl.scale = Vector2(sc, sc)
	# 剩余次数（源 refreshGetwayLimit :374-450 limitContainer）
	_add_limit_label(board, raw_sid, title, is_elite)
	_getway_buttons.append(board)


# count > 0 棕色，count==0 红色。limitContainer 在 elite 右侧（ed.getRightSidePos(gw.elite)）。
func _add_limit_label(board: Control, raw_sid: int, title_node: Label, is_elite: bool) -> void:
	if not _is_stage_open(raw_sid):
		var not_open := Label.new()
		not_open.text = cm.get_lstr(LSTR_NOT_OPEN) if cm != null else LSTR_NOT_OPEN_FALLBACK
		not_open.modulate = COLOR_NOT_OPEN
		not_open.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tx: float = 65.0 + title_node.get_combined_minimum_size().x
		if is_elite and board.get_child_count() >= 4:
			var elite_node: Node = board.get_child(3)
			if elite_node is Label:
				tx = (elite_node as Label).position.x + (elite_node as Label).get_combined_minimum_size().x + 4.0
		not_open.position = Vector2(tx, 35.0 - not_open.get_combined_minimum_size().y * 0.5)
		board.add_child(not_open)
		return
	var stage_table: Dictionary = cm.get_raw_table(&"Stage")
	var limit: int = int(stage_table.get(str(raw_sid), {}).get("Daily Limit", 0))
	if limit <= 0:
		return
	var lookup_sid: int = int(stage_table.get(str(raw_sid), {}).get("Stage Group", raw_sid)) if is_elite else raw_sid
	var used: int = int(pd.stage_limit.get(lookup_sid, 0))
	var count: int = maxi(0, limit - used)
	var lbl := Label.new()
	lbl.text = "(" + str(count) + "/" + str(limit) + ")"
	lbl.modulate = COLOR_LIMIT_OK if count > 0 else COLOR_LIMIT_LOW
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tx2: float = 65.0 + title_node.get_combined_minimum_size().x
	if is_elite and board.get_child_count() >= 4:
		var elite_node2: Node = board.get_child(3)
		if elite_node2 is Label:
			tx2 = (elite_node2 as Label).position.x + (elite_node2 as Label).get_combined_minimum_size().x + 4.0
	lbl.position = Vector2(tx2, 35.0 - lbl.get_combined_minimum_size().y * 0.5)
	board.add_child(lbl)


func _is_stage_open(sid: int) -> bool:
	var star: int = pd.stage_manager.stage_stars(sid)
	var prev: int = pd.stage_manager.stage_stars(sid - 1)
	return star + prev > 0


# 本项目 pushScene 降级为 jump_to_stage 信号（调用方可接 SceneManager；未接时面板内 toast 兜底）。
func _on_get_way_clicked(stage_id: int) -> void:
	var st: String = StageAccount.stage_type(stage_id)
	if st != "normal" and st != "elite":
		return
	if _is_stage_open(stage_id):
		AudioPlayer.play_sfx("common_click_feedback")
		jump_to_stage.emit(stage_id)
		remove_window()
	else:
		_show_toast(cm.get_lstr(LSTR_CHAPTER_YET) if cm != null else LSTR_CHAPTER_YET_FALLBACK)


func _make_getway_handler(idx: int) -> Callable:
	return func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			if idx < _getway_ids.size():
				_on_get_way_clicked(int(_getway_ids[idx]))


func _show_toast(text: String) -> void:
	Toast.show_message(text)


func _on_close_pressed() -> void:
	AudioPlayer.play_sfx("common_close_popup_window")
	remove_window()


func _on_ok_pressed() -> void:
	AudioPlayer.play_sfx("common_close_popup_window")
	remove_window()
