class_name StageSelectPanel
extends PopWindow

## 关卡选择（View 层）— 照源 stageselect.lua 地图式布局翻译。
## 重构（2026-07-17）：base 静态元素（bg/close/mode toggle/箭头）从 stage_select_content.tscn
## instantiate（位置/size 编辑器可视化调）。动态层（map_layer 章节 bg+route+stage 圆点、frame/title、
## chapter dots）procedural 由 StageSelectBuilder 建并挂 %MapLayerHost/%FrameLayer/%DotContainer。
## doChangeChapter(:423)/createDot(:676)/createModeButton(:725)/setChapterButtonState(:643)。
## 切换动画（2026-07-20 补全）：章节切 map slide±720/title fade（frame 章节不重建，照源 createFrame
## 仅 create/mode 调，行 325/1618）；mode 切 map fadeOut 0.5 + frame/title/dots fade 0.2；
## 持续 arrow 呼吸(:714-721) + pointer 浮动(:1308-1311)。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/stage_select_content.tscn")
const StageSelectBuilder = preload("res://scripts/ui/stage_select_builder.gd")
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
const META_FRAME: StringName = &"ss_frame"
const META_TITLE: StringName = &"ss_title"
const META_POINTER: StringName = &"ss_pointer"
const META_BOBBED: StringName = &"ss_bobbed"

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
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	if shade_layer != null:
		shade_layer.color.a = 0
		shade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	StageSelectBuilder.fill_mode_toggle(_mode_buttons, _mode, player.cm)
	# 用户偏好（2026-07-20）：frame 太大贴屏边 → 所有 frame 内元素 scale 0.9 about frame center(480,355)
	# （frame+map+mode+dots+箭头 等比缩保相对布局；close 返回键 + FrameworkBg 全屏 bg 不缩）。
	var _mode_layer: Control = _content.get_node("%ModeLayer") as Control
	for t in [_frame_layer, _map_host, _dot_container, _mode_layer]:
		(t as Control).pivot_offset = Vector2(480.0, 355.0)
		(t as Control).scale = Vector2(0.9, 0.9)
	for arrow in [_content.get_node("%PrevArrow"), _content.get_node("%NextArrow")]:
		var a := arrow as Control
		a.pivot_offset = Vector2(480.0 - a.offset_left, 355.0 - a.offset_top)
		a.scale = Vector2(0.9, 0.9)
	_refresh_view("init")


# setup_panel 在 show_window 前（panel 未入树），持续动画须等入树后启动（同 equip_strengthen_anim.gd:93 范式）。
func _enter_tree() -> void:
	_start_arrow_bob()
	_bob_all_pointers()


# op="init"（首次，无动画）/ "chapter"（map slide + title fade；frame 章节不重建，照源 createFrame 不随章节）/ "mode"（map fadeOut + frame/title/dots fade）。
func _refresh_view(op: String = "init") -> void:
	var cm: Variant = player.cm if player != null else null
	var star_of: Callable = Callable(self, "_get_stage_stars")
	var max_ch: int = mgr.get_max_chapter(_mode) if mgr != null else _current_chapter
	# --- map layer（源 createMap:1359，章节 slide / mode fadeOut）---
	if op == "init":
		_clear_children(_map_host)
	var old_map: Array = _map_host.get_children() if op != "init" else []
	var map_layer: Dictionary = StageSelectBuilder.create_map_layer(_map_host, _current_chapter, _mode, cm, star_of)
	_stage_buttons = map_layer["stage_buttons"]
	for sid in _stage_buttons:
		(_stage_buttons[sid] as TextureButton).pressed.connect(_on_stage_clicked.bind(sid))
	_play_map_transition(old_map, map_layer["node"] as Control, op)
	# --- frame（源 createFrame:944，章节 skip；init 清+建；mode 重建 fade）---
	if op == "init":
		_clear_children(_frame_layer)
		StageSelectBuilder.create_frame(_frame_layer, _mode)
	elif op == "mode":
		var old_frame: Array = _meta_children(_frame_layer, META_FRAME)
		StageSelectBuilder.create_frame(_frame_layer, _mode)
		_crossfade_diff(old_frame, _meta_children(_frame_layer, META_FRAME), LAYER_FADE_TIME)
	# --- title（源 createTitle:885，章节/mode 都 fade；init 直接）---
	var old_title: Array = _meta_children(_frame_layer, META_TITLE) if op != "init" else []
	StageSelectBuilder.create_title(_frame_layer, _current_chapter, cm)
	if op != "init":
		_crossfade_diff(old_title, _meta_children(_frame_layer, META_TITLE), LAYER_FADE_TIME)
	# --- mode toggle + arrows visibility（源 setChapterButtonState:643 边界隐藏）---
	StageSelectBuilder.fill_mode_toggle(_mode_buttons, _mode, cm)
	(_content.get_node("%PrevArrow") as CanvasItem).visible = _current_chapter > 1
	(_content.get_node("%NextArrow") as CanvasItem).visible = _current_chapter < max_ch
	# --- dots（源 refreshDot:667/createDot:676，mode fade 0.2；章节/init 无 fade 直接重建，源 createDot:677 移除旧容器）---
	if op == "mode":
		var old_dots := _dot_container.get_children()
		StageSelectBuilder.create_chapter_dots(_dot_container, max_ch, _current_chapter, _mode)
		_crossfade_diff(old_dots, _dot_container.get_children(), LAYER_FADE_TIME)
	else:
		_clear_children(_dot_container)
		StageSelectBuilder.create_chapter_dots(_dot_container, max_ch, _current_chapter, _mode)
	# 启动新 pointer 浮动（未入树时 _bob_pointer 守卫跳过，_enter_tree 兜底；切换后新 pointer 在此启动）
	_bob_all_pointers()


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
		var base_x: float = StageSelectBuilder.CLIP_RECT.position.x
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
	var detail := StageDetailPanel.new("stagedetail", {})
	detail.setup_panel(sid, mgr, player, rng)
	detail.show_window(get_parent())
