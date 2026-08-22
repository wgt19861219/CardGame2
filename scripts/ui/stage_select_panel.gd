class_name StageSelectPanel
extends PopWindow

## 关卡选择（View 层）— 照源 stageselect.lua 地图式布局翻译。
## 两件套（批3 Task 5，2026-08-16）：静态底板（bg/close/mode toggle/箭头/挂载层）在
## stage_select_content.tscn；动态层（map layer 章节 bg+route+stage 圆点、frame/title、
## chapter dots）由 stage_select_fills.gd 构造（原 StageSelectBuilder 317 行退役归并）。
## doChangeChapter(:423)/createDot(:676)/createModeButton(:725)/setChapterButtonState(:643)。
## 切换动画族（2026-07-30/31 补全，Task 5 保留不破坏）：章节切 map slide±720/title fade
## （frame 章节不重建，照源 createFrame 仅 create/mode 调，行 325/1618）；mode 切 map
## fadeOut 0.5 + frame/title/dots fade 0.2；持续 arrow 呼吸(:714-721) + pointer 浮动(:1308-1311)。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/stage_select_content.tscn")
const StageSelectFills = preload("res://scripts/ui/stage_select_fills.gd")
const StageDetailPanel = preload("res://scripts/ui/stage_detail_panel.gd")

# createFrame:976/createTitle:908/refreshDot:671 CCFadeIn/Out 0.2 / createChapterButton:714 CCMoveTo 1s /
# currentTag:1308 CCMoveTo 0.5s）。
const MAP_SLIDE_TIME: float = 0.5
const MAP_FADE_TIME: float = 0.5
const LAYER_FADE_TIME: float = 0.2
const MAP_SLIDE_DIST: float = 720.0
const ARROW_BOB_TIME: float = 1.0
const ARROW_BOB_DX: float = 10.0
const POINTER_BOB_TIME: float = 0.5
const POINTER_BOB_DY: float = 10.0
# 源 stageselect.lua:1234-1237 CCFadeTo(1,0)+CCFadeTo(1,255)：1s 完全淡出↔1s 回满，周期 2s
# （2026-08-22 巡检订正：旧 0.6s/0.3↔1.0 周期 1.2s 且不完全消失）。
const MASK_BLINK_TIME: float = 1.0
const MASK_ALPHA_MIN: float = 0.0
const MASK_ALPHA_MAX: float = 1.0
const META_FRAME: StringName = StageSelectFills.META_FRAME
const META_TITLE: StringName = StageSelectFills.META_TITLE
const META_POINTER: StringName = StageSelectFills.META_POINTER
const META_BOBBED: StringName = &"ss_bobbed"
const META_MASK: StringName = StageSelectFills.META_MASK
const META_MASK_BLINKED: StringName = &"ss_mask_blinked"

var mgr: StageManager = null
var player: PlayerData = null
var rng: BattleRng = null
var _current_chapter: int = 1
var _pre_chapter: int = 1   # 切换前章节，算 map slide 方向（源 self.preChapter）
var _mode: String = "normal"
var _stage_buttons: Dictionary = {}   # sid -> TextureButton（_refresh_view 重建）
var _content: Control = null
var _map_host: Control = null
var _frame_layer: Control = null
var _dot_container: Control = null
var _mode_buttons: Dictionary = {}   # mode -> TextureButton（.tscn %ModeXxxBtn）
var _arrows_bobbing: bool = false


func setup_panel(p_mgr: StageManager, p_player: PlayerData, p_rng: BattleRng) -> void:
	hud_identity = "stageselect"   # T4：原 apply/remove override 样板上收基类
	transparent_shade = true   # T4：原 shade 透明 hack 上收基类
	mgr = p_mgr
	player = p_player
	rng = p_rng
	_current_chapter = mgr.get_max_chapter("normal") if mgr != null else 1
	_pre_chapter = _current_chapter
	setup()
	_build_content()


func setup_by_stage(p_mgr: StageManager, p_player: PlayerData, p_rng: BattleRng, stage_id: int) -> void:
	mgr = p_mgr
	player = p_player
	rng = p_rng
	_current_chapter = _chapter_of_stage(stage_id)
	_pre_chapter = _current_chapter
	setup()
	_build_content()


func _chapter_of_stage(stage_id: int) -> int:
	var st: Dictionary = player.cm.get_raw_table(&"Stage")
	var sid: int = stage_id
	if stage_id >= 10000:
		sid = int(st.get(str(stage_id), {}).get("Stage Group", stage_id))
	return int(st.get(str(sid), {}).get("Chapter ID", 1))


# 建 UI 内容：base 从 .tscn instantiate（位置/size 固化）+ bind signals + fill mode toggle 文本。
# 本项目单机化 pushScene→PopWindow，故 shade 透明 + .tscn %FrameworkBg 补 bg.jpg 还原源视觉。
# 注：2026-07-20 组缩放 0.9/ModeLayer -30 系偏大口径（base×cs 漏÷CS）补偿，随 Task 5
# 贴图口径修正一并撤销（源 mode 区中心 y=205/210 直译）。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	_map_host = _content.get_node("%MapLayerHost") as Control
	_frame_layer = _content.get_node("%FrameLayer") as Control
	_dot_container = _content.get_node("%DotContainer") as Control
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	for mode in ["normal", "elite", "guild"]:
		var btn: TextureButton = _content.get_node("%Mode" + mode.capitalize() + "Btn") as TextureButton
		_mode_buttons[mode] = btn
		btn.pressed.connect(_on_mode_pressed.bind(mode))
	(_content.get_node("%PrevArrow") as BaseButton).pressed.connect(_on_prev_chapter)
	(_content.get_node("%NextArrow") as BaseButton).pressed.connect(_on_next_chapter)
	StageSelectFills.fill_mode_toggle(_mode_buttons, _mode, player.cm)
	_refresh_view("init")
	# HudOverlay 切 identity=stageselect（强制展开 shortcut + 子场景货币条）。



# setup_panel 在 show_window 前（panel 未入树），持续动画须等入树后启动（同 equip_strengthen_anim.gd:93 范式）。
func _enter_tree() -> void:
	_start_arrow_bob()
	_bob_all_pointers()
	_blink_all_masks()


# op="init"（首次，无动画）/ "chapter"（map slide + title fade；frame 章节不重建，照源 createFrame 不随章节）/ "mode"（map fadeOut + frame/title/dots fade）。
func _refresh_view(op: String = "init") -> void:
	var cm: Variant = player.cm if player != null else null
	var star_of: Callable = Callable(self, "_get_stage_stars")
	var max_ch: int = mgr.get_max_chapter(_mode) if mgr != null else _current_chapter
	# --- map layer（源 createMap:1359，章节 slide / mode fadeOut）---
	if op == "init":
		_clear_children(_map_host)
	var old_map: Array = _map_host.get_children() if op != "init" else []
	var map_layer: Dictionary = StageSelectFills.create_map_layer(_map_host, _current_chapter, _mode, cm, star_of)
	_stage_buttons = map_layer["stage_buttons"]
	for sid in _stage_buttons:
		(_stage_buttons[sid] as TextureButton).pressed.connect(_on_stage_clicked.bind(sid))
	_play_map_transition(old_map, map_layer["node"] as Control, op)
	# --- frame（源 createFrame:944，章节 skip；init 清+建；mode 重建 fade）---
	if op == "init":
		_clear_children(_frame_layer)
		StageSelectFills.create_frame(_frame_layer, _mode)
	elif op == "mode":
		var old_frame: Array = _meta_children(_frame_layer, META_FRAME)
		StageSelectFills.create_frame(_frame_layer, _mode)
		_crossfade_diff(old_frame, _meta_children(_frame_layer, META_FRAME), LAYER_FADE_TIME)
	# --- title（源 createTitle:885，章节/mode 都 fade；init 直接）---
	var old_title: Array = _meta_children(_frame_layer, META_TITLE) if op != "init" else []
	StageSelectFills.create_title(_frame_layer, _current_chapter, cm)
	if op != "init":
		_crossfade_diff(old_title, _meta_children(_frame_layer, META_TITLE), LAYER_FADE_TIME)
	# --- mode toggle + arrows visibility（源 setChapterButtonState:643 边界隐藏）---
	StageSelectFills.fill_mode_toggle(_mode_buttons, _mode, cm)
	(_content.get_node("%PrevArrow") as CanvasItem).visible = _current_chapter > 1
	(_content.get_node("%NextArrow") as CanvasItem).visible = _current_chapter < max_ch
	# --- dots（源 refreshDot:667/createDot:676，mode fade 0.2；章节/init 无 fade 直接重建，源 createDot:677 移除旧容器）---
	if op == "mode":
		var old_dots := _dot_container.get_children()
		StageSelectFills.create_chapter_dots(_dot_container, max_ch, _current_chapter, _mode)
		_crossfade_diff(old_dots, _dot_container.get_children(), LAYER_FADE_TIME)
	else:
		_clear_children(_dot_container)
		StageSelectFills.create_chapter_dots(_dot_container, max_ch, _current_chapter, _mode)
	# guild 模式 dots 隐藏（源 createDot :698-702 dotContainer:setVisible(false)）
	_dot_container.visible = _mode != "guild"
	# 启动新 pointer 浮动（未入树时 _bob_pointer 守卫跳过，_enter_tree 兜底；切换后新 pointer 在此启动）
	_bob_all_pointers()
	_blink_all_masks()


static func _clear_children(host: Control) -> void:
	for c in host.get_children():
		c.free()


static func _meta_children(host: Control, key: StringName) -> Array:
	var out: Array = []
	for c in host.get_children():
		if c is CanvasItem and c.get_meta(key, false):
			out.append(c)
	return out


# 旧节点 fadeOut→free，新节点（all - old）fadeIn。源 createFrame/createTitle/refreshDot crossfade 0.2s。
func _crossfade_diff(old: Array, all_nodes: Array, time: float) -> void:
	for c in old:
		if is_instance_valid(c):
			var tw := create_tween()
			tw.tween_property(c, "modulate:a", 0.0, time)
			tw.tween_callback(c.free)
	for c in all_nodes:
		if c not in old and is_instance_valid(c):
			(c as CanvasItem).modulate.a = 0.0
			var tw := create_tween()
			tw.tween_property(c, "modulate:a", 1.0, time)


func _play_map_transition(old_maps: Array, new_map: Control, op: String) -> void:
	if op == "init" or old_maps.is_empty() or new_map == null:
		return
	if op == "chapter":
		var dir: float = 1.0 if _current_chapter > _pre_chapter else -1.0
		var base_x: float = StageSelectFills.CLIP_RECT.position.x
		new_map.position.x = base_x + dir * MAP_SLIDE_DIST
		var tw := create_tween()
		tw.tween_property(new_map, "position:x", base_x, MAP_SLIDE_TIME).set_ease(Tween.EASE_OUT)
		for old in old_maps:
			if is_instance_valid(old):
				(old as CanvasItem).position.x = base_x
				var tw2 := create_tween()
				tw2.tween_property(old, "position:x", base_x - dir * MAP_SLIDE_DIST, MAP_SLIDE_TIME).set_ease(Tween.EASE_OUT)
				tw2.tween_callback((old as Node).free)
	elif op == "mode":
		for old in old_maps:
			if is_instance_valid(old):
				var tw := create_tween()
				tw.tween_property(old, "modulate:a", 0.0, MAP_FADE_TIME)
				tw.tween_callback((old as Node).free)


func _start_arrow_bob() -> void:
	if _arrows_bobbing or _content == null or not is_instance_valid(_content):
		return
	_arrows_bobbing = true
	_bob_x(_content.get_node_or_null("%PrevArrow") as CanvasItem, -ARROW_BOB_DX)
	_bob_x(_content.get_node_or_null("%NextArrow") as CanvasItem, ARROW_BOB_DX)


func _bob_x(node: CanvasItem, dx: float) -> void:
	if node == null or not node.is_inside_tree():
		return
	var base_x: float = node.position.x
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "position:x", base_x + dx, ARROW_BOB_TIME)
	tw.tween_property(node, "position:x", base_x, ARROW_BOB_TIME)


func _bob_all_pointers() -> void:
	if _map_host == null:
		return
	for layer in _map_host.get_children():
		if not (layer is Control):
			continue
		for c in (layer as Control).get_children():
			if c.has_meta(META_POINTER) and not c.get_meta(META_BOBBED, false):
				_bob_pointer(c as CanvasItem)


func _bob_pointer(p: CanvasItem) -> void:
	if p == null or not p.is_inside_tree() or p.get_meta(META_BOBBED, false):
		return
	var base_y: float = p.position.y
	var tw := p.create_tween().set_loops()
	tw.tween_property(p, "position:y", base_y - POINTER_BOB_DY, POINTER_BOB_TIME)
	tw.tween_property(p, "position:y", base_y, POINTER_BOB_TIME)
	p.set_meta(META_BOBBED, true)


# 钥匙关 current/passed mask 循环 alpha 闪烁（源 stageselect.lua:1229-1238 FadeTo 0.3↔1.0）。
# mask 与 stage btn 平级挂 map layer（Task 5 照源 :1229-1241 平级直译），遍历 layer 子级。
func _blink_all_masks() -> void:
	if _map_host == null:
		return
	for layer in _map_host.get_children():
		if not (layer is Control):
			continue
		for c in (layer as Control).get_children():
			if c.has_meta(META_MASK) and not c.get_meta(META_MASK_BLINKED, false):
				_blink_mask(c as CanvasItem)


func _blink_mask(m: CanvasItem) -> void:
	if m == null or not m.is_inside_tree() or m.get_meta(META_MASK_BLINKED, false):
		return
	var tw := m.create_tween().set_loops()
	tw.tween_property(m, "modulate:a", MASK_ALPHA_MIN, MASK_BLINK_TIME)
	tw.tween_property(m, "modulate:a", MASK_ALPHA_MAX, MASK_BLINK_TIME)
	m.set_meta(META_MASK_BLINKED, true)


func _get_stage_stars(sid: int) -> int:
	if mgr == null:
		return 0
	return mgr.stage_stars(sid)


func _on_mode_pressed(mode: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_mode = mode
	_current_chapter = mgr.get_max_chapter(mode) if mgr != null else 1
	_refresh_view("mode")


func _on_prev_chapter() -> void:
	_change_chapter(-1)


func _on_next_chapter() -> void:
	_change_chapter(1)


func _change_chapter(delta: int) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var max_ch: int = mgr.get_max_chapter(_mode) if mgr != null else StageSelectMap.CHAPTER_MAX
	_pre_chapter = _current_chapter
	_current_chapter = clampi(_current_chapter + delta, 1, max_ch)
	if _current_chapter != _pre_chapter:
		_refresh_view("chapter")


func _on_stage_clicked(sid: int) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	if mgr == null or player == null or rng == null:
		return
	# 详情标题栏复用关卡选择的章节标题栏（FrameLayer 下 procedural Label，全屏绝对坐标 z=201）。
	# 详情打开期间把它的文字从章节名（如"第一章 全军出击"）改成当前关卡名（如"异界战场"），
	# 详情关闭（tree_exited）时恢复章节名（2026-07-30）。详情自身的 Title 节点已删（避免两个标题重叠）。
	_set_chapter_title_text(_stage_name(sid))
	var detail := StageDetailPanel.new("stagedetail", {})
	detail.setup_panel(sid, mgr, player, rng)
	detail.show_window(get_parent())
	detail.tree_exited.connect(_on_detail_closed)


# 详情关闭时恢复章节标题为当前章节名。
func _on_detail_closed() -> void:
	_set_chapter_title_text(_chapter_name())


# 取关卡名（Stage 表 "Stage Name" 经 get_lstr 本地化，同 stage_detail_panel._get_stage_info 口径）。
func _stage_name(sid: int) -> String:
	if player == null:
		return ""
	var row: Dictionary = player.cm.get_raw_table(&"Stage").get(str(sid), {})
	return String(player.cm.get_lstr(String(row.get("Stage Name", str(sid)))))


# 取当前章节名（Chapter 表 "Pre Chapter Name" + "Chapter Name"，同 StageSelectFills.create_title 口径）。
func _chapter_name() -> String:
	if player == null:
		return ""
	var cm: Variant = player.cm
	var ch_row: Dictionary = cm.get_raw_table(&"Chapter").get(str(_current_chapter), {})
	var pre: String = String(cm.get_lstr(String(ch_row.get("Pre Chapter Name", ""))))
	var name: String = String(cm.get_lstr(String(ch_row.get("Chapter Name", ""))))
	return pre + "   " + name if not name.is_empty() else ("第 " + str(_current_chapter) + " 章")


# 设 FrameLayer 下带 META_TITLE 的章节标题 Label 的文字（create_title procedural 建的 Label）。
func _set_chapter_title_text(t: String) -> void:
	if _frame_layer == null:
		return
	for c in _meta_children(_frame_layer, META_TITLE):
		if is_instance_valid(c) and c is Label:
			(c as Label).text = t
