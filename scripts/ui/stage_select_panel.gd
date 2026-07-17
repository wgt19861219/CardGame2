class_name StageSelectPanel
extends PopWindow

## 关卡选择（View 层）— 照源 stageselect.lua 地图式布局翻译。
## 重构（2026-07-17）：base 静态元素（bg/close/mode toggle/箭头）从 stage_select_content.tscn
## instantiate（位置/size 编辑器可视化调）。动态层（map_layer 章节 bg+route+stage 圆点、frame/title、
## chapter dots）procedural 由 StageSelectBuilder 建并挂 %MapLayerHost/%FrameLayer/%DotContainer。
## 源 stageselect.lua create(:1573)/createMap(:1359)/createStage(:1212)/doChangeMode(:319)/
## doChangeChapter(:423)/createDot(:676)/createModeButton(:725)/setChapterButtonState(:643)。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/stage_select_content.tscn")
const StageSelectBuilder = preload("res://scripts/ui/stage_select_builder.gd")
const StageDetailPanel = preload("res://scripts/ui/stage_detail_panel.gd")

var mgr: StageManager = null
var player: PlayerData = null
var rng: BattleRng = null
var _current_chapter: int = 1
var _mode: String = "normal"  # 源 stageselect.lua:319 doChangeMode — normal/elite/guild
var _stage_buttons: Dictionary = {}   # sid -> TextureButton（_refresh_view 重建）
var _content: Control = null
var _map_host: Control = null
var _frame_layer: Control = null
var _dot_container: Control = null
var _mode_buttons: Dictionary = {}   # mode -> TextureButton（.tscn %ModeXxxBtn）


func setup_panel(p_mgr: StageManager, p_player: PlayerData, p_rng: BattleRng) -> void:
	mgr = p_mgr
	player = p_player
	rng = p_rng
	_current_chapter = mgr.get_max_chapter("normal") if mgr != null else 1
	setup()
	_build_content()


# 源 createByStage(id)（equipcraft doClickGetWay :83 跳转）：按 stage_id 定位章再 setup。
func setup_by_stage(p_mgr: StageManager, p_player: PlayerData, p_rng: BattleRng, stage_id: int) -> void:
	mgr = p_mgr
	player = p_player
	rng = p_rng
	_current_chapter = _chapter_of_stage(stage_id)
	setup()
	_build_content()


# 源 createByStage(:1642-1663) — stage_id → Chapter ID（elite/raid 经 Stage Group 反查）。
func _chapter_of_stage(stage_id: int) -> int:
	var st: Dictionary = player.cm.get_raw_table(&"Stage")
	var sid: int = stage_id
	if stage_id >= 10000:
		sid = int(st.get(str(stage_id), {}).get("Stage Group", stage_id))
	return int(st.get(str(sid), {}).get("Chapter ID", 1))


# 建 UI 内容：base 从 .tscn instantiate（位置/size 固化）+ bind signals + fill mode toggle 文本。
# 源 framework.lua:749-751 pushScene 场景全屏 bg.jpg（stageselect 源是独立场景），
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
	_refresh_view()


# 源 create(:1617-1622) 顺序：map → frame/title → mode → arrows → dots。
# 动态层（map/frame/dots）随章/mode 变，_refresh_view 清空 host 再重建；静态层（mode/arrows）只切态。
func _refresh_view() -> void:
	_clear_children(_map_host)
	_clear_children(_frame_layer)
	_clear_children(_dot_container)
	_stage_buttons.clear()
	var cm: Variant = player.cm if player != null else null
	var star_of: Callable = Callable(self, "_get_stage_stars")
	var map_layer: Dictionary = StageSelectBuilder.create_map_layer(_map_host, _current_chapter, _mode, cm, star_of)
	_stage_buttons = map_layer["stage_buttons"]
	for sid in _stage_buttons:
		(_stage_buttons[sid] as TextureButton).pressed.connect(_on_stage_clicked.bind(sid))
	StageSelectBuilder.create_frame_and_title(_frame_layer, _current_chapter, _mode, cm)
	StageSelectBuilder.fill_mode_toggle(_mode_buttons, _mode, cm)
	var max_ch: int = mgr.get_max_chapter(_mode) if mgr != null else _current_chapter
	(_content.get_node("%PrevArrow") as CanvasItem).visible = _current_chapter > 1
	(_content.get_node("%NextArrow") as CanvasItem).visible = _current_chapter < max_ch
	StageSelectBuilder.create_chapter_dots(_dot_container, max_ch, _current_chapter, _mode)


static func _clear_children(host: Control) -> void:
	for c in host.get_children():
		c.free()


func _get_stage_stars(sid: int) -> int:
	if mgr == null:
		return 0
	return mgr.stage_stars(sid)


# 源 doChangeMode(:319) — 三 mode toggle（normal/elite/guild）。
func _on_mode_pressed(mode: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_mode = mode
	_current_chapter = mgr.get_max_chapter(mode) if mgr != null else 1
	_refresh_view()


# 源 doChangeChapter(:423)/setChapterButtonState(:643) — 章节切换（边界隐藏箭头）。
func _on_prev_chapter() -> void:
	_change_chapter(-1)


func _on_next_chapter() -> void:
	_change_chapter(1)


func _change_chapter(delta: int) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var max_ch: int = mgr.get_max_chapter(_mode) if mgr != null else StageSelectMap.CHAPTER_MAX
	_current_chapter = clampi(_current_chapter + delta, 1, max_ch)
	_refresh_view()


# 源 gotoDetailScene(:214) — 点击 stage 圆点弹关卡详情（照源 stageselect→stagedetail→battle）。
func _on_stage_clicked(sid: int) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	if mgr == null or player == null or rng == null:
		return
	var detail := StageDetailPanel.new("stagedetail", {})
	detail.setup_panel(sid, mgr, player, rng)
	detail.show_window(get_parent())
